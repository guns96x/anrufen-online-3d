extends SceneTree
const Rules = preload("res://shared/combat/pet_skill_rules.gd")
var failures: int = 0
var checks: int = 0
var source: Dictionary

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func close(a: float, b: float) -> bool:
	return absf(a-b) < 0.00001

func pet_for(id: int = 90014) -> Dictionary:
	var species: int = 140001
	var skills: Array[int] = [id]
	if id >= 90145:
		skills = []
		for key: String in source["species"]:
			if int(source["species"][key]["innate_skill_id"]) == id:
				species = int(key)
				break
	return {"uid":"test_pet","species_id":species,"level":10,"hp":50,"max_hp":200,"mp":40,"max_mp":40,"attack":100.0,"magic_attack":80.0,"base_max_hp":200,"base_max_mp":40,"hunger":100,"skills":skills}

func owner() -> Dictionary:
	return {"account_id":1,"level":10,"hp":50,"max_hp":300,"base_max_hp":300,"attack":80}

func enemy() -> Dictionary:
	return {"account_id":2,"level":12,"hp":500,"max_hp":500,"defense":30}

func context(id: int) -> Dictionary:
	return {"selected_skill_id":id,"distance":1.0,"owner_distance":1.0,"target_is_monster":true,"roll":0.25}

