class_name WorldDecor
extends Node3D

## Procedural set dressing for Guanlin Town: textured ground, grass & flowers,
## forest border, scattered rocks, dirt paths, street lamps, fountain water,
## ambient pollen and invisible map bounds. Everything is batched (MultiMesh)
## so it stays cheap on mobile GPUs.

const TREE_SCENE: PackedScene = preload("res://assets/models/v2/oak.glb")
const ROCK_SCENE: PackedScene = preload("res://assets/models/rock_boulder.glb")

## Playable area (world units). Outside of it is decorative forest.
@export var bounds_min: Vector2 = GuanlinLayout.BOUNDS_MIN
@export var bounds_max: Vector2 = GuanlinLayout.BOUNDS_MAX
@export var grass_count: int = 6000
@export var flower_count: int = 500
@export var rng_seed: int = 1337

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _blocked: Array[Rect2] = []   # XZ rects where props must not be scattered
var _tree_transforms: Array[Transform3D] = []

func _ready() -> void:
	rng.seed = rng_seed
	_blocked = GuanlinLayout.blocked_rects()
	_blocked.append(Rect2(-24.0, -29.0, 6.0, 20.0))  # consignment arcade
	_style_ground()
	_build_paths()
	_build_plaza()
	_build_grass()
	_build_flowers()
	_build_forest_border()
	_scatter_rocks()
	_build_lamps()
	_build_fountain_water()
	_build_pollen()
	_build_bounds()

func _is_blocked(p: Vector2) -> bool:
	for r: Rect2 in _blocked:
		if r.has_point(p):
			return true
	return false

func _rand_point(margin: float = 0.0) -> Vector2:
	return Vector2(
		rng.randf_range(bounds_min.x + margin, bounds_max.x - margin),
		rng.randf_range(bounds_min.y + margin, bounds_max.y - margin))

# ------------------------------------------------------------------ Ground ---

func _style_ground() -> void:
	var ground_mesh: MeshInstance3D = get_parent().get_node_or_null("Ground/MeshInstance3D")
	if ground_mesh == null:
		return
	var meadow: ShaderMaterial = ShaderMaterial.new()
	meadow.shader = preload("res://client/shaders/meadow.gdshader")
	meadow.set_shader_parameter("paving", preload("res://assets/textures/cobble.png"))
	ground_mesh.material_override = meadow
	get_parent().get_node("CobblestonePlaza").hide()

func _flat_material(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

func _build_paths() -> void:
	# Dirt side-paths from the main road to each building, slightly raised to avoid z-fighting.
	var dirt: StandardMaterial3D = _flat_material(Color(0.5, 0.4, 0.27))
	var paths: Array = [
		[Vector3(11.0, 0.03, -6.0), Vector3(10.0, 0.06, 3.0), 15.0],    # to blacksmith
		[Vector3(11.0, 0.03, 4.0), Vector3(10.0, 0.06, 3.0), -10.0],    # to alchemist
		[Vector3(-11.0, 0.03, -2.0), Vector3(10.0, 0.06, 3.5), -10.0],  # to militia
		[Vector3(-11.0, 0.03, 5.0), Vector3(8.0, 0.06, 3.0), 0.0],      # to training ground
	]
	for p: Array in paths:
		continue
		var mi: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = p[1]
		box.material = dirt
		mi.mesh = box
		mi.position = p[0]
		mi.rotation_degrees.y = p[2]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Forest trail continuing south past the gate
	var trail: MeshInstance3D = MeshInstance3D.new()
	var tbox: BoxMesh = BoxMesh.new()
	tbox.size = Vector3(5.0, 0.06, 32.0)
	tbox.material = dirt
	trail.mesh = tbox
	trail.position = Vector3(0, 0.04, 50.0)
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)

