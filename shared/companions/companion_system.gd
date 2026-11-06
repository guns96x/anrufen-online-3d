class_name CompanionSystem
extends RefCounted

signal changed()
signal feedback(message: String)

# All quantities and growth rates below are provisional modern tuning. Species
# and consumable identifiers come from the extracted original Anrufen tables.
# Backward-compatible verified seeds. Use egg_species_map()/available_eggs()
# for the complete dynamically matched source catalog.
const EGG_SPECIES: Dictionary = {30029: 140001, 30458: 140052}
const FOOD_ID: int = 30022
const HEAL_ID: int = 30020
const INCUBATION_SECONDS: float = 60.0
const MAX_PETS: int = 6
const MAX_INCUBATIONS: int = 3
const MAX_LEVEL: int = 100
# Original rune descriptions identify the corresponding 1-based random slot.
const LEARNING_RUNES: Dictionary = {30749:0,30023:1,30750:2}
const INHERITANCE_RUNES: Dictionary = {30751:0,30752:1,30753:2}
const AGE_STAGE_SECONDS: float = 604800.0 # Provisional stage duration.
var player: Node
var time_source: Callable
var _hunger_seconds: float = 0.0
static var _species: Array[Dictionary] = []
static var _species_ids: Dictionary = {}
static var _egg_species: Dictionary = {}
static var _unmatched_eggs: Array[int] = []
static var _ambiguous_eggs: Dictionary = {}
static var _egg_mapping_loaded: bool = false
static var _serial: int = 0

func _init() -> void:
	time_source = func() -> float: return Time.get_unix_time_from_system()

func bind_player(value: Node) -> void:
	player = value
	var stats: Dictionary = _stats()
	for key: String in ["companions", "incubations"]:
		if not stats.has(key):
			stats[key] = []
	if not stats.has("summoned_pet"):
		stats["summoned_pet"] = ""
	if not stats.has("pet_capacity"): stats["pet_capacity"] = MAX_PETS
	for pet: Variant in stats.get("companions",[]):
		if pet is Dictionary: PetDevelopment.ensure_pet(pet)

static func ensure_mana(pet: Dictionary) -> void:
	if not InventorySystem._integer(pet.get("level"),1,MAX_LEVEL): return
	if not pet.has("mp") and not pet.has("max_mp"):
		pet["max_mp"] = 40+maxi(0,int(pet.get("level",1))-1)*4
		pet["mp"] = pet["max_mp"]

func _stats() -> Dictionary:
	if is_instance_valid(player) and player.get("stats") is Dictionary:
		return player.get("stats")
	return {}

func species() -> Array[Dictionary]:
	if _species.is_empty():
		var file: FileAccess = FileAccess.open("res://data/original/all_pet.json", FileAccess.READ)
		if file == null:
			return []
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		if not parsed is Array:
			return []
		for entry: Variant in parsed:
			if not entry is Dictionary:
				continue
			var id: int = int(entry.get("id", 0))
			var strings: Array = entry.get("strings", [])
			if id < 140000 or id >= 150000 or strings.is_empty():
				continue
			var source_name: String = str(strings[0])
			var display: String = {140001: "Вепр", 140052: "Шакал", 140002: "Павук", 140000: "Курча", 140007: "Качка", 140011: "Слизень", 140005: "Скелет"}.get(id, source_name)
			_species.append({"id": id, "name": source_name, "label": display})
			_species_ids[id] = true
	return _species.duplicate(true)

static func _source_name(text: String) -> String:
	# The extracted wolf/snake species records start with a model-role prefix.
	# Strip only that explicit prefix and spacing; do not guess animal synonyms.
	return text.strip_edges().trim_prefix("怪物-").trim_prefix("怪物_").replace(" ", "")

