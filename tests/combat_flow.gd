extends SceneTree

var failures: int = 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(275)
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var player: Player = load("res://client/scenes/entities/player.tscn").instantiate()
	stage.add_child(player)
	var monster: Monster = load("res://client/scenes/entities/monster.tscn").instantiate()
	stage.add_child(monster)
	player.set_physics_process(false)
	player.set_process(false)
	monster.set_physics_process(false)
	player.global_position = Vector3(0, 0, -1)
	monster.global_position = Vector3.ZERO
	monster.target_player = player
	var hp: int = player.stats["hp"]
	monster._execute_attack()
	check(player.stats["hp"] == hp and monster.windup_left > 0.0, "enemy warns before dealing damage")
	player.global_position = Vector3(0, 0, -5)
	monster._resolve_attack()
	check(player.stats["hp"] == hp, "leaving warning avoids hit")
	player.global_position = Vector3(0, 0, -1)
	monster._execute_attack()
	player.dash_timer = player.DASH_DURATION
	monster._resolve_attack()
	check(player.stats["hp"] == hp, "dash avoids committed attack")
	player.dash_timer = 0.0
	player.stats["evasion"] = 0.0
	monster._execute_attack()
	monster._resolve_attack()
	check(player.stats["hp"] < hp, "standing in warning receives formula damage")
	player.controls_blocked = true
	player.perform_attack()
	player.perform_skill_1()
	player.perform_skill_2()
	check(player.cooldowns["attack"] == 0 and player.cooldowns["fire"] == 0 and player.cooldowns["dash"] == 0, "dialogue locks combat controls")
	player.controls_blocked = false
	var exp_before: int = player.stats["exp"]
	monster.take_damage({"damage": 10000}, player)
	var exp_after: int = player.stats["exp"]
	monster.take_damage({"damage": 10000}, player)
	check(monster.is_dead() and exp_after > exp_before and player.stats["exp"] == exp_after, "enemy rewards experience once per death")
	check(monster.windup_left == 0.0 and not monster._telegraph.visible, "death cancels pending attack")
	monster.respawn()
	check(not monster.is_dead() and monster.current_hp == monster.max_hp and monster.attack_cooldown == 0.0, "respawn resets combat state")
	stage.queue_free()
	await process_frame
	await process_frame
	print("COMBAT_FLOW: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
