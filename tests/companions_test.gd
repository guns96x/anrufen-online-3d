extends SceneTree
const Companions = preload("res://shared/companions/companion_system.gd")
class FakePlayer:
	extends Node
	var stats: Dictionary = {"hp":100,"inventory":{"30029":3,"30458":2,"30022":10,"30020":10},"copper":500,"locked_items":[]}
var failures: int = 0
var now: float = 1000.0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor: FakePlayer = FakePlayer.new()
	var pets = Companions.new()
	pets.time_source = func() -> float: return now
	pets.bind_player(actor)
	check(pets.species().size() == 27,"27 actual source species; timestamp excluded")
	var mapping: Dictionary = pets.egg_species_map()
	var report: Dictionary = pets.egg_mapping_report()
	check(pets.available_eggs().size() == 23 and mapping.size() >= 20,"23 named original eggs mapped dynamically")
	var unique_species: Dictionary = {}
	for egg_id: int in pets.available_eggs():
		unique_species[int(mapping[egg_id])] = true
	check(unique_species.size() >= 20,"mapped eggs cover at least 20 original species")
	check(mapping.get(30074) == 140038 and mapping.get(30588) == 140010,"explicit model-prefix normalization matches wolf and snake")
	check(mapping.get(30029) == 140001 and mapping.get(30458) == 140052,"verified boar and jackal mappings retained")
	check(report["unmatched_ids"] == [30527],"unnamed generic egg documented and skipped")
	check(report["ambiguous_candidates"].size() == 4 and mapping.get(30028) == 140000,"duplicate source names use reported deterministic IDs")
	actor.stats["inventory"]["30527"] = 1
	check(not pets.start_incubation(30527) and actor.stats["inventory"]["30527"] == 1,"unmatched generic egg refused without consumption")
	check(pets.validate_state(actor.stats),"empty initialized state validates")
	check(not pets.start_incubation(999999),"unknown egg rejected")
	actor.stats["locked_items"] = [30029]
	check(not pets.start_incubation(30029),"locked egg rejected")
	actor.stats["locked_items"] = []
	check(pets.start_incubation(30029) and actor.stats["inventory"]["30029"] == 2,"incubation consumes one egg")
	check(not pets.hatch(0) and actor.stats["incubations"].size() == 1,"early hatch preserves incubation")
	now += 60.0
	check(pets.hatch(0),"completed incubation hatches")
	check(not pets.hatch(0) and actor.stats["companions"].size() == 1,"hatch cannot be repeated")
	var first: Dictionary = actor.stats["companions"][0]
	var uid_a: String = first["uid"]
	check(first["species_id"] == 140001,"boar egg yields source boar species")
	first["hunger"] = 70
	first["hp"] = 20
	check(pets.feed(uid_a) and first["hunger"] == 100 and actor.stats["inventory"]["30022"] == 9,"feeding restores and consumes once")
	check(not pets.feed(uid_a) and actor.stats["inventory"]["30022"] == 9,"full pet does not consume food")
	check(pets.heal(uid_a) and first["hp"] == 60 and actor.stats["inventory"]["30020"] == 9,"pet potion heals and consumes once")
	check(not pets.heal(uid_a) and actor.stats["inventory"]["30020"] == 9,"healthy pet does not consume potion")
	check(not pets.rename_pet(uid_a,"x") and not pets.rename_pet(uid_a,"bad\nname"),"invalid names rejected")
	check(pets.rename_pet(uid_a,"Борис"),"valid name accepted")
	check(pets.summon(uid_a) and not pets.summon(uid_a),"summon selects once")
	check(not pets.release_pet(uid_a),"summoned pet cannot be released")
	pets.tick(120.0)
	check(first["hunger"] == 98,"summoned pet hunger advances")
	pets.dismiss()
	check(actor.stats["summoned_pet"] == "","dismiss clears summon")
	check(pets.start_incubation(30458),"jackal egg incubates")
	now += 60.0
	check(pets.hatch(0),"jackal hatches")
	var second: Dictionary = actor.stats["companions"][1]
	var uid_b: String = second["uid"]
	check(second["species_id"] == 140052,"jackal uses source species")
	check(not pets.breed(uid_a,uid_b),"juveniles cannot breed")
	check(pets.gain_exp(uid_a,1000) and pets.gain_exp(uid_b,1000) and first["level"] == 5,"experience advances pet levels")
	check(not pets.breed(uid_a,uid_a),"self breeding rejected")
	actor.stats["copper"] = 99
	check(not pets.breed(uid_a,uid_b) and actor.stats["incubations"].is_empty(),"poor breeding preserves state")
	actor.stats["copper"] = 500
	first["gender"] = "male"
	second["gender"] = "female"
	check(pets.breed(uid_a,uid_b) and actor.stats["copper"] == 400,"breeding charges once and queues offspring")
	check(not pets.hatch(0),"bred egg also waits for incubation")
	first["skills"] = [90014,90035]
	second["skills"] = [90014]
	check(not pets.transfer_skill(uid_a,uid_a,1),"self skill transfer rejected")
	check(not pets.transfer_skill(uid_a,uid_b,0),"duplicate target skill rejected")
	check(pets.transfer_skill(uid_a,uid_b,1) and first["skills"] == [90014] and second["skills"] == [90014,90035] and actor.stats["copper"] == 350,"skill moves and charges exactly once")
	check(pets.validate_state(actor.stats),"populated state validates")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(actor.stats))
	check(pets.validate_state(loaded),"JSON float-number roundtrip validates")
	var bad: Dictionary = loaded.duplicate(true)
	bad["companions"].append(bad["companions"][0].duplicate(true))
	check(not pets.validate_state(bad),"duplicate UID rejected")
	bad = loaded.duplicate(true)
	bad["companions"][0]["species_id"] = 999999
	check(not pets.validate_state(bad),"unknown species rejected")
	bad = loaded.duplicate(true)
	bad["companions"][0]["hunger"] = "100"
	check(not pets.validate_state(bad),"string numeric stat rejected")
	bad = loaded.duplicate(true)
	bad["companions"][0]["born_at"] = NAN
	check(not pets.validate_state(bad),"nonfinite timestamp rejected")
	bad = loaded.duplicate(true)
	bad["incubations"][0]["hatch_at"] = bad["incubations"][0]["started_at"]
	check(not pets.validate_state(bad),"impossible incubation window rejected")
	bad = loaded.duplicate(true)
	bad["summoned_pet"] = "missing"
	check(not pets.validate_state(bad),"orphan summoned reference rejected")
	check(pets.release_pet(uid_b) and actor.stats["companions"].size() == 1,"dismissed pet can be released")
	actor.stats["inventory"]["30048"] = 1
	check(pets.start_incubation(30048),"additional original spider egg incubates")
	check(pets.validate_state(JSON.parse_string(JSON.stringify(actor.stats))),"dynamic egg/species queue survives JSON validation")
	var wrong_pair: Dictionary = actor.stats.duplicate(true)
	wrong_pair["incubations"][1]["species_id"] = 140001
	check(not pets.validate_state(wrong_pair),"mismatched dynamic egg/species pairing rejected")
	now += 60.0
	check(pets.hatch(1) and actor.stats["companions"][1]["species_id"] == 140002,"additional egg hatches correct source spider")
	check(not pets.hatch(1),"additional egg cannot hatch twice")
	actor.stats["inventory"]["30015"] = 2
	first["hp"] = 0
	check(pets.rejuvenate(uid_a,30015) and first["hp"] == 1 and pets.age_seconds(uid_a) == 0.0 and actor.stats["inventory"]["30015"] == 1,"source longevity fruit resets age and revives with provisional one HP")
	check(not pets.rejuvenate(uid_a,30015) and actor.stats["inventory"]["30015"] == 1,"already rejuvenated pet does not consume another fruit")
	check(pets.validate_state(JSON.parse_string(JSON.stringify(actor.stats))),"rejuvenation state survives JSON validation")
	bad = actor.stats.duplicate(true)
	bad["companions"][0]["rejuvenated_at"] = "invalid"
	check(not pets.validate_state(bad),"malformed rejuvenation timestamp rejected")
	actor.free()
	print("COMPANIONS_SUITE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