func _ensure_egg_mapping() -> void:
	if _egg_mapping_loaded:
		return
	var candidates: Dictionary = {}
	for entry: Dictionary in species():
		var name_key: String = _source_name(str(entry["name"]))
		if not candidates.has(name_key):
			candidates[name_key] = []
		candidates[name_key].append(int(entry["id"]))
	_egg_species = EGG_SPECIES.duplicate()
	var file: FileAccess = FileAccess.open("res://data/original/all_prop.json", FileAccess.READ)
	if file == null:
		return
	var parser: JSON = JSON.new()
	var result: Error = parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Array:
		return
	_unmatched_eggs.clear()
	_ambiguous_eggs.clear()
	for entry: Variant in parser.data:
		if not entry is Dictionary or not entry.get("strings") is Array or entry["strings"].is_empty():
			continue
		var title: String = str(entry["strings"][0]).strip_edges()
		if not title.begins_with("魔法兽蛋"):
			continue
		var id: int = int(entry.get("id", 0))
		if id <= 0:
			continue
		var suffix: String = title.trim_prefix("魔法兽蛋").replace("（", "(").replace("）", ")").strip_edges()
		if not suffix.begins_with("(") or not suffix.ends_with(")"):
			_unmatched_eggs.append(id)
			continue
		var name_key: String = _source_name(suffix.trim_prefix("(").trim_suffix(")"))
		if not candidates.has(name_key):
			_unmatched_eggs.append(id)
			continue
		var matching: Array = candidates[name_key].duplicate()
		matching.sort()
		# Chicken and duck have multiple identically named source species. The
		# lowest actual ID is a deterministic adaptation, surfaced in the report.
		if matching.size() > 1:
			_ambiguous_eggs[id] = matching
		if not EGG_SPECIES.has(id):
			_egg_species[id] = int(matching[0])
	_egg_mapping_loaded = true

func available_eggs() -> Array[int]:
	_ensure_egg_mapping()
	var ids: Array[int] = []
	for id: int in _egg_species:
		ids.append(id)
	ids.sort()
	return ids

func egg_species_map() -> Dictionary:
	_ensure_egg_mapping()
	return _egg_species.duplicate(true)

func egg_mapping_report() -> Dictionary:
	_ensure_egg_mapping()
	return {"mapped_count": _egg_species.size(), "unmatched_ids": _unmatched_eggs.duplicate(), "ambiguous_candidates": _ambiguous_eggs.duplicate(true), "duplicate_name_policy": "lowest original species ID; known seed mappings retained"}

func get_pet(uid: String) -> Dictionary:
	for pet: Dictionary in _stats().get("companions", []):
		if pet.get("uid") == uid:
			return pet
	return {}

func age_seconds(uid: String) -> float:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty():
		return 0.0
	return maxf(0.0, _now() - float(pet["born_at"]))

func life_stage(uid: String) -> String:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty():
		return ""
	if int(pet["level"]) < 5:
		return "дитинча"
	if pet.has("rejuvenated_at") and age_seconds(uid) < 604800.0:
		return "омолоджений"
	# A reversible label for UI, not an assertion of original lifespan rules.
	return "літній" if age_seconds(uid) >= 604800.0 else "дорослий"

func _now() -> float:
	return float(time_source.call())

func _uid() -> String:
	_serial += 1
	return "%s-%d-%d" % [Crypto.new().generate_random_bytes(8).hex_encode(), Time.get_ticks_usec(), _serial]

func _has_item(id: int) -> bool:
	var stats: Dictionary = _stats()
	return not id in stats.get("locked_items", []) and int(stats.get("inventory", {}).get(str(id), 0)) > 0

func _consume(id: int) -> void:
	var bag: Dictionary = _stats()["inventory"]
	bag[str(id)] = int(bag[str(id)]) - 1
	if int(bag[str(id)]) == 0:
		bag.erase(str(id))

func _fail(text: String) -> bool:
	feedback.emit(text)
	return false

func _queue(species_id: int, egg_id: int = 0, parents: Array = []) -> void:
	var now: float = _now()
	_stats()["incubations"].append({"uid": _uid(), "species_id": species_id, "egg_id": egg_id, "started_at": now, "hatch_at": now + INCUBATION_SECONDS, "parents": parents})

func start_incubation(egg_id: int) -> bool:
	_ensure_egg_mapping()
	var stats: Dictionary = _stats()
	if stats.is_empty() or not _egg_species.has(egg_id) or not _has_item(egg_id):
		return _fail("Потрібне яйце магічного звіра без замка.")
	if stats["incubations"].size() >= MAX_INCUBATIONS:
		return _fail("Усі три інкубатори зайняті.")
	if not is_finite(_now()) or _now() < 0:
		return false
	_consume(egg_id)
	_queue(_egg_species[egg_id], egg_id)
	changed.emit()
	feedback.emit("Яйце поміщено в інкубатор на 60 секунд.")
	return true

