class_name CitizenLook
extends RefCounted

## Guanlin citizens dressed from the CC0 KayKit adventurers: one of five rigged
## bases, the props each role carries, tinted clothing and an idle animation.
## Roles come from GuanlinLayout.CITIZENS.

const BASES: Dictionary = {
	"knight": "res://assets/characters/kaykit/Knight.glb",
	"mage": "res://assets/characters/kaykit/Mage.glb",
	"barbarian": "res://assets/characters/kaykit/Barbarian.glb",
	"rogue": "res://assets/characters/kaykit/Rogue.glb",
	"hooded": "res://assets/characters/kaykit/Rogue_Hooded.glb",
}

## role -> [base, visible props, clothing tint, idle animation, scale]
const LOOKS: Dictionary = {
	"mayor": ["mage", ["Spellbook"], Color("e0b64a"), "Idle", 1.0],
	"tribune": ["knight", ["Knight_Cape"], Color("7a4fa0"), "Idle", 1.0],
	"ranger": ["hooded", ["Rogue_Cape", "1H_Crossbow"], Color("5f8a3c"), "1H_Ranged_Aiming", 1.0],
	"militia_captain": ["knight", ["Knight_Helmet", "Knight_Cape", "1H_Sword", "Round_Shield"], Color("b33a2e"), "Blocking", 1.0],
	"gourmand": ["barbarian", ["Mug"], Color("c98a4a"), "Idle", 1.12],
	"widow_anna": ["hooded", ["Rogue_Cape"], Color("4a4a58"), "Idle", 0.95],
	"smuggler": ["rogue", ["Rogue_Cape", "Knife"], Color("3c3f47"), "Idle", 1.0],
	"madman": ["barbarian", ["Barbarian_Hat"], Color("8c6a8a"), "Cheer", 1.0],
	"madmans_wife": ["hooded", [], Color("8a5a3c"), "Idle", 0.95],
	"tom": ["rogue", [], Color("4a7ab0"), "Idle", 0.72],
	"jessie": ["mage", [], Color("d07090"), "Cheer", 0.7],
	"alchemist": ["mage", ["Mage_Hat", "Mage_Cape", "Spellbook_open"], Color("3c8a7a"), "Spellcasting", 1.0],
	"breeder": ["barbarian", [], Color("6a9a4a"), "Interact", 1.0],
	"doctor_jack": ["mage", ["Mage_Cape"], Color("e8e8e0"), "Idle", 1.0],
	"jeweller": ["mage", ["Mage_Cape"], Color("2f8f9a"), "Idle", 0.96],
	"beast_tamer": ["barbarian", ["Barbarian_Hat", "Barbarian_Cape"], Color("8a5a2a"), "Idle", 1.0],
	"weapon_merchant": ["barbarian", ["1H_Axe"], Color("5a5048"), "Idle", 1.05],
	"armor_merchant": ["knight", ["Rectangle_Shield"], Color("6a7a8a"), "Idle", 1.0],
	"item_merchant": ["rogue", ["Rogue_Cape"], Color("b07a3a"), "Interact", 1.0],
	"accessory_merchant": ["mage", ["Mage_Cape"], Color("c86a9a"), "Idle", 0.95],
	"resident": ["rogue", [], Color("8a7a5a"), "Idle", 1.0],
	"stable_master": ["barbarian", ["Barbarian_Hat"], Color("7a5a3a"), "Idle", 1.0],
	"mystery_merchant": ["hooded", ["Rogue_Cape"], Color("4a2f6a"), "Idle", 1.0],
	"arena_steward": ["knight", ["Knight_Helmet", "Knight_Cape", "2H_Sword"], Color("c9a23a"), "2H_Melee_Idle", 1.05],
	"consign": ["rogue", ["Rogue_Cape"], Color("2f5aa0"), "Idle", 1.0],
	"viper_bandit": ["rogue", ["Rogue_Cape", "Knife", "Knife_Offhand"], Color("7a1f1f"), "Idle", 1.0],
	"viper_brute": ["barbarian", ["Barbarian_Cape", "1H_Axe", "Barbarian_Round_Shield"], Color("4a1414"), "Idle", 1.1],
}

