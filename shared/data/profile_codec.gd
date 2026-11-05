class_name ProfileCodec
extends RefCounted

# JSON represents numbers as floats. Godot Array.has/Dictionary.has compare
# numeric Variant types strictly, so normalize identifiers before using them.
static func _ids(values: Array) -> Array:
	var normalized: Array = []
	for value: Variant in values:
		normalized.append(int(value) if _whole(value) else value)
	return normalized

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) < 1000000000000000.0

static func normalize(stats: Dictionary) -> void:
	for key: String in ["class_id","race_id","title_id","mount_id","level","stat_points","skill_points","copper","bag_capacity","warehouse_capacity","pet_capacity","free_starter_skill","hp","max_hp","mp","max_mp","exp","exp_to_next","attack","defense","element","magic_attack","base_attack","base_magic_attack","base_defense","base_max_hp"]:
		if _whole(stats.get(key)):
			stats[key] = int(stats[key])
	for key: String in ["inventory","equipment","warehouse","attributes","skills","hotbar"]:
		if stats.get(key) is Dictionary:
			for id: Variant in stats[key]:
				if _whole(stats[key][id]): stats[key][id] = int(stats[key][id])
	for key: String in ["locked_items","owned_titles"]:
		if stats.get(key) is Array:
			stats[key] = _ids(stats[key])
	if stats.get("companions") is Array:
		for pet: Variant in stats["companions"]:
			if pet is Dictionary and pet.get("skills") is Array:
				pet["skills"] = _ids(pet["skills"])
			if pet is Dictionary:
				for key: String in ["species_id","level","exp","hp","max_hp","mp","max_mp","hunger","innate_skill_id","form_rank","growth_base_hp","growth_base_mp"]:
					if _whole(pet.get(key)): pet[key] = int(pet[key])
				if pet.get("talents") is Dictionary:
					for key: Variant in pet["talents"]:
						if _whole(pet["talents"][key]): pet["talents"][key] = int(pet["talents"][key])
	if stats.get("incubations") is Array:
		for egg: Variant in stats["incubations"]:
			if egg is Dictionary and egg.get("inherited_skills") is Array:
				egg["inherited_skills"] = _ids(egg["inherited_skills"])
