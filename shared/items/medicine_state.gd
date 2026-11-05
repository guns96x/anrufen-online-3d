class_name MedicineState
extends RefCounted

## A shared category cooldown is modern tuning. Original Lua verifies medicine
## cooldown checks but does not include their durations or server grouping.
const COOLDOWN_SECONDS: float = 5.0
const GROUPS: Array[String] = ["player_hp","player_mp","pet_hp","pet_mp"]

static func group(effect: Dictionary) -> String:
	if effect.get("type") != "restore" or effect.get("stat") not in ["hp","mp"]: return ""
	return ("pet_" if effect.get("recipient") == "pet" else "player_")+str(effect["stat"])

static func validate(stats: Dictionary) -> bool:
	var values: Variant = stats.get("medicine_cooldowns",{})
	if not values is Dictionary or values.size() > GROUPS.size(): return false
	for key: Variant in values:
		var value: Variant = values[key]
		if not key is String or key not in GROUPS or (not value is int and not value is float): return false
		if not is_finite(float(value)) or float(value) < 0 or float(value) > 1000000000000.0: return false
	return true

static func available(stats: Dictionary, key: String, now: float) -> bool:
	return key in GROUPS and is_finite(now) and now >= 0 and validate(stats) and now >= float(stats.get("medicine_cooldowns",{}).get(key,0))

static func start(stats: Dictionary, key: String, now: float) -> void:
	if not stats.has("medicine_cooldowns"): stats["medicine_cooldowns"] = {}
	stats["medicine_cooldowns"][key] = now+COOLDOWN_SECONDS
