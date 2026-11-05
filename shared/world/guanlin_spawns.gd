class_name GuanlinSpawns
extends RefCounted

## Forest encounters shared by the server simulation and the client scene, so
## both sides agree on who stands where and how strong they are (Balance roles).
## [node name, monster id, spawn, role, level, display name]
const ENCOUNTERS: Array = [
	["WildBoar1", 70073, Vector3(-8, 0, 28), "beast", 1, "Дикий вепр"],
	["WildBoar2", 70073, Vector3(10, 0, 30), "beast", 1, "Дикий вепр"],
	["WildBoar3", 70073, Vector3(-16, 0, 24), "beast", 2, "Дикий вепр"],
	["WildBoar4", 70073, Vector3(18, 0, 26), "beast", 2, "Дикий вепр"],
	["ForestSpider1", 70076, Vector3(16, 0, 42), "swarm", 2, "Лісовий павук"],
	["ForestSpider2", 70076, Vector3(-12, 0, 44), "swarm", 2, "Лісовий павук"],
	["ForestSpider3", 70076, Vector3(24, 0, 40), "swarm", 3, "Лісовий павук"],
	["ForestSpider4", 70076, Vector3(-22, 0, 38), "swarm", 3, "Лісовий павук"],
	["ScavengerJackal1", 70115, Vector3(4, 0, 56), "hunter", 3, "Шакал-трупоїд"],
	["ScavengerJackal2", 70115, Vector3(-8, 0, 58), "hunter", 3, "Шакал-трупоїд"],
	["ScavengerJackal3", 70115, Vector3(14, 0, 55), "hunter", 4, "Шакал-трупоїд"],
	["Bandit1", 70071, Vector3(27, 0, 28), "bandit", 3, "Розбійник банди Гадюки"],
	["Bandit2", 70071, Vector3(30, 0, 39), "bandit", 3, "Розбійник банди Гадюки"],
	["Bandit3", 70071, Vector3(-29, 0, 27), "brute", 4, "Громила банди Гадюки"],
	["Bandit4", 70071, Vector3(-31, 0, 47), "bandit", 3, "Розбійник банди Гадюки"],
	["Bandit5", 70071, Vector3(28, 0, 57), "bandit", 4, "Розбійник банди Гадюки"],
]

const SPEEDS: Dictionary = {"beast": 3.5, "swarm": 3.8, "hunter": 4.2, "bandit": 3.6, "brute": 3.2}

static func display_name(entry: Array) -> String:
	return "%s · Рів. %d" % [entry[5], entry[4]]
