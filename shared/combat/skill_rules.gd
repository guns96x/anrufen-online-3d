class_name SkillRules
extends RefCounted

# Numeric constants and cooldowns below are read from the original Lua/binary.
# World ranges, MP prices and required character levels remain modern tuning.
const LABELS: Dictionary = {
	90020:"Базове фехтування",90022:"Володіння зброєю",90042:"Міць",90095:"Заряджений розмах",90043:"Спритність",90021:"Метання кинджала",
	90044:"Подвійний удар",90040:"Майстерність захисту",90104:"Аура стійкості",90084:"Прискорення",90096:"Швидке загоєння",90105:"Розсічення душі",
	90117:"Гнівний удар",90118:"Розрив",90119:"Зневага до болю",90120:"Лють",90121:"Шалений натиск",
	90106:"Провокація",90107:"Аура опіки",90113:"Священний клинок",90115:"Щит лицаря",90116:"Розвіювання",
	90122:"Вогняна куля",90124:"Вивчення магії",90125:"Запас мани",90126:"Лікування",90097:"Контроль мани",90123:"Заморожування",
	90127:"Полум'я",90130:"Опір природі",90131:"Аура мани",90129:"Магічний щит",90098:"Відновлення мани",90128:"Хуртовина",
	90132:"Групове лікування",90133:"Дар стихій",90134:"Крижане пронизування",90135:"Панування над стихіями",90136:"Кара священного дракона",
	90137:"Тіньове жало",90141:"Завіса тіней",90140:"Пришестя темряви",90138:"Мітка смерті",90139:"Прокляття тіні",
}
const PASSIVES: Array[int] = [90022,90042,90043,90040,90096,90118,90107,90124,90125,90097,90130,90098,90133,90141]
const SELF_SKILLS: Array[int] = [90084,90119,90120,90115,90126,90129]
const PARTY_SKILLS: Array[int] = [90104,90131,90132,90135]
const AREA_SKILLS: Array[int] = [90128,90136,90140,90138]
const ANCESTORS: Dictionary = {130001:[130001],130004:[130001,130004],130006:[130001,130004,130006],130007:[130001,130004,130007],130002:[130002],130005:[130002,130005],130008:[130002,130005,130008],130009:[130002,130005,130009]}
const DESCRIPTIONS: Dictionary = {
	90020:"Ближній удар із додатковою фізичною атакою {add_phy}.",
	90022:"Пасивно: фізична атака +{add_phy}.",90042:"Пасивно: максимум здоров'я +{add_hp_max}.",
	90095:"Удар із додатковою атакою {add_phy}; атака +{buff_phy} на {buff_duration} с.",
	90043:"Пасивно підвищує ухилення.",90021:"Кидок кинджала з додатковою фізичною атакою {add_phy}.",
	90044:"Два удари: фізичний із посиленням {add_phy_rate}% і священний із силою {add_holy}.",
	90040:"Пасивно: фізичний захист +{add_phy_def}.",
	90104:"Вам і найближчим членам групи: максимум здоров'я +{add_hp_max} на {buff_duration} хв.",
	90084:"Швидкість руху +{add_speed} на {buff_duration} с.",
	90096:"Пасивно: додаткові {hp_grow} здоров'я за 10 с.",90105:"Спалює ману цілі: {add_phy_rate}% вашої фізичної атаки плюс {damage_mp}.",
	90117:"Потужний удар: +{add_phy} атаки й додаткові {add_phy_rate}% фізичної атаки.",
	90118:"Пасивно підвищує критичний удар, влучність та ухилення.",
	90119:"Імовірність {rem_buff_rate}% зняти із себе до {rem_buff_num} ослаблень.",
	90120:"На {buff_duration} с: атака +{add_phy_rate}%, здоров'я +{add_hp_max}, захист і опір −{sub_def}%.",
	90121:"Комбінація з трьох ударів. Останній удар має посилену атаку та шанс критичного удару.",
	90106:"Додає {add_hate} загрози, привертаючи увагу монстра.",
	90107:"Пасивно: максимум здоров'я +{add_hp_max_rate}% і всі опори +{add_resist}.",
	90113:"Витрачає всю ману на священний удар. Коефіцієнт перетворення: {tran_rate}.",
	90115:"На {buff_duration} с: фізичний захист і всі опори +{add_resist}.",
	90116:"Імовірність {rem_buff_rate}% зняти з ворога до {rem_buff_num} посилень.",
	90122:"Дальня вогняна атака. Додаткова магічна атака: {add_fire}.",
	90124:"Пасивно: магічна атака +{add_mag}.",90125:"Пасивно: максимум мани +{add_mp_max}.",
	90126:"Відновлює собі {add_hp} здоров'я.",90097:"Пасивно підвищує влучність.",
	90123:"Крижана атака: +{add_water} магічної атаки та +{add_fatal}% критичного удару.",
	90127:"Вогняна атака: +{add_fire_val} і додаткові {add_fire_rate}% магічної атаки.",
	90130:"Пасивно: усі опори +{add_resist}.",
	90131:"Вам і найближчим членам групи: максимум мани +{add_mp_max} на {buff_duration} хв.",
	90129:"На 30 с: {work_rate}% отриманої шкоди поглинається маною; {mp_trans_hp} мани за одиницю шкоди.",
	90098:"Пасивно: додаткові {mp_grow} мани за 10 с.",
	90128:"Атака кригою по області: +{add_water} і {basic_attack_rate}% магічної атаки.",
	90132:"Відновлює вам і найближчим членам групи {add_hp_rate}% базового максимуму здоров'я.",
	90133:"Пасивно: фізичний захист +{add_def}, максимум здоров'я +{add_hp_max_rate}%.",
	90134:"Крижана атака; імовірність {buff_rate}% заморозити ціль на {buff_duration} с.",
	90135:"Вам і найближчим членам групи: усі опори +{add_resist} на {buff_duration} с.",
	90136:"Вогняна атака по області: +{add_fire} і додаткові {add_fire_rate}% магічної атаки.",
	90137:"Темна атака: +{add_dark} і додаткові {add_dark_rate}% магічної атаки.",
	90141:"Пасивно підвищує опори, влучність, ухилення й магічну атаку.",
	90140:"Темна атака по області з посиленими атакою та шансом критичного удару.",
	90138:"На {debuff_duration} с знижує фізичний захист і опори ворогів в області на {ignore_per}%.",
	90139:"Прокляття лише проти гравців. Періодична шкода зростає від 20% до 90% базового здоров'я цілі.",
}
static var _catalog: Dictionary = {}
static var _player_definitions: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/skill_rules.json"))
		if parsed is Dictionary and parsed.get("skills") is Dictionary:
			for key: String in parsed["skills"]:
				var row: Dictionary = parsed["skills"][key]
				if row.get("owner") == "player":
					_catalog[int(key)] = row
	return _catalog

