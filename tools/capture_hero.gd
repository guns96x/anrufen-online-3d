extends SceneTree

## Renders the player hero (idle, run, strike, cast, tier 3 gear) to build/hero-*.png:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_hero.gd

func _initialize() -> void:
	call_deferred("_capture")

func _shot(name: String) -> void:
	for i: int in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hero-%s.png" % name)

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 40:
		await process_frame
	var player: Player = world.local_player
	player.global_position = Vector3(2, 0, -18)
	player.visual_root.rotation.y = PI * 0.15
	world.hud.hide()
	var cam: Camera3D = Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(3.6, 1.7, -14.8)
	cam.look_at(Vector3(2, 1.0, -18))
	cam.fov = 45
	cam.make_current()
	await create_timer(0.6).timeout
	await _shot("idle")
	player.velocity = Vector3(0, 0, -6)
	await create_timer(0.5).timeout
	await _shot("run")
	player.velocity = Vector3.ZERO
	player._motion.strike()
	await create_timer(0.22).timeout
	await _shot("strike")
	player.stats["level"] = 32
	player._motion._rebuild()
	await create_timer(0.8).timeout
	await _shot("tier3")
	player._motion.strike()
	await create_timer(0.25).timeout
	await _shot("tier3-strike")
	print("HERO_CAPTURED")
	quit()
