class_name ItemLook
extends RefCounted

## Gives every piece of gear its own look, read from the original item name
## and id: which model (sword, greatsword, axe, dagger, wand, staff, shield
## shape, helmet, hat, circlet, crown, cape cut), its colours, its proportions,
## and its element (fire, ice, lightning, holy, shadow, blood, poison, nature,
## wind, bone, beast, arcane), which drives colour and the weapon effect
## (GearFx). Props come from all four KayKit sets and are attached to the
## hero's bones, so a knight can wear a barbarian's horned helm or a rogue's cloak.

const SOURCES: Dictionary = {
	"knight": "res://assets/characters/kaykit/Knight.glb",
	"mage": "res://assets/characters/kaykit/Mage.glb",
	"barbarian": "res://assets/characters/kaykit/Barbarian.glb",
	"rogue": "res://assets/characters/kaykit/Rogue.glb",
}
## prop name -> source set
const PROPS: Dictionary = {
	"1H_Sword": "knight", "2H_Sword": "knight", "Round_Shield": "knight", "Badge_Shield": "knight",
	"Rectangle_Shield": "knight", "Spike_Shield": "knight", "Knight_Helmet": "knight", "Knight_Cape": "knight",
	"1H_Wand": "mage", "2H_Staff": "mage", "Mage_Hat": "mage", "Mage_Cape": "mage", "Spellbook": "mage", "Spellbook_open": "mage",
	"1H_Axe": "barbarian", "2H_Axe": "barbarian", "Barbarian_Hat": "barbarian", "Barbarian_Cape": "barbarian", "Barbarian_Round_Shield": "barbarian",
	"Knife": "rogue", "Rogue_Cape": "rogue",
}

## element: [keywords], glow colour, cloth, second cloth, metal, trim
const ELEMENTS: Dictionary = {
	"fire": [["火", "炎", "焰", "红莲", "熔"], Color(1.0, 0.45, 0.12), Color("b0281e"), Color("f0a040"), Color("9a4a32"), Color("ffb040")],
	"ice": [["冰", "雪", "霜"], Color(0.55, 0.85, 1.0), Color("dceeff"), Color("5a9ad8"), Color("c8e4f8"), Color("aee4ff")],
	"lightning": [["雷", "电", "霹雳"], Color(0.7, 0.75, 1.0), Color("2c2e78"), Color("f0d850"), Color("8a90b8"), Color("fff07a")],
	"holy": [["圣", "光", "天", "审判", "裁决", "净化", "公正", "秩序", "公理", "澄净", "无垢", "神"], Color(1.0, 0.86, 0.45), Color("f4f0e4"), Color("d8b050"), Color("e8dcb8"), Color("ffe08a")],
	"shadow": [["暗", "影", "夜", "邪", "堕落", "恶魔", "鬼", "深渊", "深坑", "嫉妒", "仇恨", "背德", "卑劣", "丑恶", "欺骗", "荒谬", "苦痛", "冥", "魔"], Color(0.7, 0.35, 1.0), Color("221a30"), Color("6a2a9a"), Color("3a3448"), Color("b070ff")],
	"blood": [["血", "撕肉", "剔骨", "残酷"], Color(1.0, 0.18, 0.2), Color("5a0e14"), Color("1e1416"), Color("6a4a4a"), Color("e03040")],
	"poison": [["毒", "玷污", "腐", "枯萎"], Color(0.55, 1.0, 0.3), Color("2a3a1a"), Color("7ab040"), Color("4a5a3a"), Color("a8f060")],
	"nature": [["木", "藤", "森", "草", "荆棘", "翠"], Color(0.5, 1.0, 0.5), Color("3e6e2a"), Color("a8783a"), Color("7a6a4a"), Color("b8e070")],
	"wind": [["风", "台风"], Color(0.7, 1.0, 0.92), Color("2e8a84"), Color("e8f4f0"), Color("a8c8c4"), Color("c0fff0")],
	"bone": [["骨", "骷髅", "骸", "颚骨", "脊骨"], Color(0.7, 1.0, 0.8), Color("4a4a40"), Color("e8e0c8"), Color("d8d0b8"), Color("b8f0c8")],
	"beast": [["兽", "豺狼", "猎豹", "猛虎", "巨熊", "牙", "之拥", "之首"], Color(1.0, 0.75, 0.4), Color("6a4a2a"), Color("c8a070"), Color("7a6a5a"), Color("e0b070")],
	"arcane": [["符文", "雕文", "元素", "法力", "秘", "宝石", "水晶", "琉璃", "镶嵌", "智慧", "先知", "命运", "召唤", "理性"], Color(0.45, 0.8, 1.0), Color("2a3a7a"), Color("5ad0e0"), Color("9aa8c8"), Color("8af0ff")],
}
## Colour schemes for gear without an element, picked by item id.
const PLAIN: Array = [
	[Color("2f56b0"), Color("e8e0d0"), Color("a8b2be"), Color("c8a050")],
	[Color("7a2a2a"), Color("d8c8a0"), Color("9aa0a8"), Color("d0a040")],
	[Color("2a5a4a"), Color("e0d0a0"), Color("a0a8a8"), Color("c8b060")],
	[Color("4a3a6a"), Color("d0c8e0"), Color("b0b4c0"), Color("d8b060")],
	[Color("6a4a2a"), Color("e8d8b0"), Color("8a8a90"), Color("b08040")],
	[Color("1e2e4a"), Color("c8d0e0"), Color("c0c8d4"), Color("e0c070")],
	[Color("8a6a2a"), Color("2a2a2a"), Color("a8a8a8"), Color("f0d070")],
	[Color("3a3a3a"), Color("b02a2a"), Color("7a7e88"), Color("d0a040")],
]

