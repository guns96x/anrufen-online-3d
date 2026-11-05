class_name StatusEffects
extends RefCounted

const MODIFIERS: Array[String] = ["attack_add","attack_rate","magic_attack_add","magic_attack_rate","defense_add","defense_rate","max_hp_add","max_hp_rate","max_mp_add","resist_add","resist_rate","accuracy_add","crit_rate_add","evasion_add","speed_add","slow_rate","shield_rate","shield_ratio","rooted"]

static func ensure_stats(stats: Dictionary) -> void:
	if not stats.has("skill_effects"): stats["skill_effects"] = []
	if not stats.has("skill_cooldowns"): stats["skill_cooldowns"] = {}

static func add(stats: Dictionary, skill_id: int, rank: int, duration: float, positive: bool, modifiers: Dictionary, owner: int = 0, periodic: Dictionary = {}) -> void:
	ensure_stats(stats)
	if duration <= 0.0: return
	var effect: Dictionary = {"skill_id":skill_id,"rank":rank,"remaining":duration,"positive":positive,"modifiers":modifiers.duplicate(true),"owner":owner,"periodic":periodic.duplicate(true)}
	for index: int in stats["skill_effects"].size():
		var old: Dictionary = stats["skill_effects"][index]
		if int(old["skill_id"]) == skill_id:
			if int(old["rank"]) > rank:
				old["remaining"] = maxf(float(old["remaining"]),duration)
			else:
				stats["skill_effects"][index] = effect
			return
	if stats["skill_effects"].size() < 64:
		stats["skill_effects"].append(effect)

static func modifiers(stats: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for effect: Dictionary in stats.get("skill_effects",[]):
		for key: String in effect["modifiers"]:
			if key in ["slow_rate","shield_rate","shield_ratio","rooted"]:
				result[key] = maxf(float(result.get(key,0)),float(effect["modifiers"][key]))
			else:
				result[key] = float(result.get(key,0))+float(effect["modifiers"][key])
	return result

static func cleanse(stats: Dictionary, positive: bool, maximum: int, chance: float) -> int:
	ensure_stats(stats)
	var removed: int = 0
	if randf()*100.0 >= chance: return 0
	for index: int in range(stats["skill_effects"].size()-1,-1,-1):
		if bool(stats["skill_effects"][index]["positive"]) == positive and removed < maximum:
			stats["skill_effects"].remove_at(index)
			removed += 1
	return removed

static func tick(stats: Dictionary, delta: float) -> Array[Dictionary]:
	ensure_stats(stats)
	var events: Array[Dictionary] = []
	if not is_finite(delta) or delta <= 0.0 or delta > 3600.0: return events
	for key: String in stats["skill_cooldowns"].keys():
		stats["skill_cooldowns"][key] = maxf(0.0,float(stats["skill_cooldowns"][key])-delta)
		if float(stats["skill_cooldowns"][key]) <= 0.0: stats["skill_cooldowns"].erase(key)
	for index: int in range(stats["skill_effects"].size()-1,-1,-1):
		var effect: Dictionary = stats["skill_effects"][index]
		var elapsed: float = minf(delta,float(effect["remaining"]))
		effect["remaining"] = maxf(0.0,float(effect["remaining"])-delta)
		var periodic: Dictionary = effect.get("periodic",{})
		if not periodic.is_empty():
			periodic["next"] -= elapsed
			var count: int = 0
			while float(periodic["next"]) <= 0.000001 and count < 64:
				var rates: Array = periodic["rates"]
				var rate: float = float(rates[mini(int(periodic["step"]),rates.size()-1)])
				events.append({"owner":int(effect["owner"]),"skill_id":int(effect["skill_id"]),"damage":maxi(1,roundi(float(stats.get("base_max_hp",stats.get("max_hp",1)))*rate/100.0))})
				periodic["step"] += 1
				periodic["next"] += float(periodic["interval"])
				count += 1
		if float(effect["remaining"]) <= 0.0:
			stats["skill_effects"].remove_at(index)
	return events

static func absorb(stats: Dictionary, incoming: int) -> int:
	if incoming <= 0: return 0
	var effects: Dictionary = modifiers(stats)
	var ratio: float = maxf(0.01,float(effects.get("shield_ratio",1)))
	var blocked: int = mini(floori(float(incoming)*clampf(float(effects.get("shield_rate",0))/100.0,0,1)),floori(float(stats.get("mp",0))/ratio))
	stats["mp"] = maxi(0,int(stats.get("mp",0))-ceili(float(blocked)*ratio))
	return incoming-blocked

static func speed_multiplier(stats: Dictionary) -> float:
	var effects: Dictionary = modifiers(stats)
	if float(effects.get("rooted",0)) > 0.0: return 0.0
	return maxf(0.1,(1.0+float(effects.get("speed_add",0))/6.0)*(1.0-clampf(float(effects.get("slow_rate",0)),0,0.9)))

static func validate(stats: Dictionary) -> bool:
	if not stats.get("skill_effects",[]) is Array or stats.get("skill_effects",[]).size() > 64 or not stats.get("skill_cooldowns",{}) is Dictionary or stats.get("skill_cooldowns",{}).size() > 100: return false
	for key: Variant in stats.get("skill_cooldowns",{}):
		if not key is String or not key.is_valid_int() or str(int(key)) != key or not SkillRules.catalog().has(int(key)) or not _number(stats["skill_cooldowns"][key],0,86400): return false
	var seen: Array[int] = []
	for effect: Variant in stats.get("skill_effects",[]):
		if not effect is Dictionary or not _integer(effect.get("skill_id"),1,999999) or not SkillRules.catalog().has(int(effect["skill_id"])) or not _integer(effect.get("rank"),1,15) or not _number(effect.get("remaining"),0,86400) or not effect.get("positive") is bool or not effect.get("modifiers") is Dictionary or not _integer(effect.get("owner"),0,2147483647) or not effect.get("periodic") is Dictionary: return false
		if int(effect["skill_id"]) in seen or int(effect["rank"]) > int(SkillRules.catalog()[int(effect["skill_id"])]["max_rank"]): return false
		seen.append(int(effect["skill_id"]))
		for key: Variant in effect["modifiers"]:
			if key not in MODIFIERS or not _number(effect["modifiers"][key],-10000000,10000000): return false
		var periodic: Dictionary = effect["periodic"]
		if not periodic.is_empty():
			if not _number(periodic.get("interval"),0.1,3600) or not _number(periodic.get("next"),0,3600) or not _integer(periodic.get("step"),0,1000000) or not periodic.get("rates") is Array or periodic["rates"].is_empty() or periodic["rates"].size() > 20: return false
			for rate: Variant in periodic["rates"]:
				if not _number(rate,0,100): return false
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and float(value) == floor(float(value))
