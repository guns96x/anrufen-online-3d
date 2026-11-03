class_name CombatFormulas
extends RefCounted

# Core Combat & Stat Calculation Formulas (Covenant RPG Engine)
# Damage Types
enum DamageType {
	PHY = 1,
	FIRE = 2,
	WATER = 3,
	HOLY = 4,
	DARK = 5
}

# Core combat constants and balance parameters (from game balance tables)
const FATAL_RATE: float = 2.0 # Critical hit multiplier
const MAGIC_SHIELD_RESIST_PER: float = 100.0

# Hit chance modifiers by level difference (HIT_MODIFY_VALUE)
const HIT_MODIFY_VALUE: Dictionary = {
	1: 0.03, 2: 0.06, 3: 0.09, 4: 0.12, 5: 0.15,
	6: 0.18, 7: 0.21, 8: 0.24, 9: 0.27, 10: 0.30
}

# Elemental affinity matrix: [AttackerElement][DefenderElement] -> Multiplier
# FIRE beats WATER/NATURE, WATER beats FIRE, HOLY beats DARK, DARK beats HOLY
static var ELEMENTAL_MATRIX: Dictionary = {
	DamageType.PHY: { DamageType.PHY: 1.0, DamageType.FIRE: 1.0, DamageType.WATER: 1.0, DamageType.HOLY: 1.0, DamageType.DARK: 1.0 },
	DamageType.FIRE: { DamageType.PHY: 1.0, DamageType.FIRE: 0.75, DamageType.WATER: 1.5, DamageType.HOLY: 1.0, DamageType.DARK: 1.0 },
	DamageType.WATER: { DamageType.PHY: 1.0, DamageType.FIRE: 1.5, DamageType.WATER: 0.75, DamageType.HOLY: 1.0, DamageType.DARK: 1.0 },
	DamageType.HOLY: { DamageType.PHY: 1.0, DamageType.FIRE: 1.0, DamageType.WATER: 1.0, DamageType.HOLY: 0.5, DamageType.DARK: 1.75 },
	DamageType.DARK: { DamageType.PHY: 1.0, DamageType.FIRE: 1.0, DamageType.WATER: 1.0, DamageType.HOLY: 1.75, DamageType.DARK: 0.5 }
}

class DamageResult extends RefCounted:
	var final_damage: int
	var is_critical: bool
	var is_miss: bool
	var damage_type: DamageType

static func calculate_damage(attacker_stats: Dictionary, defender_stats: Dictionary, skill_multiplier: float = 1.0, dmg_type: DamageType = DamageType.PHY) -> Dictionary:
	var atk: float = float(attacker_stats.get("attack", 10))
	var def: float = float(defender_stats.get("defense", 5))
	var crit_chance: float = float(attacker_stats.get("crit_rate", 0.10))
	var accuracy: float = float(attacker_stats.get("accuracy", 0.95))
	var evasion: float = float(defender_stats.get("evasion", 0.05))
	
	# Check miss
	var hit_chance: float = clampf(accuracy - evasion, 0.20, 1.0)
	if randf() > hit_chance:
		return {
			"damage": 0,
			"is_critical": false,
			"is_miss": true,
			"damage_type": dmg_type
		}
	
	# Elemental multiplier
	var def_element: DamageType = defender_stats.get("element", DamageType.PHY)
	var elem_mult: float = 1.0
	if ELEMENTAL_MATRIX.has(dmg_type) and ELEMENTAL_MATRIX[dmg_type].has(def_element):
		elem_mult = ELEMENTAL_MATRIX[dmg_type][def_element]
		
	# Base raw damage
	var raw_damage: float = maxf(1.0, (atk * skill_multiplier) - def)
	
	# Small random variance (-5% to +5%)
	var variance: float = randf_range(0.95, 1.05)
	var damage: float = raw_damage * elem_mult * variance
	
	# Critical check
	var is_crit: bool = false
	if randf() < crit_chance:
		damage *= FATAL_RATE
		is_crit = true
		
	return {
		"damage": maxi(1, int(round(damage))),
		"is_critical": is_crit,
		"is_miss": false,
		"damage_type": dmg_type
	}