func _build_plaza() -> void:
	# Round cobblestone plaza around the fountain with a darker ring border.
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/textures/cobble.png")
	mat.uv1_scale = Vector3(4, 4, 4)
	mat.roughness = 0.8

	var ring: MeshInstance3D = MeshInstance3D.new()
	var rmesh: CylinderMesh = CylinderMesh.new()
	rmesh.top_radius = GuanlinLayout.PLAZA_RADIUS + 0.5
	rmesh.bottom_radius = GuanlinLayout.PLAZA_RADIUS + 0.5
	rmesh.height = 0.08
	rmesh.radial_segments = 48
	rmesh.material = _flat_material(Color(0.42, 0.36, 0.3))
	ring.mesh = rmesh
	ring.position = GuanlinLayout.PLAZA + Vector3(0, 0.07, 0)
	add_child(ring)

	var plaza: MeshInstance3D = MeshInstance3D.new()
	var pmesh: CylinderMesh = CylinderMesh.new()
	pmesh.top_radius = GuanlinLayout.PLAZA_RADIUS
	pmesh.bottom_radius = GuanlinLayout.PLAZA_RADIUS
	pmesh.height = 0.1
	pmesh.radial_segments = 48
	pmesh.material = mat
	plaza.mesh = pmesh
	plaza.position = GuanlinLayout.PLAZA + Vector3(0, 0.08, 0)
	add_child(plaza)

	# Road surface gets the same cobble texture
	var road: MeshInstance3D = get_parent().get_node_or_null("CobblestonePlaza")
	if road:
		var road_mat: StandardMaterial3D = mat.duplicate()
		road_mat.uv1_triplanar = true
		road_mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
		road.material_override = road_mat

# ------------------------------------------------------------ Vegetation ---

func _make_grass_blade_mesh() -> ArrayMesh:
	# Three crossed tapered blades, coloured dark at the root and light at the tip.
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root_col: Color = Color(0.16, 0.34, 0.1)
	var tip_col: Color = Color(0.55, 0.8, 0.32)
	for i: int in 3:
		var a: float = TAU * float(i) / 3.0 + 0.3
		var dir: Vector3 = Vector3(cos(a), 0.0, sin(a)) * 0.09
		var lean: Vector3 = Vector3(cos(a + 1.2), 0.0, sin(a + 1.2)) * 0.08
		st.set_normal(Vector3.UP)
		st.set_color(root_col)
		st.add_vertex(-dir)
		st.set_color(root_col)
		st.add_vertex(dir)
		st.set_color(tip_col)
		st.add_vertex(Vector3(0, 0.45, 0) + lean)
	return st.commit()

func _build_grass() -> void:
	var mesh: ArrayMesh = _make_grass_blade_mesh()
	var wind: ShaderMaterial = ShaderMaterial.new()
	wind.shader = preload("res://client/shaders/meadow_wind.gdshader")
	mesh.surface_set_material(0, wind)

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	var transforms: Array[Transform3D] = []
	var tries: int = 0
	while transforms.size() < grass_count and tries < grass_count * 3:
		tries += 1
		var p: Vector2 = _rand_point(-6.0)
		if _is_blocked(p):
			continue
		var s: float = rng.randf_range(0.7, 1.5)
		var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		transforms.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		var tint: float = rng.randf_range(0.85, 1.15)
		mm.set_instance_color(i, Color(tint, tint, tint * 0.9))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_flowers() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.14
	sphere.radial_segments = 6
	sphere.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(0.15, 0.12, 0.1)
	sphere.material = mat
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	var palette: Array[Color] = [Color(1, 0.85, 0.2), Color(0.95, 0.35, 0.45), Color(0.7, 0.5, 1.0), Color(1, 1, 1), Color(1, 0.55, 0.15)]
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	while transforms.size() < flower_count:
		# Flowers grow in small clusters
		var center: Vector2 = _rand_point(-4.0)
		if _is_blocked(center):
			continue
		var col: Color = palette[rng.randi() % palette.size()]
		for k: int in rng.randi_range(4, 9):
			var p: Vector2 = center + Vector2(rng.randf_range(-1.2, 1.2), rng.randf_range(-1.2, 1.2))
			transforms.append(Transform3D(Basis(), Vector3(p.x, rng.randf_range(0.25, 0.4), p.y)))
			colors.append(col)
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_forest_border() -> void:
	# Dense ring of trees just outside the playable bounds, two rows deep.
	var holder: Node3D = Node3D.new()
	holder.name = "ForestBorder"
	add_child(holder)
	for row: int in 2:
		var inset: float = -2.0 - row * 5.0
		var step: float = 6.0 + row * 1.5
		var x: float = bounds_min.x + inset
		while x <= bounds_max.x - inset:
			_place_tree(holder, Vector2(x, bounds_min.y + inset))
			# Leave the south trail open on the inner row
			if not (row == 0 and absf(x) < 4.0):
				_place_tree(holder, Vector2(x, bounds_max.y - inset))
			x += step + rng.randf_range(-1.0, 1.0)
		var z: float = bounds_min.y + inset
		while z <= bounds_max.y - inset:
			_place_tree(holder, Vector2(bounds_min.x + inset, z))
			_place_tree(holder, Vector2(bounds_max.x - inset, z))
			z += step + rng.randf_range(-1.0, 1.0)
	# A few trees inside the southern forest zone for cover
	for i: int in 14:
		var p: Vector2 = Vector2(rng.randf_range(-36, 36), rng.randf_range(24, 62))
		if absf(p.x) < 6.0:
			continue
		_place_tree(holder, p)
	_batch_trees(holder)

