class_name Outfit
extends RefCounted

## Per-character colour schemes for the KayKit swatch atlases (outfit.gdshader).
## Every swatch is classed once by hand below (S skin, H hair, D eyes/black,
## M metal, L leather, C main cloth, c second cloth, T gold trim, X untouched),
## so a palette can recolour cloth, leather, metal, trim and hair separately.

const SHADER: Shader = preload("res://client/shaders/outfit.gdshader")

const TABLES: Dictionary = {
	"knight": "SHDMMLLMCMMMTLLMMMCLMMMMXXXXXXXX",
	"mage": "SHDMMLLLCCcMMLLCMccLMMGSXXXXXXXX",
	"rogue": "SHDMMLLLCCMMMLLLXCcLLLLMXXXXXXXX",
	"hooded": "SHDMMLLLCCMMMLLLXCcLLLLMXXXXXXXX",
	"barbarian": "SHDMMLLLCCMMMLLMMTCLMMMMXXXXXXXX",
}
## Centre colour of each swatch (sRGB hex), sampled from the atlases.
const CENTRES: Dictionary = {
	"knight": "f6c09c daae7d 13191b 818c91 4a5155 b16f52 9b5a45 818c91 d3252a c0cacd 818c91 818c91 eac253 9b5a45 6b5c53 4a5155 c0cacd 978f86 d3252a 9b5a45 978f86 978f86 8e8e8d 8e8e8d",
	"mage": "f6c09c 1b191b 13191b 818c91 818c91 b45829 9b5a45 6b5c53 484471 484471 a41a5a 818c91 4a5155 9b5a45 6b5c53 2b294b d4dbde a41a5a 2f6c73 9b5a45 978f86 978f86 55b66a f6c09c",
	"rogue": "f6c09c 9b5a45 13191b 818c91 4a5155 b16f52 9b5a45 6b5c53 096253 008353 818c91 818c91 4a5155 b16f52 9b5a45 9b5a45 e7cdb4 008353 55b66a b16f52 9b5a45 9b5a45 6b5c53 8e8e8d",
	"hooded": "f6c09c 9b5a45 13191b 818c91 4a5155 b16f52 9b5a45 6b5c53 096253 008353 818c91 818c91 4a5155 b16f52 9b5a45 9b5a45 e7cdb4 008353 55b66a b16f52 9b5a45 9b5a45 6b5c53 8e8e8d",
	"barbarian": "f6c09c 978f86 13191b 818c91 4a5155 b16f52 9b5a45 6b5c53 4d6c82 4d6c82 d4dbde 818c91 978f86 9b5a45 6b5c53 978f86 d4dbde d09745 4d6c82 6b5c53 978f86 978f86 8e8e8d 978f86",
}
## The swatch whose brightness maps to the palette colour, per category; the
## others keep their relative light/dark against it.
const REFERENCE: Dictionary = {"C": "main", "c": "second", "L": "9b5a45", "M": "818c91", "T": "eac253", "H": "hair"}
const KEYS: Dictionary = {"C": "cloth", "c": "cloth2", "L": "leather", "M": "metal", "T": "trim", "H": "hair", "S": "skin", "G": "gem"}
const WEAPONS: Array[String] = ["1H_Sword", "2H_Sword", "1H_Wand", "2H_Staff", "1H_Axe", "2H_Axe", "1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable"]

static func _lum(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return maxf(0.02, l.r * 0.2126 + l.g * 0.7152 + l.b * 0.0722)

## Builds the 8x4 remap texture for one atlas and palette.
## palette keys: cloth, cloth2, leather, metal, trim, hair (Color); glow (trim
## emission 0..2), metal_glow (emission on metal swatches, used for weapons).
static func remap_texture(base: String, palette: Dictionary, weapon: bool = false) -> ImageTexture:
	var table: String = TABLES.get(base, TABLES["rogue"])
	var centres: PackedStringArray = CENTRES.get(base, CENTRES["rogue"]).split(" ")
	var main_ref: float = 0.0
	var second_ref: float = 0.0
	for i: int in table.length():
		if table[i] == "C" and main_ref == 0.0:
			main_ref = _lum(Color(centres[i]))
		if table[i] == "c" and second_ref == 0.0:
			second_ref = _lum(Color(centres[i]))
	var img: Image = Image.create(8, 4, false, Image.FORMAT_RGBAF)
	for i: int in 32:
		var cat: String = table[i]
		var px: Color = Color(0, 0, 0, 0)
		if KEYS.has(cat) and palette.has(KEYS[cat]):
			var colour: Color = palette[KEYS[cat]]
			if cat == "M" and weapon and palette.has("weapon_metal"):
				colour = palette["weapon_metal"]
			var target: Color = colour.srgb_to_linear()
			var ref: float
			match cat:
				"C": ref = main_ref
				"c": ref = second_ref if second_ref > 0.0 else main_ref
				"H", "S", "G": ref = _lum(Color(centres[i]))
				_: ref = _lum(Color(REFERENCE[cat]))
			var k: float = 1.0 / ref
			px = Color(target.r * k, target.g * k, target.b * k, 1.0)
			if cat == "G":
				px.a += 1.2
			if cat == "T":
				px.a += float(palette.get("glow", 0.0))
			if cat == "M" and weapon:
				px.a += float(palette.get("metal_glow", 0.0))
			if (cat == "C" or cat == "c") and not weapon:
				px.a += float(palette.get("cloth_glow", 0.0))
		img.set_pixel(i % 8, i / 8, px)
	return ImageTexture.create_from_image(img)

static func _material(albedo: Texture2D, remap: Texture2D, outline: bool, sheen: float, pulse: float) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo_tex", albedo)
	mat.set_shader_parameter("remap", remap)
	mat.set_shader_parameter("sheen", sheen)
	mat.set_shader_parameter("pulse", pulse)
	mat.set_meta("toon", true)
	if outline:
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = ToonStyle.OUTLINE_COLOR
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = 0.018
		mat.next_pass = ink
	return mat

## Recolours every atlas mesh of a KayKit model. Returns false when the model
## has no atlas (hand-made models keep their own look).
static func paint(model: Node, base: String, palette: Dictionary) -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	var body_remap: ImageTexture = remap_texture(base, palette)
	var weapon_remap: ImageTexture = remap_texture(base, palette, true)
	var cache: Dictionary = {}
	var painted: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh == null:
			continue
		var weapon: bool = WEAPONS.has(String(mi.name))
		for s: int in mi.mesh.get_surface_count():
			var src: BaseMaterial3D = mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null or src.albedo_texture == null:
				continue
			var key: String = "%s|%s" % [src.albedo_texture.resource_path, weapon]
			if not cache.has(key):
				cache[key] = _material(src.albedo_texture, weapon_remap if weapon else body_remap, not weapon,
					0.8 if weapon else 0.0, 0.35 if weapon else float(palette.get("pulse", 0.0)))
			mi.set_surface_override_material(s, cache[key])
			painted = true
	return painted
