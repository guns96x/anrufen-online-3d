class_name GameServices
extends RefCounted

signal changed()
signal feedback(message: String)
var player: Node
var inventory: InventorySystem

static var RECIPES: Array[Dictionary] = []
static var recipes_by_id: Dictionary = {}
static var _recipes_loaded: bool = false

static func _static_init() -> void:
	ensure_recipes_loaded()

static func ensure_recipes_loaded() -> void:
	if _recipes_loaded:
		return
	_recipes_loaded = true
	RECIPES.clear()
	recipes_by_id.clear()
	var path: String = "res://data/recipes.json"
	if not FileAccess.file_exists(path):
		return
	var content: String = FileAccess.get_file_as_string(path)
	var parser: JSON = JSON.new()
	if parser.parse(content) != OK or not parser.data is Array:
		return
	for item: Variant in parser.data:
		if not item is Dictionary:
			continue
		var raw: Dictionary = (item as Dictionary).duplicate(true)
		var id_val: int = int(raw.get("id", 0))
		var name_val: String = str(raw.get("name", ""))
		var copper_val: int = int(raw.get("copper", 0))
		var req_lvl: int = int(raw.get("required_level", 1))
		var is_prov: bool = bool(raw.get("provisional", false))
		var src_id: Variant = raw.get("source_record_id")
		if src_id != null:
			src_id = int(src_id)
		
		var in_dict: Dictionary = {}
		var raw_inputs: Variant = raw.get("inputs", raw.get("input", {}))
		if raw_inputs is Dictionary:
			for k: Variant in raw_inputs:
				in_dict[str(int(k))] = int(raw_inputs[k])
		
		var out_id: int = 0
		var out_count: int = 1
		var raw_output: Variant = raw.get("output")
		if raw_output is Dictionary:
			if raw_output.has("item_id") and raw_output.has("count"):
				out_id = int(raw_output["item_id"])
				out_count = int(raw_output["count"])
			elif not raw_output.is_empty():
				out_id = int(raw_output.keys()[0])
				out_count = int(raw_output.values()[0])
		elif raw_output != null:
			out_id = int(raw_output)
			out_count = int(raw.get("count", 1))
		
		var norm: Dictionary = {
			"id": id_val,
			"name": name_val,
			"input": in_dict,
			"inputs": in_dict,
			"output": out_id,
			"count": out_count,
			"copper": copper_val,
			"required_level": req_lvl,
			"provisional": is_prov,
			"source_record_id": src_id
		}
		RECIPES.append(norm)
		if id_val > 0:
			recipes_by_id[id_val] = norm
			recipes_by_id[str(id_val)] = norm

static func recipe_by_id(recipe_id: Variant) -> Dictionary:
	ensure_recipes_loaded()
	if recipe_id is int or (recipe_id is float and float(int(recipe_id)) == recipe_id):
		var num: int = int(recipe_id)
		if recipes_by_id.has(num):
			return (recipes_by_id[num] as Dictionary).duplicate(true)
	elif recipe_id is String:
		if recipes_by_id.has(recipe_id):
			return (recipes_by_id[recipe_id] as Dictionary).duplicate(true)
		if recipe_id.is_valid_int():
			var num: int = recipe_id.to_int()
			if recipes_by_id.has(num):
				return (recipes_by_id[num] as Dictionary).duplicate(true)
	return {}

static func recipe_by_index(index: int) -> Dictionary:
	ensure_recipes_loaded()
	if index >= 0 and index < RECIPES.size():
		return RECIPES[index].duplicate(true)
	return {}

func bind_player(value: Node, items: InventorySystem) -> void:
	player = value
	inventory = items
	if not player.stats.has("warehouse"):
		player.stats["warehouse"] = {}
	if not player.stats.has("locked_items"):
		player.stats["locked_items"] = []
	if not player.stats.has("warehouse_capacity"):
		player.stats["warehouse_capacity"] = 64

func deposit(id: int, count: int = 1) -> bool:
	if count <= 0 or inventory.count_item(id) < count or id in inventory.locked_items:
		return false
	var bank: Dictionary = player.stats["warehouse"]
	if not bank.has(str(id)) and bank.size() >= int(player.stats.get("warehouse_capacity",64)):
		feedback.emit("Склад заповнений.")
		return false
	var acquired_at: Variant = player.stats.get("mount_acquired_at",{}).get(str(id))
	if not inventory.remove_item(id, count):
		return false
	if acquired_at != null:
		player.stats["mount_acquired_at"][str(id)] = acquired_at
	bank[str(id)] = int(bank.get(str(id), 0)) + count
	changed.emit()
	return true

func withdraw(id: int, count: int = 1) -> bool:
	var bank: Dictionary = player.stats["warehouse"]
	if count <= 0 or int(bank.get(str(id), 0)) < count or not inventory.can_add(id, count):
		return false
	if not inventory.add_item(id, count):
		return false
	bank[str(id)] -= count
	if int(bank[str(id)]) == 0:
		bank.erase(str(id))
	changed.emit()
	return true

