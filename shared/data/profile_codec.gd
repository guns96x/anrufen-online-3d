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
				for key: String in ["species_id","level","exp","hp","max_hp","mp","max_mp","hunger","innate_skill_id","form_rank","growth_base_hp","growth_base_mp","growth_base_attack","growth_base_defense","growth_base_speed","personality_id","loyalty"]:
					if _whole(pet.get(key)): pet[key] = int(pet[key])
				var lvl: int = maxi(1, int(pet.get("level", 1)))
				var lvl_mp: int = 40 + maxi(0, lvl - 1) * 4
				if not pet.has("max_hp"): pet["max_hp"] = int(pet.get("hp", 60))
				if not pet.has("hp"): pet["hp"] = int(pet["max_hp"])
				if not pet.has("skills") or not pet.get("skills") is Array: pet["skills"] = []
				if not pet.has("hunger"): pet["hunger"] = 100
				if not pet.has("born_at"): pet["born_at"] = 0.0
				if not pet.has("max_mp") and not pet.has("mp"):
					pet["max_mp"] = lvl_mp
					pet["mp"] = lvl_mp
				if not pet.has("growth_base_hp"): pet["growth_base_hp"] = int(pet.get("max_hp", 60))
				if not pet.has("growth_base_mp"): pet["growth_base_mp"] = int(pet.get("max_mp", lvl_mp))
				if not pet.has("growth_base_attack"): pet["growth_base_attack"] = 8 + lvl * 3
				if not pet.has("growth_base_defense"): pet["growth_base_defense"] = 5 + lvl * 2
				if not pet.has("growth_base_speed"): pet["growth_base_speed"] = 10 + lvl
				if pet.get("talents") is Dictionary:
					for key: Variant in pet["talents"]:
						if _whole(pet["talents"][key]): pet["talents"][key] = int(pet["talents"][key])
				if not pet.get("growth_talents") is Dictionary:
					pet["growth_talents"] = {"hp": 10, "attack": 10, "defense": 10, "speed": 10}
				else:
					for stat: String in ["hp", "attack", "defense", "speed"]:
						if _whole(pet["growth_talents"].get(stat)): pet["growth_talents"][stat] = int(pet["growth_talents"][stat])
						elif not pet["growth_talents"].has(stat): pet["growth_talents"][stat] = 10
				if pet.get("gender") not in ["male", "female"]:
					pet["gender"] = "male"
				if not _whole(pet.get("personality_id")):
					pet["personality_id"] = 190001
					pet["personality"] = "brave"
				else:
					pet["personality_id"] = int(pet["personality_id"])
					if not pet.get("personality") is String:
						pet["personality"] = SourcePetCatalog.personality_info(int(pet["personality_id"])).get("name", "brave")
				var species_max_life: float = SourcePetCatalog.lifespan_raw(int(pet.get("species_id", 0)))
				if not (pet.get("max_lifespan") is int or pet.get("max_lifespan") is float) or float(pet["max_lifespan"]) <= 0:
					pet["max_lifespan"] = species_max_life
				else:
					pet["max_lifespan"] = float(pet["max_lifespan"])
				if not (pet.get("lifespan") is int or pet.get("lifespan") is float):
					pet["lifespan"] = pet["max_lifespan"]
				else:
					pet["lifespan"] = clampf(float(pet["lifespan"]), 0.0, pet["max_lifespan"])
				if not _whole(pet.get("loyalty")):
					pet["loyalty"] = 60
				else:
					pet["loyalty"] = clampi(int(pet["loyalty"]), 0, 100)
	if stats.get("incubations") is Array:
		for egg: Variant in stats["incubations"]:
			if egg is Dictionary and egg.get("inherited_skills") is Array:
				egg["inherited_skills"] = _ids(egg["inherited_skills"])
