extends SceneTree
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player: Player = load("res://client/scenes/entities/player.tscn").instantiate()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	var controller: ProgressionController = ProgressionController.new()
	controller.auto_save_enabled = false
	root.add_child(controller)
	controller.bind_player(player)
	controller.quest_states[80591] = QuestData.QuestState.ACTIVE
	var npc: NPC = NPC.new()
	npc.citizen_id = 50179
	npc.npc_name = "Торговець"
	controller.get_npc_interaction(npc)
	npc.free()
	player.stats["inventory"] = {}
	player.stats["bag_capacity"] = 1
	player.stats["inventory"]["30016"] = 1
	var money: int = player.stats["copper"]
	check(not controller.buy_sword(),"quest purchase cannot overflow full bag")
	check(player.stats["inventory"].size() == 1 and player.stats["copper"] == money,"rejected quest purchase consumes nothing")
	player.stats["skills"]["90023"] = 1
	player.stats["hotbar"]["1"] = 90023
	check(not CharacterSystem.validate(player.stats),"passive ability rejected in saved active hotbar")
	player.stats["hotbar"]["1"] = 90036
	player.stats["warehouse"] = {"030037":1}
	check(not GameServices.validate(player.stats),"warehouse rejects noncanonical inaccessible item key")
	player.stats["warehouse"] = {}
	var old: Dictionary = player.stats.duplicate(true)
	for key: String in ["stat_points","skill_points","attributes","skills","hotbar","class_id","race_id","equipment","bag_capacity","warehouse_capacity","regeneration_effects","mounted","mount_id"]:
		old.erase(key)
	old["level"] = 5
	controller._migrate_profile(old)
	check(old["stat_points"] == 12 and old["skill_points"] == 5,"old high-level profiles receive earned point budgets")
	check(MountSystem.validate(old),"old profile receives valid unmounted state")
	player.stats["inventory"]["10086"] = 1
	MountSystem.register_acquisition(player.stats,10086,100.0)
	check(MountSystem.mount(player.stats,10086,200.0),"timed mount works during source three-day lease")
	MountSystem.dismount(player.stats)
	check(not MountSystem.mount(player.stats,10086,259301.0),"expired timed mount cannot be ridden")
	MountSystem.register_acquisition(player.stats,10086,500.0)
	check(player.stats["mount_acquired_at"]["10086"] == 100.0,"repeated acquisition bookkeeping cannot renew a lease")
	var inventory: InventorySystem = InventorySystem.new()
	player.stats["bag_capacity"] = 32
	inventory.bind_player(player)
	var services: GameServices = GameServices.new()
	services.bind_player(player,inventory)
	check(services.deposit(10086) and services.withdraw(10086) and player.stats["mount_acquired_at"]["10086"] == 100.0,"warehouse round trip cannot extend timed mount lease")
	var restored: Dictionary = JSON.parse_string(JSON.stringify({"class_id":130001,"owned_titles":[180003],"title_id":180003,"locked_items":[10003],"companions":[{"skills":[90014]}]}))
	ProfileCodec.normalize(restored)
	check(180003 in restored["owned_titles"] and 10003 in restored["locked_items"] and 90014 in restored["companions"][0]["skills"],"JSON restores identifier arrays with usable integer membership")
	check(TitleSystem.validate(restored) and TitleSystem.select(restored,180003),"owned original title survives JSON round trip")
	check(not TitleSystem.select(restored,180013),"unearned source title cannot be selected")
	restored["title_id"] = "bad"
	TitleSystem.ensure_stats(restored)
	check(not TitleSystem.validate(restored),"title initialization cannot launder invalid saved identifiers")
	controller.free()
	player.queue_free()
	await process_frame
	await process_frame
	print("REGRESSION_FEATURES_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
