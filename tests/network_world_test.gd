extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	SettingsStore.current().set_value("auto_loot",false)
	var player: Player = scene.local_player
	var offline: Dictionary = player.stats.duplicate(true)
	var journal: Dictionary = scene.hud.progression.journal_snapshot()
	var location: Vector3 = player.global_position
	var net: Node = root.get_node("NetworkManager")
	net.persistence_enabled = false
	check(net.start_server(17981),"shared combat host starts in the actual world")
	await process_frame
	await physics_frame
	await process_frame
	check(player.get_meta("network_world",false) and not scene.hud.progression.auto_save_enabled,"entering online world protects offline profile")
	check(net.world_snapshot.get("state",{}).get("monsters",{}).size() == 16,"all sixteen encounters receive authoritative snapshots")
	check(player.stats["copper"] == 100 and player.stats["name"] == "Мандрівник","network character has separate authoritative economy")
	var account: int = int(net.social_snapshot["own_id"])
	var session: ServerGameSession = net._sessions[account]
	var previous: int = session.actor.stats["copper"]
	player.stats["copper"] = 999999
	check(session.actor.stats["copper"] == previous,"client view cannot mutate server wallet by reference")
	player.take_damage(999999)
	check(session.actor.stats["hp"] > 0,"local damage path cannot kill network actor")
	net.simulation.actors[account]["position"] = ServerGameSession.CITIZENS[50179]
	net.request("game_buy",{"id":10003})
	await process_frame
	check(player.stats["inventory"].has("10003") and session.actor.stats["inventory"].has("10003"),"server purchase syncs into actual game bag")
	net.request("game_equip",{"id":10003})
	await process_frame
	check(player.stats["equipment"].get("weapon",0) == 10003,"server equipment syncs into game character")
	net.simulation.actors[account]["position"] = Vector3(-8,0,27)
	net.simulation.actors[account]["cooldowns"]["attack"] = 0.0
	session.actor.stats["attack"] = 9999
	session.actor.stats["accuracy"] = 1.0
	session.actor.stats["base_accuracy"] = 1.0
	var monster: Dictionary = net.simulation.monsters["WildBoar1"]
	monster["stats"]["evasion"] = 0.0
	monster["hp"] = 1
	var old_exp: int = int(session.actor.stats["exp"])
	net.request("game_attack",{"target":{"kind":"monster","id":"WildBoar1"}})
	await process_frame
	check(monster["state"] == "dead" and int(session.actor.stats["exp"]) > old_exp,"server kill awards experience once")
	var exp: int = int(session.actor.stats["exp"])
	net.request("game_attack",{"target":{"kind":"monster","id":"WildBoar1"}})
	check(session.actor.stats["exp"] == exp and net._loots.size() == 1,"replayed death cannot duplicate experience or loot")
	var loot_id: int = int(net._loots.keys()[0]) if not net._loots.is_empty() else 0
	if loot_id > 0:
		net.request("game_pickup",{"id":loot_id})
		check(session.items.count_item(30037) == 1 and net._loots.is_empty(),"authoritative loot pickup reaches the same economy")
	var position_before: Vector3 = net.simulation.actors[account]["position"]
	net.send_world_input(Vector2(1,0),0.0)
	net.simulation.tick(0.1)
	check(net.simulation.actors[account]["position"].x > position_before.x,"input intent moves authoritative actor")
	net.disconnect_session()
	await process_frame
	check(not player.get_meta("network_world",false) and player.stats == offline,"disconnect restores complete offline character")
	check(scene.hud.progression.journal_snapshot() == journal and player.global_position.distance_to(location) < 0.5,"disconnect restores offline quest journal and location")
	scene.queue_free()
	await process_frame
	await process_frame
	print("NETWORK_WORLD_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
