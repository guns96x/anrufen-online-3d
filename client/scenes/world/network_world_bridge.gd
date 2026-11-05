class_name NetworkWorldBridge
extends Node

var world: GuanlinTown
var network: Node
var _active: bool = false
var _offline: Dictionary = {}
var _offline_monsters: Dictionary = {}
var _remotes: Dictionary = {}
var _loot_visuals: Dictionary = {}
var _loot_attempts: Dictionary = {}
var _save_enabled: bool

func _ready() -> void:
	network = get_node("/root/NetworkManager")
	network.world_updated.connect(_receive_world)
	network.state_updated.connect(_receive_profile)
	network.world_event.connect(_event)
	if not network.world_snapshot.is_empty():
		call_deferred("_receive_world",network.world_snapshot)

func _enter() -> void:
	var player: Player = world.local_player
	_offline = {"stats":player.stats.duplicate(true),"journal":world.hud.progression.journal_snapshot(),"position":player.global_position,"dead":player.is_dead,"respawn":player.respawn_timer,"cooldowns":player.cooldowns.duplicate(true)}
	_save_enabled = world.hud.progression.auto_save_enabled
	world.hud.progression.auto_save_enabled = false
	player.set_meta("network_world",true)
	player.current_target = null
	player.cancel_navigation()
	for monster: Monster in get_tree().get_nodes_in_group("monsters"):
		_offline_monsters[str(monster.name)] = {"position":monster.global_position,"hp":monster.current_hp,"state":monster.state,"respawn":monster.respawn_timer}
		monster.set_meta("network_world",true)
	for loot: Node in get_tree().get_nodes_in_group("ground_loot"):
		loot.hide()
	if network.is_server and network.simulation:
		network.simulation.movement_allowed = _can_move
	_active = true
	world.hud.close_dialogue()

func _leave() -> void:
	if not _active:
		return
	var player: Player = world.local_player
	player.stats = _offline["stats"]
	player.set_meta("network_world",false)
	player.global_position = _offline["position"]
	player.is_dead = _offline["dead"]
	player.respawn_timer = _offline["respawn"]
	player.cooldowns = _offline["cooldowns"]
	player.current_target = null
	player.cancel_navigation()
	world.hud.progression.apply_journal(_offline["journal"])
	world.hud.progression.auto_save_enabled = _save_enabled
	for monster: Monster in get_tree().get_nodes_in_group("monsters"):
		monster.set_meta("network_world",false)
		var old: Dictionary = _offline_monsters.get(str(monster.name),{})
		if not old.is_empty():
			monster.global_position = old["position"]
			monster.current_hp = old["hp"]
			monster.state = old["state"]
			monster.respawn_timer = old["respawn"]
			monster.visual_root.visible = monster.state != Monster.State.DEAD
			monster.name_label.visible = monster.state != Monster.State.DEAD
			monster.hp_bar_3d.visible = monster.state != Monster.State.DEAD
			monster._telegraph.hide()
			monster._update_labels()
	for node: Node in _remotes.values():
		node.queue_free()
	for node: Node in _loot_visuals.values():
		node.queue_free()
	_remotes.clear()
	_loot_visuals.clear()
	_loot_attempts.clear()
	for loot: Node in get_tree().get_nodes_in_group("ground_loot"):
		loot.show()
	_active = false
	world.hud.close_dialogue()
	world.hud.on_systems_changed()

