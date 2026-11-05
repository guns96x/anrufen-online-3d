class_name VillagePresentation
extends Node3D

## Guanlin Town buildings, market, palisade and gate, built from GuanlinLayout.
## Presentation and collision only; story data stays in the shared systems.

var _ambience: AudioStreamPlayer
var builder: TownBuilder

func _exit_tree() -> void:
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null

func _ready() -> void:
	builder = TownBuilder.new()
	builder.name = "Buildings"
	add_child(builder)
	for h: Array in GuanlinLayout.HOUSES:
		var house: Node3D = builder.house(h[1], h[2], h[3], h[4], h[5], h[6])
		house.name = String(h[0]).to_pascal_case()
	_build_tree_collisions()
	_build_market()
	_build_palisade()
	_build_gate()
	_build_props()
	_build_sign(Vector3(-4.5, 0, 9.0), "ҐУАНЬЛІНЬ", "Сонячний ліс  ↓")
	_build_sign(Vector3(-5.5, 0, -38.0), "ПЛОЩА", "Таверна ↑   Церква ←")
	_build_landscape()
	_build_audio()

func _material(color: Color, rough: float = 0.9) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat

func _wood() -> StandardMaterial3D:
	var wood: StandardMaterial3D = _material(Color("8a6a4a"))
	wood.albedo_texture = preload("res://assets/village/T_WoodTrim_BaseColor.png")
	wood.normal_enabled = true
	wood.normal_texture = preload("res://assets/village/T_WoodTrim_Normal.png")
	return wood

func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node

func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)

func _build_tree_collisions() -> void:
	var foliage: Node = get_parent().get_node_or_null("ForestFoliage")
	if foliage == null:
		return
	for tree: Node in foliage.get_children():
		if str(tree.name).begins_with("Tree"): TreeCollision.add_to(tree)
	# The plaza fountain obstructs both characters and the spring-arm camera.
	var fountain: Node3D = get_parent().get_node_or_null("Fountain")
	if fountain:
		var body: StaticBody3D = StaticBody3D.new()
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.radius = 2.4
		shape.height = 1.0
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position.y = 0.5
		body.add_child(col)
		fountain.add_child(body)

## Canopied market stalls: posts, a sloped cloth roof, a counter with goods and crates.
func _build_market() -> void:
	var wood: StandardMaterial3D = _wood()
	var goods: Array[StandardMaterial3D] = [_material(Color("c98b3a")), _material(Color("8e2f2a")), _material(Color("d8c27a")), _material(Color("5d7b3a"))]
	for s: Array in GuanlinLayout.STALLS:
		var stall: Node3D = Node3D.new()
		stall.position = s[0]
		stall.rotation.y = deg_to_rad(s[1])
		add_child(stall)
		var length: float = s[2]
		var cloth: StandardMaterial3D = _material(s[3], 0.95)
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		var bays: int = maxi(1, int(round(length / 3.0)))
		for i: int in bays + 1:
			var x: float = -length * 0.5 + i * length / bays
			_box(stall, Vector3(x, 1.35, 1.1), Vector3(0.16, 2.7, 0.16), wood)
			_box(stall, Vector3(x, 1.1, -1.1), Vector3(0.16, 2.2, 0.16), wood)
		var roof: MeshInstance3D = _box(stall, Vector3(0, 2.5, 0), Vector3(length + 0.6, 0.06, 2.9), cloth)
		roof.rotation.x = deg_to_rad(-9.0)
		for i: int in bays:
			var x: float = -length * 0.5 + (i + 0.5) * length / bays
			var valance: MeshInstance3D = _box(stall, Vector3(x, 2.55, 1.45), Vector3(length / bays - 0.1, 0.35, 0.03), cloth)
			valance.rotation.x = deg_to_rad(-9.0)
			_box(stall, Vector3(x, 0.85, 0.6), Vector3(length / bays - 0.4, 0.12, 0.9), wood)
			_box(stall, Vector3(x, 0.42, 0.6), Vector3(length / bays - 0.6, 0.8, 0.7), wood)
			for k: int in 4:
				var item: MeshInstance3D = _box(stall, Vector3(x - 0.75 + k * 0.5, 0.98, 0.55), Vector3(0.34, 0.16, 0.5), goods[(i + k) % goods.size()])
				item.rotation.y = 0.15 * k
			var crate: Node3D = builder.place(stall, "Prop_Crate", Vector3(x + 0.6, 0, -0.6), 15.0 * i)
			crate.scale = Vector3.ONE * 0.6
		_solid(stall, Vector3(0, 0.6, 0.6), Vector3(length, 1.2, 1.0))
		builder.bake(stall)

