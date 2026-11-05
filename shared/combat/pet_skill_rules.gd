class_name PetSkillRules
extends RefCounted

## Pure plans. Source constants are never scaled by the raw rank limit.
## MP /20, world-space ranges and aura refresh/lifetime are MODERN tuning.
const SOURCE_PATH: String = "res://data/original/pet_rules.json"
const PASSIVES: Array[int] = [90023,90027,90037,90051,90052,90053,90054,90055,90056]
const HEALS: Array[int] = [90041,90049,90057]
const AURAS: Array[int] = [90058,90059,90060,90061,90062,90063,90064,90065,90066,90068,90069,90070,90071,90072,90073,90074,90075,90076,90077,90078,90079]
const SELF_SUPPORT: Array[int] = [90155,90156]
const MELEE_RANGE: float = 2.5
const MAGIC_RANGE: float = 10.0
const OWNER_RANGE: float = 12.0
const AURA_REFRESH: float = 5.0
const AURA_LIFETIME: float = 10.0
const LABELS: Dictionary = {
	90014:"Сильна атака",90024:"Руйнівний удар",90025:"Полум'яний удар",90035:"Крижаний удар",90036:"Вогняна куля",90038:"Крижаний постріл",90039:"Пекельне полум'я",
	90023:"Бойове тренування I",90053:"Бойове тренування II",90054:"Бойове тренування III",90037:"Магічне навчання I",90051:"Магічне навчання II",90052:"Магічне навчання III",90027:"Витривалість I",90055:"Витривалість II",90056:"Витривалість III",
	90041:"Лікування I",90049:"Лікування II",90057:"Лікування III",90058:"Ореол атаки I",90059:"Ореол атаки II",90060:"Ореол атаки III",90061:"Ореол захисту I",90062:"Ореол захисту II",90063:"Ореол захисту III",90064:"Ореол здоров'я I",90065:"Ореол здоров'я II",90066:"Ореол здоров'я III",
	90068:"Ореол опору вогню I",90069:"Ореол опору вогню II",90070:"Ореол опору вогню III",90071:"Ореол опору холоду I",90072:"Ореол опору холоду II",90073:"Ореол опору холоду III",90074:"Ореол ухилення I",90075:"Ореол ухилення II",90076:"Ореол ухилення III",90077:"Ореол влучності I",90078:"Ореол влучності II",90079:"Ореол влучності III",
	90145:"Натиск",90146:"Магічний меч",90147:"Укус",90148:"Хитрий напад",90149:"Палаючий слиз",90150:"Свинячий натиск",90151:"Крижаний захист",90152:"Маневровий бій",90153:"Вогняне жало",90154:"Холодні ікла",90155:"Клич",90156:"Натхнення",90157:"Поглинання"}
static var _definitions: Dictionary = {}
static var _species: Dictionary = {}

static func _catalog() -> Dictionary:
	if not _definitions.is_empty(): return _definitions
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_PATH))
	if not parsed is Dictionary: return {}
	_species = parsed.get("species",{}).duplicate(true)
	for key: String in parsed.get("skills",{}):
		var row: Dictionary = parsed["skills"][key]
		var id: int = int(key)
		var category: String = "passive" if id in PASSIVES else ("aura" if id in AURAS else "active")
		var candidate: Variant = row.get("mana_cost_candidate")
		var cost: int = ceili(float(candidate)/20.0) if candidate != null and float(candidate) > 0.0 else 0
		var source_range: float = float(row.get("source_range_raw",0))
		_definitions[id] = {"id":id,"name":row["name"],"description":row["description"],"kind":row["kind"],"category":category,
			"source_name":row["name"],"source_description":row["description"],"label":LABELS.get(id,row["name"]),
			"constants":row["constants"].duplicate(true),"raw_rank_limit":int(row["raw_rank_limit"]),
			"source_candidate_mp_cost":candidate,"mp_cost":cost,
			"source_cooldown":float(row["cooldown_milliseconds_raw"])/1000.0,
			"cooldown":0.0 if category == "passive" else (AURA_REFRESH if category == "aura" else float(row["cooldown_milliseconds_raw"])/1000.0),
			"cast_seconds":float(row["cast_milliseconds_raw"])/1000.0,"source_range_raw":source_range,
			"range":OWNER_RANGE if id in HEALS or id in AURAS or id in SELF_SUPPORT else (MELEE_RANGE if source_range <= 64.0 else MAGIC_RANGE),
			"modern_tuning":["candidate_mana_divided_by_20","world_space_range"] + (["aura_refresh_and_lifetime"] if category == "aura" else [])}
	for id: int in _definitions: _definitions[id]["description_uk"] = _description_uk(id)
	return _definitions

