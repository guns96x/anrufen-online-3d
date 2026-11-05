class_name HeroAvatar
extends Node

## The player's KayKit hero: picks the rigged base by class, shows the gear that
## is actually equipped (weapon, shield, helmet, cape, armour tint) and drives the 76 baked animations (locomotion, strikes, casts,
## dodge, hit reactions, death). Replaces the old limb-pivot CharacterMotion.

const KNIGHT: String = "res://assets/characters/kaykit/Knight.glb"
const MAGE: String = "res://assets/characters/kaykit/Mage.glb"
const MAGE_CLASSES: Array[int] = [130002, 130005, 130008, 130009]

## Shield art by item rarity (MenuSkin.rarity): plain, badge, kite, spiked.
const SHIELDS: Array[String] = ["Round_Shield", "Badge_Shield", "Rectangle_Shield", "Spike_Shield"]
## Body tint by rarity so a better chest piece reads at a glance.
const ARMOR_TINT: Array[Color] = [Color(1, 1, 1), Color(0.82, 1.0, 0.82), Color(0.78, 0.88, 1.15), Color(0.95, 0.8, 1.15), Color(1.15, 0.95, 0.65)]
const BODY: Array[String] = ["ArmLeft", "ArmRight", "Body", "Head", "LegLeft", "LegRight"]
const STRIKES_1H: Array[String] = ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Stab"]
const STRIKES_2H: Array[String] = ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Chop", "2H_Melee_Attack_Spin"]

var actor: Player
var model: Node3D
var anim: AnimationPlayer
var strike_left: float = 0.0:
	set(value):
		strike_left = value
		if value > 0.0:
			strike()

var _base: String = ""
var _signature: String = ""
var _two_handed_gear: bool = false
var _race: int = 0
var _action_left: float = 0.0
var _combo: int = 0
var _dead: bool = false

func _ready() -> void:
	_rebuild()

## Visible props for what is actually equipped (ItemCatalog slots).
static func gear_props(stats: Dictionary) -> Dictionary:
	var mage: bool = int(stats.get("class_id", 130001)) in MAGE_CLASSES
	var equipment: Dictionary = stats.get("equipment", {})
	var props: Array[String] = []
	var two_handed: bool = false
	var weapon: Dictionary = ItemCatalog.get_item(int(equipment.get("weapon", 0))) if equipment.has("weapon") else {}
	var weapon_name: String = str(weapon.get("name", ""))
	if mage:
		props.append("2H_Staff" if "杖" in weapon_name else "1H_Wand")
		if equipment.has("head"): props.append("Mage_Hat")
		if equipment.has("body") and MenuSkin.rarity(ItemCatalog.get_item(int(equipment["body"]))) >= 1: props.append("Mage_Cape")
		if equipment.has("shield"): props.append("Spellbook")
	else:
		two_handed = "斧" in weapon_name   # 巨斧 great axes are the two-handed line
		props.append("2H_Sword" if two_handed else "1H_Sword")
		if equipment.has("shield") and not two_handed:
			props.append(SHIELDS[mini(3, MenuSkin.rarity(ItemCatalog.get_item(int(equipment["shield"]))))])
		if equipment.has("head"): props.append("Knight_Helmet")
		if equipment.has("body") and MenuSkin.rarity(ItemCatalog.get_item(int(equipment["body"]))) >= 1: props.append("Knight_Cape")
	var armor: int = MenuSkin.rarity(ItemCatalog.get_item(int(equipment["body"]))) if equipment.has("body") else -1
	return {"props": props, "two_handed": two_handed, "armor": armor}

## Shows the equipped pieces on a KayKit model and tints the body by armour rarity.
static func dress(model: Node3D, stats: Dictionary) -> Dictionary:
	var gear: Dictionary = gear_props(stats)
	var race: int = int(stats.get("race_id", 250001))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var part: String = String(mi.name)
		var keep: bool = gear["props"].has(part)
		for suffix: String in BODY:
			if part.ends_with("_" + suffix):
				keep = true
		mi.visible = keep and not (race == 250002 and part.ends_with("_Helmet"))
		if part.ends_with("_Body"):
			for s: int in mi.mesh.get_surface_count():
				var base_mat: BaseMaterial3D = mi.mesh.surface_get_material(s) as BaseMaterial3D
				if base_mat == null:
					continue
				if int(gear["armor"]) <= 0:
					mi.set_surface_override_material(s, null)
				else:
					var tinted: BaseMaterial3D = base_mat.duplicate()
					tinted.albedo_color = ARMOR_TINT[int(gear["armor"])]
					mi.set_surface_override_material(s, tinted)
	return gear

