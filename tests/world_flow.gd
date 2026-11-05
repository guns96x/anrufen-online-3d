extends SceneTree

var failures: int = 0
var world: GuanlinTown
var completions: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func action(npc_name: String, qid: int, expected: String) -> void:
	world.hud.show_dialogue_npc(world.get_node(npc_name))
	check(world.hud.active_quest_id == qid, npc_name + " routes quest " + str(qid))
	check(world.hud._current_dialogue_action == expected, "dialogue action " + expected)
	world.hud._on_dialogue_accept()

func run() -> void:
	world = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var hud: GameHUD = world.hud
	var progression: ProgressionController = hud.progression
	progression.auto_save_enabled = false
	check(get_nodes_in_group("npcs").size() == GuanlinLayout.CITIZENS.size(), "story and service citizens exist")
	check(get_nodes_in_group("monsters").size() == 16, "original wildlife and five bandits exist")
	check(QuestData.DEFINITIONS.size() == 10 and not QuestData.DEFINITIONS.has(80003), "source investigation and cooking chain replace invented forging quest")
	hud.quest_completed.connect(func(qid: int, _xp: int, _atk: int) -> void: completions[qid] = completions.get(qid, 0) + 1)
	action("NPC_Elder", 80004, "accept")
	action("NPC_Weaponsmith", 80004, "complete")
	action("NPC_Weaponsmith", 80591, "accept")
	# Purchase is a distinct interaction rather than a free courier reward.
	hud.show_dialogue_npc(world.get_node("NPC_Weaponsmith"))
	check(hud._current_dialogue_action in ["buy", "buy_sword", "purchase"], "merchant offers actual sword purchase")
	hud._on_dialogue_accept()
	action("NPC_Elder", 80591, "complete")
	action("NPC_Elder", 80552, "accept")
	action("NPC_Militia", 80552, "complete")
	action("NPC_Militia", 80005, "accept")
	for entry: Array in [["NPC_Gourmand", 80006, 70071], ["NPC_Smuggler", 80010, 70073], ["NPC_Anna", 80012, 70076]]:
		action(entry[0], entry[1], "accept")
		check(not progression.complete_quest(entry[1]).get("success", false), "incomplete kill objective cannot claim reward")
		for i: int in 10:
			hud.add_monster_kill(entry[2])
		check(progression.quest_kills[entry[1]] == 10, "original ten-kill objective")
		action(entry[0], entry[1], "complete")
	world.local_player.gain_exp(5000)
	action("NPC_Militia", 80005, "complete")
	for entry: Array in [[80007,30037,10],[80008,30038,10],[80009,30039,5]]:
		action("NPC_Gourmand",entry[0],"accept")
		hud.items.add_item(entry[1],entry[2])
		action("NPC_Gourmand",entry[0],"complete")
	for qid: int in QuestData.DEFINITIONS:
		check(progression.quest_states[qid] == QuestData.QuestState.DONE, "quest complete " + str(qid))
		check(completions.get(qid, 0) == 1, "HUD emits reward once " + str(qid))
	# Test the live modal connection to movement and combat, then close with API.
	hud.show_dialogue_npc(world.get_node("NPC_Elder"))
	await process_frame
	check(world.local_player.controls_blocked and hud.is_modal_active(), "world applies dialogue control lock")
	hud.close_dialogue()
	await process_frame
	check(not world.local_player.controls_blocked, "closing dialogue restores controls")
	world.queue_free()
	await process_frame
	await process_frame
	print("WORLD_FLOW: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