func hatch(index: int) -> bool:
	var stats: Dictionary = _stats()
	if stats.is_empty() or index < 0 or index >= stats["incubations"].size():
		return false
	var egg: Dictionary = stats["incubations"][index]
	if not is_finite(_now()) or _now() < float(egg["hatch_at"]):
		return _fail("Звір ще не готовий вилупитися.")
	if stats["companions"].size() >= int(stats.get("pet_capacity",MAX_PETS)):
		return _fail("Немає вільних контрактів для нового звіра.")
	var id: int = int(egg["species_id"])
	var label: String = "Магічний звір"
	for entry: Dictionary in species():
		if entry["id"] == id:
			label = entry["label"]
	# Source skills are real; this species seeding is modern provisional tuning.
	var seed_skill: int = 90035 if id == 140002 else 90036 if id == 140052 else 90014
	var inherited: Array = egg.get("inherited_skills",[seed_skill]).duplicate()
	var talent_ranges: Dictionary = SourcePetCatalog.species_talent_ranges(id)
	var growth_talents: Dictionary = {}
	for stat: String in PetDevelopment.GROWTH_STATS:
		var r: Array = talent_ranges.get(stat, [10, 20])
		growth_talents[stat] = randi_range(int(r[0]), int(r[1]))
	var gender: String = "male" if randf() < 0.5 else "female"
	var personalities: Array = SourcePetCatalog.personalities().keys()
	var p_id: int = int(personalities[randi() % personalities.size()]) if not personalities.is_empty() else 190001
	var p_name: String = str(SourcePetCatalog.personality_info(p_id).get("name", "brave"))
	var max_life: float = SourcePetCatalog.lifespan_raw(id)
	var pet: Dictionary = {
		"uid": _uid(),
		"species_id": id,
		"name": label,
		"level": 1,
		"exp": 0,
		"hp": 60,
		"max_hp": 60,
		"mp": 40,
		"max_mp": 40,
		"hunger": 100,
		"born_at": _now(),
		"skills": inherited,
		"growth_talents": growth_talents,
		"gender": gender,
		"personality_id": p_id,
		"personality": p_name,
		"lifespan": max_life,
		"max_lifespan": max_life,
		"loyalty": 60,
		"growth_base_hp": 60,
		"growth_base_mp": 40,
		"growth_base_attack": 11,
		"growth_base_defense": 7,
		"growth_base_speed": 11
	}
	PetDevelopment.rebuild(pet)
	stats["companions"].append(pet)
	stats["incubations"].remove_at(index)
	changed.emit()
	feedback.emit("Вилупився новий звір: " + label)
	return true

func summon(uid: String) -> bool:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty() or int(pet["hp"]) <= 0 or int(pet["hunger"]) <= 0:
		return _fail("Цей звір не може приєднатися до тебе.")
	if float(pet.get("lifespan", 18000.0)) <= 0.0:
		return _fail("Звір досяг кінця життя і потребує омолодження.")
	if _stats()["summoned_pet"] == uid:
		return false
	ensure_mana(pet)
	_stats()["summoned_pet"] = uid
	changed.emit()
	return true

func dismiss() -> void:
	if not _stats().is_empty() and _stats().get("summoned_pet", "") != "":
		_stats()["summoned_pet"] = ""
		changed.emit()

func rename_pet(uid: String, new_name: String) -> bool:
	var pet: Dictionary = get_pet(uid)
	var clean: String = new_name.strip_edges()
	if pet.is_empty() or clean.length() < 2 or clean.length() > 24 or "\n" in clean or "\r" in clean or "\t" in clean:
		return _fail("Ім'я звіра має містити від 2 до 24 символів в одному рядку.")
	if pet["name"] == clean:
		return false
	pet["name"] = clean
	changed.emit()
	return true

func feed(uid: String, item_id: int = FOOD_ID) -> bool:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty() or item_id != FOOD_ID or int(pet["hunger"]) >= 100 or not _has_item(item_id):
		return _fail("Потрібен голодний звір і плід Біро в сумці.")
	_consume(item_id)
	pet["hunger"] = mini(100, int(pet["hunger"]) + 35)
	pet["loyalty"] = mini(100, int(pet.get("loyalty", 60)) + 10)
	changed.emit()
	return true

