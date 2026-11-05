class_name ForestForage
extends RefCounted

## Source task80009 requires five wild vegetables (prop30039). Placement,
## yield and regrowth timing adapt gathering to the present 3D forest.
const REGROW_SECONDS: float = 60.0
const POINTS: Dictionary = {
	1:Vector3(-11,0,19),2:Vector3(-17,0,23),3:Vector3(-22,0,18),
	4:Vector3(10,0,25),5:Vector3(18,0,22),6:Vector3(22,0,16),
}
var ready_at: Dictionary = {}

func harvest(id: int, position: Vector3, inventory: InventorySystem, now: float) -> bool:
	if not POINTS.has(id) or not is_finite(now) or now < 0 or position.distance_to(POINTS[id]) > 2.8: return false
	if not is_instance_valid(inventory.player) or int(inventory.player.get("stats").get("hp",0)) <= 0: return false
	if now < float(ready_at.get(id,0)) or not inventory.can_add(30039): return false
	if not inventory.add_item(30039): return false
	ready_at[id] = now+REGROW_SECONDS
	return true

func available(id: int, now: float) -> bool:
	return POINTS.has(id) and now >= float(ready_at.get(id,0))

func snapshot(now: float) -> Dictionary:
	var result: Dictionary = {}
	for id: int in POINTS: result[str(id)] = available(id,now)
	return result
