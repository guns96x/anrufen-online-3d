class_name NewHero
extends RefCounted

## Hand-off from the main menu's hero creation to the town: the chosen name,
## race and class are applied when the town binds the player, replacing the
## saved profile (kept as a backup), and the town then plays its intro.

static var pending: Dictionary = {}
static var play_intro: bool = false

const RACES: Dictionary = {250001: "Людина", 250002: "Нічний ельф"}
const STARTER_CLASSES: Array[int] = [130001, 130002]
## Night elves: lavender skin and silver hair tint on the KayKit head and hands.
const ELF_SKIN: Color = Color(0.6, 0.48, 0.98)

static func begin(hero_name: String, race_id: int, class_id: int, slot: int = HeroSlots.active) -> void:
	HeroSlots.active = slot
	pending = {"name": hero_name, "race_id": race_id, "class_id": class_id}
	play_intro = true

## Applies a pending hero to fresh stats; returns true when it did.
static func apply(stats: Dictionary, save_path: String) -> bool:
	if pending.is_empty():
		return false
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".previous"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	stats["name"] = str(pending["name"])
	if int(pending["class_id"]) != int(stats.get("class_id", 130001)) or int(pending["race_id"]) != int(stats.get("race_id", 250001)):
		CharacterSystem.choose_class(stats, int(pending["class_id"]), int(pending["race_id"]))
	pending = {}
	return true

## Tints skin parts of a KayKit model for the given race.
static func dress_race(model: Node, race_id: int) -> void:
	if race_id != 250002:
		return
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var part: String = String(mi.name)
		if part.ends_with("_Helmet"):
			mi.visible = false   # elves fight bare-headed so the lavender face reads
		if part.ends_with("_Head") or part.ends_with("_ArmLeft") or part.ends_with("_ArmRight"):
			for s: int in mi.mesh.get_surface_count():
				var mat: BaseMaterial3D = mi.get_active_material(s) as BaseMaterial3D
				if mat:
					var tinted: BaseMaterial3D = mat.duplicate()
					tinted.albedo_color = ELF_SKIN
					mi.set_surface_override_material(s, tinted)
