class_name MountVisual
extends Node3D

var player: Player
var _feathers: StandardMaterial3D
var _mount_id: int = 0

func _ready() -> void:
	if player == null:
		player = get_parent() as Player
	_build_bird()
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if not is_instance_valid(player):
		hide()
		return
	visible = typeof(player.stats.get("mounted")) == TYPE_BOOL and player.stats["mounted"]
	if not visible:
		return
	rotation.y = player.visual_root.rotation.y
	var id: int = int(player.stats.get("mount_id",0))
	if id != _mount_id:
		_mount_id = id
		_feathers.albedo_color = Color(0.13,0.28,0.19) if id == 10018 else Color(0.27,0.30,0.32) if id in [10085,10087] else Color(0.39,0.44,0.48)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _mesh(name_key: String, mesh: Mesh, position_value: Vector3, material: Material, scale_value: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = name_key
	node.mesh = mesh
	node.material_override = material
	node.position = position_value
	node.scale = scale_value
	add_child(node)
	return node

func _sphere(name_key: String, p: Vector3, size: Vector3, material: Material, segments: int = 12, rings: int = 6) -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = segments
	sphere.rings = rings
	_mesh(name_key,sphere,p,material,size)

func _box(name_key: String,p: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	return _mesh(name_key,box,p,material)

func _beam(name_key: String,a: Vector3,b: Vector3,radius: float,material: Material) -> void:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 8
	var node: MeshInstance3D = _mesh(name_key,cylinder,(a+b)*0.5,material)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func _build_bird() -> void:
	_feathers = _material(Color(0.13,0.28,0.19))
	var beak: StandardMaterial3D = _material(Color(0.65,0.42,0.12))
	var dark: StandardMaterial3D = _material(Color(0.075,0.065,0.045))
	var leather: StandardMaterial3D = _material(Color(0.19,0.095,0.045))
	_sphere("Body",Vector3(0,0.7,0.1),Vector3(1.0,1.0,1.55),_feathers)
	_beam("Neck",Vector3(0,0.8,-0.4),Vector3(0,1.12,-0.8),0.18,_feathers)
	_sphere("Head",Vector3(0,1.18,-0.87),Vector3(0.45,0.44,0.48),_feathers)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0
	cone.bottom_radius = 0.13
	cone.height = 0.36
	cone.radial_segments = 8
	var tip: MeshInstance3D = _mesh("Beak",cone,Vector3(0,1.15,-1.18),beak)
	tip.rotation.x = -PI*0.5
	for sign_value: float in [-1.0,1.0]:
		var wing: MeshInstance3D = _box("Wing",Vector3(sign_value*0.53,0.72,0.12),Vector3(0.36,0.17,1.04),_feathers)
		wing.rotation.z = sign_value*0.24
		for index: int in 3:
			var feather: MeshInstance3D = _box("WingFeather",Vector3(sign_value*(0.54+index*0.055),0.67,0.37+index*0.09),Vector3(0.12,0.09,0.6),_feathers)
			feather.rotation.y = sign_value*0.15
		_beam("Leg",Vector3(sign_value*0.24,0.06,0.2),Vector3(sign_value*0.24,0.5,0.13),0.055,beak)
		_box("Foot",Vector3(sign_value*0.24,0.045,0.03),Vector3(0.19,0.09,0.4),dark)
		_sphere("Eye",Vector3(sign_value*0.175,1.23,-1.015),Vector3(0.075,0.075,0.075),dark,6,3)
	var tail: MeshInstance3D = _box("Tail",Vector3(0,0.76,0.97),Vector3(0.42,0.14,0.7),_feathers)
	tail.rotation.x = -0.25
	_box("Saddle",Vector3(0,1.11,0.08),Vector3(0.54,0.15,0.64),leather)
	_box("SaddleBack",Vector3(0,1.23,0.36),Vector3(0.56,0.19,0.12),leather)
