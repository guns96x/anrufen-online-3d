class_name ProgressionController
extends Node

signal quest_accepted(quest_id: int)
signal quest_progress_updated(quest_id: int, current: int, required: int)
signal quest_completed(quest_id: int, exp_reward: int, attack_bonus: int)
signal save_completed(success: bool)
signal save_loaded(success: bool)

const DEFAULT_SAVE_PATH: String = "user://guanlin_v2.json"
const SAVE_VERSION: int = 6
var quest_states: Dictionary = {}
var quest_kills: Dictionary = {}
var completed_rewards: Array[int] = []
var legacy_report_credits: Array[int] = []
var active_quest_id: int = 0
var player_ref: Node
var save_file_path: String = DEFAULT_SAVE_PATH
var auto_save_enabled: bool = true
var is_corrupt_save_detected: bool = false
var _last_citizen_id: int = 0
var _mutating: bool = false

func _init(custom_save_path: String = "") -> void:
	save_file_path = custom_save_path if not custom_save_path.is_empty() else HeroSlots.path(HeroSlots.active)
	_init_default_quests()

func _ready() -> void:
	var timer: Timer = Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(_save_if_enabled)
	add_child(timer)
	timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_if_enabled()

func _save_if_enabled() -> void:
	if auto_save_enabled and not _mutating and not is_corrupt_save_detected:
		save_to_file()

func _init_default_quests() -> void:
	quest_states.clear()
	quest_kills.clear()
	completed_rewards.clear()
	legacy_report_credits.clear()
	active_quest_id = 0
	for qid: int in QuestData.DEFINITIONS:
		quest_states[qid] = QuestData.QuestState.LOCKED
		quest_kills[qid] = 0
	refresh_available_quests()

func _stats() -> Dictionary:
	if is_instance_valid(player_ref) and player_ref.get("stats") is Dictionary:
		return player_ref.get("stats")
	return {}

func bind_player(player: Node) -> void:
	if player == null or player == player_ref:
		return
	player_ref = player
	var stats: Dictionary = _stats()
	_initialize_profile_fields(stats)
	if not stats.has("copper"):
		stats["copper"] = QuestData.PROVISIONAL_INITIAL_COPPER
	if not stats.has("inventory"):
		stats["inventory"] = {}
	if NewHero.apply(stats, save_file_path):
		_save_if_enabled()
	elif auto_save_enabled:
		if FileAccess.file_exists(save_file_path):
			load_from_file()
		elif FileAccess.file_exists(save_file_path + ".bak"):
			load_from_file(save_file_path + ".bak")
	if player.has_signal("leveled_up") and not player.is_connected("leveled_up",_on_level_up):
		player.connect("leveled_up", _on_level_up)
	if player.has_signal("respawned") and not player.is_connected("respawned",_save_if_enabled):
		player.connect("respawned", _save_if_enabled)
	refresh_available_quests()

func _initialize_profile_fields(stats: Dictionary) -> void:
	CharacterSystem.ensure_stats(stats)
	TitleSystem.ensure_stats(stats)
	MountSystem.ensure_stats(stats)
	var defaults: Dictionary = {"warehouse": {}, "warehouse_capacity": 64, "regeneration_effects": [], "locked_items": [], "companions": [], "incubations": [], "summoned_pet": "", "starter_supplies_granted": false}
	defaults["pet_capacity"] = CompanionSystem.MAX_PETS
	for key: String in defaults:
		if not stats.has(key):
			stats[key] = defaults[key]

func _on_level_up(_level: int) -> void:
	refresh_available_quests()
	# Player can emit several level-ups in one gain_exp call. Save once the
	# entire operation has settled, never an intermediate exp >= threshold.
	call_deferred("_save_if_enabled")

