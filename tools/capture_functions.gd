extends SceneTree

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var world: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 40:
		await process_frame
	world.hud.items.add_item(10002)
	world.hud.items.add_item(10004)
	world.hud.items.add_item(10010)
	world.hud.items.equip_item(10002)
	world.hud.items.equip_item(10010)
	world.local_player.stats["stat_points"] = 3
	world.hud.items.add_item(30029)
	world.hud.items.add_item(30458)
	world.hud.items.add_item(30015)
	world.hud.items.add_item(30749)
	world.hud.items.add_item(30751)
	world.hud.pets.start_incubation(30029)
	world.hud.pets.start_incubation(30458)
	var future: float = Time.get_unix_time_from_system()+61.0
	world.hud.pets.time_source = func() -> float: return future
	world.hud.pets.hatch(0)
	world.hud.pets.hatch(0)
	for tab: String in ["inventory","equipment","character","skills","pets","settings","social"]:
		world.hud.game_menu.open_tab(tab)
		for i: int in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/functions-%s.png" % tab)
	world.queue_free()
	await process_frame
	await process_frame
	print("FUNCTIONS_CAPTURE: PASS")
	quit()