func _place_tree(parent: Node3D, p: Vector2) -> void:
	var s: float = rng.randf_range(1.3, 2.2)
	var pos: Vector3 = Vector3(p.x + rng.randf_range(-1.2, 1.2), 0.0, p.y + rng.randf_range(-1.2, 1.2))
	var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
	_tree_transforms.append(Transform3D(basis, pos))
	TreeCollision.add_to(parent,Transform3D(basis,pos))

func _batch_trees(parent: Node3D) -> void:
	var source: Node3D = TREE_SCENE.instantiate()
	CharacterMotion.prepare_palette(source)
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = _tree_transforms.size()
		for i: int in _tree_transforms.size():
			mm.set_instance_transform(i, _tree_transforms[i] * mi.transform)
		var batch: MultiMeshInstance3D = MultiMeshInstance3D.new()
		batch.multimesh = mm
		parent.add_child(batch)
	source.free()

func _scatter_rocks() -> void:
	for i: int in 16:
		var p: Vector2 = _rand_point(3.0)
		if _is_blocked(p) or p.y < GuanlinLayout.GATE_Z + 4.0 and p.y > -70.0:
			continue
		var r: Node3D = ROCK_SCENE.instantiate()
		var s: float = rng.randf_range(0.6, 1.6)
		r.position = Vector3(p.x, -0.1, p.y)
		r.rotation.y = rng.randf() * TAU
		r.scale = Vector3(s, s * rng.randf_range(0.7, 1.1), s)
		add_child(r)

# ------------------------------------------------------------------ Props ---

func _build_lamps() -> void:
	var pole_mat: StandardMaterial3D = _flat_material(Color(0.18, 0.16, 0.15), 0.6)
	pole_mat.metallic = 0.6
	var glow_mat: StandardMaterial3D = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.85, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.75, 0.35)
	glow_mat.emission_energy_multiplier = 3.0
	var spots: Array[Vector3] = [
		Vector3(-4.2, 0, -50), Vector3(4.2, 0, -44), Vector3(-4.2, 0, -14),
		Vector3(4.2, 0, -2), Vector3(-4.2, 0, 8), Vector3(4.2, 0, 8),
		Vector3(-14, 0, -26.5), Vector3(14, 0, -33.5), Vector3(28, 0, -26.5), Vector3(-28, 0, -33.5),
	]
	for spot: Vector3 in spots:
		var lamp: Node3D = Node3D.new()
		lamp.position = spot
		add_child(lamp)
		var pole: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.12
		cyl.height = 3.2
		cyl.material = pole_mat
		pole.mesh = cyl
		pole.position.y = 1.6
		lamp.add_child(pole)
		var bulb: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		sph.radius = 0.22
		sph.height = 0.44
		sph.material = glow_mat
		bulb.mesh = sph
		bulb.position.y = 3.35
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.add_child(bulb)
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = Color(1.0, 0.8, 0.5)
		light.light_energy = 1.2
		light.omni_range = 7.0
		light.position.y = 3.2
		lamp.add_child(light)
		# Simple collision so the player bumps into poles
		var body: StaticBody3D = StaticBody3D.new()
		var col: CollisionShape3D = CollisionShape3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 0.2
		shape.height = 3.0
		col.shape = shape
		col.position.y = 1.5
		body.add_child(col)
		lamp.add_child(body)

