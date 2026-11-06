class_name Player
extends CharacterBody3D

const CombatFormulas = preload("res://shared/combat/combat_formulas.gd")

signal died()
signal respawned()
signal leveled_up(new_level: int)
signal exp_gained(amount: int)

@export var move_speed: float = 6.0
@export var rotation_speed: float = 14.0
@export var is_local_player: bool = true
@export var respawn_delay: float = 3.0

# Skill tuning
const ATTACK_COOLDOWN: float = 0.45
const FIRE_COOLDOWN: float = 4.0
const FIRE_MP_COST: int = 15
const FIRE_RADIUS: float = 5.0
const DASH_COOLDOWN: float = 2.5
const DASH_DURATION: float = 0.18
const DASH_SPEED: float = 20.0
const HP_REGEN_PER_SEC: float = 1.5
const MP_REGEN_PER_SEC: float = 2.5
const OUT_OF_COMBAT_DELAY: float = 4.0
const OUT_OF_COMBAT_REGEN_MULT: float = 4.0

@onready var visual_root: Node3D = $Visual
@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var move_direction: Vector2 = Vector2.ZERO
var current_target: Node3D = null
var nearby_npc: Node3D = null

# Combat Stats
var stats: Dictionary = {
	"name": "Мандрівник",
	"class_name": "见习战士",
	"level": 1,
	"exp": 0,
	"exp_to_next": 100,
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

# State
var is_dead: bool = false
var spawn_point: Vector3 = Vector3.ZERO
var respawn_timer: float = 0.0
var cooldowns: Dictionary = { "attack": 0.0, "fire": 0.0, "dash": 0.0 }
var dash_timer: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var time_since_combat: float = 99.0
var _hp_regen_acc: float = 0.0
var _mp_regen_acc: float = 0.0

# Camera Orbit & Zoom
var cam_rot_h: float = 0.0
var cam_rot_v: float = -35.0 # Isometric tilt
var cam_dist: float = 9.0

# Mobile Touch Tracking
var touches: Dictionary = {}
var pinch_start_dist: float = 0.0
var pinch_start_cam_dist: float = 9.0
var _tap_start_pos: Vector2 = Vector2.ZERO
var _tap_moved: bool = false
## Set by the world: returns true when a screen point is over HUD controls.
var ui_hit_test: Callable = Callable()
var controls_blocked: bool = false
var _camera_impulse: float = 0.0
var _mouse_orbit: bool = false
var _motion: HeroAvatar
var pathfinder: GridPathfinder = GridPathfinder.new()
var navigation_route: PackedVector3Array = []
var navigation_target: Vector3 = Vector3.ZERO
var _navigation_marker: MeshInstance3D
var _network_input_timer: float = 0.0
var original_skills: OriginalSkillController = OriginalSkillController.new()

func _is_reserved_touch(pos: Vector2) -> bool:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	# Left 45% (below the status panel) belongs to the floating joystick
	if pos.x < vp_size.x * 0.45 and pos.y > vp_size.y * 0.25:
		return true
	if ui_hit_test.is_valid() and ui_hit_test.call(pos):
		return true
	return false

func _ready() -> void:
	original_skills.player = self
	spawn_point = global_position
	CharacterSystem.ensure_stats(stats)
	TitleSystem.ensure_stats(stats)
	MountSystem.ensure_stats(stats)
	var mount_visual: MountVisual = MountVisual.new()
	mount_visual.player = self
	add_child(mount_visual)
	_motion = HeroAvatar.new()
	_motion.actor = self
	add_child(_motion)
	if is_local_player:
		camera.make_current()
		spring_arm.add_excluded_object(get_rid())
		spring_arm.collision_mask = 1|8
		_update_camera_orbit()
	else:
		spring_arm.queue_free()

func _input(event: InputEvent) -> void:
	if not is_local_player:
		return
	if controls_blocked:
		touches.clear()
		_mouse_orbit = false
		return

	# Native Android Touch Handling.
	# Only fingers that start on the "world" part of the screen are tracked here:
	# the joystick thumb and on-screen buttons are ignored so they never cause
	# accidental pinch-zoom or camera spin.
	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_reserved_touch(event.position):
				return
			touches[event.index] = event.position
			if touches.size() == 2:
				# Start pinch gesture
				var t_keys: Array = touches.keys()
				pinch_start_dist = touches[t_keys[0]].distance_to(touches[t_keys[1]])
				pinch_start_cam_dist = cam_dist
			elif touches.size() == 1:
				_tap_start_pos = event.position
				_tap_moved = false
		else:
			if touches.has(event.index):
				touches.erase(event.index)
				# Short tap without dragging = select target
				if touches.is_empty() and not _tap_moved:
					_raycast_target_select(event.position)
			if touches.size() < 2:
				pinch_start_dist = 0.0

	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() >= 2:
			# Pinch to Zoom
			_tap_moved = true
			var t_keys: Array = touches.keys()
			var current_dist: float = touches[t_keys[0]].distance_to(touches[t_keys[1]])
			if pinch_start_dist > 10.0:
				var zoom_factor: float = pinch_start_dist / maxf(1.0, current_dist)
				cam_dist = clampf(pinch_start_cam_dist * zoom_factor, 4.0, 16.0)
				_update_camera_orbit()
		else:
			# Single finger camera orbit
			if event.position.distance_to(_tap_start_pos) > 12.0:
				_tap_moved = true
			var sensitivity: float = float(SettingsStore.current().get_value("camera_sensitivity"))
			var sign_y: float = -1.0 if SettingsStore.current().get_value("invert_camera_y") else 1.0
			cam_rot_h -= event.relative.x * 0.35 * sensitivity
			cam_rot_v = clampf(cam_rot_v - event.relative.y * 0.25 * sensitivity * sign_y, -65.0, -15.0)
			_update_camera_orbit()

	# Mouse wheel zoom (PC testing)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist - 0.8, 4.0, 16.0)
			_update_camera_orbit()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist + 0.8, 4.0, 16.0)
			_update_camera_orbit()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_mouse_orbit = event.pressed
	elif event is InputEventMouseMotion and _mouse_orbit:
		var sensitivity: float = float(SettingsStore.current().get_value("camera_sensitivity"))
		var sign_y: float = -1.0 if SettingsStore.current().get_value("invert_camera_y") else 1.0
		cam_rot_h -= event.relative.x * 0.25 * sensitivity
		cam_rot_v = clampf(cam_rot_v - event.relative.y * 0.2 * sensitivity * sign_y, -65.0, -15.0)
		_update_camera_orbit()