func refresh_available_quests() -> void:
	for qid: int in QuestData.get_ordered_quest_ids():
		if quest_states.get(qid) != QuestData.QuestState.LOCKED:
			continue
		var available: bool = true
		for required: int in QuestData.DEFINITIONS[qid].get("prerequisites", []):
			var state: int = quest_states.get(required, QuestData.QuestState.LOCKED)
			if required == 80005:
				available = available and state in [QuestData.QuestState.ACTIVE, QuestData.QuestState.READY, QuestData.QuestState.DONE]
			else:
				available = available and state == QuestData.QuestState.DONE
		if available:
			quest_states[qid] = QuestData.QuestState.AVAILABLE
	for qid: int in QuestData.DEFINITIONS:
		var required_items: Dictionary = QuestData.DEFINITIONS[qid].get("required_items",{})
		if required_items.is_empty() or quest_states[qid] not in [QuestData.QuestState.ACTIVE,QuestData.QuestState.READY]: continue
		var count: int = 0
		for key: String in required_items:
			count += mini(int(required_items[key]),int(_stats().get("inventory",{}).get(key,0)))
		quest_kills[qid] = count
		quest_states[qid] = QuestData.QuestState.READY if count == int(QuestData.DEFINITIONS[qid]["required"]) else QuestData.QuestState.ACTIVE
	if quest_states.get(80005) in [QuestData.QuestState.ACTIVE,QuestData.QuestState.READY]:
		var reports: int = 0
		for qid: int in QuestData.REPORT_ITEMS:
			var item: int = QuestData.REPORT_ITEMS[qid]
			if quest_states[qid] == QuestData.QuestState.DONE and (int(_stats().get("inventory",{}).get(str(item),0)) > 0 or item in legacy_report_credits):
				reports += 1
		quest_kills[80005] = reports
		quest_states[80005] = QuestData.QuestState.READY if reports == 3 and int(_stats().get("level",1)) >= 8 else QuestData.QuestState.ACTIVE

func accept_quest(qid: int) -> bool:
	if quest_states.get(qid) != QuestData.QuestState.AVAILABLE:
		return false
	quest_states[qid] = QuestData.QuestState.ACTIVE
	active_quest_id = qid
	refresh_available_quests()
	quest_accepted.emit(qid)
	_save_if_enabled()
	return true

func add_monster_kill(monster_id: int) -> Array[int]:
	var ready: Array[int] = []
	var changed: bool = false
	for qid: int in QuestData.DEFINITIONS:
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		if quest_states[qid] == QuestData.QuestState.ACTIVE and monster_id in q.get("targets", []):
			quest_kills[qid] = mini(int(q["required"]), int(quest_kills[qid]) + 1)
			changed = true
			if quest_kills[qid] == int(q["required"]):
				quest_states[qid] = QuestData.QuestState.READY
				ready.append(qid)
			quest_progress_updated.emit(qid, quest_kills[qid], q["required"])
	if changed:
		_save_if_enabled()
	return ready

func has_sword() -> bool:
	return int(_stats().get("inventory", {}).get(str(QuestData.ITEM_LONGSWORD_ID), 0)) > 0

func buy_sword() -> bool:
	var stats: Dictionary = _stats()
	if _last_citizen_id != QuestData.NPC_WEAPONSMITH_ID or quest_states[80591] != QuestData.QuestState.ACTIVE or has_sword() or stats.is_empty():
		return false
	var price: int = QuestData.PROVISIONAL_SWORD_PRICE_COPPER
	if int(stats.get("copper", 0)) < price:
		return false
	var inventory: InventorySystem = InventorySystem.new()
	inventory.bind_player(player_ref)
	if not inventory.can_add(QuestData.ITEM_LONGSWORD_ID,1):
		return false
	stats["copper"] -= price
	stats["inventory"][str(QuestData.ITEM_LONGSWORD_ID)] = 1
	_save_if_enabled()
	return true

func complete_quest(qid: int, citizen_id: int = 0) -> Dictionary:
	var result: Dictionary = {"success": false, "already_claimed": completed_rewards.has(qid), "exp": 0, "attack_bonus": 0, "copper": 0}
	if not QuestData.DEFINITIONS.has(qid) or completed_rewards.has(qid) or _stats().is_empty():
		return result
	var q: Dictionary = QuestData.DEFINITIONS[qid]
	refresh_available_quests()
	var citizen: int = _last_citizen_id if citizen_id == 0 else citizen_id
	if quest_states[qid] != QuestData.QuestState.READY or citizen != int(q["turnin_id"]):
		return result
	var consumed: Dictionary = required_items(qid)
	for key: String in consumed:
		if int(key) in _stats().get("locked_items",[]):
			result["error"] = "Зніми замок із предметів для передачі."
			return result
	var plan: Dictionary = OriginalQuestCatalog.reward_inventory(_stats(),qid,consumed)
	if plan.is_empty():
		result["error"] = "Звільни місце в сумці для всієї винагороди."
		return result
	_mutating = true
	var stats: Dictionary = _stats()
	for field: String in ["inventory","copper","owned_titles"]:
		stats[field] = plan[field]
	if qid == 80005: legacy_report_credits.clear()
	quest_states[qid] = QuestData.QuestState.DONE
	completed_rewards.append(qid)
	player_ref.gain_exp(int(plan["exp"]))
	refresh_available_quests()
	_mutating = false
	result.merge({"success": true, "exp": int(plan["exp"]), "copper": int(q["copper"])}, true)
	quest_completed.emit(qid, int(plan["exp"]), 0)
	_save_if_enabled()
	return result

