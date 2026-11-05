extends SceneTree
func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var world: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 5: await process_frame
	var net: Node = root.get_node("NetworkManager")
	net.persistence_enabled = false
	net.local_player_data = {"name":"Мандрівник"}
	if not net.start_server(17982): quit(1); return
	net._admit(42,"Вартовий",Crypto.new().generate_random_bytes(32).hex_encode())
	net.simulation.actors[2]["position"] = Vector3(7,0,6)
	net._broadcast()
	net._broadcast_world()
	for i: int in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/network-world.png")
	world.hud.game_menu.open_tab("social")
	for i: int in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/network-social.png")
	net.disconnect_session()
	world.queue_free()
	await process_frame
	await process_frame
	print("NETWORK_CAPTURE: PASS")
	quit()
