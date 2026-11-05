class_name TownBuilder
extends Node3D

## Assembles Guanlin Town buildings from the CC0 Quaternius modular village kit
## (assets/village, 2 m wall cells, 3 m storeys) following GuanlinLayout.

const KIT: String = "res://assets/village/%s.gltf"
const CELL: float = 2.0
const STOREY: float = 3.0

var _cache: Dictionary = {}

func piece(name: String) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load(KIT % name)
	return (_cache[name] as PackedScene).instantiate()

func place(parent: Node3D, name: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var node: Node3D = piece(name)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(node)
	return node

## A rectangular house of w x d wall cells and the given storeys.
## spec keys: base ("UnevenBrick" | "Plaster"), upper ("Plaster" | "UnevenBrick"),
## door (cell index on the front side), roof (kit roof name or ""), gable (front piece),
## chimney (bool), windows ("Wide_Round" etc.).
func house(pos: Vector3, yaw_deg: float, w: int, d: int, storeys: int, spec: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	add_child(root)
	var hw: float = w * CELL * 0.5
	var hd: float = d * CELL * 0.5
	var sides: Array = [
		[Vector3(0, 0, hd), 0.0, w, Vector3(1, 0, 0)],      # front (+Z)
		[Vector3(0, 0, -hd), 180.0, w, Vector3(-1, 0, 0)],  # back
		[Vector3(hw, 0, 0), 90.0, d, Vector3(0, 0, -1)],    # right (+X)
		[Vector3(-hw, 0, 0), -90.0, d, Vector3(0, 0, 1)],   # left
	]
	var window: String = spec.get("windows", "Wide_Round")
	for s: int in storeys:
		var y: float = s * STOREY
		var style: String = spec.get("base", "UnevenBrick") if s == 0 else spec.get("upper", "Plaster")
		for side_i: int in sides.size():
			var side: Array = sides[side_i]
			var count: int = side[2]
			for c: int in count:
				var offset: float = (c - (count - 1) * 0.5) * CELL
				var p: Vector3 = side[0] + side[3] * offset + Vector3(0, y, 0)
				var kind: String = "Straight"
				if s == 0 and side_i == 0 and c == int(spec.get("door", count / 2)):
					kind = "Door_Round"
				elif (c + side_i) % 2 == 1:
					kind = "Window_" + window
				var name: String = "Wall_%s_%s" % [style, kind]
				if style == "Plaster" and kind == "Straight" and spec.get("timber", true):
					name = "Wall_Plaster_WoodGrid"
				place(root, name, p, side[1])
				if kind == "Door_Round":
					place(root, "Door_1_Round", p + side[3] * -0.53 + Vector3(0, 0, 0.02), side[1])
				elif kind.begins_with("Window"):
					place(root, "Window_" + window + "1", p, side[1])
		for corner: Vector3 in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
			place(root, "Corner_Exterior_Wood" if style == "Plaster" else "Corner_Exterior_Brick", corner + Vector3(0, y, 0))
		if s > 0:
			for side: Array in sides:
				for c: int in side[2]:
					var off: float = (c - (side[2] - 1) * 0.5) * CELL
					place(root, "Wall_BottomCover", side[0] + side[3] * off + Vector3(0, y, 0), side[1])
	var top: float = storeys * STOREY
	var roof: String = spec.get("roof", "")
	if roof != "":
		place(root, roof, Vector3(0, top, 0), spec.get("roof_yaw", 0.0))
		var gable: String = spec.get("gable", "")
		if gable != "":
			place(root, gable, Vector3(0, top, hd), 0.0)
			place(root, gable, Vector3(0, top, -hd), 180.0)
	if spec.get("chimney", false):
		place(root, "Prop_Chimney", Vector3(hw - 1.0, top + 1.0, -hd + 1.0))
	_solid(root, Vector3(0, top * 0.5, 0), Vector3(w * CELL, top, d * CELL))
	return root

func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1 | 4   # characters and camera obstruction
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
