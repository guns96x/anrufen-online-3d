extends SceneTree
## Client half of tools/check_dedicated.py: joins a headless dedicated server and
## checks that the world is server-owned (no host avatar, movement applied remotely).
var failures: int = 0
var net: Node

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	net = root.get_node("NetworkManager")
	net.persistence_enabled = false
	net.local_player_data = {"name": "Dedicated Client"}
	check(net.start_client("127.0.0.1", 17903), "client connects to the dedicated server")
	var deadline: int = Time.get_ticks_msec() + 5000
	while net.world_snapshot.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not net.world_snapshot.is_empty(), "received the server world")
	if net.world_snapshot.is_empty():
		_finish()
		return
	var actors: Dictionary = net.world_snapshot["state"]["actors"]
	check(actors.size() == 1, "dedicated host has no avatar of its own")
	var own: int = int(net.world_snapshot["own_id"])
	var start: Vector3 = actors[own]["position"] if actors.has(own) else actors[str(own)]["position"]
	deadline = Time.get_ticks_msec() + 2500
	var moved: bool = false
	while Time.get_ticks_msec() < deadline and not moved:
		net.send_world_input(Vector2(0, -1), 0.0)
		await process_frame
		var now_actors: Dictionary = net.world_snapshot["state"]["actors"]
		var row: Dictionary = now_actors.get(own, now_actors.get(str(own), {}))
		moved = not row.is_empty() and Vector3(row["position"]).distance_to(start) > 0.5
	check(moved, "server applies movement input and sends it back")
	check(net.world_snapshot["state"].get("monsters", {}).size() > 0, "server simulates the forest monsters")
	_finish()

func _finish() -> void:
	print("DEDICATED_CLIENT: ", "PASS" if failures == 0 else "FAIL")
	net.disconnect_session()
	await process_frame
	quit(0 if failures == 0 else 1)