func lock_item(id: int) -> bool:
	if inventory.count_item(id) <= 0:
		return false
	var locks: Array = player.stats["locked_items"]
	if id in locks:
		locks.erase(id)
	else:
		locks.append(id)
	if inventory != null:
		if id in inventory.locked_items:
			inventory.locked_items.erase(id)
		elif id in locks:
			inventory.locked_items.append(id)
	changed.emit()
	return true

func craft_by_index(index: int) -> bool:
	ensure_recipes_loaded()
	if index >= 0 and index < RECIPES.size():
		return _execute_craft(RECIPES[index])
	return false

func craft_by_id(recipe_id: Variant) -> bool:
	var r: Dictionary = recipe_by_id(recipe_id)
	if r.is_empty():
		return false
	return _execute_craft(r)

func synthesize(recipe_key: Variant = 0) -> bool:
	return craft(recipe_key)

func craft(recipe_key: Variant = 0) -> bool:
	ensure_recipes_loaded()
	if player == null or inventory == null or not player.get("stats") is Dictionary:
		return false
	if recipe_key is Dictionary:
		return _execute_craft(recipe_key)
	if recipe_key is String:
		var by_id: Dictionary = recipe_by_id(recipe_key)
		if not by_id.is_empty():
			return _execute_craft(by_id)
		if recipe_key.is_valid_int():
			var idx: int = recipe_key.to_int()
			if idx >= 0 and idx < RECIPES.size():
				return _execute_craft(RECIPES[idx])
		return false
	if recipe_key is int or (recipe_key is float and float(int(recipe_key)) == recipe_key):
		var num: int = int(recipe_key)
		if num >= 0 and num < RECIPES.size() and not recipes_by_id.has(num):
			return _execute_craft(RECIPES[num])
		if recipes_by_id.has(num):
			return _execute_craft(recipes_by_id[num])
		if num >= 0 and num < RECIPES.size():
			return _execute_craft(RECIPES[num])
	return false

func _execute_craft(recipe: Dictionary) -> bool:
	var stats: Dictionary = player.stats
	var req_lvl: int = int(recipe.get("required_level", 1))
	if int(stats.get("level", 1)) < req_lvl:
		feedback.emit("Недостатній рівень для створення.")
		return false
	var copper_cost: int = int(recipe.get("copper", 0))
	if int(stats.get("copper", 0)) < copper_cost:
		feedback.emit("Недостатньо міді.")
		return false
	var inputs: Dictionary = recipe.get("inputs", recipe.get("input", {}))
	var locked: Array = stats.get("locked_items", [])
	for key: Variant in inputs:
		var item_id: int = int(key)
		var needed: int = int(inputs[key])
		if item_id in inventory.locked_items or item_id in locked or inventory.count_item(item_id) < needed:
			feedback.emit("Недостатньо матеріалів.")
			return false
	
	var out_id: int = int(recipe.get("output", 0))
	var out_count: int = int(recipe.get("count", 1))
	if out_id <= 0 or out_count <= 0:
		return false
	
	var before_inv: Dictionary = stats.get("inventory", {}).duplicate(true)
	var sim_inv: Dictionary = before_inv.duplicate(true)
	for key: Variant in inputs:
		var skey: String = str(int(key))
		var needed: int = int(inputs[key])
		sim_inv[skey] = int(sim_inv.get(skey, 0)) - needed
		if int(sim_inv[skey]) <= 0:
			sim_inv.erase(skey)
	
	if not inventory._bag_accepts(sim_inv, out_id, out_count):
		feedback.emit("Сумка заповнена.")
		return false
	
	stats["inventory"] = sim_inv
	stats["copper"] = int(stats.get("copper", 0)) - copper_cost
	if not inventory.add_item(out_id, out_count):
		stats["inventory"] = before_inv
		stats["copper"] = int(stats.get("copper", 0)) + copper_cost
		return false
	changed.emit()
	return true

func expand_bag() -> bool:
	var capacity: int = int(player.stats.get("bag_capacity", 32))
	var cost: int = 100 + (capacity - 32) * 10
	if capacity >= 100 or int(player.stats["copper"]) < cost:
		return false
	player.stats["copper"] -= cost
	player.stats["bag_capacity"] = mini(100, capacity + 5)
	changed.emit()
	return true

static func validate(stats: Dictionary) -> bool:
	if not stats.get("warehouse", {}) is Dictionary or not ProgressionController._integer(stats.get("warehouse_capacity",64),1,128) or stats.get("warehouse", {}).size() > int(stats.get("warehouse_capacity",64)) or not stats.get("locked_items", []) is Array:
		return false
	for key: Variant in stats.get("warehouse", {}):
		var value: Variant = stats["warehouse"][key]
		if not key is String or not key.is_valid_int() or str(int(key)) != key or ItemCatalog.get_item(int(key)).is_empty() or not ProgressionController._integer(value, 1, 99999):
			return false
	for id: Variant in stats.get("locked_items", []):
		if not ProgressionController._integer(id, -9999999, 9999999) or ItemCatalog.get_item(int(id)).is_empty():
			return false
	return true
