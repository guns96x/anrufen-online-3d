class_name ProfileActor
extends Node3D

signal leveled_up(new_level: int)
signal exp_gained(amount: int)
signal died()
signal respawned()

var stats: Dictionary = {}
var is_dead: bool = false
var inventory: InventorySystem

func bind_profile(profile: Dictionary) -> void:
	stats = profile
	CharacterSystem.ensure_stats(stats)
	inventory = InventorySystem.new()
	inventory.bind_player(self)
	is_dead = int(stats.get("hp",0)) <= 0

func gain_exp(amount: int) -> void:
	if amount <= 0 or amount > 10000000 or stats.is_empty() or int(stats.get("level",1)) >= 100:
		return
	if inventory == null:
		inventory = InventorySystem.new()
		inventory.bind_player(self)
	stats["exp"] = int(stats.get("exp",0)) + amount
	exp_gained.emit(amount)
	while int(stats["level"]) < 100 and int(stats["exp"]) >= int(stats.get("exp_to_next",100)):
		stats["exp"] -= int(stats.get("exp_to_next",100))
		stats["level"] = int(stats["level"]) + 1
		stats["exp_to_next"] = int(100.0 * pow(1.35,int(stats["level"])-1))
		stats["stat_points"] = int(stats.get("stat_points",0)) + 3
		stats["skill_points"] = int(stats.get("skill_points",0)) + 1
		CharacterSystem.rebuild_stats(stats,inventory.bonus_totals())
		stats["hp"] = stats["max_hp"]
		stats["mp"] = stats["max_mp"]
		is_dead = false
		leveled_up.emit(int(stats["level"]))
	if int(stats["level"]) == 100:
		stats["exp"] = 0