func _raycast_target_select(screen_pos: Vector2) -> void:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * 100.0
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 4) # Mask 4 = Monsters / NPCs
	var result: Dictionary = space.intersect_ray(query)
	if result:
		var collider: Object = result.collider
		if collider is Monster or collider is NPC or (collider is Node and collider.has_meta("network_account")):
			current_target = collider
			print("[Player] Selected target: ", collider.name)

func _update_camera_orbit() -> void:
	if spring_arm:
		spring_arm.rotation_degrees = Vector3(cam_rot_v, cam_rot_h, 0)
		spring_arm.spring_length = cam_dist

func set_move_vector(input_vec: Vector2) -> void:
	move_direction = input_vec
	if input_vec.length() > 0.05:
		cancel_navigation()

func navigate_to(destination: Vector3) -> bool:
	if is_dead:
		return false
	navigation_route = pathfinder.find_route(global_position,destination,get_world_3d().direct_space_state)
	if navigation_route.is_empty():
		return false
	navigation_target = destination
	if not is_instance_valid(_navigation_marker):
		_navigation_marker = MeshInstance3D.new()
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = 0.6
		ring.outer_radius = 0.8
		_navigation_marker.mesh = ring
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.2,0.8,1.0)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_navigation_marker.material_override = material
		get_parent().add_child(_navigation_marker)
	_navigation_marker.global_position = destination + Vector3(0,0.1,0)
	_navigation_marker.show()
	return true

