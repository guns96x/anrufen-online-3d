class_name DataManager
extends RefCounted

static var quests: Dictionary = {}
static var monsters: Dictionary = {}
static var scenes: Dictionary = {}
static var classes: Dictionary = {}
static var is_loaded: bool = false

static func load_all_data() -> void:
	if is_loaded:
		return
	quests = _load_json("res://data/quests.json")
	monsters = _load_json("res://data/monsters.json")
	scenes = _load_json("res://data/scenes.json")
	classes = _load_json("res://data/classes.json")
	is_loaded = true
	print("[DataManager] Successfully loaded game data: %d quests, %d monsters, %d scenes" % [quests.size(), monsters.size(), scenes.size()])

static func _load_json(file_path: String) -> Dictionary:
	var result: Dictionary = {}
	if not FileAccess.file_exists(file_path):
		push_warning("[DataManager] File does not exist: %s" % file_path)
		return result
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] Failed to open: %s" % file_path)
		return result
	var text = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(text)
	if err != OK:
		push_error("[DataManager] JSON Parse error in %s: %s" % [file_path, json.get_error_message()])
		return result
	var data = json.get_data()
	if typeof(data) == TYPE_ARRAY:
		for item in data:
			if typeof(item) == TYPE_DICTIONARY and item.has("id"):
				result[item["id"]] = item
	return result

static func get_quest(quest_id: int) -> Dictionary:
	return quests.get(quest_id, {})

static func get_monster(monster_id: int) -> Dictionary:
	return monsters.get(monster_id, {})
