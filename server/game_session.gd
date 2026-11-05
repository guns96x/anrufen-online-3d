class_name ServerGameSession
extends Node

# All commands operate on the server-owned profile. Clients send intent only.
static var CITIZENS: Dictionary = _citizen_positions()

static func _citizen_positions() -> Dictionary:
	var result: Dictionary = {}
	for entry: Array in GuanlinLayout.CITIZENS:
		if not result.has(entry[0]): result[entry[0]] = entry[2]
	return result
var account: int
var social: SocialState
var world: WorldSimulation
var actor: ProfileActor
var progression: ProgressionController
var items: InventorySystem
var pets: CompanionSystem
var services: GameServices
var pet_position: Vector3 = Vector3.ZERO
var pet_target: String = ""
var _pet_cooldown: float = 0.0

static func upgrade_profile(profile: Dictionary) -> void:
	var defaults: Dictionary = {"name":"Мандрівник","class_name":"Воїн-початківець","level":1,"exp":0,"exp_to_next":100,"hp":100,"max_hp":100,"mp":50,"max_mp":50,"attack":22,"defense":8,"crit_rate":0.15,"accuracy":0.95,"evasion":0.05,"element":1,"copper":100,"inventory":{"30016":3,"30645":2},"starter_supplies_granted":true,"pk_mode":"peaceful"}
	for key: String in defaults:
		if not profile.has(key):
			profile[key] = defaults[key]
	ProfileCodec.normalize(profile)
	CharacterSystem.ensure_stats(profile)
	TitleSystem.ensure_stats(profile)
	var initializer: ProgressionController = ProgressionController.new()
	initializer._initialize_profile_fields(profile)
	initializer.free()

func bind_account(id: int, state: SocialState, simulation: WorldSimulation) -> void:
	account = id
	social = state
	world = simulation
	var row: Dictionary = social.players[id]
	upgrade_profile(row["profile"])
	if actor == null:
		actor = ProfileActor.new()
		add_child(actor)
		progression = ProgressionController.new()
		progression.auto_save_enabled = false
		add_child(progression)
	actor.bind_profile(row["profile"])
	progression.player_ref = null
	progression.bind_player(actor)
	if row.has("journal"):
		progression.apply_journal(row["journal"])
	items = actor.inventory
	pets = CompanionSystem.new()
	pets.bind_player(actor)
	services = GameServices.new()
	services.bind_player(actor,items)
	sync()

func sync() -> void:
	if world.actors.has(account):
		actor.position = world.actors[account]["position"]
		actor.is_dead = world.actors[account]["dead"]
	items.locked_items.clear()
	for id: Variant in actor.stats.get("locked_items",[]):
		items.locked_items.append(int(id))
	for id: int in progression.quest_item_locks():
		if id not in items.locked_items: items.locked_items.append(id)
	if actor.stats.get("mounted",false):
		var id: int = int(actor.stats.get("mount_id",0))
		if id not in items.locked_items:
			items.locked_items.append(id)
	actor.stats["quest_item_locks"] = progression.quest_item_locks()
	CharacterSystem.rebuild_stats(actor.stats,items.bonus_totals())
	progression.refresh_available_quests()
	social.players[account]["journal"] = progression.journal_snapshot()

func near(ids: Array, distance: float = 5.5) -> bool:
	if not world.actors.has(account):
		return false
	for id: Variant in ids:
		if CITIZENS.has(id) and world.actors[account]["position"].distance_to(CITIZENS[id]) <= distance:
			return true
	return false

func _int(payload: Dictionary, key: String, low: int = 0, high: int = 999999) -> int:
	return int(payload[key]) if SocialState._integer(payload.get(key),low,high) else -1