func cancel_navigation() -> void:
	navigation_route.clear()
	if is_instance_valid(_navigation_marker):
		_navigation_marker.hide()

func _process(delta: float) -> void:
	if not is_local_player:
		return
	if not get_meta("network_world",false):
		ItemEffects.tick(stats,delta)
		original_skills.tick(delta)
	if stats.get("mounted",false) and MountSystem.seconds_left(stats,int(stats.get("mount_id",0))) <= 0.0:
		MountSystem.dismount(stats)
		var hud: Node = get_tree().get_first_node_in_group("hud")
		if hud:
			hud.on_systems_changed()
	_camera_impulse = move_toward(_camera_impulse, 0.0, delta * 2.5)
	camera.h_offset = sin(Time.get_ticks_msec() * 0.075) * _camera_impulse * 0.06
	camera.v_offset = cos(Time.get_ticks_msec() * 0.095) * _camera_impulse * 0.04
	if get_meta("network_world",false):
		return
	for key: String in cooldowns:
		if cooldowns[key] > 0.0:
			cooldowns[key] = maxf(0.0, cooldowns[key] - delta)
	if is_dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()
		return
	time_since_combat += delta
	_regenerate(delta)

func _regenerate(delta: float) -> void:
	var mult: float = OUT_OF_COMBAT_REGEN_MULT if time_since_combat > OUT_OF_COMBAT_DELAY else 1.0
	if stats["hp"] < stats["max_hp"]:
		_hp_regen_acc += (HP_REGEN_PER_SEC*mult+float(stats.get("hp_regen_bonus",0))) * delta
		if _hp_regen_acc >= 1.0:
			var gain: int = int(_hp_regen_acc)
			_hp_regen_acc -= gain
			stats["hp"] = mini(stats["max_hp"], stats["hp"] + gain)
	else:
		_hp_regen_acc = 0.0
	if stats["mp"] < stats["max_mp"]:
		_mp_regen_acc += (MP_REGEN_PER_SEC*mult+float(stats.get("mp_regen_bonus",0))) * delta
		if _mp_regen_acc >= 1.0:
			var gain_mp: int = int(_mp_regen_acc)
			_mp_regen_acc -= gain_mp
			stats["mp"] = mini(stats["max_mp"], stats["mp"] + gain_mp)
	else:
		_mp_regen_acc = 0.0

func _physics_process(delta: float) -> void:
	if not is_local_player:
		return
	if get_meta("network_world",false):
		_network_move(delta)
		return
	if StatusEffects.speed_multiplier(stats) <= 0.0: dash_timer = 0.0

	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
	elif dash_timer > 0.0:
		dash_timer -= delta
		velocity.x = dash_dir.x * DASH_SPEED
		velocity.z = dash_dir.z * DASH_SPEED
	else:
		var dir_2d: Vector2 = move_direction
		if controls_blocked:
			dir_2d = Vector2.ZERO
		elif not navigation_route.is_empty():
			while not navigation_route.is_empty() and Vector2(global_position.x-navigation_route[0].x,global_position.z-navigation_route[0].z).length() < 0.4:
				navigation_route.remove_at(0)
			if navigation_route.is_empty():
				cancel_navigation()
			else:
				var wish: Vector3 = (navigation_route[0]-global_position).normalized()
				var forward: Vector3 = -camera.global_basis.z
				forward.y = 0.0
				forward = forward.normalized()
				var right: Vector3 = camera.global_basis.x
				right.y = 0.0
				right = right.normalized()
				dir_2d = Vector2(wish.dot(right),-wish.dot(forward))
		if dir_2d.length() > 0.05:
			# True camera-relative movement:
			# -Z of camera basis is forward, +X is right
			var cam_basis: Basis = camera.global_transform.basis
			var cam_forward: Vector3 = -cam_basis.z
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()

			var cam_right: Vector3 = cam_basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()

			# Joystick UP has negative Y -> moves forward
			# Joystick RIGHT has positive X -> moves right
			var wish_dir: Vector3 = (cam_forward * (-dir_2d.y) + cam_right * dir_2d.x).normalized()
			var speed_scale: float = clampf(dir_2d.length(), 0.0, 1.0)

			velocity.x = wish_dir.x * move_speed * speed_scale * MountSystem.speed_multiplier(stats) * StatusEffects.speed_multiplier(stats)
			velocity.z = wish_dir.z * move_speed * speed_scale * MountSystem.speed_multiplier(stats) * StatusEffects.speed_multiplier(stats)

			# Smoothly rotate visual toward movement direction
			var target_angle: float = atan2(-wish_dir.x, -wish_dir.z)
			visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, rotation_speed * delta)

			visual_root.position.y = move_toward(visual_root.position.y, 0.85 if stats.get("mounted",false) else 0.0, delta * 3.0)
		else:
			velocity.x = move_toward(velocity.x, 0, move_speed * 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0, move_speed * 10.0 * delta)
			visual_root.position.y = move_toward(visual_root.position.y, 0.85 if stats.get("mounted",false) else 0.0, delta * 3.0)

	# Apply gravity
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0

	move_and_slide()

	# Safety net: fell through the world
	if global_position.y < -30.0:
		global_position = spawn_point
		velocity = Vector3.ZERO

