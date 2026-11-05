class_name QuestData
extends RefCounted

## Source-backed quest definitions and metadata extracted from original Anrufen files:
## private/A000BA0E/all_task.godat, all_citizen.godat, and data/quests.json.
##
## Opening narrative from verified text. Prerequisite graph is an adaptation:
## 80004 -> 80591 -> 80552 -> 80005
## While 80005 is ACTIVE, 3 independent witness investigation quests unlock:
## 80006 (Gourmand / Bandits 70071)
## 80010 (Smuggler / Boars 70073)
## 80012 (Widow Anna / Spiders 70076)
## 80005 becomes READY once all 3 reports are collected and player level >= 8.
## Note: Fabricated 80003 jackal forging quest has been removed from the source chain.

enum QuestState {
	LOCKED = 0,     ## Prerequisites not met
	AVAILABLE = 1,  ## Can be accepted from NPC (!)
	ACTIVE = 2,     ## In progress
	READY = 3,      ## Objectives completed, ready to turn in (?)
	DONE = 4        ## Completed and reward claimed
}

## Verified Citizen (NPC) IDs from all_citizen.godat
const NPC_MAYOR_ID: int = 50164       # 观林镇镇长 (Mayor of Guanlin Town / Староста Ґуаньліня)
const NPC_WEAPONSMITH_ID: int = 50179 # 武器商人（人类）(Weaponsmith / Торговець зброєю)
const NPC_MILITIA_ID: int = 50166     # 民兵队长 (Militia Captain / Капітан ополчення)
const NPC_GOURMAND_ID: int = 50167    # 馋鬼 (Gourmand / Ласун)
const NPC_ANNA_ID: int = 50168        # 寡妇安娜 (Widow Anna / Вдова Анна)
const NPC_SMUGGLER_ID: int = 50169    # 走私者 (Smuggler / Контрабандист)

## Verified Monster IDs from all_monster.godat / monsters.json
const MONSTER_BANDIT_ID: int = 70071  # 毒蛇帮路匪 (Viper Gang Bandit Lv.2)
const MONSTER_BOAR_ID: int = 70073    # 野猪 (Wild Boar Lv.1)
const MONSTER_SPIDER_ID: int = 70076  # 蜘蛛 (Forest Spider Lv.2)

## Verified Item Identifiers
const ITEM_LONGSWORD_ID: int = 10010 # data/equipment.json: 长剑 (Довгий меч)

## Provisional modern tuning constants (prices/rewards not claimed as binary extraction)
const PROVISIONAL_SWORD_PRICE_COPPER: int = 200 # Source equipment10010 buy-price field.
const PROVISIONAL_INITIAL_COPPER: int = 100

