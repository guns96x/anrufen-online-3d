class_name CharacterSystem
extends RefCounted

# Class names and skill IDs come from the extracted tables. Requirements,
# point budgets and numerical effects are provisional modern balance.
const CLASSES: Dictionary = {
	130001: "Воїн-початківець", 130002: "Учень мага", 130004: "Воїн",
	130005: "Маг", 130006: "Лицар", 130007: "Берсерк",
	130008: "Маг стихій", 130009: "Маг тіней",
}
static var SKILLS: Dictionary = {
	90014: {"name": "Потужний удар", "source": "猛力攻击", "effect": "heavy", "level": 1, "max_rank": 5, "mp": 8, "cooldown": 3.0},
	90036: {"name": "Вогняна магія", "source": "火球术", "effect": "fire", "level": 1, "max_rank": 5, "mp": 15, "cooldown": 4.0},
	90035: {"name": "Крижаний удар", "source": "冻寒打击", "effect": "ice", "level": 3, "max_rank": 5, "mp": 12, "cooldown": 5.0},
	90041: {"name": "Зцілення", "source": "医疗术I", "effect": "heal", "level": 3, "max_rank": 5, "mp": 15, "cooldown": 6.0},
	90023: {"name": "Бойове тренування", "source": "战斗训练I", "effect": "passive_attack", "level": 1, "max_rank": 5, "mp": 0, "cooldown": 0.0},
	90037: {"name": "Магічне навчання", "source": "魔法学习I", "effect": "passive_mana", "level": 1, "max_rank": 5, "mp": 0, "cooldown": 0.0},
}
const ATTRIBUTES: Dictionary = {"strength": "Сила", "vitality": "Витривалість", "intelligence": "Інтелект", "agility": "Спритність"}
static var _source_skills_loaded: bool = false

static func ensure_skills() -> void:
	if not _source_skills_loaded:
		SKILLS.merge(SkillRules.player_definitions(),true)
		_source_skills_loaded = true

static func ensure_stats(stats: Dictionary) -> void:
	ensure_skills()
	StatusEffects.ensure_stats(stats)
	if not stats.has("base_accuracy"): stats["base_accuracy"] = stats.get("accuracy",0.95)
	if not stats.has("base_evasion"): stats["base_evasion"] = stats.get("evasion",0.05)
	var starter: int = 90122 if int(stats.get("class_id",130001)) in [130002,130005,130008,130009] else 90020
	var defaults: Dictionary = {"class_id": 130001, "race_id": 250001, "stat_points": 0, "skill_points": 1, "attributes": {"strength": 0, "vitality": 0, "intelligence": 0, "agility": 0}, "skills": {str(starter): 1}, "hotbar": {"1": starter}, "free_starter_skill":starter,"equipment": {}, "bag_capacity": 32}
	for key: String in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]

static func allocate(stats: Dictionary, attribute: String) -> bool:
	ensure_stats(stats)
	if not ATTRIBUTES.has(attribute) or int(stats["stat_points"]) <= 0:
		return false
	stats["stat_points"] -= 1
	stats["attributes"][attribute] = int(stats["attributes"].get(attribute, 0)) + 1
	return true

static func learn_skill(stats: Dictionary, skill_id: int) -> bool:
	ensure_stats(stats)
	if not SKILLS.has(skill_id) or int(stats["skill_points"]) <= 0:
		return false
	var skill: Dictionary = SKILLS[skill_id]
	if SkillRules.catalog().has(skill_id):
		if not SkillRules.allowed(int(stats["class_id"]),skill_id): return false
		var required: int = int(skill.get("prerequisite_skill",0))
		if required != 0 and int(stats["skills"].get(str(required),0)) < int(skill.get("prerequisite_rank",1)): return false
	var rank: int = int(stats["skills"].get(str(skill_id), 0))
	if int(stats["level"]) < int(skill["level"]) or rank >= int(skill["max_rank"]):
		return false
	stats["skill_points"] -= 1
	stats["skills"][str(skill_id)] = rank + 1
	return true

static func assign_skill(stats: Dictionary, slot: String, skill_id: int) -> bool:
	if slot not in ["1","2","3","4"] or not SKILLS.has(skill_id) or int(stats["skills"].get(str(skill_id), 0)) <= 0 or str(SKILLS[skill_id]["effect"]).begins_with("passive") or (slot != "1" and not SkillRules.catalog().has(skill_id)):
		return false
	stats["hotbar"][slot] = skill_id
	return true