const ALWAYS_VISIBLE: Array[String] = ["ArmLeft", "ArmRight", "Body", "Head", "LegLeft", "LegRight", "Head_Hooded"]

## Each named citizen's own colour scheme (Outfit): main and second cloth,
## leather, metal, gold trim, hair and skin. Unlisted keys keep KayKit colours.
const PALETTES: Dictionary = {
	"mayor": {"cloth": Color("5e2a86"), "cloth2": Color("e8c25a"), "leather": Color("4a2e1a"), "metal": Color("d9b45a"), "trim": Color("f2d27a"), "glow": 0.25, "hair": Color("cfcfcf")},
	"tribune": {"cloth": Color("7a4fa0"), "cloth2": Color("2e2a4a"), "metal": Color("b8c0cc"), "trim": Color("e8c25a"), "hair": Color("3a2a20")},
	"ranger": {"cloth": Color("3f6e2e"), "cloth2": Color("a8743a"), "leather": Color("6a4a2a"), "metal": Color("6a7078"), "hair": Color("b8462a")},
	"militia_captain": {"cloth": Color("b33a2e"), "cloth2": Color("ece4d4"), "metal": Color("8f9aa8"), "trim": Color("e8c25a"), "hair": Color("2a2420")},
	"gourmand": {"cloth": Color("d0923a"), "cloth2": Color("7a3a2a"), "leather": Color("8a5a30"), "hair": Color("6a3a20"), "skin": Color("f0a888")},
	"widow_anna": {"cloth": Color("2c2a3a"), "cloth2": Color("6a5a7a"), "leather": Color("3a2a2a"), "hair": Color("1a1418"), "skin": Color("f4d8c8")},
	"smuggler": {"cloth": Color("3c3f47"), "cloth2": Color("8a2a2a"), "leather": Color("4a3020"), "metal": Color("5a5e66"), "hair": Color("202020"), "skin": Color("c8906a")},
	"madman": {"cloth": Color("8c6a8a"), "cloth2": Color("4a8a5a"), "leather": Color("6a4a3a"), "hair": Color("ecead8")},
	"madmans_wife": {"cloth": Color("9a5a3c"), "cloth2": Color("d8c090"), "hair": Color("8a4a2a")},
	"tom": {"cloth": Color("4a7ab0"), "cloth2": Color("d0a860"), "hair": Color("e0b860")},
	"jessie": {"cloth": Color("e07898"), "cloth2": Color("f4e4a8"), "hair": Color("e8903a")},
	"alchemist": {"cloth": Color("2f8a7a"), "cloth2": Color("c8e05a"), "leather": Color("5a3a2a"), "trim": Color("7af0d0"), "glow": 0.8, "pulse": 0.4, "hair": Color("4a2a5a")},
	"breeder": {"cloth": Color("6a9a4a"), "cloth2": Color("c8a060"), "hair": Color("7a5030"), "skin": Color("d8a070")},
	"doctor_jack": {"cloth": Color("eeeee6"), "cloth2": Color("3a6ab0"), "metal": Color("c0c8d0"), "hair": Color("707070")},
	"jeweller": {"cloth": Color("2f8f9a"), "cloth2": Color("e8c25a"), "metal": Color("ecd490"), "trim": Color("f4e48a"), "glow": 0.6, "hair": Color("141014"), "skin": Color("f2cca8")},
	"beast_tamer": {"cloth": Color("8a5a2a"), "cloth2": Color("3a2a1a"), "leather": Color("5a3a1a"), "hair": Color("2a1a10"), "skin": Color("a86a48")},
	"weapon_merchant": {"cloth": Color("5a5048"), "cloth2": Color("9a3a1a"), "metal": Color("8a9098"), "hair": Color("3a2a20"), "skin": Color("c08060")},
	"armor_merchant": {"cloth": Color("3a4a6a"), "cloth2": Color("aab4c0"), "metal": Color("b4bcc8"), "hair": Color("8a7a6a")},
	"item_merchant": {"cloth": Color("b07a3a"), "cloth2": Color("3a6a8a"), "hair": Color("5a3a20")},
	"accessory_merchant": {"cloth": Color("c86a9a"), "cloth2": Color("f4d4e4"), "trim": Color("f4c4dc"), "glow": 0.4, "hair": Color("2a1830")},
	"stable_master": {"cloth": Color("7a5a3a"), "cloth2": Color("c8b080"), "hair": Color("9a7a50")},
	"mystery_merchant": {"cloth": Color("2a1a4a"), "cloth2": Color("6a3aa0"), "trim": Color("b080ff"), "glow": 1.2, "pulse": 0.5, "cloth_glow": 0.05, "hair": Color("c8c8e8")},
	"arena_steward": {"cloth": Color("c9a23a"), "cloth2": Color("6a1a1a"), "metal": Color("e8d080"), "trim": Color("fff0a0"), "glow": 0.5, "hair": Color("1a1a1a")},
	"viper_bandit": {"cloth": Color("26262a"), "cloth2": Color("8a1f1f"), "leather": Color("3a2418"), "metal": Color("4a4a50"), "hair": Color("1a1a1a"), "skin": Color("d0a080")},
	"viper_brute": {"cloth": Color("4a1414"), "cloth2": Color("2a2a2a"), "leather": Color("3a2418"), "metal": Color("3a3a40"), "hair": Color("5a2a1a"), "skin": Color("b07a58")},
}
## Townsfolk without a name get one of these, picked by their variant number.
const FOLK: Array[Dictionary] = [
	{"cloth": Color("8a6a4a"), "cloth2": Color("d8c8a0"), "hair": Color("4a3020")},
	{"cloth": Color("4a6a8a"), "cloth2": Color("c8b890"), "hair": Color("1a1a1a"), "skin": Color("d8a880")},
	{"cloth": Color("7a3a3a"), "cloth2": Color("e0d0b0"), "hair": Color("b07030")},
	{"cloth": Color("5a7a4a"), "cloth2": Color("a88a5a"), "hair": Color("6a6a6a")},
	{"cloth": Color("6a4a7a"), "cloth2": Color("e8d8c0"), "hair": Color("3a2010"), "skin": Color("a87050")},
	{"cloth": Color("a87a3a"), "cloth2": Color("4a3a2a"), "hair": Color("d8c070")},
	{"cloth": Color("3a5a5a"), "cloth2": Color("c0a080"), "hair": Color("2a1a1a"), "skin": Color("f0c8a8")},
	{"cloth": Color("9a5a6a"), "cloth2": Color("f0e0c8"), "hair": Color("5a3020")},
]

