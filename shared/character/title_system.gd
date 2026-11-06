class_name TitleSystem
extends RefCounted

# Names and IDs are recovered original title records. Class-title unlocks are
# a modern adaptation; the archive's original grant conditions are undecoded.
const CLASS_TITLES: Dictionary = {130001: 180003, 130002: 180002, 130004: 180005, 130005: 180004}

const LABELS: Dictionary = {
	180000: "Винищувач курей",
	180001: "Непереможний Схід",
	180002: "Маг-початківець",
	180003: "Воїн-початківець",
	180004: "Досвідчений маг",
	180005: "Досвідчений воїн",
	180006: "Лісовий рейнджер",
	180007: "Паладин світла",
	180008: "Священний лицар",
	180009: "Мисливець на вампірів",
	180010: "Вигнанець демонів",
	180011: "Королівський авангард",
	180012: "Мисливець на качок",
	180013: "Герой королівства",
	180014: "Малий розбишака",
	180015: "Королівський лицар",
	180016: "Лиходій",
	180017: "Бувалий воїн",
	180018: "Друг лісу",
	180019: "Охоронець лісу",
	180020: "Подих степу",
	180021: "Непохитна скеля",
	180022: "Вічні сніги",
	180023: "Барон",
	180024: "Зоря королівства",
	180025: "Цвіт королівства",
	180026: "Залізна правиця",
	180027: "Мисливець на левів",
	180028: "Аристократ",
	180029: "Пісня весни",
	180030: "Літній дощ",
	180031: "Осінній лист",
	180032: "Зимовий буран",
	180033: "Сталевий клинок",
	180034: "Приборкувач полум'я",
	180035: "Шалений вогонь",
	180036: "Грізна гора",
	180037: "Туманна десниця",
	180038: "Хмільний гульвіса",
	180039: "Шукач істини",
	180040: "Викрадач яєць",
	180041: "Вітер спогадів",
	180042: "Дух помсти",
	180043: "Щире серце",
	180044: "Кривава слава",
	180045: "Захисник гномів",
	180046: "Шинкарський завсідник",
	180047: "Головний землемір",
	180048: "Щасливчик",
	180049: "Невідомий шукач пригод",
	180050: "Авантюрист",
	180051: "Хранитель персня",
	180052: "Хірургічний скальпель",
	180053: "Ловець блукаючих вогнів",
	180054: "Слідопит Чорної Вдови",
	180055: "Промінь надії",
	180056: "Вартовий храму",
	180057: "Передзвін дзвіночків",
	180058: "Цукеркова гармата",
	180059: "Імбирний принц",
	180060: "Володар супутників",
	180061: "Володар індиків",
	180062: "Бульбяний десант",
	180063: "Ласун на перекусі",
	180064: "Зимовий Дід",
	180065: "Різдвяна зоря",
	180066: "Хмільний знавець",
	180067: "Мудрий розвідник",
	180068: "Кмітливий писар",
	180069: "Герой легенд",
	180070: "Юний новачок",
	180071: "Сивий мудрець",
	180072: "Титан світла",
	180073: "Мандрівник у часі",
	180074: "Брат стихій",
	180075: "Темний володар",
	180076: "Друг звірят",
	180077: "Забрьоха",
	180078: "Чемпіон арени",
	180079: "Срібний призер",
	180080: "Бронзовий призер",
	180081: "Триразовий тріумфатор",
	180082: "Чарівна піснярка",
	180083: "Повелитель дракончиків",
	180084: "Пряничний лицар",
	180085: "Зоряний лицар",
	180086: "Синій гном",
	180087: "Підступний чаклун",
	180088: "Глава ордену",
	180089: "Червона шапочка",
	180090: "Добрий дядечко",
	180091: "Королева півночі",
	180092: "Сльозливець",
	180093: "Буркотун",
	180094: "Всезнайко",
	180095: "Чхач",
	180096: "Дрімота",
	180097: "Сором'язливий",
	180098: "Плутаник",
	180099: "Вітрогон",
	180100: "Похмурий",
	180101: "Простодушний",
	180102: "Хитрий дотепник",
	180103: "Духовний аватар",
	180104: "Влучний стрілець",
	180105: "Бурхлива хвиля",
	180106: "Володар тисячі битв",
	180107: "Мудрець сувоїв",
	180108: "Придорожній листок",
	180109: "Коваль-чарівник",
	180110: "Бідний мандрівник",
	180111: "Морський вовк",
	180112: "Великий літописець",
	180113: "Вершитель доль",
	180114: "Добродій",
	180115: "Владика земель",
	180116: "Відблиск на воді",
	180117: "Паросток лотоса",
	180118: "Дерево на вітрі",
	180119: "Тінь місяця",
	180120: "Лезо вітру",
	180121: "Проклятий",
	180122: "Перша кров",
	180123: "Невблаганний жнець",
	180124: "Невдаха!",
	180125: "Горе-воїн!",
	180126: "Бідолаха",
	180127: "Вісник невдач",
	180128: "Нищівний шквал",
	180129: "Першовідкривач",
	180130: "Піонер фронтиру",
	180131: "Шукач пригод",
	180132: "Той, хто благає",
	180133: "Божественний каратель",
	180134: "Доброчесний лицар",
	180135: "Нещасний",
	180136: "Знедолений",
	10000001: "Таємничий знак",
}

