class_name HeroSlots
extends RefCounted

## Three hero save slots. Slot 0 keeps the original save file so existing
## profiles stay where they were; the others get their own files.

const COUNT: int = 3
static var active: int = 0

static func path(slot: int) -> String:
	return ProgressionController.DEFAULT_SAVE_PATH if slot == 0 else "user://guanlin_v2_slot%d.json" % (slot + 1)

## {name, race_id, class_id, level} of the hero in a slot, or {} when empty or unreadable.
static func summary(slot: int) -> Dictionary:
	var file: String = path(slot)
	if not FileAccess.file_exists(file):
		file += ".bak"
		if not FileAccess.file_exists(file):
			return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if not data is Dictionary or not data.get("player_stats") is Dictionary:
		return {}
	var stats: Dictionary = data["player_stats"]
	return {"name": str(stats.get("name", "Мандрівник")), "race_id": int(stats.get("race_id", 250001)),
		"class_id": int(stats.get("class_id", 130001)), "level": int(stats.get("level", 1))}

## Removes a hero; the files are kept as .deleted so a mistake can be undone by hand.
static func delete(slot: int) -> void:
	for suffix: String in ["", ".bak"]:
		var file: String = path(slot) + suffix
		if FileAccess.file_exists(file):
			var absolute: String = ProjectSettings.globalize_path(file)
			DirAccess.rename_absolute(absolute, absolute + ".deleted")