static func palette_for(role: String, variant: int, tint: Color) -> Dictionary:
	if PALETTES.has(role):
		return PALETTES[role]
	if role.begins_with("consign_"):
		var c: Dictionary = FOLK[(variant + role.length()) % FOLK.size()].duplicate()
		c["cloth"] = tint
		return c
	if role == "resident":
		return FOLK[variant % FOLK.size()]
	return {"cloth": tint, "cloth2": tint.lightened(0.5)}

## Body type for the anime proportions pass (Proportions.LOOK).
const BODIES: Dictionary = {
	"widow_anna": "woman", "madmans_wife": "woman", "accessory_merchant": "woman", "jeweller": "woman",
	"alchemist": "woman", "consign_jewelry": "woman", "consign_gems": "woman",
	"gourmand": "brute", "viper_brute": "brute", "weapon_merchant": "brute", "beast_tamer": "brute",
	"breeder": "brute", "stable_master": "brute", "madman": "brute",
	"tom": "child", "jessie": "child",
}

static func body_for(role: String) -> String:
	return BODIES.get(role, "man")

static func look_for(role: String) -> Array:
	if role.begins_with("consign_"):
		return LOOKS["consign"]
	return LOOKS.get(role, LOOKS["resident"])

## Hand-made cast models (docs/model-handoff-codex.md) take priority over KayKit.
static func cast_model(role: String, variant: int = 0) -> Node3D:
	var candidates: Array[String] = ["res://assets/characters/cast/%s.glb" % role]
	if role.begins_with("consign_"):
		candidates.push_front("res://assets/characters/cast/consign_%d.glb" % (["consign_gems","consign_weapons","consign_armor","consign_jewelry","consign_beasts","consign_goods"].find(role) + 1))
	if role == "resident":
		candidates.push_front("res://assets/characters/cast/resident_%d.glb" % (variant % 4 + 1))
	for path: String in candidates:
		if ResourceLoader.exists(path):
			var model: Node3D = (load(path) as PackedScene).instantiate()
			model.rotation.y = PI
			ToonStyle.apply(model, true)
			var anim: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
			if anim:
				var idle: String = "Idle_Character" if anim.has_animation("Idle_Character") else "Idle"
				if anim.has_animation(idle):
					anim.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
					anim.play(idle)
					anim.seek(randf() * anim.get_animation(idle).length, true)
			return model
	return null