const ZH_TO_UK: Dictionary = {
	"杀鸡专业户": "Винищувач курей",
	"东方不败": "Непереможний Схід",
	"新手法师": "Маг-початківець",
	"新手战士": "Воїн-початківець",
	"进阶法师": "Досвідчений маг",
	"进阶战士": "Досвідчений воїн",
	"巡林客": "Лісовий рейнджер",
	"聖武士": "Паладин світла",
	"吸血鬼猎人": "Мисливець на вампірів",
	"除魔者": "Вигнанець демонів",
	"皇家先锋": "Королівський авангард",
	"屠鸭专业户": "Мисливець на качок",
	"王国英雄": "Герой королівства",
	"小坏蛋": "Малий розбишака",
	"皇家骑士": "Королівський лицар",
	"反面角色": "Лиходій",
	"老手": "Бувалий воїн",
	"森林之友": "Друг лісу",
	"森林守护者": "Охоронець лісу",
	"草原之风": "Подих степу",
	"不动如山": "Непохитна скеля",
	"万年雪": "Вічні сніги",
	"男爵": "Барон",
	"王国之星": "Зоря королівства",
	"王国之花": "Цвіт королівства",
	"铁腕": "Залізна правиця",
	"狮子猎人": "Мисливець на левів",
	"贵族": "Аристократ",
	"春之歌": "Пісня весни",
	"夏之雨": "Літній дощ",
	"秋之叶": "Осінній лист",
	"冬之风": "Зимовий буран",
	"钢刀": "Сталевий клинок",
	"驭火者": "Приборкувач полум'я",
	"奔烈如火": "Шалений вогонь",
	"动如山": "Грізна гора",
	"雾之手": "Туманна десниця",
	"烂醉如泥": "Хмільний гульвіса",
	"真相缔造者": "Шукач істини",
	"偷蛋者": "Викрадач яєць",
	"回忆之风": "Вітер спогадів",
	"复仇之魂": "Дух помсти",
	"赤子之心": "Щире серце",
	"血之荣耀": "Кривава слава",
	"侏儒护卫者": "Захисник гномів",
	"酒徒": "Шинкарський завсідник",
	"首席勘测员": "Головний землемір",
	"祝你好运": "Щасливчик",
	"无名的冒险者": "Невідомий шукач пригод",
	"冒险家": "Авантюрист",
	"护戒使者": "Хранитель персня",
	"手术刀": "Хірургічний скальпель",
	"鬼火狩猎者": "Ловець блукаючих вогнів",
	"寡妇追迹者": "Слідопит Чорної Вдови",
	"希望之光": "Промінь надії",
	"神殿尖兵": "Вартовий храму",
	"铃儿响叮当": "Передзвін дзвіночків",
	"糖果大炮": "Цукеркова гармата",
	"姜饼亲王": "Імбирний принц",
	"泡沫国王": "Володар супутників",
	"火鸡DAI王": "Володар індиків",
	"土豆突击队": "Бульбяний десант",
	"我想食热狗": "Ласун на перекусі",
	"圣诞老人": "Зимовий Дід",
	"圣诞之星": "Різдвяна зоря",
	"酒虫": "Хмільний знавець",
	"睿智的情报官": "Мудрий розвідник",
	"智慧的书记官": "Кмітливий писар",
	"勇者-伪": "Герой легенд",
	"新手-伪": "Юний новачок",
	"贤者-伪": "Сивий мудрець",
	"奥特曼-伪": "Титан світла",
	"克赛-伪": "Мандрівник у часі",
	"葫芦娃-伪": "Брат стихій",
	"大魔王-伪": "Темний володар",
	"小怪兽-伪": "Друг звірят",
	"小邋遢-伪": "Забрьоха",
	"冠军-伪": "Чемпіон арени",
	"亚军-伪": "Срібний призер",
	"季军-伪": "Бронзовий призер",
	"三冠王-伪": "Триразовий тріумфатор",
	"歌姬-伪": "Чарівна піснярка",
	"小龙人-伪": "Повелитель дракончиків",
	"姜饼人-伪": "Пряничний лицар",
	"圣斗士-伪": "Зоряний лицар",
	"蓝精灵-伪": "Синій гном",
	"格格巫-伪": "Підступний чаклун",
	"教主-伪": "Глава ордену",
	"小红帽-伪": "Червона шапочка",
	"舅舅-伪": "Добрий дядечко",
	"女王-伪": "Королева півночі",
	"爱哭鬼-伪": "Сльозливець",
	"爱生气-伪": "Буркотун",
	"万事通-伪": "Всезнайко",
	"喷嚏精-伪": "Чхач",
	"瞌睡虫-伪": "Дрімота",
	"害羞鬼-伪": "Сором'язливий",
	"糊涂蛋-伪": "Плутаник",
	"没头脑-伪": "Вітрогон",
	"不高兴-伪": "Похмурий",
	"天然呆-伪": "Простодушний",
	"阿凡提-伪": "Хитрий дотепник",
	"阿凡达-伪": "Духовний аватар",
	"神射手-伪": "Влучний стрілець",
	"千尺浪": "Бурхлива хвиля",
	"千人斩-伪": "Володар тисячі битв",
	"万卷书": "Мудрець сувоїв",
	"路旁叶": "Придорожній листок",
	"神匠-伪": "Коваль-чарівник",
	"穷鬼-伪": "Бідний мандрівник",
	"海贼王-伪": "Морський вовк",
	"大文豪-伪": "Великий літописець",
	"终结者-伪": "Вершитель доль",
	"好人-伪": "Добродій",
	"王者-伪": "Владика земель",
	"水面影": "Відблиск на воді",
	"尖角荷": "Паросток лотоса",
	"临风树": "Дерево на вітрі",
	"揽月影": "Тінь місяця",
	"刃如风": "Лезо вітру",
	"受诅咒者": "Проклятий",
	"第一滴血": "Перша кров",
	"杀人如麻": "Невблаганний жнець",
	"杯具！": "Невдаха!",
	"餐具！": "Горе-воїн!",
	"大茶几": "Бідолаха",
	"衰神": "Вісник невдач",
	"望风披靡": "Нищівний шквал",
	"探索者-伪": "Першовідкривач",
	"开拓者-伪": "Піонер фронтиру",
	"追寻者-伪": "Шукач пригод",
	"祈愿者-伪": "Той, хто благає",
	"神之杀戮": "Божественний каратель",
	"仁者无敌": "Доброчесний лицар",
	"不幸的人": "Нещасний",
	"苦命的人": "Знедолений",
}

