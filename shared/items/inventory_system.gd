class_name InventorySystem
extends RefCounted

signal changed()
signal feedback(message: String)
var player: Node
var locked_items: Array[int] = []
var time_source: Callable = func() -> float: return Time.get_unix_time_from_system()

func bind_player(value: Node) -> void:
	player = value
	ItemCatalog.ensure_loaded()
	if not is_instance_valid(player) or not player.get("stats") is Dictionary:
		return
	var stats: Dictionary = player.get("stats")
	MountSystem.ensure_stats(stats)
	for key: String in ["inventory","equipment"]:
		if not stats.has(key):
			stats[key] = {}
	if not stats.has("copper"):
		stats["copper"] = 100
	if not stats.has("bag_capacity"):
		stats["bag_capacity"] = 32
	if not stats.has("warehouse_capacity"):
		stats["warehouse_capacity"] = 64
	if not stats.has("regeneration_effects"):
		stats["regeneration_effects"] = []
	if not stats.has("medicine_cooldowns"): stats["medicine_cooldowns"] = {}

func _stats() -> Dictionary:
	if is_instance_valid(player) and player.get("stats") is Dictionary:
		return player.get("stats")
	return {}

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

func _count_valid(count: Variant) -> bool:
	return _integer(count,1,99999)

func count_item(id: int) -> int:
	return int(_stats().get("inventory",{}).get(str(id),0))

func used_slots() -> int:
	return _stats().get("inventory",{}).size()

func _bag_accepts(bag: Dictionary, id: int, count: int) -> bool:
	var item: Dictionary = ItemCatalog.get_item(id)
	if item.is_empty() or int(bag.get(str(id),0)) + count > int(item["max_stack"]):
		return false
	return bag.has(str(id)) or bag.size() < int(_stats().get("bag_capacity",32))

func can_add(id: int, count: Variant = 1) -> bool:
	if _stats().is_empty() or not _count_valid(count):
		return false
	return _bag_accepts(_stats()["inventory"],id,int(count))

func add_item(id: int, count: Variant = 1) -> bool:
	if not can_add(id,count):
		return _fail("У сумці немає місця або стос переповнений.")
	var bag: Dictionary = _stats()["inventory"]
	bag[str(id)] = int(bag.get(str(id),0)) + int(count)
	MountSystem.register_acquisition(_stats(),id)
	changed.emit()
	return true

func _subtract(bag: Dictionary, id: int, count: int) -> void:
	var remaining: int = int(bag.get(str(id),0)) - count
	if remaining == 0:
		bag.erase(str(id))
		if ItemCatalog.get_item(id).get("kind") == "mount":
			_stats().get("mount_acquired_at",{}).erase(str(id))
	else:
		bag[str(id)] = remaining

func remove_item(id: int, count: Variant = 1) -> bool:
	if not _count_valid(count) or ItemCatalog.get_item(id).is_empty() or id in locked_items or count_item(id) < int(count):
		return _fail("Предмет захищено або його кількості недостатньо.")
	_subtract(_stats()["inventory"],id,int(count))
	changed.emit()
	return true

func equip_item(id: int) -> bool:
	var stats: Dictionary = _stats()
	var item: Dictionary = ItemCatalog.get_item(id)
	if stats.is_empty() or item.get("kind") != "equipment" or id in locked_items or count_item(id) < 1 or int(stats.get("level",1)) < int(item["required_level"]):
		return _fail("Цю річ зараз не можна одягнути.")
	var slot: String = item["slot"]
	var old: int = int(stats["equipment"].get(slot,0))
	if old == id:
		return _fail("Цю річ уже одягнено.")
	if old in locked_items:
		return _fail("Одягнену річ захищено.")
	var bag: Dictionary = stats["inventory"].duplicate(true)
	_subtract(bag,id,1)
	if old != 0:
		if not _bag_accepts(bag,old,1):
			return _fail("Немає місця для попередньої речі.")
		bag[str(old)] = int(bag.get(str(old),0)) + 1
	stats["inventory"] = bag
	stats["equipment"][slot] = id
	changed.emit()
	return true

