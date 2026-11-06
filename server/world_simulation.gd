class_name WorldSimulation
extends RefCounted

signal monster_defeated(account_id: int, monster_key: String)
signal combat_event(event: Dictionary)

# Pure authoritative first-zone state. Geometry/source IDs and current local
# encounter setup are reproduced; all combat numbers remain provisional tuning.
var social: SocialState
var actors: Dictionary = {}
var monsters: Dictionary = {}
var movement_allowed: Callable
var duels: Dictionary = {}
var duel_requests: Dictionary = {}
var forage: ForestForage = ForestForage.new()

const INPUT_TIMEOUT: float = 0.35
const MAX_STEP: float = 0.25
const MIN_X: float = GuanlinLayout.BOUNDS_MIN.x + 1.0
const MAX_X: float = GuanlinLayout.BOUNDS_MAX.x - 1.0
const MIN_Z: float = GuanlinLayout.BOUNDS_MIN.y + 1.0
const MAX_Z: float = GuanlinLayout.BOUNDS_MAX.y - 1.0
const MELEE_RANGE: float = 3.5

func _init() -> void:
	for entry: Array in GuanlinSpawns.ENCOUNTERS:
		var numbers: Dictionary = Balance.monster(int(entry[4]), str(entry[3]))
		monsters[entry[0]] = {"monster_id":entry[1],"type":entry[1],"position":entry[2],"spawn":entry[2],"hp":numbers["max_hp"],"max_hp":numbers["max_hp"],"attack_damage":numbers["attack"],"speed":GuanlinSpawns.SPEEDS[entry[3]],"level":entry[4],"exp":numbers["exp"],"name":GuanlinSpawns.display_name(entry),"stats":{"defense":numbers["defense"],"evasion":numbers["evasion"],"element":1,"level":entry[4]},"state":"idle","target":0,"warning_target":0,"warning_timer":0.0,"warning_position":Vector3.ZERO,"respawn_timer":0.0,"attack_cooldown":0.0,"slow_timer":0.0}

func bind_social(value: SocialState) -> void:
	social = value

func _profile(id: int) -> Dictionary:
	if social == null or not social.players.has(id):
		return {}
	return social.players[id].get("profile",{})

func _finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _bounded(value: Vector3) -> Vector3:
	return Vector3(clampf(value.x,MIN_X,MAX_X),0.0,clampf(value.z,MIN_Z,MAX_Z))

func _online(id: int) -> bool:
	return social != null and social.players.has(id) and social.players[id].get("online",false)

func _alive(id: int) -> bool:
	return actors.has(id) and _online(id) and not actors[id]["dead"] and int(_profile(id).get("hp",0)) > 0

func add_actor(id: int, spawn: Vector3 = Vector3(4.5,0,6)) -> bool:
	if id < 1 or actors.has(id) or not _online(id) or not _finite_vector(spawn):
		return false
	var profile: Dictionary = _profile(id)
	for field: String in ["hp","max_hp","mp","max_mp","level"]:
		if not _integer(profile.get(field),0,1000000000):
			return false
	if int(profile["max_hp"]) <= 0 or int(profile["hp"]) > int(profile["max_hp"]) or int(profile["mp"]) > int(profile["max_mp"]) or int(profile["level"]) < 1:
		return false
	MountSystem.ensure_stats(profile)
	var location: Vector3 = _bounded(spawn)
	var dead: bool = int(profile["hp"]) <= 0
	if dead:
		MountSystem.dismount(profile)
	var mode: String = str(profile.get("pk_mode","peaceful"))
	if mode not in ["peaceful","party","guild","free"]:
		mode = "peaceful"
	actors[id] = {"position":location,"spawn":location,"yaw":0.0,"input":Vector2.ZERO,"input_age":INPUT_TIMEOUT,"cooldowns":{"attack":0.0,"fire":0.0,"dash":0.0},"dash_timer":0.0,"dash_direction":Vector3.ZERO,"respawn_timer":3.0 if dead else 0.0,"dead":dead,"time_since_combat":99.0,"hp_regen":0.0,"mp_regen":0.0,"slow_timer":0.0,"pk_mode":mode}
	return true

func remove_actor(id: int) -> void:
	_cancel_duel(id)
	_clear_requests(id)
	actors.erase(id)
	for monster: Dictionary in monsters.values():
		if int(monster["target"]) == id:
			monster["target"] = 0
			if monster["state"] != "dead":
				monster["state"] = "return"
				monster["warning_timer"] = 0.0

