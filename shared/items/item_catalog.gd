class_name ItemCatalog
extends RefCounted

## Text/IDs/slots are original data. Numerical prices, bonuses and levels are
## explicit provisional balance until original binary numerical fields decode.
const SLOTS: Array[String] = ["head", "body", "weapon", "shoes", "belt", "glove", "necklace", "ring", "shield"]
const STARTER_SHOP: Array[int] = [10002,10003,10004,10439,10005,10006,10007,10010,30016,30033,30419,31142,31143,30645,30030,30484,31144,31145,30195,30197,30198,30199,30200,30201,30202,30203,30204,30205,30621,30081,30092,30020,30022,30029,30458,10018]
const MOUNT_LABELS: Dictionary = {10116:"Сивий гриф",10063:"Сивий гриф",10086:"Сивий гриф · 3 дні",10018:"Зелений гриф",10085:"Сірий гриф",10087:"Сірий гриф · 3 дні"}
const LABELS: Dictionary = {10002:"Шолом новачка",10003:"Меч новачка",10004:"Обладунок новачка",10439:"Чоботи новачка",10005:"Обруч новачка",10006:"Посох новачка",10007:"Мантія новачка",10010:"Довгий меч",30016:"Мале зілля здоров'я",30645:"Мале зілля мани",30020:"Кров звіра · лікування",30022:"Плід Біло · корм",30029:"Яйце вепра",30458:"Яйце шакала",30037:"Кістка вепра"}
static var all_items: Dictionary = {}
static var _loaded: bool = false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for row: Variant in _rows("res://data/equipment.json"):
		if not row is Dictionary or not row.has("id") or not row.get("details") is Array:
			continue
		var tokens: Array = row["details"]
		var record_id: int = int(row["id"])
		if record_id in [10116,10063,10086,10018,10085,10087] and "HORSE" in tokens:
			var mount: Dictionary = _definition(record_id,str(row.get("name","")),tokens,"mount","",200,1,{})
			mount["label"] = MOUNT_LABELS[record_id]
			mount["seats"] = 2 if record_id in [10116,10063,10086] else 1
			mount["duration_seconds"] = 259200 if record_id in [10086,10087] else 0
			all_items[record_id] = mount
			continue
		if "equip" not in tokens:
			continue
		var slot: String = ""
		for candidate: String in SLOTS:
			if candidate in tokens:
				slot = candidate
				break
		if slot.is_empty():
			continue
		var id: int = int(row["id"])
		var bonuses: Dictionary = {"attack": 6} if slot == "weapon" else {"defense": 2}
		if slot in ["necklace","ring"]:
			bonuses = {"max_mp": 8}
		if slot == "body":
			bonuses = {"defense": 4,"max_hp": 10}
		all_items[id] = _definition(id,str(row.get("name","")),tokens,"equipment",slot,200 if id == 10010 else 40 if slot == "weapon" else 25,1,bonuses)
	for row: Variant in _rows("res://data/original/all_prop.json"):
		if not row is Dictionary or not row.get("strings") is Array or row["strings"].is_empty():
			continue
		var tokens: Array = row["strings"]
		if not _has_item_path(tokens):
			continue
		var id: int = int(row.get("id",0))
		if id <= 0 or all_items.has(id):
			continue
		var kind: String = "material"
		var price: int = 5
		var effect: Dictionary = _effect_from_source(id,tokens)
		if not effect.is_empty():
			kind = "pet_food" if effect.get("type") == "pet_talent" else "pet_potion" if effect.get("recipient") == "pet" else "consumable"
			price = 20 if effect["type"] in ["restore","regenerate"] else 100
		elif id in [30020,30025,30703]:
			kind = "pet_potion"
			price = 20
		elif id in [30022,30015,30988,30989]:
			kind = "pet_food"
			price = 10
		elif id in [30749,30023,30750,30751,30752,30753]:
			kind = "pet_rune"
			price = 50
		elif str(tokens[0]).begins_with("魔法兽蛋"):
			kind = "pet_egg"
			price = 60
		var definition: Dictionary = _definition(id,str(tokens[0]).strip_edges(),tokens,kind,"",price,99 if kind != "material" else 999,{})
		if not effect.is_empty():
			definition["effect"] = effect
		all_items[id] = definition

