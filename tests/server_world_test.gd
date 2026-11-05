extends SceneTree
const Realm = preload("res://server/world_simulation.gd")
const Actor = preload("res://server/profile_actor.gd")
var sim: Realm
var social: SocialState
var wrappers: Array[Node] = []
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func fresh() -> void:
	social = SocialState.new()
	sim = Realm.new()
	sim.bind_social(social)
	for id: int in [101,202,303]:
		social.join(id,"Hero%d" % id)
		var profile: Dictionary = {"name":"Hero%d" % id,"class_name":"Воїн","level":1,"exp":0,"exp_to_next":100,"hp":100,"max_hp":100,"mp":100,"max_mp":100,"attack":22,"defense":8,"accuracy":1.0,"crit_rate":0.0,"evasion":0.0,"element":1,"copper":100,"inventory":{},"equipment":{},"bag_capacity":32}
		var actor = Actor.new()
		# Explicit v0.4 profile keeps regression coverage for migrated hotbars.
		profile["skills"] = {"90014":1,"90036":1}
		profile["hotbar"] = {"1":90036}
		actor.bind_profile(profile)
		wrappers.append(actor)
		social.players[id]["profile"] = profile
		sim.add_actor(id,Vector3(float((id/101)-1),0,0))

func profile(id: int = 101) -> Dictionary:
	return social.players[id]["profile"]

func isolate_boar() -> Dictionary:
	for key: String in sim.monsters:
		if key != "WildBoar1":
			sim.monsters[key]["state"] = "dead"
			sim.monsters[key]["respawn_timer"] = 999.0
	var monster: Dictionary = sim.monsters["WildBoar1"]
	monster["stats"]["evasion"] = 0.0
	sim.actors[101]["position"] = monster["position"] + Vector3(0,0,-1.0)
	return monster

func advance(seconds: float) -> void:
	var remaining: float = seconds
	while remaining > 0.000001:
		var step: float = minf(0.25,remaining)
		sim.tick(step)
		remaining -= step