func unequip_item(slot: String) -> bool:
	var stats: Dictionary = _stats()
	if stats.is_empty() or not stats["equipment"].has(slot):
		return false
	var id: int = int(stats["equipment"][slot])
	if id in locked_items or not can_add(id,1):
		return _fail("Річ захищено або сумку заповнено.")
	stats["inventory"][str(id)] = count_item(id) + 1
	stats["equipment"].erase(slot)
	changed.emit()
	return true

func use_item(id: int) -> bool:
	CharacterSystem.ensure_skills()
	var stats: Dictionary = _stats()
	if stats.is_empty() or id in locked_items or count_item(id) < 1 or int(stats.get("hp",0)) <= 0:
		return _fail("Предмет не можна використати.")
	var effect: Dictionary = ItemCatalog.get_item(id).get("effect",{})
	var now: float = float(time_source.call())
	var medicine_group: String = MedicineState.group(effect)
	if not medicine_group.is_empty() and not MedicineState.available(stats,medicine_group,now): return _fail("Зілля ще відновлюється.")
	if effect.get("recipient") == "pet":
		var pets: CompanionSystem = CompanionSystem.new()
		pets.player = player
		var used: bool = pets.feed_talent(str(stats.get("summoned_pet","")),id) if effect.get("type") == "pet_talent" else pets.medicate(str(stats.get("summoned_pet","")),id,now)
		if used: changed.emit()
		return used
	match effect.get("type",""):
		"restore", "regenerate":
			var field: String = effect["stat"]
			if not _integer(stats.get(field),0,1000000000) or not _integer(stats.get("max_"+field),0,1000000000) or int(stats[field]) >= int(stats["max_"+field]):
				return _fail("Відновлення зараз не потрібне.")
			if effect["type"] == "restore":
				stats[field] = mini(int(stats["max_"+field]),int(stats[field]) + int(effect["amount"]))
			else:
				if not ItemEffects.validate(stats):
					return false
				var effects: Array = stats.get("regeneration_effects",[])
				if effects.size() >= ItemEffects.MAX_EFFECTS:
					return _fail("Уже діє п'ять ефектів їжі.")
				for active: Dictionary in effects:
					if int(active["item_id"]) == id:
						return _fail("Ефект цієї їжі вже діє.")
				effects.append({"item_id":id,"stat":field,"remaining_amount":float(effect["amount"]),"remaining_time":float(effect["duration"]),"fractional":0.0})
				stats["regeneration_effects"] = effects
		"expand_bag":
			if not _integer(stats.get("bag_capacity"),1,100) or int(stats["bag_capacity"]) >= 100:
				return _fail("Сумка вже має максимальну місткість.")
			stats["bag_capacity"] = mini(100,int(stats["bag_capacity"]) + int(effect["amount"]))
		"expand_pets":
			if not _integer(stats.get("pet_capacity",CompanionSystem.MAX_PETS),1,PetDevelopment.CAPACITY_LIMIT-1): return _fail("Досягнуто межі контрактів зі звірами.")
			stats["pet_capacity"] = int(stats.get("pet_capacity",CompanionSystem.MAX_PETS))+int(effect["amount"])
		"expand_warehouse":
			var capacity: Variant = stats.get("warehouse_capacity",64)
			if not _integer(capacity,64,128) or int(capacity) >= 128:
				return _fail("Склад уже має максимальну місткість.")
			stats["warehouse_capacity"] = mini(128,int(capacity) + int(effect["amount"]))
		"respec_skills":
			if not stats.get("skills") is Dictionary or stats["skills"].is_empty() or not _integer(stats.get("skill_points"),0,100000):
				return _fail("Немає витрачених очок навичок для повернення.")
			for key: Variant in stats["skills"]:
				if not key is String or not key.is_valid_int() or not CharacterSystem.SKILLS.has(int(key)) or not _integer(stats["skills"][key],1,int(CharacterSystem.SKILLS[int(key)]["max_rank"])):
					return false
			if not CharacterSystem.respec_skills(stats,0):
				return false
		_:
			return _fail("Цей предмет має інше призначення.")
	_subtract(stats["inventory"],id,1)
	if not medicine_group.is_empty(): MedicineState.start(stats,medicine_group,now)
	changed.emit()
	return true

