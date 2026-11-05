class_name Monster
extends CharacterBody3D

signal monster_died(monster: Monster, killer: Node3D)

enum State { IDLE, CHASE, ATTACK, RETURN, DEAD }

@export var monster_id: int = 1001
@export var monster_name: String = "Лісовий звір"
@export var max_hp: int = 60
@export var current_hp: int = 60
@export var move_speed: float = 3.5
@export var aggro_radius: float = 7.0
@export var attack_radius: float = 1.8
@export var attack_damage: int = 12
@export var exp_reward: int = 0 # 0 = derive from max_hp / attack
@export var respawn_time: float = 8.0
@export var leash_radius: float = 18.0
## Optional model that replaces the default beast mesh (e.g. boar / spider GLB).
@export var model_scene: PackedScene
@export var model_scale: float = 1.0

var state: State = State.IDLE
var spawn_point: Vector3 = Vector3.ZERO
var target_player: Node3D = null
var attack_cooldown: float = 0.0
var respawn_timer: float = 0.0
var windup_left: float = 0.0
var slow_timer: float = 0.0
var _telegraph: MeshInstance3D
var _attack_point: Vector3
var threat: Dictionary = {}
var animator: MobAnimator
const WINDUP_TIME: float = 0.65

@onready var visual_root: Node3D = $Visual
@onready var name_label: Label3D = $NameLabel
@onready var hp_bar_3d: Label3D = $HPLabel

var stats: Dictionary = {
	"defense": 4,
	"evasion": 0.05,
	"element": 1 # PHY
}

func _ready() -> void:
	if model_scene:
		for c: Node in visual_root.get_children():
			c.queue_free()
		var model: Node3D = model_scene.instantiate()
		model.scale = Vector3.ONE * model_scale
		visual_root.add_child(model)
	CharacterMotion.prepare_palette(visual_root)
	spawn_point = global_position
	current_hp = max_hp
	if exp_reward <= 0:
		exp_reward = int(max_hp * 0.5 + attack_damage * 1.5)
	_update_labels()
	add_to_group("monsters")
	_build_telegraph()

func is_dead() -> bool:
	return state == State.DEAD

func _is_valid_target(p: Node3D) -> bool:
	return p != null and is_instance_valid(p) and p.get("is_dead") != true

func _physics_process(delta: float) -> void:
	if get_meta("network_world",false):
		return
	StatusEffects.tick(stats,delta)
	refresh_status_stats()
	if state != State.DEAD and StatusEffects.speed_multiplier(stats) <= 0.0: return
	slow_timer = maxf(0.0,slow_timer-delta)
	if not is_on_floor():
		velocity.y -= 19.6 * delta

	if state == State.DEAD:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			respawn()
		move_and_slide()
		return

	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if windup_left > 0.0:
		windup_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		_telegraph.scale = Vector3.ONE * lerpf(0.4, 1.0, 1.0 - windup_left / WINDUP_TIME)
		if windup_left <= 0.0:
			_resolve_attack()
		move_and_slide()
		return

	if not _is_valid_target(target_player):
		target_player = best_threat_target()
		if not _is_valid_target(target_player):
			if state == State.CHASE or state == State.ATTACK: state = State.RETURN
			if state == State.IDLE: _find_nearest_player()

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta * 10.0)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta * 10.0)
			if target_player and global_position.distance_to(target_player.global_position) <= aggro_radius:
				state = State.CHASE

		State.CHASE:
			var dist: float = global_position.distance_to(target_player.global_position)
			var chase_distance: float = leash_radius if threat.has(target_player) else aggro_radius*1.5
			if dist > chase_distance or global_position.distance_to(spawn_point) > leash_radius:
				target_player = null
				state = State.RETURN
			elif dist <= attack_radius:
				state = State.ATTACK
				velocity.x = 0
				velocity.z = 0
			else:
				_move_towards(target_player.global_position, move_speed, delta)

		State.ATTACK:
			velocity.x = 0
			velocity.z = 0
			var dist_a: float = global_position.distance_to(target_player.global_position)
			if dist_a > attack_radius:
				state = State.CHASE
			elif attack_cooldown <= 0.0:
				_execute_attack()

		State.RETURN:
			var home_dist: float = Vector2(global_position.x - spawn_point.x, global_position.z - spawn_point.z).length()
			if home_dist < 0.6:
				state = State.IDLE
				velocity.x = 0
				velocity.z = 0
				# Heal up when back home
				current_hp = max_hp
				threat.clear()
				_update_labels()
			else:
				_move_towards(spawn_point, move_speed * 1.3, delta)

	move_and_slide()

