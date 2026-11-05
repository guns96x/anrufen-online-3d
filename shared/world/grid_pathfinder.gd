class_name GridPathfinder
extends RefCounted

const CELL: float = 1.5
const MIN_CELL: Vector2i = Vector2i(int(GuanlinLayout.BOUNDS_MIN.x / CELL), int(GuanlinLayout.BOUNDS_MIN.y / CELL))
const MAX_CELL: Vector2i = Vector2i(int(GuanlinLayout.BOUNDS_MAX.x / CELL), int(GuanlinLayout.BOUNDS_MAX.y / CELL))
var blocked: Dictionary = {}
var _shape: SphereShape3D = SphereShape3D.new()

func _init() -> void:
	_shape.radius = 0.55

func _world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))

func _is_blocked(cell: Vector2i, space: PhysicsDirectSpaceState3D) -> bool:
	if not blocked.has(cell):
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = _shape
		query.transform.origin = _world(cell) + Vector3.UP
		query.collision_mask = 1
		blocked[cell] = not space.intersect_shape(query, 1).is_empty()
	return blocked[cell]

func find_route(start: Vector3, end: Vector3, space: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	var first: Vector2i = _cell(start)
	var goal: Vector2i = _cell(end)
	var result: PackedVector3Array = []
	if _is_blocked(goal, space):
		return result
	var open: Array[Vector2i] = [first]
	var previous: Dictionary = {}
	var cost: Dictionary = {first: 0}
	var closed: Dictionary = {}
	var steps: int = 0
	while not open.is_empty() and steps < 5000:
		steps += 1
		var best: int = 0
		var score: int = 999999
		for i: int in open.size():
			var node: Vector2i = open[i]
			var value: int = int(cost[node]) + absi(node.x-goal.x) + absi(node.y-goal.y)
			if value < score:
				score = value
				best = i
		var current: Vector2i = open.pop_at(best)
		if current == goal:
			var reverse: Array[Vector3] = [end]
			while current != first:
				reverse.append(_world(current))
				current = previous[current]
			reverse.reverse()
			return PackedVector3Array(reverse)
		closed[current] = true
		for offset: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = current + offset
			if next.x < MIN_CELL.x or next.x > MAX_CELL.x or next.y < MIN_CELL.y or next.y > MAX_CELL.y or closed.has(next) or _is_blocked(next,space):
				continue
			var next_cost: int = int(cost[current]) + 1
			if next_cost < int(cost.get(next, 999999)):
				cost[next] = next_cost
				previous[next] = current
				if next not in open:
					open.append(next)
	return result
