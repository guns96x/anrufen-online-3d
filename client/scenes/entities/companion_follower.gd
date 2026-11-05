class_name CompanionFollower
extends CharacterBody3D

var owner_player: Player
var companions: CompanionSystem
var current_uid: String = ""
var _visual: Node3D
var _cooldown: float = 0.0
const FOLLOW_DISTANCE: float = 2.0
const SPEED: float = 6.0
const ATTACK_RANGE: float = 2.5
const ATTACK_COOLDOWN: float = 1.6
const BOAR: PackedScene = preload("res://assets/models/v2/boar.glb")
const JACKAL: PackedScene = preload("res://assets/models/v2/jackal.glb")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 0.8
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.4
	add_child(collision)
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	_sync_pet()

func _sync_pet() -> Dictionary:
	if not is_instance_valid(owner_player) or companions == null:
		current_uid = ""
		hide()
		collision_mask = 0
		return {}
	var uid: String = str(owner_player.stats.get("summoned_pet", ""))
	var pet: Dictionary = companions.get_pet(uid)
	if uid.is_empty() or pet.is_empty() or int(pet.get("hp", 0)) <= 0 or int(pet.get("hunger", 0)) <= 0:
		current_uid = ""
		hide()
		collision_mask = 0
		return {}
	if uid != current_uid:
		current_uid = uid
		for child: Node in _visual.get_children():
			child.free()
		var model: Node3D = (JACKAL if int(pet["species_id"]) == 140052 else BOAR).instantiate()
		model.scale = Vector3.ONE * 0.6
		_visual.add_child(model)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh: MeshInstance3D = node
			for surface: int in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material and material.resource_name.begins_with("Vertex palette"):
					material.vertex_color_use_as_albedo = true
		global_position = owner_player.global_position + Vector3(1.5, 0.2, 1.5)
		velocity = Vector3.ZERO
		_cooldown = 0.0
	show()
	collision_mask = 1
	return pet

func _physics_process(delta: float) -> void:
	var pet: Dictionary = _sync_pet()
	if is_instance_valid(owner_player) and owner_player.get_meta("network_world",false):
		var row: Dictionary = owner_player.get_meta("network_pet",{})
		if not row.is_empty() and not pet.is_empty():
			global_position = row["position"]
		velocity = Vector3.ZERO
		return
	if pet.is_empty():
		velocity = Vector3.ZERO
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	if global_position.distance_to(owner_player.global_position) > 18.0 or global_position.y < -20.0:
		global_position = owner_player.global_position + Vector3(1.5, 0.2, 1.5)
		velocity = Vector3.ZERO
	var target: Monster = _combat_target()
	var goal: Vector3 = owner_player.global_position
	var stop_distance: float = FOLLOW_DISTANCE
	if target:
		goal = target.global_position
		stop_distance = ATTACK_RANGE - 0.4
	var direction: Vector3 = goal - global_position
	direction.y = 0.0
	if direction.length() > stop_distance:
		var walk: Vector3 = direction.normalized()
		velocity.x = walk.x * SPEED
		velocity.z = walk.z * SPEED
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-walk.x, -walk.z), delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 30.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 30.0)
	if not is_on_floor():
		velocity.y -= 19.6 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if target and not target.is_dead() and global_position.distance_to(target.global_position) <= ATTACK_RANGE and _cooldown <= 0.0:
		var attack: Dictionary = companions.combat_strike(current_uid)
		var result: Dictionary = CombatFormulas.calculate_damage(attack, target.stats, 1.0,attack["element"])
		if 90035 in pet["skills"] and attack["element"] == CombatFormulas.DamageType.WATER and not result.get("is_miss",false):
			target.slow_timer = maxf(target.slow_timer,3.0)
		_cooldown = ATTACK_COOLDOWN
		# The player is the legal combat owner. Monster death routes its existing
		# quest/experience signals once; pet EXP is awarded by the main HUD.
		target.take_damage(result, owner_player)

func _combat_target() -> Monster:
	if is_instance_valid(owner_player) and owner_player.get_meta("network_world",false):
		return null
	if not is_instance_valid(owner_player) or owner_player.is_dead or owner_player.controls_blocked:
		return null
	var candidate: Node3D = owner_player.current_target
	if not is_instance_valid(candidate) or not candidate is Monster or candidate.is_dead():
		return null
	if candidate.global_position.distance_to(owner_player.global_position) > 12.0:
		return null
	return candidate
