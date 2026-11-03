class_name Player
extends CharacterBody3D

const CombatFormulas = preload("res://shared/combat/combat_formulas.gd")

@export var move_speed: float = 6.0
@export var rotation_speed: float = 14.0
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

# Mobile Touch Tracking
var touches: Dictionary = {}
var pinch_start_dist: float = 0.0
var pinch_start_cam_dist: float = 9.0

func _ready() -> void:
	if is_local_player:
		camera.make_current()
		_update_camera_orbit()
	else:
		spring_arm.queue_free()

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
		
	# Native Android Touch Handling
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 2:
				# Start pinch gesture
				var t_keys = touches.keys()
				pinch_start_dist = touches[t_keys[0]].distance_to(touches[t_keys[1]])
				pinch_start_cam_dist = cam_dist
			elif touches.size() == 1:
				# Check if tapping to select an object in 3D world (right 55% of screen)
				var vp_size = get_viewport().get_visible_rect().size
				if event.position.x > vp_size.x * 0.45:
					_raycast_target_select(event.position)
		else:
			touches.erase(event.index)
			if touches.size() < 2:
				pinch_start_dist = 0.0
				
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			# Pinch to Zoom
			var t_keys = touches.keys()
			var current_dist = touches[t_keys[0]].distance_to(touches[t_keys[1]])
			if pinch_start_dist > 10.0:
				var zoom_factor = pinch_start_dist / maxf(1.0, current_dist)
				cam_dist = clampf(pinch_start_cam_dist * zoom_factor, 4.0, 16.0)
				_update_camera_orbit()
		elif touches.size() == 1:
			# Single finger camera orbit (right 55% of screen)
			var vp_size = get_viewport().get_visible_rect().size
			if event.position.x > vp_size.x * 0.45 and event.position.y < vp_size.y * 0.85:
				cam_rot_h -= event.relative.x * 0.35
				cam_rot_v = clampf(cam_rot_v - event.relative.y * 0.25, -65.0, -15.0)
				_update_camera_orbit()

func _raycast_target_select(screen_pos: Vector2) -> void:
	var from = camera.project_ray_origin(screen_pos)
	var to = from + camera.project_ray_normal(screen_pos) * 100.0
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to, 4) # Mask 4 = Monsters / NPCs
	var result = space.intersect_ray(query)
	if result:
		var collider = result.collider
		if collider is Monster or collider is NPC:
			current_target = collider
			print("[Player] Selected target: ", collider.name)

func _update_camera_orbit() -> void:
	if spring_arm:
		spring_arm.rotation_degrees = Vector3(cam_rot_v, cam_rot_h, 0)
		spring_arm.spring_length = cam_dist

func set_move_vector(input_vec: Vector2) -> void:
	move_direction = input_vec

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
		
	var dir_2d = move_direction
	if dir_2d.length() > 0.05:
		# True camera-relative movement:
		# -Z of camera basis is forward, +X is right
		var cam_basis = camera.global_transform.basis
		var cam_forward = -cam_basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		
		var cam_right = cam_basis.x
		cam_right.y = 0.0
		cam_right = cam_right.normalized()
		
		# Joystick UP has negative Y -> moves forward
		# Joystick RIGHT has positive X -> moves right
		var wish_dir = (cam_forward * (-dir_2d.y) + cam_right * dir_2d.x).normalized()
		
		velocity.x = wish_dir.x * move_speed
		velocity.z = wish_dir.z * move_speed
		
		# Smoothly rotate visual toward movement direction
		var target_angle = atan2(-wish_dir.x, -wish_dir.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, rotation_speed * delta)
		
		# Stylized bobbing step
		visual_root.position.y = abs(sin(Time.get_ticks_msec() * 0.012)) * 0.12
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed * 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, move_speed * 10.0 * delta)
		visual_root.position.y = move_toward(visual_root.position.y, 0, delta * 3.0)
		
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0
		
	move_and_slide()

func perform_attack() -> void:
	# If we have a target monster, orient toward it
	if current_target and is_instance_valid(current_target):
		var to_target = (current_target.global_position - global_position).normalized()
		visual_root.rotation.y = atan2(-to_target.x, -to_target.z)
		
	# Sword swing visual
	var orig_rot = visual_root.rotation.y
	var tween = create_tween()
	tween.tween_property(visual_root, "rotation:y", orig_rot + 0.6, 0.08)
	tween.tween_property(visual_root, "rotation:y", orig_rot - 0.4, 0.12)
	tween.tween_property(visual_root, "rotation:y", orig_rot, 0.1)
	
	# Melee range check
	var forward = -visual_root.global_transform.basis.z.normalized()
	var attack_center = global_position + forward * 1.5 + Vector3(0, 0.5, 0)
	
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m.has_method("take_damage"):
			var dist = attack_center.distance_to(m.global_position)
			if dist < 2.5:
				var res = CombatFormulas.calculate_damage(stats, m.stats, 1.2, CombatFormulas.DamageType.PHY)
				m.take_damage(res, self)
				break

func perform_skill_1() -> void:
	if stats["mp"] < 15:
		return
	stats["mp"] -= 15
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m.has_method("take_damage"):
			var dist = global_position.distance_to(m.global_position)
			if dist < 5.0:
				var res = CombatFormulas.calculate_damage(stats, m.stats, 2.0, CombatFormulas.DamageType.FIRE)
				m.take_damage(res, self)

func perform_skill_2() -> void:
	var forward = -visual_root.global_transform.basis.z.normalized()
	velocity += forward * 15.0
