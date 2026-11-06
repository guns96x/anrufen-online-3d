class_name EquipmentRules
extends RefCounted

# Source-backed definitions; all conversion and service prices below are modern tuning.
const Skills = preload("res://shared/combat/skill_rules.gd")
const Catalog = preload("res://shared/items/item_catalog.gd")
const MAX_UPGRADE: int = 10
const MODERN_DURABILITY: int = 100
const INGOTS: Dictionary = {1:[30064,30482],2:[30065,30810],3:[30066]}
const PROTECTION: Array[int] = [30067,30697]
const BOOST: Array[int] = [30068,30483]
const SCALED: Dictionary = {20:"attack",21:"defense",22:"magic_attack",23:"magic_defense",30:"max_hp",31:"max_mp"}
const RATES: Dictionary = {41:"crit_rate",43:"accuracy",44:"evasion"}
static var _gear: Dictionary = {}
static var _properties: Dictionary = {}
static var _suits: Dictionary = {}
static var _affixes: Dictionary = {}

static func _load() -> void:
	Catalog.ensure_loaded()
	if not _gear.is_empty(): return
	for pair: Array in [["equipment",_gear],["property",_properties],["suit",_suits],["affix",_affixes]]:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/%s_rules.json" % pair[0]))
		if not parsed is Dictionary: continue
		for row: Dictionary in parsed.get("records",[]): pair[1][int(row["id"])] = row

static func definition(item_id: int) -> Dictionary:
	_load()
	return _gear.get(item_id,{}).duplicate(true)

static func can_equip(stats: Dictionary, item_id: int) -> bool:
	var item: Dictionary = definition(item_id)
	if item.is_empty() or not _integer(stats.get("level",0),1,100000): return false
	if not _integer(stats.get("class_id",0),0,1000000): return false
	var ancestry: Array = Skills.ANCESTORS.get(int(stats.get("class_id",0)),[])
	for req: Dictionary in item["requirements"]:
		if int(stats["level"]) < int(req["level_candidate"]): return false
		if int(req["class_id"]) != 0 and not int(req["class_id"]) in ancestry: return false
		# No invented semantics for currently zero source constraint fields.
		if int(req["raw_condition_1"]) != 0: return false
		for value: Variant in req["raw_stat_constraints"]:
			if int(value) != 0: return false
	return true

static func raw_properties(item_id: int, upgrade: int = 0) -> Dictionary:
	var item: Dictionary = definition(item_id)
	var raw: Dictionary = {}
	if item.is_empty() or upgrade < 0 or upgrade > MAX_UPGRADE: return raw
	for group: Array in item["property_id_groups"]:
		for property_id: Variant in group:
			if int(property_id) == 0: continue
			var property: Dictionary = _properties.get(int(property_id),{})
			if not property.is_empty(): _add(raw,str(int(property["attribute_id"])),property["values"][upgrade])
	return raw

static func bonuses(item_id: int, state: Dictionary = {}) -> Dictionary:
	if definition(item_id).is_empty(): return {}
	var normalized: Dictionary = _state(state)
	if normalized.is_empty(): return {}
	var raw: Dictionary = raw_properties(item_id,int(normalized["upgrade"]))
	for side: String in ["prefix_id","suffix_id"]:
		var affix: Dictionary = _affixes.get(int(normalized[side]),{})
		for effect: Dictionary in affix.get("effects",[]): _add(raw,str(int(effect["attribute_id"])),effect["value"])
	var converted: Dictionary = _convert(raw)
	converted["active"] = int(normalized["durability"]) > 0
	if not converted["active"]:
		for key: Variant in converted.keys():
			if converted[key] is int or converted[key] is float: converted[key] = 0.0
	return converted

