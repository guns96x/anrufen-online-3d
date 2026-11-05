class_name Minimap
extends Control

## Player-centred round minimap. Draws monsters, NPCs (with quest markers) and town outline.

@export var world_units_visible: float = 70.0 # diameter in world units

var hud: Node = null
var _player: Node3D = null
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font

func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("players") as Node3D
	queue_redraw()

func _world_to_map(world: Vector3, center: Vector3, cam_yaw: float, scale_px: float) -> Vector2:
	var d: Vector2 = Vector2(world.x - center.x, world.z - center.z).rotated(-cam_yaw)
	return size / 2.0 + d * scale_px

func _draw() -> void:
	var r: float = minf(size.x, size.y) / 2.0
	var c: Vector2 = size / 2.0
	draw_circle(c, r, Color(0.06, 0.1, 0.08, 0.72))
	if _player == null:
		return
	var scale_px: float = (r * 2.0) / world_units_visible
	var center: Vector3 = _player.global_position
	var cam_yaw: float = 0.0
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var fwd: Vector3 = -cam.global_transform.basis.z
		cam_yaw = atan2(fwd.x, -fwd.z)

	# Town plaza / road outline
	for z: float in [-30.0, -20.0, -10.0, 0.0, 10.0, 20.0, 30.0]:
		var p: Vector2 = _world_to_map(Vector3(0, 0, z), center, cam_yaw, scale_px)
		if p.distance_to(c) < r - 3.0:
			draw_circle(p, 3.0 * scale_px * 2.0, Color(0.55, 0.5, 0.42, 0.35))

	for m: Node in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and not m.is_dead():
			var p: Vector2 = _world_to_map(m.global_position, center, cam_yaw, scale_px)
			if p.distance_to(c) < r - 3.0:
				draw_circle(p, 3.0, Color(1.0, 0.3, 0.25))

	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if n is Node3D:
			var p: Vector2 = _world_to_map(n.global_position, center, cam_yaw, scale_px)
			var marker: String = ""
			var qid: int = n.get("quest_id") if n.get("quest_id") != null else 0
			if hud and hud.has_method("get_npc_marker"):
				marker = hud.get_npc_marker(n)
			elif hud and hud.has_method("get_quest_state"):
				var st: int = hud.get_quest_state(qid)
				if GameHUD.QUESTS.has(qid):
					if st == GameHUD.QuestState.NONE:
						marker = "!"
					elif st == GameHUD.QuestState.READY:
						marker = "?"
			if p.distance_to(c) > r - 6.0:
				# Clamp quest givers to the rim so they can always be found
				if marker == "":
					continue
				p = c + (p - c).normalized() * (r - 6.0)
			draw_circle(p, 4.0, Color(1.0, 0.85, 0.3))
			if marker != "":
				draw_string(_font, p + Vector2(-3, -6), marker, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.95, 0.3))

	# Player arrow (always points up = camera forward)
	var fwd2: Vector2 = Vector2(0, -1)
	var vis: Node3D = _player.get_node_or_null("Visual")
	if vis:
		var pf: Vector3 = -vis.global_transform.basis.z
		fwd2 = Vector2(pf.x, pf.z).rotated(-cam_yaw).normalized()
	var side: Vector2 = Vector2(-fwd2.y, fwd2.x)
	var tip: Vector2 = c + fwd2 * 8.0
	draw_colored_polygon(PackedVector2Array([tip, c - fwd2 * 5.0 + side * 5.0, c - fwd2 * 2.0, c - fwd2 * 5.0 - side * 5.0]), Color(0.4, 0.85, 1.0))
	draw_arc(c, r - 1.0, 0.0, TAU, 48, Color(0.45, 0.7, 1.0, 0.8), 2.0, true)
