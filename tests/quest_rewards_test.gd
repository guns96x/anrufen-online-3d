extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rules: Dictionary = OriginalQuestCatalog.rules()
	check(rules.size() == 712,"all original task footers are accessible")
	var verified: int = 0
	for rule: Dictionary in rules.values():
		if rule["reward_length_valid"]: verified += 1
	check(verified == 709,"reward block lengths independently verify 709 records")
	check(OriginalQuestCatalog.get_rule(80006)["next_id"] == 80007 and OriginalQuestCatalog.get_rule(80007)["next_id"] == 80008,"cooking chain follows binary next-task links")
	check(OriginalQuestCatalog.get_rule(80005)["minimum_turnin_level"] == 8,"original investigation requires level eight")
	check(OriginalQuestCatalog.rewards(80552,130006)["items"] == {"10002":1},"warrior descendant receives only warrior helmet")
	check(OriginalQuestCatalog.rewards(80552,130009)["items"] == {"10005":1},"mage descendant receives only mage headpiece")
	var actor: ProfileActor = ProfileActor.new()
	var stats: Dictionary = {}
	ServerGameSession.upgrade_profile(stats)
	actor.bind_profile(stats)
	root.add_child(actor)
	var progression: ProgressionController = ProgressionController.new()
	progression.auto_save_enabled = false
	root.add_child(progression)
	progression.bind_player(actor)
	progression.accept_quest(80004)
	var npc: NPC = NPC.new()
	npc.citizen_id = 50179
	npc.npc_name = "Merchant"
	progression.get_npc_interaction(npc)
	var before: int = stats["copper"]
	check(progression.complete_quest(80004,50179)["success"] and stats["copper"] == before+300 and stats["exp"] == 45,"first source reward grants currency and experience through transaction")
	check(180049 in stats["owned_titles"],"source welcome title is actually earned")
	progression.accept_quest(80591)
	progression.buy_sword()
	npc.citizen_id = 50164
	progression.get_npc_interaction(npc)
	check(progression.complete_quest(80591,50164)["success"],"source sword purchase and delivery remain reachable")
	progression.accept_quest(80552)
	npc.citizen_id = 50166
	progression.get_npc_interaction(npc)
	stats["bag_capacity"] = stats["inventory"].size()
	var snapshot: Dictionary = stats.duplicate(true)
	check(not progression.complete_quest(80552,50166)["success"] and stats == snapshot and not progression.completed_rewards.has(80552),"full bag cannot consume or partially grant a class reward")
	stats["bag_capacity"] = 32
	check(progression.complete_quest(80552,50166)["success"] and actor.inventory.count_item(10002) == 1 and actor.inventory.count_item(10005) == 0,"free space allows the complete source equipment reward")
	progression.accept_quest(80005)
	progression.accept_quest(80006)
	for index: int in 10: progression.add_monster_kill(70071)
	npc.citizen_id = 50167
	progression.get_npc_interaction(npc)
	check(progression.complete_quest(80006,50167)["success"] and actor.inventory.count_item(30000) == 1 and actor.inventory.count_item(30024) == 1,"witness grants physical report plus original petition item")
	check(not progression.complete_quest(80006,50167)["success"] and actor.inventory.count_item(30000) == 1,"replayed witness cannot duplicate report")
	check(30000 in progression.quest_item_locks(),"unfinished investigation protects physical reports")
	check(progression.accept_quest(80007),"source next link unlocks first cooking stage")
	actor.inventory.add_item(30037,9)
	progression.refresh_available_quests()
	check(progression.quest_kills[80007] == 9 and not progression.complete_quest(80007,50167)["success"],"collection uses actual inventory rather than monster kill count")
	actor.inventory.add_item(30037)
	progression.refresh_available_quests()
	stats["locked_items"] = [30037]
	check(not progression.complete_quest(80007,50167)["success"] and actor.inventory.count_item(30037) == 10,"manual item lock prevents quest handover")
	stats["locked_items"] = []
	check(progression.complete_quest(80007,50167)["success"] and actor.inventory.count_item(30037) == 0,"cooking consumes exact collected ingredients")
	check(progression.accept_quest(80008),"second cooking stage unlocks after first reward")
	actor.inventory.add_item(30038,10)
	progression.refresh_available_quests()
	actor.inventory.remove_item(30038)
	progression.refresh_available_quests()
	check(progression.quest_states[80008] == QuestData.QuestState.ACTIVE and not progression.complete_quest(80008,50167)["success"],"removing ingredients revokes ready status")
	actor.inventory.add_item(30038)
	check(progression.complete_quest(80008,50167)["success"] and progression.accept_quest(80009),"collection handover rechecks live quantities")
	var forage: ForestForage = ForestForage.new()
	check(not forage.harvest(1,Vector3.ZERO,actor.inventory,100),"gathering rejects remote harvest")
	check(forage.harvest(1,ForestForage.POINTS[1],actor.inventory,100) and not forage.harvest(1,ForestForage.POINTS[1],actor.inventory,100),"plant yields once then enters regrowth")
	check(not forage.harvest(1,ForestForage.POINTS[1],actor.inventory,159.9) and forage.harvest(1,ForestForage.POINTS[1],actor.inventory,160),"regrowth boundary is enforced")
	for id: int in [2,3,4]: forage.harvest(id,ForestForage.POINTS[id],actor.inventory,160)
	check(progression.complete_quest(80009,50167)["success"] and actor.inventory.count_item(30039) == 0 and actor.inventory.count_item(30041) == 1,"five gathered vegetables complete cooking and award the original dish")
	var legacy: Dictionary = progression.journal_snapshot()
	legacy["version"] = 5
	legacy["player_stats"] = stats.duplicate(true)
	legacy.erase("quest_revision")
	legacy.erase("legacy_report_credits")
	for id: int in [80007,80008,80009]:
		legacy["quests"].erase(str(id))
		legacy["completed_rewards"].erase(id)
	legacy["active_quest_id"] = 80006
	legacy["player_stats"]["inventory"].erase("30000")
	var upgraded: Dictionary = progression.upgrade_envelope(legacy)
	check(progression.validate_save_data(legacy) and upgraded["legacy_report_credits"] == [30000],"old seven-record save migrates missing physical report without bag mutation")
	check(progression.validate_save_data(JSON.parse_string(JSON.stringify(upgraded))),"migration survives JSON numeric conversion")
	var bad: Dictionary = upgraded.duplicate(true)
	bad["legacy_report_credits"] = [30031]
	check(not progression.validate_save_data(bad),"migration cannot invent a report from an unfinished witness")
	bad = upgraded.duplicate(true)
	bad["quests"]["80006"] = "broken"
	check(not progression.validate_save_data(bad),"malformed migration witness is rejected safely")
	var social: SocialState = SocialState.new()
	social.join(1,"Gatherer")
	var simulation: WorldSimulation = WorldSimulation.new()
	simulation.bind_social(social)
	ServerGameSession.upgrade_profile(social.players[1]["profile"])
	simulation.add_actor(1,Vector3.ZERO)
	var session: ServerGameSession = ServerGameSession.new()
	root.add_child(session)
	session.bind_account(1,social,simulation)
	check(not session.act("forage",{"id":1})["ok"],"server rejects spoofed remote gather")
	simulation.actors[1]["position"] = ForestForage.POINTS[1]
	check(session.act("forage",{"id":1})["ok"] and session.items.count_item(30039) == 1,"server gathers into authoritative inventory")
	check(not session.act("forage",{"id":1})["ok"],"repeated online gather cannot replay yield")
	session.free()
	npc.free()
	progression.free()
	actor.free()
	await process_frame
	print("QUEST_REWARDS_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