func _move_towards(pos: Vector3, speed: float, delta: float) -> void:
	var dir: Vector3 = pos - global_position
	dir.y = 0.0
	dir = dir.normalized()
	velocity.x = dir.x * speed * (0.45 if slow_timer > 0.0 else 1.0)
	velocity.z = dir.z * speed * (0.45 if slow_timer > 0.0 else 1.0)
	var target_angle: float = atan2(-dir.x, -dir.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 10.0 * delta)

func _find_nearest_player() -> void:
	var closest_dist: float = aggro_radius
	var best_player: Node3D = null
	for p: Node in get_tree().get_nodes_in_group("players"):
		if p is Node3D and _is_valid_target(p):
			var d: float = global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				best_player = p
	target_player = best_player

func _execute_attack() -> void:
	attack_cooldown = 1.4
	windup_left = WINDUP_TIME
	_attack_point = target_player.global_position
	var dir: Vector3 = _attack_point - global_position
	visual_root.rotation.y = atan2(-dir.x, -dir.z)
	_telegraph.show()
	_telegraph.scale = Vector3.ONE * 0.4
	if animator:
		animator.attack(WINDUP_TIME)
		return
	var anticipation: Tween = create_tween()
	anticipation.tween_property(visual_root, "rotation:x", -0.22, WINDUP_TIME * 0.8)

func _resolve_attack() -> void:
	_telegraph.hide()
	visual_root.rotation.x = 0.0
	if animator == null:
		# Visual lunge for unrigged models
		var orig_z: float = visual_root.position.z
		var tween: Tween = create_tween()
		tween.tween_property(visual_root, "position:z", orig_z + 0.3, 0.1)
		tween.tween_property(visual_root, "position:z", orig_z, 0.15)

	# The warning is committed at the start of the swing. Moving or dashing
	# away during the windup avoids the hit; enemies cannot hit at any range.
	if _is_valid_target(target_player) and global_position.distance_to(target_player.global_position) <= attack_radius + 0.35 and target_player.global_position.distance_to(_attack_point) < 1.5:
		var pstats: Variant = target_player.get("stats")
		if pstats is Dictionary:
			var attack_stats: Dictionary = {"attack": attack_damage, "accuracy": 1.0, "crit_rate": 0.0}
			var result: Dictionary = CombatFormulas.calculate_damage(attack_stats, pstats)
			var dmg: int = int(result["damage"])
			if target_player.has_method("take_damage"):
				target_player.take_damage(dmg)
			else:
				pstats["hp"] = maxi(0, pstats["hp"] - dmg)
				_spawn_damage_text(target_player.global_position + Vector3(0, 1.5, 0), str(dmg), Color(1, 0.3, 0.3))

func take_damage(dmg_result: Dictionary, attacker: Node3D) -> void:
	if get_meta("network_world",false):
		return
	if state == State.DEAD:
		return
	var dmg: int = dmg_result.get("damage", 10)
	var is_crit: bool = dmg_result.get("is_critical", false)
	var is_miss: bool = dmg_result.get("is_miss", false)

	# Aggro onto attacker
	if _is_valid_target(attacker):
		add_threat(attacker,0.1 if is_miss else float(dmg))
		if state != State.ATTACK:
			state = State.CHASE

	if is_miss:
		_spawn_damage_text(global_position + Vector3(0, 1.2, 0), "MISS", Color.GRAY)
		return

	current_hp = maxi(0, current_hp - dmg)
	_update_labels()

	# Damage text & flash
	var txt: String = str(dmg)
	var col: Color = Color.GOLD if is_crit else Color.WHITE
	if is_crit:
		txt = "CRIT! " + txt
	_spawn_damage_text(global_position + Vector3(0, 1.4, 0), txt, col)

	# Hurt reaction
	if animator:
		animator.hit()
	else:
		var tween: Tween = create_tween()
		tween.tween_property(visual_root, "scale", Vector3.ONE * 1.2, 0.06)
		tween.tween_property(visual_root, "scale", Vector3.ONE, 0.08)

	if current_hp <= 0:
		die(attacker)