static func definitions() -> Dictionary:
	return _catalog().duplicate(true)

static func definition(id: int) -> Dictionary:
	return _catalog().get(id,{}).duplicate(true)

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value,low,high) and float(value) == floor(float(value))

static func _snapshot_valid(stats: Dictionary) -> bool:
	if not _integer(stats.get("max_hp"),1,1000000) or not _integer(stats.get("hp"),0,int(stats["max_hp"])): return false
	if stats.has("is_dead") and not stats["is_dead"] is bool: return false
	if not _integer(stats.get("level",1),1,1000): return false
	for key: String in ["attack","magic_attack","defense","magic_defense","base_attack","base_magic_attack","base_max_hp","base_max_mp"]:
		if stats.has(key) and not _number(stats[key],0,1000000): return false
	return true

static func _pet_valid(pet: Dictionary) -> bool:
	_catalog()
	if not _integer(pet.get("level"),1,100): return false
	if not _snapshot_valid(pet) or not _integer(pet.get("species_id"),1,999999) or not _species.has(str(int(pet["species_id"]))): return false
	if not _integer(pet.get("max_mp",40),0,1000000) or not _integer(pet.get("mp",0),0,int(pet.get("max_mp",40))): return false
	if not _number(pet.get("hunger",100),0,100) or not pet.get("skills",[]) is Array or pet.get("skills",[]).size() > 3: return false
	if pet.has("summoned") and not pet["summoned"] is bool: return false
	var seen: Array[int] = []
	for skill: Variant in pet.get("skills",[]):
		if not _integer(skill,1,999999) or int(skill) in seen or not _definitions.has(int(skill)) or _definitions[int(skill)]["kind"] != "random": return false
		seen.append(int(skill))
	if not pet.get("skill_cooldowns",{}) is Dictionary or pet.get("skill_cooldowns",{}).size() > 53: return false
	for key: Variant in pet.get("skill_cooldowns",{}):
		if not (key is int or (key is String and key.is_valid_int())) or not _definitions.has(int(key)) or not _number(pet["skill_cooldowns"][key],0,86400): return false
	return true

static func _alive(stats: Dictionary) -> bool:
	return float(stats.get("hp",0)) > 0.0 and not bool(stats.get("is_dead",false))

static func _context_valid(context: Dictionary) -> bool:
	if context.has("selected_skill_id") and not _integer(context["selected_skill_id"],0,999999): return false
	for key: String in ["triggered_innate","target_is_monster","hostile_allowed","target_is_ally","owner_hurt","controls_blocked"]:
		if context.has(key) and not context[key] is bool: return false
	for key: String in ["distance","owner_distance","elapsed"]:
		if context.has(key) and not _number(context[key],0,1000000): return false
	return not context.has("roll") or _number(context["roll"],0,1)

static func _constant(id: int, name: String) -> float:
	var values: Array = _definitions[id]["constants"].get(name,[])
	return float(values[0]) if not values.is_empty() else 0.0