func set_input(id: int, direction: Vector2, yaw: float) -> bool:
	if not _alive(id) or not is_finite(direction.x) or not is_finite(direction.y) or direction.length_squared() > 1.000001 or not is_finite(yaw):
		return false
	actors[id]["input"] = direction
	actors[id]["input_age"] = 0.0
	actors[id]["yaw"] = wrapf(yaw,-PI,PI)
	return true

func _ok(extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok":true,"error":""}
	result.merge(extra,true)
	return result

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and float(value) >= low and float(value) <= high

func _target_shape(target: Dictionary) -> bool:
	if target.size() != 2 or not target.has("id") or target.get("kind") not in ["monster","player"]:
		return false
	if target["kind"] == "monster":
		return target["id"] is String and target["id"].length() > 0 and target["id"].length() <= 64
	return _integer(target["id"],1,2147483647)

func _nearest_monster(position: Vector3, radius: float) -> String:
	var best: String = ""
	var distance: float = radius
	for key: String in monsters:
		var monster: Dictionary = monsters[key]
		if monster["state"] == "dead":
			continue
		var candidate: float = position.distance_to(monster["position"])
		if candidate <= distance:
			distance = candidate
			best = key
	return best

func _resolve_target(id: int, requested: Dictionary, reach: float) -> Dictionary:
	var target: Dictionary = requested
	if target.is_empty():
		var nearest: String = _nearest_monster(actors[id]["position"],reach)
		if not nearest.is_empty():
			target = {"kind":"monster","id":nearest}
	if not _target_shape(target):
		return {}
	if target["kind"] == "monster":
		var key: String = target["id"]
		if not monsters.has(key) or monsters[key]["state"] == "dead" or actors[id]["position"].distance_to(monsters[key]["position"]) > reach:
			return {}
		return {"kind":"monster","id":key,"stats":monsters[key]["stats"]}
	var other: int = int(target["id"])
	if not can_hurt(id,other) or actors[id]["position"].distance_to(actors[other]["position"]) > reach:
		return {}
	return {"kind":"player","id":other,"stats":_profile(other)}

func attack(id: int, target: Dictionary = {}) -> Dictionary:
	if not _alive(id) or not MountSystem.can_attack(_profile(id)):
		return _fail("Зараз атакувати не можна.")
	if float(actors[id]["cooldowns"]["attack"]) > 0.0:
		return _fail("Удар ще відновлюється.")
	var resolved: Dictionary = _resolve_target(id,target,MELEE_RANGE)
	if resolved.is_empty():
		return _fail("Недоступна ціль або надто велика відстань.")
	actors[id]["cooldowns"]["attack"] = 0.45
	actors[id]["time_since_combat"] = 0.0
	var result: Dictionary = CombatFormulas.calculate_damage(_profile(id),resolved["stats"],1.2,CombatFormulas.DamageType.PHY)
	_apply_damage(id,resolved,result)
	return _ok({"result":result,"target":{"kind":resolved["kind"],"id":resolved["id"]}})

func cast_skill(id: int, target: Dictionary = {}, slot: String = "1") -> Dictionary:
	if slot not in ["1","2","3","4"]: return _fail("Невідома кнопка навички.")
	if not _alive(id):
		return _fail("Навичка недоступна або відновлюється.")
	var profile: Dictionary = _profile(id)
	var skill_id: int = int(profile.get("hotbar",{}).get(slot,0))
	if SkillRules.catalog().has(skill_id):
		return _cast_original(id,skill_id,target)
	if float(actors[id]["cooldowns"]["fire"]) > 0.0:
		return _fail("Навичка відновлюється.")
	if not CharacterSystem.SKILLS.has(skill_id) or not _integer(profile.get("skills",{}).get(str(skill_id)),1,5):
		return _fail("Ця навичка не вивчена.")
	var skill: Dictionary = CharacterSystem.SKILLS[skill_id]
	if int(profile["level"]) < int(skill["level"]):
		return _fail("Рівень персонажа замалий для цієї навички.")
	var effect: String = skill["effect"]
	if effect not in ["heavy","fire","ice","heal"] or (not MountSystem.can_attack(profile) and effect != "heal"):
		return _fail("Навичку не можна застосувати верхи.")
	if int(profile["mp"]) < int(skill["mp"]):
		return _fail("Недостатньо мани.")
	var rank: int = int(profile["skills"][str(skill_id)])
	var resolved: Dictionary = {}
	if effect == "heal":
		if not target.is_empty() and (not _target_shape(target) or target["kind"] != "player" or int(target["id"]) != id):
			return _fail("Ця навичка лікує лише самого персонажа.")
		if int(profile["hp"]) >= int(profile["max_hp"]):
			return _fail("Зцілення не потрібне.")
	else:
		resolved = _resolve_target(id,target,12.0 if effect == "fire" else 6.0 if effect == "ice" else MELEE_RANGE)
		if resolved.is_empty():
			return _fail("Недоступна ціль або надто велика відстань.")
	profile["mp"] -= int(skill["mp"])
	actors[id]["cooldowns"]["fire"] = float(skill["cooldown"])
	actors[id]["time_since_combat"] = 0.0
	if effect == "heal":
		var restored: int = mini(int(profile["max_hp"]) - int(profile["hp"]),20 + rank*12)
		profile["hp"] += restored
		combat_event.emit({"type":"heal","attacker":id,"target":id,"amount":restored,"skill_id":skill_id})
		return _ok({"restored":restored,"skill_id":skill_id})
	var multiplier: float = (2.0 if effect == "fire" else 1.5 if effect == "ice" else 1.4) + rank*0.2
	var damage_type: CombatFormulas.DamageType = CombatFormulas.DamageType.FIRE if effect == "fire" else CombatFormulas.DamageType.WATER if effect == "ice" else CombatFormulas.DamageType.PHY
	var result: Dictionary = CombatFormulas.calculate_damage(profile,resolved["stats"],multiplier,damage_type)
	_apply_damage(id,resolved,result,skill_id)
	if effect == "ice" and not result.get("is_miss",false):
		if resolved["kind"] == "monster" and monsters[resolved["id"]]["state"] != "dead":
			monsters[resolved["id"]]["slow_timer"] = 3.0
		elif resolved["kind"] == "player" and _alive(int(resolved["id"])):
			actors[int(resolved["id"])]["slow_timer"] = 3.0
	return _ok({"result":result,"skill_id":skill_id,"target":{"kind":resolved["kind"],"id":resolved["id"]}})

func dash(id: int) -> Dictionary:
	if not _alive(id) or float(actors[id]["cooldowns"]["dash"]) > 0.0 or StatusEffects.speed_multiplier(_profile(id)) <= 0.0:
		return _fail("Ривок зараз недоступний.")
	var actor: Dictionary = actors[id]
	actor["cooldowns"]["dash"] = 2.5
	actor["dash_timer"] = 0.18
	actor["dash_direction"] = Vector3(-sin(float(actor["yaw"])),0,-cos(float(actor["yaw"])))
	combat_event.emit({"type":"dash","attacker":id,"target":id})
	return _ok()

func _apply_damage(attacker: int, target: Dictionary, result: Dictionary, skill_id: int = 0) -> void:
	var amount: int = 0 if result.get("is_miss",false) else int(result.get("damage",0))
	if target["kind"] == "monster":
		var monster: Dictionary = monsters[target["id"]]
		if monster["state"] == "dead":
			return
		_add_monster_threat(monster,attacker,float(amount))
		if monster["state"] != "windup":
			monster["state"] = "chase"
		amount = mini(int(monster["hp"]),amount)
		monster["hp"] = maxi(0,int(monster["hp"]) - amount)
		if int(monster["hp"]) == 0:
			monster["state"] = "dead"
			monster["respawn_timer"] = 8.0
			monster["warning_timer"] = 0.0
			monster["warning_target"] = 0
			monster["target"] = 0
			monster["threat"] = {}
			TitleSystem.record_kill(_profile(attacker), monster.get("monster_id", monster.get("type", 0)))
			monster_defeated.emit(attacker,str(target["id"]))
	else:
		amount = _damage_actor(attacker,int(target["id"]),amount)
	combat_event.emit({"type":"damage","attacker":attacker,"attacker_kind":"player","target":{"kind":target["kind"],"id":target["id"]},"amount":amount,"is_critical":result.get("is_critical",false),"is_miss":result.get("is_miss",false),"skill_id":skill_id})

func _damage_actor(attacker: int, target: int, amount: int, monster_key: String = "") -> int:
	if not _alive(target) or amount <= 0 or float(actors[target]["dash_timer"]) > 0.0:
		return 0
	var profile: Dictionary = _profile(target)
	var actual: int = maxi(1,roundi(float(amount) * (MountSystem.damage_multiplier(profile) if not monster_key.is_empty() else 1.0)))
	actual = StatusEffects.absorb(profile,actual)
	actors[target]["time_since_combat"] = 0.0
	if int(profile["hp"]) - actual <= 0 and duels.get(attacker,0) == target:
		var dealt: int = int(profile["hp"]) - 1
		profile["hp"] = 1
		_cancel_duel(attacker)
		combat_event.emit({"type":"duel_finished","winner":attacker,"loser":target,"attacker":attacker,"target":target,"duel":true})
		return dealt
	actual = mini(int(profile["hp"]),actual)
	profile["hp"] = maxi(0,int(profile["hp"]) - actual)
	if int(profile["hp"]) == 0:
		var actor: Dictionary = actors[target]
		actor["dead"] = true
		actor["respawn_timer"] = 3.0
		actor["dash_timer"] = 0.0
		actor["input"] = Vector2.ZERO
		actor["input_age"] = INPUT_TIMEOUT
		MountSystem.dismount(profile)
		profile["skill_effects"] = []
		_cancel_duel(target)
		_clear_requests(target)
		combat_event.emit({"type":"death","attacker":attacker,"target":target,"duel":false,"monster_key":monster_key})
	return actual

func set_pk_mode(id: int, mode: String) -> bool:
	if not actors.has(id) or mode not in ["peaceful","party","guild","free"]:
		return false
	actors[id]["pk_mode"] = mode
	_profile(id)["pk_mode"] = mode
	return true

func can_hurt(attacker: int, target: int) -> bool:
	if attacker == target or not _alive(attacker) or not _alive(target) or not MountSystem.can_attack(_profile(attacker)):
		return false
	if duels.get(attacker,0) == target and duels.get(target,0) == attacker:
		return true
	if actors[attacker]["pk_mode"] == "peaceful":
		return false
	var mode: String = actors[attacker]["pk_mode"]
	for group: String in ["party","guild"]:
		if mode != group:
			continue
		var own: int = int(social.players[attacker].get(group,0))
		if own != 0 and own == int(social.players[target].get(group,0)):
			return false
	return true

func duel_request(id: int, target: int) -> Dictionary:
	if id == target or not _alive(id) or not _alive(target) or duels.has(id) or duels.has(target) or duel_requests.has(target):
		return _fail("Дуель зараз недоступна.")
	if actors[id]["position"].distance_to(actors[target]["position"]) > 20.0:
		return _fail("Гравець надто далеко.")
	duel_requests[target] = {"from":id,"remaining":30.0}
	combat_event.emit({"type":"duel_request","attacker":id,"target":target})
	return _ok()

func duel_accept(id: int, from_id: int) -> Dictionary:
	if not duel_requests.has(id) or int(duel_requests[id]["from"]) != from_id or not _alive(id) or not _alive(from_id) or duels.has(id) or duels.has(from_id):
		return _fail("Немає такого запрошення на дуель.")
	if actors[id]["position"].distance_to(actors[from_id]["position"]) > 20.0:
		return _fail("Гравець надто далеко.")
	_clear_requests(id)
	_clear_requests(from_id)
	duels[id] = from_id
	duels[from_id] = id
	combat_event.emit({"type":"duel_started","attacker":from_id,"target":id})
	return _ok()

func duel_decline(id: int, from_id: int = 0) -> bool:
	if not duel_requests.has(id) or (from_id != 0 and int(duel_requests[id]["from"]) != from_id):
		return false
	duel_requests.erase(id)
	return true

func duel_cancel(id: int) -> bool:
	if not duels.has(id):
		return false
	_cancel_duel(id)
	return true

func _cancel_duel(id: int) -> void:
	var other: int = int(duels.get(id,0))
	duels.erase(id)
	if other != 0:
		duels.erase(other)
		for account: int in [id,other]:
			var profile: Dictionary = _profile(account)
			var effects: Array = profile.get("skill_effects",[])
			var changed: bool = false
			for index: int in range(effects.size()-1,-1,-1):
				if not effects[index]["positive"] and int(effects[index]["owner"]) in [id,other]:
					effects.remove_at(index)
					changed = true
			if changed: CharacterSystem.rebuild_stats(profile,CharacterSystem.equipment_bonuses(profile))

func _clear_requests(id: int) -> void:
	for target: int in duel_requests.keys():
		if target == id or int(duel_requests[target]["from"]) == id:
			duel_requests.erase(target)

func _allowed(from: Vector3, to: Vector3) -> bool:
	if not movement_allowed.is_valid():
		# Dedicated server: the town plan is the collision map; never trap someone already inside.
		return not GuanlinLayout.blocks(Vector2(to.x, to.z)) or GuanlinLayout.blocks(Vector2(from.x, from.z))
	var result: Variant = movement_allowed.call(from,to)
	return typeof(result) == TYPE_BOOL and result

func _move(from: Vector3, offset: Vector3) -> Vector3:
	var to: Vector3 = _bounded(from + offset)
	if _allowed(from,to):
		return to
	var x_only: Vector3 = Vector3(to.x,0,from.z)
	if x_only != from and _allowed(from,x_only):
		return x_only
	var z_only: Vector3 = Vector3(from.x,0,to.z)
	return z_only if z_only != from and _allowed(from,z_only) else from

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var step: float = minf(delta,MAX_STEP)
	for id: int in actors.keys():
		if not _online(id):
			continue
		_tick_actor(id,step)
	for key: String in monsters:
		_tick_monster(key,step)
	for id: int in duel_requests.keys():
		duel_requests[id]["remaining"] -= step
		if float(duel_requests[id]["remaining"]) <= 0.0:
			duel_requests.erase(id)
	for id: int in duels.keys():
		var other: int = int(duels.get(id,0))
		if not _alive(id) or not _alive(other) or actors[id]["position"].distance_to(actors[other]["position"]) > 30.0:
			_cancel_duel(id)

func _tick_actor(id: int, delta: float) -> void:
	var actor: Dictionary = actors[id]
	var profile: Dictionary = _profile(id)
	for key: String in actor["cooldowns"]:
		actor["cooldowns"][key] = maxf(0.0,float(actor["cooldowns"][key]) - delta)
	var had_effects: bool = not profile.get("skill_effects",[]).is_empty()
	var periodic: Array[Dictionary] = StatusEffects.tick(profile,delta)
	if had_effects:
		CharacterSystem.rebuild_stats(profile,CharacterSystem.equipment_bonuses(profile))
	for event: Dictionary in periodic:
		var owner: int = int(event["owner"])
		if can_hurt(owner,id):
			var dealt: int = _damage_actor(owner,id,int(event["damage"]))
			combat_event.emit({"type":"damage","attacker":owner,"attacker_kind":"player","target":{"kind":"player","id":id},"amount":dealt,"skill_id":event["skill_id"],"periodic":true})
	var selected_skill: int = int(profile.get("hotbar",{}).get("1",0))
	if SkillRules.catalog().has(selected_skill):
		actor["cooldowns"]["fire"] = float(profile["skill_cooldowns"].get(str(selected_skill),0))
	if actor["dead"]:
		actor["respawn_timer"] -= delta
		if float(actor["respawn_timer"]) <= 0.0:
			actor["dead"] = false
			actor["respawn_timer"] = 0.0
			actor["position"] = actor["spawn"]
			actor["hp_regen"] = 0.0
			actor["mp_regen"] = 0.0
			actor["time_since_combat"] = 99.0
			profile["hp"] = int(profile["max_hp"])
			profile["mp"] = int(profile["max_mp"])
			combat_event.emit({"type":"respawn","attacker":0,"target":id})
		return
	var input_time: float = minf(delta,maxf(0.0,INPUT_TIMEOUT - float(actor["input_age"])))
	actor["input_age"] = minf(INPUT_TIMEOUT,float(actor["input_age"]) + delta)
	var dash_time: float = minf(delta,float(actor["dash_timer"]))
	var movement: Vector3 = actor["dash_direction"] * 20.0 * dash_time
	actor["dash_timer"] = maxf(0.0,float(actor["dash_timer"]) - delta)
	var direction: Vector2 = actor["input"]
	var speed: float = 6.0 * MountSystem.speed_multiplier(profile) * StatusEffects.speed_multiplier(profile) * (0.45 if float(actor["slow_timer"]) > 0.0 else 1.0)
	if StatusEffects.speed_multiplier(profile) <= 0.0:
		movement = Vector3.ZERO
		actor["dash_timer"] = 0.0
	movement += Vector3(direction.x,0,direction.y) * speed * maxf(0.0,input_time - dash_time)
	actor["position"] = _move(actor["position"],movement)
	actor["slow_timer"] = maxf(0.0,float(actor["slow_timer"]) - delta)
	actor["time_since_combat"] += delta
	var multiplier: float = 4.0 if float(actor["time_since_combat"]) > 4.0 else 1.0
	for entry: Array in [["hp",1.5,"hp_regen","hp_regen_bonus"],["mp",2.5,"mp_regen","mp_regen_bonus"]]:
		var field: String = entry[0]
		var accumulator: String = entry[2]
		if int(profile[field]) < int(profile["max_" + field]):
			actor[accumulator] += (float(entry[1])*multiplier+float(profile.get(entry[3],0))) * delta
			var amount: int = floori(float(actor[accumulator]))
			if amount > 0:
				actor[accumulator] -= amount
				profile[field] = mini(int(profile["max_"+field]),int(profile[field]) + amount)
		else:
			actor[accumulator] = 0.0

func _nearest_actor(position: Vector3) -> int:
	var closest: float = 7.0
	var best: int = 0
	for id: int in actors:
		if not _alive(id):
			continue
		var distance: float = position.distance_to(actors[id]["position"])
		if distance <= closest:
			closest = distance
			best = id
	return best

func _tick_monster(key: String, delta: float) -> void:
	var monster: Dictionary = monsters[key]
	StatusEffects.tick(monster["stats"],delta)
	_refresh_monster_stats(monster)
	if monster["state"] == "dead":
		monster["respawn_timer"] -= delta
		if float(monster["respawn_timer"]) <= 0.0:
			monster.merge({"position":monster["spawn"],"hp":monster["max_hp"],"state":"idle","target":0,"warning_target":0,"warning_timer":0.0,"respawn_timer":0.0,"attack_cooldown":0.0,"slow_timer":0.0,"threat":{}},true)
		return
	if StatusEffects.speed_multiplier(monster["stats"]) <= 0.0:
		return
	monster["attack_cooldown"] = maxf(0.0,float(monster["attack_cooldown"]) - delta)
	monster["slow_timer"] = maxf(0.0,float(monster["slow_timer"]) - delta)
	var target: int = int(monster["target"])
	if not _alive(target) and monster["state"] != "return":
		var replacement: int = _best_threat(monster)
		if replacement != 0:
			target = replacement
			monster["target"] = replacement
	if monster["state"] == "windup":
		monster["warning_timer"] = maxf(0.0,float(monster["warning_timer"]) - delta)
		if float(monster["warning_timer"]) <= 0.0:
			_resolve_monster_attack(key)
			monster["state"] = "chase" if _alive(target) else "return"
		return
	if monster["state"] == "return":
		if monster["position"].distance_to(monster["spawn"]) < 0.6:
			monster["position"] = monster["spawn"]
			monster["hp"] = monster["max_hp"]
			monster["state"] = "idle"
			monster["threat"] = {}
		else:
			var home_direction: Vector3 = (monster["spawn"] - monster["position"]).normalized()
			monster["position"] = _move(monster["position"],home_direction*float(monster["speed"])*1.3*delta)
		return
	if not _alive(target):
		target = _nearest_actor(monster["position"])
		monster["target"] = target
	if target == 0:
		monster["state"] = "idle"
		return
	var distance: float = monster["position"].distance_to(actors[target]["position"])
	var chase_distance: float = 18.0 if monster.get("threat",{}).has(target) else 10.5
	if distance > chase_distance or monster["position"].distance_to(monster["spawn"]) > 18.0:
		monster["state"] = "return"
		monster["target"] = 0
		return
	monster["state"] = "chase"
	if distance <= 1.8:
		if float(monster["attack_cooldown"]) <= 0.0:
			monster["state"] = "windup"
			monster["warning_timer"] = 0.65
			monster["warning_position"] = actors[target]["position"]
			monster["warning_target"] = target
			monster["attack_cooldown"] = 1.4
			combat_event.emit({"type":"warning","attacker":0,"monster_key":key,"target":target,"position":monster["warning_position"],"duration":0.65})
		return
	var direction: Vector3 = (actors[target]["position"] - monster["position"]).normalized()
	var speed: float = float(monster["speed"]) * StatusEffects.speed_multiplier(monster["stats"]) * (0.45 if float(monster["slow_timer"]) > 0.0 else 1.0)
	monster["position"] = _move(monster["position"],direction*speed*delta)

func _resolve_monster_attack(key: String) -> void:
	var monster: Dictionary = monsters[key]
	var target: int = int(monster["warning_target"])
	if not _alive(target) or monster["position"].distance_to(actors[target]["position"]) > 2.15 or actors[target]["position"].distance_to(monster["warning_position"]) >= 1.5:
		return
	var attack_stats: Dictionary = {"attack":monster["attack_damage"],"accuracy":1.0,"crit_rate":0.05,"element":1,"level":int(monster.get("level",1))}
	var result: Dictionary = CombatFormulas.calculate_damage(attack_stats,_profile(target))
	var amount: int = 0 if result.get("is_miss",false) else int(result.get("damage",0))
	amount = _damage_actor(0,target,amount,key)
	combat_event.emit({"type":"damage","attacker":0,"attacker_kind":"monster","monster_key":key,"target":{"kind":"player","id":target},"amount":amount,"is_miss":result.get("is_miss",false),"is_critical":false})

func _cast_original(id: int, skill_id: int, target: Dictionary) -> Dictionary:
	var profile: Dictionary = _profile(id)
	var definition: Dictionary = SkillRules.player_definitions()[skill_id]
	var rank: int = int(profile.get("skills",{}).get(str(skill_id),0))
	if rank < 1 or rank > int(definition["max_rank"]) or not SkillRules.allowed(int(profile.get("class_id",130001)),skill_id):
		return _fail("Навичка не вивчена або належить іншій професії.")
	if int(profile.get("level",1)) < int(definition["level"]):
		return _fail("Рівень персонажа замалий.")
	var self_target: Dictionary = {"kind":"player","id":id,"stats":profile}
	var allies: Array[Dictionary] = [self_target]
	var party: int = int(social.players[id].get("party",0))
	if party != 0:
		for other: int in actors:
			if other != id and _alive(other) and int(social.players[other].get("party",0)) == party and actors[id]["position"].distance_to(actors[other]["position"]) <= 12.0:
				allies.append({"kind":"player","id":other,"stats":_profile(other)})
	var targets: Array[Dictionary] = []
	if skill_id not in SkillRules.SELF_SKILLS and skill_id not in SkillRules.PARTY_SKILLS:
		if not MountSystem.can_attack(profile): return _fail("Верха атакувати не можна.")
		var resolved: Dictionary = _resolve_target(id,target,float(definition["range"]))
		if resolved.is_empty(): return _fail("Ціль недоступна або надто далеко.")
		if skill_id in SkillRules.AREA_SKILLS:
			var center: Vector3 = monsters[resolved["id"]]["position"] if resolved["kind"] == "monster" else actors[int(resolved["id"])]["position"]
			for key: String in monsters:
				if monsters[key]["state"] != "dead" and center.distance_to(monsters[key]["position"]) <= 5.0:
					targets.append({"kind":"monster","id":key,"stats":monsters[key]["stats"]})
			for other: int in actors:
				if can_hurt(id,other) and center.distance_to(actors[other]["position"]) <= 5.0:
					targets.append({"kind":"player","id":other,"stats":_profile(other)})
		else:
			targets.append(resolved)
	var plan: Dictionary = SkillActionPlan.build(profile,skill_id,rank,self_target,targets,allies)
	if not plan["ok"]: return plan
	StatusEffects.ensure_stats(profile)
	profile["mp"] -= int(plan["mp"])
	profile["skill_cooldowns"][str(skill_id)] = float(plan["cooldown"])
	if int(profile.get("hotbar",{}).get("1",0)) == skill_id:
		actors[id]["cooldowns"]["fire"] = float(plan["cooldown"])
	actors[id]["time_since_combat"] = 0.0
	var duel_opponent: int = int(duels.get(id,0))
	for action: Dictionary in plan["actions"]:
		if duel_opponent != 0 and action["target"]["kind"] == "player" and int(action["target"]["id"]) == duel_opponent and int(duels.get(id,0)) != duel_opponent:
			continue
		_apply_original_action(id,action,skill_id)
	combat_event.emit({"type":"skill","attacker":id,"skill_id":skill_id})
	return _ok({"skill_id":skill_id,"actions":plan["actions"].size()})

func _apply_original_action(id: int, action: Dictionary, skill_id: int) -> void:
	var target: Dictionary = action["target"]
	var stats: Dictionary
	if target["kind"] == "monster":
		if not monsters.has(str(target["id"])) or monsters[str(target["id"])]["state"] == "dead": return
		stats = monsters[str(target["id"])]["stats"]
	else:
		if not _alive(int(target["id"])): return
		# A duel can finish during an earlier segment of the same combo.
		if action["type"] in ["damage","drain"] and not can_hurt(id,int(target["id"])): return
		if int(target["id"]) != id and action["type"] == "buff" and not action["positive"] and not can_hurt(id,int(target["id"])): return
		if int(target["id"]) != id and action["type"] == "cleanse" and not can_hurt(id,int(target["id"])): return
		stats = _profile(int(target["id"]))
	match action["type"]:
		"damage":
			var resolved: Dictionary = target.duplicate()
			resolved["stats"] = stats
			_apply_damage(id,resolved,action["result"],skill_id)
		"heal":
			var amount: int = mini(int(stats["max_hp"])-int(stats["hp"]),int(action["amount"]))
			stats["hp"] += amount
			combat_event.emit({"type":"heal","attacker":id,"target":target["id"],"amount":amount,"skill_id":skill_id})
		"buff": StatusEffects.add(stats,skill_id,int(action["rank"]),float(action["duration"]),bool(action["positive"]),action["modifiers"],id,action.get("periodic",{}))
		"cleanse": StatusEffects.cleanse(stats,bool(action["positive"]),int(action["maximum"]),float(action["chance"]))
		"drain":
			var amount: int = mini(int(stats.get("mp",0)),int(action["amount"]))
			stats["mp"] = maxi(0,int(stats.get("mp",0))-amount)
			combat_event.emit({"type":"mana_drain","attacker":id,"target":target,"amount":amount,"skill_id":skill_id})
		"taunt":
			_add_monster_threat(monsters[str(target["id"])],id,float(action["hate"]))
			monsters[str(target["id"])]["state"] = "chase"
			monsters[str(target["id"])]["warning_timer"] = 0.0
	if action["type"] in ["buff","cleanse"]:
		if target["kind"] == "player": CharacterSystem.rebuild_stats(stats,CharacterSystem.equipment_bonuses(stats))
		else: _refresh_monster_stats(monsters[str(target["id"])])

func _refresh_monster_stats(monster: Dictionary) -> void:
	var stats: Dictionary = monster["stats"]
	if not stats.has("base_defense"): stats["base_defense"] = stats.get("defense",4)
	var modifiers: Dictionary = StatusEffects.modifiers(stats)
	stats["defense"] = maxf(0.0,(float(stats["base_defense"])+float(modifiers.get("defense_add",0)))*(1.0+float(modifiers.get("defense_rate",0))))
	stats["resist"] = maxf(0.0,float(modifiers.get("resist_add",0))*(1.0+float(modifiers.get("resist_rate",0))))

func _add_monster_threat(monster: Dictionary, account: int, amount: float) -> void:
	if not _alive(account): return
	if not monster.has("threat"): monster["threat"] = {}
	monster["threat"][account] = float(monster["threat"].get(account,0))+maxf(0.1,amount)
	monster["target"] = _best_threat(monster)

func _best_threat(monster: Dictionary) -> int:
	var best: int = 0
	var highest: float = -1.0
	for id: int in monster.get("threat",{}).keys():
		if not _alive(id) or actors[id]["position"].distance_to(monster["position"]) > 18.0:
			monster["threat"].erase(id)
		elif float(monster["threat"][id]) > highest:
			highest = float(monster["threat"][id])
			best = id
	return best

func public_snapshot() -> Dictionary:
	var actor_data: Dictionary = {}
	for id: int in actors:
		var profile: Dictionary = _profile(id)
		var actor: Dictionary = actors[id]
		actor_data[id] = {"id":id,"name":str(profile.get("name","")),"position":actor["position"],"yaw":actor["yaw"],"hp":profile.get("hp",0),"max_hp":profile.get("max_hp",0),"mp":profile.get("mp",0),"max_mp":profile.get("max_mp",0),"level":profile.get("level",1),"class_id":profile.get("class_id",130001),"mount_id":profile.get("mount_id",0),"mounted":profile.get("mounted",false),"dead":actor["dead"],"respawn_timer":actor["respawn_timer"],"dash_timer":actor["dash_timer"],"slow_timer":actor["slow_timer"],"cooldowns":actor["cooldowns"].duplicate(true),"pk_mode":actor["pk_mode"],"race_id":profile.get("race_id",250001),"sex":profile.get("sex","m"),"equipment":profile.get("equipment",{}).duplicate()}
	var monster_data: Dictionary = {}
	for key: String in monsters:
		var monster: Dictionary = monsters[key]
		monster_data[key] = {"id":key,"monster_id":monster["monster_id"],"type":monster["type"],"position":monster["position"],"hp":monster["hp"],"max_hp":monster["max_hp"],"state":monster["state"],"warning_timer":monster["warning_timer"],"warning_position":monster["warning_position"],"respawn_timer":monster["respawn_timer"],"slow_timer":monster["slow_timer"]}
	return {"actors":actor_data,"monsters":monster_data,"duels":duels.duplicate(true),"duel_requests":duel_requests.duplicate(true),"forage":forage.snapshot(Time.get_ticks_msec()/1000.0)}
