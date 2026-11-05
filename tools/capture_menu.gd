extends SceneTree

## Renders menu tabs to build/menu-*.png:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_menu.gd -- --review

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	for i: int in 40:
		await process_frame
	var hud: GameHUD = world.hud
	for id: int in [10010, 30037, 30038, 30016, 30645]:
		hud.items.add_item(id, 3 if id > 30000 else 1)
	hud.items.equip_item(10010)
	for tab: String in ["inventory", "equipment", "skills", "journal"]:
		hud.game_menu.open_tab(tab)
		await create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/menu-%s.png" % tab)
	print("MENU_CAPTURED")
	quit()