func buy_item(id: int, count: Variant = 1) -> bool:
	var stats: Dictionary = _stats()
	var item: Dictionary = ItemCatalog.get_item(id)
	if stats.is_empty() or not _count_valid(count) or item.is_empty() or id not in ItemCatalog.shop_items() or not can_add(id,count):
		return _fail("Цю покупку неможливо виконати.")
	var cost: int = int(item["buy_price"]) * int(count)
	if cost <= 0 or int(stats["copper"]) < cost:
		return _fail("Недостатньо міді.")
	stats["copper"] = int(stats["copper"]) - cost
	stats["inventory"][str(id)] = count_item(id) + int(count)
	MountSystem.register_acquisition(stats,id)
	changed.emit()
	return true

func sell_item(id: int, count: Variant = 1) -> bool:
	var stats: Dictionary = _stats()
	var item: Dictionary = ItemCatalog.get_item(id)
	if stats.is_empty() or not _count_valid(count) or item.is_empty() or id in locked_items or count_item(id) < int(count):
		return _fail("Предмет не можна продати.")
	var income: int = int(item["sell_price"]) * int(count)
	if int(stats["copper"]) + income > 1000000000:
		return false
	_subtract(stats["inventory"],id,int(count))
	stats["copper"] = int(stats["copper"]) + income
	changed.emit()
	return true

func discard_item(id: int, count: Variant = 1) -> bool:
	return remove_item(id,count)

func bonus_totals() -> Dictionary:
	var totals: Dictionary = {}
	for value: Variant in _stats().get("equipment",{}).values():
		var bonuses: Dictionary = ItemCatalog.get_item(int(value)).get("bonuses",{})
		for key: String in bonuses:
			totals[key] = int(totals.get(key,0)) + int(bonuses[key])
	return totals

func snapshot() -> Dictionary:
	var stats: Dictionary = _stats()
	return {"inventory":stats.get("inventory",{}).duplicate(true),"equipment":stats.get("equipment",{}).duplicate(true),"copper":stats.get("copper",0),"bag_capacity":stats.get("bag_capacity",32),"warehouse_capacity":stats.get("warehouse_capacity",64),"regeneration_effects":stats.get("regeneration_effects",[]).duplicate(true)}

func validate_state(stats: Dictionary) -> bool:
	if not stats.get("inventory") is Dictionary or not stats.get("equipment") is Dictionary or not _integer(stats.get("copper"),0,1000000000) or not _integer(stats.get("bag_capacity"),1,100):
		return false
	if not _integer(stats.get("warehouse_capacity",64),64,128) or not ItemEffects.validate(stats) or not MedicineState.validate(stats):
		return false
	if stats["inventory"].size() > int(stats["bag_capacity"]):
		return false
	for key: Variant in stats["inventory"]:
		if not key is String or not key.is_valid_int() or str(int(key)) != key:
			return false
		var item: Dictionary = ItemCatalog.get_item(int(key))
		if item.is_empty() or not _integer(stats["inventory"][key],1,int(item["max_stack"])):
			return false
	var equipped_ids: Array[int] = []
	for key: Variant in stats["equipment"]:
		var value: Variant = stats["equipment"][key]
		if not key is String or key not in ItemCatalog.SLOTS or not _integer(value,1,99999999):
			return false
		var item: Dictionary = ItemCatalog.get_item(int(value))
		if item.is_empty() or item["kind"] != "equipment" or item["slot"] != key or int(value) in equipped_ids:
			return false
		equipped_ids.append(int(value))
	return true

func _fail(message: String) -> bool:
	feedback.emit(message)
	return false