func run() -> void:
	seed(145)
	fresh()
	check(sim.monsters.size() == 16 and sim.monsters.has("Bandit5"),"all16 original-zone encounters have stable keys")
	check(not sim.add_actor(101) and not sim.add_actor(999),"duplicate and unknown account spawns rejected")
	check(not sim.set_input(101,Vector2(50,0),0) and not sim.set_input(101,Vector2(NAN,0),0) and not sim.set_input(101,Vector2.ZERO,NAN),"speed vectors and nonfinite input rejected")
	check(sim.set_input(101,Vector2.RIGHT,0),"normalized world-XZ input accepted")
	sim.tick(0.25)
	check(is_equal_approx(sim.actors[101]["position"].x,1.5),"server walking speed capped at six")
	sim.tick(0.25)
	check(is_equal_approx(sim.actors[101]["position"].x,2.1),"input expires after350ms rather than moving forever")
	var stopped: Vector3 = sim.actors[101]["position"]
	sim.tick(0.25)
	check(sim.actors[101]["position"] == stopped,"expired input remains stopped")
	sim.set_input(101,Vector2.RIGHT,0)
	sim.tick(5.0)
	check(sim.actors[101]["position"].distance_to(stopped) <= 1.50001,"oversized server delta capped at quarter second")
	stopped = sim.actors[101]["position"]
	sim.tick(NAN)
	check(sim.actors[101]["position"] == stopped,"nonfinite delta ignored")
	sim.actors[101]["position"] = Vector3(39,0,65)
	sim.set_input(101,Vector2.RIGHT,0)
	sim.tick(0.25)
	check(sim.actors[101]["position"].x == 39.0,"map boundary enforced")
	sim.actors[101]["position"] = Vector3.ZERO
	sim.movement_allowed = func(_from: Vector3,_to: Vector3) -> bool: return false
	sim.set_input(101,Vector2.RIGHT,0)
	sim.tick(0.25)
	check(sim.actors[101]["position"] == Vector3.ZERO,"collision callback can reject movement")
	sim.movement_allowed = Callable()
	sim.set_input(101,Vector2.ZERO,0)
	check(sim.dash(101)["ok"] and not sim.dash(101)["ok"],"dash cooldown prevents request spam")
	sim.tick(0.18)
	check(is_equal_approx(sim.actors[101]["position"].z,-3.6),"dash distance is20 times180ms")
	profile()["inventory"]["10018"] = 1
	MountSystem.mount(profile(),10018)
	sim.actors[101]["position"] = Vector3.ZERO
	sim.set_input(101,Vector2.RIGHT,0)
	sim.tick(0.25)
	check(is_equal_approx(sim.actors[101]["position"].x,2.4),"mounted movement uses server-owned mount multiplier")
	var snapshot: Dictionary = sim.public_snapshot()
	check(not snapshot["actors"][101].has("profile") and not snapshot["actors"][101].has("inventory"),"public snapshot omits private profile and bag")
	snapshot["actors"][101]["cooldowns"]["attack"] = 999.0
	check(sim.actors[101]["cooldowns"]["attack"] != 999.0,"snapshot cannot mutate authoritative cooldowns")
	fresh()
	var monster: Dictionary = isolate_boar()
	monster["max_hp"] = 1000
	monster["hp"] = 1000
	var target: Dictionary = {"kind":"monster","id":"WildBoar1"}
	check(not sim.attack(101,{"kind":"monster","id":"WildBoar1","damage":999999})["ok"],"client-supplied damage field rejected")
	check(not sim.attack(101,{"kind":"monster","id":"missing"})["ok"] and not sim.attack(101,{"kind":"npc","id":"WildBoar1"})["ok"],"unknown and spoofed target types rejected")
	sim.actors[101]["position"] = Vector3.ZERO
	check(not sim.attack(101,target)["ok"] and sim.actors[101]["cooldowns"]["attack"] == 0.0,"out-of-reach hit rejected without cooldown charge")
	sim.actors[101]["position"] = monster["position"] + Vector3(0,0,-2)
	check(sim.attack(101,target)["ok"] and monster["hp"] < 1000,"authoritative melee computes damage")
	var health: int = monster["hp"]
	check(not sim.attack(101,target)["ok"] and monster["hp"] == health,"melee cooldown blocks repeated damage")
	profile()["mp"] = 0
	check(not sim.cast_skill(101,target)["ok"] and sim.actors[101]["cooldowns"]["fire"] == 0.0,"insufficient mana does not cast")
	profile()["mp"] = 100
	profile()["skills"] = {}
	check(not sim.cast_skill(101,target)["ok"],"unlearned skill cannot be cast")
	profile()["skills"] = {"90036":1}
	check(sim.cast_skill(101,target)["ok"] and profile()["mp"] == 85,"learned fire skill charges exact mana")
	check(not sim.cast_skill(101,target)["ok"] and profile()["mp"] == 85,"skill cooldown prevents repeated mana/damage action")
	profile()["skills"]["90035"] = 1
	profile()["hotbar"]["1"] = 90035
	sim.actors[101]["cooldowns"]["fire"] = 0.0
	check(not sim.cast_skill(101,target)["ok"],"server enforces minimum skill level")
	profile()["level"] = 3
	check(sim.cast_skill(101,target)["ok"] and monster["slow_timer"] == 3.0,"ice applies server slow")
	profile()["skills"]["90041"] = 1
	profile()["hotbar"]["1"] = 90041
	profile()["hp"] = 50
	profile()["mp"] = 100
	sim.actors[101]["cooldowns"]["fire"] = 0.0
	profile()["inventory"]["10018"] = 1
	MountSystem.mount(profile(),10018)
	check(not sim.attack(101,target)["ok"],"mount forbids outgoing melee")
	check(not sim.cast_skill(101,{"kind":"player","id":202})["ok"] and profile()["mp"] == 100,"self heal cannot spoof another target")
	check(sim.cast_skill(101)["ok"] and profile()["hp"] == 82 and profile()["mp"] == 85,"mounted self-heal is allowed and server-calculated")
	sim.actors[101]["cooldowns"]["fire"] = 0.0
	profile()["hotbar"]["1"] = 90036
	check(not sim.cast_skill(101,target)["ok"] and profile()["mp"] == 85,"mount forbids offensive magic")
	fresh()
	monster = isolate_boar()
	sim.tick(0.1)
	check(monster["state"] == "windup" and monster["warning_timer"] == 0.65 and profile()["hp"] == 100,"enemy announces committed windup before damage")
	sim.set_input(101,Vector2(0,-1),0)
	advance(0.65)
	check(profile()["hp"] == 100,"moving out of committed warning avoids damage")
	fresh()
	monster = isolate_boar()
	sim.tick(0.1)
	advance(0.55)
	sim.movement_allowed = func(_from: Vector3,_to: Vector3) -> bool: return false
	check(sim.dash(101)["ok"],"dash can begin during warning")
	sim.tick(0.1)
	check(profile()["hp"] == 100,"dash evades even when a wall prevents travel")
	fresh()
	monster = isolate_boar()
	sim.tick(0.1)
	advance(0.65)
	check(profile()["hp"] < 100,"standing in warning takes formula damage")
	monster["position"] = monster["spawn"] + Vector3(10,0,0)
	monster["hp"] = 5
	monster["state"] = "chase"
	monster["target"] = 101
	sim.actors[101]["position"] = Vector3(39,0,65)
	sim.tick(0.1)
	check(monster["state"] == "return" and monster["hp"] == 5,"leash returns before healing")
	advance(3.0)
	check(monster["position"] == monster["spawn"] and monster["hp"] == monster["max_hp"],"returning monster heals only after reaching home")
	fresh()
	monster = isolate_boar()
	profile()["attack"] = 1000
	var defeated: Array = []
	sim.monster_defeated.connect(func(id: int,key: String) -> void: defeated.append([id,key]))
	check(sim.attack(101,target)["ok"] and defeated == [[101,"WildBoar1"]] and monster["state"] == "dead","monster defeat emits one owning-account signal")
	check(not sim.attack(101,target)["ok"] and defeated.size() == 1 and profile()["exp"] == 0,"dead monster cannot grant duplicate credit and world awards no XP")
	advance(7.75)
	check(monster["state"] == "dead","monster does not respawn early")
	advance(0.25)
	check(monster["state"] == "idle" and monster["hp"] == monster["max_hp"],"monster respawns after eight server seconds")
	check(sim.attack(101,target)["ok"] and defeated.size() == 2,"next life can be defeated exactly once")
	fresh()
	var player_target: Dictionary = {"kind":"player","id":202}
	check(not sim.can_hurt(101,202) and not sim.attack(101,player_target)["ok"],"peaceful mode blocks outgoing PvP")
	check(not sim.set_pk_mode(101,"forged") and sim.set_pk_mode(101,"free"),"only server-supported PK modes accepted")
	check(sim.can_hurt(101,202),"free mode permits other-player combat")
	social.players[101]["party"] = 9
	social.players[202]["party"] = 9
	check(sim.can_hurt(101,202),"free mode permits friendly fire and differs from party mode")
	sim.set_pk_mode(101,"party")
	check(not sim.can_hurt(101,202),"same party protected from friendly fire")
	social.players[101]["party"] = 0
	social.players[202]["party"] = 0
	social.players[101]["guild"] = 7
	social.players[202]["guild"] = 7
	check(sim.can_hurt(101,202),"party mode does not silently act as guild mode")
	sim.set_pk_mode(101,"guild")
	check(not sim.can_hurt(101,202),"same guild protected from friendly fire")
	social.players[101]["guild"] = 0
	social.players[202]["guild"] = 0
	sim.set_pk_mode(101,"peaceful")
	check(sim.duel_request(101,202)["ok"] and not sim.can_hurt(101,202),"duel request alone does not authorize damage")
	check(not sim.duel_accept(303,101)["ok"] and not sim.duel_accept(202,303)["ok"],"duel consent cannot be spoofed")
	check(sim.duel_accept(202,101)["ok"] and sim.can_hurt(101,202) and sim.can_hurt(202,101),"accepted duel enables both peaceful participants")
	var events: Array = []
	sim.combat_event.connect(func(event: Dictionary) -> void: events.append(event))
	profile()["attack"] = 1000
	check(sim.attack(101,player_target)["ok"] and profile(202)["hp"] == 1 and not sim.actors[202]["dead"] and sim.duels.is_empty(),"duel finishes at one HP without death")
	check(events.any(func(event: Dictionary) -> bool: return event.get("type") == "duel_finished"),"duel completion event emitted")
	sim.set_pk_mode(101,"free")
	sim.actors[101]["cooldowns"]["attack"] = 0.0
	profile(202)["inventory"]["10018"] = 1
	MountSystem.mount(profile(202),10018)
	check(sim.attack(101,player_target)["ok"] and sim.actors[202]["dead"] and not profile(202)["mounted"],"nonduel lethal PvP kills and dismounts target")
	check(events.any(func(event: Dictionary) -> bool: return event.get("type") == "death" and event.get("attacker") == 101 and event.get("target") == 202 and not event.get("duel",true)),"authoritative death event carries stable accounts")
	check(not sim.set_input(202,Vector2.RIGHT,0) and not sim.attack(202,{"kind":"player","id":101})["ok"],"dead actor cannot move or attack")
	advance(2.75)
	check(sim.actors[202]["dead"],"actor does not respawn before three seconds")
	advance(0.25)
	check(not sim.actors[202]["dead"] and profile(202)["hp"] == profile(202)["max_hp"] and profile(202)["mp"] == profile(202)["max_mp"] and sim.actors[202]["position"] == sim.actors[202]["spawn"],"actor respawns at server spawn with full resources")
	fresh()
	sim.duel_request(101,202)
	sim.remove_actor(202)
	check(sim.duel_requests.is_empty() and sim.duels.is_empty(),"disconnect clears duel invitations")
	var progression = Actor.new()
	var original: Dictionary = profile().duplicate(true)
	original["inventory"] = {"10010":1}
	progression.bind_profile(original)
	progression.inventory.equip_item(10010)
	progression.gain_exp(235)
	check(original["level"] == 3 and original["exp"] == 0 and original["stat_points"] == 6 and original["skill_points"] == 3,"server profile actor levels with exact point awards")
	check(original["attack"] == 34 and original["hp"] == original["max_hp"] and original["mp"] == original["max_mp"],"server profile actor rebuilds equipped stats and restores resources")
	progression.free()
	for wrapper: Node in wrappers:
		wrapper.free()
	print("SERVER_WORLD_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
