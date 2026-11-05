extends SceneTree

## Renders Guanlin Town overview shots to build/town-*.png:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_town.gd -- --review

const VIEWS: Array = [
	["overview", Vector3(34, 46, 30), Vector3(0, 0, -26)],
	["gate", Vector3(10, 7, 30), Vector3(0, 3, 6)],
	["plaza", Vector3(9, 8, -16), Vector3(-2, 2, -32)],
	["chapel", Vector3(-8, 7, -30), Vector3(-26, 3, -45)],
	["tavern", Vector3(8, 6, -40), Vector3(0, 3, -60)],
	["market", Vector3(-6, 5, -12), Vector3(-20, 1.5, -20)],
]

func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i: int in 60:
		await process_frame
	world.hud.hide()
	var camera: Camera3D = Camera3D.new()
	camera.fov = 55
	camera.far = 400
	world.add_child(camera)
	camera.make_current()
	for v: Array in VIEWS:
		camera.position = v[1]
		camera.look_at(v[2])
		for i: int in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/town-%s.png" % v[0])
	world.hud.show()
	world.local_player.camera.make_current()
	for i: int in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/town-gameplay.png")
	print("TOWN_CAPTURED draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	quit()
