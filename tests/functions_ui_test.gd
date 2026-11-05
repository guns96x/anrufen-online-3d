extends SceneTree
var failures: int = 0
var world: GuanlinTown

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	world = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var hud: GameHUD = world.hud
	var player: Player = world.local_player
	for tab: String in GameMenu.TABS:
		hud.game_menu.open_tab(tab)
		await process_frame
		check(hud.is_modal_active() and player.controls_blocked,"menu tab renders and blocks world: " + tab)
	hud.close_dialogue()
	await process_frame
	check(not player.controls_blocked,"closing menu restores controls")
	check(hud.items.count_item(30016) == 3,"starter healing supplies granted once")
	var attack: int = player.stats["attack"]
	hud.items.add_item(10003)
	check(hud.items.equip_item(10003),"real bag equipment action")
	check(player.stats["attack"] > attack,"equipping changes actual combat attack")
	check(hud.items.unequip_item("weapon") and player.stats["attack"] == attack,"unequip removes bonus without drift")
	player.stats["hp"] = 10
	check(hud.items.use_item(30016) and player.stats["hp"] == 60,"bag potion heals live actor")
	player.stats["stat_points"] = 1
	check(CharacterSystem.allocate(player.stats,"strength"),"attribute point allocated")
	hud.on_systems_changed()
	check(player.stats["attack"] == attack+2,"attribute changes live attack")
	player.stats["level"] = 3
	player.stats["skill_points"] = 1
	check(CharacterSystem.learn_skill(player.stats,90041),"healing skill learned")
	check(CharacterSystem.assign_skill(player.stats,"1",90041),"skill assigned to action button")
	player.stats["hp"] = 1
	player.stats["mp"] = 50
	player.perform_skill_1()
	check(player.stats["hp"] > 1 and player.stats["mp"] == 35,"assigned healing skill executes in gameplay")
	player.cooldowns["fire"] = 0.0
	hud.items.add_item(30037,4)
	player.stats["copper"] = 1000
	check(hud.services.craft(0),"synthesis produces real items")
	check(hud.items.count_item(30037) == 2,"synthesis consumes exact materials")
	check(hud.services.deposit(30037),"warehouse deposits actual bag item")
	check(hud.services.withdraw(30037),"warehouse returns actual item")
	hud.items.add_item(30029)
	hud.pets.time_source = func() -> float: return 100.0
	check(hud.pets.start_incubation(30029),"live profile egg incubation starts")
	hud.pets.time_source = func() -> float: return 161.0
	check(hud.pets.hatch(0),"egg hatches into live profile")
	var uid: String = str(player.stats["companions"][0]["uid"])
	check(hud.pets.summon(uid),"pet summon action")
	await physics_frame
	await physics_frame
	var followers: Array[Node] = world.find_children("*","CompanionFollower",true,false)
	check(followers.size() == 1 and followers[0].visible,"summoned pet visible in actual world")
	var path: PackedVector3Array = player.pathfinder.find_route(GuanlinLayout.PLAZA+Vector3(0,0,7),GuanlinLayout.PLAZA+Vector3(0,0,-7),player.get_world_3d().direct_space_state)
	check(not path.is_empty(),"NPC route finds path around fountain")
	var blocked: bool = false
	for point: Vector3 in path:
		if Vector2(point.x-GuanlinLayout.PLAZA.x,point.z-GuanlinLayout.PLAZA.z).length() < 2.5:
			blocked = true
	check(not blocked,"route avoids fountain collision")
	var save_path: String = "res://build/functions-profile.json"
	check(hud.progression.save_to_file(save_path),"complete character/items/pets profile saves")
	player.stats["companions"] = []
	player.stats["summoned_pet"] = ""
	check(hud.progression.load_from_file(save_path),"complete profile restores")
	check(player.stats["companions"].size() == 1 and player.stats["summoned_pet"] == uid,"pet and summoned state survive disk round trip")
	var net: Node = root.get_node("NetworkManager")
	check(net.start_server(17881),"social tab can start real local server")
	net._server_state.join(2,"Draft Partner")
	net._broadcast()
	net.request("trade_request",{"target":2})
	var trade_id: int = int(net.social_snapshot["trade"]["id"])
	net._server_state.act(2,"trade_accept",{"trade_id":trade_id})
	net._broadcast()
	hud.game_menu.open_tab("social")
	hud.game_menu._trade_item_draft["30016"] = 2
	hud.game_menu._drafts["trade_copper"] = "10"
	hud.game_menu._drafts["chat_channel"] = 2
	net.request("chat",{"channel":"global","text":"Incoming while drafting"})
	await process_frame
	await process_frame
	check(hud.game_menu._trade_item_draft.get("30016",0) == 2 and hud.game_menu._drafts.get("trade_copper") == "10","incoming snapshot preserves unsent trade draft")
	var chat_channel_preserved: bool = false
	for control: Node in hud.game_menu.find_children("*","OptionButton",true,false):
		if control.item_count == 4 and control.get_item_text(0) == "Загальний":
			chat_channel_preserved = control.selected == 2
	check(chat_channel_preserved,"incoming snapshot preserves chosen chat channel")
	net.disconnect_session()
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path+suffix):
			DirAccess.remove_absolute(save_path+suffix)
	world.queue_free()
	await process_frame
	await process_frame
	print("FUNCTIONS_UI_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
