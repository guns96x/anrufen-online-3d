class_name GameServices
extends RefCounted

signal changed()
signal feedback(message: String)
var player: Node
var inventory: InventorySystem

# Recipe quantities are provisional; the original UI confirms synthesis,
# while the binary recipe quantities have not yet been decoded.
const RECIPES: Array[Dictionary] = [
	{"name": "Лікувальні припаси", "input": {"30037": 2}, "output": 30016, "count": 2, "copper": 8},
	{"name": "Відновлення мани", "input": {"30037": 2}, "output": 30645, "count": 2, "copper": 8},
]

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
	changed.emit()
	return true

func craft(index: int) -> bool:
	if index < 0 or index >= RECIPES.size():
		return false
	var recipe: Dictionary = RECIPES[index]
	if int(player.stats["copper"]) < int(recipe["copper"]):
		return false
	for key: String in recipe["input"]:
		if int(key) in inventory.locked_items or inventory.count_item(int(key)) < int(recipe["input"][key]):
			return false
	# Simulate the final bag rather than rejecting a recipe whose input frees
	# the space needed for its output. Rollback is local and synchronous.
	var before: Dictionary = player.stats["inventory"].duplicate(true)
	for key: String in recipe["input"]:
		player.stats["inventory"][key] -= int(recipe["input"][key])
		if int(player.stats["inventory"][key]) == 0:
			player.stats["inventory"].erase(key)
	if not inventory.add_item(recipe["output"], recipe["count"]):
		player.stats["inventory"] = before
		return false
	player.stats["copper"] -= int(recipe["copper"])
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