func act(action: String, payload: Dictionary) -> Dictionary:
	sync()
	if not world.actors.has(account) or actor.is_dead or payload.size() > 6:
		return {"ok":false,"error":"Дія зараз недоступна."}
	var id: int = _int(payload,"id")
	var target: int = _int(payload,"target",1,2147483647)
	var uid: String = str(payload.get("uid","")) if payload.get("uid","") is String else ""
	var stats: Dictionary = actor.stats
	var ok: bool = false
	match action:
		"attack", "skill":
			var requested: Dictionary = payload.get("target",{}) if payload.get("target",{}) is Dictionary else {"invalid":true}
			var slot: String = str(payload.get("slot","1")) if payload.get("slot","1") is String else "invalid"
			var result: Dictionary = world.attack(account,requested) if action == "attack" else world.cast_skill(account,requested,slot)
			if result.get("ok",false) and requested.get("kind") == "monster":
				var skill: int = int(stats.get("hotbar",{}).get(slot,0))
				if action == "attack" or (skill not in SkillRules.SELF_SKILLS and skill not in SkillRules.PARTY_SKILLS and CharacterSystem.SKILLS.get(skill,{}).get("effect") != "heal"):
					pet_target = str(requested.get("id",""))
			return result
		"dash": return world.dash(account)
		"pk_mode": ok = world.set_pk_mode(account,str(payload.get("mode","")))
		"duel_request": return world.duel_request(account,target)
		"duel_accept": return world.duel_accept(account,target)
		"duel_decline": ok = world.duel_decline(account,target)
		"duel_cancel": ok = world.duel_cancel(account)
		"equip": ok = items.equip_item(id)
		"unequip": ok = items.unequip_item(str(payload.get("slot","")))
		"use": ok = items.use_item(id)
		"forage": ok = world.forage.harvest(id,actor.position,items,Time.get_ticks_msec()/1000.0)
		"buy": ok = near([50179,50167,50168,50180]) and items.buy_item(id)
		"sell": ok = near([50179,50167,50168,50180]) and items.sell_item(id)
		"discard": ok = items.discard_item(id)
		"lock": ok = services.lock_item(id)
		"deposit": ok = near([50179]) and services.deposit(id)
		"withdraw": ok = near([50179]) and services.withdraw(id)
		"craft": ok = near([50182,50179]) and services.craft(_int(payload,"recipe",0,100))
		"expand_bag": ok = services.expand_bag()
		"mount": ok = MountSystem.mount(stats,id)
		"dismount": MountSystem.dismount(stats); ok = true
		"title": ok = TitleSystem.select(stats,id)
		"rename":
			if SocialState._name(payload.get("name")):
				stats["name"] = str(payload["name"]).strip_edges()
				social.players[account]["name"] = stats["name"]
				ok = true
		"allocate": ok = CharacterSystem.allocate(stats,str(payload.get("attribute","")))
		"choose_class": ok = CharacterSystem.choose_class(stats,_int(payload,"class_id"),_int(payload,"race_id"))
		"learn_skill": ok = CharacterSystem.learn_skill(stats,id)
		"assign_skill": ok = CharacterSystem.assign_skill(stats,str(payload.get("slot","")),id)
		"respec": ok = CharacterSystem.respec_skills(stats)
		"quest":
			var citizen: int = _int(payload,"citizen")
			var qid: int = _int(payload,"qid")
			if near([citizen]) and QuestData.DEFINITIONS.has(qid):
				progression._last_citizen_id = citizen
				if int(QuestData.DEFINITIONS[qid]["turnin_id"]) == citizen and progression.quest_states[qid] == QuestData.QuestState.ACTIVE and progression._can_deliver(qid):
					progression.quest_states[qid] = QuestData.QuestState.READY
					progression.quest_kills[qid] = 1
				match str(payload.get("action","")):
					"accept": ok = int(QuestData.DEFINITIONS[qid]["giver_id"]) == citizen and progression.accept_quest(qid)
					"complete": ok = progression.complete_quest(qid,citizen).get("success",false)
					"buy": ok = progression.buy_sword()
		"pet_start_incubation": ok = near([50180]) and pets.start_incubation(_int(payload,"egg_id"))
		"pet_hatch": ok = pets.hatch(_int(payload,"index",0,2))
		"pet_summon": ok = pets.summon(uid)
		"pet_dismiss": pets.dismiss(); ok = true
		"pet_feed": ok = pets.feed(uid)
		"pet_heal": ok = pets.heal(uid)
		"pet_medicate": ok = pets.medicate(uid,id)
		"pet_talent": ok = pets.feed_talent(uid,id)
		"pet_tactic": ok = pets.set_tactic(uid,str(payload.get("tactic","")))
		"pet_transform":
			if not near([50180]): return {"ok":false,"error":"Для перетворення звернися до дресирувальника."}
			var result: Dictionary = pets.transform(uid,str(payload.get("donor","")),_int(payload,"boost"),_int(payload,"protection"))
			if result.get("ok",false): sync()
			return result
		"pet_rename": ok = pets.rename_pet(uid,str(payload.get("name","")))
		"pet_rejuvenate": ok = pets.rejuvenate(uid,_int(payload,"item_id"))
		"pet_revive": ok = pets.revive(uid,_int(payload,"item_id"))
		"pet_transfer_runes": ok = near([50180]) and pets.transfer_with_runes(str(payload.get("from_uid","")),str(payload.get("to_uid","")),_int(payload,"learning"),_int(payload,"inheritance"))
		"pet_release": ok = pets.release_pet(uid)
		"pet_breed": ok = near([50180]) and pets.breed(str(payload.get("first","")),str(payload.get("second","")))
		"pet_transfer_skill": ok = near([50180]) and pets.transfer_skill(str(payload.get("from_uid","")),str(payload.get("to_uid","")),_int(payload,"index",0,3))
	if ok:
		sync()
	return {"ok":ok,"error":"" if ok else "Дію відхилено: перевір відстань, ресурси та умови."}