func _build_fountain_water() -> void:
	var fountain: Node3D = get_parent().get_node_or_null("Fountain")
	if fountain == null:
		return
	var aabb: AABB = _calc_aabb(fountain)
	var radius: float = maxf(aabb.size.x, aabb.size.z) * 0.42
	if radius <= 0.1:
		radius = 1.6
	var water_mat: StandardMaterial3D = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.25, 0.6, 0.85, 0.75)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.metallic = 0.3
	water_mat.roughness = 0.05
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.05, 0.18, 0.3)
	var water: MeshInstance3D = MeshInstance3D.new()
	var disk: CylinderMesh = CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.05
	disk.radial_segments = 32
	disk.material = water_mat
	var animated_water: ShaderMaterial = ShaderMaterial.new()
	animated_water.shader = preload("res://client/shaders/water.gdshader")
	disk.material = animated_water
	water.mesh = disk
	water.position = fountain.position + Vector3(0, minf(aabb.size.y * 0.35, 0.6), 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

	# Water spray
	var spray: GPUParticles3D = GPUParticles3D.new()
	spray.amount = 80
	spray.lifetime = 1.1
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -9.8, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.0
	spray.process_material = pm
	var drop: SphereMesh = SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 4
	drop.rings = 2
	var drop_mat: StandardMaterial3D = StandardMaterial3D.new()
	drop_mat.albedo_color = Color(0.75, 0.9, 1.0, 0.8)
	drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = drop_mat
	spray.draw_pass_1 = drop
	spray.position = fountain.position + Vector3(0, maxf(aabb.size.y, 1.0), 0)
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)

func _calc_aabb(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var local: AABB = mi.get_aabb()
		var xf: Transform3D = (node as Node3D).global_transform.affine_inverse() * mi.global_transform
		var box: AABB = xf * local
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _build_pollen() -> void:
	# Floating sunlit motes that follow the camera area: cheap "magic" ambience.
	var motes: GPUParticles3D = GPUParticles3D.new()
	motes.amount = 120
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.visibility_aabb = AABB(Vector3(-60, -2, -60), Vector3(120, 20, 160))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(42, 2, 66)
	pm.direction = Vector3(0.3, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.gravity = Vector3.ZERO
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 0.7, 0), Color(1, 1, 0.7, 1), Color(1, 1, 0.7, 1), Color(1, 1, 0.7, 0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	motes.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(1, 0.95, 0.6)
	quad.material = mat
	motes.draw_pass_1 = quad
	motes.position = Vector3(0, 2.5, -10)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)

func _build_bounds() -> void:
	# Invisible walls on the edge of the playable area.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "MapBounds"
	add_child(body)
	var w: float = bounds_max.x - bounds_min.x
	var d: float = bounds_max.y - bounds_min.y
	var cx: float = (bounds_min.x + bounds_max.x) / 2.0
	var cz: float = (bounds_min.y + bounds_max.y) / 2.0
	var walls: Array = [
		[Vector3(cx, 2, bounds_min.y), Vector3(w, 4, 1)],
		[Vector3(cx, 2, bounds_max.y), Vector3(w, 4, 1)],
		[Vector3(bounds_min.x, 2, cz), Vector3(1, 4, d)],
		[Vector3(bounds_max.x, 2, cz), Vector3(1, 4, d)],
	]
	for wdef: Array in walls:
		var col: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = wdef[1]
		col.shape = box
		col.position = wdef[0]
		body.add_child(col)