static func _hash(id: int, salt: int = 0) -> float:
	var h: int = (id * 2654435761 + salt * 40503) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	return float(h % 10007) / 10007.0

static func element(item: Dictionary) -> String:
	var name: String = str(item.get("name", ""))
	if "魔法" in name:
		name = name.replace("魔法", "")   # "magic" sword/armour are arcane, not shadow
		if name.length() <= 2:
			return "arcane"
	for key: String in ELEMENTS:
		for word: String in ELEMENTS[key][0]:
			if word in name:
				return key
	return ""

static func glow_color(item: Dictionary) -> Color:
	var e: String = element(item)
	if e != "":
		return ELEMENTS[e][1]
	return GearFx.RARITY_GLOW[GearFx.tier(item)]

## Colours for one item: cloth, cloth2, metal, trim, plus glow strength.
static func colours(item: Dictionary) -> Dictionary:
	var id: int = int(item.get("id", 0))
	var e: String = element(item)
	var tier: int = GearFx.tier(item)
	var c: Dictionary
	if e != "":
		var row: Array = ELEMENTS[e]
		c = {"cloth": row[2], "cloth2": row[3], "metal": row[4], "trim": row[5], "glow_color": row[1]}
	else:
		var row: Array = PLAIN[int(_hash(id, 3) * PLAIN.size()) % PLAIN.size()]
		c = {"cloth": row[0], "cloth2": row[1], "metal": row[2], "trim": row[3], "glow_color": GearFx.RARITY_GLOW[tier]}
		var name: String = str(item.get("name", ""))
		if "秘银" in name: c["metal"] = Color("b8d4f0")
		elif "精金" in name or "金" in name: c["metal"] = Color("e0bc60")
		elif "钢" in name: c["metal"] = Color("b4bcc8")
		elif "铁" in name: c["metal"] = Color("7e8690")
	# Small per-item shift so two items of one element still differ.
	var shift: float = (_hash(id, 9) - 0.5) * 0.08
	for k: String in ["cloth", "cloth2"]:
		var col: Color = c[k]
		c[k] = Color.from_hsv(fmod(col.h + shift + 1.0, 1.0), col.s, col.v)
	c["tier"] = tier
	c["element"] = e
	return c