func plan(id: int) -> Dictionary:
	return Rules.build(pet_for(id),owner(),enemy(),context(id))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	source = JSON.parse_string(FileAccess.get_file_as_string("res://data/original/pet_rules.json"))
	var definitions: Dictionary = Rules.definitions()
	check(definitions.size() == 53,"all53 definitions")
	var innates: int = 0
	var random_skills: int = 0
	var passives: int = 0
	for id: int in definitions:
		var row: Dictionary = definitions[id]
		if row["kind"] == "innate": innates += 1
		else: random_skills += 1
		check(row["label"] != "" and row["description_uk"] != "" and row["source_name"] == source["skills"][str(id)]["name"],"localized + original source preserved %d" % id)
		check(row["constants"] == source["skills"][str(id)]["constants"] and row["raw_rank_limit"] == int(source["skills"][str(id)]["raw_rank_limit"]),"source constants and raw ranks %d" % id)
		var pet: Dictionary = pet_for(id)
		var own: Dictionary = owner()
		var foe: Dictionary = enemy()
		var options: Dictionary = context(id)
		var before: String = JSON.stringify([pet,own,foe,options])
		var result: Dictionary = Rules.build(pet,own,foe,options)
		check(result["ok"],"supported semantics %d" % id)
		check(JSON.stringify([pet,own,foe,options]) == before,"pure inputs %d" % id)
		if row["category"] == "passive":
			passives += 1
			check(not result.get("modifiers",{}).is_empty() and result["actions"].is_empty() and result["mp_cost"] == 0,"real passive modifiers %d" % id)
		else:
			check(not result["actions"].is_empty(),"real active/aura actions %d" % id)
			for action: Dictionary in result["actions"]:
				check(action["kind"] in ["damage","heal_hp","effect","dispel","threat"] and action["recipient"] in ["enemy","self","owner"],"supported actual action %d" % id)
	check(innates == 13 and random_skills == 40 and passives == 9,"exact source partition")
	definitions[90014]["constants"]["add_phy_dam_rate"][0] = 999
	check(Rules.definition(90014)["constants"]["add_phy_dam_rate"][0] == 0,"catalog returns deep copies")
	check(Rules.definition(999).is_empty(),"unknown catalog ID")
	check(Rules.definition(90157)["raw_rank_limit"] == 15 and Rules.definition(90014)["raw_rank_limit"] == 30,"raw limits never become rank scaling")

	check(plan(90014)["actions"][0]["base"] == 100.0 and plan(90014)["mp_cost"] == 0,"free physical baseline")
	check(plan(90024)["actions"][0]["base"] == 160.0,"source60percent heavy bonus")
	check(plan(90025)["actions"].size() == 2 and plan(90025)["actions"][1]["damage_type"] == 2,"physical plus fire")
	check(plan(90035)["actions"].size() == 2 and plan(90035)["actions"][1]["damage_type"] == 3,"ice prose overrides erroneous fire constant key")
	check(plan(90038)["actions"][0]["damage_type"] == 3 and plan(90038)["actions"].size() == 1,"ice attack does not invent freeze")
	check(close(plan(90039)["actions"][0]["base"],128.0),"source60percent magic bonus")
	check(close(plan(90145)["actions"][0]["base"],104.0),"zombie source2percent maximumHP")
	check(close(plan(90146)["actions"][0]["base"],108.0),"skeleton source8percent physical")
	check(plan(90147)["actions"][0]["base"] == 140.0,"jackal own level times4")
	check(plan(90148)["actions"][0]["base"] == 160.0,"vulture target level times5")
	check(close(plan(90153)["actions"][0]["base"],86.4),"scorpion source8percent magic")
	check(close(plan(90154)["actions"][0]["base"],80.8),"spider source2percent maximumMP")
	check(plan(90150)["actions"][1]["kind"] == "threat" and plan(90150)["actions"][1]["amount"] == 200,"boar monster threat level times20")
	check(plan(90149)["actions"][0]["damage_type"] == 2 and plan(90149)["actions"][1]["amount"] == 200,"slime fire and threat")
	var options: Dictionary = context(90150)
	options["target_is_monster"] = false
	options["hostile_allowed"] = true
	check(Rules.build(pet_for(90150),owner(),enemy(),options)["actions"].size() == 1,"threat never forces player aggro")
	check(plan(90151)["actions"][1]["modifiers"]["resist_add"] == 30.0 and plan(90151)["actions"][1]["duration"] == 5.0,"cockatrice source5second all-resist effect")
	check(plan(90152)["actions"][1]["modifiers"]["defense_add"] == 30.0,"wolf source level-based defense")
	for id: int in [90155,90156]:
		var result: Dictionary = plan(id)
		check(result["actions"].size() == 2 and result["actions"][0]["recipient"] == "self" and result["actions"][1]["recipient"] == "owner" and result["actions"][0]["duration"] == 60.0,"owner and self60second support %d" % id)
	check(plan(90155)["actions"][0]["modifiers"]["attack_add"] == 100.0 and plan(90156)["actions"][1]["modifiers"]["magic_attack_add"] == 100.0,"source100point group bonuses")

	var pet: Dictionary = pet_for()
	pet["skills"] = [90023,90037,90056]
	var modifiers: Dictionary = Rules.passive_modifiers(pet)
	check(close(modifiers["attack_rate"],0.03) and close(modifiers["magic_attack_rate"],0.03) and close(modifiers["crit_rate_add"],0.04),"passive physical/magic/crit sum")
	check(close(modifiers["max_hp_rate"],0.05) and close(modifiers["crit_resist_add"],0.12),"passiveHP and critical resistance")
	check(plan(90070)["actions"][0]["modifiers"] == {"fire_resist_rate":0.07},"fire resistance remains elemental")
	check(plan(90073)["actions"][1]["modifiers"] == {"water_resist_rate":0.07},"ice resistance remains elemental")
	check(plan(90060)["actions"][0]["modifiers"] == {"attack_rate":0.05,"magic_attack_rate":0.05},"documented generic attack aura mapping")
	check(plan(90079)["actions"][0]["modifiers"] == {"accuracy_add":0.03},"accuracy aura source probability")
	check(plan(90076)["actions"][0]["modifiers"] == {"evasion_add":0.03},"evasion aura source probability")
	var aura: Dictionary = plan(90058)
	check(aura["cooldown"] == 5.0 and aura["actions"][0]["duration"] == 10.0 and aura["actions"][0]["while_summoned"],"explicit modern aura lease/refresh")
	options = context(90058)
	options["owner_distance"] = 13.0
	check(Rules.build(pet_for(90058),owner(),enemy(),options)["actions"].size() == 1,"far owner gets no aura")
	check(plan(90041)["actions"][0]["amount"] == 20 and plan(90041)["actions"][1]["amount"] == 30,"each heal uses recipient own baseHP")
	check(plan(90057)["actions"][0]["amount"] == 50 and plan(90057)["actions"][1]["amount"] == 75,"healIII preserves source25percent")
	pet = pet_for(90041)
	pet["hp"] = 195
	var own: Dictionary = owner()
	own["hp"] = 298
	var healing: Dictionary = Rules.build(pet,own,{},context(90041))
	check(healing["actions"][0]["amount"] == 5 and healing["actions"][1]["amount"] == 2,"no overheal")
	pet["hp"] = pet["max_hp"]
	own["hp"] = own["max_hp"]
	check(not Rules.build(pet,own,{},context(90041))["ok"],"full health does not waste mana")
	own["hp"] = 0
	check(not Rules.build(pet,own,{},context(90041))["ok"],"no healing a dead owner")
	pet["hp"] = 0
	check(not Rules.build(pet,owner(),{},context(90041))["ok"],"dead pet cannot heal or act")

	check(Rules.definition(90036)["source_candidate_mp_cost"] == 40 and plan(90036)["mp_cost"] == 2,"modernMP raw40 becomes2")
	check(plan(90145)["mp_cost"] == 3 and plan(90057)["mp_cost"] == 25,"modernMP ceil raw50/500 becomes3/25")
	check(plan(90155)["cooldown"] == 180.0 and plan(90157)["cooldown"] == 60.0,"source cooldown seconds retained")
	pet = pet_for(90036)
	pet["mp"] = 1
	var denied: Dictionary = Rules.build(pet,owner(),enemy(),context(90036))
	check(not denied["ok"] and denied["actions"].is_empty() and denied["mp_cost"] == 0 and pet["mp"] == 1,"mana guard never spends or underflows")
	pet["mp"] = 0
	pet["skills"] = [90036,90014]
	check(Rules.build(pet,owner(),enemy(),{"distance":1,"target_is_monster":true})["skill_id"] == 90014,"auto falls back to affordable owned attack")
	pet = pet_for(90014)
	pet["skill_cooldowns"] = {"90014":0.01}
	check(not Rules.build(pet,owner(),enemy(),context(90014))["ok"],"cooldown blocks plan")
	check(not Rules.build(pet,owner(),enemy(),{"selected_skill_id":90014,"elapsed":100,"distance":1,"target_is_monster":true})["ok"],"elapsed cannot bypass cooldown")
	pet.erase("skill_cooldowns")
	check(not Rules.build(pet,owner(),enemy(),context(90020))["ok"],"player skill spoof rejected")
	check(not Rules.build(pet,owner(),enemy(),context(90145))["ok"],"other species innate spoof rejected")
	pet["innate_skill_id"] = 90145
	check(Rules.build(pet,owner(),enemy(),{"triggered_innate":true,"distance":1,"target_is_monster":true})["skill_id"] == 90150,"innate selected from verified species, not claimed field")
	pet["skills"] = [90145]
	check(not Rules.build(pet,owner(),enemy(),context(90145))["ok"],"innate cannot be forged as a random skill")
	pet = pet_for(90014)
	check(not Rules.build(pet,owner(),enemy(),{"selected_skill_id":90036,"distance":1,"target_is_monster":true})["ok"],"unowned random skill rejected")
	check(not Rules.build(pet,owner(),enemy(),{"selected_skill_id":90014,"distance":1})["ok"],"hostile permission fails closed")
	options = context(90014)
	options["target_is_ally"] = true
	check(not Rules.build(pet,owner(),enemy(),options)["ok"],"ally attack blocked")
	options = context(90014)
	options["distance"] = 2.5
	check(Rules.build(pet,owner(),enemy(),options)["ok"],"melee boundary allowed")
	options["distance"] = 2.50001
	check(not Rules.build(pet,owner(),enemy(),options)["ok"],"melee out of range blocked")
	options = context(90036)
	options["distance"] = 10.01
	check(not Rules.build(pet_for(90036),owner(),enemy(),options)["ok"],"magic out of range blocked")
	options.erase("distance")
	check(not Rules.build(pet_for(90036),owner(),enemy(),options)["ok"],"missing hostile distance rejected")
	var foe: Dictionary = enemy()
	foe["hp"] = 0
	check(not Rules.build(pet,owner(),foe,context(90014))["ok"],"dead enemy rejected")
	foe = enemy()
	foe["account_id"] = 1
	check(not Rules.build(pet,owner(),foe,context(90014))["ok"],"owner self-target spoof rejected")
	options = context(90014)
	options["controls_blocked"] = true
	check(not Rules.build(pet,owner(),enemy(),options)["ok"],"blocked controls stop action")
	pet["hunger"] = 0
	check(not Rules.build(pet,owner(),enemy(),context(90014))["ok"],"hungry pet cannot attack")
	pet = pet_for(90023)
	pet["summoned"] = false
	check(Rules.passive_modifiers(pet).is_empty() and not Rules.build(pet,owner(),enemy(),context(90023))["ok"],"dismissed pet cannot supply passive or active effects")

	for field: String in ["mp","attack","level","max_hp"]:
		pet = pet_for(90036)
		pet[field] = NAN
		check(not Rules.build(pet,owner(),enemy(),context(90036))["ok"],"nonfinite snapshot %s" % field)
	for field: String in ["distance","roll","owner_distance","selected_skill_id"]:
		options = context(90014)
		options[field] = INF
		check(not Rules.build(pet_for(90014),owner(),enemy(),options)["ok"],"nonfinite context %s" % field)
	options = context(90157)
	options["roll"] = 0.4999
	var success: Dictionary = Rules.build(pet_for(90157),owner(),enemy(),options)
	check(success["actions"][0]["kind"] == "dispel" and success["actions"][0]["succeeded"] and success["actions"][0]["maximum"] == 1,"worm source50percent removes one positive effect")
	options["roll"] = 0.5
	var failed: Dictionary = Rules.build(pet_for(90157),owner(),enemy(),options)
	check(failed["ok"] and not failed["actions"][0]["succeeded"] and failed["mp_cost"] == 10,"failed dispel still has cost and cooldown")
	check(failed == Rules.build(pet_for(90157),owner(),enemy(),options),"fixed roll produces deterministic plan")
	options.erase("roll")
	check(not Rules.build(pet_for(90157),owner(),enemy(),options)["ok"],"probabilistic action requires caller roll")
	seed(1456)
	var expected: float = randf()
	seed(1456)
	plan(90157)
	check(randf() == expected,"planner never consumes global RNG")
	pet = pet_for(90014)
	pet["poison"] = {"duration":100,"damage":999}
	pet["regen"] = 999
	pet["shield_rate"] = 100
	var injected: Dictionary = Rules.build(pet,owner(),enemy(),context(90014))
	check(injected["actions"].size() == 1 and injected["actions"][0]["kind"] == "damage","injected poison regen shield cannot fabricate source skills")
	print("PET_SKILL_RULES: %d checks, %d failures" % [checks,failures])
	print("PET_SKILL_RULES_SUITE: PASS" if failures == 0 else "PET_SKILL_RULES_SUITE: FAIL")
	quit(1 if failures else 0)