# ---------------------------------------------------------------- Combat ---

func get_cooldown_left(skill: String) -> float:
	if skill.begins_with("slot"):
		var id: int = int(stats.get("hotbar",{}).get(skill.trim_prefix("slot"),0))
		return float(stats.get("skill_cooldowns",{}).get(str(id),0))
	if skill == "fire":
		var id: int = int(stats.get("hotbar",{}).get("1",0))
		if SkillRules.catalog().has(id): return float(stats.get("skill_cooldowns",{}).get(str(id),0))
	return cooldowns.get(skill, 0.0)

func perform_attack() -> void:
	if get_meta("network_world",false):
		# Online the server decides the hit; the swing plays at once so the
		# button always answers (the damage number arrives with the event).
		if is_dead or controls_blocked or not MountSystem.can_attack(stats) or cooldowns["attack"] > 0.0:
			return
		cooldowns["attack"] = ATTACK_COOLDOWN
		time_since_combat = 0.0
		_face_attack_target()
		_motion.strike_left = 0.35
		CombatFeedback.arc(get_parent(), global_position, visual_root.rotation.y, Color(0.75, 0.92, 1.0, 0.8))
		CombatFeedback.sound(self, "swing", -20.0)
		_network_action("attack")
		return
	if is_dead or controls_blocked or not MountSystem.can_attack(stats) or cooldowns["attack"] > 0.0:
		return
	cooldowns["attack"] = ATTACK_COOLDOWN
	time_since_combat = 0.0

	# Auto-face: selected target, otherwise nearest monster in reach
	var face_target: Node3D = null
	if current_target is Monster and is_instance_valid(current_target) \
			and not current_target.is_dead() and global_position.distance_to(current_target.global_position) < 4.0:
		face_target = current_target
	else:
		face_target = _nearest_monster(3.5)
		if face_target:
			current_target = face_target
	if face_target:
		var to_target: Vector3 = face_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.01:
			to_target = to_target.normalized()
			visual_root.rotation.y = atan2(-to_target.x, -to_target.z)

	# Sword swing visual
	var orig_rot: float = visual_root.rotation.y
	_motion.strike_left = 0.35
	CombatFeedback.arc(get_parent(), global_position, orig_rot, Color(0.75, 0.92, 1.0, 0.8))
	CombatFeedback.sound(self, "swing", -20.0)

	# Melee range check (closest monster in front)
	var forward: Vector3 = -visual_root.global_transform.basis.z.normalized()
	var attack_center: Vector3 = global_position + forward * 1.5
	var best: Monster = null
	var best_dist: float = 2.5
	for m: Node in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and not m.is_dead():
			var dist: float = attack_center.distance_to(m.global_position)
			if dist < best_dist:
				best_dist = dist
				best = m
	if best:
		var res: Dictionary = CombatFormulas.calculate_damage(stats, best.stats, 1.2, CombatFormulas.DamageType.PHY)
		best.take_damage(res, self)
		if not res.get("is_miss", false):
			_camera_impulse = 0.5
			CombatFeedback.sound(self, "hit", -16.0)