## Which model a weapon uses and how it is proportioned.
static func weapon_shape(item: Dictionary, mage: bool) -> Dictionary:
	var name: String = str(item.get("name", ""))
	var id: int = int(item.get("id", 0))
	var mesh: String
	if mage:
		mesh = "2H_Staff" if ("杖" in name and not "短杖" in name) or "棍" in name else "1H_Wand"
	elif "斧" in name:
		mesh = "2H_Axe" if ("巨" in name or "大" in name or "战" in name) else "1H_Axe"
	elif "重剑" in name or "巨剑" in name or "巨刃" in name or "双刃" in name or "十字剑" in name:
		mesh = "2H_Sword"
	elif "短剑" in name or "匕" in name or "牙" in name:
		mesh = "Knife"
	elif "骨" in name or "撕肉" in name:
		mesh = "1H_Axe"
	else:
		mesh = "1H_Sword"
	var length: float = lerpf(0.92, 1.22, _hash(id, 1))
	var width: float = lerpf(0.9, 1.25, _hash(id, 2))
	if "刀" in name:   # sabres: broader blade
		width *= 1.25
	if "长" in name or "阔" in name:
		length *= 1.12
	if mesh == "Knife":
		length *= 1.5
		width *= 1.3
	return {"mesh": mesh, "length": length, "width": width, "two_handed": mesh.begins_with("2H")}

static func helmet_shape(item: Dictionary, mage: bool) -> String:
	var name: String = str(item.get("name", ""))
	if "之首" in name or "军帽" in name:
		return "Barbarian_Hat"
	if "冠" in name:
		return "Mage_Hat" if mage and "法冠" in name else "crown"
	if "环" in name or "圈" in name or "头饰" in name or "面纱" in name or "妆容" in name:
		return "circlet"
	if "盔" in name:
		return "Knight_Helmet"
	return "Mage_Hat" if mage else "Knight_Helmet"

static func cape_shape(item: Dictionary, mage: bool) -> String:
	var name: String = str(item.get("name", ""))
	var tier: int = GearFx.tier(item)
	if "之拥" in name or "皮" in name:
		return "Barbarian_Cape"
	if "斗篷" in name:
		return "Rogue_Cape"
	if tier < 1 and not "袍" in name:
		return ""
	if mage:
		return "Mage_Cape" if _hash(int(item.get("id", 0)), 5) < 0.6 else "Rogue_Cape"
	return ["Knight_Cape", "Knight_Cape", "Rogue_Cape", "Barbarian_Cape"][int(_hash(int(item.get("id", 0)), 5) * 4.0) % 4]

static func shield_shape(item: Dictionary) -> String:
	var name: String = str(item.get("name", ""))
	if "刺" in name or "荆棘" in name: return "Spike_Shield"
	if "圆" in name or "木" in name: return "Round_Shield"
	if "塔" in name or "壁垒" in name: return "Rectangle_Shield"
	return ["Round_Shield", "Badge_Shield", "Rectangle_Shield", "Spike_Shield", "Barbarian_Round_Shield"][int(_hash(int(item.get("id", 0)), 7) * 5.0) % 5]

# ------------------------------------------------------------- Attaching ---

## Copies a prop (mesh + offset + bone) out of its KayKit set.
static func _prop_source(prop: String, cache: Dictionary) -> Dictionary:
	if cache.has(prop):
		return cache[prop]
	var set_name: String = PROPS.get(prop, "knight")
	var key: String = "scene:" + set_name
	if not cache.has(key):
		cache[key] = (load(SOURCES[set_name]) as PackedScene).instantiate()
	var scene: Node = cache[key]
	var mi: MeshInstance3D = scene.find_child(prop, true, false) as MeshInstance3D
	var out: Dictionary = {}
	if mi and mi.get_parent() is BoneAttachment3D:
		out = {"mesh": mi.mesh, "transform": mi.transform, "bone": (mi.get_parent() as BoneAttachment3D).bone_name, "set": set_name}
	cache[prop] = out
	return out

