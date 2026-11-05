extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var player: Player = scene.local_player
	player.set_process(false)
	player.set_physics_process(false)
	player.stats["level"] = 30
	player.stats["skill_points"] = 30
	for i: int in 4: CharacterSystem.learn_skill(player.stats,90020)
	for i: int in 5: CharacterSystem.learn_skill(player.stats,90043)
	for i: int in 5: CharacterSystem.learn_skill(player.stats,90042)
	CharacterSystem.learn_skill(player.stats,90021)
	CharacterSystem.learn_skill(player.stats,90095)
	CharacterSystem.rebuild_stats(player.stats)
	player.stats["base_accuracy"] = 1.0
	player.stats["accuracy"] = 1.0
	player.stats["mp"] = player.stats["max_mp"]
	check(CharacterSystem.assign_skill(player.stats,"2",90021) and CharacterSystem.assign_skill(player.stats,"3",90020) and CharacterSystem.assign_skill(player.stats,"4",90095),"four active slots accept learned source skills")
	check(not CharacterSystem.assign_skill(player.stats,"5",90021) and not CharacterSystem.assign_skill(player.stats,"4",90043),"hotbar rejects unknown slot and passive skill")
	check(CharacterSystem.validate(player.stats),"four-slot profile validates with original skill prerequisites")
	var monster: Monster = scene.get_node("Monsters/WildBoar1")
	monster.current_hp = 10000
	monster.max_hp = 10000
	monster.stats["evasion"] = 0.0
	monster.set_physics_process(false)
	player.global_position = monster.global_position+Vector3(0,0,-1)
	player.current_target = monster
	var mp: int = int(player.stats["mp"])
	player.perform_assigned_skill("2")
	check(monster.current_hp < 10000 and player.stats["mp"] == mp-15,"second slot executes real offline knife skill")
	var hp: int = monster.current_hp
	player.perform_assigned_skill("2")
	check(monster.current_hp == hp and player.stats["mp"] == mp-15,"second-slot repeat obeys skill cooldown")
	player.perform_skill_1()
	hp = monster.current_hp
	player.perform_assigned_skill("3")
	check(monster.current_hp == hp,"same skill in another slot cannot bypass its per-skill cooldown")
	scene.hud.update_cooldowns(player)
	var button: Button = scene.hud.get_node("BottomRight/AssignedSkill4")
	check(button.visible and not scene.hud.get_node("BottomRight/AssignedSkill2").text.is_empty(),"assigned mobile controls become visible with live cooldown text")
	player.controls_blocked = false
	scene.hud._press_button(button)
	check(monster.current_hp < hp and player.stats["skill_cooldowns"].has("90095"),"actual touch-control dispatch executes fourth-slot charged swing")
	player.stats["hotbar"].erase("2")
	scene.hud.update_cooldowns(player)
	check(not scene.hud.get_node("BottomRight/AssignedSkill2").visible,"unassigned control disappears instead of becoming inert UI")
	check(InputMap.has_action("game_slot_2") and SettingsStore.KEYS["slot_4"] == KEY_4,"additional desktop skill keys use persistent settings map")
	var net: Node = root.get_node("NetworkManager")
	net.persistence_enabled = false
	net.start_server(17984)
	await process_frame
	await process_frame
	var account: int = int(net.social_snapshot["own_id"])
	var session: ServerGameSession = net._sessions[account]
	net.request("game_assign_skill",{"slot":"2","id":90020})
	check(session.actor.stats["hotbar"].get("2",0) == 90020,"server assigns additional slot into authoritative profile")
	var boar: Dictionary = net.simulation.monsters["WildBoar1"]
	boar["hp"] = 1000
	boar["max_hp"] = 1000
	boar["stats"]["evasion"] = 0.0
	net.simulation.actors[account]["position"] = boar["position"]+Vector3(0,0,-1)
	session.actor.stats["base_accuracy"] = 1.0
	net.request("game_skill",{"slot":"2","target":{"kind":"monster","id":"WildBoar1"}})
	check(boar["hp"] < 1000 and session.actor.stats["skill_cooldowns"].has("90020"),"server slot payload routes to the intended source skill")
	hp = int(boar["hp"])
	net.request("game_skill",{"slot":"99","target":{"kind":"monster","id":"WildBoar1"}})
	check(boar["hp"] == hp,"forged slot cannot reach a different ability")
	net.disconnect_session(false)
	scene.queue_free()
	await process_frame
	await process_frame
	print("HOTBAR_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
