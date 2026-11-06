class_name BenmaSpawns
extends RefCounted

## Steppe encounters shared by the server simulation and the client scene, so
## both sides agree on who stands where and how strong they are (Balance roles).
## [node name, monster id, spawn, role, level, display name]
const ENCOUNTERS: Array = [
	["Deserter1", 70151, Vector3(-10, 0, 26), "bandit", 10, "Дезертир"],
	["Deserter2", 70151, Vector3(12, 0, 28), "bandit", 10, "Дезертир"],
	["Deserter3", 70151, Vector3(-18, 0, 32), "bandit", 10, "Дезертир"],
	["Deserter4", 70151, Vector3(16, 0, 30), "bandit", 10, "Дезертир"],
	["DeserterArcher1", 70162, Vector3(-6, 0, 38), "hunter", 11, "Лучник-дезертир"],
	["DeserterArcher2", 70162, Vector3(8, 0, 40), "hunter", 11, "Лучник-дезертир"],
	["DeserterArcher3", 70162, Vector3(20, 0, 36), "hunter", 11, "Лучник-дезертир"],
	["OrcBandit1", 70150, Vector3(-24, 0, 42), "bandit", 12, "Орк-розбійник"],
	["OrcBandit2", 70150, Vector3(-16, 0, 46), "bandit", 12, "Орк-розбійник"],
	["OrcBandit3", 70150, Vector3(14, 0, 48), "bandit", 12, "Орк-розбійник"],
	["OrcBandit4", 70150, Vector3(26, 0, 44), "bandit", 12, "Орк-розбійник"],
	["OgreBandit1", 70157, Vector3(-20, 0, 54), "brute", 13, "Людожер-розбійник"],
	["OgreBandit2", 70157, Vector3(10, 0, 56), "brute", 13, "Людожер-розбійник"],
	["OgreKidnapper1", 70158, Vector3(-8, 0, 56), "brute", 13, "Людожер-викрадач"],
	["OgreKidnapper2", 70158, Vector3(22, 0, 55), "brute", 13, "Людожер-викрадач"],
	["CaptainJack1", 70007, Vector3(2, 0, 60), "brute", 15, "Капітан Джек"],
]

const SPEEDS: Dictionary = {
	"beast": 3.5,
	"swarm": 3.8,
	"hunter": 4.2,
	"bandit": 3.6,
	"brute": 3.2,
}

static func display_name(entry: Array) -> String:
	return "%s · Рів. %d" % [entry[5], entry[4]]
