extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var net: Node = root.get_node("NetworkManager")
	var prefix: String = "res://build/bounty-integrated-%d" % OS.get_process_id()
	net.persistence_enabled = true
	net.identity_path = prefix+".token"
	net.server_state_path = prefix+".json"
	var target_token: String = "b".repeat(64)
	var hunter_token: String = "c".repeat(64)
	check(net.start_server(17983),"persistent bounty world starts")
	check(net._admit(42,"Target Hero",target_token) and net._admit(43,"Hunter Hero",hunter_token),"server admits separate target and hunter profiles")
	net.request("bounty_create",{"target":2,"reward":20,"min_level":1,"required":2})
	check(net._server_state.bounties.size() == 1 and net._server_state.players[1]["profile"]["copper"] == 80,"published hunt reserves actual server money")
	var id: int = int(net._server_state.bounties.keys()[0])
	net._handle_request(43,"bounty_accept",{"bounty_id":id})
	check(net._server_state.bounties[id]["hunter"] == 3,"third player accepts public hunt")
	defeat(net)
	check(net._server_state.bounties[id]["kills"] == 1 and net._server_state.players[3]["profile"]["copper"] == 100,"first authoritative kill records progress without early payment")
	net.disconnect_session(false)
	check(net.start_server(17983) and net._admit(42,"Target Hero",target_token) and net._admit(43,"Hunter Hero",hunter_token),"accepted hunt and three identities resume after host restart")
	check(net._server_state.bounties[id]["kills"] == 1 and net._server_state.bounties[id]["state"] == "accepted","multi-kill bounty progress survives server JSON")
	for i: int in 13: net.simulation.tick(0.25)
	defeat(net)
	check(net._server_state.bounties[id]["state"] == "completed" and net._server_state.players[3]["profile"]["copper"] == 120,"final real PvP death releases escrow to hunter")
	net._handle_request(43,"game_attack",{"target":{"kind":"player","id":2}})
	check(net._server_state.players[3]["profile"]["copper"] == 120,"dead-target replay cannot pay bounty again")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(net.server_state_path))
	raw["state"]["bounties"][str(id)]["kills"] = 9
	check(net._store.normalize(raw).is_empty(),"server store rejects corrupted completed bounty ledger")
	net.disconnect_session(false)
	for path: String in [prefix+".json",prefix+".token"]:
		for suffix: String in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	await process_frame
	print("BOUNTY_INTEGRATION_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
func defeat(net: Node) -> void:
	net.simulation.actors[3]["position"] = Vector3(5,0,6)
	net.simulation.actors[2]["position"] = Vector3(6,0,6)
	net.simulation.actors[3]["cooldowns"]["attack"] = 0.0
	net.simulation.set_pk_mode(3,"free")
	net._server_state.players[3]["profile"]["accuracy"] = 1.0
	net._server_state.players[3]["profile"]["base_accuracy"] = 1.0
	net._server_state.players[2]["profile"]["evasion"] = 0.0
	net._server_state.players[2]["profile"]["base_evasion"] = 0.0
	net._server_state.players[2]["profile"]["hp"] = 1
	net._handle_request(43,"game_attack",{"target":{"kind":"player","id":2}})
