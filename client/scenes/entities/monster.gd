class_name Monster
extends CharacterBody3D

signal monster_died(monster: Monster, killer: Node3D)

enum State { IDLE, CHASE, ATTACK, DEAD }

@export var monster_id: int = 1001
@export var monster_name: String = "Forest Beast (森林幼兽)"
@export var max_hp: int = 60
@export var current_hp: int = 60
@export var move_speed: float = 3.5
@export var aggro_radius: float = 7.0
@export var attack_radius: float = 1.8
@export var attack_damage: int = 12

var state: State = State.IDLE
var spawn_point: Vector3 = Vector3.ZERO
var target_player: Node3D = null
var attack_cooldown: float = 0.0
var respawn_timer: float = 0.0

@onready var visual_root: Node3D = $Visual
@onready var name_label: Label3D = $NameLabel
@onready var hp_bar_3d: Label3D = $HPLabel

var stats: Dictionary = {
	"defense": 4,
	"evasion": 0.05,
	"element": 1 # PHY
}

func _ready() -> void:
	spawn_point = global_position
	current_hp = max_hp
	_update_labels()
	add_to_group("monsters")

func _physics_process(delta: float) -> void:
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
		
	# Find target player if none
	if target_player == null or not is_instance_valid(target_player):
		_find_nearest_player()
		
	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, move_speed * delta)
			velocity.z = move_toward(velocity.z, 0, move_speed * delta)
			if target_player and global_position.distance_to(target_player.global_position) <= aggro_radius:
				state = State.CHASE
				
		State.CHASE:
			if target_player == null or not is_instance_valid(target_player):
				state = State.IDLE
				return
			var dist = global_position.distance_to(target_player.global_position)
			if dist > aggro_radius * 1.5:
				target_player = null
				state = State.IDLE
			elif dist <= attack_radius:
				state = State.ATTACK
			else:
				var dir = (target_player.global_position - global_position).normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				var target_angle = atan2(-dir.x, -dir.z)
				visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, 10.0 * delta)
				
		State.ATTACK:
			velocity.x = 0
			velocity.z = 0
			if target_player and is_instance_valid(target_player):
				var dist = global_position.distance_to(target_player.global_position)
				if dist > attack_radius:
					state = State.CHASE
				elif attack_cooldown <= 0.0:
					_execute_attack()
			else:
				state = State.IDLE

	move_and_slide()

func _find_nearest_player() -> void:
	var closest_dist = aggro_radius
	var best_player = null
	for p in get_tree().get_nodes_in_group("players"):
		if is_instance_valid(p):
			var d = global_position.distance_to(p.global_position)
			if d < closest_dist:
				closest_dist = d
				best_player = p
	target_player = best_player

func _execute_attack() -> void:
	attack_cooldown = 1.4
	# Visual lunge
	var orig_z = visual_root.position.z
	var tween = create_tween()
	tween.tween_property(visual_root, "position:z", orig_z + 0.3, 0.1)
	tween.tween_property(visual_root, "position:z", orig_z, 0.15)
	
	if target_player and is_instance_valid(target_player):
		var pstats = target_player.get("stats")
		if pstats:
			var dmg = maxi(1, attack_damage - int(pstats.get("defense", 0)))
			pstats["hp"] = maxi(0, pstats["hp"] - dmg)
			_spawn_damage_text(target_player.global_position + Vector3(0, 1.5, 0), str(dmg), Color(1, 0.3, 0.3))

func take_damage(dmg_result: Dictionary, attacker: Node3D) -> void:
	if state == State.DEAD:
		return
	var dmg: int = dmg_result.get("damage", 10)
	var is_crit: bool = dmg_result.get("is_critical", false)
	var is_miss: bool = dmg_result.get("is_miss", false)
	
	if is_miss:
		_spawn_damage_text(global_position + Vector3(0, 1.2, 0), "MISS", Color.GRAY)
		return
		
	current_hp = maxi(0, current_hp - dmg)
	_update_labels()
	
	# Damage text & flash
	var txt = str(dmg)
	var col = Color.GOLD if is_crit else Color.WHITE
	if is_crit:
		txt = "CRIT! " + txt
	_spawn_damage_text(global_position + Vector3(0, 1.4, 0), txt, col)
	
	# Hurt visual flash
	var orig_scale = visual_root.scale
	var tween = create_tween()
	tween.tween_property(visual_root, "scale", orig_scale * 1.2, 0.06)
	tween.tween_property(visual_root, "scale", orig_scale, 0.08)
	
	# Aggro onto attacker
	target_player = attacker
	state = State.CHASE
	
	if current_hp <= 0:
		die(attacker)

func die(killer: Node3D) -> void:
	state = State.DEAD
	monster_died.emit(self, killer)
	_spawn_damage_text(global_position + Vector3(0, 1.6, 0), "+45 EXP", Color.SPRING_GREEN)
	respawn_timer = 5.0
	
	# Notify HUD for quest
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("add_monster_kill"):
		hud.add_monster_kill()
		
	# Death sink animation
	var tween = create_tween()
	tween.tween_property(visual_root, "position:y", -1.2, 0.5)
	$CollisionShape3D.set_deferred("disabled", true)

func respawn() -> void:
	state = State.IDLE
	global_position = spawn_point + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	current_hp = max_hp
	visual_root.position.y = 0
	$CollisionShape3D.set_deferred("disabled", false)
	_update_labels()

func _update_labels() -> void:
	name_label.text = monster_name
	hp_bar_3d.text = "HP: %d / %d" % [current_hp, max_hp]
	if current_hp < max_hp * 0.35:
		hp_bar_3d.modulate = Color(1, 0.2, 0.2)
	else:
		hp_bar_3d.modulate = Color(0.2, 1, 0.3)

func _spawn_damage_text(world_pos: Vector3, text: String, color: Color) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("spawn_floating_text"):
		var cam = get_viewport().get_camera_3d()
		if cam:
			var screen_pos = cam.unproject_position(world_pos)
			hud.spawn_floating_text(screen_pos, text, color)
