extends SceneTree
var failures: int = 0
var profile: String = "res://build/progression-test-%d.json" % Time.get_ticks_usec()
var controller: ProgressionController
var player: Player

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func visit(citizen: int) -> void:
	var npc: NPC = NPC.new()
	npc.citizen_id = citizen
	npc.npc_name = "Test citizen"
	controller.get_npc_interaction(npc)
	npc.free()

func finish(qid: int, citizen: int) -> bool:
	visit(citizen)
	return controller.complete_quest(qid, citizen).get("success", false)

func run() -> void:
	player = load("res://client/scenes/entities/player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	controller = ProgressionController.new(profile)
	controller.auto_save_enabled = false
	root.add_child(controller)
	controller.bind_player(player)
	check(not controller.accept_quest(80591), "locked quest rejected")
	check(controller.accept_quest(80004), "opening available")
	check(not controller.complete_quest(80004,50179)["success"], "courier must visit destination")
	check(finish(80004,50179), "courier reaches merchant")
	controller.accept_quest(80591)
	check(not finish(80591,50164), "delivery requires purchased sword")
	visit(50179)
	var copper: int = player.stats["copper"]
	check(controller.buy_sword(), "actual sword purchase")
	check(player.stats["copper"] == copper-200 and controller.has_sword(), "source purchase costs 200 copper")
	check(not controller.buy_sword(), "duplicate courier purchase rejected")
	visit(50164)
	check(not controller.complete_quest(80591,50166)["success"], "wrong NPC rejected")
	copper = player.stats["copper"]
	check(controller.complete_quest(80591,50164)["success"], "sword handover succeeds")
	check(not controller.has_sword() and player.stats["copper"] == copper+600, "item consumed and copper awarded once")
	check(not controller.complete_quest(80591,50164)["success"], "duplicate reward rejected")
	controller.accept_quest(80552)
	check(finish(80552,50166), "captain referral")
	controller.accept_quest(80005)
	for qid: int in [80006,80010,80012]:
		check(controller.quest_states[qid] == QuestData.QuestState.AVAILABLE, "witness available " + str(qid))
	controller.accept_quest(80010)
	controller.add_monster_kill(70076)
	check(controller.quest_kills[80010] == 0, "unrelated kill ignored")
	for i: int in 9:
		controller.add_monster_kill(70073)
	check(not controller.complete_quest(80010,50169)["success"], "nine kills cannot turn in")
	check(controller.save_to_file(), "partial progress saves")
	check(controller.save_to_file() and FileAccess.file_exists(profile+".bak"), "replacement preserves backup")
	var saved: String = FileAccess.get_file_as_string(profile)
	check(controller.validate_save_data(JSON.parse_string(saved)), "serialized JSON numeric types validate")
	controller.quest_kills[80010] = 0
	check(controller.load_from_file() and controller.quest_kills[80010] == 9, "disk round trip restores partial kills")
	controller.add_monster_kill(70073)
	controller.add_monster_kill(70073)
	check(controller.quest_kills[80010] == 10, "kill count capped")
	check(finish(80010,50169), "smuggler report")
	for entry: Array in [[80006,70071,50167],[80012,70076,50168]]:
		controller.accept_quest(entry[0])
		for i: int in 10:
			controller.add_monster_kill(entry[1])
		check(finish(entry[0],entry[2]), "witness report " + str(entry[0]))
	player.stats["level"] = 7
	controller.quest_states[80005] = QuestData.QuestState.ACTIVE
	controller.refresh_available_quests()
	check(not finish(80005,50166), "reports also require level eight")
	player.stats["level"] = 8
	controller.refresh_available_quests()
	check(finish(80005,50166), "investigation completes at eight")
	check(controller.save_to_file(), "completed graph saves")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile))
	var bad: Dictionary = valid.duplicate(true)
	bad["quests"]["80004"] = "invalid"
	check(not controller.validate_save_data(bad), "bad nested quest rejected safely")
	bad = valid.duplicate(true)
	bad["player_stats"]["hp"] = "invalid"
	check(not controller.validate_save_data(bad), "string stat rejected")
	bad = valid.duplicate(true)
	bad["completed_rewards"].append(80004)
	check(not controller.validate_save_data(bad), "duplicate reward ledger rejected")
	bad = valid.duplicate(true)
	bad["player_stats"]["hp"] = 0
	var file: FileAccess = FileAccess.open(profile,FileAccess.WRITE)
	file.store_string(JSON.stringify(bad))
	file.close()
	check(controller.load_from_file() and player.stats["hp"] == player.stats["max_hp"], "fallen save restores healthy player")
	file = FileAccess.open(profile,FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	check(not controller.load_from_file(), "corrupt JSON rejected")
	check(not controller.save_to_file() and FileAccess.get_file_as_string(profile) == "{broken-json", "corrupt file protected from autosave")
	controller.free()
	player.queue_free()
	await process_frame
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile+suffix):
			DirAccess.remove_absolute(profile+suffix)
	print("PROGRESSION_SUITE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
