class_name OriginalQuestCatalog
extends RefCounted

## Full recovered archive. An archived quest is not automatically playable:
## prerequisites/objective target IDs missing from the client require an adapter.
static var _rules: Dictionary = {}
static var _texts: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/quest_rules.json"))
		if data is Dictionary and data.get("quests") is Dictionary:
			_rules = data["quests"]
	return _rules

static func get_rule(id: int) -> Dictionary:
	return rules().get(str(id),{}).duplicate(true)

static func texts(id: int) -> Array:
	if _texts.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/quest_graph.json"))
		if data is Dictionary and data.get("quests") is Dictionary:
			_texts = data["quests"]
	return _texts.get(str(id),{}).get("source_strings",[]).duplicate()

static func rewards(id: int, class_id: int) -> Dictionary:
	var rule: Dictionary = get_rule(id)
	if rule.is_empty(): return {}
	var amounts: Array = rule["reward_amounts"]
	var items: Dictionary = {}
	for entry: Dictionary in rule["items"]:
		if entry["conditional"]:
			var conditions: Array = entry.get("condition_words",[])
			# All 90 conditional entries in this archive have exactly these two
			# source class predicates; reject unknown conditions, never grant all.
			if conditions.size() != 7: return {}
			for index: int in [0,1,3,4,5,6]:
				if int(conditions[index]) != 0: return {}
			var branch: int = 130002 if class_id in [130002,130005,130008,130009] else 130001
			if int(conditions[2]) != branch: continue
		items[str(int(entry["id"]))] = int(entry["quantity"])
	return {"copper":int(amounts[0]),"exp":int(amounts[1]),"items":items,"titles":rule["titles"].duplicate()}

static func reward_inventory(stats: Dictionary, id: int, consumed: Dictionary = {}) -> Dictionary:
	var reward: Dictionary = rewards(id,int(stats.get("class_id",130001)))
	if reward.is_empty() or not stats.get("inventory") is Dictionary: return {}
	var bag: Dictionary = stats["inventory"].duplicate(true)
	for key: String in consumed:
		var quantity: int = int(consumed[key])
		if quantity < 1 or int(bag.get(key,0)) < quantity: return {}
		if int(bag[key]) == quantity: bag.erase(key)
		else: bag[key] = int(bag[key])-quantity
	for key: String in reward["items"]:
		var definition: Dictionary = ItemCatalog.get_item(int(key))
		if definition.is_empty(): return {}
		var quantity: int = int(bag.get(key,0))+int(reward["items"][key])
		if quantity > int(definition["max_stack"]): return {}
		bag[key] = quantity
	if bag.size() > int(stats.get("bag_capacity",32)) or int(stats.get("copper",0))+int(reward["copper"]) > 1000000000: return {}
	var titles: Array = stats.get("owned_titles",[]).duplicate()
	for title: Variant in reward["titles"]:
		if not TitleSystem.catalog().has(int(title)): return {}
		if int(title) not in titles: titles.append(int(title))
	return {"inventory":bag,"owned_titles":titles,"copper":int(stats.get("copper",0))+int(reward["copper"]),"exp":int(reward["exp"])}