func tick_pet(delta: float) -> void:
	_pet_cooldown = maxf(0.0,_pet_cooldown-delta)
	var pet: Dictionary = pets.get_pet(str(actor.stats.get("summoned_pet","")))
	if pet.is_empty() or int(pet.get("hp",0)) <= 0 or int(pet.get("hunger",0)) <= 0 or not world.actors.has(account) or world.actors[account]["dead"]:
		pet_target = ""
		return
	var owner_position: Vector3 = world.actors[account]["position"]
	if pet_position.distance_to(owner_position) > 18.0:
		pet_position = owner_position+Vector3(1.5,0,1.5)
	var target: Dictionary = world.monsters.get(pet_target,{})
	var valid_target: bool = not target.is_empty() and target["state"] != "dead" and owner_position.distance_to(target["position"]) <= 12.0
	var goal: Vector3 = target["position"] if valid_target else owner_position
	var reach: float = 2.5 if valid_target else 2.0
	if pet_position.distance_to(goal) > reach-0.2:
		pet_position = world._move(pet_position,(goal-pet_position).normalized()*minf(6.0*delta,pet_position.distance_to(goal)))
	if valid_target and pet_position.distance_to(goal) <= reach and _pet_cooldown <= 0.0 and MountSystem.can_attack(actor.stats):
		_pet_cooldown = 1.6
		var attack: Dictionary = pets.combat_strike(str(pet["uid"]))
		var damage: Dictionary = CombatFormulas.calculate_damage(attack,target["stats"],1.0,attack["element"])
		if 90035 in pet["skills"] and attack["element"] == CombatFormulas.DamageType.WATER and not damage.get("is_miss",false):
			target["slow_timer"] = maxf(float(target["slow_timer"]),3.0)
		world._apply_damage(account,{"kind":"monster","id":pet_target,"stats":target["stats"]},damage)

func pet_snapshot() -> Dictionary:
	var pet: Dictionary = pets.get_pet(str(actor.stats.get("summoned_pet","")))
	if pet.is_empty():
		return {}
	return {"position":pet_position,"uid":pet["uid"],"name":pet["name"],"species_id":pet["species_id"],"hp":pet["hp"],"max_hp":pet["max_hp"],"mp":pet.get("mp",40),"max_mp":pet.get("max_mp",40),"level":pet["level"],"hunger":pet["hunger"]}