static func player_definitions() -> Dictionary:
	if not _player_definitions.is_empty(): return _player_definitions
	var result: Dictionary = {}
	for id: int in catalog():
		var row: Dictionary = _catalog[id]
		result[id] = {"name":LABELS.get(id,row["source_name"]),"source":row["source_name"],"class_id":int(row["class_id"]),"effect":"passive_original" if id in PASSIVES else "original","level":1 if int(row["class_id"]) in [130001,130002] else 10,"max_rank":int(row["max_rank"]),"mp":0 if id in PASSIVES or id == 90020 else 15,"cooldown":0.0 if id in PASSIVES else float(row["cooldown"]),"range":3.5 if float(row["source_range"]) <= 64.0 else 12.0,"prerequisite_skill":int(row["prerequisite_skill"]),"prerequisite_rank":int(row["prerequisite_rank"])}
	_player_definitions = result
	return _player_definitions

static func value(id: int, key: String, rank: int) -> float:
	var values: Array = catalog().get(id,{}).get("constants",{}).get(key,[])
	return 0.0 if values.is_empty() else float(values[clampi(rank-1,0,values.size()-1)])

static func allowed(class_id: int, skill_id: int) -> bool:
	return catalog().has(skill_id) and int(_catalog[skill_id]["class_id"]) in ANCESTORS.get(class_id,[])

static func passive_bonuses(stats: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {"attack":0.0,"magic_attack":0.0,"defense":0.0,"max_hp":0.0,"max_mp":0.0,"hp_rate":0.0,"magic_rate":0.0,"crit_rate":0.0,"accuracy":0.0,"evasion":0.0,"resist":0.0,"hp_regen":0.0,"mp_regen":0.0}
	for key: String in stats.get("skills",{}):
		var id: int = int(key)
		var rank: int = int(stats["skills"][key])
		if id not in PASSIVES or rank <= 0: continue
		match id:
			90022: bonuses["attack"] += value(id,"add_phy",rank)
			90042: bonuses["max_hp"] += value(id,"add_hp_max",rank)
			90043: bonuses["evasion"] += value(id,"add_flee",rank)/1000.0
			90040: bonuses["defense"] += value(id,"add_phy_def",rank)
			90096: bonuses["hp_regen"] += value(id,"hp_grow",rank)/10.0
			90118:
				bonuses["crit_rate"] += value(id,"add_fatal",rank)/100.0
				bonuses["accuracy"] += value(id,"add_hit",rank)/1000.0
				bonuses["evasion"] += value(id,"add_evade",rank)/1000.0
			90107:
				bonuses["resist"] += value(id,"add_resist",rank)
				bonuses["hp_rate"] += value(id,"add_hp_max_rate",rank)/100.0
			90124: bonuses["magic_attack"] += value(id,"add_mag",rank)
			90125: bonuses["max_mp"] += value(id,"add_mp_max",rank)
			90097: bonuses["accuracy"] += value(id,"add_hit",rank)/1000.0
			90130: bonuses["resist"] += value(id,"add_resist",rank)
			90098: bonuses["mp_regen"] += value(id,"mp_grow",rank)/10.0
			90133:
				bonuses["defense"] += value(id,"add_def",rank)
				bonuses["hp_rate"] += value(id,"add_hp_max_rate",rank)/100.0
			90141:
				bonuses["resist"] += value(id,"add_resist",rank)
				bonuses["magic_rate"] += value(id,"add_mag_rate",rank)/100.0
				bonuses["accuracy"] += value(id,"add_hit",rank)/1000.0
				bonuses["evasion"] += value(id,"add_evade",rank)/1000.0
	return bonuses

static func describe(id: int, rank: int) -> String:
	var row: Dictionary = catalog().get(id,{})
	if row.is_empty(): return ""
	var description: String = str(DESCRIPTIONS.get(id,""))
	for key: String in row["constants"]:
		var number: float = value(id,key,maxi(1,rank))
		description = description.replace("{"+key+"}",str(int(number)) if number == floor(number) else str(number))
	if id not in PASSIVES:
		var definition: Dictionary = player_definitions()[id]
		description += " Мана: %s · Відновлення: %.1f с." % ["уся" if id == 90113 else str(definition["mp"]),float(definition["cooldown"])]
	return description
