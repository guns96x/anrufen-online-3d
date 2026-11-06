class_name SourcePetCatalog
extends RefCounted

static var _data: Dictionary = {}
const TYPE_LABELS: Dictionary = {300001:"Фізичний",300005:"Магічний",300006:"Захисний",300007:"Підтримка"}

# Original 12 personalities from pet_rules.json with Ukrainian labels and provisional stat nudge mapping.
const PERSONALITY_MAP: Dictionary = {
	190001: {"name": "brave", "label": "Хоробрий", "nudge_stat": "attack", "nudge_bonus": 0.10},
	190002: {"name": "timid", "label": "Боязкий", "nudge_stat": "speed", "nudge_bonus": 0.10},
	190004: {"name": "erudite", "label": "Мудрий", "nudge_stat": "mp", "nudge_bonus": 0.10},
	190005: {"name": "loyal", "label": "Вірний", "nudge_stat": "defense", "nudge_bonus": 0.10},
	190007: {"name": "proud", "label": "Гордий", "nudge_stat": "attack", "nudge_bonus": 0.08},
	190008: {"name": "solitary", "label": "Самітній", "nudge_stat": "defense", "nudge_bonus": 0.08},
	190009: {"name": "boastful", "label": "Пихатий", "nudge_stat": "attack", "nudge_bonus": 0.10},
	190010: {"name": "quirky", "label": "Дивакуватий", "nudge_stat": "speed", "nudge_bonus": 0.08},
	190011: {"name": "playful", "label": "Грайливий", "nudge_stat": "speed", "nudge_bonus": 0.10},
	190012: {"name": "vicious", "label": "Лютий", "nudge_stat": "attack", "nudge_bonus": 0.10},
	190013: {"name": "cunning", "label": "Хитрий", "nudge_stat": "defense", "nudge_bonus": 0.08},
	190014: {"name": "cautious", "label": "Обережний", "nudge_stat": "hp", "nudge_bonus": 0.10}
}

# Provisional species talent growth ranges (min..max) scaled per species template.
const TEMPLATE_TALENT_RANGES: Dictionary = {
	300001: {"hp": [12, 20], "attack": [15, 25], "defense": [10, 18], "speed": [10, 18]}, # Physical
	300005: {"hp": [10, 16], "attack": [16, 26], "defense": [8, 15], "speed": [12, 20]},  # Magic
	300006: {"hp": [18, 28], "attack": [10, 16], "defense": [16, 26], "speed": [8, 14]},  # Defense
	300007: {"hp": [14, 22], "attack": [10, 18], "defense": [12, 20], "speed": [14, 22]},  # Support
	0: {"hp": [10, 20], "attack": [10, 20], "defense": [10, 20], "speed": [10, 20]}         # Special / fallback
}

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

static func lifespan_raw(id: int) -> float:
	var val: Variant = data().get("species",{}).get(str(id),{}).get("lifespan_raw", 18000)
	return float(val) if val != null and float(val) > 0 else 18000.0

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

static func personalities() -> Dictionary:
	return PERSONALITY_MAP.duplicate(true)

static func personality_info(id: int) -> Dictionary:
	return PERSONALITY_MAP.get(id, PERSONALITY_MAP[190001]).duplicate(true)

static func species_talent_ranges(species_id: int) -> Dictionary:
	var t_id: int = type_id(species_id)
	return TEMPLATE_TALENT_RANGES.get(t_id, TEMPLATE_TALENT_RANGES[0]).duplicate(true)