func _citizen(npc: Node) -> int:
	var explicit_id: Variant = npc.get("citizen_id")
	if explicit_id is int and explicit_id > 0:
		return explicit_id
	var qid: int = int(npc.get("quest_id")) if npc.get("quest_id") != null else 0
	return {80001: 50164, 80002: 50166, 80003: 50179}.get(qid, 0)

func _can_deliver(qid: int) -> bool:
	return qid in [80004, 80552] or (qid == 80591 and has_sword())

func required_items(qid: int) -> Dictionary:
	var result: Dictionary = QuestData.DEFINITIONS.get(qid,{}).get("required_items",{}).duplicate()
	if qid == 80591: result[str(QuestData.ITEM_LONGSWORD_ID)] = 1
	if qid == 80005:
		for item: int in QuestData.REPORT_ITEMS.values():
			if item not in legacy_report_credits: result[str(item)] = 1
	return result

func quest_item_locks() -> Array[int]:
	var result: Array[int] = []
	for qid: int in QuestData.DEFINITIONS:
		if quest_states[qid] not in [QuestData.QuestState.ACTIVE,QuestData.QuestState.READY]: continue
		for key: String in required_items(qid):
			if int(key) not in result: result.append(int(key))
	return result

func get_npc_interaction(npc: Node) -> Dictionary:
	_last_citizen_id = _citizen(npc)
	refresh_available_quests()
	var result: Dictionary = {"speaker": str(npc.get("npc_name")), "text": "Вітаю, мандрівнику.", "quest_id": 0, "action": "none", "action_button_text": "", "close_button_text": "Закрити"}
	for qid: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		if int(q["turnin_id"]) != _last_citizen_id:
			continue
		if quest_states[qid] == QuestData.QuestState.ACTIVE and _can_deliver(qid):
			quest_states[qid] = QuestData.QuestState.READY
			quest_kills[qid] = 1
			_save_if_enabled()
		if quest_states[qid] == QuestData.QuestState.READY:
			result.merge({"quest_id": qid, "text": q["ready_text"], "action": "complete", "action_button_text": "Завершити · +%d досвіду" % q["exp"]}, true)
			return result
	for qid: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		if int(q["giver_id"]) == _last_citizen_id and quest_states[qid] == QuestData.QuestState.AVAILABLE:
			result.merge({"quest_id": qid, "text": q["offer_text"], "action": "accept", "action_button_text": "Прийняти доручення", "close_button_text": "Пізніше"}, true)
			return result
	if _last_citizen_id == QuestData.NPC_WEAPONSMITH_ID and quest_states[80591] == QuestData.QuestState.ACTIVE and not has_sword():
		result.merge({"quest_id": 80591, "text": "Довгий меч для старости коштує %d міді.\nУ тебе: %d міді." % [QuestData.PROVISIONAL_SWORD_PRICE_COPPER, _stats().get("copper", 0)], "action": "buy", "action_button_text": "Купити меч · %d міді" % QuestData.PROVISIONAL_SWORD_PRICE_COPPER}, true)
		return result
	for qid: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		if int(q["giver_id"]) == _last_citizen_id or int(q["turnin_id"]) == _last_citizen_id:
			if quest_states[qid] == QuestData.QuestState.ACTIVE:
				result.merge({"quest_id": qid, "text": q["progress_text"]}, true)
				if not q.get("targets", []).is_empty() or not q.get("required_items",{}).is_empty():
					result["text"] += "\n%d / %d" % [quest_kills[qid], q["required"]]
				if qid == 80005:
					result["text"] += "\nЗвіти: %d/3 · Рівень: %d/8" % [quest_kills[qid], _stats().get("level", 1)]
				return result
			if quest_states[qid] == QuestData.QuestState.DONE:
				result["text"] = q["done_text"]
	return result