static func respec_skills(stats: Dictionary, price: int = 100) -> bool:
	if price not in [0,100] or int(stats.get("copper", 0)) < price:
		return false
	var points: int = 0
	for key: String in stats["skills"]:
		points += int(stats["skills"][key])
	var starter: int = int(stats.get("free_starter_skill",0))
	var preserve_starter: bool = starter != 0 and int(stats["skills"].get(str(starter),0)) > 0 and SkillRules.allowed(int(stats.get("class_id",130001)),starter)
	if preserve_starter: points -= 1
	if points <= 0: return false
	stats["copper"] -= price
	stats["skill_points"] += points
	stats["skills"] = {}
	stats["hotbar"] = {}
	if preserve_starter:
		stats["skills"][str(starter)] = 1
		stats["hotbar"]["1"] = starter
	return true

static func choose_class(stats: Dictionary, class_id: int, race_id: int) -> bool:
	if not CLASSES.has(class_id) or race_id not in [250001, 250002]:
		return false
	if class_id in [130001, 130002]:
		if int(stats["level"]) != 1:
			return false
	elif int(stats["level"]) < 10 or int(stats.get("copper", 0)) < 200:
		return false
	elif class_id in [130004, 130006, 130007] and int(stats["class_id"]) not in [130001, 130004, 130006, 130007]:
		return false
	elif class_id in [130005, 130008, 130009] and int(stats["class_id"]) not in [130002, 130005, 130008, 130009]:
		return false
	if int(stats["class_id"]) == class_id and int(stats["race_id"]) == race_id:
		return false
	if class_id not in [130001, 130002]:
		stats["copper"] -= 200
	stats["class_id"] = class_id
	stats["race_id"] = race_id
	stats["class_name"] = CLASSES[class_id]
	var free: int = int(stats.get("free_starter_skill",0))
	for key: String in stats["skills"].keys():
		var id: int = int(key)
		if SkillRules.catalog().has(id) and not SkillRules.allowed(class_id,id):
			stats["skill_points"] += maxi(0,int(stats["skills"][key])-(1 if free == id else 0))
			stats["skills"].erase(key)
	for slot: String in stats["hotbar"].keys():
		if not stats["skills"].has(str(int(stats["hotbar"][slot]))): stats["hotbar"].erase(slot)
	var starter: int = 90122 if class_id in [130002,130005,130008,130009] else 90020
	if not stats["skills"].has(str(starter)): stats["skills"][str(starter)] = 1
	stats["free_starter_skill"] = starter
	if not stats["hotbar"].has("1"): stats["hotbar"]["1"] = starter
	TitleSystem.ensure_stats(stats)
	return true

static func available_skills(stats: Dictionary) -> Array[int]:
	ensure_skills()
	var result: Array[int] = []
	for id: int in SKILLS:
		if SkillRules.allowed(int(stats.get("class_id",130001)),id) or (not SkillRules.catalog().has(id) and int(stats.get("skills",{}).get(str(id),0)) > 0): result.append(id)
	return result

