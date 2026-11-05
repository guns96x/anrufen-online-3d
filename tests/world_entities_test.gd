extends SceneTree
const Loot = preload("res://client/scenes/entities/ground_loot.gd")
const Follower = preload("res://client/scenes/entities/companion_follower.gd")
var failures: int = 0
var stage: Node3D
var actor: Player
var items: InventorySystem

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func make_loot(contents: Dictionary, copper: int, position: Vector3 = Vector3.ZERO):
	var loot = Loot.new()
	loot.contents = contents
	loot.copper = copper
	loot.position = position
	stage.add_child(loot)
	return loot

func run() -> void:
	seed(55)
	stage = Node3D.new()
	root.add_child(stage)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.position.y = -0.5
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(100,1,100)
	floor_shape.shape = floor_box
	ground.add_child(floor_shape)
	stage.add_child(ground)
	actor = load("res://client/scenes/entities/player.tscn").instantiate()
	stage.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.position = Vector3.ZERO
	items = InventorySystem.new()
	items.bind_player(actor)
	actor.stats["inventory"] = {}
	actor.stats["copper"] = 100
	actor.stats["bag_capacity"] = 32
	var loot = make_loot({"30016":2},10,Vector3(8,0,0))
	check(not loot.pickup(items) and actor.stats["copper"] == 100,"distant loot cannot award")
	loot.position = Vector3(1,0,0)
	actor.is_dead = true
	check(not loot.pickup(items),"dead player cannot pick up")
	actor.is_dead = false
	check(loot.pickup(items) and actor.stats["copper"] == 110 and items.count_item(30016) == 2,"nearby loot awards whole stack and coins")
	check(not loot.pickup(items) and actor.stats["copper"] == 110 and items.count_item(30016) == 2,"repeat pickup cannot duplicate")
	actor.stats["bag_capacity"] = 1
	actor.stats["inventory"] = {"30016":1}
	var partial = make_loot({"30016":1,"30645":1},7)
	check(partial.pickup(items) and items.count_item(30016) == 2 and actor.stats["copper"] == 117,"full bag can take matching stack and coins")
	check(partial.contents == {"30645":1} and partial.copper == 0,"uncollected stack remains on ground")
	check(not partial.pickup(items) and actor.stats["copper"] == 117,"full bag cannot duplicate partial coins")
	items.remove_item(30016,2)
	check(partial.pickup(items) and items.count_item(30645) == 1,"freed bag slot collects remaining loot")
	check(not partial.pickup(items),"finished partial pickup guarded")
	var invalid = make_loot({"30016":1,"999999999":1},100)
	check(not invalid.pickup(items) and actor.stats["copper"] == 117,"unknown entry rejects entire packet before coins")
	invalid.contents = {"30016":"1"}
	check(not invalid.pickup(items),"string quantity rejected")
	invalid.contents = {"30016":-1}
	check(not invalid.pickup(items),"negative stack rejected")
	invalid.contents = {}
	invalid.copper = -1
	check(not invalid.pickup(items),"negative coins rejected")
	var expiry = make_loot({},1)
	expiry.lifetime = 0.05
	var expiry_signals: Array[int] = [0]
	expiry.expired.connect(func() -> void: expiry_signals[0] += 1)
	expiry._process(0.06)
	expiry._process(0.06)
	check(expiry_signals[0] == 1 and not expiry.pickup(items),"expired loot cannot award and expires once")
	var companions: CompanionSystem = CompanionSystem.new()
	companions.bind_player(actor)
	actor.stats["companions"] = [{"uid":"test-pet", "species_id":140001,"name":"Веприк","level":5,"exp":0,"hp":100,"max_hp":100,"hunger":100,"born_at":1000.0,"skills":[90014]}]
	var follower = Follower.new()
	follower.owner_player = actor
	follower.companions = companions
	stage.add_child(follower)
	follower.set_physics_process(false)
	check(not follower.visible and follower.current_uid == "","follower hidden when no pet summoned")
	companions.summon("test-pet")
	follower._physics_process(0.016)
	check(follower.visible and follower.current_uid == "test-pet" and follower.collision_layer == 0 and follower.collision_mask == 1,"summoning binds nonblocking world follower")
	var enemy: Monster = load("res://client/scenes/entities/monster.tscn").instantiate()
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.max_hp = 1000
	enemy.current_hp = 1000
	enemy.stats["evasion"] = 0.0
	enemy.global_position = follower.global_position + Vector3(0,0,1)
	actor.current_target = enemy
	actor.is_dead = true
	follower._physics_process(0.016)
	check(enemy.current_hp == 1000,"pet cannot attack while owner dead")
	actor.is_dead = false
	actor.controls_blocked = true
	follower._physics_process(0.016)
	check(enemy.current_hp == 1000,"pet cannot attack through modal controls lock")
	actor.controls_blocked = false
	follower._physics_process(0.016)
	check(enemy.current_hp < 1000,"pet attacks nearby legal player target")
	var after_hit: int = enemy.current_hp
	follower._physics_process(0.016)
	check(enemy.current_hp == after_hit,"pet attack obeys cooldown")
	enemy.global_position = Vector3(11,0,0)
	follower._physics_process(2.0)
	check(enemy.current_hp == after_hit,"pet cannot deal damage beyond reach")
	actor.current_target = null
	follower.global_position = Vector3(40,0,40)
	follower._physics_process(0.016)
	check(follower.global_position.distance_to(actor.global_position) < 4.0,"stuck or distant pet returns to owner")
	companions.dismiss()
	follower._physics_process(0.016)
	check(not follower.visible and follower.current_uid == "","dismissal removes follower from play")
	stage.queue_free()
	await process_frame
	await process_frame
	print("WORLD_ENTITIES_SUITE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
