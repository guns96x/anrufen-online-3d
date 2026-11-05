extends SceneTree

## Renders the combat HUD with a target and a cooldown running to build/hud-*.png:
## Godot_v4.7.2-stable_win64_console.exe --path . -s tools/capture_hud.gd -- --review

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var world: Node3D = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	for i: int in 40:
		await process_frame
	var p: Player = world.local_player
	p.global_position = Vector3(1.5, 0, -19)
	p.visual_root.rotation.y = PI * 0.85
	p.stats["hotbar"] = {"1": 90020, "2": 90036, "3": 90035, "4": 90041}
	for id: int in [90036, 90035, 90041]:
		p.stats["skills"][str(id)] = 1
	var boar: Node = world.get_node("Monsters").get_child(0)
	p.current_target = boar
	p.cooldowns["dash"] = 1.6
	await create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hud-combat.png")
	var npc: NPC = world.get_node("NPC_Militia")
	world.hud.show_dialogue_npc(npc)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/hud-dialogue.png")
	print("HUD_CAPTURED")
	quit()
