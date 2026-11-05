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
}

const ALWAYS_VISIBLE: Array[String] = ["ArmLeft", "ArmRight", "Body", "Head", "LegLeft", "LegRight", "Head_Hooded"]

static func look_for(role: String) -> Array:
	if role.begins_with("consign_"):
		return LOOKS["consign"]
	return LOOKS.get(role, LOOKS["resident"])

## Instantiates the dressed, animated model for a role.
static func build(role: String, variant: int = 0) -> Node3D:
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
		if keep and (part.ends_with("_Body") or part.ends_with("_Cape") or part.ends_with("_Hat")):
			for s: int in mi.mesh.get_surface_count():
				var mat: BaseMaterial3D = (mi.get_active_material(s) as BaseMaterial3D)
				if mat:
					var tinted: BaseMaterial3D = mat.duplicate()
					tinted.albedo_color = tint
					mi.set_surface_override_material(s, tinted)
	model.scale = Vector3.ONE * float(look[4])
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
