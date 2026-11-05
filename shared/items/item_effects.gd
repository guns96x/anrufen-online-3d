class_name ItemEffects
extends RefCounted

# Original text distinguishes immediate potions and gradual food. Restoration
# quantities, ten-second food duration and the five-effect cap are provisional.
const MAX_EFFECTS: int = 5

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and floor(float(value)) == float(value)

static func validate(stats: Dictionary) -> bool:
	var entries: Variant = stats.get("regeneration_effects",[])
	if not entries is Array or entries.size() > MAX_EFFECTS:
		return false
	var seen: Array[int] = []
	for entry: Variant in entries:
		if not entry is Dictionary or not _integer(entry.get("item_id"),1,99999999) or not entry.get("stat") is String or entry["stat"] not in ["hp","mp"]:
			return false
		for key: Variant in entry:
			if key not in ["item_id","stat","remaining_amount","remaining_time","fractional"]:
				return false
		var id: int = int(entry["item_id"])
		if id in seen:
			return false
		seen.append(id)
		var effect: Dictionary = ItemCatalog.get_item(id).get("effect",{})
		if effect.get("type") != "regenerate" or effect.get("stat") != entry["stat"]:
			return false
		if not _number(entry.get("remaining_amount"),0.000000001,float(effect["amount"])) or not _number(entry.get("remaining_time"),0.000000001,float(effect["duration"])):
			return false
		if not _number(entry.get("fractional",0.0),0.0,1.0) or float(entry.get("fractional",0.0)) >= 1.0 or float(entry["remaining_amount"]) + float(entry.get("fractional",0.0)) > float(effect["amount"]) + 0.00001:
			return false
	return true

static func tick(stats: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0 or delta > 3600.0 or not validate(stats):
		return
	for field: String in ["hp","mp","max_hp","max_mp"]:
		if not _integer(stats.get(field),0,1000000000):
			return
	if int(stats["hp"]) <= 0:
		stats["regeneration_effects"] = []
		return
	var kept: Array[Dictionary] = []
	for entry: Dictionary in stats.get("regeneration_effects",[]):
		var field: String = entry["stat"]
		var maximum: String = "max_" + field
		if not _integer(stats.get(field),0,1000000000) or not _integer(stats.get(maximum),0,1000000000):
			return
		if int(stats[field]) >= int(stats[maximum]):
			continue
		var remaining_time: float = float(entry["remaining_time"])
		var elapsed: float = minf(delta,remaining_time)
		if remaining_time - elapsed < 0.000001:
			elapsed = remaining_time
		var scheduled: float = float(entry["remaining_amount"]) * elapsed / remaining_time
		var accumulated: float = float(entry.get("fractional",0.0)) + scheduled
		var done: bool = elapsed >= remaining_time
		var restore: int = roundi(accumulated) if done else floori(accumulated)
		stats[field] = mini(int(stats[maximum]),int(stats[field]) + restore)
		entry["remaining_amount"] = maxf(0.0,float(entry["remaining_amount"]) - scheduled)
		entry["remaining_time"] = maxf(0.0,remaining_time - elapsed)
		entry["fractional"] = maxf(0.0,accumulated - float(restore))
		if not done and int(stats[field]) < int(stats[maximum]):
			kept.append(entry)
	stats["regeneration_effects"] = kept
