extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var social: SocialState = SocialState.new()
	social.join(1,"Server Hero")
	social.join(2,"Other Hero")
	var simulation: WorldSimulation = WorldSimulation.new()
	simulation.bind_social(social)
	var session: ServerGameSession = ServerGameSession.new()
	root.add_child(session)
	session.bind_account(1,social,simulation)
	check(simulation.add_actor(1),"legacy social wallet upgrades to a playable character")
	check(session.actor.stats["copper"] == 100 and session.items.count_item(30016) == 3,"upgrade preserves wallet and supplies")
	check(not session.act("buy",{"id":10003})["ok"],"server rejects shopping away from merchant")
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50179]
	check(session.act("buy",{"id":10003})["ok"],"server buys real equipment near merchant")
	var attack: int = session.actor.stats["attack"]
	check(session.act("equip",{"id":10003})["ok"] and session.actor.stats["attack"] > attack,"server equipment changes combat stats")
	check(session.act("unequip",{"slot":"weapon"})["ok"] and session.actor.stats["attack"] == attack,"server unequip removes bonuses once")
	check(session.act("lock",{"id":10003})["ok"] and not session.act("sell",{"id":10003})["ok"],"server item lock blocks sale")
	check(not social.act(1,"auction_list",{"item_id":10003,"count":1,"price":10})["ok"],"locked equipment cannot bypass lock via auction")
	session.act("lock",{"id":10003})
	check(session.act("deposit",{"id":10003})["ok"] and session.items.count_item(10003) == 0,"bank moves actual server item")
	check(session.act("withdraw",{"id":10003})["ok"] and session.items.count_item(10003) == 1,"server bank withdrawal restores item")
	session.actor.stats["hp"] = 10
	check(session.act("use",{"id":30016})["ok"] and session.actor.stats["hp"] == 60,"server potion heals authoritative HP")
	check(not session.act("allocate",{"attribute":"strength"})["ok"],"client cannot allocate unearned stat points")
	check(not session.act("rename",{"name":"x"})["ok"] and session.act("rename",{"name":"Updated Hero"})["ok"],"bounded rename updates account and character")
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50164]
	check(session.act("quest",{"action":"accept","qid":80004,"citizen":50164})["ok"],"server accepts original opening quest")
	check(not session.act("quest",{"action":"complete","qid":80004,"citizen":50179})["ok"],"quest handover cannot spoof distant citizen")
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50179]
	check(session.act("quest",{"action":"complete","qid":80004,"citizen":50179})["ok"],"server completes courier at correct citizen")
	var copper: int = session.actor.stats["copper"]
	check(not session.act("quest",{"action":"complete","qid":80004,"citizen":50179})["ok"] and session.actor.stats["copper"] == copper,"server rejects replayed quest reward")
	check(session.act("quest",{"action":"accept","qid":80591,"citizen":50179})["ok"] and session.act("quest",{"action":"buy","qid":80591,"citizen":50179})["ok"],"server authentic sword purchase")
	check(not session.act("discard",{"id":10010})["ok"] and not social.act(1,"auction_list",{"item_id":10010,"count":1,"price":10})["ok"],"quest sword protected across discard and consignment")
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50164]
	check(session.act("quest",{"action":"complete","qid":80591,"citizen":50164})["ok"] and session.items.count_item(10010) == 0,"server consumes quest sword once")
	var validator: ProgressionController = ProgressionController.new()
	var envelope: Dictionary = session.progression.journal_snapshot()
	envelope["version"] = ProgressionController.SAVE_VERSION
	envelope["player_stats"] = session.actor.stats
	check(validator.validate_save_data(envelope),"server character and completed journal satisfy save schema")
	var store: SessionStore = SessionStore.new()
	store.path = "res://build/server-session-%d.json" % OS.get_process_id()
	var registry: Dictionary = {"a".repeat(64):1,"b".repeat(64):2}
	check(store.commit(social,registry,3),"server character persists atomically")
	var loaded: Dictionary = store.load_state()
	check(not loaded.is_empty() and loaded["state"]["players"][1]["journal"]["completed_rewards"].size() == 2,"server journal survives JSON round trip")
	var corrupt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(store.path))
	corrupt["state"]["players"]["1"]["profile"]["skills"]["90014"] = 999
	check(store.normalize(corrupt).is_empty(),"server store rejects malformed full combat profile")
	# A source egg supplies a real pet; its strikes use the same server death path.
	session.items.add_item(30029)
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50180]
	check(session.act("pet_start_incubation",{"egg_id":30029})["ok"],"server breeder starts real egg incubation")
	session.actor.stats["incubations"][0]["hatch_at"] = 0.0
	check(session.act("pet_hatch",{"index":0})["ok"],"server hatches incubated pet")
	var pet_uid: String = session.actor.stats["companions"][0]["uid"]
	check(session.act("pet_summon",{"uid":pet_uid})["ok"],"server summons owned pet")
	simulation.actors[1]["position"] = Vector3(-8,0,27)
	var monster: Dictionary = simulation.monsters["WildBoar1"]
	monster["hp"] = 1
	monster["stats"]["evasion"] = 0.0
	session.pet_position = monster["position"]
	session.pet_target = "WildBoar1"
	var defeated: Array = []
	simulation.monster_defeated.connect(func(owner: int,key: String) -> void: defeated.append([owner,key]))
	session.tick_pet(0.1)
	check(monster["state"] == "dead" and defeated == [[1,"WildBoar1"]],"pet combat credits server owner through one death signal")
	session.tick_pet(2.0)
	check(defeated.size() == 1,"pet cannot duplicate defeated monster credit")
	for suffix: String in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix): DirAccess.remove_absolute(store.path+suffix)
	validator.free()
	session.queue_free()
	await process_frame
	print("SERVER_SESSION_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