static func _description_uk(id: int) -> String:
	match id:
		90014: return "Ближня фізична атака без витрати мани."
		90024: return "Ближня фізична атака з додатковими 60% сили удару."
		90025: return "Ближня атака завдає фізичної та вогняної магічної шкоди."
		90035: return "Ближня атака завдає фізичної та крижаної магічної шкоди."
		90036: return "Вогняна магічна атака на відстані."
		90038: return "Крижана магічна атака на відстані."
		90039: return "Вогняна магічна атака з додатковими 60% шкоди."
		90023,90053,90054: return "Фізична атака +%.0f%%, імовірність критичного удару +%.0f%%." % [_constant(id,"add_phy_attack_rate"),_constant(id,"add_fatal")]
		90037,90051,90052: return "Магічна атака +%.0f%%, імовірність критичного удару +%.0f%%." % [_constant(id,"add_magic_attack_rate"),_constant(id,"add_fatal")]
		90027,90055,90056: return "Максимум здоров'я +%.0f%%, захист від критичних ударів +%.0f%%." % [_constant(id,"add_hp_max_rate"),_constant(id,"add_luck")]
		90041,90049,90057: return "Лікує тварину та власника на %.0f%% їхнього базового максимуму здоров'я." % _constant(id,"cure_self_hp_rate")
		90058,90059,90060: return "Поки тварину викликано, атака власника й тварини +%.0f%%." % _constant(id,"add_attack_rate")
		90061,90062,90063: return "Поки тварину викликано, фізичний захист власника й тварини +%.0f%%." % _constant(id,"add_defence_rate")
		90064,90065,90066: return "Поки тварину викликано, максимум здоров'я власника й тварини +%.0f%%." % _constant(id,"add_hp_max_rate")
		90068,90069,90070: return "Поки тварину викликано, опір вогню власника й тварини +%.0f%%." % _constant(id,"add_fire_res_rate")
		90071,90072,90073: return "Поки тварину викликано, опір холоду власника й тварини +%.0f%%." % _constant(id,"add_ice_res_rate")
		90074,90075,90076: return "Поки тварину викликано, ухилення власника й тварини +%.0f%%." % _constant(id,"add_jook")
		90077,90078,90079: return "Поки тварину викликано, влучність власника й тварини +%.0f%%." % _constant(id,"add_hit")
		90145: return "Фізична атака з додатковою шкодою 2% базового максимуму здоров'я."
		90146: return "Фізична атака з додатковими 8% базової сили атаки."
		90147: return "Фізична атака з додатковою шкодою: рівень тварини ×4."
		90148: return "Фізична атака з додатковою шкодою: рівень ворога ×5."
		90149: return "Вогняна атака; загроза для монстра зростає на рівень тварини ×20."
		90150: return "Фізична атака; загроза для монстра зростає на рівень тварини ×20."
		90151: return "Крижана атака; усі опори тварини +рівень ×3 на 5 с."
		90152: return "Фізична атака; захист тварини +рівень ×3 на 5 с."
		90153: return "Вогняна магічна атака з додатковими 8% сили атаки."
		90154: return "Крижана атака з додатковою шкодою 2% базового максимуму мани."
		90155: return "Фізична атака власника й тварини +100 на 60 с."
		90156: return "Магічна атака власника й тварини +100 на 60 с."
		90157: return "Імовірність 50% зняти один позитивний ефект із ворога."
	return ""

static func _passive(id: int) -> Dictionary:
	match id:
		90023,90053,90054: return {"attack_rate":_constant(id,"add_phy_attack_rate")/100.0,"crit_rate_add":_constant(id,"add_fatal")/100.0}
		90037,90051,90052: return {"magic_attack_rate":_constant(id,"add_magic_attack_rate")/100.0,"crit_rate_add":_constant(id,"add_fatal")/100.0}
		90027,90055,90056: return {"max_hp_rate":_constant(id,"add_hp_max_rate")/100.0,"crit_resist_add":_constant(id,"add_luck")/100.0}
	return {}

static func passive_modifiers(pet: Dictionary) -> Dictionary:
	if not _pet_valid(pet) or not _alive(pet) or not bool(pet.get("summoned",true)) or float(pet.get("hunger",100)) <= 0.0: return {}
	var result: Dictionary = {}
	for skill: Variant in pet.get("skills",[]):
		for key: String in _passive(int(skill)):
			result[key] = float(result.get(key,0.0))+float(_passive(int(skill))[key])
	return result

static func _owned(pet: Dictionary, id: int) -> bool:
	if not _definitions.has(id): return false
	if _definitions[id]["kind"] == "innate":
		return int(_species[str(int(pet["species_id"]))]["innate_skill_id"]) == id
	return id in pet.get("skills",[])

static func _cooldown(pet: Dictionary, id: int) -> float:
	var values: Dictionary = pet.get("skill_cooldowns",{})
	return float(values.get(str(id),values.get(id,0.0)))