static func _attachment(model: Node, bone: String) -> Node3D:
	for node: Node in model.find_children("*", "BoneAttachment3D", true, false):
		if (node as BoneAttachment3D).bone_name == bone:
			return node
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	return att

static func _add_prop(model: Node, prop: String, cache: Dictionary, palette: Dictionary, scale: Vector3 = Vector3.ONE, weapon: bool = false) -> MeshInstance3D:
	var src: Dictionary = _prop_source(prop, cache)
	if src.is_empty():
		return null
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = prop
	mi.mesh = src["mesh"]
	mi.transform = src["transform"]
	mi.scale = mi.scale * scale
	mi.set_meta("item_prop", true)
	if weapon:
		mi.set_meta("item_weapon", true)
	_attachment(model, src["bone"]).add_child(mi)
	Outfit.paint(mi, src["set"], palette)
	return mi

static func _circlet(model: Node, palette: Dictionary, crown: bool, gem: Color) -> void:
	var att: Node3D = _attachment(model, "head")
	var root: Node3D = Node3D.new()
	root.name = "Circlet"
	root.set_meta("item_prop", true)
	att.add_child(root)
	root.position = Vector3(0, 0.7, 0)
	root.rotation.x = -0.12
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = palette.get("trim", Color("d8b050"))
	metal.metallic = 0.6
	metal.roughness = 0.35
	metal.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	metal.rim_enabled = true
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.56
	torus.rings = 24
	torus.ring_segments = 6
	torus.material = metal
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.6, 1.0)
	root.add_child(ring)
	if crown:
		for i: int in 7:
			var a: float = float(i) / 7.0 * TAU
			var spike: MeshInstance3D = MeshInstance3D.new()
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.06
			cone.height = 0.22 if i != 0 else 0.3
			cone.radial_segments = 4
			cone.material = metal
			spike.mesh = cone
			spike.position = Vector3(sin(a) * 0.53, 0.12, cos(a) * 0.53)
			root.add_child(spike)
	var jewel: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.07
	sph.height = 0.14
	sph.radial_segments = 8
	sph.rings = 4
	var jm: StandardMaterial3D = StandardMaterial3D.new()
	jm.albedo_color = gem
	jm.emission_enabled = true
	jm.emission = gem
	jm.emission_energy_multiplier = 1.6
	sph.material = jm
	jewel.mesh = sph
	jewel.position = Vector3(0, 0.02, 0.56)
	root.add_child(jewel)