static func suit_bonuses(equipment: Dictionary, states: Dictionary = {}) -> Dictionary:
	_load()
	var worn: Dictionary = {}
	for slot: Variant in equipment:
		if not _integer(equipment[slot],1,100000000): continue
		var item_id: int = int(equipment[slot])
		if not _gear.has(item_id): continue
		var state: Variant = states.get(str(item_id),states.get(item_id,states.get(slot,{})))
		if not state is Dictionary: continue
		var normalized: Dictionary = _state(state)
		if normalized.is_empty() or int(normalized["durability"]) == 0: continue
		worn[item_id] = true
	var raw: Dictionary = {}
	var counts: Dictionary = {}
	var applied: Array[Dictionary] = []
	for suit_id: int in _suits:
		var suit: Dictionary = _suits[suit_id]
		var members: Dictionary = {}
		for member: Dictionary in suit["members"]:
			if int(member["item_id"]) != 0: members[int(member["item_id"])] = true
		for member: Variant in suit["gear_footer_members"]:
			if int(member) != 0: members[int(member)] = true
		var pieces: int = 0
		for item_id: int in worn:
			if members.has(item_id): pieces += 1
		if pieces == 0: continue
		counts[str(suit_id)] = pieces
		for index: int in range(suit["bonuses"].size()):
			var effect: Dictionary = suit["bonuses"][index]
			if pieces >= int(effect["required_piece_count"]):
				_add(raw,str(int(effect["attribute_id"])),effect["value"])
				applied.append({"suit_id":suit_id,"effect_index":index,"pieces":int(effect["required_piece_count"])})
	var result: Dictionary = _convert(raw)
	result["suit_piece_counts"] = counts
	result["applied_suit_effects"] = applied
	return result

static func upgrade_plan(stats: Dictionary, item_id: int, state: Dictionary, material_id: int, protection_id: int = 0, boost_id: int = 0, roll: float = 0.5) -> Dictionary:
	var item: Dictionary = definition(item_id)
	var next: Dictionary = _state(state)
	if item.is_empty() or next.is_empty(): return _reject("invalid_item_or_state")
	if int(next["upgrade"]) >= MAX_UPGRADE: return _reject("maximum_upgrade")
	if not material_id in INGOTS.get(int(item["quality"]),[]): return _reject("material_quality_mismatch")
	if protection_id != 0 and not protection_id in PROTECTION: return _reject("invalid_protection")
	if boost_id != 0 and not boost_id in BOOST: return _reject("invalid_boost")
	if not is_finite(roll) or roll < 0.0 or roll >= 1.0: return _reject("invalid_roll")
	var consume: Dictionary = {str(material_id):1}
	if protection_id != 0: consume[str(protection_id)] = 1
	if boost_id != 0: consume[str(boost_id)] = 1
	var cost: int = 10 * (int(next["upgrade"]) + 1)
	var error: String = _resources(stats,cost,consume)
	if not error.is_empty(): return _reject(error)
	var chance: float = minf(0.99,maxf(0.10,0.90-0.07*int(next["upgrade"]))+(0.10 if boost_id != 0 else 0.0))
	var success: bool = roll < chance
	if success:
		next["upgrade"] += 1
	else:
		next["upgrade"] = maxi(0,int(next["upgrade"])-1)
		if protection_id == 0:
			next["max_durability"] = maxi(1,int(next["max_durability"])-5)
			next["durability"] = mini(int(next["durability"]),int(next["max_durability"]))
	var result: Dictionary = _accept(next,cost,consume)
	result.merge({"success":success,"success_chance":chance,"balance_is_provisional":true})
	return result

static func affix_plan(stats: Dictionary, item_id: int, state: Dictionary, material_id: int) -> Dictionary:
	var item: Dictionary = definition(item_id)
	var next: Dictionary = _state(state)
	var affix: Dictionary = _affixes.get(material_id,{})
	if item.is_empty() or next.is_empty(): return _reject("invalid_item_or_state")
	if affix.is_empty() or affix["is_test"]: return _reject("invalid_affix")
	var key: String = str(affix["side"])+"_id"
	if int(next[key]) != 0: return _reject("affix_already_set")
	if not _integer(stats.get("level",0),1,100000): return _reject("invalid_actor_level")
	for req: Dictionary in affix["requirements"]:
		if int(stats["level"]) < int(req["level_candidate"]): return _reject("affix_actor_level")
	var consume: Dictionary = {str(material_id):1}
	var error: String = _resources(stats,30,consume)
	if not error.is_empty(): return _reject(error)
	next[key] = material_id
	var result: Dictionary = _accept(next,30,consume)
	result["balance_is_provisional"] = true
	result["material_actor_level_gate_is_inferred"] = true
	return result

