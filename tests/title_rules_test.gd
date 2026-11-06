extends SceneTree

var failures: int = 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running TitleRulesTest ---")

	# 1. Rules loading and schema verification
	var rules: Dictionary = TitleSystem.rules()
	check(rules.size() == 138, "rules dictionary contains all 138 titles")
	check(TitleSystem.catalog().size() >= 137, "catalog contains all valid original titles")

	var all_provisional: bool = true
	var all_have_uk: bool = true
	var all_have_conditions: bool = true
	for id: int in rules:
		var entry: Dictionary = rules[id]
		if not entry.get("provisional", false):
			all_provisional = false
		if str(entry.get("name_uk", "")).is_empty():
			all_have_uk = false
		if not entry.has("condition") or not entry["condition"] is Dictionary:
			all_have_conditions = false

	check(all_provisional, "all title rules are marked provisional: true")
	check(all_have_uk, "all title rules have non-empty Ukrainian fantasy names")
	check(all_have_conditions, "all title rules define earning conditions")

	# 2. Translation lookups
	check(TitleSystem.label(180003) == "Воїн-початківець", "label() returns correct Ukrainian name for warrior starter")
	check(TitleSystem.label(180000) == "Винищувач курей", "label() returns Ukrainian name for chicken slayer")
	check(TitleSystem.translate_name("杀鸡专业户") == "Винищувач курей", "translate_name translates Chinese title into Ukrainian")

	# 3. Stats initialization and starter title
	var stats: Dictionary = {
		"class_id": 130001,
		"level": 1,
		"copper": 0,
	}
	TitleSystem.ensure_stats(stats)
	check(stats.has("owned_titles") and stats["owned_titles"] is Array, "ensure_stats initializes owned_titles")
	check(stats.has("titles") and stats["titles"] is Array, "ensure_stats initializes titles alias")
	check(180003 in stats["owned_titles"], "warrior starter title 180003 is granted automatically")
	check(int(stats["title_id"]) == 180003, "starter title is automatically selected when title_id was 0")
	check(stats.has("kill_counts") and stats.has("pk_kills"), "kill tracking dictionaries initialized")

	# 4. Bonuses from selected title only
	var b: Dictionary = TitleSystem.bonuses(stats)
	check(b.get("attack", 0) == 3 and b.get("max_hp", 0) == 25, "bonuses() returns bonuses for active starter title")

	TitleSystem.select(stats, 0)
	check(TitleSystem.bonuses(stats).is_empty(), "bonuses() returns empty dictionary when title_id is 0")

	# Selecting an unowned title must fail
	check(not TitleSystem.select(stats, 180001), "select() rejects unowned title")
	check(int(stats["title_id"]) == 0, "title_id remains unchanged after failed select")

	# 5. Level requirement unlock
	stats["level"] = 4
	var unlocked: Array[int] = TitleSystem.check_unlocks(stats)
	check(180018 not in unlocked and 180018 not in stats["owned_titles"], "level 5 title 180018 is locked at level 4")

	stats["level"] = 5
	unlocked = TitleSystem.check_unlocks(stats)
	check(180018 in unlocked and 180018 in stats["owned_titles"], "level 5 title 180018 unlocks at level 5")
	check(180018 in stats["titles"], "unlocked title is present in stats['titles']")

	var repeat_unlocked: Array[int] = TitleSystem.check_unlocks(stats)
	check(180018 not in repeat_unlocked, "check_unlocks does not duplicate already owned titles")

	# 6. Class progression unlock
	var mage_stats: Dictionary = {
		"class_id": 130005, # Mage
		"level": 10,
	}
	TitleSystem.ensure_stats(mage_stats)
	TitleSystem.check_unlocks(mage_stats)
	check(180004 in mage_stats["owned_titles"], "mage class at level 10 unlocks Adept Mage title 180004")

	# Warrior should not unlock Adept Mage title
	check(180004 not in stats["owned_titles"], "warrior does not unlock Adept Mage title")

	# 7. Monster kill count unlocks via record_kill
	stats["kill_counts"].clear()
	for i: int in range(99):
		TitleSystem.record_kill(stats, "chicken")
	check(180000 not in stats["owned_titles"], "chicken slayer title locked at 99 kills")
	check(int(stats["kill_counts"]["chicken"]) == 99, "kill_counts increments accurately")

	TitleSystem.record_kill(stats, "chicken")
	check(180000 in stats["owned_titles"], "chicken slayer title 180000 unlocks at 100 kills")
	check(180000 in stats["titles"], "chicken slayer title reflected in stats['titles']")

	# Test alias resolution by ID (70073 -> boar)
	TitleSystem.record_kill(stats, 70073)
	check(int(stats["kill_counts"]["boar"]) >= 1, "record_kill with monster ID 70073 syncs to boar alias")

	# 8. PK kills tracking and unlock
	check(int(stats["pk_kills"]) == 0, "pk_kills starts at 0")
	for i: int in range(9):
		TitleSystem.record_kill(stats, "player")
	check(180016 not in stats["owned_titles"], "villain title locked at 9 PK kills")

	TitleSystem.record_kill(stats, "player")
	check(int(stats["pk_kills"]) == 10, "pk_kills increments to 10")
	check(180016 in stats["owned_titles"], "villain title 180016 unlocks at 10 PK kills")

	# 9. Pet count unlock
	stats["pets"] = [{"id": 30001}]
	unlocked = TitleSystem.check_unlocks(stats)
	check(180076 in unlocked and 180076 in stats["owned_titles"], "pet count 1 unlocks title 180076")

	stats["pets"] = [{"id": 30001}, {"id": 30002}, {"id": 30003}]
	unlocked = TitleSystem.check_unlocks(stats)
	check(180083 in unlocked and 180083 in stats["owned_titles"], "pet count 3 unlocks title 180083")

	# 10. Copper unlock
	stats["copper"] = 49999
	unlocked = TitleSystem.check_unlocks(stats)
	check(180023 not in stats["owned_titles"], "baron title 180023 locked below 50000 copper")

	stats["copper"] = 50000
	unlocked = TitleSystem.check_unlocks(stats)
	check(180023 in unlocked and 180023 in stats["owned_titles"], "baron title 180023 unlocks at 50000 copper")

	# 11. Quest completion unlock
	stats["completed_quests"] = [80011]
	unlocked = TitleSystem.check_unlocks(stats)
	check(180014 in unlocked and 180014 in stats["owned_titles"], "quest 80011 unlocks title 180014")

	# Test quest dictionary format
	stats["quests"] = {
		"80098": {"state": 4} # QuestData.QuestState.DONE
	}
	unlocked = TitleSystem.check_unlocks(stats)
	check(180015 in unlocked and 180015 in stats["owned_titles"], "quest 80098 in quests dict unlocks title 180015")

	# 12. Manual titles cannot be auto-unlocked
	check(180057 not in stats["owned_titles"], "manual event title 180057 remains locked")
	check(10000001 not in stats["owned_titles"], "manual empty title 10000001 remains locked")

	# 13. Profile validation
	check(TitleSystem.validate(stats), "valid stats dictionary passes validate()")

	var invalid_stats: Dictionary = stats.duplicate(true)
	invalid_stats["owned_titles"] = [99999999] # unknown title ID
	check(not TitleSystem.validate(invalid_stats), "validate() rejects unknown title ID")

	invalid_stats = stats.duplicate(true)
	invalid_stats["title_id"] = 999999 # not owned
	check(not TitleSystem.validate(invalid_stats), "validate() rejects selecting unowned title_id")

	invalid_stats = stats.duplicate(true)
	invalid_stats["owned_titles"] = [180003, 180003] # duplicates
	check(not TitleSystem.validate(invalid_stats), "validate() rejects duplicate title IDs")

	# 14. Title switching and bonus application
	TitleSystem.select(stats, 180023) # Baron
	check(int(stats["title_id"]) == 180023, "selected Baron title")
	var baron_bonuses: Dictionary = TitleSystem.bonuses(stats)
	check(baron_bonuses.get("max_hp", 0) == 40 and baron_bonuses.get("max_mp", 0) == 40, "Baron bonuses applied correctly")

	print("--- TitleRulesTest finished with %d failure(s) ---" % failures)
	print("TITLE_RULES_SUITE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
