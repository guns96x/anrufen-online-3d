class_name GuanlinLayout
extends RefCounted

## Guanlin Town plan, adapted from the original city_guanlinzhen.wim grid
## (docs/reference/guanlin). The original 50x50 isometric tiles map to metres:
## x = (tile_y - 22) * TILE, z = TOWN_Z + (tile_x - 21) * TILE. The original east
## gate to Sunny Forest faces +Z, where the forest area of this scene begins.
## Districts and citizens follow the original; the look is a modern reinterpretation.

const TILE: float = 1.6
const TOWN_Z: float = -30.0
const GATE_Z: float = 12.0
const PLAZA: Vector3 = Vector3(0, 0, TOWN_Z)
const PLAZA_RADIUS: float = 6.5
const BOUNDS_MIN: Vector2 = Vector2(-46.0, -74.0)
const BOUNDS_MAX: Vector2 = Vector2(46.0, 66.0)

## Road centre lines: [from, to, half width]. The original crossroads sits at tile (21, 22).
const ROADS: Array = [
	[Vector2(0, -56), Vector2(0, GATE_Z + 4.0), 3.4],   # tavern -> plaza -> forest gate
	[Vector2(-34, TOWN_Z), Vector2(38, TOWN_Z), 3.0],    # cross street (original north-south road)
]