static var _catalog: Dictionary = {}
static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/titles_rules.json")) == OK and parser.data is Dictionary:
			for key: Variant in parser.data:
				var entry: Variant = parser.data[key]
				if entry is Dictionary:
					var id: int = int(entry.get("id", int(str(key))))
					_rules[id] = entry
	return _rules

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/original/all_title.json")) == OK and parser.data is Array:
			for row: Variant in parser.data:
				if row is Dictionary:
					var id: int = int(row.get("id", 0))
					if (id >= 180000 and id < 190000) or id == 10000001:
						var s: Array = row.get("strings", [])
						_catalog[id] = str(s[0]) if not s.is_empty() else str(LABELS.get(id, ""))
	return _catalog

static func ensure_stats(stats: Dictionary) -> void:
	if not stats.has("owned_titles") or not stats["owned_titles"] is Array:
		stats["owned_titles"] = []
	if not stats.has("titles") or not stats["titles"] is Array:
		stats["titles"] = stats["owned_titles"]
	else:
		for t: Variant in stats["titles"]:
			if int(t) not in stats["owned_titles"]:
				stats["owned_titles"].append(int(t))
		for t: Variant in stats["owned_titles"]:
			if int(t) not in stats["titles"]:
				stats["titles"].append(int(t))
	if not stats.has("title_id"):
		stats["title_id"] = 0
	if not stats.has("kill_counts") or not stats["kill_counts"] is Dictionary:
		stats["kill_counts"] = {}
	if not stats.has("pk_kills"):
		stats["pk_kills"] = 0
	var class_id: Variant = stats.get("class_id", 130001)
	if CLASS_TITLES.has(class_id) and stats["owned_titles"] is Array:
		var id: int = int(CLASS_TITLES[class_id])
		if id not in stats["owned_titles"]:
			stats["owned_titles"].append(id)
		if id not in stats["titles"]:
			stats["titles"].append(id)
		if CharacterSystem._integer(stats["title_id"], 0, 999999) and int(stats["title_id"]) == 0:
			stats["title_id"] = id

