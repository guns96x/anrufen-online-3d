extends SceneTree
var failures: int = 0
func check(ok: bool,label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	TreeCollision.add_to(stage)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-2,1,0),Vector3(2,1,0),1)).is_empty(),"tree trunk physically blocks movement layer")
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-4,4,0),Vector3(4,4,0),1)).is_empty(),"leaf crown does not create a player movement wall")
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-4,4,0),Vector3(4,4,0),8)).is_empty(),"leaf crown obstructs dedicated camera layer")
	stage.free()
	var world: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await physics_frame
	await physics_frame
	world.local_player.set_physics_process(false)
	for monster: Node in get_nodes_in_group("monsters"): monster.set_physics_process(false)
	check(world.local_player.spring_arm.collision_mask == 9,"orbit camera checks both buildings and canopy")
	var pathfinder: GridPathfinder = GridPathfinder.new()
	for id: int in ForestForage.POINTS:
		check(not pathfinder.find_route(Vector3(4.5,0,6),ForestForage.POINTS[id],world.get_world_3d().direct_space_state).is_empty(),"gathering patch reachable around physical obstacles "+str(id))
	world.local_player.position = ForestForage.POINTS[1]+Vector3(0,0,2)
	for frame: int in 4: await physics_frame
	var query: PhysicsPointQueryParameters3D = PhysicsPointQueryParameters3D.new()
	query.position = world.local_player.camera.global_position
	query.collision_mask = 8
	check(world.get_world_3d().direct_space_state.intersect_point(query).is_empty(),"camera stays outside opaque forest canopy near first gathering patch")
	world.queue_free()
	await process_frame
	await process_frame
	print("FOREST_NAVIGATION_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