## Kit houses: [id, position, yaw_deg, cells_w, cells_d, storeys, spec]. Front faces local +Z.
const HOUSES: Array = [
	["chapel", Vector3(-27, 0, -41), 90.0, 3, 7, 1, {"base": "UnevenBrick", "roof": "Roof_RoundTiles_6x14", "gable": "Roof_Front_Brick6", "door": 1, "windows": "Thin_Round"}],
	["chapel_tower", Vector3(-27, 0, -51), 90.0, 2, 2, 3, {"base": "UnevenBrick", "upper": "UnevenBrick", "roof": "Roof_Tower_RoundTiles", "door": 9, "windows": "Thin_Round"}],
	["tavern", Vector3(0, 0, -62.5), 0.0, 4, 6, 2, {"roof": "Roof_RoundTiles_8x12", "gable": "Roof_Front_Brick8", "door": 1, "chimney": true}],
	["mayor_house", Vector3(13, 0, -46), -90.0, 3, 4, 2, {"roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6", "chimney": true}],
	["home_ne1", Vector3(25, 0, -53), -90.0, 3, 3, 2, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6"}],
	["home_ne2", Vector3(25, 0, -42), -90.0, 3, 3, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6", "chimney": true}],
	["home_kids", Vector3(-15, 0, -57), 0.0, 3, 3, 2, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6"}],
	["alchemy", Vector3(16, 0, -19), -90.0, 3, 4, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6", "chimney": true}],
	["smithy", Vector3(16, 0, -3), -90.0, 3, 3, 1, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6", "chimney": true}],
	["inn", Vector3(-14, 0, 3), 90.0, 3, 4, 2, {"roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6"}],
	["home_sw", Vector3(-30, 0, -3), 90.0, 3, 3, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6"}],
	["home_w", Vector3(-31, 0, -62), 0.0, 3, 3, 2, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6", "chimney": true}],
]

## Market canopies: [position, yaw_deg, length_m, cloth colour].
const STALLS: Array = [
	[Vector3(-21, 0, -19), 90.0, 18.0, Color("7d3b2e")],   # consignment arcade (six traders)
	[Vector3(-11.2, 0, -16.5), 0.0, 4.0, Color("2f5d7c")],
	[Vector3(8.5, 0, -6.5), 0.0, 4.0, Color("8a6a2a")],
	[Vector3(6.5, 0, 2.5), 0.0, 4.0, Color("4b6b3a")],
]

const TRAINING_DUMMIES: Array = [Vector3(13, 0, -25), Vector3(15.5, 0, -25), Vector3(18, 0, -25)]

## Closed town palisade with a single opening at the forest gate.
const PALISADE: Array = [
	[Vector2(-40, GATE_Z), Vector2(-4.5, GATE_Z)],
	[Vector2(4.5, GATE_Z), Vector2(40, GATE_Z)],
	[Vector2(-40, GATE_Z), Vector2(-40, -70)],
	[Vector2(40, GATE_Z), Vector2(40, -70)],
	[Vector2(-40, -70), Vector2(40, -70)],
]

## Every citizen of the original scene record 120005 with its source tile.
## [citizen_id, role, position, original sprite archetype]
const CITIZENS: Array = [
	[50164, "mayor", Vector3(3.2, 0, -49.2), "forest_town_mayor"],
	[50165, "ranger", Vector3(6.4, 0, -41.2), "warrior"],
	[50166, "militia_captain", Vector3(-6.4, 0, -25.2), "guard"],
	[50167, "gourmand", Vector3(-14.4, 0, -34.8), "stout_man"],
	[50168, "widow_anna", Vector3(-9.6, 0, -36.4), "woodcutter_wife"],
	[50169, "smuggler", Vector3(9.6, 0, -26.8), "youth"],
	[50170, "madman", Vector3(-14.4, 0, -26.8), "coachman"],
	[50171, "madmans_wife", Vector3(8.0, 0, -15.6), "woodcutter_wife"],
	[50172, "tribune", Vector3(-9.6, 0, -41.2), "town_mayor"],
	[50173, "tom", Vector3(-11.2, 0, -49.2), "youth"],
	[50174, "jessie", Vector3(-14.4, 0, -47.6), "girl"],
	[50175, "alchemist", Vector3(8.0, 0, -18.8), "mage"],
	[50176, "breeder", Vector3(8.0, 0, -23.6), "tamer"],
	[50177, "doctor_jack", Vector3(6.4, 0, -36.4), "mage"],
	[50183, "mailbox", Vector3(4.8, 0, -10.8), "mailbox"],
	[50182, "jeweller", Vector3(-6.4, 0, -4.4), "girl"],
	[50180, "beast_tamer", Vector3(-3.2, 0, -20.4), "peddler"],
	[50179, "weapon_merchant", Vector3(8.0, 0, -10.8), "blacksmith"],
	[50178, "item_merchant", Vector3(4.8, 0, 0.4), "merchant"],
	[50203, "resident", Vector3(-24.0, 0, 3.6), "resident"],
	[50203, "resident", Vector3(-17.6, 0, -6.0), "resident"],
	[50204, "resident", Vector3(19.2, 0, -52.4), "resident"],
	[50204, "resident", Vector3(19.2, 0, -42.8), "resident"],
	[50184, "stable_master", Vector3(-6.4, 0, -10.8), "coachman"],
	[50427, "mystery_merchant", Vector3(8.0, 0, -52.4), "horse_city_lord"],
	[50440, "arena_steward", Vector3(14.4, 0, -36.4), "general"],
	[50181, "consign_gems", Vector3(-17.6, 0, -15.6), "fruit_picker"],
	[50490, "consign_weapons", Vector3(-17.6, 0, -26.8), "fruit_picker"],
	[50492, "consign_armor", Vector3(-17.6, 0, -22.0), "fruit_picker"],
	[50493, "consign_jewelry", Vector3(-24.0, 0, -26.8), "fruit_picker"],
	[50494, "consign_beasts", Vector3(-17.6, 0, -10.8), "fruit_picker"],
	[50495, "consign_goods", Vector3(-24.0, 0, -18.8), "fruit_picker"],
	[50027, "armor_merchant", Vector3(8.0, 0, 5.2), "blacksmith"],
	[50030, "accessory_merchant", Vector3(-3.2, 0, 3.6), "girl"],
]

## Original player arrival tile (42, 22): just inside the forest gate.
const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0, 3.6)

## XZ rectangles that set dressing must keep clear (roads, plaza, buildings).
static func blocked_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for road: Array in ROADS:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var hw: float = road[2] + 0.8
		rects.append(Rect2(minf(a.x, b.x) - hw, minf(a.y, b.y) - hw, absf(b.x - a.x) + hw * 2.0, absf(b.y - a.y) + hw * 2.0))
	rects.append(Rect2(PLAZA.x - PLAZA_RADIUS - 1.0, PLAZA.z - PLAZA_RADIUS - 1.0, PLAZA_RADIUS * 2.0 + 2.0, PLAZA_RADIUS * 2.0 + 2.0))
	for h: Array in HOUSES:
		var p: Vector3 = h[1]
		var quarter: bool = absf(fmod(float(h[2]), 180.0)) > 45.0
		var sx: float = (h[4] if quarter else h[3]) * 2.0 + 3.0
		var sz: float = (h[3] if quarter else h[4]) * 2.0 + 3.0
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