## Snapshots are trusted combat inputs; hostile_allowed must come from the
## authoritative PK policy. Missing monster/hostile permission fails closed.
static func build(pet: Dictionary, owner: Dictionary, enemy: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not _pet_valid(pet) or not _snapshot_valid(owner) or not _context_valid(context): return _fail("Некоректні бойові дані.")
	if not _alive(pet) or not _alive(owner) or not bool(pet.get("summoned",true)) or float(pet.get("hunger",100)) <= 0.0 or bool(context.get("controls_blocked",false)): return _fail("Тварина або власник не можуть діяти.")
	var id: int = int(context.get("selected_skill_id",0))
	if id != 0: return _plan(pet,owner,enemy,context,id)
	if bool(context.get("triggered_innate",false)):
		id = int(_species[str(int(pet["species_id"]))]["innate_skill_id"])
		return _plan(pet,owner,enemy,context,id)
	# Modern deterministic choice: needed healing, aura refresh, then attack;
	# skip unavailable/cooling/too expensive choices. No input is changed.
	var choices: Array[int] = []
	for category: int in range(3):
		for skill: Variant in pet.get("skills",[]):
			id = int(skill)
			if (category == 0 and id in HEALS) or (category == 1 and id in AURAS) or (category == 2 and id not in PASSIVES and id not in HEALS and id not in AURAS): choices.append(id)
	for candidate: int in choices:
		var plan: Dictionary = _plan(pet,owner,enemy,context,candidate)
		if bool(plan["ok"]): return plan
	return _fail("Немає доступної дії.")

static func _plan(pet: Dictionary, owner: Dictionary, enemy: Dictionary, context: Dictionary, id: int) -> Dictionary:
	if not _owned(pet,id): return _fail("Навичка не належить цій тварині.",id)
	var row: Dictionary = _definitions[id]
	if id in PASSIVES:
		var passive_plan: Dictionary = _success(id,[],0,0.0)
		passive_plan["passive"] = true
		passive_plan["modifiers"] = _passive(id)
		return passive_plan
	if _cooldown(pet,id) > 0.0: return _fail("Навичка відновлюється.",id)
	if int(pet.get("mp",0)) < int(row["mp_cost"]): return _fail("Недостатньо мани.",id)
	var support: bool = id in HEALS or id in AURAS or id in SELF_SUPPORT
	if not support:
		if not _snapshot_valid(enemy) or not _alive(enemy) or not context.has("distance"): return _fail("Немає живої цілі в межах дії.",id)
		if bool(context.get("target_is_ally",false)) or bool(enemy.get("is_ally",false)) or not (bool(context.get("target_is_monster",false)) or bool(context.get("hostile_allowed",false))): return _fail("Атака цієї цілі заборонена.",id)
		if pet.get("uid","") != "" and pet.get("uid") == enemy.get("uid"): return _fail("Не можна атакувати себе.",id)
		if owner.get("account_id",0) != 0 and owner.get("account_id") == enemy.get("account_id"): return _fail("Не можна атакувати власника.",id)
		if float(context["distance"]) > float(row["range"]): return _fail("Ціль надто далеко.",id)
	var actions: Array[Dictionary] = []
	var near_owner: bool = float(context.get("owner_distance",0.0)) <= OWNER_RANGE
	if id in AURAS:
		var aura: Dictionary = _aura(id)
		_effect(actions,"self",aura,AURA_LIFETIME,true)
		if near_owner: _effect(actions,"owner",aura,AURA_LIFETIME,true)
	elif id in HEALS:
		_heal(actions,"self",pet,_constant(id,"cure_self_hp_rate")/100.0)
		if near_owner: _heal(actions,"owner",owner,_constant(id,"cure_self_hp_rate")/100.0)
	elif id in SELF_SUPPORT:
		var modifiers: Dictionary = {"attack_add":_constant(id,"app_phy")} if id == 90155 else {"magic_attack_add":_constant(id,"app_mag")}
		_effect(actions,"self",modifiers,_constant(id,"buff_duration"))
		if near_owner: _effect(actions,"owner",modifiers,_constant(id,"buff_duration"))
	else:
		match id:
			90014: _damage(actions,pet,enemy,1)
			90024: _damage(actions,pet,enemy,1,1.0+_constant(id,"add_phy_dam_rate")/100.0)
			90025,90035:
				_damage(actions,pet,enemy,1,1.0+_constant(id,"add_phy_dam_rate")/100.0)
				# 90035's misleading Lua key says fire; the original prose says ICE.
				_damage(actions,pet,enemy,2 if id == 90025 else 3,1.0+_constant(id,"add_fire_dam_rate")/100.0)
			90036: _damage(actions,pet,enemy,2,1.0+_constant(id,"add_fire_dam_rate")/100.0)
			90038: _damage(actions,pet,enemy,3,1.0+_constant(id,"add_ice_dam_rate")/100.0)
			90039: _damage(actions,pet,enemy,2,1.0+_constant(id,"add_fire_dam_rate")/100.0)
			90145: _damage(actions,pet,enemy,1,1.0,0.0,_constant(id,"app_hp_max_rate"))
			90146: _damage(actions,pet,enemy,1,1.0+_constant(id,"app_phy_rate")/100.0)
			90147: _damage(actions,pet,enemy,1,1.0,0.0,0.0,0.0,_constant(id,"app_rate"))
			90148: _damage(actions,pet,enemy,1,1.0,0.0,0.0,0.0,0.0,_constant(id,"app_rate"))
			90149,90150:
				_damage(actions,pet,enemy,2 if id == 90149 else 1)
				if bool(context.get("target_is_monster",false)): actions.append({"kind":"threat","recipient":"enemy","toward":"self","amount":int(pet["level"])*int(_constant(id,"app_rate")),"monster_only":true})
			90151,90152:
				_damage(actions,pet,enemy,3 if id == 90151 else 1)
				_effect(actions,"self",{("resist_add" if id == 90151 else "defense_add"):float(pet["level"])*_constant(id,"app_rate")},_constant(id,"buff_duration"))
			90153: _damage(actions,pet,enemy,2,1.0+_constant(id,"app_rate")/100.0)
			90154: _damage(actions,pet,enemy,3,1.0,0.0,0.0,_constant(id,"app_rate"))
			90157:
				if not context.has("roll"): return _fail("Потрібне серверне випадкове значення.",id)
				var chance: float = _constant(id,"remove_rate")/100.0
				actions.append({"kind":"dispel","recipient":"enemy","positive":true,"maximum":int(_constant(id,"remove_num")),"chance":chance,"succeeded":float(context["roll"]) < chance,"roll":float(context["roll"])})
			_: return _fail("Немає підтриманого правила.",id)
	if actions.is_empty(): return _fail("Немає потрібного ефекту.",id)
	return _success(id,actions,int(row["mp_cost"]),float(row["cooldown"]))

static func _aura(id: int) -> Dictionary:
	match id:
		90058,90059,90060:
			var rate: float = _constant(id,"add_attack_rate")/100.0
			return {"attack_rate":rate,"magic_attack_rate":rate}
		90061,90062,90063: return {"defense_rate":_constant(id,"add_defence_rate")/100.0}
		90064,90065,90066: return {"max_hp_rate":_constant(id,"add_hp_max_rate")/100.0}
		90068,90069,90070: return {"fire_resist_rate":_constant(id,"add_fire_res_rate")/100.0}
		90071,90072,90073: return {"water_resist_rate":_constant(id,"add_ice_res_rate")/100.0}
		90074,90075,90076: return {"evasion_add":_constant(id,"add_jook")/100.0}
		90077,90078,90079: return {"accuracy_add":_constant(id,"add_hit")/100.0}
	return {}

static func _base(stats: Dictionary, key: String, fallback: float) -> float:
	return float(stats.get("base_"+key,stats.get(key,fallback)))

static func _damage(actions: Array[Dictionary], pet: Dictionary, enemy: Dictionary, element: int, attack_rate: float = 1.0, flat: float = 0.0, hp_rate: float = 0.0, mp_rate: float = 0.0, level_rate: float = 0.0, target_level_rate: float = 0.0) -> void:
	var fallback: float = 8.0+float(pet["level"])*3.0 # Explicit modern fallback for existing minimal pet snapshots.
	var stat: String = "attack" if element == 1 else "magic_attack"
	var power: float = _base(pet,stat,_base(pet,"attack",fallback))*attack_rate+flat+_base(pet,"max_hp",float(pet["max_hp"]))*hp_rate+_base(pet,"max_mp",float(pet.get("max_mp",40)))*mp_rate+float(pet["level"])*level_rate+float(enemy.get("level",1))*target_level_rate
	actions.append({"kind":"damage","recipient":"enemy","damage_type":element,"base_stat":stat,"base":power,"flat":flat,"attack_rate":attack_rate,"hp_max_rate":hp_rate,"mp_max_rate":mp_rate,"level_rate":level_rate,"target_level_rate":target_level_rate})

static func _effect(actions: Array[Dictionary], recipient: String, modifiers: Dictionary, duration: float, aura: bool = false) -> void:
	actions.append({"kind":"effect","recipient":recipient,"positive":true,"duration":duration,"modifiers":modifiers.duplicate(true),"while_summoned":aura})

static func _heal(actions: Array[Dictionary], recipient: String, target: Dictionary, rate: float) -> void:
	if not _alive(target): return
	var missing: int = int(target["max_hp"])-int(target["hp"])
	var amount: int = mini(missing,maxi(0,floori(_base(target,"max_hp",float(target["max_hp"]))*rate)))
	if amount > 0: actions.append({"kind":"heal_hp","recipient":recipient,"amount":amount,"hp_max_rate":rate})

static func _success(id: int, actions: Array[Dictionary], cost: int, cooldown: float) -> Dictionary:
	return {"ok":true,"error":"","actions":actions,"mp_cost":cost,"skill_id":id,"cooldown":cooldown,"cast_seconds":float(_definitions[id]["cast_seconds"]),"source_candidate_mp_cost":_definitions[id]["source_candidate_mp_cost"]}

static func _fail(message: String, id: int = 0) -> Dictionary:
	return {"ok":false,"error":message,"actions":[],"mp_cost":0,"skill_id":id,"cooldown":0.0}
