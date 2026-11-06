extends SceneTree

var failures: int = 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Location 2 (Benma City) Data Tests ---")
	test_layout()
	test_spawns()
	test_quests_and_citizens()
	test_monsters_and_encounters()
	test_navigation_reachability()
	print("LOCATION2_DATA_SUITE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func test_layout() -> void:
	check(BenmaLayout.TILE > 0.0, "BenmaLayout tile size is positive")
	check(BenmaLayout.BOUNDS_MIN.x < BenmaLayout.BOUNDS_MAX.x and BenmaLayout.BOUNDS_MIN.y < BenmaLayout.BOUNDS_MAX.y, "Layout bounds form valid rectangle")
	check(BenmaLayout.CITIZENS.size() == 31, "Layout contains exactly 31 citizens from original scene 120056")
	check(BenmaLayout.HOUSES.size() >= 8, "Layout defines architectural building groups")
	check(BenmaLayout.ROADS.size() >= 3, "Layout defines main road arteries")
	check(BenmaLayout.STALLS.size() >= 3, "Layout defines market stall canopies")
	check(BenmaLayout.PALISADE.size() >= 4, "Layout defines boundary palisade walls")

	var player_spawn: Vector3 = BenmaLayout.PLAYER_SPAWN
	check(player_spawn.x >= BenmaLayout.BOUNDS_MIN.x and player_spawn.x <= BenmaLayout.BOUNDS_MAX.x, "Player spawn X inside bounds")
	check(player_spawn.z >= BenmaLayout.BOUNDS_MIN.y and player_spawn.z <= BenmaLayout.BOUNDS_MAX.y, "Player spawn Z inside bounds")
	check(not BenmaLayout.blocks(Vector2(player_spawn.x, player_spawn.z)), "Player spawn is not inside a blocked obstacle")

	# Test tile to world round-trip
	var test_tiles: Array[Vector2i] = [Vector2i(28, 20), Vector2i(17, 25), Vector2i(29, 18), Vector2i(42, 22)]
	var round_trip_ok: bool = true
	for t: Vector2i in test_tiles:
		var world_pos: Vector3 = BenmaLayout.tile_to_world(t)
		var back_tile: Vector2i = BenmaLayout.world_to_tile(world_pos)
		if back_tile != t:
			round_trip_ok = false
			break
	check(round_trip_ok, "Tile to world coordinate transformation is bijective and reversible")

	var citizens_valid: bool = true
	var citizen_ids: Dictionary = {}
	for c: Array in BenmaLayout.CITIZENS:
		var cid: int = int(c[0])
		var role: String = str(c[1])
		var pos: Vector3 = c[2]
		var archetype: String = str(c[3])

		if cid <= 50000 or role.is_empty() or archetype.is_empty():
			citizens_valid = false
		if pos.x < BenmaLayout.BOUNDS_MIN.x or pos.x > BenmaLayout.BOUNDS_MAX.x:
			citizens_valid = false
		if pos.z < BenmaLayout.BOUNDS_MIN.y or pos.z > BenmaLayout.BOUNDS_MAX.y:
			citizens_valid = false
		if BenmaLayout.blocks(Vector2(pos.x, pos.z)):
			citizens_valid = false
		citizen_ids[cid] = true

	check(citizens_valid, "All 31 citizens have valid roles, archetypes and stand within bounds without obstacle collisions")
	check(citizen_ids.has(50186), "City Lord 50186 exists among citizens")
	check(citizen_ids.has(50188), "Royal Knight Envoy 50188 exists among citizens")
	check(citizen_ids.has(50187), "Orc Guard Captain 50187 exists among citizens")
	check(citizen_ids.has(50189), "Gnome Caravan Leader 50189 exists among citizens")

func test_spawns() -> void:
	check(BenmaSpawns.ENCOUNTERS.size() >= 12, "BenmaSpawns contains sufficient encounter spawns")
	var encounters_valid: bool = true
	for entry: Array in BenmaSpawns.ENCOUNTERS:
		var node_name: String = str(entry[0])
		var mid: int = int(entry[1])
		var pos: Vector3 = entry[2]
		var role: String = str(entry[3])
		var level: int = int(entry[4])
		var dname: String = str(entry[5])

		if node_name.is_empty() or mid <= 0 or role.is_empty() or level <= 0 or dname.is_empty():
			encounters_valid = false
		if not BenmaSpawns.SPEEDS.has(role):
			encounters_valid = false
		if pos.x < BenmaLayout.BOUNDS_MIN.x or pos.x > BenmaLayout.BOUNDS_MAX.x:
			encounters_valid = false
		if pos.z < BenmaLayout.BOUNDS_MIN.y or pos.z > BenmaLayout.BOUNDS_MAX.y:
			encounters_valid = false

		var formatted: String = BenmaSpawns.display_name(entry)
		if not formatted.contains(dname) or not formatted.contains(str(level)):
			encounters_valid = false

	check(encounters_valid, "All encounters have valid names, roles, positions, speeds and formatted titles")

func test_quests_and_citizens() -> void:
	var file_path: String = "res://data/benma_quests.json"
	check(FileAccess.file_exists(file_path), "Quests file res://data/benma_quests.json exists")

	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	check(file != null, "Quests file opens successfully")
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	check(err == OK, "Quests file parses as valid JSON")

	var quests: Variant = json.data
	check(quests is Array, "Quests root is an Array")
	var quest_array: Array = quests as Array
	check(quest_array.size() >= 9, "Quests array contains all 9 Benma story quests")

	var citizen_ids: Dictionary = {}
	for c: Array in BenmaLayout.CITIZENS:
		citizen_ids[int(c[0])] = true

	var required_quests: Array[int] = [80051, 80052, 80053, 80054, 80055, 80056, 80058, 80705, 80706]
	var found_quest_ids: Dictionary = {}

	var all_givers_valid: bool = true
	var all_texts_valid: bool = true
	var all_rewards_valid: bool = true

	for q_var: Variant in quest_array:
		var q: Dictionary = q_var as Dictionary
		var qid: int = int(q.get("id", 0))
		found_quest_ids[qid] = true

		var giver_id: int = int(q.get("giver_id", 0))
		var giver_scene: int = int(q.get("giver_scene", 0))
		var turnin_id: int = int(q.get("turnin_id", 0))
		var turnin_scene: int = int(q.get("turnin_scene", 0))

		# Validate giver presence
		if giver_scene == 120056:
			if not citizen_ids.has(giver_id):
				all_givers_valid = false
		elif giver_scene == 120005:
			# Guanlin transfer quest 80051
			if giver_id != 50164:
				all_givers_valid = false
		else:
			all_givers_valid = false

		# Validate turnin presence
		if turnin_scene == 120056:
			if not citizen_ids.has(turnin_id):
				all_givers_valid = false

		# Validate Ukrainian text fields
		var title_uk: String = str(q.get("title_uk", ""))
		var offer_text: String = str(q.get("offer_text", ""))
		var done_text: String = str(q.get("done_text", ""))
		if title_uk.is_empty() or offer_text.is_empty() or done_text.is_empty():
			all_texts_valid = false

		# Validate rewards
		var rewards: Dictionary = q.get("rewards", {})
		if int(rewards.get("exp", 0)) <= 0 or int(rewards.get("copper", 0)) <= 0:
			all_rewards_valid = false
		if not rewards.has("items") or not (rewards.get("items") is Array):
			all_rewards_valid = false
		
		# Specific item rewards validation against original quest_rules
		var items: Array = rewards.get("items", [])
		if qid == 80054:
			var has_badge: bool = false
			var has_potion: bool = false
			for it_var: Variant in items:
				var it: Dictionary = it_var as Dictionary
				if int(it.get("id", 0)) == 30099 and int(it.get("count", 0)) == 1:
					has_badge = true
				if int(it.get("id", 0)) == 30419 and int(it.get("count", 0)) == 10:
					has_potion = true
			if not (has_badge and has_potion):
				all_rewards_valid = false
		elif qid == 80055:
			var has_badge: bool = false
			var has_gear: bool = false
			for it_var: Variant in items:
				var it: Dictionary = it_var as Dictionary
				if int(it.get("id", 0)) == 30099 and int(it.get("count", 0)) == 1:
					has_badge = true
				if int(it.get("id", 0)) == 10611 and int(it.get("count", 0)) == 1:
					has_gear = true
			if not (has_badge and has_gear):
				all_rewards_valid = false

	for rq: int in required_quests:
		check(found_quest_ids.has(rq), "Story quest %d is present in benma_quests.json" % rq)

	check(all_givers_valid, "All quest givers and turn-ins exist in their corresponding scenes")
	check(all_texts_valid, "All quests contain natural Ukrainian titles and dialogue text")
	check(all_rewards_valid, "All quests specify positive exp and copper rewards, and accurate source items")

func test_monsters_and_encounters() -> void:
	var monster_file_path: String = "res://data/original/all_monster.json"
	check(FileAccess.file_exists(monster_file_path), "Original monster data file exists")

	var file: FileAccess = FileAccess.open(monster_file_path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	check(err == OK, "Original monster data parses as valid JSON")

	var monster_db: Dictionary = {}
	for m_var: Variant in (json.data as Array):
		var m: Dictionary = m_var as Dictionary
		monster_db[int(m.get("id", 0))] = m

	# Verify every monster ID in BenmaSpawns exists in all_monster.json
	var spawn_ids_valid: bool = true
	var spawned_monster_ids: Dictionary = {}
	for entry: Array in BenmaSpawns.ENCOUNTERS:
		var mid: int = int(entry[1])
		spawned_monster_ids[mid] = true
		if not monster_db.has(mid):
			spawn_ids_valid = false
			print("Unknown monster id in spawns: %d" % mid)

	check(spawn_ids_valid, "All monster IDs in BenmaSpawns.ENCOUNTERS exist in data/original/all_monster.json")

	# Verify all quest combat targets exist in original data and are spawned
	var quest_monster_targets: Array[int] = [70151, 70162, 70150, 70157, 70158, 70007]
	var targets_valid: bool = true
	var targets_spawned: bool = true
	for mid: int in quest_monster_targets:
		if not monster_db.has(mid):
			targets_valid = false
		if not spawned_monster_ids.has(mid):
			targets_spawned = false

	check(targets_valid, "All quest monster targets (70151, 70162, 70150, 70157, 70158, 70007) exist in all_monster.json")
	check(targets_spawned, "All quest monster targets have active encounter spawns in the steppe zone")

func test_navigation_reachability() -> void:
	# Breadth-first search on a 1.0m sampled navigation grid
	# confirming that player arrival point can reach every citizen interaction position
	var start_pos: Vector2 = Vector2(BenmaLayout.PLAYER_SPAWN.x, BenmaLayout.PLAYER_SPAWN.z)
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	var start_coord: Vector2i = Vector2i(roundi(start_pos.x), roundi(start_pos.y))
	queue.append(start_coord)
	visited[start_coord] = true

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]

	while not queue.is_empty():
		var curr: Vector2i = queue.pop_front()
		for d: Vector2i in dirs:
			var nxt: Vector2i = curr + d
			if visited.has(nxt):
				continue
			var world_p: Vector2 = Vector2(float(nxt.x), float(nxt.y))
			if world_p.x < BenmaLayout.BOUNDS_MIN.x or world_p.x > BenmaLayout.BOUNDS_MAX.x:
				continue
			if world_p.y < BenmaLayout.BOUNDS_MIN.y or world_p.y > BenmaLayout.BOUNDS_MAX.y:
				continue
			if BenmaLayout.blocks(world_p):
				continue
			visited[nxt] = true
			queue.append(nxt)

	var all_citizens_reachable: bool = true
	for c: Array in BenmaLayout.CITIZENS:
		var cpos: Vector3 = c[2]
		var c_grid: Vector2i = Vector2i(roundi(cpos.x), roundi(cpos.z))
		var reachable: bool = false
		if visited.has(c_grid):
			reachable = true
		else:
			# Check 1m radius around citizen for interaction point
			for d: Vector2i in dirs:
				if visited.has(c_grid + d):
					reachable = true
					break
		if not reachable:
			all_citizens_reachable = false
			print("Unreachable citizen: ID %d at %v" % [int(c[0]), cpos])

	check(all_citizens_reachable, "Navigation path exists from player arrival to every citizen interaction position")