func heal(uid: String, item_id: int = HEAL_ID) -> bool:
	return medicate(uid,item_id)

func medicate(uid: String, item_id: int, now: float = -1.0) -> bool:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty() or int(pet["hp"]) <= 0 or int(_stats().get("hp",0)) <= 0 or not _has_item(item_id): return _fail("Потрібні живий звір і відповідне зілля.")
	var effect: Dictionary = ItemCatalog.get_item(item_id).get("effect",{})
	var group: String = MedicineState.group(effect)
	var current: float = _now() if now < 0 else now
	if effect.get("recipient") != "pet" or effect.get("type") != "restore" or not MedicineState.available(_stats(),group,current): return false
	var normalized: Dictionary = pet.duplicate(true)
	ensure_mana(normalized)
	var field: String = str(effect["stat"])
	if not _integer(normalized.get(field),0,1000000) or not _integer(normalized.get("max_"+field),1,1000000) or int(normalized[field]) >= int(normalized["max_"+field]): return false
	_consume(item_id)
	pet["mp"] = normalized["mp"]
	pet["max_mp"] = normalized["max_mp"]
	pet[field] = mini(int(normalized["max_"+field]),int(normalized[field])+int(effect["amount"]))
	MedicineState.start(_stats(),group,current)
	changed.emit()
	return true

func rejuvenate(uid: String, item_id: int = 30015) -> bool:
	# Original 30015/30988 text explicitly resets lifespan to youth and works
	# on deceased beasts. Resetting the biological clock is reversible; this
	# module never kills pets from age. Restoring a deceased pet to 1 HP is
	# provisional revival tuning, not a decoded original healing quantity.
	var pet: Dictionary = get_pet(uid)
	var now: float = _now()
	if pet.is_empty() or item_id not in [30015,30988,30989] or not _has_item(item_id) or not is_finite(now) or now < 0:
		return false
	var max_life: float = float(pet.get("max_lifespan", SourcePetCatalog.lifespan_raw(int(pet.get("species_id", 0)))))
	var current_life: float = float(pet.get("lifespan", max_life))
	if age_seconds(uid) <= 0.0 and current_life >= max_life and int(pet["hp"]) > 0:
		return _fail("Звір уже має найменший біологічний вік.")
	_consume(item_id)
	pet["born_at"] = now if item_id != 30989 else minf(now,float(pet["born_at"])+AGE_STAGE_SECONDS)
	pet["rejuvenated_at"] = pet["born_at"]
	if item_id == 30989:
		pet["lifespan"] = minf(max_life, current_life + (max_life * 0.25))
	else:
		pet["lifespan"] = max_life
	if int(pet["hp"]) <= 0:
		pet["hp"] = 1
	changed.emit()
	feedback.emit("Магічного звіра омолоджено.")
	return true

func breed(uid_a: String, uid_b: String) -> bool:
	var a: Dictionary = get_pet(uid_a)
	var b: Dictionary = get_pet(uid_b)
	if uid_a == uid_b or a.is_empty() or b.is_empty():
		return false
	if int(a["level"]) < 5 or int(b["level"]) < 5 or int(a["hunger"]) < 50 or int(b["hunger"]) < 50 or int(a["hp"]) <= 0 or int(b["hp"]) <= 0:
		return _fail("Для розведення потрібні два здорові ситі звірі від 5-го рівня.")
	if str(a.get("gender", "male")) == str(b.get("gender", "female")):
		return _fail("Для розведення потрібні звірі протилежної статі.")
	if _stats()["incubations"].size() >= MAX_INCUBATIONS or int(_stats().get("copper", 0)) < 100 or not is_finite(_now()) or _now() < 0:
		return _fail("Потрібні вільний інкубатор і 100 міді.")
	_stats()["copper"] = int(_stats()["copper"]) - 100
	a["hunger"] = int(a["hunger"]) - 20
	b["hunger"] = int(b["hunger"]) - 20
	_queue(int(a["species_id"]), 0, [uid_a, uid_b])
	var inherited: Array = a["skills"].duplicate()
	for skill: Variant in b["skills"]:
		if skill not in inherited and inherited.size() < 3:
			inherited.append(skill)
	_stats()["incubations"][-1]["inherited_skills"] = inherited
	changed.emit()
	return true

