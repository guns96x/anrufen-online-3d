extends SceneTree

## Renders the title screen, hero creation and an intro frame to build/start-*.png:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_start.gd -- --review

func _initialize() -> void:
	call_deferred("_run")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/start-%s.png" % name)

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var menu: Node = load("res://client/scenes/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await create_timer(1.6).timeout
	await _shot("title")
	menu._show_create()
	menu.race_id = 250002
	menu._update_cards()
	menu._refresh_hero()
	await create_timer(1.6).timeout
	await _shot("create")
	menu.queue_free()
	await process_frame
	NewHero.play_intro = true
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	await create_timer(5.2).timeout
	await _shot("intro")
	print("START_CAPTURED")
	quit()