func die(killer: Node3D) -> void:
	threat.clear()
	state = State.DEAD
	windup_left = 0.0
	_telegraph.hide()
	visual_root.rotation.x = 0.0
	target_player = null
	velocity = Vector3.ZERO
	respawn_timer = respawn_time
	_spawn_damage_text(global_position + Vector3(0, 1.6, 0), "+%d EXP" % exp_reward, Color.SPRING_GREEN)
	if killer and is_instance_valid(killer) and killer.has_method("gain_exp"):
		killer.gain_exp(exp_reward)
	monster_died.emit(self, killer)

	# Notify HUD for quest
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_monster_kill") and killer is Player and killer.is_local_player:
		hud.add_monster_kill(monster_id)

	name_label.hide()
	hp_bar_3d.hide()
	# Death: play the clip, then sink out of sight
	var tween: Tween = create_tween()
	if animator:
		animator.die()
		tween.tween_interval(2.2)
	tween.tween_property(visual_root, "position:y", -1.2, 0.5)
	$CollisionShape3D.set_deferred("disabled", true)

func respawn() -> void:
	threat.clear()
	stats["skill_effects"] = []
	state = State.IDLE
	windup_left = 0.0
	attack_cooldown = 0.0
	_telegraph.hide()
	global_position = spawn_point + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	current_hp = max_hp
	visual_root.position.y = 0
	visual_root.scale = Vector3.ONE
	if animator:
		animator.revive()
	$CollisionShape3D.set_deferred("disabled", false)
	name_label.show()
	hp_bar_3d.show()
	_update_labels()

func refresh_status_stats() -> void:
	if not stats.has("base_defense"): stats["base_defense"] = stats.get("defense",4)
	var modifiers: Dictionary = StatusEffects.modifiers(stats)
	stats["defense"] = maxf(0.0,(float(stats["base_defense"])+float(modifiers.get("defense_add",0)))*(1.0+float(modifiers.get("defense_rate",0))))
	stats["resist"] = maxf(0.0,float(modifiers.get("resist_add",0))*(1.0+float(modifiers.get("resist_rate",0))))

func add_threat(attacker: Node3D, amount: float) -> void:
	if not _is_valid_target(attacker): return
	threat[attacker] = float(threat.get(attacker,0))+maxf(0.1,amount)
	target_player = best_threat_target()

func best_threat_target() -> Node3D:
	var best: Node3D = null
	var highest: float = -1.0
	for actor: Variant in threat.keys():
		if not is_instance_valid(actor) or not _is_valid_target(actor) or global_position.distance_to(actor.global_position) > leash_radius:
			threat.erase(actor)
		elif float(threat[actor]) > highest:
			highest = float(threat[actor])
			best = actor
	return best

func _build_telegraph() -> void:
	_telegraph = MeshInstance3D.new()
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = attack_radius - 0.15
	ring.outer_radius = attack_radius + 0.15
	ring.rings = 28
	ring.ring_segments = 6
	_telegraph.mesh = ring
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.22, 0.08)
	_telegraph.material_override = mat
	_telegraph.position.y = 0.08
	_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_telegraph)
	_telegraph.hide()

func _update_labels() -> void:
	name_label.text = monster_name
	hp_bar_3d.text = "HP: %d / %d" % [current_hp, max_hp]
	if current_hp < max_hp * 0.35:
		hp_bar_3d.modulate = Color(1, 0.2, 0.2)
	else:
		hp_bar_3d.modulate = Color(0.2, 1, 0.3)

func _spawn_damage_text(world_pos: Vector3, text: String, color: Color) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("spawn_floating_text"):
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam:
			var screen_pos: Vector2 = cam.unproject_position(world_pos)
			hud.spawn_floating_text(screen_pos, text, color)