## Replaces the base model's props with the equipped items' own looks.
## Returns {two_handed, weapon_item}.
static func equip(model: Node3D, stats: Dictionary, hero_palette: Dictionary) -> Dictionary:
	for node: Node in model.find_children("*", "", true, false):
		if node.has_meta("item_prop"):
			node.get_parent().remove_child(node)
			node.queue_free()
	var mage: bool = int(stats.get("class_id", 130001)) in HeroAvatar.MAGE_CLASSES
	var elf: bool = int(stats.get("race_id", 250001)) == 250002
	var equipment: Dictionary = stats.get("equipment", {})
	var cache: Dictionary = {}
	var result: Dictionary = {"two_handed": false}
	if equipment.has("weapon"):
		var item: Dictionary = ItemCatalog.get_item(int(equipment["weapon"]))
		var shape: Dictionary = weapon_shape(item, mage)
		var c: Dictionary = colours(item)
		var pal: Dictionary = {"metal": c["metal"].lerp(Color.WHITE, 0.15), "trim": c["trim"], "leather": c["cloth"].darkened(0.3),
			"cloth": c["cloth"], "cloth2": c["cloth2"], "gem": c["glow_color"], "weapon_metal": c["metal"].lerp(Color.WHITE, 0.15),
			"metal_glow": [0.0, 0.05, 0.25, 0.6, 1.1][c["tier"]] + (0.25 if c["element"] != "" else 0.0), "glow": 0.6}
		var w: MeshInstance3D = _add_prop(model, shape["mesh"], cache, pal, Vector3(shape["width"], shape["length"], shape["width"]), true)
		if w:
			w.set_meta("item", item)
		result["two_handed"] = shape["two_handed"] and not mage
		result["weapon_item"] = item
	if equipment.has("shield") and not result["two_handed"]:
		var sitem: Dictionary = ItemCatalog.get_item(int(equipment["shield"]))
		var sc: Dictionary = colours(sitem)
		if mage:
			_add_prop(model, "Spellbook_open" if GearFx.tier(sitem) >= 2 else "Spellbook", cache, {"cloth": sc["cloth"], "leather": sc["cloth"], "trim": sc["trim"], "glow": 0.5})
		else:
			_add_prop(model, shield_shape(sitem), cache, {"cloth": sc["cloth"], "cloth2": sc["cloth2"], "metal": sc["metal"], "trim": sc["trim"], "leather": sc["cloth"].darkened(0.4), "glow": 0.3 * sc["tier"]})
	if equipment.has("head") and not (elf and not mage and false):
		var hitem: Dictionary = ItemCatalog.get_item(int(equipment["head"]))
		var hc: Dictionary = colours(hitem)
		var hshape: String = helmet_shape(hitem, mage)
		if elf and hshape == "Knight_Helmet":
			hshape = "circlet"   # elves fight bare-headed so the face reads
		if hshape == "circlet" or hshape == "crown":
			_circlet(model, hc, hshape == "crown", hc["glow_color"])
		else:
			_add_prop(model, hshape, cache, {"cloth": hc["cloth"], "cloth2": hc["cloth2"], "metal": hc["metal"], "trim": hc["trim"], "leather": hc["cloth"].darkened(0.35), "glow": 0.25 * hc["tier"]})
	if equipment.has("body"):
		var bitem: Dictionary = ItemCatalog.get_item(int(equipment["body"]))
		var cape: String = cape_shape(bitem, mage)
		if cape != "":
			var bc: Dictionary = colours(bitem)
			_add_prop(model, cape, cache, {"cloth": bc["cloth2"] if not mage else bc["cloth"], "cloth2": bc["cloth"], "leather": bc["cloth"].darkened(0.4), "trim": bc["trim"], "metal": bc["metal"], "glow": 0.3 * bc["tier"]})
	for key: String in cache:
		if key.begins_with("scene:"):
			(cache[key] as Node).free()
	return result

## The hero's body colours from the equipped armour (element and id), layered
## over the class palette.
static func body_palette(base: Dictionary, stats: Dictionary) -> Dictionary:
	var equipment: Dictionary = stats.get("equipment", {})
	if not equipment.has("body"):
		return base
	var item: Dictionary = ItemCatalog.get_item(int(equipment["body"]))
	var c: Dictionary = colours(item)
	var p: Dictionary = base.duplicate()
	var mage: bool = int(stats.get("class_id", 130001)) in HeroAvatar.MAGE_CLASSES
	p["cloth"] = c["cloth"]
	p["cloth2"] = c["cloth2"]
	p["trim"] = c["trim"]
	if not mage:
		p["metal"] = c["metal"]
	p["glow"] = [0.0, 0.1, 0.4, 0.9, 1.5][c["tier"]] + (0.2 if c["element"] != "" else 0.0)
	if c["tier"] >= 3:
		p["pulse"] = 0.35
	if c["tier"] == 4:
		p["cloth_glow"] = 0.08
	return p
