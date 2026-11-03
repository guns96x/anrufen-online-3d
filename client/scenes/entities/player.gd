class_name Player
extends CharacterBody3D

const CombatFormulas = preload("res://shared/combat/combat_formulas.gd")

@export var move_speed: float = 6.0
@export var rotation_speed: float = 12.0
@export var is_local_player: bool = true

@onready var visual_root: Node3D = $Visual
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var move_direction: Vector2 = Vector2.ZERO
var current_target: Node3D = null
var nearby_npc: Node3D = null

# Combat Stats
var stats: Dictionary = {
	"name": "Novice Hero",
	"class_name": "见习战士",
	"level": 1,
	"hp": 100,
	"max_hp": 100,
	"mp": 50,
	"max_mp": 50,
	"attack": 22,
	"defense": 8,
	"crit_rate": 0.15,
	"accuracy": 0.95,
	"evasion": 0.05,
	"element": 1 # PHY
}

# Camera Orbit & Zoom
var cam_rot_h: float = 0.0
var cam_rot_v: float = -35.0 # Isometric tilt
var cam_dist: float = 9.0

# Network peer id
var peer_id: int = 1

func _ready() -> void:
	if is_local_player:
		camera.make_current()
	else:
		# Remote puppet player
		spring_arm.queue_free()

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	# Touch screen drag in right half of screen rotates camera
	if event is InputEventScreenDrag:
		var vp_size = get_viewport().get_visible_rect().size
		if event.position.x > vp_size.x * 0.4:
			cam_rot_h -= event.relative.x * 0.3
			cam_rot_v = clampf(cam_rot_v - event.relative.y * 0.2, -65.0, -15.0)
			_update_camera_orbit()
			
	# Mouse drag for PC testing
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cam_rot_h -= event.relative.x * 0.4
		cam_rot_v = clampf(cam_rot_v - event.relative.y * 0.3, -65.0, -15.0)
		_update_camera_orbit()
		
	# Mouse wheel zoom for PC
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.5, 4.0, 16.0)
			_update_camera_orbit()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.5, 4.0, 16.0)
			_update_camera_orbit()

func _update_camera_orbit() -> void:
	if spring_arm:
		spring_arm.rotation_degrees = Vector3(cam_rot_v, cam_rot_h, 0)
		spring_arm.spring_length = cam_dist

func set_move_vector(input_vec: Vector2) -> void:
	move_direction = input_vec

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
		
	# Keyboard fallback for PC testing
	var kb_x = Input.get_axis("ui_left", "ui_right")
	var kb_y = Input.get_axis("ui_up", "ui_down")
	var dir_2d = move_direction
	if dir_2d.length() < 0.05 and (kb_x != 0 or kb_y != 0):
		dir_2d = Vector2(kb_x, kb_y).normalized()
		
	if dir_2d.length() > 0.05:
		# Calculate camera-relative movement direction
		var cam_yaw = deg_to_rad(cam_rot_h)
		var forward = Vector3(sin(cam_yaw), 0, cos(cam_yaw))
		var right = Vector3(cos(cam_yaw), 0, -sin(cam_yaw))
		
		# Invert forward so pressing UP moves away from camera
		var wish_dir = (-forward * dir_2d.y + right * dir_2d.x).normalized()
		
		velocity.x = wish_dir.x * move_speed
		velocity.z = wish_dir.z * move_speed
		
		# Smoothly rotate visual toward movement
		var target_angle = atan2(-wish_dir.x, -wish_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, rotation_speed * delta)
		
		# Bobbing walk animation
		visual_root.position.y = abs(sin(Time.get_ticks_msec() * 0.012)) * 0.12
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 8.0 * delta)
		visual_root.position.y = move_toward(visual_root.position.y, 0, delta * 2.0)
		
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0
		
	move_and_slide()
	
	# Network sync position to other players
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		rpc("sync_transform", global_position, visual_root.rotation.y)

@rpc("unreliable", "call_remote")
func sync_transform(pos: Vector3, rot_y: float) -> void:
	global_position = global_position.lerp(pos, 0.3)
	if visual_root:
		visual_root.rotation.y = rot_y

func perform_attack() -> void:
	# Sword swing visual
	var orig_rot = visual_root.rotation.y
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:y", orig_rot + 0.6, 0.08)
	tween.tween_property(visual_root, "rotation:y", orig_rot - 0.4, 0.12)
	tween.tween_property(visual_root, "rotation:y", orig_rot, 0.1)
	
	# Find monster in range (melee attack: 2.5 meters in front)
	var space_state = get_world_3d().direct_space_state
	var forward = -visual_root.global_transform.basis.z.normalized()
	var attack_center = global_position + forward * 1.5 + Vector3(0, 0.5, 0)
	
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m.has_method("take_damage"):
			var dist = attack_center.distance_to(m.global_position)
			if dist < 2.2:
				var res = CombatFormulas.calculate_damage(stats, m.stats, 1.2, CombatFormulas.DamageType.PHY)
				m.take_damage(res, self)
				break

func perform_skill_1() -> void:
	if stats["mp"] < 15:
		return
	stats["mp"] -= 15
	# Fire burst attack
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m.has_method("take_damage"):
			var dist = global_position.distance_to(m.global_position)
			if dist < 4.5:
				var res = CombatFormulas.calculate_damage(stats, m.stats, 2.0, CombatFormulas.DamageType.FIRE)
				m.take_damage(res, self)

func perform_skill_2() -> void:
	# Dash
	var forward = -visual_root.global_transform.basis.z.normalized()
	velocity += forward * 14.0
