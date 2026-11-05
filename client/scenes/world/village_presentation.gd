class_name VillagePresentation
extends Node3D

var _ambience: AudioStreamPlayer

func _exit_tree() -> void:
	if is_instance_valid(_ambience):
		_ambience.stop()
		_ambience.stream = null

## Presentation and collision layer, independent of authoritative story data.
func _ready() -> void:
	_build_collisions()
	_build_landscape()
	_build_sign(Vector3(-4, 0, 13), "ГУАНЬЛІНЬ", "Південний тракт  →")
	_build_sign(Vector3(4, 0, 34), "УЗЛІССЯ", "Обережно: дикі звірі")
	_build_market()
	_build_audio()

func _material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

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

func _build_collisions() -> void:
	for tree: Node in get_parent().get_node("ForestFoliage").get_children():
		if str(tree.name).begins_with("Tree"): TreeCollision.add_to(tree)
	for n: String in ["TownHall", "HouseBlacksmith", "HouseAlchemy", "HouseMilitia"]:
		var building: Node3D = get_parent().get_node(n)
		var hall: bool = n == "TownHall"
		_solid(building, Vector3(0, 2.0, 0), Vector3(7.1, 4, 5.6) if hall else Vector3(4.9, 4, 4.3))
	# The central landmark must obstruct both characters and spring-arm camera.
	var fountain: Node3D = get_parent().get_node("Fountain")
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 2.4
	shape.height = 1.0
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.5
	body.add_child(col)
	fountain.add_child(body)

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
		mountain.position = Vector3(sin(angle) * 106, -6, cos(angle) * 115 + 12)
		mountain.rotation.y = angle + rng.randf_range(-0.5, 0.5)
		add_child(mountain)

func _build_sign(pos: Vector3, title: String, subtitle: String) -> void:
	var signpost: Node3D = Node3D.new()
	signpost.position = pos
	add_child(signpost)
	var wood: StandardMaterial3D = _material(Color("4d3322"))
	wood.albedo_texture = preload("res://assets/textures/wood.png")
	_box(signpost, Vector3(0, 1.1, 0), Vector3(0.16, 2.2, 0.16), wood)
	_box(signpost, Vector3(0, 1.9, 0), Vector3(2.6, 0.8, 0.18), wood)
	var label: Label3D = Label3D.new()
	label.text = title + "\n" + subtitle
	label.font_size = 28
	label.pixel_size = 0.005
	label.modulate = Color("f3deab")
	label.position = Vector3(0, 1.9, 0.11)
	signpost.add_child(label)

func _build_market() -> void:
	var wood: StandardMaterial3D = _material(Color("513b29"))
	wood.albedo_texture = preload("res://assets/textures/wood.png")
	var cloth: StandardMaterial3D = _material(Color("a05e3f"))
	var produce: StandardMaterial3D = _material(Color("d7a14f"))
	for x: float in [-11.0, 11.0]:
		var stall: Node3D = Node3D.new()
		stall.position = Vector3(x, 0, 8)
		stall.rotation.y = -0.3 if x > 0 else 0.3
		add_child(stall)
		_box(stall, Vector3(0, 0.9, 0), Vector3(2.5, 0.15, 1.1), wood)
		for dx: float in [-1.1, 1.1]:
			for dz: float in [-0.45, 0.45]:
				_box(stall, Vector3(dx, 1.25, dz), Vector3(0.1, 2.5, 0.1), wood)
		var canopy: MeshInstance3D = _box(stall, Vector3(0, 2.5, 0), Vector3(2.9, 0.1, 1.7), cloth)
		canopy.rotation.x = 0.12
		for j: int in 5:
			_box(stall, Vector3(-0.8 + j * 0.4, 1.08, 0), Vector3(0.28, 0.2, 0.5), produce)
		_solid(stall, Vector3(0, 0.6, 0), Vector3(2.5, 1.2, 1.1))

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