func get_npc_marker(npc: Node) -> String:
	var citizen: int = _citizen(npc)
	for qid: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		if q["turnin_id"] == citizen and (quest_states[qid] == QuestData.QuestState.READY or (quest_states[qid] == QuestData.QuestState.ACTIVE and _can_deliver(qid))):
			return "?"
	for qid: int in QuestData.DEFINITIONS:
		if QuestData.DEFINITIONS[qid]["giver_id"] == citizen and quest_states[qid] == QuestData.QuestState.AVAILABLE:
			return "!"
	return ""

func get_hud_quest_state(qid: int) -> int:
	var mapped: int = QuestData.DEMO_QUEST_MAP.get(qid, qid)
	return {QuestData.QuestState.LOCKED: 1, QuestData.QuestState.AVAILABLE: 0, QuestData.QuestState.ACTIVE: 1, QuestData.QuestState.READY: 2, QuestData.QuestState.DONE: 3}.get(quest_states.get(mapped), 1)

static func _integer(value: Variant, low: int, high: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return is_finite(number) and number == floor(number) and number >= low and number <= high

func upgrade_envelope(input: Dictionary) -> Dictionary:
	var data: Dictionary = input.duplicate(true)
	if not _integer(data.get("version"),2,SAVE_VERSION) or not data.get("quests") is Dictionary or not data.get("player_stats") is Dictionary: return {}
	ProfileCodec.normalize(data["player_stats"])
	var quests: Dictionary = data["quests"]
	if not data.has("quest_revision"):
		# Only the exact old seven-record schema can receive migration credits.
		if quests.size() == QuestData.LEGACY_IDS.size():
			for id: int in QuestData.LEGACY_IDS:
				if not quests.get(str(id)) is Dictionary: return {}
			var credits: Array = []
			if quests["80005"].get("state",0) != QuestData.QuestState.DONE:
				for id: int in QuestData.REPORT_ITEMS:
					if quests[str(id)].get("state") == QuestData.QuestState.DONE: credits.append(QuestData.REPORT_ITEMS[id])
			data["legacy_report_credits"] = credits
			for id: int in QuestData.DEFINITIONS:
				if not quests.has(str(id)): quests[str(id)] = {"state":QuestData.QuestState.LOCKED,"kills":0}
			if quests["80004"].get("state") == QuestData.QuestState.DONE and data["player_stats"].get("owned_titles") is Array:
				if 180049 not in data["player_stats"]["owned_titles"]: data["player_stats"]["owned_titles"].append(180049)
		elif int(data["version"]) >= SAVE_VERSION:
			return {}
		data["quest_revision"] = 1
	if not data.has("legacy_report_credits"): data["legacy_report_credits"] = []
	return data

func validate_save_data(input: Dictionary) -> bool:
	var data: Dictionary = upgrade_envelope(input)
	if data.is_empty() or data.get("quest_revision") != 1: return false
	if not _integer(data.get("version"), 2, SAVE_VERSION):
		return false
	if not data.get("player_stats") is Dictionary or not data.get("quests") is Dictionary or not data.get("completed_rewards") is Array:
		return false
	var ps: Dictionary = data["player_stats"].duplicate(true)
	if int(data["version"]) < SAVE_VERSION:
		_migrate_profile(ps)
		if not ps.has("equipment"):
			ps["equipment"] = {}
		if not ps.has("bag_capacity"):
			ps["bag_capacity"] = 32
	for field: String in ["level", "max_hp", "exp_to_next", "attack"]:
		if not _integer(ps.get(field), 1, 1000000000000000):
			return false
	for field: String in ["hp", "mp", "max_mp", "exp", "defense", "copper"]:
		if not _integer(ps.get(field), 0, 1000000000000000):
			return false
	if int(ps["level"]) > 100 or int(ps["hp"]) > int(ps["max_hp"]) or int(ps["mp"]) > int(ps["max_mp"]) or int(ps["exp"]) >= int(ps["exp_to_next"]):
		return false
	for field: String in ["crit_rate", "accuracy", "evasion"]:
		var v: Variant = ps.get(field)
		if (typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT) or not is_finite(float(v)) or float(v) < 0.0 or float(v) > 1.0:
			return false
	if not _integer(ps.get("element"), 1, 5) or not ps.get("inventory") is Dictionary:
		return false
	var item_validator: InventorySystem = InventorySystem.new()
	var pet_validator: CompanionSystem = CompanionSystem.new()
	if not item_validator.validate_state(ps) or not pet_validator.validate_state(ps) or not CharacterSystem.validate(ps) or not GameServices.validate(ps) or not MountSystem.validate(ps) or not ItemEffects.validate(ps) or not TitleSystem.validate(ps):
		return false
	if not ps.get("starter_supplies_granted") is bool:
		return false
	for field: String in ["name", "class_name"]:
		if not ps.get(field) is String or ps[field].length() > 100:
			return false
	var qdict: Dictionary = data["quests"]
	if qdict.size() != QuestData.DEFINITIONS.size():
		return false
	var rewards: Array = data["completed_rewards"]
	if not data.get("legacy_report_credits") is Array or data["legacy_report_credits"].size() > 3: return false
	var credits: Array[int] = []
	for value: Variant in data["legacy_report_credits"]:
		if not _integer(value,1,999999) or int(value) not in QuestData.REPORT_ITEMS.values() or int(value) in credits: return false
		credits.append(int(value))
	var seen: Array[int] = []
	for item: Variant in rewards:
		if not _integer(item, 1, 999999) or not QuestData.DEFINITIONS.has(int(item)) or int(item) in seen:
			return false
		seen.append(int(item))
	for qid: int in QuestData.DEFINITIONS:
		var entry: Variant = qdict.get(str(qid))
		if not entry is Dictionary or not _integer(entry.get("state"), 0, 4) or not _integer(entry.get("kills"), 0, int(QuestData.DEFINITIONS[qid]["required"])):
			return false
	for credit: int in credits:
		var witness: int = QuestData.REPORT_ITEMS.find_key(credit)
		if int(qdict[str(witness)]["state"]) != QuestData.QuestState.DONE or int(qdict["80005"]["state"]) == QuestData.QuestState.DONE: return false
	for qid: int in QuestData.DEFINITIONS:
		var entry: Dictionary = qdict[str(qid)]
		var state: int = int(entry["state"])
		if (state == QuestData.QuestState.DONE) != (qid in seen):
			return false
		if state in [QuestData.QuestState.READY, QuestData.QuestState.DONE] and int(entry["kills"]) != int(QuestData.DEFINITIONS[qid]["required"]):
			return false
		if qid == 80591 and state == QuestData.QuestState.READY and int(ps["inventory"].get(str(QuestData.ITEM_LONGSWORD_ID), 0)) != 1:
			return false
		if not QuestData.DEFINITIONS[qid].get("targets", []).is_empty() and state == QuestData.QuestState.ACTIVE and int(entry["kills"]) == int(QuestData.DEFINITIONS[qid]["required"]):
			return false
		if state != QuestData.QuestState.LOCKED:
			for prereq: int in QuestData.DEFINITIONS[qid].get("prerequisites", []):
				var parent: int = int(qdict[str(prereq)]["state"])
				if (prereq == 80005 and parent < QuestData.QuestState.ACTIVE) or (prereq != 80005 and parent != QuestData.QuestState.DONE):
					return false
	if int(qdict["80005"]["state"]) >= QuestData.QuestState.READY:
		if int(ps["level"]) < 8:
			return false
		for qid: int in [80006, 80010, 80012]:
			if int(qdict[str(qid)]["state"]) != QuestData.QuestState.DONE:
				return false
	return _integer(data.get("active_quest_id", 0), 0, 999999) and (int(data.get("active_quest_id", 0)) == 0 or QuestData.DEFINITIONS.has(int(data["active_quest_id"])))

func save_to_file(path: String = "") -> bool:
	if is_corrupt_save_detected or _stats().is_empty():
		return false
	var target: String = save_file_path if path.is_empty() else path
	var quests_dump: Dictionary = {}
	for qid: int in QuestData.DEFINITIONS:
		quests_dump[str(qid)] = {"state": quest_states[qid], "kills": quest_kills[qid]}
	var data: Dictionary = {"version": SAVE_VERSION,"quest_revision":1,"legacy_report_credits":legacy_report_credits, "player_stats": _stats().duplicate(true), "quests": quests_dump, "completed_rewards": completed_rewards, "active_quest_id": active_quest_id}
	if not validate_save_data(data):
		return false
	var file: FileAccess = FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	var old_exists: bool = FileAccess.file_exists(target)
	if old_exists:
		if FileAccess.file_exists(target + ".bak"):
			DirAccess.remove_absolute(target + ".bak")
		if DirAccess.rename_absolute(target, target + ".bak") != OK:
			return false
	var err: Error = DirAccess.rename_absolute(target + ".tmp", target)
	if err != OK and old_exists:
		DirAccess.rename_absolute(target + ".bak", target)
	save_completed.emit(err == OK)
	return err == OK

func journal_snapshot() -> Dictionary:
	var rows: Dictionary = {}
	for qid: int in QuestData.DEFINITIONS:
		rows[str(qid)] = {"state":quest_states[qid],"kills":quest_kills[qid]}
	return {"quest_revision":1,"legacy_report_credits":legacy_report_credits.duplicate(),"quests":rows,"completed_rewards":completed_rewards.duplicate(),"active_quest_id":active_quest_id}

func apply_journal(data: Dictionary) -> bool:
	var envelope: Dictionary = data.duplicate(true)
	envelope["version"] = SAVE_VERSION
	envelope["player_stats"] = _stats()
	envelope = upgrade_envelope(envelope)
	if not validate_save_data(envelope):
		return false
	completed_rewards.clear()
	for value: Variant in envelope["completed_rewards"]:
		completed_rewards.append(int(value))
	legacy_report_credits.clear()
	for value: Variant in envelope["legacy_report_credits"]: legacy_report_credits.append(int(value))
	for qid: int in QuestData.DEFINITIONS:
		quest_states[qid] = int(envelope["quests"][str(qid)]["state"])
		quest_kills[qid] = int(envelope["quests"][str(qid)]["kills"])
	active_quest_id = int(envelope.get("active_quest_id",0))
	_stats()["owned_titles"] = envelope["player_stats"].get("owned_titles",[])
	refresh_available_quests()
	return true

func load_from_file(path: String = "") -> bool:
	var target: String = save_file_path if path.is_empty() else path
	if not FileAccess.file_exists(target) or _stats().is_empty():
		return false
	var file: FileAccess = FileAccess.open(target, FileAccess.READ)
	if file == null:
		return false
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	var parsed: Variant = parser.data if error == OK else null
	file.close()
	if not parsed is Dictionary or not validate_save_data(parsed):
		is_corrupt_save_detected = true
		save_loaded.emit(false)
		push_warning("Збереження пошкоджене. Оригінал збережено: " + target)
		return false
	var data: Dictionary = upgrade_envelope(parsed)
	if int(data["version"]) < SAVE_VERSION:
		var backups: Array[String] = [target+".pre-v6"]
		if int(data["version"]) < 5: backups.append(target+".pre-v5")
		for backup: String in backups:
			if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(target,backup) != OK:
				is_corrupt_save_detected = true
				save_loaded.emit(false)
				return false
		_migrate_profile(data["player_stats"])
	completed_rewards.clear()
	for value: Variant in data["completed_rewards"]:
		completed_rewards.append(int(value))
	legacy_report_credits.clear()
	for value: Variant in data["legacy_report_credits"]: legacy_report_credits.append(int(value))
	for qid: int in QuestData.DEFINITIONS:
		quest_states[qid] = int(data["quests"][str(qid)]["state"])
		quest_kills[qid] = int(data["quests"][str(qid)]["kills"])
	active_quest_id = int(data["active_quest_id"])
	var stats: Dictionary = _stats()
	for key: String in data["player_stats"]:
		if stats.has(key):
			var value: Variant = data["player_stats"][key]
			stats[key] = int(value) if typeof(stats[key]) == TYPE_INT else value
	ProfileCodec.normalize(stats)
	if int(stats["hp"]) <= 0:
		stats["hp"] = stats["max_hp"]
	refresh_available_quests()
	save_loaded.emit(true)
	return true

func _migrate_profile(stats: Dictionary) -> void:
	ProfileCodec.normalize(stats)
	if stats.get("companions") is Array:
		for pet: Variant in stats["companions"]:
			if pet is Dictionary: PetDevelopment.ensure_pet(pet)
	if not stats.has("free_starter_skill"):
		var starter: int = 90122 if int(stats.get("class_id",130001)) in [130002,130005,130008,130009] else 90020
		stats["free_starter_skill"] = starter if not stats.has("skills") or stats.get("skills",{}).has(str(starter)) else 0
	var level: int = int(stats.get("level",1))
	if not stats.has("stat_points"):
		stats["stat_points"] = maxi(0,(level-1)*3)
	if not stats.has("skill_points"):
		stats["skill_points"] = maxi(1,level)
	_initialize_profile_fields(stats)
