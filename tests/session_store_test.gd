extends SceneTree
var failures: int = 0
var prefix: String = "res://build/lan-persistence-%d" % Time.get_ticks_usec()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var model: SocialState = SocialState.new()
	model.join(1,"Alice")
	model.join(2,"Bohdan")
	model.act(1,"friend_request",{"target":2})
	model.act(2,"friend_accept",{"target":1})
	model.act(1,"guild_create",{"name":"Forest Guild"})
	model.act(1,"guild_invite",{"target":2})
	var guild: int = int(model.snapshot_for(2)["invitations"]["guild"][0]["id"])
	model.act(2,"guild_accept",{"guild_id":guild})
	model.act(1,"mail_send",{"target":2,"subject":"After restart","body":"Still here"})
	model.act(1,"chat",{"channel":"whisper","target":2,"text":"Private"})
	check(model.act(1,"auction_list",{"id":30016,"count":1,"price":10})["ok"],"consignment reserves seller item")
	var listing: int = int(model.snapshot_for(1)["auctions"][0]["id"])
	check(model.players[1]["profile"]["inventory"]["30016"] == 2,"listed stock removed from wallet bag")
	check(not model.act(1,"auction_buy",{"listing_id":listing})["ok"],"seller cannot buy own listing")
	var token_a: String = "a".repeat(64)
	var token_b: String = "b".repeat(64)
	var registry: Dictionary = {token_a.sha256_text():1,token_b.sha256_text():2}
	var store: SessionStore = SessionStore.new()
	store.path = prefix+".json"
	var committed: bool = store.commit(model,registry,3)
	check(committed,"server model and account registry commit together")
	if not committed:
		print("STORE_REASON: ",store.error)
		quit(1)
		return
	var raw: String = FileAccess.get_file_as_string(store.path)
	check(not token_a in raw and not token_b in raw,"server stores hashes rather than bearer credentials")
	var loaded: Dictionary = store.load_state()
	check(not loaded.is_empty(),"server state round trip validates")
	var restored: SocialState = SocialState.new()
	if not loaded.is_empty():
		restored.restore_state(loaded["state"])
	check(restored.snapshot_for(1).get("profile",{}).get("copper",-1) == 50,"guild charge survives restart")
	check(restored.snapshot_for(2).get("friends",[]) == [1],"friendship survives restart")
	check(restored.snapshot_for(2).get("mail",[]).size() == 1,"mail survives restart")
	check(restored.snapshot_for(2).get("auctions",[]).size() == 1,"consignment escrow survives restart")
	check(restored.snapshot_for(1).get("onlineplayers",[]).is_empty(),"stored profiles are offline until authenticated")
	check(restored.reconnect(2,"Bohdan"),"stable account reconnects")
	check(not restored.reconnect(2,"Impersonator"),"second simultaneous session rejected")
	check(restored.snapshot_for(2).get("guild",{}).get("id",0) == guild,"guild membership survives reconnect")
	check(restored.snapshot_for(2).get("known_names",{}).get(1,"") == "Alice","offline friend name remains available")
	check(not restored.act(2,"trade_request",{"target":1})["ok"],"offline player cannot be put into trade")
	check(restored.act(2,"auction_buy",{"listing_id":listing})["ok"],"buyer purchases offline seller's listing")
	check(restored.players[2]["profile"]["copper"] == 90 and restored.players[1]["profile"]["copper"] == 60,"consignment pays seller and conserves currency")
	check(restored.players[2]["profile"]["inventory"]["30016"] == 4,"buyer receives escrowed item")
	check(not restored.act(2,"auction_buy",{"listing_id":listing})["ok"],"consignment purchase cannot replay")
	check(store.commit(restored,registry,3) and FileAccess.file_exists(store.path+".bak"),"server replacement retains previous commit")
	var invalid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	invalid["state"]["players"]["1"]["profile"]["copper"] = -100
	check(store.normalize(invalid).is_empty(),"negative stored wallet rejected")
	var file: FileAccess = FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string("{bad-json")
	file.close()
	check(store.load_state().is_empty() and store.blocked,"corrupt server database protected")
	check(not store.commit(model,registry,3) and FileAccess.get_file_as_string(store.path) == "{bad-json","commit cannot overwrite corrupt database")
	# Exercise the real NetworkManager's persistent admission and failure rollback.
	var net: Node = root.get_node("NetworkManager")
	net.persistence_enabled = true
	net.identity_path = prefix+".token"
	net.server_state_path = prefix+"-host.json"
	net.local_player_data = {"name":"Persistent Host","copper":9999999}
	check(net.start_server(17879),"real host starts with persistent identity")
	var own: int = int(net.social_snapshot.get("own_id",0))
	net.request("guild_create",{"name":"Durable Guild"})
	check(net.social_snapshot.get("profile",{}).get("copper",-1) == 50,"host's server wallet is authoritative")
	net.disconnect_session()
	check(net.start_server(17879),"host restarts from database")
	check(net.social_snapshot.get("own_id",0) == own and net.social_snapshot.get("profile",{}).get("copper",-1) == 50,"reconnect preserves identity and does not mint starter money")
	var state_before: Dictionary = net._server_state.checkpoint()
	var valid_path: String = net._store.path
	net._store.path = "res://build/missing-directory/no-server.json"
	net.request("chat",{"channel":"global","text":"Must rollback"})
	check(net._server_state.checkpoint() == state_before,"failed storage rolls back entire action before publishing")
	net._store.path = valid_path
	net.disconnect_session()
	check(SessionStore.token_valid(FileAccess.get_file_as_string(net.identity_path)),"device credential has valid random-token format")
	for base: String in [prefix+".json",prefix+"-host.json",prefix+".token"]:
		for suffix: String in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base+suffix):
				DirAccess.remove_absolute(base+suffix)
	print("SESSION_STORE_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
