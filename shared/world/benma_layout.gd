class_name BenmaLayout
extends RefCounted

## Benma City plan, adapted from the original city-benmacheng.wim grid
## (docs/reference/benma). The original 60x60 isometric tiles map to metres:
## x = (tile_y - 20) * TILE, z = TOWN_Z + (tile_x - 28) * TILE.
## Original default arrival / exit tile (29, 18) leads to Sunshine Steppe at +Z.
## Districts and citizens follow the original; the look is a modern reinterpretation.

const TILE: float = 1.6
const TOWN_Z: float = -30.0
const GATE_Z: float = 12.0
const PLAZA: Vector3 = Vector3(0.0, 0.0, TOWN_Z)
const PLAZA_RADIUS: float = 8.0
const BOUNDS_MIN: Vector2 = Vector2(-46.0, -78.0)
const BOUNDS_MAX: Vector2 = Vector2(70.0, 66.0)

## Road centre lines: [from, to, half width].
const ROADS: Array = [
	[Vector2(0, -60), Vector2(0, GATE_Z + 4.0), 3.6],      # central avenue: city hall -> plaza -> steppe gate
	[Vector2(-34, TOWN_Z), Vector2(50, TOWN_Z), 3.2],       # cross street (market arcade -> plaza -> orc district)
	[Vector2(-18, -60), Vector2(-18, -8), 2.8],             # western merchant street
	[Vector2(36, -56), Vector2(36, -6), 2.8],               # eastern residential avenue
]

