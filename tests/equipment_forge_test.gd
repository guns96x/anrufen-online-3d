extends SceneTree

const Catalog = preload("res://shared/items/item_catalog.gd")
const Inventory = preload("res://shared/items/inventory_system.gd")

class FakePlayer:
	extends Node
	var stats: Dictionary = {
		"level": 35,
		"hp": 100,
		"max_hp": 100,
		"mp": 50,
		"max_mp": 50,
		"copper": 5000,
		"inventory": {},
		"equipment": {},
		"equipment_state": {},
		"bag_capacity": 32,
		"attributes": {"strength": 0, "vitality": 0, "intelligence": 0, "agility": 0},
		"skills": {},
		"hotbar": {},
		"class_id": 130001
	}

var failures: int = 0

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Catalog.ensure_loaded()
	EquipmentRules._load()

	var player: FakePlayer = FakePlayer.new()
	root.add_child(player)
	var inv: Inventory = Inventory.new()
	inv.bind_player(player)

	# 1. Equip item and initial state
	inv.add_item(10003, 1) # Novice sword, quality 1
	check(inv.equip_item(10003), "equip novice sword succeeds")
	check(player.stats["equipment"].get("weapon", 0) == 10003, "weapon slot has item 10003")
	var state: Dictionary = player.stats["equipment_state"].get("weapon", {})
	check(state.get("upgrade", -1) == 0 and state.get("durability", -1) == 100 and state.get("max_durability", -1) == 100, "initial equipment state is +0 and 100/100 durability")

	# 2. Upgrade success path with fixed roll
	player.stats["copper"] = 1000
	inv.add_item(30064, 5) # Steel ingot (quality 1)
	var copper_before: int = player.stats["copper"]
	# Upgrade +0 -> +1 with roll 0.05 (chance is 0.90)
	var ok_up: bool = inv.upgrade_item("weapon", 30064, 0, 0, 0.05)
	check(ok_up and player.stats["equipment_state"]["weapon"]["upgrade"] == 1, "upgrade success path increases level to +1")
	check(inv.count_item(30064) == 4, "material consumed on upgrade success")
	check(player.stats["copper"] == copper_before - 10, "copper consumed correctly (10 for +1)")

	# 3. Upgrade failure path with fixed roll
	copper_before = player.stats["copper"]
	# Upgrade +1 -> +2 failure with roll 0.95 (chance is 0.83)
	var ok_fail: bool = inv.upgrade_item("weapon", 30064, 0, 0, 0.95)
	check(ok_fail and player.stats["equipment_state"]["weapon"]["upgrade"] == 0, "upgrade failure path drops level back to 0")
	check(player.stats["equipment_state"]["weapon"]["max_durability"] == 95, "unprotected failure reduces max durability by 5")
	check(inv.count_item(30064) == 3, "material consumed on upgrade failure")
	check(player.stats["copper"] == copper_before - 20, "copper consumed on failure (20 for +2 attempt)")

	# 4. Protection and boost items
	inv.add_item(30067, 2) # Protection talisman
	inv.add_item(30068, 2) # Boost talisman
	# Attempt +0 -> +1 failure with roll 0.99 with protection and boost
	var ok_prot: bool = inv.upgrade_item("weapon", 30064, 30067, 30068, 0.999)
	check(ok_prot, "protected boosted upgrade attempt executes")
	check(player.stats["equipment_state"]["weapon"]["max_durability"] == 95, "protection talisman prevented further max durability loss")
	check(inv.count_item(30067) == 1 and inv.count_item(30068) == 1, "protection and boost talismans consumed")

	# 5. Max +10 boundary
	player.stats["equipment_state"]["weapon"]["upgrade"] = 10
	var max_try: bool = inv.upgrade_item("weapon", 30064, 0, 0, 0.01)
	check(not max_try, "upgrade rejected at max +10")
	check(inv.count_item(30064) == 2, "no material consumed when rejected at max +10")

	# 6. Repair durability and cost
	player.stats["equipment_state"]["weapon"]["durability"] = 75
	player.stats["equipment_state"]["weapon"]["max_durability"] = 95 # missing = 20
	copper_before = player.stats["copper"]
	var ok_repair: bool = inv.repair_item("weapon")
	check(ok_repair, "repair succeeds on damaged item")
	check(player.stats["equipment_state"]["weapon"]["durability"] == 95, "durability restored to max durability")
	check(player.stats["copper"] == copper_before - 40, "repair cost matches 2 copper per missing durability (40 copper)")
	check(not inv.repair_item("weapon"), "repair rejected when item is already fully repaired")

	# 7. Affix once per side
	inv.add_item(30206, 1) # Prefix material (stone mushroom)
	inv.add_item(30207, 1) # Another prefix material
	inv.add_item(30333, 2) # Suffix material (iron fossil)
	copper_before = player.stats["copper"]
	check(inv.affix_item("weapon", 30206), "prefix affix applied successfully")
	check(player.stats["equipment_state"]["weapon"]["prefix_id"] == 30206, "state records prefix_id")
	check(player.stats["copper"] == copper_before - 30, "affix costs 30 copper")
	check(inv.count_item(30206) == 0, "prefix material consumed")
	check(not inv.affix_item("weapon", 30207), "cannot apply second prefix to same weapon")
	check(inv.count_item(30207) == 1, "rejected affix does not consume material")
	check(inv.affix_item("weapon", 30333), "suffix affix applied successfully")
	check(player.stats["equipment_state"]["weapon"]["suffix_id"] == 30333, "state records suffix_id")
	check(not inv.affix_item("weapon", 30333), "cannot apply second suffix to same weapon")

	# 8. Set bonuses counted at 2+ pieces and durability 0 zeroing
	# Suit 40033: 10315 (head), 10316 (body), 10317 (belt), 10318 (shoes). Gives +23 attack at 2 pieces.
	player.stats["equipment"].clear()
	player.stats["equipment_state"].clear()
	player.stats["equipment"]["head"] = 10315
	player.stats["equipment_state"]["head"] = {"upgrade": 0, "durability": 100, "max_durability": 100, "prefix_id": 0, "suffix_id": 0}
	var bonuses_1_piece: Dictionary = CharacterSystem.equipment_bonuses(player.stats)
	var suit_check_1: Dictionary = EquipmentRules.suit_bonuses(player.stats["equipment"], player.stats["equipment_state"])
	check(int(suit_check_1.get("suit_piece_counts", {}).get("40033", 0)) == 1, "suit piece count is 1 with single piece")
	check(not suit_check_1.has("attack") or float(suit_check_1["attack"]) == 0.0, "no suit bonus at 1 piece")

	# Equip second piece of suit
	player.stats["equipment"]["body"] = 10316
	player.stats["equipment_state"]["body"] = {"upgrade": 0, "durability": 100, "max_durability": 100, "prefix_id": 0, "suffix_id": 0}
	var suit_check_2: Dictionary = EquipmentRules.suit_bonuses(player.stats["equipment"], player.stats["equipment_state"])
	check(int(suit_check_2.get("suit_piece_counts", {}).get("40033", 0)) == 2, "suit piece count is 2 with two pieces")
	check(int(suit_check_2.get("attack", 0)) == 23, "suit grants +23 attack bonus at 2 pieces")

	var total_bonuses_2: Dictionary = CharacterSystem.equipment_bonuses(player.stats)
	var atk_at_2: int = int(total_bonuses_2.get("attack", 0))

	# Durability 0: item gives no bonus and does not count towards suit
	player.stats["equipment_state"]["body"]["durability"] = 0
	var bonuses_zero_dur: Dictionary = CharacterSystem.equipment_bonuses(player.stats)
	check(int(bonuses_zero_dur.get("attack", 0)) < atk_at_2, "durability 0 item loses its bonuses and suit bonus")

	# 9. Bonuses change character attack
	player.stats["equipment"].clear()
	player.stats["equipment_state"].clear()
	CharacterSystem.rebuild_stats(player.stats, {})
	var base_attack: int = int(player.stats["attack"])

	# Equip weapon at +0
	player.stats["equipment"]["weapon"] = 10003
	player.stats["equipment_state"]["weapon"] = {"upgrade": 0, "durability": 100, "max_durability": 100, "prefix_id": 0, "suffix_id": 0}
	CharacterSystem.rebuild_stats(player.stats, CharacterSystem.equipment_bonuses(player.stats))
	var atk_plus_0: int = int(player.stats["attack"])
	check(atk_plus_0 > base_attack, "equipping weapon increases attack")

	# Upgrade weapon to +5
	player.stats["equipment_state"]["weapon"]["upgrade"] = 5
	CharacterSystem.rebuild_stats(player.stats, CharacterSystem.equipment_bonuses(player.stats))
	var atk_plus_5: int = int(player.stats["attack"])
	check(atk_plus_5 > atk_plus_0, "upgraded +5 weapon increases attack further")

	# 10. Death durability loss
	player.stats["equipment_state"]["weapon"]["durability"] = 100
	player.stats["equipment_state"]["weapon"]["max_durability"] = 100
	Inventory.durability_on_death(player.stats)
	check(player.stats["equipment_state"]["weapon"]["durability"] == 90, "player death subtracts 10% of max durability from worn items")

	# 11. Unequip drops equipment_state
	check(inv.unequip_item("weapon"), "unequip weapon succeeds")
	check(not player.stats["equipment_state"].has("weapon"), "unequipping drops equipment state for slot")

	# 12. Server action path (authoritative server act)
	var social: SocialState = SocialState.new()
	social.join(1, "Forge Tester")
	var simulation: WorldSimulation = WorldSimulation.new()
	simulation.bind_social(social)
	var session: ServerGameSession = ServerGameSession.new()
	root.add_child(session)
	session.bind_account(1, social, simulation)
	simulation.add_actor(1)

	session.items.add_item(10003, 1)
	check(session.act("equip", {"id": 10003})["ok"], "server equips weapon")
	check(session.actor.stats["equipment_state"].has("weapon"), "server initializes equipment_state on equip")

	session.items.add_item(30064, 5)
	session.actor.stats["copper"] = 1000
	var res_up: Dictionary = session.act("upgrade", {"slot": "weapon", "material": 30064})
	check(res_up["ok"], "server action upgrade executes successfully")
	check(session.items.count_item(30064) == 4, "server upgrade consumed material")

	# Server repair action
	session.actor.stats["equipment_state"]["weapon"]["durability"] = 50
	var res_rep: Dictionary = session.act("repair", {"slot": "weapon"})
	check(res_rep["ok"], "server action repair executes successfully")
	check(session.actor.stats["equipment_state"]["weapon"]["durability"] == session.actor.stats["equipment_state"]["weapon"]["max_durability"], "server repair restored durability")

	# Server affix action
	session.items.add_item(30206, 1)
	session.actor.stats["level"] = 35
	var res_aff: Dictionary = session.act("affix", {"slot": "weapon", "material": 30206})
	check(res_aff["ok"], "server action affix executes successfully")
	check(session.actor.stats["equipment_state"]["weapon"]["prefix_id"] == 30206, "server affix recorded prefix_id")

	# Server death durability loss
	var dur_before_death: int = int(session.actor.stats["equipment_state"]["weapon"]["durability"])
	simulation.actors[1]["dead"] = true
	session.sync()
	check(int(session.actor.stats["equipment_state"]["weapon"]["durability"]) == dur_before_death - 10, "server sync on death triggers single 10% durability loss")

	# 13. UI GameMenu equipment tab inspection
	session.actor.stats["equipment"]["head"] = 10315
	session.actor.stats["equipment_state"]["head"] = {"upgrade": 2, "durability": 80, "max_durability": 100, "prefix_id": 0, "suffix_id": 0}
	session.actor.stats["equipment"]["body"] = 10316
	session.actor.stats["equipment_state"]["body"] = {"upgrade": 0, "durability": 100, "max_durability": 100, "prefix_id": 0, "suffix_id": 0}

	var menu: GameMenu = GameMenu.new()
	root.add_child(menu)
	menu.bind_player(session.actor, session.items, session.services, session.pets)
	menu._equipment_selected_slot = "head"
	menu.open_tab("equipment")
	await process_frame
	await process_frame

	# Verify UI elements exist in ContentScroll
	var tree_dump: String = _node_text_dump(menu)
	check(tree_dump.contains("Міцність"), "equipment tab UI displays durability text")
	check(tree_dump.contains("Заточити"), "equipment tab UI displays upgrade button")
	check(tree_dump.contains("Ремонт"), "equipment tab UI displays repair button")
	check(tree_dump.contains("Вставити афікс"), "equipment tab UI displays affix button")
	check(tree_dump.contains("Комплект: 2/"), "equipment tab UI displays set progress")

	menu.queue_free()
	session.queue_free()
	player.queue_free()

	print("EQUIPMENT_FORGE_SUITE: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _node_text_dump(node: Node) -> String:
	var result: String = ""
	if node is Label or node is Button:
		result += str(node.text) + " "
	for child: Node in node.get_children():
		result += _node_text_dump(child)
	return result