static func select(stats: Dictionary, id: int) -> bool:
	if id != 0 and id not in stats.get("owned_titles", []):
		return false
	stats["title_id"] = id
	return true

static func label(id: int) -> String:
	return str(LABELS.get(id, catalog().get(id, "Без титулу")))

static func translate_name(name_zh: String) -> String:
	return str(ZH_TO_UK.get(name_zh, name_zh))

static func check_unlocks(stats: Dictionary) -> Array[int]:
	ensure_stats(stats)
	return _check_unlocks_internal(stats)

static func _check_unlocks_internal(stats: Dictionary) -> Array[int]:
	var rmap: Dictionary = rules()
	var newly_earned: Array[int] = []
	var owned: Array = stats["owned_titles"]
	var level: int = int(stats.get("level", 1))
	var class_id: int = int(stats.get("class_id", 130001))
	var copper: int = int(stats.get("copper", 0))
	var pk_kills: int = int(stats.get("pk_kills", 0))
	var kill_counts: Dictionary = stats.get("kill_counts", {})
	var pet_count: int = _evaluate_pet_count(stats)

	for id: int in rmap:
		if id in owned:
			continue
		var rule: Dictionary = rmap[id]
		var cond: Dictionary = rule.get("condition", {})
		var cond_type: String = str(cond.get("type", ""))
		var unlocked: bool = false
		match cond_type:
			"level":
				unlocked = level >= int(cond.get("value", 1))
			"class_level":
				var req_class: int = int(cond.get("class_id", 0))
				var req_lv: int = int(cond.get("value", 1))
				unlocked = _matches_class(class_id, req_class) and level >= req_lv
			"kills":
				var monster: String = str(cond.get("monster", ""))
				var req_kills: int = int(cond.get("value", 1))
				var actual_kills: int = _get_kills(kill_counts, monster)
				unlocked = actual_kills >= req_kills
			"quest":
				var qid: int = int(cond.get("id", 0))
				unlocked = _has_completed_quest(stats, qid)
			"pk_kills":
				unlocked = pk_kills >= int(cond.get("value", 1))
			"pet_count":
				unlocked = pet_count >= int(cond.get("value", 1))
			"copper":
				unlocked = copper >= int(cond.get("value", 0))
			"manual":
				unlocked = false
			_:
				unlocked = false

		if unlocked:
			owned.append(id)
			if id not in stats["titles"]:
				stats["titles"].append(id)
			newly_earned.append(id)

	return newly_earned

static func bonuses(stats: Dictionary) -> Dictionary:
	var active_id: int = int(stats.get("title_id", 0))
	if active_id == 0:
		return {}
	var rmap: Dictionary = rules()
	if rmap.has(active_id):
		return rmap[active_id].get("bonuses", {}).duplicate()
	return {}

static func record_kill(stats: Dictionary, monster_type: Variant) -> void:
	ensure_stats(stats)
	var type_str: String = str(monster_type).strip_edges().to_lower()
	if type_str in ["player", "pk", "pk_player"]:
		stats["pk_kills"] = int(stats.get("pk_kills", 0)) + 1
	else:
		stats["kill_counts"][type_str] = int(stats["kill_counts"].get(type_str, 0)) + 1
		if monster_type is int:
			stats["kill_counts"][monster_type] = stats["kill_counts"][type_str]
		_sync_kill_aliases(stats["kill_counts"], type_str)
	check_unlocks(stats)

