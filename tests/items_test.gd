extends SceneTree
const Catalog = preload("res://shared/items/item_catalog.gd")
const Inventory = preload("res://shared/items/inventory_system.gd")
class FakePlayer:
	extends Node
	var stats: Dictionary = {"level":1,"hp":40,"max_hp":100,"mp":20,"max_mp":50,"copper":500,"inventory":{},"equipment":{},"bag_capacity":2}
var failures: int = 0
var medicine_time: float = 1000.0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)
func run() -> void:
	var p: FakePlayer = FakePlayer.new()
	root.add_child(p)
	var inv: Inventory = Inventory.new()
	inv.bind_player(p)
	inv.time_source = func() -> float: return medicine_time
	Catalog.ensure_loaded()
	check(Catalog.all_items.size() > 1700,"source catalog contains equipment and props")
	check(Catalog.get_item(10010)["name"] == "长剑","actual longsword source identifier")
	check(Catalog.get_item(30016)["kind"] == "consumable" and Catalog.get_item(30022)["kind"] == "pet_food","known source consumable classifications")
	check(inv.buy_item(30016,2) and p.stats["copper"] == 460 and inv.count_item(30016) == 2,"purchase mutates currency and bag once")
	check(not inv.buy_item(30016,0) and not inv.buy_item(30016,-1) and not inv.buy_item(30016,1.5),"invalid quantities rejected")
	check(not inv.add_item(99999999) and not inv.buy_item(99999999),"unknown IDs rejected")
	check(inv.use_item(30016) and p.stats["hp"] == 90 and inv.count_item(30016) == 1,"potion consumes one and restores health")
	check(not inv.use_item(30016) and inv.count_item(30016) == 1,"manual repeat is blocked by medicine cooldown")
	medicine_time += MedicineState.COOLDOWN_SECONDS
	check(inv.use_item(30016) and p.stats["hp"] == 100,"potion clamps at maximum health")
	inv.add_item(30016)
	check(not inv.use_item(30016) and inv.count_item(30016) == 1,"full health does not waste potion")
	inv.add_item(10003)
	check(not inv.add_item(10002),"full bag rejects new item type")
	check(inv.equip_item(10003) and p.stats["equipment"]["weapon"] == 10003 and inv.count_item(10003) == 0,"equip removes bag item")
	inv.add_item(10010)
	check(inv.equip_item(10010) and inv.count_item(10003) == 1 and inv.used_slots() == 2,"full-bag equipment swap uses freed input slot")
	var before: Dictionary = inv.snapshot()
	check(not inv.unequip_item("weapon") and inv.snapshot() == before,"failed unequip leaves state unchanged")
	check(inv.bonus_totals().get("attack",0) == 6,"equipment bonus derived without mutating combat stats")
	inv.locked_items = [10003]
	before = inv.snapshot()
	check(not inv.equip_item(10003) and not inv.sell_item(10003) and not inv.discard_item(10003) and not inv.remove_item(10003),"protected quest items cannot mutate")
	check(inv.snapshot() == before,"all blocked operations are transactional")
	inv.locked_items = []
	var copper: int = p.stats["copper"]
	check(inv.sell_item(10003) and p.stats["copper"] == copper+20 and inv.count_item(10003) == 0,"sale removes item and adds price once")
	check(not inv.sell_item(10003),"selling absent item grants no money")
	p.stats["copper"] = 0
	before = inv.snapshot()
	check(not inv.buy_item(30645) and inv.snapshot() == before,"insufficient money leaves transaction unchanged")
	check(inv.validate_state(p.stats),"live state validates")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(p.stats))
	check(inv.validate_state(roundtrip),"JSON integer-valued floats accepted")
	var bad: Dictionary = roundtrip.duplicate(true)
	bad["inventory"]["30016"] = "2"
	check(not inv.validate_state(bad),"string count rejected")
	bad = roundtrip.duplicate(true)
	bad["equipment"]["head"] = 10010
	check(not inv.validate_state(bad),"equipment wrong slot rejected")
	bad = roundtrip.duplicate(true)
	bad["bag_capacity"] = 0
	check(not inv.validate_state(bad),"invalid bag capacity rejected")
	bad = roundtrip.duplicate(true)
	bad["inventory"]["30016"] = 100
	check(not inv.validate_state(bad),"overfilled stack rejected")
	p.stats["inventory"] = {}
	p.stats["bag_capacity"] = 32
	p.stats["hp"] = 10
	p.stats["max_hp"] = 2000
	p.stats["mp"] = 5
	p.stats["max_mp"] = 2000
	p.stats["copper"] = 500
	for id: int in [30016,30033,30419,31142,31143,30210,30644,30650,30019,30030,30484,31144,31145,30215,30645,30651]:
		check(Catalog.get_item(id).get("effect",{}).get("type") == "restore","original instant restoration classified " + str(id))
	for id: int in [30195,30197,30198,30199,30200,30201,30202,30203,30204,30205]:
		check(Catalog.get_item(id).get("effect",{}).get("type") == "regenerate","original gradual food classified " + str(id))
	inv.add_item(30033,2)
	inv.add_item(30484,2)
	medicine_time += MedicineState.COOLDOWN_SECONDS
	check(inv.use_item(30033) and p.stats["hp"] == 110 and inv.count_item(30033) == 1,"second HP tier restores provisional100 and consumes once")
	check(inv.use_item(30484) and p.stats["mp"] == 155 and inv.count_item(30484) == 1,"third MP tier restores provisional150 and consumes once")
	inv.add_item(31143)
	p.stats["hp"] = 1800
	medicine_time += MedicineState.COOLDOWN_SECONDS
	check(inv.use_item(31143) and p.stats["hp"] == 2000,"highest HP tier clamps to actual maximum")
	p.stats["hp"] = 50
	inv.add_item(30197,3)
	check(inv.use_item(30197) and p.stats["hp"] == 50 and inv.count_item(30197) == 2,"food queues without instant restoration")
	check(not inv.use_item(30197) and inv.count_item(30197) == 2,"duplicate same-food effect rejected without consumption")
	ItemEffects.tick(p.stats,2.5)
	check(p.stats["hp"] == 75 and p.stats["regeneration_effects"].size() == 1,"food restores proportional amount on partial tick")
	p.stats = JSON.parse_string(JSON.stringify(p.stats))
	check(ItemEffects.validate(p.stats) and inv.validate_state(p.stats),"partial food survives JSON save schema")
	ItemEffects.tick(p.stats,7.5)
	check(p.stats["hp"] == 150 and p.stats["regeneration_effects"].is_empty(),"food completes exact total and removes finished effect")
	p.stats["mp"] = 0
	inv.add_item(30201,3)
	check(inv.use_item(30201),"MP food queues")
	ItemEffects.tick(p.stats,0.1)
	check(p.stats["mp"] == 0 and float(p.stats["regeneration_effects"][0]["fractional"]) > 0.0,"fractional food restoration retained")
	ItemEffects.tick(p.stats,9.9)
	check(p.stats["mp"] == 30 and p.stats["regeneration_effects"].is_empty(),"fractional food delivers exact amount at deadline")
	p.stats["mp"] = 0
	check(inv.use_item(30201),"MP food can restart after effect completion")
	for index: int in 300:
		ItemEffects.tick(p.stats,1.0/30.0)
	check(p.stats["mp"] == 30 and p.stats["regeneration_effects"].is_empty(),"small fractional MP ticks preserve exact total")
	p.stats["hp"] = 50
	check(inv.use_item(30197),"food can be used after previous effect expires")
	for index: int in 300:
		ItemEffects.tick(p.stats,1.0/30.0)
	check(p.stats["hp"] == 150 and p.stats["regeneration_effects"].is_empty(),"frame-sized ticks do not lose final restoration to rounding")
	p.stats["hp"] = 50
	check(inv.use_item(30197),"food queues before reaching full health")
	p.stats["hp"] = p.stats["max_hp"]
	ItemEffects.tick(p.stats,1.0)
	check(p.stats["regeneration_effects"].is_empty() and p.stats["hp"] == p.stats["max_hp"],"full resource drops food without overheal")
	p.stats["hp"] = 50
	inv.add_item(30195,2)
	check(inv.use_item(30195),"food queues for validation probes")
	var active: Dictionary = p.stats.duplicate(true)
	var invalid_effect: Dictionary = active.duplicate(true)
	invalid_effect["regeneration_effects"][0]["remaining_time"] = 0
	check(not ItemEffects.validate(invalid_effect),"zero remaining food time rejected")
	invalid_effect = active.duplicate(true)
	invalid_effect["regeneration_effects"][0]["remaining_amount"] = NAN
	check(not ItemEffects.validate(invalid_effect),"nonfinite food amount rejected")
	invalid_effect = active.duplicate(true)
	invalid_effect["regeneration_effects"][0]["item_id"] = 30016
	check(not ItemEffects.validate(invalid_effect),"instant potion cannot forge gradual effect")
	invalid_effect = active.duplicate(true)
	invalid_effect["regeneration_effects"].append(invalid_effect["regeneration_effects"][0].duplicate(true))
	check(not ItemEffects.validate(invalid_effect),"duplicate persisted food effect rejected")
	invalid_effect = active.duplicate(true)
	invalid_effect["regeneration_effects"][0]["extra"] = "forged"
	check(not ItemEffects.validate(invalid_effect),"unknown effect fields rejected")
	ItemEffects.tick(p.stats,NAN)
	check(p.stats == active,"nonfinite delta cannot mutate food state")
	p.stats["hp"] = 0
	ItemEffects.tick(p.stats,1.0)
	check(p.stats["hp"] == 0 and p.stats["regeneration_effects"].is_empty(),"death cancels food rather than reviving player")
	p.stats["hp"] = 50
	p.stats["inventory"] = {}
	for id: int in [30195,30197,30198,30199,30200,30201]:
		inv.add_item(id,2)
	for id: int in [30195,30197,30198,30199,30200]:
		inv.use_item(id)
	check(p.stats["regeneration_effects"].size() == 5 and not inv.use_item(30201) and inv.count_item(30201) == 2,"five-effect cap does not consume sixth food")
	p.stats["regeneration_effects"] = []
	p.stats["inventory"] = {}
	p.stats["bag_capacity"] = 95
	inv.add_item(30621,2)
	check(inv.use_item(30621) and p.stats["bag_capacity"] == 100 and inv.count_item(30621) == 1,"bag expansion consumes one and adds source five slots")
	check(not inv.use_item(30621) and inv.count_item(30621) == 1,"bag cap does not waste expansion book")
	p.stats["warehouse_capacity"] = 123
	inv.add_item(30081,2)
	check(inv.use_item(30081) and p.stats["warehouse_capacity"] == 128 and inv.count_item(30081) == 1,"warehouse expansion adds five up to modern cap")
	check(not inv.use_item(30081) and inv.count_item(30081) == 1,"warehouse cap does not waste book")
	CharacterSystem.ensure_stats(p.stats)
	p.stats["skills"] = {"90014":2,"90036":1}
	p.stats["hotbar"] = {"1":90036}
	p.stats["skill_points"] = 3
	p.stats["copper"] = 0
	inv.add_item(30092,2)
	check(inv.use_item(30092) and p.stats["skill_points"] == 6 and p.stats["skills"].is_empty() and p.stats["hotbar"].is_empty() and p.stats["copper"] == 0 and inv.count_item(30092) == 1,"training book refunds assigned ranks once without cash charge")
	check(not inv.use_item(30092) and inv.count_item(30092) == 1 and p.stats["skill_points"] == 6,"empty skill tree does not consume another book or duplicate points")
	check(not CharacterSystem.respec_skills(p.stats,-1) and not CharacterSystem.respec_skills(p.stats,200),"respec price extension rejects unsupported fees")
	p.stats["bag_capacity"] = 95
	inv.locked_items = [30621]
	check(not inv.use_item(30621) and p.stats["bag_capacity"] == 95,"locked expansion book cannot be consumed")
	inv.locked_items = []
	p.stats["hp"] = 0
	inv.add_item(30016)
	check(not inv.use_item(30016),"dead player cannot consume healing")
	p.queue_free()
	await process_frame
	print("ITEMS_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