static func repair_plan(stats: Dictionary, item_id: int, state: Dictionary) -> Dictionary:
	var next: Dictionary = _state(state)
	if definition(item_id).is_empty() or next.is_empty(): return _reject("invalid_item_or_state")
	var missing: int = int(next["max_durability"])-int(next["durability"])
	if missing <= 0: return _reject("already_repaired")
	var cost: int = missing * 2
	var error: String = _resources(stats,cost,{})
	if not error.is_empty(): return _reject(error)
	next["durability"] = next["max_durability"]
	var result: Dictionary = _accept(next,cost,{})
	result["balance_is_provisional"] = true
	return result

static func _state(state: Dictionary) -> Dictionary:
	_load()
	var next: Dictionary = state.duplicate(true)
	for pair: Array in [["upgrade",0],["durability",MODERN_DURABILITY],["max_durability",MODERN_DURABILITY],["prefix_id",0],["suffix_id",0]]:
		if not next.has(pair[0]): next[pair[0]] = pair[1]
		if not _integer(next[pair[0]],0,100000000): return {}
		next[pair[0]] = int(next[pair[0]])
	if next["upgrade"] > MAX_UPGRADE or next["max_durability"] < 1 or next["max_durability"] > MODERN_DURABILITY or next["durability"] > next["max_durability"]: return {}
	for side: String in ["prefix","suffix"]:
		var id: int = next[side+"_id"]
		if id == 0: continue
		var affix: Dictionary = _affixes.get(id,{})
		if affix.is_empty() or affix["is_test"] or affix["side"] != side: return {}
	return next

static func _resources(stats: Dictionary, cost: int, consume: Dictionary) -> String:
	if not _integer(stats.get("copper",-1),0,1000000000): return "invalid_currency"
	if not _integer(stats.get("bag_capacity",32),1,10000): return "invalid_capacity"
	var bag: Variant = stats.get("inventory",{})
	if not bag is Dictionary or bag.size() > int(stats.get("bag_capacity",32)): return "invalid_inventory"
	for key: Variant in bag:
		if not key is String or not key.is_valid_int() or str(int(key)) != key: return "invalid_inventory"
		var item: Dictionary = Catalog.get_item(int(key))
		if item.is_empty() or not _integer(bag[key],1,int(item["max_stack"])): return "invalid_inventory"
	if int(stats["copper"]) < cost: return "insufficient_copper"
	for key: String in consume:
		if int(bag.get(key,0)) < int(consume[key]): return "missing_material"
	return ""

static func _convert(raw: Dictionary) -> Dictionary:
	var result: Dictionary = {"raw_bonus":raw.duplicate(true),"unsupported_raw":{},"conversion_is_provisional":true}
	for key: String in raw:
		var attr: int = int(key)
		if SCALED.has(attr): _add(result,SCALED[attr],float(raw[key])/10.0)
		elif RATES.has(attr): _add(result,RATES[attr],float(raw[key])/10000.0)
		else: result["unsupported_raw"][key] = raw[key]
	return result

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _add(target: Dictionary, key: String, value: Variant) -> void:
	target[key] = target.get(key,0) + value

static func _reject(error: String) -> Dictionary:
	return {"ok":false,"error":error,"state":{},"copper_cost":0,"consume":{}}

static func _accept(state: Dictionary, cost: int, consume: Dictionary) -> Dictionary:
	return {"ok":true,"error":"","state":state,"copper_cost":cost,"consume":consume}
