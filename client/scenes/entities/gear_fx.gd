class_name GearFx
extends Node3D

## Weapon effects on the hero, different per class:
## - warrior: a bright swing trail behind the blade on every strike, sparks on
##   rare blades;
## - mage: a glowing orb with orbiting motes at the wand/staff tip, a flash on
##   every cast;
## plus a rising aura on epic and legendary weapons. Colour follows rarity.

const RARITY_GLOW: Array[Color] = [Color(0.85, 0.92, 1.0), Color(0.6, 1.0, 0.65), Color(0.45, 0.75, 1.0), Color(0.8, 0.5, 1.0), Color(1.0, 0.78, 0.3)]
const MAGE_ORB: Array[Color] = [Color(0.55, 0.85, 1.0), Color(0.55, 1.0, 0.8), Color(0.4, 0.65, 1.0), Color(0.85, 0.45, 1.0), Color(1.0, 0.75, 0.3)]
const TRAIL_SAMPLES: int = 14

var weapon: MeshInstance3D
var mage: bool = false
var rarity: int = 0
var _tip_local: Vector3 = Vector3.ZERO
var _base_local: Vector3 = Vector3.ZERO
var _trail: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _samples: Array = []
var _trail_left: float = 0.0
var _orb: MeshInstance3D

## Visual tier 0..4 of a piece of gear. Prices in the catalogue are still
## provisional (nearly everything is "common"), so the original item names
## decide too: novice < iron < steel/silver < magic/dark/elemental < divine/dragon.
const TIER_WORDS: Array = [["神", "圣", "龙", "天", "帝", "王", "传说"], ["魔", "暗", "炎", "冰", "雷", "灵", "星", "月", "血"], ["钢", "银", "金", "精", "闪亮", "古"], ["铁", "长", "木", "皮", "布"]]
static func tier(item: Dictionary) -> int:
	if item.is_empty():
		return 0
	var by_price: int = MenuSkin.rarity(item)
	var name: String = str(item.get("name", ""))
	if "新手" in name and not "闪亮" in name:
		return by_price
	for i: int in TIER_WORDS.size():
		for word: String in TIER_WORDS[i]:
			if word in name:
				return maxi(by_price, 4 - i)
	return by_price

## Rebuilds the effects for the visible weapon of a dressed model.
static func attach(model: Node3D, stats: Dictionary) -> GearFx:
	var old: Node = model.get_node_or_null("GearFx")
	if old:
		old.free()
	if DisplayServer.get_name() == "headless":
		return null
	var fx: GearFx = GearFx.new()
	fx.name = "GearFx"
	fx.mage = int(stats.get("class_id", 130001)) in HeroAvatar.MAGE_CLASSES
	var equipment: Dictionary = stats.get("equipment", {})
	fx.rarity = tier(ItemCatalog.get_item(int(equipment["weapon"]))) if equipment.has("weapon") else 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.visible and Outfit.WEAPONS.has(String(mi.name)):
			fx.weapon = mi
			break
	model.add_child(fx)
	if fx.weapon:
		fx._setup()
	return fx

func _setup() -> void:
	var box: AABB = weapon.get_aabb()
	var axis: int = box.get_longest_axis_index()
	var lo: Vector3 = box.get_center()
	var hi: Vector3 = box.get_center()
	lo[axis] = box.position[axis]
	hi[axis] = box.end[axis]
	# The grip sits at the mesh origin; the tip is the far end of the long axis.
	if absf(lo[axis]) > absf(hi[axis]):
		_tip_local = lo
		_base_local = hi.lerp(lo, 0.3)
	else:
		_tip_local = hi
		_base_local = lo.lerp(hi, 0.3)
	if mage:
		_make_orb()
	else:
		_make_trail()
		if rarity >= 2:
			_make_aura(weapon, RARITY_GLOW[rarity], 6 + rarity * 4, 0.05, Vector3(0.02, box.size[axis] * 0.4, 0.02), (_tip_local + _base_local) * 0.5)
	if rarity >= 3:
		_make_aura(get_parent(), RARITY_GLOW[rarity], 10 + (rarity - 3) * 10, 0.06, Vector3(0.35, 0.05, 0.35), Vector3(0, 0.1, 0), true)

func _particles(color: Color, amount: int, size: float, extents: Vector3, rising: bool) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 1.1 if rising else 0.7
	p.local_coords = false
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 20.0 if rising else 180.0
	pm.initial_velocity_min = 0.3 if rising else 0.05
	pm.initial_velocity_max = 0.9 if rising else 0.25
	pm.gravity = Vector3(0, 0.6 if rising else 0.0, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = Vfx._spark_material(color)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p

func _make_aura(parent: Node, color: Color, amount: int, size: float, extents: Vector3, at: Vector3, rising: bool = false) -> void:
	var p: GPUParticles3D = _particles(color, amount, size, extents, rising)
	parent.add_child(p)
	p.position = at
	p.emitting = true

func _make_orb() -> void:
	var color: Color = MAGE_ORB[rarity]
	_orb = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.06 + rarity * 0.008
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.9)
	sphere.material = mat
	_orb.mesh = sphere
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	weapon.add_child(_orb)
	_orb.position = _tip_local
	var halo: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.42, 0.42) * (1.0 + rarity * 0.15)
	var hm: StandardMaterial3D = Vfx._spark_material(color)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_color = Color(color.r, color.g, color.b, 0.55)
	quad.material = hm
	halo.mesh = quad
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.add_child(halo)
	_make_aura(_orb, color, 8 + rarity * 4, 0.045, Vector3(0.09, 0.09, 0.09), Vector3.ZERO)

func _make_trail() -> void:
	_trail_mesh = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _trail_mesh
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	_trail.material_override = mat
	add_child(_trail)
	_trail.global_transform = Transform3D.IDENTITY

## Called by HeroAvatar on each strike / cast.
func swing(duration: float = 0.4) -> void:
	if mage:
		if _orb:
			Vfx.burst(get_tree().current_scene, _orb.global_position, MAGE_ORB[rarity], 14 + rarity * 4, 2.5, 0.1, 0.4, 0.0)
		return
	_trail_left = duration
	_samples.clear()

func _process(delta: float) -> void:
	if _orb:
		var t: float = Time.get_ticks_msec() * 0.001
		_orb.scale = Vector3.ONE * (1.0 + 0.12 * sin(t * 5.0))
	if _trail == null or not is_instance_valid(weapon):
		return
	if _trail_left > 0.0:
		_trail_left -= delta
		var xf: Transform3D = weapon.global_transform
		_samples.push_front([xf * _base_local, xf * _tip_local])
		if _samples.size() > TRAIL_SAMPLES:
			_samples.pop_back()
	elif not _samples.is_empty():
		_samples.pop_back()
	_trail_mesh.clear_surfaces()
	if _samples.size() < 2:
		return
	var color: Color = RARITY_GLOW[rarity]
	var boost: float = 1.2 + rarity * 0.25
	_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in _samples.size():
		var a: float = 1.0 - float(i) / float(_samples.size())
		var c: Color = Color(color.r * boost, color.g * boost, color.b * boost, a * a * 0.85)
		_trail_mesh.surface_set_color(Color(c.r, c.g, c.b, 0.0))
		_trail_mesh.surface_add_vertex(_samples[i][0])
		_trail_mesh.surface_set_color(c)
		_trail_mesh.surface_add_vertex(_samples[i][1])
	_trail_mesh.surface_end()
