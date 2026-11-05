extends SceneTree
const Rules = preload("res://shared/items/equipment_rules.gd")
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
func actor() -> Dictionary:
	return {"level":100,"class_id":130006,"copper":10000,"bag_capacity":16,"inventory":{"30064":20,"30482":1,"30065":2,"30810":1,"30066":2,"30067":2,"30697":1,"30068":2,"30483":1,"30251":2,"30333":2,"30345":1}}
func run() -> void:
	var stats: Dictionary = actor()
	check(Rules.definition(10010)["buy_price"] == 200,"source longsword price")
	check(Rules.definition(10010)["raw_unknown_scalar2"] == 1,"unknown scalar preserved")
	check(Rules.definition(10165)["slot"] == "necklace" and Rules.definition(10313)["source_slot_id"] == 7,"numeric slot authoritative over icon")
	check(Rules.definition(999999).is_empty(),"unknown definition")
	var copy: Dictionary = Rules.definition(10010)
	copy["requirements"][0]["level_candidate"] = 999
	check(Rules.definition(10010)["requirements"][0]["level_candidate"] == 10,"definition is deep copied")
	check(Rules.can_equip(stats,10010),"descendant inherits base class equipment")
	check(not Rules.can_equip({"level":9,"class_id":130001},10010),"level candidate enforced")
	check(not Rules.can_equip({"level":100,"class_id":130009},10010),"unrelated class rejected")
	check(not Rules.can_equip({"level":10.5,"class_id":130001},10010),"fractional level rejected")
	check(Rules.can_equip({"level":10.0,"class_id":130001.0},10010),"JSON whole integers accepted")
	check(Rules.raw_properties(10003,0)["20"] == 260,"source base attack 260")
	check(Rules.raw_properties(10003,10)["20"] == 780,"source level ten endpoint")
	check(Rules.raw_properties(10003,-1).is_empty() and Rules.raw_properties(10003,11).is_empty(),"upgrade index never silently clamped")
	check(Rules.raw_properties(10009,0)["32"] == 60 and Rules.raw_properties(10009,1)["32"] == 0,"nonmonotonic source curve remains nonmonotonic")
	var curve: Array = [260,286,338,390,423,455,520,585,650,715,780]
	for n: int in range(11): check(Rules.raw_properties(10003,n)["20"] == curve[n],"exact source curve %d" % n)
	check(is_equal_approx(Rules.bonuses(10003)["attack"],26.0),"explicit provisional scale")
	check(Rules.bonuses(10003,{"durability":0})["attack"] == 0 and Rules.bonuses(10003,{"durability":0})["raw_bonus"]["20"] == 260,"broken suppresses runtime but preserves raw")
	check(Rules.bonuses(10003,{"upgrade":1.5}).is_empty(),"invalid fractional state")
	var two: Dictionary = Rules.suit_bonuses({"a":10323,"b":10324})
	check(two["raw_bonus"].get("20") == 300 and not two["raw_bonus"].has("108"),"40035 two-piece threshold")
	var three: Dictionary = Rules.suit_bonuses({"a":10323,"b":10324,"c":10603})
	check(three["raw_bonus"]["20"] == 300 and three["raw_bonus"]["108"] == 200,"40035 third threshold")
	var four: Dictionary = Rules.suit_bonuses({"a":10323,"b":10324,"c":10603,"d":10760})
	check(four["raw_bonus"]["20"] == 300 and four["raw_bonus"]["51"] == 300 and four["raw_bonus"]["108"] == 200,"40035 exact raw 300/300/200")
	check(four["applied_suit_effects"].size() == 3,"dual membership never doubles effects")
	check(four["unsupported_raw"]["51"] == 300 and four["unsupported_raw"]["108"] == 200,"unsupported effects retained only as raw")
	check(Rules.suit_bonuses({"a":10323,"b":10323})["suit_piece_counts"]["40035"] == 1,"duplicate IDs count once")
	check(Rules.suit_bonuses({"a":10571})["suit_piece_counts"]["40014"] == 1,"footer membership despite placeholder")
	check(Rules.suit_bonuses({"a":10117})["suit_piece_counts"]["40026"] == 1,"explicit membership despite zero footer")
	check(Rules.suit_bonuses({"a":0})["suit_piece_counts"].is_empty(),"zero placeholder never equipped")
	check(Rules.suit_bonuses({"a":10323,"b":10324},{"10323":{"durability":0}})["suit_piece_counts"]["40035"] == 1,"broken item not an active set piece")
	var before: Dictionary = stats.duplicate(true)
	var state: Dictionary = {"upgrade":3,"durability":100,"max_durability":100,"custom":{"uid":"sample"}}
	var saved: Dictionary = state.duplicate(true)
	var plan: Dictionary = Rules.upgrade_plan(stats,10003,state,30064,0,0,0.0)
	check(plan["ok"] and plan["success"] and plan["state"]["upgrade"] == 4,"ordinary success")
	check(plan["copper_cost"] == 40 and plan["consume"] == {"30064":1},"explicit service cost and exact consumption")
	check(stats == before and state == saved,"plans never mutate inputs")
	plan["state"]["custom"]["uid"] = "changed"
	check(state == saved,"plan state deep copied")
	check(Rules.upgrade_plan(stats,10003,{},30482,0,0,0.0)["ok"],"alternate ordinary material")
	check(not Rules.upgrade_plan(stats,10003,{},30065)["ok"],"ordinary rejects excellent material")
	check(Rules.upgrade_plan(stats,10000,{},30065,0,0,0.0)["ok"] and Rules.upgrade_plan(stats,10000,{},30810,0,0,0.0)["ok"],"excellent material aliases")
	check(Rules.upgrade_plan(stats,10026,{},30066,0,0,0.0)["ok"] and not Rules.upgrade_plan(stats,10026,{},30064)["ok"],"highest exact material quality")
	plan = Rules.upgrade_plan(stats,10003,state,30064,0,0,0.999)
	check(plan["ok"] and not plan["success"] and plan["state"]["upgrade"] == 2 and plan["state"]["max_durability"] == 95 and plan["state"]["durability"] == 95,"failed attempt costs resources and loses level and max durability")
	for protection: int in [30067,30697]:
		plan = Rules.upgrade_plan(stats,10003,state,30064,protection,0,0.999)
		check(plan["state"]["upgrade"] == 2 and plan["state"]["max_durability"] == 100 and plan["consume"].has(str(protection)),"protection saves durability only %d" % protection)
	var normal: Dictionary = Rules.upgrade_plan(stats,10003,{},30064,0,0,0.95)
	for boost: int in [30068,30483]:
		plan = Rules.upgrade_plan(stats,10003,{},30064,0,boost,0.95)
		check(not normal["success"] and plan["success"] and plan["success_chance"] > normal["success_chance"],"boost increases provisional chance %d" % boost)
	check(not Rules.upgrade_plan(stats,10003,{"upgrade":10},30064)["ok"],"max upgrade cap")
	check(not Rules.upgrade_plan(stats,10003,{},30064,999)["ok"] and not Rules.upgrade_plan(stats,10003,{},30064,0,999)["ok"],"unknown runes rejected")
	check(not Rules.upgrade_plan(stats,10003,{},30064,0,0,1.0)["ok"] and not Rules.upgrade_plan(stats,10003,{},30064,0,0,NAN)["ok"],"invalid randomness rejected")
	var poor: Dictionary = stats.duplicate(true)
	poor["copper"] = 0
	check(not Rules.upgrade_plan(poor,10003,{},30064)["ok"],"currency checked before change")
	poor = stats.duplicate(true)
	poor["inventory"].erase("30064")
	check(not Rules.upgrade_plan(poor,10003,{},30064)["ok"],"must own consumed material")
	poor = stats.duplicate(true)
	poor["bag_capacity"] = 1
	check(not Rules.upgrade_plan(poor,10003,{},30064)["ok"],"corrupt overcapacity bag rejected")
	poor = stats.duplicate(true)
	poor["bag_capacity"] = poor["inventory"].size()
	check(Rules.upgrade_plan(poor,10003,{},30064)["ok"],"valid full bag needs no new slot")
	poor["inventory"]["30064"] = -1
	check(not Rules.upgrade_plan(poor,10003,{},30064)["ok"],"negative resource stack rejected")
	plan = Rules.affix_plan(stats,10003,{},30251)
	check(plan["ok"] and plan["state"]["prefix_id"] == 30251,"production prefix")
	var affixed: Dictionary = Rules.bonuses(10003,plan["state"])
	check(affixed["raw_bonus"]["61"] == 25.0 and affixed["unsupported_raw"]["61"] == 25.0,"exact float64 resistance retained")
	check(not Rules.affix_plan(stats,10003,plan["state"],30251)["ok"],"prefix immutable")
	plan = Rules.affix_plan(stats,10003,plan["state"],30333)
	check(plan["ok"] and plan["state"]["prefix_id"] == 30251 and plan["state"]["suffix_id"] == 30333,"independent suffix once")
	check(Rules.bonuses(10003,plan["state"])["raw_bonus"]["20"] == 352.0,"exact affix double added to exact curve")
	check(not Rules.affix_plan(stats,10003,plan["state"],30345)["ok"],"suffix cannot replace")
	check(not Rules.affix_plan(stats,10003,{},30007)["ok"] and not Rules.affix_plan(stats,10003,{},30008)["ok"],"test affixes forbidden")
	poor = stats.duplicate(true)
	poor["level"] = 29
	check(not Rules.affix_plan(poor,10003,{},30251)["ok"],"inferred actor material threshold enforced")
	poor["level"] = 30
	check(Rules.affix_plan(poor,10003,{},30251)["ok"],"actor threshold inclusive and item level unrestricted")
	check(Rules.bonuses(10003,{"prefix_id":30333}).is_empty(),"wrong affix side corrupt state rejected")
	plan = Rules.repair_plan(stats,10003,{"durability":40,"max_durability":95})
	check(plan["ok"] and plan["state"]["durability"] == 95 and plan["state"]["max_durability"] == 95 and plan["copper_cost"] == 110 and plan["consume"].is_empty(),"repair restores remaining max without reversing degradation")
	check(not Rules.repair_plan(stats,10003,{})["ok"],"full repair rejected")
	check(not Rules.repair_plan({"copper":0},10003,{"durability":0})["ok"],"repair insufficient money")
	check(not Rules.repair_plan(stats,10003,{"durability":96,"max_durability":95})["ok"],"incoherent durability rejected")
	check(stats == before and state == saved,"all service planning remains pure")
	verify_source_coverage()
	print("EquipmentRules: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func verify_source_coverage() -> void:
	var gear: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/equipment_rules.json"))["records"]
	var properties: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/original/property_rules.json"))["records"]: properties[int(row["id"])] = row
	check(gear.size() == 777 and properties.size() == 1626,"complete source tables loaded")
	for item: Dictionary in gear:
		check(Rules.definition(int(item["id"]))["source_slot_id"] == item["source_slot_id"],"numeric source slot %d" % item["id"])
		for n: int in range(11):
			var expected: Dictionary = {}
			for group: Array in item["property_id_groups"]:
				for id: Variant in group:
					if int(id) == 0: continue
					var property: Dictionary = properties[int(id)]
					var key: String = str(int(property["attribute_id"]))
					expected[key] = expected.get(key,0) + property["values"][n]
			check(Rules.raw_properties(int(item["id"]),n) == expected,"all gear curves %d +%d" % [item["id"],n])
	var production: int = 0
	for affix: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data/original/affix_rules.json"))["records"]:
		if affix["is_test"]: continue
		production += 1
		var stats: Dictionary = actor()
		stats["inventory"][str(int(affix["id"]))] = 1
		var plan: Dictionary = Rules.affix_plan(stats,10003,{},int(affix["id"]))
		check(plan["ok"],"production affix usable %d" % affix["id"])
		if not plan["ok"]: continue
		var raw: Dictionary = Rules.bonuses(10003,plan["state"])["raw_bonus"]
		for effect: Dictionary in affix["effects"]:
			var key: String = str(int(effect["attribute_id"]))
			check(raw[key] == float(effect["value"])+(260.0 if key == "20" else 0.0),"exact source double %d" % affix["id"])
	check(production == 42,"all 42 production affixes")
	var suits: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/suit_rules.json"))["records"]
	check(suits.size() == 41,"all 41 suits")
	for suit: Dictionary in suits:
		var members: Dictionary = {}
		for member: Dictionary in suit["members"]:
			if int(member["item_id"]) != 0: members[int(member["item_id"])] = int(member["item_id"])
		for id: Variant in suit["gear_footer_members"]:
			if int(id) != 0: members[int(id)] = int(id)
		var actual: Dictionary = Rules.suit_bonuses(members)
		check(actual["suit_piece_counts"].get(str(int(suit["id"])),0) == members.size(),"complete membership union %d" % suit["id"])