static func validate(stats: Dictionary) -> bool:
	if not stats.get("owned_titles") is Array or stats["owned_titles"].size() > 200 or not CharacterSystem._integer(stats.get("title_id"), 0, 10000001):
		return false
	var seen: Array[int] = []
	for value: Variant in stats["owned_titles"]:
		var id_int: int = int(value)
		if not CharacterSystem._integer(value, 180000, 189999) and id_int != 10000001:
			return false
		if not catalog().has(id_int) and not rules().has(id_int):
			return false
		if id_int in seen:
			return false
		seen.append(id_int)
	return int(stats["title_id"]) == 0 or int(stats["title_id"]) in seen

static func _matches_class(actual_class: int, required_class: int) -> bool:
	if actual_class == required_class:
		return true
	# Check warrior progressions
	if required_class == 130001:
		return actual_class in [130001, 130004, 130006, 130007]
	if required_class == 130004:
		return actual_class in [130004, 130006, 130007]
	# Check mage progressions
	if required_class == 130002:
		return actual_class in [130002, 130005, 130008, 130009]
	if required_class == 130005:
		return actual_class in [130005, 130008, 130009]
	return false

static func _get_kills(kill_counts: Dictionary, monster: String) -> int:
	var m_lower: String = monster.to_lower()
	var total: int = int(kill_counts.get(m_lower, kill_counts.get(monster, 0)))
	# Check known aliases
	match m_lower:
		"chicken":
			total = maxi(total, int(kill_counts.get("70365", kill_counts.get(70365, 0))))
		"duck":
			total = maxi(total, int(kill_counts.get("70078", kill_counts.get(70078, 0))))
		"boar":
			total = maxi(total, int(kill_counts.get("70073", kill_counts.get(70073, 0))))
		"spider":
			total = maxi(total, int(kill_counts.get("70076", kill_counts.get(70076, 0))))
	return total

static func _sync_kill_aliases(kill_counts: Dictionary, key: String) -> void:
	var aliases: Array[String] = []
	if key in ["chicken", "70365"]:
		aliases = ["chicken", "70365"]
	elif key in ["duck", "70078"]:
		aliases = ["duck", "70078"]
	elif key in ["boar", "wild_boar", "70073"]:
		aliases = ["boar", "wild_boar", "70073"]
	elif key in ["spider", "70076"]:
		aliases = ["spider", "70076"]
	elif key in ["vampire", "70068", "70109", "70112"]:
		aliases = ["vampire"]
	elif key in ["demon", "70093", "70094", "70095"]:
		aliases = ["demon"]
	var mx: int = 0
	for a: String in aliases:
		mx = maxi(mx, int(kill_counts.get(a, 0)))
	for a: String in aliases:
		kill_counts[a] = mx

static func _has_completed_quest(stats: Dictionary, quest_id: int) -> bool:
	if stats.get("completed_quests") is Array:
		if quest_id in stats["completed_quests"] or str(quest_id) in stats["completed_quests"]:
			return true
	if stats.get("completed_rewards") is Array:
		if quest_id in stats["completed_rewards"] or str(quest_id) in stats["completed_rewards"]:
			return true
	if stats.get("quests") is Dictionary:
		var q: Variant = stats["quests"].get(str(quest_id), stats["quests"].get(quest_id))
		if q is Dictionary and int(q.get("state", 0)) == QuestData.QuestState.DONE:
			return true
		if q is int and q == QuestData.QuestState.DONE:
			return true
	if stats.get("quest_states") is Dictionary:
		var s: Variant = stats["quest_states"].get(quest_id, stats["quest_states"].get(str(quest_id)))
		if int(s) == QuestData.QuestState.DONE:
			return true
	if stats.get("journal") is Dictionary and stats["journal"].get("quests") is Dictionary:
		var jq: Variant = stats["journal"]["quests"].get(str(quest_id), stats["journal"]["quests"].get(quest_id))
		if jq is Dictionary and int(jq.get("state", 0)) == QuestData.QuestState.DONE:
			return true
	return false

static func _evaluate_pet_count(stats: Dictionary) -> int:
	if stats.has("pet_count"):
		return int(stats["pet_count"])
	if stats.get("pets") is Array:
		return stats["pets"].size()
	if stats.get("pets") is Dictionary:
		return stats["pets"].size()
	if stats.get("owned_pets") is Array:
		return stats["owned_pets"].size()
	return 0
