class_name ForagePatch
extends Node3D

var point_id: int
var available: bool = true
var label: Label3D

func _ready() -> void:
	add_to_group("forage_patches")
	for index: int in 7:
		var leaf: MeshInstance3D = MeshInstance3D.new()
		var mesh: PrismMesh = PrismMesh.new()
		mesh.size = Vector3(0.24,0.5,0.08)
		leaf.mesh = mesh
		leaf.position = Vector3(sin(index*2.4)*0.2,0.25,cos(index*2.4)*0.2)
		leaf.rotation = Vector3(0,index*2.4,0.3)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.2,0.48,0.12)
		material.roughness = 0.9
		leaf.material_override = material
		add_child(leaf)
	label = Label3D.new()
	label.text = "Дика зелень · зібрати"
	label.position.y = 1.1
	label.font_size = 27
	label.pixel_size = 0.007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.8,1,0.6)
	add_child(label)

func set_available(value: bool) -> void:
	available = value
	visible = value