func _rebuild() -> void:
	var stats: Dictionary = actor.stats
	var base: String = MAGE if int(stats.get("class_id", 130001)) in MAGE_CLASSES else KNIGHT
	var race: int = int(stats.get("race_id", 250001))
	var signature: String = "%s|%d|%s" % [base, race, JSON.stringify(stats.get("equipment", {}))]
	if signature == _signature:
		return
	_signature = signature
	if base != _base or race != _race:
		for child: Node in actor.visual_root.get_children():
			child.queue_free()
		model = (load(base) as PackedScene).instantiate()
		model.rotation.y = PI   # KayKit faces +Z; the player's visual faces -Z
		actor.visual_root.add_child(model)
		anim = model.find_child("AnimationPlayer", true, false)
		NewHero.dress_race(model, race)
		ToonStyle.apply(model, true)
		for loop: String in ["Idle", "Running_A", "Walking_A", "2H_Melee_Idle", "Blocking", "Sit_Chair_Idle", "Death_A_Pose"]:
			if anim.has_animation(loop):
				anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
		_base = base
		_race = race
	_two_handed_gear = bool(dress(model, stats)["two_handed"])

## Stand-alone dressed model for menus (equipment preview), idling.
static func preview_model(stats: Dictionary) -> Node3D:
	var mage: bool = int(stats.get("class_id", 130001)) in MAGE_CLASSES
	var model: Node3D = (load(MAGE if mage else KNIGHT) as PackedScene).instantiate()
	var shown: Dictionary = stats.duplicate()
	if not shown.has("equipment"):
		# Creation screen: show a starter kit so the class reads at once.
		shown["equipment"] = {"weapon": 10006 if mage else 10003, "head": 10005 if mage else 10002, "body": 10007 if mage else 10004}
	NewHero.dress_race(model, int(stats.get("race_id", 250001)))
	dress(model, shown)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player and player.has_animation("Idle"):
		player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")
	return model

func _two_handed() -> bool:
	return _base == KNIGHT and _two_handed_gear

func _play(name: String, blend: float = 0.12, speed: float = 1.0) -> void:
	if anim and anim.has_animation(name) and anim.current_animation != name:
		anim.play(name, blend, speed)

func _one_shot(name: String, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(name):
		return
	anim.play(name, 0.08, speed)
	anim.seek(0.0, true)
	_action_left = anim.get_animation(name).length / speed * 0.85

func strike() -> void:
	if _dead:
		return
	var pool: Array[String] = STRIKES_2H if _two_handed() else STRIKES_1H
	if _base == MAGE:
		pool = ["Spellcast_Shoot"]
	_one_shot(pool[_combo % pool.size()], 1.6)
	_combo += 1

func cast() -> void:
	if not _dead:
		_one_shot("Spellcast_Shoot", 1.4)

func dodge() -> void:
	if not _dead:
		_one_shot("Dodge_Forward", 1.5)

func hurt() -> void:
	if not _dead and _action_left <= 0.0:
		_one_shot("Hit_A", 1.4)

func die() -> void:
	_dead = true
	_one_shot("Death_A", 1.0)

func revive() -> void:
	_dead = false
	_action_left = 0.0
	_play("Idle", 0.05)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or anim == null:
		return
	if Engine.get_process_frames() % 30 == 0:
		_rebuild()
	if _dead:
		if _action_left > 0.0:
			_action_left -= delta
		else:
			_play("Death_A_Pose", 0.0)
		return
	if _action_left > 0.0:
		_action_left -= delta
		return
	if actor.stats.get("mounted", false):
		_play("Sit_Chair_Idle")
		return
	var speed: float = Vector2(actor.velocity.x, actor.velocity.z).length()
	if speed > 3.2:
		_play("Running_A", 0.15, clampf(speed / 6.0, 0.8, 1.3))
	elif speed > 0.3:
		_play("Walking_A", 0.15)
	elif _two_handed() and actor.time_since_combat < 6.0:
		_play("2H_Melee_Idle")
	else:
		_play("Idle", 0.2)