static func _effect_from_source(id: int, tokens: Array) -> Dictionary:
	# Tier labels and immediate/gradual semantics are original text; quantities
	# and the unified capacity limits are explicitly provisional modern balance.
	if id in [30621,30622,30674,30689,30728,30732,30733,30734]:
		return {"type":"expand_bag","amount":5}
	if id in [30081,30998]:
		return {"type":"expand_warehouse","amount":5}
	if id in [30092,30788]:
		return {"type":"respec_skills"}
	if id in [30595,30727]: return {"type":"expand_pets","amount":1}
	var talent: Dictionary = SourcePetCatalog.consumable(id).get("talent_increment",{})
	if not talent.is_empty(): return {"type":"pet_talent","recipient":"pet","stat":talent["stat"],"amount":talent["amount"]}
	for key: String in AutoMedicine.PRIORITIES:
		if key.begins_with("player_") and id in AutoMedicine.PRIORITIES[key]:
			return {"type":"restore","stat":"hp" if key == "player_hp" else "mp","amount":50 if key == "player_hp" else 30}
	var tiers: Array[String] = ["少量","部分","较多","很多","大量"]
	for token: Variant in tokens:
		if not token is String:
			continue
		var is_pet: bool = "立即恢复魔法兽" in token
		var mode: String = "restore" if "立即恢复人物" in token or is_pet else "regenerate" if "逐渐恢复人物" in token else ""
		if mode.is_empty():
			continue
		var field: String = "hp" if "体力" in token else "mp" if "法力" in token else ""
		if field.is_empty():
			continue
		for tier: int in tiers.size():
			if tiers[tier] in token:
				var amounts: Array = [50,100,250,500,1000] if field == "hp" else [30,60,150,300,600]
				var effect: Dictionary = {"type":mode,"stat":field,"amount":amounts[tier]}
				if is_pet: effect["recipient"] = "pet"
				if mode == "regenerate":
					effect["duration"] = 10.0
				return effect
	return {}

static var _CJK: RegEx = RegEx.create_from_string("[\\x{4e00}-\\x{9fff}]")

## Ukrainian fallback for source items that have no translated label yet.
static func _generic_label(kind: String, slot: String, id: int) -> String:
	var slots: Dictionary = {"head":"Шолом","body":"Обладунок","weapon":"Зброя","shoes":"Чоботи","belt":"Пояс","glove":"Рукавиці","necklace":"Намисто","ring":"Перстень","shield":"Щит"}
	var kinds: Dictionary = {"consumable":"Зілля","material":"Матеріал","mount":"Скакун","pet_egg":"Яйце магічного звіра","pet_rune":"Руна звіра","pet_food":"Корм для звіра","pet_potion":"Зілля для звіра"}
	var base: String = slots.get(slot,"Спорядження") if kind == "equipment" else kinds.get(kind,"Предмет")
	return "%s №%d" % [base,id % 1000]

static func _definition(id: int, original_name: String, tokens: Array, kind: String, slot: String, price: int, stack: int, bonuses: Dictionary) -> Dictionary:
	var descriptions: PackedStringArray = []
	for token: Variant in tokens:
		if token is String and token.length() > 8 and not token.begins_with("icon_") and not token.begins_with("group"):
			descriptions.append(token)
	var label: String = LABELS.get(id,original_name)
	if _CJK.search(label) != null:
		label = _generic_label(kind,slot,id)
	var clean: PackedStringArray = []
	for line: String in descriptions:
		if _CJK.search(line) == null and not line.contains("\\") and not line.contains(".bmp"):
			clean.append(line)
	descriptions = clean
	return {"id":id,"name":original_name,"label":label,"slot":slot,"kind":kind,"buy_price":price,"sell_price":maxi(1,price/2),"max_stack":stack,"bonuses":bonuses,"required_level":1,"description":"\n".join(descriptions),"balance_source":"provisional"}

static func _rows(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Array:
		return []
	return parser.data

static func _has_item_path(tokens: Array) -> bool:
	for token: Variant in tokens:
		if token is String and (token == "item" or token.begins_with("item\\")):
			return true
	return false

static func get_item(id: int) -> Dictionary:
	ensure_loaded()
	return all_items.get(id,{}).duplicate(true)

static func shop_items() -> Array[int]:
	ensure_loaded()
	var result: Array[int] = []
	var candidates: Array[int] = STARTER_SHOP.duplicate()
	candidates.append_array(CompanionSystem.new().available_eggs())
	candidates.append_array([30015,30988,30989,30025,30703,30749,30023,30750,30751,30752,30753])
	for values: Array in AutoMedicine.PRIORITIES.values(): candidates.append_array(values)
	candidates.append_array([30595,30727,30164,30694,30730,30731,30696,30253])
	for key: String in SourcePetCatalog.data().get("consumables",{}):
		if not SourcePetCatalog.consumable(int(key)).get("talent_increment",{}).is_empty(): candidates.append(int(key))
	for id: int in candidates:
		if all_items.has(id) and id not in result:
			result.append(id)
	return result