## Sharpened-log palisade along every run, batched in one MultiMesh.
func _build_palisade() -> void:
	var log_mesh: CylinderMesh = CylinderMesh.new()
	log_mesh.top_radius = 0.2
	log_mesh.bottom_radius = 0.24
	log_mesh.height = 3.4
	log_mesh.radial_segments = 7
	log_mesh.rings = 1
	log_mesh.material = _wood()
	var tip_mesh: CylinderMesh = CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.2
	tip_mesh.height = 0.55
	tip_mesh.radial_segments = 7
	tip_mesh.rings = 1
	tip_mesh.material = log_mesh.material
	var logs: Array[Transform3D] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4711
	var walls: StaticBody3D = StaticBody3D.new()
	walls.name = "Palisade"
	add_child(walls)
	for run: Array in GuanlinLayout.PALISADE:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var count: int = int(a.distance_to(b) / 0.46)
		for i: int in count + 1:
			var p: Vector2 = a.lerp(b, float(i) / count)
			var h: float = rng.randf_range(0.88, 1.08)
			var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, h, 1))
			logs.append(Transform3D(basis, Vector3(p.x, 1.7 * h, p.y)))
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(a.distance_to(b) + 0.5, 4.0, 0.6)
		var col: CollisionShape3D = CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3((a.x + b.x) * 0.5, 2.0, (a.y + b.y) * 0.5)
		col.rotation.y = -atan2(b.y - a.y, b.x - a.x)
		walls.add_child(col)
	for part: Array in [[log_mesh, 0.0], [tip_mesh, 1.97]]:
		var mm: MultiMesh = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part[0]
		mm.instance_count = logs.size()
		for i: int in logs.size():
			var t: Transform3D = logs[i]
			mm.set_instance_transform(i, Transform3D(t.basis, t.origin + Vector3(0, float(part[1]) * t.basis.get_scale().y, 0)))
		var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	# Horizontal binding rails on the inner face.
	var rail_mat: StandardMaterial3D = _wood()
	for run: Array in GuanlinLayout.PALISADE:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		for y: float in [0.9, 2.5]:
			var rail: MeshInstance3D = _box(self, Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5), Vector3(a.distance_to(b), 0.14, 0.12), rail_mat)
			rail.rotation.y = -atan2(b.y - a.y, b.x - a.x)

## Forest gate: two log watchtowers joined by a lintel, with lit braziers.
func _build_gate() -> void:
	var gate: Node3D = Node3D.new()
	gate.name = "ForestGate"
	gate.position = Vector3(0, 0, GuanlinLayout.GATE_Z)
	add_child(gate)
	var wood: StandardMaterial3D = _wood()
	var ember: StandardMaterial3D = _material(Color(1, 0.55, 0.2))
	ember.emission_enabled = true
	ember.emission = Color(1.0, 0.45, 0.12)
	ember.emission_energy_multiplier = 4.0
	for side: float in [-1.0, 1.0]:
		var tower: Node3D = Node3D.new()
		tower.position = Vector3(side * 5.6, 0, 0)
		gate.add_child(tower)
		for dx: float in [-1.0, 1.0]:
			for dz: float in [-1.0, 1.0]:
				_box(tower, Vector3(dx * 0.95, 2.6, dz * 0.95), Vector3(0.32, 5.2, 0.32), wood)
		_box(tower, Vector3(0, 4.6, 0), Vector3(2.5, 0.2, 2.5), wood)
		for dz: float in [-1.15, 1.15]:
			_box(tower, Vector3(0, 5.1, dz), Vector3(2.4, 0.8, 0.12), wood)
		var cap: MeshInstance3D = MeshInstance3D.new()
		var pyramid: CylinderMesh = CylinderMesh.new()
		pyramid.top_radius = 0.0
		pyramid.bottom_radius = 2.1
		pyramid.height = 1.6
		pyramid.radial_segments = 4
		pyramid.rings = 1
		var tiles: StandardMaterial3D = _material(Color("b4553a"))
		tiles.albedo_texture = preload("res://assets/village/T_RoundTiles_BaseColor.png")
		pyramid.material = tiles
		cap.mesh = pyramid
		cap.position = Vector3(0, 6.3, 0)
		cap.rotation.y = PI / 4.0
		tower.add_child(cap)
		_solid(tower, Vector3(0, 2.6, 0), Vector3(2.3, 5.2, 2.3))
		builder.bake(tower)
		var fire: OmniLight3D = OmniLight3D.new()
		fire.light_color = Color(1.0, 0.62, 0.3)
		fire.light_energy = 1.6
		fire.omni_range = 9.0
		fire.position = Vector3(-side * 1.6, 2.2, -1.4)
		tower.add_child(fire)
		_box(tower, Vector3(-side * 1.6, 0.8, -1.4), Vector3(0.1, 1.6, 0.1), wood)
		var brazier: MeshInstance3D = _box(tower, Vector3(-side * 1.6, 1.7, -1.4), Vector3(0.45, 0.25, 0.45), _material(Color("2b2622"), 0.5))
		_box(brazier, Vector3(0, 0.15, 0), Vector3(0.35, 0.08, 0.35), ember)
	_box(gate, Vector3(0, 4.9, 0), Vector3(13.6, 0.5, 0.6), wood)
	var plank: MeshInstance3D = _box(gate, Vector3(0, 4.2, -0.35), Vector3(4.2, 0.9, 0.08), _material(Color("5a3b22")))
	var label: Label3D = Label3D.new()
	label.text = "ҐУАНЬЛІНЬ"
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color("f2d48c")
	label.outline_size = 10
	label.position = Vector3(0, 0, -0.05)
	label.rotation.y = PI
	plank.add_child(label)

