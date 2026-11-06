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
var fx: GearFx

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
		if equipment.has("body") and GearFx.tier(ItemCatalog.get_item(int(equipment["body"]))) >= 1: props.append("Mage_Cape")
		if equipment.has("shield"): props.append("Spellbook")
	else:
		two_handed = "斧" in weapon_name   # 巨斧 great axes are the two-handed line
		props.append("2H_Sword" if two_handed else "1H_Sword")
		if equipment.has("shield") and not two_handed:
			props.append(SHIELDS[mini(3, GearFx.tier(ItemCatalog.get_item(int(equipment["shield"]))))])
		if equipment.has("head"): props.append("Knight_Helmet")
		if equipment.has("body") and GearFx.tier(ItemCatalog.get_item(int(equipment["body"]))) >= 1: props.append("Knight_Cape")
	var armor: int = GearFx.tier(ItemCatalog.get_item(int(equipment["body"]))) if equipment.has("body") else -1
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
	var path: String = String(model.scene_file_path)
	if path.contains("/kaykit/"):
		Outfit.paint(model, "mage" if path.ends_with("Mage.glb") else "knight", hero_palette(stats, gear))
	return gear

## Colour scheme for the hero: warrior steel and royal blue, mage burgundy and
## cream (elves: silver-lilac and lilac-white). Better armour adds a coloured,
## glowing trim; better weapons a tinted, glowing blade or staff.
const TRIM_BY_RARITY: Array[Color] = [Color("8a6a3a"), Color("c8a050"), Color("9ad0ff"), Color("c890ff"), Color("ffd060")]
const WEAPON_BY_RARITY: Array[Color] = [Color("b8c0c8"), Color("c8e0c8"), Color("a8c8ff"), Color("d0a8ff"), Color("ffe090")]
## Warrior armour plate by tier: iron, steel, blue steel, night steel, gold.
const PLATE_BY_TIER: Array[Color] = [Color("8e98a4"), Color("a8b2be"), Color("86a8d8"), Color("5e4e86"), Color("dcb456")]
## Mage robe accents by tier: cream, linen, sky, amethyst, gold.
const ROBE_ACCENT_BY_TIER: Array[Color] = [Color("d8ccb0"), Color("e8dcc0"), Color("8ac0f0"), Color("b880f0"), Color("f0c860")]
static func hero_palette(stats: Dictionary, gear: Dictionary) -> Dictionary:
	var mage: bool = int(stats.get("class_id", 130001)) in MAGE_CLASSES
	var elf: bool = int(stats.get("race_id", 250001)) == 250002
	var armor: int = clampi(int(gear.get("armor", -1)), -1, 4)
	var at: int = maxi(armor, 0)
	var p: Dictionary
	if mage and elf:
		p = {"cloth": Color("9a88dc"), "cloth2": Color("f2eeff"), "leather": Color("5a4a7a"), "metal": Color("d8e0f0"), "hair": Color("eceaf8")}
	elif mage:
		p = {"cloth": Color("8a2444"), "cloth2": Color("e8dcc0"), "leather": Color("4a2a1a"), "metal": Color("c89a5a"), "hair": Color("2a2030")}
	elif elf:
		p = {"cloth": Color("6a58b8"), "cloth2": Color("1e2448"), "leather": Color("3a3050"), "metal": Color("dce4f0"), "hair": Color("e8e6f4")}
	else:
		p = {"cloth": Color("2f56b0"), "cloth2": Color("e8e0d0"), "leather": Color("5a3a22"), "metal": Color("a8b2be"), "hair": Color("4a2e1e")}
	if elf:
		p["skin"] = Color("cdbcf2")
	if mage:
		if armor >= 2:
			p["cloth2"] = ROBE_ACCENT_BY_TIER[at]
			p["cloth_glow"] = [0.0, 0.0, 0.08, 0.18, 0.28][at]
		if not elf:
			p["cloth"] = [Color("8a2444"), Color("8a2444"), Color("1f4a96"), Color("40287a"), Color("f2e8cc")][at]
			if at == 4:
				p["cloth2"] = Color("e0b050")
				p["leather"] = Color("c89a4a")
	elif not elf or armor >= 2:
		p["metal"] = PLATE_BY_TIER[at]
	if armor >= 0:
		p["trim"] = TRIM_BY_RARITY[armor]
		p["glow"] = [0.0, 0.0, 0.35, 0.9, 1.5][armor]
		if armor >= 3:
			p["pulse"] = 0.35
	var equipment: Dictionary = stats.get("equipment", {})
	var w: int = GearFx.tier(ItemCatalog.get_item(int(equipment["weapon"]))) if equipment.has("weapon") else 0
	p["weapon_metal"] = WEAPON_BY_RARITY[w].lerp(p["metal"], 0.35 if mage else 0.0)
	p["metal_glow"] = [0.0, 0.0, 0.3, 0.7, 1.2][w]
	p["gem"] = GearFx.MAGE_ORB[w]
	return p

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
		model = (load(hero_path(stats, base)) as PackedScene).instantiate()
		model.rotation.y = PI   # KayKit faces +Z; the player's visual faces -Z
		actor.visual_root.add_child(model)
		anim = model.find_child("AnimationPlayer", true, false)
		NewHero.dress_race(model, race)
		ToonStyle.apply(model, true)
		reshape(model, stats)
		for loop: String in ["Idle", "Running_A", "Walking_A", "2H_Melee_Idle", "Blocking", "Sit_Chair_Idle", "Death_A_Pose"]:
			if anim.has_animation(loop):
				anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
		_base = base
		_race = race
	_two_handed_gear = bool(dress(model, stats)["two_handed"])
	fx = GearFx.attach(model, stats)

## A hand-made hero (assets/characters/hero/<race>_<class>_<sex>.glb) when present.
static func hero_path(stats: Dictionary, fallback: String) -> String:
	var race: String = "elf" if int(stats.get("race_id", 250001)) == 250002 else "human"
	var role: String = "mage" if int(stats.get("class_id", 130001)) in MAGE_CLASSES else "warrior"
	var path: String = "res://assets/characters/hero/%s_%s_%s.glb" % [race, role, str(stats.get("sex", "m"))]
	return path if ResourceLoader.exists(path) else fallback

## KayKit heroes get the slimmer anime proportions; hand-made models are left as built.
static func reshape(model: Node, stats: Dictionary) -> void:
	if String(model.scene_file_path).contains("/kaykit/"):
		Proportions.apply(model, "heroine" if str(stats.get("sex", "m")) == "f" else "hero")

## Stand-alone dressed model for menus (equipment preview), idling.
static func preview_model(stats: Dictionary) -> Node3D:
	var mage: bool = int(stats.get("class_id", 130001)) in MAGE_CLASSES
	var model: Node3D = (load(hero_path(stats, MAGE if mage else KNIGHT)) as PackedScene).instantiate()
	var shown: Dictionary = stats.duplicate()
	if not shown.has("equipment"):
		# Creation screen: show a starter kit so the class reads at once.
		shown["equipment"] = {"weapon": 10006 if mage else 10003, "head": 10005 if mage else 10002, "body": 10007 if mage else 10004}
	NewHero.dress_race(model, int(stats.get("race_id", 250001)))
	reshape(model, stats)
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
	if fx:
		fx.swing(0.42)

func cast() -> void:
	if not _dead:
		_one_shot("Spellcast_Shoot", 1.4)
		if fx:
			fx.swing()

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