## Turns toward the selected target, or the nearest monster in reach.
func _face_attack_target() -> void:
	var face_target: Node3D = null
	if is_instance_valid(current_target) and current_target is Node3D and global_position.distance_to(current_target.global_position) < 4.0 			and not (current_target is Monster and current_target.is_dead()):
		face_target = current_target
	else:
		face_target = _nearest_monster(3.5)
		if face_target:
			current_target = face_target
	if face_target:
		var to_target: Vector3 = face_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.01:
			to_target = to_target.normalized()
			visual_root.rotation.y = atan2(-to_target.x, -to_target.z)

## Online skill: the cast or strike plays at once, the server resolves it.
func _network_skill(slot: String) -> void:
	if is_dead or controls_blocked:
		return
	var id: int = int(stats.get("hotbar",{}).get(slot,0))
	var effect: String = str(CharacterSystem.SKILLS.get(id,{}).get("effect",""))
	if effect != "heal":
		_face_attack_target()
	if effect in ["fire", "ice", "heal"] or int(stats.get("class_id", 130001)) in HeroAvatar.MAGE_CLASSES:
		_motion.cast()
	else:
		_motion.strike_left = 0.35
	set_meta("predicted_skill_until", Time.get_ticks_msec() + 900)
	_network_action("skill", slot)

func perform_skill_1() -> void:
	if get_meta("network_world",false):
		_network_skill("1")
		return
	if is_dead or controls_blocked:
		return
	var id: int = int(stats.get("hotbar",{}).get("1",0))
	if SkillRules.catalog().has(id):
		original_skills.cast()
		return
	if cooldowns["fire"] > 0.0:
		return
	var rank: int = int(stats.get("skills",{}).get(str(id),0))
	if not CharacterSystem.SKILLS.has(id) or rank <= 0:
		_float_text(global_position+Vector3.UP*2,"Признач навичку в меню",Color.SKY_BLUE)
		return
	var skill: Dictionary = CharacterSystem.SKILLS[id]
	var effect: String = skill["effect"]
	if not MountSystem.can_attack(stats) and effect != "heal":
		return
	var target: Monster = null
	if effect != "heal":
		var reach: float = 12.0 if effect == "fire" else 6.0 if effect == "ice" else 3.5
		if is_instance_valid(current_target) and current_target is Monster and not current_target.is_dead() and global_position.distance_to(current_target.global_position) <= reach:
			target = current_target
		else:
			target = _nearest_monster(reach)
		if target == null:
			_float_text(global_position+Vector3.UP*2,"Ціль поза досяжністю",Color.SKY_BLUE)
			return
	if int(stats["mp"]) < int(skill["mp"]):
		_float_text(global_position+Vector3.UP*2,"Недостатньо мани",Color.SKY_BLUE)
		return
	if effect == "heal" and int(stats["hp"]) >= int(stats["max_hp"]):
		return
	stats["mp"] -= int(skill["mp"])
	cooldowns["fire"] = float(skill["cooldown"])
	time_since_combat = 0.0
	match effect:
		"heal":
			stats["hp"] = mini(int(stats["max_hp"]),int(stats["hp"])+20+rank*12)
			CombatFeedback.arc(get_parent(),global_position,0,Color(0.3,1,0.5,0.8),1.5)
			Vfx.heal(get_parent(),global_position)
		"heavy":
			current_target = target
			var result: Dictionary = CombatFormulas.calculate_damage(stats,target.stats,2.0+rank*0.2,CombatFormulas.DamageType.PHY)
			target.take_damage(result,self)
			CombatFeedback.arc(get_parent(),global_position,visual_root.rotation.y,Color.GOLD,2.7)
			_motion.strike_left = 0.35
		"fire", "ice":
			current_target = target
			_motion.cast()
			_cast_projectile(target,rank,effect == "ice")

