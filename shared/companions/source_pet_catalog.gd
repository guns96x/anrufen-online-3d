class_name SourcePetCatalog
extends RefCounted

static var _data: Dictionary = {}
const TYPE_LABELS: Dictionary = {300001:"Фізичний",300005:"Магічний",300006:"Захисний",300007:"Підтримка"}

static func data() -> Dictionary:
	if _data.is_empty():
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/pet_rules.json"))
		if value is Dictionary: _data = value
	return _data

static func species(id: int) -> Dictionary:
	return data().get("species",{}).get(str(id),{}).duplicate(true)

static func type_id(id: int) -> int:
	return int(data().get("species",{}).get(str(id),{}).get("template_id",0))

static func innate(id: int) -> int:
	return int(data().get("species",{}).get(str(id),{}).get("innate_skill_id",0))

static func same_type(first: int, second: int) -> bool:
	var kind: int = type_id(first)
	return TYPE_LABELS.has(kind) and kind == type_id(second)

static func skill(id: int) -> Dictionary:
	return data().get("skills",{}).get(str(id),{}).duplicate(true)

static func random_skills() -> Array[int]:
	var result: Array[int] = []
	for key: String in data().get("skills",{}):
		if data()["skills"][key].get("kind") == "random": result.append(int(key))
	result.sort()
	return result

static func consumable(id: int) -> Dictionary:
	return data().get("consumables",{}).get(str(id),{}).duplicate(true)