## Full dictionary of source-backed quest definitions.
const DEFINITIONS: Dictionary = {
	80004: {
		"id": 80004,
		"title_zh": "欢迎来到观林镇",
		"title_uk": "Ласкаво просимо до Ґуаньліня",
		"title": "Welcome to Guanlin Town! (欢迎来到观林镇)",
		"giver_id": NPC_MAYOR_ID,
		"giver_name": "Mayor of Guanlin (观林镇镇长)",
		"turnin_id": NPC_WEAPONSMITH_ID,
		"turnin_name": "Weaponsmith (武器商人)",
		"prerequisites": [],
		"min_level": 1,
		"targets": [],
		"target_name": "Weaponsmith (武器商人)",
		"required": 1,
		"exp": 45,
		"copper": 300,
		"attack_bonus": 0,
		"locked_text": "Староста зайнятий справами містечка.",
		"offer_text": "Ти ще не зовсім знайомий із нашими торговцями! Зробімо так: вирушай до торговця зброєю на східній площі та познайомся з ним, а я заплачу тобі за клопіт!",
		"decline_text": "Ех, нинішня молодь... зовсім не хоче допомогти рідному місту.",
		"progress_text": "Знайди торговця зброєю на східному боці площі.",
		"ready_text": "Ти прийшов від старости? Радий знайомству! Купити в мене добрий клинок — не проблема.",
		"done_text": "Ти познайомився з торговцем зброєю.",
	},
	80591: {
		"id": 80591,
		"title_zh": "买回长剑",
		"title_uk": "Купити довгий меч",
		"title": "Buy Longsword for Mayor (买回长剑)",
		"giver_id": NPC_WEAPONSMITH_ID,
		"giver_name": "Weaponsmith (武器商人)",
		"turnin_id": NPC_MAYOR_ID,
		"turnin_name": "Mayor of Guanlin (观林镇镇长)",
		"prerequisites": [80004],
		"min_level": 1,
		"targets": [],
		"required_item": ITEM_LONGSWORD_ID,
		"item_price": PROVISIONAL_SWORD_PRICE_COPPER,
		"target_name": "Mayor of Guanlin (观林镇镇长)",
		"required": 1,
		"exp": 45,
		"copper": 600,
		"attack_bonus": 0,
		"locked_text": "Спочатку познайомся з торговцем за дорученням старости.",
		"offer_text": "Поговори зі мною та вибери покупку, щоб знайти довгий меч. Купи його за 200 міді й віднеси старості!",
		"decline_text": "Як знаєш, але староста чекає на цю зброю.",
		"progress_text": "Придбай довгий меч (200 міді) у торговця зброєю та віднеси старості.",
		"ready_text": "Щиро дякую тобі, юначе! Клинок відмінної ковки. Ось твоя винагорода за допомогу.",
		"done_text": "Староста задоволений якістю викуваного меча.",
	},
	80552: {
		"id": 80552,
		"title_zh": "民兵队长",
		"title_uk": "До капітана ополчення",
		"title": "Report to Militia Captain (民兵队长)",
		"giver_id": NPC_MAYOR_ID,
		"giver_name": "Mayor of Guanlin (观林镇镇长)",
		"turnin_id": NPC_MILITIA_ID,
		"turnin_name": "Militia Captain (民兵队长)",
		"prerequisites": [80591],
		"min_level": 1,
		"targets": [],
		"target_name": "Militia Captain (民兵队长)",
		"required": 1,
		"exp": 60,
		"copper": 70,
		"attack_bonus": 0,
		"locked_text": "Староста довіряє це завдання лише тим, хто довів свою надійність.",
		"offer_text": "Я чув, що мій капітан ополчення зараз у великій скруті через тривожні події в лісі. Вирушай на тренувальний майданчик і допоможи йому!",
		"decline_text": "Шкода, ополченню зараз дуже потрібні відважні бійці.",
		"progress_text": "Капітан ополчення на тренувальному плацу в західній частині містечка.",
		"ready_text": "Ти прийшов від старости? Якраз вчасно! У нас тут надзвичайно складна справа в лісі...",
		"done_text": "Капітан ополчення радий бачити нового помічника.",
	},
	80005: {
		"id": 80005,
		"title_zh": "不安的树林",
		"title_uk": "Неспокійний ліс: Розслідування",
		"title": "The Restless Forest (不安的树林)",
		"giver_id": NPC_MILITIA_ID,
		"giver_name": "Militia Captain (民兵队长)",
		"turnin_id": NPC_MILITIA_ID,
		"turnin_name": "Militia Captain (民兵队长)",
		"prerequisites": [80552],
		"min_level": 8,    # Verified requirement from quests.json: "你需要达到8级才能完成任务"
		"witness_quests": [80006, 80010, 80012],
		"targets": [],
		"target_name": "Militia Captain (民兵队长)",
		"required": 3,     # 3 witness reports
		"exp": 180,
		"copper": 180,
		"attack_bonus": 0,
		"locked_text": "Спочатку доповідай капітану ополчення про прибуття.",
		"offer_text": "У південному лісі щось коїться: колись безпечні хащі тепер сповнені смертельної небезпеки. Жителі міста — Ласун, Вдова Анна та Контрабандист — зустріли там монстрів. Збери у кожного з них свідчення, отримай 3 звіти та досягни 8-го рівня, щоб ополчення могло вимагати допомоги у гарнізону!",
		"decline_text": "Місто не виживе без безпечного лісу, подумай ще раз.",
		"progress_text": "Збери всі 3 звіти у свідків (Ласун, Вдова Анна, Контрабандист) та досягни 8-го рівня!",
		"ready_text": "Чудова служба! Усі три звіти зібрано, і ти досяг 8-го рівня загартування. Тепер у нас є повна картина загрози!",
		"done_text": "Звіти свідків передано до ополчення, розслідування завершено.",
	},
	80006: {
		"id": 80006,
		"title_zh": "毒蛇入侵a",
		"title_uk": "Вторгнення Гадюк",
		"title": "Viper Gang Invasion (毒蛇入侵a)",
		"giver_id": NPC_GOURMAND_ID,
		"giver_name": "Gourmand (馋鬼)",
		"turnin_id": NPC_GOURMAND_ID,
		"turnin_name": "Gourmand (馋鬼)",
		"prerequisites": [80005], # Active parent quest prerequisite
		"min_level": 1,
		"targets": [MONSTER_BANDIT_ID],
		"target_name": "Viper Gang Bandits (毒蛇帮路匪)",
		"required": 10,    # Verified count from quests.json: 杀死10名毒蛇帮路匪
		"exp": 150,
		"copper": 150,
		"attack_bonus": 0,
		"report_name": "馋鬼的报告书",
		"locked_text": "Ласун скаржиться лише тим, хто розслідує справи за дорученням ополчення.",
		"offer_text": "Розбійники з банди Гадюки напали на мене в сонячному лісі та пограбували: забрали геть усі мої смаколики! Вони геть знахабніли! Знищ 10 бандитів Гадючої банди, і я напишу для тебе звіт про їхнє лігво!",
		"decline_text": "Ох, мої бідні закуски... невже ніхто їх не покарає?",
		"progress_text": "Бандити Гадюки все ще рискають лісом. Знищ 10 розбійників і повертайся!",
		"ready_text": "Чудово зроблено! Ти помстився за мої закуски, а в лісі стало трохи безпечніше. Ось мій звіт свідка для капітана ополчення!",
		"done_text": "Ласун ситий і задоволений, його звіт передано.",
	},
	80010: {
		"id": 80010,
		"title_zh": "野猪的骚扰",
		"title_uk": "Навала диких вепрів",
		"title": "Boar Harassment (野猪的骚扰)",
		"giver_id": NPC_SMUGGLER_ID,
		"giver_name": "Smuggler (走私者)",
		"turnin_id": NPC_SMUGGLER_ID,
		"turnin_name": "Smuggler (走私者)",
		"prerequisites": [80005], # Active parent quest prerequisite
		"min_level": 1,
		"targets": [MONSTER_BOAR_ID],
		"target_name": "Wild Boars (野猪)",
		"required": 10,    # Verified count from quests.json: 杀死10只野猪
		"exp": 120,
		"copper": 140,
		"attack_bonus": 0,
		"report_name": "走私者的报告书",
		"locked_text": "Контрабандист не розмовляє з незнайомцями без причини.",
		"offer_text": "Ці кляті вепри немов збожеволіли: вони розірвали мій вантаж на південній дорозі! Я ненавиджу мати справу з владою, але якщо ти знищиш 10 диких вепрів, які зривають мій заробіток, я так і бути напишу для ополчення звіт!",
		"decline_text": "Ну й біжи, а я знайду іншого помічника.",
		"progress_text": "Ці дурні тварини все ще розривають дорогу. Знищ 10 вепрів!",
		"ready_text": "Непогана робота! Хе-хе, ось твій звіт для капітана ополчення і трохи міді за допомогу.",
		"done_text": "Контрабандист передав свій звіт про лісові шляхи.",
	},
	80012: {
		"id": 80012,
		"title_zh": "遍地蛛网a",
		"title_uk": "Павутиння в хащах",
		"title": "Spider Webs Everywhere (遍地蛛网a)",
		"giver_id": NPC_ANNA_ID,
		"giver_name": "Widow Anna (寡妇安娜)",
		"turnin_id": NPC_ANNA_ID,
		"turnin_name": "Widow Anna (寡妇安娜)",
		"prerequisites": [80005], # Active parent quest prerequisite
		"min_level": 1,
		"targets": [MONSTER_SPIDER_ID],
		"target_name": "Forest Spiders (蜘蛛)",
		"required": 10,    # Verified count from quests.json: 杀死10只蜘蛛
		"exp": 220,
		"copper": 170,
		"attack_bonus": 0,
		"report_name": "寡妇安娜的报告书",
		"locked_text": "Вдова Анна у глибокій скорботі і поки не готова говорити.",
		"offer_text": "Який ще звіт?! Ми з чоловіком збирали гриби в північному лісі, коли на нас напали ці мерзенні павуки... і мій чоловік загинув! У мене немає сил писати звіти, доки кривдники живі. Знищ 10 лісових павуків, відомсти за мого чоловіка, і тоді я напишу звіт для ополчення!",
		"decline_text": "Благаю, хтось має відомстити за нього...",
		"progress_text": "Я все ще бачу цих отруйних потвор у снах. Знищ 10 лісових павуків!",
		"ready_text": "Дякую тобі від усього серця! Тепер душа мого чоловіка знайде спокій. Щоб інші люди більше не переживали такого горя, ось мій детальний звіт для капітана ополчення.",
		"done_text": "Вдова Анна передала свій звіт про небезпеку в лісі.",
	},
	80007: {
		"id":80007,"title_zh":"野味火锅-猪骨浓汤","title_uk":"Лісова юшка: кістковий бульйон",
		"giver_id":NPC_GOURMAND_ID,"turnin_id":NPC_GOURMAND_ID,"prerequisites":[80006],
		"min_level":1,"targets":[],"required_items":{"30037":10},"required":10,"exp":110,"copper":120,"attack_bonus":0,
		"offer_text":"Я давно мрію зварити юшку з лісової дичини, та бракує складників. Ти ж мені допоможеш? Щедрої платні не обіцяю, зате поділюся стравою. Для початку принеси десять кісток із ніг вепра — без них доброго бульйону не буде.",
		"progress_text":"Збери 10 кісток із ніг вепрів у Сонячному лісі й принеси Ласуну.",
		"ready_text":"Які чудові кістки! Поглянь на цей червоний мозок! Я починаю варити бульйон, а ти продовжуй збирати складники.",
		"done_text":"Ласун уже варить бульйон.","locked_text":"Спочатку допоможи Ласуну позбутися розбійників.",
	},
	80008: {
		"id":80008,"title_zh":"野味火锅-蜘蛛腿肉","title_uk":"Лісова юшка: м'ясо павуків",
		"giver_id":NPC_GOURMAND_ID,"turnin_id":NPC_GOURMAND_ID,"prerequisites":[80007],
		"min_level":1,"targets":[],"required_items":{"30038":10},"required":10,"exp":270,"copper":200,"attack_bonus":0,
		"offer_text":"Найніжніше лісове м'ясо має не чотири ноги, а вісім — воно у павуків! Ти й не уявляєш, яке воно смачне в юшці. Принеси мені десять шматків м'яса з павучих ніг.",
		"progress_text":"Збери 10 шматків м'яса з павучих ніг і принеси Ласуну.",
		"ready_text":"Чудово! Залишилося додати трохи дикої зелені — і можна їсти.",
		"done_text":"М'ясо для юшки зібрано.","locked_text":"Спочатку приготуй із Ласуном бульйон.",
	},
	80009: {
		"id":80009,"title_zh":"野味火锅-野菜","title_uk":"Лісова юшка: дика зелень",
		"giver_id":NPC_GOURMAND_ID,"turnin_id":NPC_GOURMAND_ID,"prerequisites":[80008],
		"min_level":1,"targets":[],"required_items":{"30039":5},"required":5,"exp":330,"copper":230,"attack_bonus":0,
		"offer_text":"Основні складники вже готові. Мерщій збери трохи дикої зелені — і відразу все зваримо!",
		"progress_text":"Знайди в Сонячному лісі 5 порцій дикої зелені для Ласуна. Біля смачних рослин часто бродять небезпечні звірі.",
		"ready_text":"До столу! Юшка готова!",
		"done_text":"Ти поділив із Ласуном лісову юшку.","locked_text":"Спочатку принеси м'ясо павуків.",
	},
}

## Helper mapping for legacy prototype quest IDs (80001, 80002, 80003)
## mapped to source quest IDs for NPCs placed in guanlin_town.tscn.
const DEMO_QUEST_MAP: Dictionary = {
	80001: 80004, # Mayor starts 80004
	80002: 80552, # Captain starts 80552 -> 80005
	80003: 80591  # Weaponsmith starts 80591
}

## Returns the source quest definition by ID (or mapped legacy ID).
static func get_definition(quest_id: int) -> Dictionary:
	if DEFINITIONS.has(quest_id):
		return DEFINITIONS[quest_id]
	if DEMO_QUEST_MAP.has(quest_id):
		var mapped_id: int = DEMO_QUEST_MAP[quest_id]
		if DEFINITIONS.has(mapped_id):
			return DEFINITIONS[mapped_id]
	return {}

## Returns all defined quest IDs in progression order.
static func get_ordered_quest_ids() -> Array[int]:
	return [80004, 80591, 80552, 80005, 80006, 80010, 80012, 80007, 80008, 80009]

const LEGACY_IDS: Array[int] = [80004,80591,80552,80005,80006,80010,80012]
const REPORT_ITEMS: Dictionary = {80006:30000,80010:30031,80012:30027}
