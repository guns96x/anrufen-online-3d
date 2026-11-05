extends SceneTree
var failures: int = 0
var social: SocialState
var realm: WorldSimulation
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func fresh(class_id: int, skills: Dictionary, hotbar: int) -> void:
	social = SocialState.new()
	realm = WorldSimulation.new()
	realm.bind_social(social)
	for id: int in [1,2,3]:
		social.join(id,"Hero %d" % id)
		var stats: Dictionary = social.players[id]["profile"]
		ServerGameSession.upgrade_profile(stats)
		stats["class_id"] = class_id if id == 1 else 130001
		stats["level"] = 20
		stats["skills"] = skills.duplicate(true) if id == 1 else {}
		stats["hotbar"] = {"1":hotbar} if id == 1 else {}
		stats["base_accuracy"] = 1.0
		stats["base_evasion"] = 0.0
		CharacterSystem.rebuild_stats(stats)
		stats["hp"] = stats["max_hp"]
		stats["mp"] = stats["max_mp"]
		realm.add_actor(id,Vector3(id,0,0))
	for monster: Dictionary in realm.monsters.values():
		monster["state"] = "dead"
		monster["respawn_timer"] = 9999.0
func profile(id: int = 1) -> Dictionary:
	return social.players[id]["profile"]
func run() -> void:
	fresh(130001,{"90020":1},90020)
	var boar: Dictionary = realm.monsters["WildBoar1"]
	boar.merge({"state":"idle","position":Vector3(2,0,0),"hp":1000,"max_hp":1000},true)
	boar["stats"]["evasion"] = 0.0
	var mp: int = int(profile()["mp"])
	check(realm.cast_skill(1,{"kind":"monster","id":"WildBoar1"})["ok"] and boar["hp"] < 1000,"original sword skill changes actual server monster HP")
	check(profile()["mp"] == mp and profile()["skill_cooldowns"]["90020"] == 0.8,"source free attack uses real 800ms cooldown")
	var hp: int = int(boar["hp"])
	check(not realm.cast_skill(1,{"kind":"monster","id":"WildBoar1"})["ok"] and boar["hp"] == hp,"server rejects repeated source skill during its own cooldown")
	fresh(130004,{"90104":1},90104)
	social.players[1]["party"] = 10
	social.players[2]["party"] = 10
	var base: int = int(profile()["max_hp"])
	var other_base: int = int(profile(3)["max_hp"])
	check(realm.cast_skill(1)["ok"] and profile()["max_hp"] == base+1200 and profile(2)["max_hp"] == base+1200 and profile(3)["max_hp"] == other_base,"actual aura affects self and nearby party only")
	profile()["hp"] = base+100
	realm.tick(0.1)
	check(profile()["hp"] >= base+100,"rebuilding active aura cannot truncate healed HP back to unbuffed maximum")
	profile()["skill_effects"][0]["remaining"] = 0.1
	realm.tick(0.2)
	check(profile()["max_hp"] == base and profile()["hp"] <= base,"source aura expiration restores underlying maximum safely")
	fresh(130005,{"90129":1},90129)
	check(realm.cast_skill(1)["ok"],"source magic shield casts in authoritative world")
	hp = int(profile()["hp"])
	mp = int(profile()["mp"])
	check(realm._damage_actor(2,1,100) == 36 and profile()["hp"] == hp-36 and profile()["mp"] == mp-128,"server damage respects shield damage-to-MP conversion")
	fresh(130007,{"90119":10},90119)
	StatusEffects.add(profile(),90134,1,10,false,{"rooted":1.0},2)
	check(realm.cast_skill(1)["ok"] and StatusEffects.speed_multiplier(profile()) > 0.0,"source cleanse removes an actual frozen state")
	fresh(130009,{"90139":1},90139)
	realm.set_pk_mode(1,"free")
	realm.duel_request(1,2)
	realm.duel_accept(2,1)
	check(realm.cast_skill(1,{"kind":"player","id":2})["ok"] and not profile(2)["skill_effects"].is_empty(),"shadow curse installs attributed periodic effect on a legal player")
	realm.duel_cancel(1)
	hp = int(profile(2)["hp"])
	for i: int in 24: realm.tick(0.25)
	check(profile(2)["hp"] == hp and profile(2)["skill_effects"].is_empty(),"ending duel removes harmful duel effects even if caster's PK mode is free")
	fresh(130007,{"90121":15},90121)
	realm.set_pk_mode(1,"free")
	realm.duel_request(1,2)
	realm.duel_accept(2,1)
	check(realm.cast_skill(1,{"kind":"player","id":2})["ok"] and profile(2)["hp"] == 1 and not realm.actors[2]["dead"],"remaining combo segments cannot kill after duel finishes at one HP")
	fresh(130001,{"90122":1},90122)
	check(not realm.cast_skill(1,{"kind":"player","id":2})["ok"],"server blocks skill belonging to another class line")
	fresh(130006,{"90106":1},90106)
	boar = realm.monsters["WildBoar1"]
	boar.merge({"state":"idle","position":Vector3(2,0,0),"hp":1000,"max_hp":1000},true)
	realm._add_monster_threat(boar,2,2000)
	check(realm.cast_skill(1,{"kind":"monster","id":"WildBoar1"})["ok"] and boar["target"] == 2 and boar["threat"][1] == 1000,"taunt adds original threat amount instead of unconditionally stealing aggro")
	profile()["skill_cooldowns"].clear()
	realm.cast_skill(1,{"kind":"monster","id":"WildBoar1"})
	profile()["skill_cooldowns"].clear()
	realm.cast_skill(1,{"kind":"monster","id":"WildBoar1"})
	check(boar["target"] == 1 and boar["threat"][1] == 3000,"accumulated taunt overtakes stronger existing threat")
	var scene: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var player: Player = scene.local_player
	player.set_process(false)
	player.set_physics_process(false)
	player.stats["skills"] = {"90020":1}
	player.stats["hotbar"] = {"1":90020}
	player.stats["accuracy"] = 1.0
	var monster: Monster = scene.get_node("Monsters/WildBoar1")
	monster.current_hp = 1
	monster.stats["evasion"] = 0.0
	player.global_position = monster.global_position+Vector3(0,0,-1)
	player.current_target = monster
	var exp: int = int(player.stats["exp"])
	player.perform_skill_1()
	check(monster.is_dead() and player.stats["exp"] > exp,"same source action plan drives actual offline damage, death and rewards")
	exp = int(player.stats["exp"])
	player.perform_skill_1()
	check(player.stats["exp"] == exp,"offline source-skill replay cannot duplicate monster reward")
	scene.queue_free()
	await process_frame
	await process_frame
	print("ORIGINAL_SKILL_FLOW_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
