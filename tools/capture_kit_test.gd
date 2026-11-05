extends SceneTree

## Renders a single kit house and the KayKit knight to check orientation:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_kit_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("9fc3e0")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.72, 0.8)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color("6f8f4e")
	ground.material_override = gm
	world.add_child(ground)
	var b: TownBuilder = TownBuilder.new()
	world.add_child(b)
	b.house(Vector3(0, 0, 0), 0.0, 3, 4, 2, {"roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6", "chimney": true})
	var knight: Node3D = (load("res://assets/characters/kaykit/Knight.glb") as PackedScene).instantiate()
	knight.position = Vector3(2.5, 0, 6.5)
	world.add_child(knight)
	var ap: AnimationPlayer = knight.find_child("AnimationPlayer", true, false)
	if ap: ap.play("Idle")
	var cam: Camera3D = Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	var views: Array = [[Vector3(9, 6, 14), Vector3(0, 3, 0)], [Vector3(-12, 8, -10), Vector3(0, 3, 0)], [Vector3(4, 1.6, 9.5), Vector3(2.5, 1.0, 6.5)]]
	for i: int in views.size():
		cam.position = views[i][0]
		cam.look_at(views[i][1])
		for f: int in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/kit-test-%d.png" % i)
	print("KIT_TEST_DONE")
	quit()