func _cast_projectile(target: Monster, rank: int, ice: bool) -> void:
	var projectile: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	projectile.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.6,1.9,2.5) if ice else Color(2.6,1.0,0.2)   # HDR so the bolt blooms
	projectile.material_override = material
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3.UP*1.2
	var destination: Vector3 = target.global_position + Vector3.UP
	var duration: float = maxf(0.12,projectile.global_position.distance_to(destination)/22.0)
	var tween: Tween = projectile.create_tween()
	tween.tween_property(projectile,"global_position",destination,duration)
	tween.finished.connect(func() -> void:
		if is_instance_valid(target) and not target.is_dead() and target.global_position.distance_to(destination-Vector3.UP) < 1.8:
			var result: Dictionary = CombatFormulas.calculate_damage(stats,target.stats,(1.5 if ice else 2.0)+rank*0.2,CombatFormulas.DamageType.WATER if ice else CombatFormulas.DamageType.FIRE)
			target.take_damage(result,self)
			if ice:
				Vfx.ice(get_parent(),destination)
			else:
				Vfx.fire(get_parent(),destination)
			if ice and not result.get("is_miss",false):
				target.slow_timer = 3.0
		projectile.queue_free())
	CombatFeedback.sound(self,"fire",-19.0)

func perform_skill_2() -> void:
	if get_meta("network_world",false):
		_network_action("dash")
		return
	if is_dead or controls_blocked or cooldowns["dash"] > 0.0 or StatusEffects.speed_multiplier(stats) <= 0.0:
		return
	cooldowns["dash"] = DASH_COOLDOWN
	var forward: Vector3 = -visual_root.global_transform.basis.z
	forward.y = 0.0
	dash_dir = forward.normalized()
	dash_timer = DASH_DURATION
	_motion.dodge()
	CombatFeedback.sound(self, "swing", -23.0)

func _nearest_monster(max_dist: float) -> Monster:
	var best: Monster = null
	var best_dist: float = max_dist
	for m: Node in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and not m.is_dead():
			var d: float = global_position.distance_to(m.global_position)
			if d < best_dist:
				best_dist = d
				best = m
	return best

func _spawn_fire_nova() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	mesh_inst.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.1, 0.9)
	mesh_inst.material_override = mat
	get_parent().add_child(mesh_inst)
	mesh_inst.global_position = global_position + Vector3(0, 0.4, 0)
	var tween: Tween = mesh_inst.create_tween().set_parallel(true)
	tween.tween_property(mesh_inst, "scale", Vector3.ONE * FIRE_RADIUS, 0.35)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.finished.connect(mesh_inst.queue_free)

# ------------------------------------------------------- Damage / Death ---

func take_damage(amount: int) -> void:
	if get_meta("network_world",false):
		return
	if is_dead or dash_timer > 0.0:
		return
	_camera_impulse = 1.0
	amount = maxi(1,roundi(float(amount)*MountSystem.damage_multiplier(stats))) if amount > 0 else 0
	amount = StatusEffects.absorb(stats,amount)
	time_since_combat = 0.0
	stats["hp"] = maxi(0, stats["hp"] - amount)
	_float_text(global_position + Vector3(0, 1.5, 0), str(amount), Color(1, 0.3, 0.3))
	if stats["hp"] <= 0:
		die()
	elif amount > 0:
		_motion.hurt()

func die() -> void:
	stats["skill_effects"] = []
	is_dead = true
	MountSystem.dismount(stats)
	cancel_navigation()
	respawn_timer = respawn_delay
	dash_timer = 0.0
	current_target = null
	_motion.die()
	died.emit()

func respawn() -> void:
	is_dead = false
	global_position = spawn_point
	velocity = Vector3.ZERO
	visual_root.rotation.x = 0.0
	_motion.revive()
	stats["hp"] = stats["max_hp"]
	stats["mp"] = stats["max_mp"]
	time_since_combat = 99.0
	respawned.emit()