## Instantiates the dressed, animated model for a role.
static func build(role: String, variant: int = 0) -> Node3D:
	var custom: Node3D = cast_model(role, variant)
	if custom:
		return custom
	var look: Array = look_for(role)
	var model: Node3D = (load(BASES[look[0]]) as PackedScene).instantiate()
	var props: Array = look[1]
	var tint: Color = look[2]
	if variant > 0:
		tint = tint.lerp(Color.from_hsv(fmod(0.13 * variant, 1.0), 0.45, 0.65), 0.55)
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var part: String = String(mi.name)
		var keep: bool = props.has(part)
		for suffix: String in ALWAYS_VISIBLE:
			if part.ends_with("_" + suffix):
				keep = true
		mi.visible = keep
	if not Outfit.paint(model, look[0], palette_for(role, variant, tint)):
		ToonStyle.apply(model, true)
	CharacterMerge.merge(model)
	Proportions.apply(model, body_for(role))
	model.scale = Vector3.ONE * float(look[4])
	model.rotation.y = PI   # KayKit faces +Z; NPC visuals face -Z toward the player
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if player:
		var idle: String = look[3]
		if not player.has_animation(idle):
			idle = "Idle"
		var anim: Animation = player.get_animation(idle)
		anim.loop_mode = Animation.LOOP_LINEAR
		player.play(idle)
		player.seek(randf() * anim.length, true)
		player.speed_scale = randf_range(0.9, 1.1)
	return model

## A simple post-box for the mailbox citizen (人类信箱).
static func mailbox() -> Node3D:
	var root: Node3D = Node3D.new()
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/village/T_WoodTrim_BaseColor.png")
	var red: StandardMaterial3D = StandardMaterial3D.new()
	red.albedo_color = Color("9a2a22")
	red.roughness = 0.45
	var post: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.18, 1.1, 0.18)
	pm.material = wood
	post.mesh = pm
	post.position.y = 0.55
	root.add_child(post)
	var box: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.6, 0.55, 0.45)
	bm.material = red
	box.mesh = bm
	box.position.y = 1.35
	root.add_child(box)
	var lid: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.3
	cm.bottom_radius = 0.3
	cm.height = 0.45
	cm.material = red
	lid.mesh = cm
	lid.rotation.x = PI / 2.0
	lid.scale = Vector3(1, 1, 0.5)
	lid.position.y = 1.62
	root.add_child(lid)
	return root
