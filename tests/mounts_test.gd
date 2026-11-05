extends SceneTree
const Mounts = preload("res://shared/mounts/mount_system.gd")
const Visual = preload("res://client/scenes/entities/mount_visual.gd")
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	ItemCatalog.ensure_loaded()
	for id: int in [10116,10063,10086,10018,10085,10087]:
		var item: Dictionary = ItemCatalog.get_item(id)
		check(item.get("kind") == "mount" and item.get("max_stack") == 1 and item.get("slot") == "" and item.get("buy_price") == 200,"source mount registered outside equipment slots " + str(id))
	check(10018 in ItemCatalog.shop_items(),"starter shop offers original green vulture")
	var stats: Dictionary = {"hp":100,"inventory":{}}
	Mounts.ensure_stats(stats)
	check(stats["mount_id"] == 0 and not stats["mounted"] and Mounts.validate(stats),"new unmounted state initializes")
	check(not Mounts.mount(stats,999999),"unknown mount rejected")
	check(not Mounts.mount(stats,10010),"ordinary weapon cannot be ridden")
	check(not Mounts.mount(stats,10018),"mount requires owned item")
	stats["inventory"]["10018"] = "1"
	check(not Mounts.mount(stats,10018),"string bag count rejected")
	stats["inventory"]["10018"] = 1
	stats["hp"] = 0
	check(not Mounts.mount(stats,10018),"fallen player cannot mount")
	stats["hp"] = 100
	check(Mounts.mount(stats,10018) and stats["mounted"] and stats["mount_id"] == 10018,"owned mount can be ridden")
	check(not Mounts.mount(stats,10018) and stats["inventory"]["10018"] == 1,"repeated mount is harmless and keeps owned item")
	check(is_equal_approx(Mounts.speed_multiplier(stats),1.6) and is_equal_approx(Mounts.damage_multiplier(stats),0.5) and not Mounts.can_attack(stats),"riding applies provisional speed/reduction and forbids attacks")
	check(Mounts.validate(JSON.parse_string(JSON.stringify(stats))),"mounted JSON numeric roundtrip validates")
	stats["inventory"]["10085"] = 1
	check(Mounts.mount(stats,10085) and stats["mount_id"] == 10085,"owned mount can be switched")
	Mounts.dismount(stats)
	check(not stats["mounted"] and stats["mount_id"] == 10085 and Mounts.can_attack(stats),"dismount retains selected item and restores attacks")
	check(Mounts.speed_multiplier(stats) == 1.0 and Mounts.damage_multiplier(stats) == 1.0,"dismount restores movement and incoming damage")
	var bad: Dictionary = stats.duplicate(true)
	bad["mounted"] = true
	bad["inventory"].erase("10085")
	check(not Mounts.validate(bad) and Mounts.speed_multiplier(bad) == 1.0,"unowned ridden mount cannot grant movement")
	bad = stats.duplicate(true)
	bad["mount_id"] = 10010
	check(not Mounts.validate(bad),"invalid selected mount rejected")
	bad = stats.duplicate(true)
	bad["mounted"] = "true"
	check(not Mounts.validate(bad) and not Mounts.mount(bad,10018),"malformed mounted type rejected safely")
	bad = stats.duplicate(true)
	bad["mount_id"] = true
	check(not Mounts.validate(bad),"boolean mount ID rejected")
	bad = stats.duplicate(true)
	bad["mount_id"] = 10018.5
	check(not Mounts.validate(bad),"fractional mount ID rejected")
	var actor: Player = load("res://client/scenes/entities/player.tscn").instantiate()
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.stats["inventory"] = {"10018":1}
	Mounts.ensure_stats(actor.stats)
	var presentation = Visual.new()
	presentation.player = actor
	actor.add_child(presentation)
	presentation.set_process(false)
	check(not presentation.visible,"mount visual hidden while walking")
	Mounts.mount(actor.stats,10018)
	presentation._process(0.0)
	check(presentation.visible,"mount visual shown while riding")
	var triangles: int = 0
	for node: Node in presentation.find_children("*","MeshInstance3D",true,false):
		triangles += int(node.mesh.get_faces().size()/3)
	check(triangles > 0 and triangles <= 2000,"bird silhouette stays under 2000 triangles: " + str(triangles))
	actor.visual_root.rotation.y = 0.7
	presentation._process(0.0)
	check(is_equal_approx(presentation.rotation.y,0.7),"mount follows facing without changing player visual")
	Mounts.dismount(actor.stats)
	presentation._process(0.0)
	check(not presentation.visible,"mount visual hides on dismount")
	actor.queue_free()
	await process_frame
	await process_frame
	print("MOUNTS_SUITE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
