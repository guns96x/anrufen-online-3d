extends SceneTree
func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("capture")
func capture() -> void:
	root.size = Vector2i(1280,720)
	var world: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 20: await process_frame
	var player: Player = world.local_player
	player.stats["copper"] = 1000
	CharacterSystem.choose_class(player.stats,130002,250002)
	player.stats["level"] = 20
	CharacterSystem.choose_class(player.stats,130005,250002)
	CharacterSystem.choose_class(player.stats,130008,250002)
	player.stats["skills"] = {"90122":5,"90124":5,"90125":5,"90126":1,"90123":1,"90129":1,"90132":1}
	player.stats["hotbar"] = {"1":90122,"2":90126,"3":90129,"4":90132}
	player.stats["skill_points"] = 3
	world.hud.on_systems_changed()
	player.stats["mp"] = player.stats["max_mp"]
	player.stats["hp"] = player.stats["max_hp"]
	for i: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/source-hotbar.png")
	world.hud.game_menu.open_tab("skills")
	for i: int in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/source-skills.png")
	world.queue_free()
	await process_frame
	await process_frame
	print("SOURCE_SKILL_CAPTURE: PASS")
	quit()