## Kit houses: [id, position, yaw_deg, cells_w, cells_d, storeys, spec]. Front faces local +Z.
const HOUSES: Array = [
	["city_hall", Vector3(8, 0, -58), 0.0, 4, 5, 2, {"base": "UnevenBrick", "roof": "Roof_RoundTiles_8x10", "gable": "Roof_Front_Brick8", "door": 1, "chimney": true}],
	["barracks", Vector3(-24, 0, -60), 90.0, 3, 4, 2, {"roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6", "door": 1}],
	["smithy", Vector3(-8, 0, -58), 0.0, 3, 3, 1, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6", "chimney": true}],
	["caravan_hall", Vector3(14, 0, -66), 0.0, 3, 4, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6"}],
	["stable", Vector3(38, 0, -28), -90.0, 3, 5, 1, {"roof": "Roof_RoundTiles_6x10", "gable": "Roof_Front_Brick6"}],
	["orc_lodge", Vector3(46, 0, -14), -90.0, 3, 5, 2, {"base": "UnevenBrick", "roof": "Roof_RoundTiles_6x10", "gable": "Roof_Front_Brick6", "chimney": true}],
	["armory", Vector3(-18, 0, 0), 90.0, 3, 4, 2, {"roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6", "chimney": true}],
	["jewellery_shop", Vector3(-18, 0, 8), 90.0, 3, 3, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6"}],
	["residence_e", Vector3(26, 0, -38), 90.0, 3, 3, 2, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6"}],
	["inn", Vector3(12, 0, -18), -90.0, 4, 5, 2, {"roof": "Roof_RoundTiles_8x10", "gable": "Roof_Front_Brick8", "chimney": true}],
]

## Market canopies: [position, yaw_deg, length_m, cloth colour].
const STALLS: Array = [
	[Vector3(-28.0, 0, -47.6), 90.0, 20.0, Color("7d3b2e")],  # consignment arcade (five traders)
	[Vector3(-2.0, 0, -16.0), 0.0, 5.0, Color("2f5d7c")],      # town square market
	[Vector3(0.0, 0, -8.0), 0.0, 4.0, Color("4b6b3a")],       # beast tamer stall
	[Vector3(-12.0, 0, -16.0), 0.0, 4.0, Color("8a6a2a")],    # goods vendor stall
]

## Closed town palisade with a single opening at the steppe gate.
const PALISADE: Array = [
	[Vector2(-42, GATE_Z), Vector2(-5.0, GATE_Z)],
	[Vector2(5.0, GATE_Z), Vector2(62, GATE_Z)],
	[Vector2(-42, GATE_Z), Vector2(-42, -72)],
	[Vector2(62, GATE_Z), Vector2(62, -72)],
	[Vector2(-42, -72), Vector2(62, -72)],
]

## Every citizen of original scene record 120056 with its source tile.
## [citizen_id, role, position, original sprite archetype]
const CITIZENS: Array = [
	[50186, "lord", Vector3(8.0, 0, -47.6), "horse_city_lord"],
	[50187, "guard_captain", Vector3(-20.8, 0, -55.6), "orc_warrior"],
	[50189, "caravan_leader", Vector3(12.8, 0, -60.4), "gnome_leader"],
	[50190, "orc_brother", Vector3(40.0, 0, -6.0), "orc_warrior"],
	[50191, "orc_sister", Vector3(40.0, 0, -2.8), "orc_girl"],
	[50192, "lucky_kaka", Vector3(12.8, 0, -55.6), "lucky_kaka"],
	[50193, "war_blacksmith", Vector3(-8.0, 0, -52.4), "blacksmith"],
	[50194, "secretary", Vector3(8.0, 0, -50.8), "girl"],
	[50195, "royal_envoy", Vector3(-16.0, 0, -23.6), "priest"],
	[50197, "orc_villager", Vector3(49.6, 0, -23.6), "orc_resident"],
	[50198, "orc_villager", Vector3(56.0, 0, -7.6), "orc_resident"],
	[50199, "gnome_villager", Vector3(30.4, 0, -62.0), "gnome_resident"],
	[50200, "gnome_villager", Vector3(46.4, 0, -50.8), "gnome_resident"],
	[50201, "resident", Vector3(33.6, 0, -42.8), "resident"],
	[50202, "resident", Vector3(25.6, 0, -31.6), "resident"],
	[50183, "mailbox", Vector3(9.6, 0, 3.6), "mailbox"],
	[50181, "consign_gems", Vector3(-25.6, 0, -42.8), "fruit_picker"],
	[50180, "beast_tamer", Vector3(0.0, 0, -4.4), "peddler"],
	[50178, "item_merchant", Vector3(-14.4, 0, -12.4), "merchant"],
	[50424, "stable_master", Vector3(36.8, 0, -23.6), "coachman"],
	[50188, "knight_envoy", Vector3(1.6, 0, -23.6), "general"],
	[50490, "consign_weapons", Vector3(-25.6, 0, -52.4), "fruit_picker"],
	[50492, "consign_armor", Vector3(-25.6, 0, -47.6), "fruit_picker"],
	[50493, "consign_jewelry", Vector3(-16.0, 0, -34.8), "fruit_picker"],
	[50494, "consign_beasts", Vector3(-16.0, 0, -55.6), "fruit_picker"],
	[50495, "consign_goods", Vector3(-16.0, 0, -30.0), "fruit_picker"],
	[50030, "accessory_merchant", Vector3(-1.6, 0, -52.4), "girl"],
	[50039, "weapon_merchant", Vector3(-3.2, 0, 3.6), "blacksmith"],
	[50044, "jeweller", Vector3(-14.4, 0, 3.6), "girl"],
	[50041, "armor_merchant", Vector3(-14.4, 0, -4.4), "blacksmith"],
	[50061, "magic_chest", Vector3(-3.2, 0, -28.4), "chest"],
]

## Player arrival point facing town plaza from steppe gate.
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0, 3.6)

## Original exit tile (29, 18) to Sunshine Steppe.
const EXIT_TILE: Vector2i = Vector2i(29, 18)
const ORIGINAL_SPAWN_TILE: Vector2i = Vector2i(42, 22)

static func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3((float(tile.y) - 20.0) * TILE, 0.0, TOWN_Z + (float(tile.x) - 28.0) * TILE)

static func world_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(roundi((pos.z - TOWN_Z) / TILE) + 28, roundi(pos.x / TILE) + 20)

## XZ rectangles that set dressing must keep clear (roads, plaza, buildings).
static func blocked_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for road: Array in ROADS:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var hw: float = float(road[2]) + 0.8
		rects.append(Rect2(minf(a.x, b.x) - hw, minf(a.y, b.y) - hw, absf(b.x - a.x) + hw * 2.0, absf(b.y - a.y) + hw * 2.0))
	rects.append(Rect2(PLAZA.x - PLAZA_RADIUS - 1.0, PLAZA.z - PLAZA_RADIUS - 1.0, PLAZA_RADIUS * 2.0 + 2.0, PLAZA_RADIUS * 2.0 + 2.0))
	for h: Array in HOUSES:
		var p: Vector3 = h[1]
		var quarter: bool = absf(fmod(float(h[2]), 180.0)) > 45.0
		var sx: float = (float(h[4]) if quarter else float(h[3])) * 2.0 + 3.0
		var sz: float = (float(h[3]) if quarter else float(h[4])) * 2.0 + 3.0
		rects.append(Rect2(p.x - sx * 0.5, p.z - sz * 0.5, sx, sz))
	return rects

static func on_road(p: Vector2) -> bool:
	if p.distance_to(Vector2(PLAZA.x, PLAZA.z)) < PLAZA_RADIUS:
		return true
	for road: Array in ROADS:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var t: float = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < float(road[2]):
			return true
	return false

## Solid obstacles for the headless server, which has no physics scene:
## building footprints, stalls, the fountain and the palisade with its gate gap.
static func blocks(p: Vector2) -> bool:
	if p.distance_to(Vector2(PLAZA.x, PLAZA.z)) < 2.4:
		return true
	for h: Array in HOUSES:
		var c: Vector3 = h[1]
		var quarter: bool = absf(fmod(float(h[2]), 180.0)) > 45.0
		var hx: float = (float(h[4]) if quarter else float(h[3])) * 1.0 + 0.4
		var hz: float = (float(h[3]) if quarter else float(h[4])) * 1.0 + 0.4
		if absf(p.x - c.x) < hx and absf(p.y - c.z) < hz:
			return true
	for s: Array in STALLS:
		var c: Vector3 = s[0]
		var along_x: bool = absf(fmod(float(s[1]), 180.0)) < 45.0
		var half_long: float = float(s[2]) * 0.5
		if along_x and absf(p.x - c.x) < half_long and absf(p.y - (c.z + 0.6)) < 0.7:
			return true
		if not along_x and absf(p.y - c.z) < half_long and absf(p.x - (c.x + 0.6)) < 0.7:
			return true
	for run: Array in PALISADE:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var t: float = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		if p.distance_to(a.lerp(b, t)) < 0.6:
			return true
	return false
