extends SceneTree

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 90:
		await process_frame
	await create_timer(2.0).timeout
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(21, 20, 29)
	camera.look_at(Vector3(0, 1, -7))
	camera.fov = 60
	camera.make_current()
	world.hud.hide()
	for i: int in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/review-village.png")
	world.hud.show()
	world.local_player.camera.make_current()
	for i: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/review-gameplay.png")
	print("RENDER_METRICS draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	world.hud._display_dialogue("Капітан ополчення", QuestData.DEFINITIONS[80005]["offer_text"], 80005, "accept", "Прийняти доручення", "Пізніше")
	for i: int in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/review-dialogue.png")
	print("VISUAL_REVIEW_CAPTURED")
	world.queue_free()
	await process_frame
	quit()
