extends SceneTree
var failures: int = 0
var net: Node
var _host_done: bool = false
var scene: GuanlinTown
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	net = root.get_node("NetworkManager")
	net.persistence_enabled = false
	scene = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	if "--world-host" in OS.get_cmdline_user_args():
		await host()
	else:
		await client()
	net.disconnect_session()
	scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
func host() -> void:
	net.local_player_data = {"name":"World Host"}
	net.state_updated.connect(func(snapshot: Dictionary) -> void:
		if snapshot.is_empty(): return
		for row: Dictionary in net._server_state.players.values():
			row["profile"]["accuracy"] = 1.0
			row["profile"]["base_accuracy"] = 1.0
			row["profile"]["evasion"] = 0.0
			row["profile"]["base_evasion"] = 0.0
		for message: Dictionary in snapshot.get("chat",[]):
			if message["text"] == "world-client-pass": _host_done = true
	)
	net.world_event.connect(func(event: Dictionary) -> void:
		if event.get("type") == "duel_request" and int(event.get("target",0)) == 1:
			net.request.call_deferred("game_duel_accept",{"target":event["attacker"]})
	)
	check(net.start_server(17879),"two-process world host starts")
	print("WORLD_HOST_READY")
	await create_timer(7.0).timeout
	check(_host_done,"remote movement, avatars and duel completed over ENet")
	print("WORLD_TRANSPORT_HOST: ","PASS" if failures == 0 else "FAIL")
func client() -> void:
	net.local_player_data = {"name":"World Client","hp":999999,"copper":999999}
	check(net.start_client("127.0.0.1",17879),"world client connects")
	var deadline: int = Time.get_ticks_msec()+4000
	while (net.world_snapshot.is_empty() or net.world_snapshot.get("state",{}).get("actors",{}).size() != 2) and Time.get_ticks_msec() < deadline:
		await process_frame
	if net.world_snapshot.is_empty():
		check(false,"received initial world snapshot")
		return
	var own: int = int(net.world_snapshot["own_id"])
	check(net.world_snapshot["state"]["actors"].size() == 2,"both actual clients inhabit one shared world")
	check(scene.has_node("OnlinePlayer1") and scene.get_node("OnlinePlayer1").get_meta("network_account") == 1,"remote player has a selectable rendered avatar")
	check(scene.local_player.stats["copper"] == 100 and scene.local_player.stats["hp"] <= 100,"client-supplied character stats cannot enter server world")
	var before: Vector3 = net.world_snapshot["state"]["actors"][own]["position"]
	scene.local_player.move_direction = Vector2.ZERO
	# The actual player controller sends camera-relative intent continuously.
	var aim: Vector3 = scene.local_player.camera.global_basis.x
	aim.y = 0
	scene.local_player.move_direction = Vector2(1,0)
	await create_timer(0.22).timeout
	scene.local_player.move_direction = Vector2.ZERO
	await create_timer(0.25).timeout
	var after: Vector3 = net.world_snapshot["state"]["actors"][own]["position"]
	check(after.distance_to(before) > 0.4 and after.distance_to(before) < 2.5,"movement crosses real ENet and returns a bounded server position")
	net.request("game_duel_request",{"target":1})
	await create_timer(0.35).timeout
	check(net.world_snapshot["state"]["duels"].get(own,0) == 1,"duel requires and receives consent from the other process")
	var hp: int = int(net.world_snapshot["state"]["actors"][1]["hp"])
	net.request("game_attack",{"target":{"kind":"player","id":1}})
	await create_timer(0.3).timeout
	check(int(net.world_snapshot["state"]["actors"][1]["hp"]) < hp,"PvP hit changes authoritative HP on the remote host")
	net.request("game_assign_skill",{"slot":"2","id":90020})
	await create_timer(0.15).timeout
	check(net.world_snapshot["profile"]["hotbar"].get("2",0) == 90020,"extra hotbar slot is assigned through real ENet")
	hp = int(net.world_snapshot["state"]["actors"][1]["hp"])
	net.request("game_skill",{"slot":"2","target":{"kind":"player","id":1}})
	await create_timer(0.25).timeout
	check(int(net.world_snapshot["state"]["actors"][1]["hp"]) < hp,"source class skill from extra slot damages remote authoritative actor")
	net.request("game_duel_cancel")
	await create_timer(0.2).timeout
	check(not net.world_snapshot["state"]["duels"].has(own),"either participant can leave the duel")
	if failures == 0:
		net.request("chat",{"channel":"global","text":"world-client-pass"})
	await create_timer(0.2).timeout
	print("WORLD_TRANSPORT_CLIENT: ","PASS" if failures == 0 else "FAIL")
