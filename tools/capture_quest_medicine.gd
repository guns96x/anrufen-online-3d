extends SceneTree
func _initialize() -> void: call_deferred("capture")
func shot(path: String) -> void:
	for frame: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/"+path+".png")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var world: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame: int in 30: await process_frame
	for monster: Node in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	world.local_player.set_physics_process(false)
	world.local_player.position = ForestForage.POINTS[1]+Vector3(0,0,2)
	await shot("v06-forest-gathering")
	var controller: ProgressionController = world.hud.progression
	for entry: Array in [[80004,50179],[80591,50164],[80552,50166]]:
		controller.accept_quest(entry[0])
		if entry[0] == 80591:
			controller._last_citizen_id = 50179
			controller.buy_sword()
		controller.quest_states[entry[0]] = QuestData.QuestState.READY
		controller.quest_kills[entry[0]] = 1
		controller.complete_quest(entry[0],entry[1])
	controller.accept_quest(80005)
	controller.accept_quest(80006)
	for index: int in 10: controller.add_monster_kill(70071)
	controller.complete_quest(80006,50167)
	world.hud.show_dialogue_npc(world.get_node("NPC_Gourmand"))
	await shot("v06-cooking-story")
	world.hud.close_dialogue()
	world.hud.game_menu.open_tab("settings")
	var scroll: ScrollContainer = world.hud.game_menu.find_child("ContentScroll",true,false)
	for frame: int in 5: await process_frame
	for node: Node in world.hud.game_menu.find_children("*","CheckButton",true,false):
		if node.text == "Зілля здоров'я гравця автоматично": scroll.scroll_vertical = roundi(node.position.y)
	await shot("v06-auto-medicine-settings")
	world.hud.items.add_item(30029)
	world.hud.pets.start_incubation(30029)
	world.local_player.stats["incubations"][0]["hatch_at"] = 0.0
	world.hud.pets.hatch(0)
	world.hud.items.add_item(30754)
	world.hud.game_menu.open_tab("pets")
	await shot("v06-pet-mana")
	world.queue_free()
	await process_frame
	await process_frame
	print("QUEST_MEDICINE_CAPTURE: PASS")
	quit()