static func rebuild_stats(stats: Dictionary, equipment_bonuses: Dictionary = {}) -> void:
	ensure_stats(stats)
	var lv: int = int(stats["level"])
	var a: Dictionary = stats["attributes"]
	var mage: bool = int(stats["class_id"]) in [130002, 130005, 130008, 130009]
	stats["max_hp"] = (80 if mage else 100) + (lv - 1) * 15 + int(a["vitality"]) * 5 + int(equipment_bonuses.get("max_hp", 0))
	stats["max_mp"] = (90 if mage else 50) + (lv - 1) * 8 + int(a["intelligence"]) * 4 + int(stats["skills"].get("90037", 0)) * 5 + int(equipment_bonuses.get("max_mp", 0))
	stats["attack"] = (18 if mage else 22) + (lv - 1) * 3 + int(a["strength"]) * 2 + int(stats["skills"].get("90023", 0)) * 2 + int(equipment_bonuses.get("attack", 0))
	stats["defense"] = 8 + (lv - 1) * 2 + int(a["vitality"]) + int(equipment_bonuses.get("defense", 0))
	stats["crit_rate"] = minf(0.5, 0.15 + int(a["agility"]) * 0.005)
	var passive: Dictionary = SkillRules.passive_bonuses(stats)
	var effects: Dictionary = StatusEffects.modifiers(stats)
	stats["base_attack"] = int(stats["attack"])+roundi(passive["attack"])
	stats["base_magic_attack"] = (18 if mage else 12)+(lv-1)*3+int(a["intelligence"])*2+roundi(passive["magic_attack"])
	stats["base_defense"] = int(stats["defense"])+roundi(passive["defense"])
	stats["base_max_hp"] = roundi((float(stats["max_hp"])+passive["max_hp"])*(1.0+passive["hp_rate"]))
	stats["max_hp"] = maxi(1,roundi((float(stats["base_max_hp"])+float(effects.get("max_hp_add",0)))*(1.0+float(effects.get("max_hp_rate",0)))))
	stats["max_mp"] = maxi(0,int(stats["max_mp"])+roundi(passive["max_mp"]+float(effects.get("max_mp_add",0))))
	stats["attack"] = maxi(1,roundi((float(stats["base_attack"])+float(effects.get("attack_add",0)))*(1.0+float(effects.get("attack_rate",0)))))
	stats["magic_attack"] = maxi(1,roundi((float(stats["base_magic_attack"])+float(effects.get("magic_attack_add",0)))*(1.0+passive["magic_rate"]+float(effects.get("magic_attack_rate",0)))))
	stats["defense"] = maxi(0,roundi((float(stats["base_defense"])+float(effects.get("defense_add",0)))*(1.0+float(effects.get("defense_rate",0)))))
	stats["resist"] = maxf(0.0,(passive["resist"]+float(effects.get("resist_add",0)))*(1.0+float(effects.get("resist_rate",0))))
	stats["crit_rate"] = clampf(float(stats["crit_rate"])+passive["crit_rate"]+float(effects.get("crit_rate_add",0)),0.0,0.95)
	stats["accuracy"] = clampf(float(stats.get("base_accuracy",0.95))+passive["accuracy"]+float(effects.get("accuracy_add",0)),0.0,1.0)
	stats["evasion"] = clampf(float(stats.get("base_evasion",0.05))+passive["evasion"]+float(effects.get("evasion_add",0)),0.0,0.85)
	stats["hp_regen_bonus"] = passive["hp_regen"]
	stats["mp_regen_bonus"] = passive["mp_regen"]
	stats["hp"] = mini(int(stats["hp"]),int(stats["max_hp"]))
	stats["mp"] = mini(int(stats["mp"]),int(stats["max_mp"]))

static func equipment_bonuses(stats: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: Variant in stats.get("equipment",{}).values():
		for key: String in ItemCatalog.get_item(int(id)).get("bonuses",{}):
			result[key] = int(result.get(key,0))+int(ItemCatalog.get_item(int(id))["bonuses"][key])
	return result

static func validate(stats: Dictionary) -> bool:
	ensure_skills()
	if not StatusEffects.validate(stats): return false
	for key: String in ["base_accuracy","base_evasion"]:
		if stats.has(key) and not StatusEffects._number(stats[key],0.0,1.0): return false
	if stats.has("free_starter_skill") and (not _integer(stats["free_starter_skill"],0,999999) or int(stats["free_starter_skill"]) not in [0,90020,90122]): return false
	for field: String in ["class_id", "race_id", "stat_points", "skill_points"]:
		var value: Variant = stats.get(field)
		if not _integer(value, 0, 10000000):
			return false
	if not CLASSES.has(int(stats["class_id"])) or int(stats["race_id"]) not in [250001, 250002]:
		return false
	for field: String in ["attributes", "skills", "hotbar"]:
		if not stats.get(field) is Dictionary:
			return false
	if stats["attributes"].size() != ATTRIBUTES.size():
		return false
	for field: String in ATTRIBUTES:
		if not _integer(stats["attributes"].get(field), 0, 10000):
			return false
	for field: Variant in stats["skills"]:
		if not field is String or not field.is_valid_int() or str(int(field)) != field or not SKILLS.has(int(field)) or not _integer(stats["skills"][field], 1, int(SKILLS[int(field)]["max_rank"])):
			return false
		if SkillRules.catalog().has(int(field)) and not SkillRules.allowed(int(stats["class_id"]),int(field)): return false
	for slot: Variant in stats["hotbar"]:
		var id: Variant = stats["hotbar"][slot]
		if slot not in ["1","2","3","4"] or not _integer(id, 1, 999999) or not SKILLS.has(int(id)) or not stats["skills"].has(str(int(id))):
			return false
		if str(SKILLS[int(id)]["effect"]).begins_with("passive"):
			return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high
