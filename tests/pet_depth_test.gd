extends SceneTree

const Companions = preload("res://shared/companions/companion_system.gd")

class DepthActor:
	extends Node
	var stats: Dictionary = {
		"hp": 100,
		"inventory": {
			"30029": 5,
			"30458": 5,
			"30022": 20,
			"30015": 5,
			"30988": 5,
			"30989": 5
		},
		"copper": 5000,
		"locked_items": [],
		"companions": [],
		"incubations": [],
		"summoned_pet": ""
	}

var failures: int = 0
var now: float = 2000.0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor: DepthActor = DepthActor.new()
	var pets: CompanionSystem = CompanionSystem.new()
	pets.time_source = func() -> float: return now
	pets.bind_player(actor)

	# --- 1. Pet Talents rolled at hatching within species template range ---
	check(pets.start_incubation(30029), "boar egg starts incubation")
	now += 60.0
	check(pets.hatch(0), "boar hatches")
	var boar: Dictionary = actor.stats["companions"][0]
	var boar_uid: String = boar["uid"]
	check(boar.has("growth_talents"), "hatched pet has growth_talents")
	var b_talents: Dictionary = boar.get("growth_talents", {})
	for stat: String in ["hp", "attack", "defense", "speed"]:
		check(b_talents.has(stat), "growth_talents contains stat: " + stat)
	var boar_ranges: Dictionary = SourcePetCatalog.species_talent_ranges(140001)
	check(int(b_talents["hp"]) >= int(boar_ranges["hp"][0]) and int(b_talents["hp"]) <= int(boar_ranges["hp"][1]), "boar hp talent in template range")
	check(int(b_talents["attack"]) >= int(boar_ranges["attack"][0]) and int(b_talents["attack"]) <= int(boar_ranges["attack"][1]), "boar attack talent in template range")
	check(int(b_talents["defense"]) >= int(boar_ranges["defense"][0]) and int(b_talents["defense"]) <= int(boar_ranges["defense"][1]), "boar defense talent in template range")
	check(int(b_talents["speed"]) >= int(boar_ranges["speed"][0]) and int(b_talents["speed"]) <= int(boar_ranges["speed"][1]), "boar speed talent in template range")

	# Jackal (physical template 300001)
	check(pets.start_incubation(30458), "jackal egg starts incubation")
	now += 60.0
	check(pets.hatch(0), "jackal hatches")
	var jackal: Dictionary = actor.stats["companions"][1]
	var jackal_uid: String = jackal["uid"]
	var j_talents: Dictionary = jackal.get("growth_talents", {})
	var jackal_ranges: Dictionary = SourcePetCatalog.species_talent_ranges(140052)
	check(int(j_talents["attack"]) >= int(jackal_ranges["attack"][0]) and int(j_talents["attack"]) <= int(jackal_ranges["attack"][1]), "jackal attack talent in template range")

	# --- 2. Talents scale level-up stat gains ---
	var low_pet: Dictionary = boar.duplicate(true)
	low_pet["uid"] = "low_pet"
	low_pet["level"] = 1
	low_pet["growth_talents"] = {"hp": 10, "attack": 10, "defense": 10, "speed": 10}
	low_pet["growth_base_attack"] = 8
	PetDevelopment.ensure_pet(low_pet)
	PetDevelopment.level_up(low_pet)

	var high_pet: Dictionary = boar.duplicate(true)
	high_pet["uid"] = "high_pet"
	high_pet["level"] = 1
	high_pet["growth_talents"] = {"hp": 25, "attack": 25, "defense": 25, "speed": 20}
	high_pet["growth_base_attack"] = 8
	PetDevelopment.ensure_pet(high_pet)
	PetDevelopment.level_up(high_pet)

	check(int(high_pet["growth_base_attack"]) > int(low_pet["growth_base_attack"]), "higher attack talent yields higher attack on level-up")
	check(int(high_pet["growth_base_hp"]) > int(low_pet["growth_base_hp"]), "higher hp talent yields higher hp on level-up")

	# --- 3. Gender and personality rolled at hatching; breeding requires opposite genders ---
	check(boar.get("gender") in ["male", "female"], "boar gender is male or female")
	check(jackal.get("gender") in ["male", "female"], "jackal gender is male or female")

	# Advance both to level 5 for breeding test
	check(pets.gain_exp(boar_uid, 1000) and pets.gain_exp(jackal_uid, 1000), "pets reach level 5")
	# Force same gender
	boar["gender"] = "male"
	jackal["gender"] = "male"
	check(not pets.breed(boar_uid, jackal_uid), "breeding same gender male/male rejected")
	boar["gender"] = "female"
	jackal["gender"] = "female"
	check(not pets.breed(boar_uid, jackal_uid), "breeding same gender female/female rejected")
	# Opposite genders
	jackal["gender"] = "male"
	check(pets.breed(boar_uid, jackal_uid), "breeding opposite genders female/male accepted")

	# Personality rolled from original 12 IDs
	var valid_personalities: Dictionary = SourcePetCatalog.personalities()
	check(valid_personalities.has(int(boar.get("personality_id"))), "boar personality is one of 12 original IDs")
	check(not boar.get("personality", "").is_empty(), "boar personality has readable identifier")

	# Personality nudges one stat
	var brave_pet: Dictionary = boar.duplicate(true)
	brave_pet["uid"] = "brave_pet"
	brave_pet["personality_id"] = 190001 # Brave -> attack +10%
	brave_pet["personality"] = "brave"
	brave_pet["growth_base_attack"] = 20
	brave_pet["skills"] = []
	actor.stats["companions"].append(brave_pet)
	var brave_prof: Dictionary = pets.combat_profile("brave_pet")
	check(brave_prof["attack"] == 22, "brave personality nudges attack by +10% (20 -> 22)")

	var loyal_pet: Dictionary = boar.duplicate(true)
	loyal_pet["uid"] = "loyal_pet"
	loyal_pet["personality_id"] = 190005 # Loyal -> defense +10%
	loyal_pet["personality"] = "loyal"
	loyal_pet["growth_base_defense"] = 20
	actor.stats["companions"].append(loyal_pet)
	var loyal_prof: Dictionary = pets.combat_profile("loyal_pet")
	check(loyal_prof["defense"] == 22, "loyal personality nudges defense by +10% (20 -> 22)")

	var cautious_pet: Dictionary = boar.duplicate(true)
	cautious_pet["uid"] = "cautious_pet"
	cautious_pet["personality_id"] = 190014 # Cautious -> hp +10%
	cautious_pet["personality"] = "cautious"
	cautious_pet["growth_base_hp"] = 100
	cautious_pet["talents"] = {}
	cautious_pet["form_rank"] = 0
	PetDevelopment.rebuild(cautious_pet)
	check(cautious_pet["max_hp"] == 110, "cautious personality nudges max_hp by +10% (100 -> 110)")

	# --- 4. Lifespan: pets age while summoned; cannot summon when lifespan <= 0 ---
	check(pets.summon(boar_uid), "boar summoned successfully")
	var life_before: float = float(boar["lifespan"])
	pets.tick(120.0)
	check(is_equal_approx(float(boar["lifespan"]), life_before - 120.0), "summoned pet lifespan drains on tick")

	pets.dismiss()
	var life_dismissed: float = float(boar["lifespan"])
	pets.tick(120.0)
	check(is_equal_approx(float(boar["lifespan"]), life_dismissed), "dismissed pet lifespan does not drain on tick")

	# Lifespan reaches zero
	boar["lifespan"] = 30.0
	pets.summon(boar_uid)
	pets.tick(60.0)
	check(float(boar["lifespan"]) == 0.0, "lifespan clamped to zero")
	check(actor.stats["summoned_pet"] == "", "pet at end of lifespan auto-dismissed")
	check(not pets.summon(boar_uid), "pet with 0 lifespan cannot be summoned")

	# Rejuvenation restores lifespan
	check(pets.rejuvenate(boar_uid, 30015), "Fruit of Longevity 30015 rejuvenates pet")
	check(float(boar["lifespan"]) == float(boar["max_lifespan"]), "Fruit of Longevity fully restores lifespan")
	check(pets.summon(boar_uid), "rejuvenated pet can be summoned again")
	pets.dismiss()

	# Rejuvenation with 30989 (stage restore)
	boar["lifespan"] = 5000.0
	var max_life: float = float(boar["max_lifespan"])
	now += 1000.0
	check(pets.rejuvenate(boar_uid, 30989), "Fruit of Life Extension 30989 rejuvenates pet")
	check(is_equal_approx(float(boar["lifespan"]), 5000.0 + (max_life * 0.25)), "30989 restores 25% of max lifespan")

	# Rejuvenation with 30988 (longevity potion full restore)
	now += 1000.0
	check(pets.rejuvenate(boar_uid, 30988), "Longevity Potion 30988 rejuvenates pet")
	check(float(boar["lifespan"]) == max_life, "Longevity Potion restores full lifespan")

	# --- 5. Loyalty / taming level raised by feeding; disobedience on low loyalty ---
	check(int(jackal.get("loyalty", 0)) == 60, "initial loyalty is 60")
	jackal["hunger"] = 60
	check(pets.feed(jackal_uid, 30022), "feeding hungry pet succeeds")
	check(int(jackal["loyalty"]) == 70, "feeding raises loyalty by +10 (60 -> 70)")

	# Low loyalty disobedience in combat_strike
	jackal["loyalty"] = 20 # Low loyalty -> disobedience chance = (50 - 20) / 100 = 0.30
	var strike_disobey: Dictionary = pets.combat_strike(jackal_uid, 0.15) # roll 0.15 < 0.30 -> disobey
	check(strike_disobey.get("disobeyed") == true, "low loyalty pet disobeys attack with roll below chance")
	check(strike_disobey["attack"] == 0 and strike_disobey["accuracy"] == 0.0, "disobeyed strike deals zero damage and zero accuracy")

	var strike_obey: Dictionary = pets.combat_strike(jackal_uid, 0.45) # roll 0.45 >= 0.30 -> obey
	check(strike_obey.get("disobeyed") == false, "low loyalty pet obeys attack with roll above chance")
	check(strike_obey["attack"] > 0, "obeyed strike performs attack")

	jackal["loyalty"] = 80 # High loyalty -> 0 chance of disobedience
	var strike_loyal: Dictionary = pets.combat_strike(jackal_uid, 0.01)
	check(strike_loyal.get("disobeyed") == false, "high loyalty pet always obeys attack")

	# Tick notification throttling: normal frame tick does not spam changed
	var notify_count: int = 0
	var tracker: Callable = func() -> void: notify_count += 1
	pets.changed.connect(tracker)
	pets.summon(jackal_uid)
	notify_count = 0
	pets.tick(0.016)
	check(notify_count == 0, "sub-minute tick does not spam changed signal")
	pets.changed.disconnect(tracker)
	pets.dismiss()

	# --- 6. Save compatibility and profile codec normalization ---
	var legacy_profile: Dictionary = {
		"companions": [
			{
				"uid": "legacy_beast",
				"species_id": 140001,
				"name": "Старий Вепр",
				"level": 3,
				"exp": 50,
				"hp": 60,
				"max_hp": 60,
				"hunger": 90,
				"born_at": 500.0,
				"skills": [90014]
			},
			{
				"uid": "legacy_phoenix",
				"species_id": 140040, # Special species with 9000 lifespan
				"name": "Фенікс",
				"level": 50,
				"exp": 0,
				"hp": 500,
				"hunger": 90,
				"born_at": 500.0,
				"skills": []
			}
		],
		"incubations": [],
		"summoned_pet": ""
	}
	ProfileCodec.normalize(legacy_profile)
	var norm_pet: Dictionary = legacy_profile["companions"][0]
	check(norm_pet.has("growth_talents"), "normalized legacy pet receives default growth_talents")
	check(norm_pet.get("gender") == "male", "normalized legacy pet receives default gender male")
	check(int(norm_pet.get("personality_id")) == 190001, "normalized legacy pet receives default personality brave")
	check(float(norm_pet.get("lifespan")) == 18000.0, "normalized legacy pet receives default lifespan 18000")
	check(int(norm_pet.get("loyalty")) == 60, "normalized legacy pet receives default loyalty 60")
	check(int(norm_pet["growth_base_attack"]) == 8 + 3 * 3, "level 3 legacy pet attack progression preserved")

	var norm_special: Dictionary = legacy_profile["companions"][1]
	check(float(norm_special.get("lifespan")) == 9000.0, "special species 140040 preserves 9000 lifespan on migration")
	check(int(norm_special["growth_base_attack"]) == 8 + 50 * 3, "level 50 legacy pet preserves 158 attack progression")
	check(int(norm_special["max_mp"]) == 40 + (50 - 1) * 4, "level 50 legacy pet preserves 236 max_mp")
	check(int(norm_special["growth_base_mp"]) == 236, "level 50 legacy pet preserves 236 growth_base_mp baseline")

	check(pets.validate_state(legacy_profile), "normalized legacy pet passes strict validate_state")

	actor.free()
	print("PET_DEPTH_SUITE: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
