extends SceneTree

var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func fresh() -> SocialState:
	var state := SocialState.new()
	for id: int in [1,2,3,4]:
		state.join(id,"Hero%d" % id)
		state.players[id]["profile"]["copper"] = 1000
		state.players[id]["profile"]["level"] = 5
	return state

func total(state: SocialState) -> int:
	var value: int = 0
	for player: Dictionary in state.players.values():
		value += int(player["profile"]["copper"])
	for bounty: Dictionary in state.bounties.values():
		if bounty["state"] in ["available","accepted"]:
			value += int(bounty["reward"])
	return value

func create(state: SocialState, extra: Dictionary = {}) -> int:
	var payload: Dictionary = {"target":2,"reward":120}
	payload.merge(extra,true)
	return int(state.act(1,"bounty_create",payload).get("bounty_id",0))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state: SocialState = fresh()
	var id: int = create(state)
	check(id > 0 and state.players[1]["profile"]["copper"] == 880,"create escrows full reward once")
	check(total(state) == 4000,"creation conserves wallets plus escrow")
	check(state.bounties[id]["min_level"] == 1 and state.bounties[id]["required"] == 1 and state.bounties[id]["kills"] == 0,"original UI options have safe defaults")
	var board: Array = state.snapshot_for(4)["bounties"]
	check(board.size() == 1 and board[0]["target_name"] == "Hero2" and board[0]["creator_name"] == "Hero1","public board includes account names")
	board[0]["reward"] = 999
	check(state.bounties[id]["reward"] == 120,"snapshot cannot mutate escrow")
	check(not state.act(3,"bounty_cancel",{"bounty_id":id})["ok"],"another player cannot cancel")
	check(not state.act(1,"bounty_accept",{"bounty_id":id})["ok"] and not state.act(2,"bounty_accept",{"bounty_id":id})["ok"],"creator and target cannot take own contract")
	check(state.act(1,"bounty_cancel",{"bounty_id":float(id)})["ok"],"JSON integer cancel returns escrow")
	check(total(state) == 4000 and state.players[1]["profile"]["copper"] == 1000,"cancel conserves money")
	check(not state.act(1,"bounty_cancel",{"bounty_id":id})["ok"] and state.players[1]["profile"]["copper"] == 1000,"cancel replay cannot refund twice")
	check(not state.act(3,"bounty_accept",{"bounty_id":id})["ok"],"cancelled bounty cannot be accepted")
	check(state.snapshot_for(4)["bounties"].is_empty() and state.snapshot_for(1)["bounties"].size() == 1,"terminal history visible to participants only")

	state = fresh()
	for malformed: Variant in [0,-1,1.5,NAN,INF,"120",null,100000001]:
		check(create(state,{"reward":malformed}) == 0,"malformed reward rejected: %s" % str(malformed))
	check(create(state,{"target":1}) == 0 and create(state,{"target":999}) == 0,"self and unknown target rejected")
	check(create(state,{"min_level":101}) == 0 and create(state,{"min_level":0}) == 0 and create(state,{"min_level":1.5}) == 0,"acceptance level bounded integer")
	check(create(state,{"required":0}) == 0 and create(state,{"required":11}) == 0 and create(state,{"required":"2"}) == 0,"kill count bounded integer")
	state.players[1]["profile"]["copper"] = 5
	check(create(state) == 0 and state.players[1]["profile"]["copper"] == 5,"insufficient funds are transactional")
	state.players[1]["profile"]["copper"] = 1000
	state.detach(2)
	check(create(state) == 0,"offline target cannot receive new bounty")
	state.reconnect(2,"Hero2")
	state.act(2,"block",{"target":1})
	check(create(state) == 0,"blocked target cannot receive new bounty")
	state.act(2,"unblock",{"target":1})
	id = create(state,{"min_level":6.0,"required":2.0})
	check(id > 0,"JSON integral floats accepted for original options")
	check(not state.act(3,"bounty_accept",{"bounty_id":id})["ok"],"hunter must meet source acceptance level")
	state.players[3]["profile"]["level"] = 6
	state.act(3,"block",{"target":2})
	check(not state.act(3,"bounty_accept",{"bounty_id":id})["ok"],"blocked hunter cannot accept")
	state.act(3,"unblock",{"target":2})
	state.detach(1)
	check(not state.act(3,"bounty_accept",{"bounty_id":id})["ok"],"offline creator cannot start a new hunt")
	state.reconnect(1,"Hero1")
	state.detach(2)
	check(not state.act(3,"bounty_accept",{"bounty_id":id})["ok"],"offline target cannot start a new hunt")
	state.reconnect(2,"Hero2")
	check(state.act(3,"bounty_accept",{"bounty_id":float(id)})["ok"],"eligible hunter accepts")
	check(not state.act(4,"bounty_accept",{"bounty_id":id})["ok"],"one hunter per bounty")
	check(not state.act(1,"bounty_cancel",{"bounty_id":id})["ok"],"accepted bounty cannot be cancelled")
	var second: int = create(state,{"reward":10})
	check(not state.act(3,"bounty_accept",{"bounty_id":second})["ok"],"hunter cannot accept two active contracts")
	check(not state.act(3,"bounty_accept",{"bounty_id":1.25})["ok"] and not state.act(1,"bounty_cancel",{"bounty_id":"1"})["ok"],"malformed bounty IDs rejected")
	check(not state.record_player_defeat(3,2,true)["ok"] and state.bounties[id]["kills"] == 0,"duels grant no bounty progress")
	check(not state.record_player_defeat(3,3)["ok"] and not state.record_player_defeat(999,2)["ok"],"self and unknown defeat reports rejected")
	check(state.record_player_defeat(4,2)["progressed"].is_empty() and state.record_player_defeat(3,4)["progressed"].is_empty(),"only assigned hunter and exact target receive credit")
	var progress: Dictionary = state.record_player_defeat(3,2)
	check(progress["progressed"] == [id] and progress["completed"].is_empty() and state.bounties[id]["kills"] == 1,"first authoritative death advances multi-kill task")
	check(state.players[3]["profile"]["copper"] == 1000 and total(state) == 4000,"partial progress pays nothing and preserves escrow")
	state.detach(1)
	progress = state.record_player_defeat(3,2)
	check(progress["completed"] == [id] and progress["reward"] == 120 and state.bounties[id]["paid"],"final death pays hunter despite offline issuer")
	check(state.players[3]["profile"]["copper"] == 1120 and total(state) == 4000,"payout conserves money")
	check(state.record_player_defeat(3,2)["completed"].is_empty() and state.players[3]["profile"]["copper"] == 1120,"terminal replay cannot duplicate payment")
	state.reconnect(1,"Hero1")
	check(state.act(3,"bounty_accept",{"bounty_id":second})["ok"],"completed hunt releases hunter slot")

	state = fresh()
	state.players[1]["profile"]["copper"] = 1000000000
	id = create(state)
	state.players[1]["profile"]["copper"] = 1000000000
	check(not state.act(1,"bounty_cancel",{"bounty_id":id})["ok"] and state.bounties[id]["state"] == "available","overflow refund preserves escrow")
	state.act(3,"bounty_accept",{"bounty_id":id})
	state.players[3]["profile"]["copper"] = 1000000000
	check(not state.record_player_defeat(3,2)["ok"] and state.bounties[id]["kills"] == 0 and not state.bounties[id]["paid"],"overflow payment leaves entire contract unconsumed")

	state = fresh()
	for i: int in range(50):
		create(state,{"reward":1})
	check(state.bounties.size() == 50 and create(state,{"reward":1}) == 0,"global board caps active contracts at fifty")
	state.act(1,"bounty_cancel",{"bounty_id":state.bounties.keys()[0]})
	check(create(state,{"reward":1}) > 0,"terminal contract releases board slot")
	state = fresh()
	for i: int in range(260):
		var history: int = create(state,{"reward":1})
		state.act(1,"bounty_cancel",{"bounty_id":history})
	check(state.bounties.size() == 250 and not state.bounties.has(1) and total(state) == 4000,"terminal ledger bounded without losing escrow or reusing IDs")

	state = fresh()
	id = create(state,{"required":2})
	state.act(3,"bounty_accept",{"bounty_id":id})
	state.record_player_defeat(3,2)
	state.detach(1)
	state.detach(2)
	state.detach(3)
	var saved: Dictionary = state.persistent_state()
	var restored := SocialState.new()
	restored.restore_state(saved)
	check(restored.bounties[id]["kills"] == 1 and restored.bounties[id]["hunter"] == 3 and not restored.players[3]["online"],"offline account progress survives persistent restore")
	check(restored.bounties[id]["reward"] == 120 and total(restored) == 4000,"restored escrow conserved")
	restored.reconnect(3,"Hero3")
	restored.reconnect(2,"Hero2")
	check(restored.record_player_defeat(3,2)["reward"] == 120,"restored hunter completes without reconnecting issuer")
	var checkpoint: Dictionary = restored.checkpoint()
	restored.act(3,"bounty_create",{"target":2,"reward":5})
	restored.restore_state(checkpoint)
	check(restored.bounties.size() == 1 and restored.bounties[id]["state"] == "completed","transaction checkpoint restores bounty state")
	check(not JSON.stringify(restored.persistent_state()).is_empty(),"persistent bounty schema is JSON encodable")
	var old: Dictionary = fresh().persistent_state()
	old.erase("bounties")
	restored.restore_state(old)
	check(restored.bounties.is_empty(),"old persistence without bounties remains compatible")

	state = fresh()
	id = create(state)
	state.act(3,"bounty_accept",{"bounty_id":id})
	state.leave(3)
	check(state.bounties[id]["state"] == "available" and state.bounties[id]["hunter"] == 0,"hard deleted hunter returns escrowed task to board")
	state.leave(2)
	check(state.bounties.is_empty() and state.players[1]["profile"]["copper"] == 1000,"hard deleted target refunds issuer and removes stale reference")
	state = fresh()
	id = create(state)
	state.players[1]["profile"]["copper"] = 1000000000
	state.leave(2)
	check(state.players.has(2) and state.bounties.has(id) and state.players[1]["profile"]["copper"] == 1000000000,"hard delete refuses overflowing refund and preserves account plus escrow")
	state.players[1]["profile"]["copper"] -= 120
	state.leave(2)
	check(not state.players.has(2) and state.bounties.is_empty() and state.players[1]["profile"]["copper"] == 1000000000,"hard delete succeeds once full escrow refund fits")

	state = fresh()
	check(not state.act(1,"guild_declaration",{"text":"Hello"})["ok"],"unguilded account cannot announce")
	state.act(1,"guild_create",{"name":"GuildOne"})
	var guild: int = int(state.players[1]["guild"])
	state.act(1,"guild_invite",{"target":3})
	state.act(3,"guild_accept",{"guild_id":guild})
	check(state.act(1,"guild_declaration",{"text":"  Збір о 20:00\nБіля брами.  "})["ok"],"leader edits source-backed guild announcement")
	check(state.snapshot_for(3)["guild"]["declaration"] == "Збір о 20:00\nБіля брами.","members see trimmed announcement")
	check(state.snapshot_for(4)["guild"].is_empty(),"guild announcement does not leak to outsiders")
	check(not state.act(3,"guild_declaration",{"text":"Takeover"})["ok"],"member cannot replace leader announcement")
	check(not state.act(1,"guild_declaration",{"text":"x".repeat(501)})["ok"] and not state.act(1,"guild_declaration",{"text":123})["ok"] and not state.act(1,"guild_declaration",{"text":"bad" + String.chr(1)})["ok"],"announcement validates length, type and controls")
	check(state.act(1,"guild_declaration",{"text":""})["ok"] and state.guilds[guild]["declaration"] == "","leader may clear announcement")
	state.act(1,"guild_declaration",{"text":"Durable message"})
	state.detach(1)
	restored.restore_state(state.persistent_state())
	check(restored.snapshot_for(3)["guild"]["declaration"] == "Durable message","announcement persists with offline leader")
	state.reconnect(1,"Hero1")
	state.act(1,"guild_leave")
	check(state.guilds[guild]["leader"] == 3 and state.act(3,"guild_declaration",{"text":"New leader"})["ok"],"promoted leader inherits announcement authority")
	check(not state.act(1,"guild_declaration",{"text":"Old leader"})["ok"],"departed leader loses announcement authority")
	state.act(3,"guild_leave")
	check(not state.guilds.has(guild) and state.snapshot_for(3)["guild"].is_empty(),"disband removes announcement with guild")
	print("Bounty/guild: %d checks, %d failures" % [checks,failures])
	print("BOUNTY_GUILD_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(1 if failures else 0)
