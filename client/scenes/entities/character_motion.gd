class_name CharacterMotion
extends Node

## Articulated stylized animation, reusing four GLB limb pivots. No per-frame
## skeleton allocations; movement, idle and strike share the same model.
var actor: Node3D
var model: Node3D
var _pivots: Dictionary = {}
var _rest: Dictionary = {}
var _phase: float = 0.0
var strike_left: float = 0.0

func _ready() -> void:
	prepare_palette(model)
	for key: String in ["Arm_L", "Arm_R", "Leg_L", "Leg_R"]:
		var node: Node3D = model.find_child(key, true, false)
		if node:
			_pivots[key] = node
			_rest[key] = node.rotation

static func prepare_palette(root_node: Node) -> void:
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for surface: int in mi.mesh.get_surface_count():
			var mat: StandardMaterial3D = mi.mesh.surface_get_material(surface) as StandardMaterial3D
			if mat and mat.resource_name.begins_with("Vertex palette"):
				mat.vertex_color_use_as_albedo = true

func _process(delta: float) -> void:
	var speed: float = 0.0
	if actor is CharacterBody3D:
		speed = Vector2(actor.velocity.x, actor.velocity.z).length()
	var death_state: Variant = actor.get("is_dead")
	if typeof(death_state) == TYPE_BOOL and death_state:
		speed = 0.0
	elif death_state is Callable and death_state.call():
		speed = 0.0
	_phase += delta * (9.0 if speed > 0.2 else 1.8)
	strike_left = maxf(0.0, strike_left - delta)
	for key: String in _pivots:
		var pivot: Node3D = _pivots[key]
		var sign_value: float = -1.0 if key.ends_with("L") else 1.0
		var amount: float = sin(_phase) * sign_value * minf(speed / 6.0, 1.0) * 0.6
		if key.begins_with("Arm"):
			amount = -amount * 0.65 + sin(_phase * 0.5) * 0.025
		if key == "Arm_R" and strike_left > 0.0:
			amount -= sin(strike_left / 0.35 * PI) * 1.6
		pivot.rotation.x = _rest[key].x + amount
