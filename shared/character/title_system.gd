class_name TitleSystem
extends RefCounted

# Names and IDs are recovered original title records. Class-title unlocks are
# a modern adaptation; the archive's original grant conditions are undecoded.
const CLASS_TITLES: Dictionary = {130001:180003,130002:180002,130004:180005,130005:180004}
const LABELS: Dictionary = {180003:"Воїн-початківець",180002:"Маг-початківець",180005:"Досвідчений воїн",180004:"Досвідчений маг",180049:"Невідомий шукач пригод"}
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var parser: JSON = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/original/all_title.json")) == OK and parser.data is Array:
			for row: Variant in parser.data:
				if row is Dictionary and int(row.get("id",0)) >= 180000 and int(row.get("id",0)) < 190000 and row.get("strings") is Array and not row["strings"].is_empty():
					_catalog[int(row["id"])] = str(row["strings"][0])
	return _catalog

static func ensure_stats(stats: Dictionary) -> void:
	if not stats.has("owned_titles"):
		stats["owned_titles"] = []
	if not stats.has("title_id"):
		stats["title_id"] = 0
	var class_id: Variant = stats.get("class_id",130001)
	if CLASS_TITLES.has(class_id) and stats["owned_titles"] is Array:
		var id: int = int(CLASS_TITLES[class_id])
		if id not in stats["owned_titles"]:
			stats["owned_titles"].append(id)
		if CharacterSystem._integer(stats["title_id"],0,999999) and int(stats["title_id"]) == 0:
			stats["title_id"] = id

static func select(stats: Dictionary, id: int) -> bool:
	if id != 0 and id not in stats.get("owned_titles",[]):
		return false
	stats["title_id"] = id
	return true

static func label(id: int) -> String:
	return str(LABELS.get(id,catalog().get(id,"Без титулу")))

static func validate(stats: Dictionary) -> bool:
	if not stats.get("owned_titles") is Array or stats["owned_titles"].size() > 200 or not CharacterSystem._integer(stats.get("title_id"),0,999999):
		return false
	var seen: Array[int] = []
	for value: Variant in stats["owned_titles"]:
		if not CharacterSystem._integer(value,180000,189999) or not catalog().has(int(value)) or int(value) in seen:
			return false
		seen.append(int(value))
	return int(stats["title_id"]) == 0 or int(stats["title_id"]) in seen