func revive(uid: String, item_id: int = 30025) -> bool:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty() or int(pet["hp"]) > 0 or item_id not in [30025,30703] or not _has_item(item_id):
		return false
	_consume(item_id)
	pet["hp"] = mini(int(pet["max_hp"]),10)
	changed.emit()
	return true

func transfer_with_runes(source_uid: String, target_uid: String, learning: int = 0, inheritance: int = 0) -> bool:
	var source: Dictionary = get_pet(source_uid)
	var target: Dictionary = get_pet(target_uid)
	if source_uid == target_uid or source.is_empty() or target.is_empty() or source["skills"].is_empty() or int(_stats().get("copper",0)) < 50:
		return false
	if _stats().get("summoned_pet","") in [source_uid,target_uid] or int(source["hp"]) <= 0 or int(target["hp"]) <= 0:
		return _fail("Спочатку відклич обох здорових звірів.")
	if (learning != 0 and (not LEARNING_RUNES.has(learning) or not _has_item(learning))) or (inheritance != 0 and (not INHERITANCE_RUNES.has(inheritance) or not _has_item(inheritance))):
		return false
	var from: int = int(INHERITANCE_RUNES[inheritance]) if inheritance != 0 else randi_range(0,source["skills"].size()-1)
	var to: int = int(LEARNING_RUNES[learning]) if learning != 0 else (randi_range(0,target["skills"].size()-1) if target["skills"].size() >= 3 else target["skills"].size())
	if from >= source["skills"].size() or to > target["skills"].size() or (learning != 0 and to >= 3) or (learning != 0 and to > target["skills"].size()):
		return _fail("Руна посилається на відсутню комірку навичок.")
	var skill: int = int(source["skills"][from])
	if skill in target["skills"]:
		return _fail("Головний звір уже знає цю навичку.")
	# Check every condition before consuming either rune or changing either pet.
	if learning != 0: _consume(learning)
	if inheritance != 0: _consume(inheritance)
	_stats()["copper"] -= 50
	source["skills"].remove_at(from)
	if to == target["skills"].size(): target["skills"].append(skill)
	else: target["skills"][to] = skill
	changed.emit()
	feedback.emit("Навичку передано.")
	return true

func combat_profile(uid: String) -> Dictionary:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty(): return {}
	var p_info: Dictionary = SourcePetCatalog.personality_info(int(pet.get("personality_id", 190001)))
	var atk_nudge: float = float(p_info.get("nudge_bonus", 0.0)) if str(p_info.get("nudge_stat", "")) == "attack" else 0.0
	var def_nudge: float = float(p_info.get("nudge_bonus", 0.0)) if str(p_info.get("nudge_stat", "")) == "defense" else 0.0
	var spd_nudge: float = float(p_info.get("nudge_bonus", 0.0)) if str(p_info.get("nudge_stat", "")) == "speed" else 0.0
	var raw_atk: float = float(pet.get("growth_base_attack", 8 + int(pet["level"]) * 3)) + (5.0 if 90023 in pet["skills"] else 0.0)
	var raw_def: float = float(pet.get("growth_base_defense", 5 + int(pet["level"]) * 2))
	var raw_spd: float = float(pet.get("growth_base_speed", 10 + int(pet["level"]) * 1))
	return {
		"attack": roundi(raw_atk * (1.0 + atk_nudge)),
		"defense": roundi(raw_def * (1.0 + def_nudge)),
		"speed": roundi(raw_spd * (1.0 + spd_nudge)),
		"accuracy": 1.0,
		"crit_rate": 0.1,
		"element": CombatFormulas.DamageType.FIRE if 90036 in pet["skills"] else CombatFormulas.DamageType.WATER if 90035 in pet["skills"] else CombatFormulas.DamageType.PHY
	}