func _build_props() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 909
	builder.place(self, "Prop_Wagon", Vector3(6.5, 0, -57.5), 70.0)
	builder.place(self, "Prop_Wagon", Vector3(-9.5, 0, -8.5), -20.0)
	for spot: Vector3 in [Vector3(-5.8, 0, -55.8), Vector3(-6.8, 0, -56.6), Vector3(20.5, 0, -7.5), Vector3(20.5, 0, 1.5), Vector3(-10, 0, -61)]:
		builder.place(self, "Prop_Crate", spot, rng.randf() * 90.0).scale = Vector3.ONE * rng.randf_range(0.7, 1.0)
	for h: Array in GuanlinLayout.HOUSES:
		if String(h[0]).begins_with("home"):
			var yaw: float = deg_to_rad(float(h[2]))
			var front: Vector3 = Vector3(sin(yaw), 0, cos(yaw))
			var right: Vector3 = Vector3(cos(yaw), 0, -sin(yaw))
			var gate_pos: Vector3 = Vector3(h[1]) + front * (float(h[4]) + 2.0)
			for k: float in [-1.0, 1.0]:
				builder.place(self, "Prop_WoodenFence_Single", gate_pos + right * k * 2.6, float(h[2]))
	for d: Vector3 in GuanlinLayout.TRAINING_DUMMIES:
		var dummy: Node3D = preload("res://assets/models/prop_training_dummy.glb").instantiate()
		dummy.position = d
		add_child(dummy)

func _build_sign(pos: Vector3, title: String, subtitle: String) -> void:
	var signpost: Node3D = Node3D.new()
	signpost.position = pos
	add_child(signpost)
	var wood: StandardMaterial3D = _wood()
	_box(signpost, Vector3(0, 1.1, 0), Vector3(0.16, 2.2, 0.16), wood)
	_box(signpost, Vector3(0, 1.9, 0), Vector3(2.6, 0.8, 0.18), wood)
	var label: Label3D = Label3D.new()
	label.text = title + "\n" + subtitle
	label.font_size = 28
	label.pixel_size = 0.005
	label.modulate = Color("f3deab")
	label.outline_size = 6
	label.position = Vector3(0, 1.9, 0.11)
	signpost.add_child(label)

func _build_landscape() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 272
	var stone: StandardMaterial3D = _material(Color("66756a"))
	for i: int in 18:
		var angle: float = float(i) / 18.0 * TAU
		var mountain: MeshInstance3D = MeshInstance3D.new()
		var peak: SphereMesh = SphereMesh.new()
		peak.radius = 1.0
		peak.height = 2.0
		peak.radial_segments = 9
		peak.rings = 4
		peak.material = stone
		mountain.mesh = peak
		mountain.scale = Vector3(rng.randf_range(26, 40), rng.randf_range(14, 23), rng.randf_range(24, 40))
		mountain.position = Vector3(sin(angle) * 112, -6, cos(angle) * 130 - 4)
		mountain.rotation.y = angle + rng.randf_range(-0.5, 0.5)
		add_child(mountain)

func _build_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	_ambience = audio
	audio.name = "MeadowAmbience"
	var stream: AudioStreamWAV = preload("res://assets/audio/meadow.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	audio.stream = stream
	audio.bus = "Music"
	audio.volume_db = -22.0
	add_child(audio)
	audio.play()
