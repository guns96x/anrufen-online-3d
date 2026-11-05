class_name HeroAvatar
extends Node

## The player's KayKit hero: picks the rigged base by class, equips a gear set
## by level tier and drives the 76 baked animations (locomotion, strikes, casts,
## dodge, hit reactions, death). Replaces the old limb-pivot CharacterMotion.

const KNIGHT: String = "res://assets/characters/kaykit/Knight.glb"
const MAGE: String = "res://assets/characters/kaykit/Mage.glb"
const MAGE_CLASSES: Array[int] = [130002, 130005, 130008, 130009]

## Visible props per gear tier (index = tier). Tier rises every 10 levels.
const KNIGHT_TIERS: Array = [
	["1H_Sword", "Round_Shield"],
	["1H_Sword", "Badge_Shield", "Knight_Helmet"],
	["1H_Sword", "Spike_Shield", "Knight_Helmet", "Knight_Cape"],
	["2H_Sword", "Knight_Helmet", "Knight_Cape"],
]
const MAGE_TIERS: Array = [
	["1H_Wand"],
	["1H_Wand", "Mage_Hat"],
	["2H_Staff", "Mage_Hat", "Mage_Cape"],
	["2H_Staff", "Mage_Hat", "Mage_Cape", "Spellbook"],
]
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
var _tier: int = -1
var _race: int = 0
var _action_left: float = 0.0
var _combo: int = 0
var _dead: bool = false

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	var stats: Dictionary = actor.stats
	var base: String = MAGE if int(stats.get("class_id", 130001)) in MAGE_CLASSES else KNIGHT
	var tier: int = clampi(int(stats.get("level", 1)) / 10, 0, 3)
	var race: int = int(stats.get("race_id", 250001))
	if base == _base and tier == _tier and race == _race:
		return
	if race != _race:
		_base = ""
	_race = race
	if base != _base:
		for child: Node in actor.visual_root.get_children():
			child.queue_free()
		model = (load(base) as PackedScene).instantiate()
		model.rotation.y = PI   # KayKit faces +Z; the player's visual faces -Z
		actor.visual_root.add_child(model)
		anim = model.find_child("AnimationPlayer", true, false)
		NewHero.dress_race(model, int(stats.get("race_id", 250001)))
		for loop: String in ["Idle", "Running_A", "Walking_A", "2H_Melee_Idle", "Blocking", "Sit_Chair_Idle", "Death_A_Pose"]:
			if anim.has_animation(loop):
				anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
		_base = base
	_tier = tier
	var props: Array = (MAGE_TIERS if base == MAGE else KNIGHT_TIERS)[tier]
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part: String = String(node.name)
		var visible_part: bool = props.has(part)
		for suffix: String in BODY:
			if part.ends_with("_" + suffix):
				visible_part = true
		(node as MeshInstance3D).visible = visible_part and not (_race == 250002 and part.ends_with("_Helmet"))

## Stand-alone dressed model for menus (equipment preview), idling.
static func preview_model(stats: Dictionary) -> Node3D:
	var mage: bool = int(stats.get("class_id", 130001)) in MAGE_CLASSES
	var model: Node3D = (load(MAGE if mage else KNIGHT) as PackedScene).instantiate()
	var props: Array = (MAGE_TIERS if mage else KNIGHT_TIERS)[clampi(int(stats.get("level", 1)) / 10, 0, 3)]
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var part: String = String(node.name)
		var keep: bool = props.has(part)
		for suffix: String in BODY:
			if part.ends_with("_" + suffix):
				keep = true
		(node as MeshInstance3D).visible = keep
	NewHero.dress_race(model, int(stats.get("race_id", 250001)))
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player and player.has_animation("Idle"):
		player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		player.play("Idle")
	return model

func _two_handed() -> bool:
	return _base == KNIGHT and _tier >= 3

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