func combat_strike(uid: String, roll: float = -1.0) -> Dictionary:
	var pet: Dictionary = get_pet(uid)
	var result: Dictionary = combat_profile(uid)
	if result.is_empty(): return result
	ensure_mana(pet)
	var loyalty: int = int(pet.get("loyalty", 60))
	if loyalty < 50:
		var chance: float = (50.0 - float(loyalty)) / 100.0
		var check_roll: float = randf() if roll < 0.0 else roll
		if check_roll < chance:
			result["disobeyed"] = true
			result["attack"] = 0
			result["accuracy"] = 0.0
			result["element"] = CombatFormulas.DamageType.PHY
			result["action"] = "ignore"
			feedback.emit("Звір проігнорував наказ атакувати через низьку відданість!")
			return result
	result["disobeyed"] = false
	# MP cost is modern tuning pending complete pet skill numeric recovery.
	if int(result["element"]) != CombatFormulas.DamageType.PHY:
		if int(pet.get("mp",0)) < 6: result["element"] = CombatFormulas.DamageType.PHY
		else:
			pet["mp"] = int(pet["mp"])-6
			changed.emit()
	return result

func transfer_skill(source_uid: String, target_uid: String, index: int) -> bool:
	var source: Dictionary = get_pet(source_uid)
	var target: Dictionary = get_pet(target_uid)
	if source_uid == target_uid or source.is_empty() or target.is_empty() or source["skills"].is_empty():
		return false
	if _stats().get("summoned_pet","") in [source_uid,target_uid] or int(source["hp"]) <= 0 or int(target["hp"]) <= 0:
		return _fail("Спочатку відклич обох здорових звірів.")
	if int(_stats().get("copper",0)) < 50:
		return _fail("Потрібно 50 міді для передачі навички.")
	if index < 0 or index >= source["skills"].size() or target["skills"].size() >= 3:
		return false
	var skill: int = int(source["skills"][index])
	if skill in target["skills"]:
		return _fail("Головний звір уже знає цю навичку.")
	_stats()["copper"] = int(_stats()["copper"]) - 50
	source["skills"].remove_at(index)
	target["skills"].append(skill)
	changed.emit()
	feedback.emit("Навичку передано.")
	return true

func transform(primary: String, donor: String, boost: int = 0, protection: int = 0, roll: float = -1.0) -> Dictionary:
	var result: Dictionary = PetDevelopment.transform(_stats(),primary,donor,boost,protection,randf() if roll < 0 else roll)
	if result.get("ok",false): changed.emit()
	feedback.emit(str(result.get("message",result.get("error",""))))
	return result

func feed_talent(uid: String, item_id: int) -> bool:
	if not PetDevelopment.feed_talent(_stats(),uid,item_id): return false
	changed.emit()
	return true

func set_tactic(uid: String, tactic: String) -> bool:
	if not PetDevelopment.change_tactic(_stats(),uid,tactic): return false
	changed.emit()
	return true

func release_pet(uid: String) -> bool:
	if _stats().get("summoned_pet", "") == uid:
		return _fail("Спочатку відклич звіра.")
	var list: Array = _stats().get("companions", [])
	for index: int in list.size():
		if list[index]["uid"] == uid:
			list.remove_at(index)
			changed.emit()
			return true
	return false

func gain_exp(uid: String, amount: int) -> bool:
	var pet: Dictionary = get_pet(uid)
	if pet.is_empty() or amount <= 0 or amount > 1000000 or int(pet["level"]) >= MAX_LEVEL:
		return false
	ensure_mana(pet)
	pet["exp"] = int(pet["exp"]) + amount
	while int(pet["level"]) < MAX_LEVEL and int(pet["exp"]) >= int(pet["level"]) * 100:
		pet["exp"] = int(pet["exp"]) - int(pet["level"]) * 100
		pet["level"] = int(pet["level"]) + 1
		PetDevelopment.level_up(pet)
	if int(pet["level"]) == MAX_LEVEL:
		pet["exp"] = 0
	changed.emit()
	return true

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or delta > 3600:
		return
	var pet: Dictionary = get_pet(str(_stats().get("summoned_pet", "")))
	if pet.is_empty():
		_hunger_seconds = 0
		return
	var current_life: float = float(pet.get("lifespan", 18000.0))
	var new_life: float = maxf(0.0, current_life - delta)
	pet["lifespan"] = new_life
	var state_changed: bool = false
	if current_life > 0.0 and new_life <= 0.0:
		_stats()["summoned_pet"] = ""
		feedback.emit("Звір досяг кінця життя і повертається на відпочинок.")
		state_changed = true
	_hunger_seconds += delta
	var loss: int = int(_hunger_seconds / 60.0)
	if loss > 0:
		_hunger_seconds -= float(loss) * 60.0
		pet["hunger"] = maxi(0, int(pet["hunger"]) - loss)
		if int(pet["hunger"]) == 0:
			_stats()["summoned_pet"] = ""
		state_changed = true
	if state_changed:
		changed.emit()

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and float(value) >= low and float(value) <= high

