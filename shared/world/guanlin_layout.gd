class_name GuanlinLayout
extends RefCounted

## Guanlin Town plan, adapted from the original city_guanlinzhen.wim grid
## (docs/reference/guanlin). The original 50x50 isometric tiles map to metres:
## x = (tile_y - 22) * TILE, z = TOWN_Z + (tile_x - 21) * TILE. The original east
## gate to Sunny Forest faces +Z, where the forest area of this scene begins.
## Positions follow the original districts; the look is a modern reinterpretation.

const TILE: float = 1.6
const TOWN_Z: float = -30.0
const GATE_Z: float = 12.0
const BOUNDS_MIN: Vector2 = Vector2(-46.0, -72.0)
const BOUNDS_MAX: Vector2 = Vector2(46.0, 66.0)

## Road centre lines: [from, to, width]. The original crossroads sits at tile (21, 22).
const ROADS: Array = [
	[Vector3(0, 0, -66), Vector3(0, 0, GATE_Z + 4.0), 7.0],   # west square -> forest gate
	[Vector3(-34, 0, TOWN_Z), Vector3(38, 0, TOWN_Z), 6.0],   # north-south high street
]

## Landmarks: id -> [position, yaw_degrees, footprint (x, z)].
const BUILDINGS: Dictionary = {
	"chapel": [Vector3(-27.0, 0, -41.0), 90.0, Vector2(11, 15)],
	"tavern": [Vector3(-3.0, 0, -61.0), 0.0, Vector2(14, 10)],
	"stall_consignment": [Vector3(-21.0, 0, -20.0), 90.0, Vector2(6, 16)],
	"stall_market_n": [Vector3(-11.2, 0, -17.2), 0.0, Vector2(5, 5)],
	"stall_market_s": [Vector3(8.0, 0, -4.4), 0.0, Vector2(5, 5)],
	"stall_gate": [Vector3(-9.6, 0, 0.4), 0.0, Vector2(5, 5)],
	"signpost": [Vector3(0.0, 0, -55.0), 0.0, Vector2(1, 1)],
	"gate": [Vector3(0.0, 0, GATE_Z), 0.0, Vector2(9, 2)],
}

## Palisade runs: closed town wall with a single opening at the forest gate.
const PALISADE: Array = [
	[Vector3(-40, 0, GATE_Z), Vector3(-4.5, 0, GATE_Z)],
	[Vector3(4.5, 0, GATE_Z), Vector3(40, 0, GATE_Z)],
	[Vector3(-40, 0, GATE_Z), Vector3(-40, 0, -68)],
	[Vector3(40, 0, GATE_Z), Vector3(40, 0, -68)],
	[Vector3(-40, 0, -68), Vector3(40, 0, -68)],
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
