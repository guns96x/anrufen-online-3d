class_name Balance
extends RefCounted

## Monster numbers by level and role. The Anrufen client carries no monster
## stats (they lived on the server), so these curves are our own model, tuned so
## the Guanlin opening (30 witness kills plus its quests) lands near level 8.
## See docs/balance-model.md.

## role -> multipliers for [hp, attack, defense, evasion, exp]
const ROLES: Dictionary = {
	"beast": [1.0, 1.0, 1.0, 0.04, 1.0],       # boar: sturdy, slow
	"swarm": [0.75, 0.9, 0.7, 0.10, 0.85],     # spider: fragile, evasive
	"hunter": [0.85, 1.15, 0.8, 0.12, 1.0],    # jackal: hits harder, dodges
	"bandit": [1.0, 1.1, 1.1, 0.08, 1.15],     # Viper Gang rogue
	"brute": [1.45, 1.25, 1.4, 0.03, 1.4],     # Viper Gang axe brute
}

static func monster(level: int, role: String) -> Dictionary:
	var r: Array = ROLES.get(role, ROLES["beast"])
	var lv: float = float(maxi(1, level))
	return {
		"level": level,
		"max_hp": roundi(45.0 * pow(1.2, lv - 1.0) * r[0]),
		"attack": roundi((8.0 + 3.0 * lv) * r[1]),
		"defense": roundi((3.0 + 1.8 * lv) * r[2]),
		"evasion": float(r[3]),
		"exp": roundi((20.0 + 14.0 * pow(lv, 1.3)) * r[4]),
	}

## Share of incoming damage that armour removes; stays meaningful at every level.
static func mitigation(defense: float, attacker_level: int) -> float:
	return defense / (defense + 40.0 + 10.0 * float(maxi(1, attacker_level)))

## Original HIT_MODIFY_VALUE: +-3 % hit chance per level of difference, capped at 10 levels.
static func level_hit_bonus(attacker_level: int, defender_level: int) -> float:
	var diff: int = clampi(attacker_level - defender_level, -10, 10)
	if diff == 0:
		return 0.0
	return signf(float(diff)) * float(CombatFormulas.HIT_MODIFY_VALUE[absi(diff)])

## Reads "Рів. N" from a monster's display name when no level was set.
static func level_from_name(name: String) -> int:
	var match: RegExMatch = RegEx.create_from_string("Рів\\.\\s*(\\d+)").search(name)
	return int(match.get_string(1)) if match else 0