static func _timestamp(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 100000000000.0

func validate_state(stats: Dictionary) -> bool:
	species()
	_ensure_egg_mapping()
	if not stats.get("companions") is Array or not stats.get("incubations") is Array or not stats.get("summoned_pet") is String:
		return false
	if not _integer(stats.get("pet_capacity",MAX_PETS),1,PetDevelopment.CAPACITY_LIMIT) or stats["companions"].size() > int(stats.get("pet_capacity",MAX_PETS)) or stats["incubations"].size() > MAX_INCUBATIONS:
		return false
	var ids: Array[String] = []
	for entry: Variant in stats["companions"]:
		if not entry is Dictionary or not entry.get("uid") is String or entry["uid"].is_empty() or entry["uid"].length() > 128 or entry["uid"] in ids:
			return false
		ids.append(entry["uid"])
		if not _integer(entry.get("species_id"),140000,149999) or not _species_ids.has(int(entry["species_id"])) or not entry.get("name") is String:
			return false
		if entry["name"].strip_edges().length() < 2 or entry["name"].length() > 24 or "\n" in entry["name"] or "\r" in entry["name"] or "\t" in entry["name"]:
			return false
		if not _integer(entry.get("level"),1,MAX_LEVEL) or not _integer(entry.get("max_hp"),1,1000000) or not _integer(entry.get("hp"),0,int(entry["max_hp"])) or not _integer(entry.get("hunger"),0,100):
			return false
		if not PetDevelopment.validate(entry): return false
		if entry.has("mp") != entry.has("max_mp"): return false
		if not _integer(entry.get("max_mp",40),1,1000000) or not _integer(entry.get("mp",40),0,int(entry.get("max_mp",40))): return false
		if not _integer(entry.get("exp"),0,int(entry["level"])*100-1) or not _timestamp(entry.get("born_at")) or not entry.get("skills") is Array or entry["skills"].size() > 3:
			return false
		if entry.has("rejuvenated_at") and (not _timestamp(entry["rejuvenated_at"]) or float(entry["rejuvenated_at"]) != float(entry["born_at"])):
			return false
		var skills: Array[int] = []
		for skill: Variant in entry["skills"]:
			if not _integer(skill,1,999999) or int(skill) in skills:
				return false
			skills.append(int(skill))
	var summoned: String = stats["summoned_pet"]
	if not summoned.is_empty() and not summoned in ids:
		return false
	for entry: Variant in stats["incubations"]:
		if not entry is Dictionary or not entry.get("uid") is String or entry["uid"].is_empty() or entry["uid"].length() > 128 or entry["uid"] in ids:
			return false
		ids.append(entry["uid"])
		if not _integer(entry.get("species_id"),140000,149999) or not _species_ids.has(int(entry["species_id"])) or not _timestamp(entry.get("started_at")) or not _timestamp(entry.get("hatch_at")):
			return false
		if float(entry["hatch_at"]) < float(entry["started_at"]) + INCUBATION_SECONDS or not _integer(entry.get("egg_id"),0,999999):
			return false
		if int(entry["egg_id"]) != 0 and (not _egg_species.has(int(entry["egg_id"])) or _egg_species[int(entry["egg_id"])] != int(entry["species_id"])):
			return false
		if not entry.get("parents") is Array or entry["parents"].size() not in [0,2]:
			return false
		if entry.has("inherited_skills"):
			if not entry["inherited_skills"] is Array or entry["inherited_skills"].size() > 3: return false
			var inherited: Array[int] = []
			for skill: Variant in entry["inherited_skills"]:
				if not _integer(skill,1,999999) or int(skill) in inherited: return false
				inherited.append(int(skill))
		for parent: Variant in entry["parents"]:
			if not parent is String or parent.is_empty() or parent.length() > 128:
				return false
	return true
