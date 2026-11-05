extends SceneTree
var failures: int = 0
var now: float = 1000.0
class FakeNetwork:
	extends Node
	var requests: Array[Dictionary] = []
	func request(action: String, payload: Dictionary) -> void:
		requests.append({"action":action,"payload":payload.duplicate(true)})
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var actor: ProfileActor = ProfileActor.new()
	var stats: Dictionary = {}
	ServerGameSession.upgrade_profile(stats)
	actor.bind_profile(stats)
	root.add_child(actor)
	var inventory: InventorySystem = actor.inventory
	inventory.time_source = func() -> float: return now
	var pets: CompanionSystem = CompanionSystem.new()
	pets.time_source = func() -> float: return now
	pets.bind_player(actor)
	stats["companions"] = [{"uid":"pet-one","species_id":140052,"name":"Шакал","level":1,"exp":0,"hp":10,"max_hp":60,"hunger":100,"born_at":0.0,"skills":[90036]}]
	pets.bind_player(actor)
	stats["summoned_pet"] = "pet-one"
	var pet: Dictionary = pets.get_pet("pet-one")
	check(pet["mp"] == 40 and pet["max_mp"] == 40,"legacy pet receives complete mana fields")
	pet["mp"] = 2
	stats["hp"] = 10
	stats["mp"] = 2
	var options: Dictionary = SettingsStore.DEFAULTS.duplicate(true)
	for key: String in ["auto_potion","auto_mp","auto_pet_hp","auto_pet_mp"]: options[key] = true
	check(AutoMedicine.intents(stats,options,now).is_empty(),"basic manual potion is absent from original automatic priority list")
	for values: Array in AutoMedicine.PRIORITIES.values():
		for id: int in values: inventory.add_item(id,2)
	var intents: Array[Dictionary] = AutoMedicine.intents(stats,options,now)
	check(intents.size() == 4,"four independent automatic resource intents are selected")
	check(intents[0]["payload"]["id"] == 30114 and intents[1]["payload"]["id"] == 30162 and intents[2]["payload"]["id"] == 30020 and intents[3]["payload"]["id"] == 30754,"original first-choice IDs and category order are honored")
	check(intents[2]["payload"]["uid"] == "pet-one" and intents[2]["action"] == "pet_medicate","automatic pet medicine targets summoned UID")
	stats["locked_items"] = [30114]
	check(AutoMedicine.intents(stats,options,now)[0]["payload"]["id"] == 30842,"locked first choice falls back to next original potion")
	stats["locked_items"] = []
	stats["hp"] = 30
	stats["max_hp"] = 100
	check(AutoMedicine.intents(stats,options,now).size() == 3,"exact thirty percent threshold does not trigger HP medicine")
	stats["hp"] = 29
	check(AutoMedicine.intents(stats,options,now).size() == 4,"strictly below threshold triggers HP medicine")
	check(inventory.use_item(30114) and stats["hp"] == 79 and inventory.count_item(30114) == 1,"automatic HP item also has actual manual restoration effect")
	var snapshot: Dictionary = stats.duplicate(true)
	check(not inventory.use_item(30842) and stats == snapshot,"switching potion IDs cannot bypass category cooldown")
	check(AutoMedicine.intents(stats,options,now).size() == 3,"active cooldown excludes player HP category")
	check(inventory.use_item(30162) and stats["mp"] == 32,"player MP restores independently of HP cooldown")
	check(pets.medicate("pet-one",30020) and pet["hp"] == 60,"pet HP priority potion restores actual pet health")
	check(pets.medicate("pet-one",30754) and pet["mp"] == 32,"pet MP potion restores actual pet mana")
	check(AutoMedicine.intents(stats,options,now).is_empty(),"cooldowns and restored resource levels prevent repeated consumption")
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(stats))
	ProfileCodec.normalize(reloaded)
	check(MedicineState.validate(reloaded) and not MedicineState.available(reloaded,"player_hp",now+4.99) and MedicineState.available(reloaded,"player_hp",now+5),"cooldown survives JSON reload and expires at exact deadline")
	var bad: Dictionary = stats.duplicate(true)
	bad["medicine_cooldowns"]["hp"] = now
	check(not MedicineState.validate(bad),"unknown cooldown group cannot masquerade as a real resource")
	bad = stats.duplicate(true)
	bad["medicine_cooldowns"]["pet_mp"] = NAN
	check(not inventory.validate_state(bad),"nonfinite medicine deadline rejects profile")
	bad = stats.duplicate(true)
	bad["companions"][0]["mp"] = "bad"
	check(not pets.validate_state(bad),"malformed pet MP is rejected")
	bad = stats.duplicate(true)
	bad["companions"][0].erase("max_mp")
	check(not pets.validate_state(bad),"partial pet resource fields are rejected")
	bad = stats.duplicate(true)
	bad["companions"][0].erase("mp")
	bad["companions"][0].erase("max_mp")
	check(pets.validate_state(bad),"fully legacy pet schema remains readable")
	now += 5
	stats["hp"] = 0
	pet["hp"] = 1
	pet["mp"] = 0
	check(AutoMedicine.intents(stats,options,now).is_empty() and not inventory.use_item(30114) and not pets.medicate("pet-one",30754),"dead owner cannot use or automatically consume medicine")
	stats["hp"] = 100
	pet["hp"] = 0
	check(not pets.heal("pet-one") and AutoMedicine.intents(stats,options,now).is_empty(),"healing potion never revives a dead pet")
	pet["hp"] = 10
	stats["summoned_pet"] = ""
	check(AutoMedicine.intents(stats,options,now).is_empty(),"dismissed pets do not trigger automatic consumption")
	stats["summoned_pet"] = "pet-one"
	pet["mp"] = 6
	check(pets.combat_strike("pet-one")["element"] == CombatFormulas.DamageType.FIRE and pet["mp"] == 0,"elemental pet strike spends real pet mana")
	check(pets.combat_strike("pet-one")["element"] == CombatFormulas.DamageType.PHY and pet["mp"] == 0,"empty pet mana falls back to physical attack without underflow")
	var settings: SettingsStore = SettingsStore.current()
	check(settings.set_value("auto_pet_mp",true) and settings.set_value("pet_mp_potion_threshold",0.4),"all new automation preferences are writable")
	check(not settings.set_value("mp_potion_threshold",NAN) and not settings.set_value("auto_mp",1),"automation settings reject malformed values")
	settings.reset_defaults()
	var social: SocialState = SocialState.new()
	social.join(1,"Medic")
	ServerGameSession.upgrade_profile(social.players[1]["profile"])
	var world: WorldSimulation = WorldSimulation.new()
	world.bind_social(social)
	world.add_actor(1)
	var session: ServerGameSession = ServerGameSession.new()
	root.add_child(session)
	session.bind_account(1,social,world)
	session.items.add_item(30114,2)
	session.actor.stats["hp"] = 10
	check(session.act("use",{"id":30114})["ok"] and not session.act("use",{"id":30114})["ok"],"authority enforces cooldown against duplicate client commands")
	session.actor.stats["companions"] = stats["companions"].duplicate(true)
	session.pets.bind_player(session.actor)
	session.items.add_item(30754)
	check(not session.act("pet_medicate",{"uid":"another-pet","id":30754})["ok"] and session.act("pet_medicate",{"uid":"pet-one","id":30754})["ok"],"authority rejects foreign pet UID and restores owned pet mana")
	session.free()
	actor.free()
	# Actual HUD online path must only send intentions until authority responds.
	var player: Player = load("res://client/scenes/entities/player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	var hud: GameHUD = load("res://client/scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	await process_frame
	hud.progression.auto_save_enabled = false
	player.set_meta("network_world",true)
	player.stats["hp"] = 1
	hud.items.add_item(30114)
	var network: Node = root.get_node("NetworkManager")
	network.name = "SavedNetwork"
	var fake: FakeNetwork = FakeNetwork.new()
	fake.name = "NetworkManager"
	root.add_child(fake)
	settings.values["auto_potion"] = true
	var original: Dictionary = player.stats.duplicate(true)
	hud._potion_timer = 0
	hud._process(0.3)
	check(fake.requests.size() == 1 and fake.requests[0] == {"action":"game_use","payload":{"id":30114}} and player.stats == original,"online HUD sends source potion intent with no optimistic HP or inventory mutation")
	hud._potion_timer = 0
	hud._process(0.3)
	check(fake.requests.size() == 1,"pending online request is throttled until a later authority snapshot")
	fake.free()
	network.name = "NetworkManager"
	settings.reset_defaults()
	hud.free()
	player.free()
	await process_frame
	await process_frame
	print("AUTO_MEDICINE_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