# --------------------------------------------------------- Progression ---

func gain_exp(amount: int) -> void:
	if get_meta("network_world",false):
		return
	if amount <= 0:
		return
	stats["exp"] += amount
	exp_gained.emit(amount)
	while stats["exp"] >= stats["exp_to_next"]:
		stats["exp"] -= stats["exp_to_next"]
		_level_up()

func _level_up() -> void:
	stats["level"] += 1
	var lv: int = stats["level"]
	stats["exp_to_next"] = int(100.0 * pow(1.35, lv - 1))
	stats["max_hp"] += 15
	stats["max_mp"] += 8
	stats["attack"] += 3
	stats["defense"] += 2
	stats["stat_points"] = int(stats.get("stat_points",0)) + 3
	stats["skill_points"] = int(stats.get("skill_points",0)) + 1
	stats["hp"] = stats["max_hp"]
	stats["mp"] = stats["max_mp"]
	_float_text(global_position + Vector3(0, 2.2, 0), "LEVEL UP! Lv.%d" % lv, Color.GOLD)
	Vfx.pillar(get_parent(), global_position)
	leveled_up.emit(lv)

func _float_text(world_pos: Vector3, text: String, color: Color) -> void:
	if not SettingsStore.current().get_value("show_damage"):
		return
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("spawn_floating_text") and camera:
		hud.spawn_floating_text(camera.unproject_position(world_pos), text, color)

func _network_action(action: String, slot: String = "1") -> void:
	if is_dead or controls_blocked:
		return
	var target: Dictionary = {}
	if is_instance_valid(current_target):
		if current_target is Monster:
			target = {"kind":"monster","id":str(current_target.name)}
		elif current_target.has_meta("network_account"):
			target = {"kind":"player","id":int(current_target.get_meta("network_account"))}
	var payload: Dictionary = {"target":target} if action != "dash" else {}
	if action == "skill":
		payload["slot"] = slot
		var id: int = int(stats.get("hotbar",{}).get(slot,0))
		if CharacterSystem.SKILLS.get(id,{}).get("effect") == "heal": payload["target"] = {}
	get_node("/root/NetworkManager").request("game_"+action,payload)

func perform_assigned_skill(slot: String) -> void:
	if slot not in ["1","2","3","4"]: return
	if slot == "1":
		perform_skill_1()
		return
	if get_meta("network_world",false):
		_network_skill(slot)
		return
	if is_dead or controls_blocked: return
	if not original_skills.cast(slot):
		var id: int = int(stats.get("hotbar",{}).get(slot,0))
		if id == 0: _float_text(global_position+Vector3.UP*2,"Признач навичку в меню",Color.SKY_BLUE)

func _network_move(delta: float) -> void:
	var wish: Vector3 = Vector3.ZERO
	if not controls_blocked and not is_dead:
		if not navigation_route.is_empty():
			while not navigation_route.is_empty() and global_position.distance_to(navigation_route[0]) < 0.55:
				navigation_route.remove_at(0)
			if not navigation_route.is_empty():
				wish = navigation_route[0]-global_position
			else:
				cancel_navigation()
		else:
			var forward: Vector3 = -camera.global_basis.z
			var right: Vector3 = camera.global_basis.x
			forward.y = 0.0
			right.y = 0.0
			wish = forward.normalized()*(-move_direction.y)+right.normalized()*move_direction.x
	wish.y = 0.0
	wish = wish.limit_length(1.0)
	if wish.length() > 0.05:
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y,atan2(-wish.x,-wish.z),rotation_speed*delta)
	_network_input_timer -= delta
	if _network_input_timer <= 0.0:
		_network_input_timer = 0.05
		get_node("/root/NetworkManager").send_world_input(Vector2(wish.x,wish.z),visual_root.rotation.y)
	velocity = wish*move_speed*MountSystem.speed_multiplier(stats)*StatusEffects.speed_multiplier(stats)
	# Local prediction is corrected from server snapshots; it never awards combat.
	move_and_slide()