func _receive_profile(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		_leave()
	elif _active and snapshot.get("world_enabled",false):
		_apply_profile(snapshot["profile"],snapshot.get("journal",{}),true)

func _apply_profile(profile: Dictionary, journal: Dictionary, refresh: bool) -> void:
	world.local_player.stats = profile.duplicate(true)
	ProfileCodec.normalize(world.local_player.stats)
	world.hud.items.bind_player(world.local_player)
	world.hud.progression.apply_journal(journal)
	world.hud.update_quest_tracker()
	if refresh:
		world.hud.on_systems_changed()

func _receive_world(packet: Dictionary) -> void:
	if packet.is_empty():
		_leave()
		return
	if not _active:
		_enter()
	_apply_profile(packet["profile"],packet["journal"],false)
	var state: Dictionary = packet["state"]
	var own_id: int = int(packet["own_id"])
	for id: int in state["actors"]:
		var row: Dictionary = state["actors"][id]
		var avatar: Player
		if id == own_id:
			avatar = world.local_player
		else:
			if not _remotes.has(id):
				avatar = preload("res://client/scenes/entities/player.tscn").instantiate()
				avatar.is_local_player = false
				avatar.name = "OnlinePlayer%d" % id
				avatar.set_meta("network_account",id)
				avatar.collision_layer = 4
				avatar.collision_mask = 0
				world.add_child(avatar)
				var label: Label3D = Label3D.new()
				label.name = "OnlineName"
				label.position.y = 2.4
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.font_size = 48
				label.pixel_size = 0.007
				label.outline_size = 8
				avatar.add_child(label)
				_remotes[id] = avatar
			avatar = _remotes[id]
			avatar.stats.merge(row,true)
			avatar.get_node("OnlineName").text = "%s · Рів. %d · %d/%d" % [row["name"],row["level"],row["hp"],row["max_hp"]]
			avatar.get_node("OnlineName").visible = SettingsStore.current().get_value("show_names")
		var location: Vector3 = row["position"]
		if id != own_id: avatar.velocity = (location-avatar.global_position)/0.1
		avatar.global_position = location if avatar.global_position.distance_to(location) > 4.0 else avatar.global_position.lerp(location,0.7)
		avatar.visual_root.rotation.y = row["yaw"]
		avatar.visual_root.visible = not row["dead"]
		avatar.is_dead = row["dead"]
		avatar.respawn_timer = row["respawn_timer"]
		avatar.dash_timer = row["dash_timer"]
		avatar.cooldowns = row["cooldowns"].duplicate(true)
		if id == own_id:
			avatar.set_meta("network_pet",row.get("pet",{}))
	for id: int in _remotes.keys():
		if not state["actors"].has(id):
			_remotes[id].queue_free()
			_remotes.erase(id)
	for monster: Monster in get_tree().get_nodes_in_group("monsters"):
		var row: Dictionary = state["monsters"].get(str(monster.name),{})
		if row.is_empty():
			continue
		monster.global_position = row["position"]
		monster.current_hp = int(row["hp"])
		monster.state = Monster.State.DEAD if row["state"] == "dead" else Monster.State.ATTACK if row["state"] == "attack" else Monster.State.IDLE
		monster.visual_root.visible = row["state"] != "dead"
		if row["state"] != "dead":
			monster.visual_root.position.y = 0.0
		monster.name_label.visible = row["state"] != "dead"
		monster.hp_bar_3d.visible = row["state"] != "dead"
		monster._telegraph.visible = float(row["warning_timer"]) > 0.0
		if monster._telegraph.visible:
			monster._telegraph.global_position = row["warning_position"]+Vector3(0,0.08,0)
			monster._telegraph.scale = Vector3.ONE*lerpf(0.4,1.0,1.0-float(row["warning_timer"])/0.65)
		monster._update_labels()
	_sync_loot(state.get("loot",{}),own_id)

func _can_move(from: Vector3, to: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.35
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.transform.origin = from+Vector3(0,0.7,0)
	query.motion = to-from
	var fraction: PackedFloat32Array = space.cast_motion(query)
	return fraction.is_empty() or fraction[0] >= 0.999

func _sync_loot(rows: Dictionary, own_id: int) -> void:
	for id: int in rows:
		var row: Dictionary = rows[id]
		if not _loot_visuals.has(id):
			var visual: MeshInstance3D = MeshInstance3D.new()
			var mesh: SphereMesh = SphereMesh.new()
			mesh.radius = 0.18
			mesh.height = 0.36
			visual.mesh = mesh
			var material: StandardMaterial3D = StandardMaterial3D.new()
			material.albedo_color = Color.GOLD
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override = material
			world.add_child(visual)
			_loot_visuals[id] = visual
		_loot_visuals[id].global_position = row["position"]+Vector3(0,0.3,0)
		if int(row["owner"]) == own_id and SettingsStore.current().get_value("auto_loot") and not world.local_player.is_dead and world.local_player.global_position.distance_to(row["position"]) < 3.0 and Time.get_ticks_msec()-int(_loot_attempts.get(id,0)) > 1500:
			_loot_attempts[id] = Time.get_ticks_msec()
			var kinds: Array = ["coins_only"]
			for entry: Array in [["loot_equipment",["equipment","mount"]],["loot_supplies",["consumable","pet_food","pet_potion"]],["loot_materials",["material","pet_egg"]]]:
				if SettingsStore.current().get_value(entry[0]):
					kinds.append_array(entry[1])
			network.request.call_deferred("game_pickup",{"id":id,"kinds":kinds})
	for id: int in _loot_visuals.keys():
		if not rows.has(id):
			_loot_visuals[id].queue_free()
			_loot_visuals.erase(id)
			_loot_attempts.erase(id)

func _event(event: Dictionary) -> void:
	if not _active:
		return
	if event.get("type") in ["duel_started","duel_finished"]:
		world.hud.show_banner("Дуель розпочато" if event["type"] == "duel_started" else "Дуель завершено")
	elif event.get("type") == "skill":
		var account: int = int(event.get("attacker",0))
		var actor: Player = world.local_player if account == int(network.world_snapshot["own_id"]) else _remotes.get(account)
		if actor:
			CombatFeedback.arc(world,actor.global_position,actor.visual_root.rotation.y,Color.SKY_BLUE,2.4)
			if actor._motion: actor._motion.strike_left = 0.35
	elif event.get("type") == "heal":
		var account: int = int(event.get("target",0))
		if network.world_snapshot["state"]["actors"].has(account):
			world.local_player._float_text(network.world_snapshot["state"]["actors"][account]["position"]+Vector3.UP*1.8,"+%d" % int(event.get("amount",0)),Color.GREEN)
	elif event.get("type") == "damage":
		var location: Vector3 = world.local_player.global_position
		var target: Dictionary = event.get("target",{})
		if target.get("kind") == "monster" and network.world_snapshot["state"]["monsters"].has(str(target.get("id"))):
			location = network.world_snapshot["state"]["monsters"][str(target["id"])]["position"]
		elif target.get("kind") == "player" and network.world_snapshot["state"]["actors"].has(int(target.get("id",0))):
			location = network.world_snapshot["state"]["actors"][int(target["id"])]["position"]
		world.local_player._float_text(location+Vector3(0,1.5,0),"MISS" if event.get("is_miss",false) else str(event.get("amount",0)),Color.ORANGE)
		if target.get("kind") == "player" and int(target.get("id",0)) == int(network.world_snapshot["own_id"]) and int(event.get("amount",0)) > 0:
			world.local_player._camera_impulse = 0.7
