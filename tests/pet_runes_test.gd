extends SceneTree
class Actor:
	extends Node
	var stats: Dictionary = {"inventory":{"30023":1,"30753":1,"30750":1,"30751":1,"30989":2,"30025":2},"locked_items":[],"copper":1000,"companions":[],"incubations":[],"summoned_pet":""}
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func pet(uid: String, species: int, skills: Array) -> Dictionary:
	var result: Dictionary = {"uid":uid,"species_id":species,"name":uid,"level":5,"exp":0,"hp":60,"max_hp":60,"hunger":100,"born_at":1000.0,"skills":skills,"gender":("male" if uid == "source" else "female")}
	PetDevelopment.ensure_pet(result)
	return result
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var actor: Actor = Actor.new()
	var pets: CompanionSystem = CompanionSystem.new()
	var now: float = 1500000.0
	pets.time_source = func() -> float: return now
	pets.bind_player(actor)
	actor.stats["companions"] = [pet("source",140001,[90014,90035,90036]),pet("target",140052,[90023,90037,90041])]
	var source: Dictionary = pets.get_pet("source")
	var target: Dictionary = pets.get_pet("target")
	check(pets.transfer_with_runes("source","target",30023,30753),"original second-slot learning and third-slot inheritance runes work together")
	check(source["skills"] == [90014,90035] and target["skills"] == [90023,90036,90041],"runes replace exact source-described slots")
	check(actor.stats["copper"] == 950 and not actor.stats["inventory"].has("30023") and not actor.stats["inventory"].has("30753"),"successful transfer consumes both runes and pays once")
	var before: Dictionary = actor.stats.duplicate(true)
	check(not pets.transfer_with_runes("source","target",30023,30753) and actor.stats == before,"replayed rune request consumes nothing")
	source["skills"] = [90014]
	target["skills"] = [90023]
	before = actor.stats.duplicate(true)
	check(not pets.transfer_with_runes("source","target",30750,30751) and actor.stats == before,"nonexistent third target slot rejects without consuming either rune")
	check(not pets.transfer_with_runes("source","source") and actor.stats == before,"self transfer rejected atomically")
	check(pets.transfer_with_runes("source","target") and target["skills"].has(90014) and source["skills"].is_empty(),"unassisted transfer handles available slots and real source skill")
	source["skills"] = [90035]
	target["skills"] = [90036]
	check(pets.breed("source","target") and actor.stats["incubations"][0]["inherited_skills"] == [90035,90036],"offspring records both parents' distinct skills at breeding time")
	check(pets.validate_state(actor.stats),"inherited egg validates before persistence")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(actor.stats))
	ProfileCodec.normalize(restored)
	check(90035 in restored["incubations"][0]["inherited_skills"] and pets.validate_state(restored),"inherited skills survive JSON round trip")
	var old_age: float = pets.age_seconds("source")
	source["hp"] = 0
	check(pets.rejuvenate("source",30989) and is_equal_approx(old_age-pets.age_seconds("source"),CompanionSystem.AGE_STAGE_SECONDS) and source["hp"] == 1,"source lifespan-extension fruit reduces one stage and revives")
	source["hp"] = 0
	check(pets.revive("source",30025) and source["hp"] == 10,"source Dragon Redemption revives a deceased pet")
	before = actor.stats.duplicate(true)
	check(not pets.revive("source",30025) and actor.stats == before,"revival cannot waste a consumable on a living pet")
	check(pets.combat_profile("source")["element"] == CombatFormulas.DamageType.WATER and pets.combat_profile("target")["element"] == CombatFormulas.DamageType.FIRE,"transferred elemental skills affect actual combat profiles")
	actor.free()
	print("PET_RUNES_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
