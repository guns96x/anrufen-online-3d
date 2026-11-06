extends SceneTree

class FakePlayer:
	extends Node
	var stats: Dictionary = {
		"level": 10,
		"copper": 100,
		"inventory": {},
		"warehouse": {},
		"locked_items": [],
		"bag_capacity": 32,
		"warehouse_capacity": 64
	}

var failures: int = 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	ItemCatalog.ensure_loaded()
	GameServices.ensure_recipes_loaded()
	
	# 1. Recipe loading & catalog presence
	check(GameServices.RECIPES.size() == 19, "all 19 recipes loaded (17 all_combine + 2 baseline)")
	check(GameServices.recipes_by_id.size() >= 19, "recipes_by_id index populated")
	
	var all_catalog_ok: bool = true
	var all_schemas_ok: bool = true
	for recipe: Dictionary in GameServices.RECIPES:
		if not recipe.has("id") or not recipe.has("name") or not recipe.has("copper") or not recipe.has("output") or not recipe.has("count"):
			all_schemas_ok = false
			break
		var inputs: Dictionary = recipe.get("inputs", recipe.get("input", {}))
		for in_id_str: String in inputs:
			var in_item: Dictionary = ItemCatalog.get_item(int(in_id_str))
			if in_item.is_empty():
				all_catalog_ok = false
				print("Missing input in catalog: ", in_id_str)
				break
		var out_item: Dictionary = ItemCatalog.get_item(int(recipe["output"]))
		if out_item.is_empty():
			all_catalog_ok = false
			print("Missing output in catalog: ", recipe["output"])
			break
	check(all_schemas_ok, "every recipe conforms to required schema")
	check(all_catalog_ok, "every recipe input and output exists in ItemCatalog")
	
	# Lookup by id (both int and string consistency)
	var r280001: Dictionary = GameServices.recipe_by_id(280001)
	var r280001_s: Dictionary = GameServices.recipe_by_id("280001")
	check(not r280001.is_empty() and int(r280001["output"]) == 30550, "recipe_by_id retrieves correct record 280001")
	check(r280001["id"] == r280001_s["id"], "recipe_by_id produces consistent results for int and string ID")
	
	var r_first: Dictionary = GameServices.recipe_by_id(1001)
	var r_first_s: Dictionary = GameServices.recipe_by_id("1001")
	check(not r_first.is_empty() and int(r_first["output"]) == 30016, "recipe_by_id retrieves baseline health supplies recipe")
	check(r_first["id"] == r_first_s["id"], "baseline recipe lookup consistent for int and string ID")
	
	# Lookup by index
	var r_idx0: Dictionary = GameServices.recipe_by_index(0)
	check(r_idx0["id"] == 1001, "recipe_by_index retrieves first recipe at index 0")
	
	# 2. Offline player & inventory synthesis tests
	var p: FakePlayer = FakePlayer.new()
	root.add_child(p)
	
	var inventory: InventorySystem = InventorySystem.new()
	inventory.bind_player(p)
	
	var services: GameServices = GameServices.new()
	services.bind_player(p, inventory)
	
	# Baseline synthesis (recipe index 0): 2 bones (30037) + 8 copper -> 2 potions (30016)
	inventory.add_item(30037, 2)
	check(inventory.count_item(30037) == 2, "test setup adds 2 boar bones")
	
	var changed_box: Array[bool] = [false]
	services.changed.connect(func() -> void: changed_box[0] = true)
	
	var craft_ok: bool = services.craft(0)
	check(craft_ok, "synthesis succeeds with exact inputs and copper by index")
	check(changed_box[0], "services emits changed signal on successful synthesis")
	check(inventory.count_item(30037) == 0, "synthesis consumed exact input items")
	check(inventory.count_item(30016) == 2, "synthesis produced exact output count")
	check(p.stats["copper"] == 92, "synthesis deducted exact copper cost")
	
	# 3. Clean failure without materials or copper
	check(not services.craft(0), "synthesis cleanly fails without materials")
	check(p.stats["copper"] == 92 and inventory.count_item(30016) == 2, "failed synthesis does not mutate copper or output")
	
	inventory.add_item(30037, 2)
	p.stats["copper"] = 4 # recipe costs 8 copper
	check(not services.craft(0), "synthesis cleanly fails with insufficient copper")
	check(inventory.count_item(30037) == 2, "failed synthesis leaves input materials untouched")
	p.stats["copper"] = 100
	
	# Clean failure with locked item
	services.lock_item(30037)
	check(not services.craft(0), "synthesis rejects locked input material")
	services.lock_item(30037) # unlock
	
	# Clean failure with insufficient level
	p.stats["level"] = 0
	check(not services.craft(0), "synthesis rejects insufficient level")
	p.stats["level"] = 10
	
	# 4. Synthesis by ID and multi-material synthesis
	# Recipe 280012: 1 Sun stone (30814), 1 Moon stone (30815), 1 Diamond (30816), 1 Amber (30817) + 100 copper -> Green Griffin (10018)
	p.stats["copper"] = 200
	inventory.add_item(30814, 1)
	inventory.add_item(30815, 1)
	inventory.add_item(30816, 1)
	inventory.add_item(30817, 1)
	
	var synth_id_ok: bool = services.synthesize(280012)
	check(synth_id_ok, "synthesize by ID succeeds for multi-ingredient recipe 280012")
	check(inventory.count_item(10018) == 1, "mount Green Griffin produced into inventory")
	check(inventory.count_item(30814) == 0 and inventory.count_item(30815) == 0, "all multi-ingredient stones consumed")
	check(p.stats["copper"] == 100, "copper deducted accurately for 100 copper recipe")
	
	# Explicit craft_by_id and craft_by_index methods
	p.stats["copper"] = 100
	inventory.add_item(30037, 2)
	check(services.craft_by_id(1001), "craft_by_id succeeds explicitly")
	inventory.add_item(30037, 2)
	check(services.craft_by_index(0), "craft_by_index succeeds explicitly")
	
	# 5. Full bag handling: input frees slot for output
	p.stats["inventory"].clear()
	p.stats["bag_capacity"] = 4
	p.stats["copper"] = 100
	# Fill bag to 4/4 slots with 3 junk items + exactly 3 certificates (30024)
	inventory.add_item(30016, 1)
	inventory.add_item(30645, 1)
	inventory.add_item(30099, 1)
	inventory.add_item(30024, 3)
	check(inventory.used_slots() == 4, "bag is completely full at 4/4 slots")
	
	# Recipe 280001 consumes 30024 x3 -> gives 30550 (new item slot!)
	check(services.craft(280001), "full bag accepts synthesis when input consumption frees required slot")
	check(inventory.count_item(30550) == 1, "output received in freed slot")
	check(inventory.used_slots() == 4, "bag remains at capacity limit")
	
	# 6. Server-authoritative session test
	var social: SocialState = SocialState.new()
	social.join(1, "Recipe Hero")
	var simulation: WorldSimulation = WorldSimulation.new()
	simulation.bind_social(social)
	var session: ServerGameSession = ServerGameSession.new()
	root.add_child(session)
	session.bind_account(1, social, simulation)
	simulation.add_actor(1)
	
	# Move player near merchant citizen 50179
	simulation.actors[1]["position"] = ServerGameSession.CITIZENS[50179]
	session.actor.stats["copper"] = 100
	session.items.add_item(30037, 2)
	
	var server_act_ok: Dictionary = session.act("craft", {"recipe": 0})
	check(server_act_ok.get("ok", false), "server act('craft', ...) synthesizes recipe near citizen")
	check(session.items.count_item(30037) == 0, "server synthesis consumes input items from authoritative inventory")
	check(session.items.count_item(30016) >= 2, "server synthesis gives output items to authoritative inventory")
	check(session.actor.stats["copper"] == 92, "server synthesis deducts authoritative copper")
	
	# Repeat without materials fails on server
	var server_fail_act: Dictionary = session.act("craft", {"recipe": 0})
	check(not server_fail_act.get("ok", true), "server act rejects synthesis cleanly without materials")
	
	# Distant citizen check
	session.items.add_item(30037, 2)
	simulation.actors[1]["position"] = Vector3(9999, 0, 9999)
	var distant_act: Dictionary = session.act("craft", {"recipe": 0})
	check(not distant_act.get("ok", true), "server act rejects synthesis when distant from crafting citizen")
	
	session.queue_free()
	p.queue_free()
	
	print("RECIPES_SUITE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
