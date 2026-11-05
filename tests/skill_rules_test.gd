extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(SkillRules.catalog().size() == 44,"all 44 Lua-backed player skills recovered across eight classes")
	check(SkillRules.value(90020,"add_phy",1) == 20 and SkillRules.value(90020,"add_phy",99) == 225,"basic sword constants follow source rank lookup and cap")
	check(SkillRules.value(90022,"add_phy",15) == 380 and SkillRules.value(90042,"add_hp_max",1) == 190,"real passive attack and health constants recovered")
	check(SkillRules.passive_bonuses({"skills":{"90096":1,"90098":1}})["hp_regen"] == 1.5,"source regeneration is per ten seconds and converts to per-second rate")
	var definitions: Dictionary = SkillRules.player_definitions()
	check(definitions[90106]["cooldown"] == 45.0 and definitions[90020]["cooldown"] == 0.8,"binary cooldown field agrees with explicit original 45-second taunt text")
	check(definitions[90095]["prerequisite_skill"] == 90042 and definitions[90095]["prerequisite_rank"] == 5,"original Might rank-five prerequisite recovered")
	check(SkillRules.allowed(130006,90020) and SkillRules.allowed(130006,90106) and not SkillRules.allowed(130006,90137),"knight inherits warrior line and cannot learn shadow line")
	var stats: Dictionary = {"attack":50,"magic_attack":60,"defense":20,"hp":500,"max_hp":1000,"base_max_hp":1000,"mp":10000,"max_mp":10000,"accuracy":1.0,"crit_rate":0.0,"element":1,"skills":{}}
	var self_target: Dictionary = {"kind":"player","id":1,"stats":stats}
	var enemy: Dictionary = {"kind":"player","id":2,"stats":{"hp":5000,"max_hp":5000,"mp":5000,"defense":0,"evasion":0.0,"element":1}}
	var monster: Dictionary = {"kind":"monster","id":"Boar","stats":{"hp":5000,"defense":0,"evasion":0.0,"element":1}}
	var allies: Array[Dictionary] = [self_target,{"kind":"player","id":3,"stats":{"hp":50,"max_hp":200,"base_max_hp":200}}]
	var original: Dictionary = stats.duplicate(true)
	for id: int in definitions:
		var targets: Array[Dictionary] = []
		targets.append(monster if id == 90106 else enemy)
		var plan: Dictionary = SkillActionPlan.build(stats,id,1,self_target,targets,allies)
		check(bool(plan["ok"]) == (id not in SkillRules.PASSIVES),"source skill has executable active semantics or validated passive: %d" % id)
	check(stats == original,"planning every source skill cannot mutate or spend profile resources")
	var plan: Dictionary = SkillActionPlan.build(stats,90044,1,self_target,[enemy],allies)
	check(plan["actions"].size() == 2 and plan["actions"][0]["result"]["damage_type"] == 1 and plan["actions"][1]["result"]["damage_type"] == 4,"double strike preserves distinct physical and holy segments")
	plan = SkillActionPlan.build(stats,90121,1,self_target,[enemy],allies)
	check(plan["actions"].size() == 3,"berserker source combo emits three separately resolved attacks")
	plan = SkillActionPlan.build(stats,90113,1,self_target,[enemy],allies)
	check(plan["mp"] == 10000 and plan["actions"][0]["result"]["damage_type"] == 4,"holy blade consumes all available MP and deals holy damage")
	plan = SkillActionPlan.build(stats,90104,1,self_target,[enemy],allies)
	check(plan["actions"].size() == 2 and plan["actions"][0]["duration"] == 600.0 and plan["actions"][0]["modifiers"]["max_hp_add"] == 1200,"source aura affects supplied allies for original minutes duration")
	check(not SkillActionPlan.build(stats,90139,1,self_target,[monster],allies)["ok"],"shadow curse cannot affect monsters")
	check(not SkillActionPlan.build(stats,90020,1,self_target,[],allies)["ok"],"enemy-target spell cannot spend resources without a legal target")
	stats["skill_cooldowns"] = {"90020":1.0}
	check(not SkillActionPlan.build(stats,90020,1,self_target,[enemy],allies)["ok"],"skill-specific cooldown blocks recasting")
	StatusEffects.tick(stats,1.0)
	check(SkillActionPlan.build(stats,90020,1,self_target,[enemy],allies)["ok"],"expired skill cooldown becomes available")
	StatusEffects.add(stats,90129,1,30,true,{"shield_rate":64.0,"shield_ratio":2.0})
	stats["mp"] = 200
	check(StatusEffects.absorb(stats,100) == 36 and stats["mp"] == 72,"magic shield converts exact protected damage into MP consumption")
	stats["mp"] = 10
	check(StatusEffects.absorb(stats,100) == 95 and stats["mp"] == 0,"magic shield cannot protect beyond available MP")
	stats["skill_effects"] = []
	StatusEffects.add(stats,90139,1,10,false,{},2,{"interval":5.0,"next":5.0,"step":0,"rates":[20,30,40,50,60,70,90]})
	var ticks: Array[Dictionary] = StatusEffects.tick(stats,10.0)
	check(ticks.size() == 2 and ticks[0]["damage"] == 200 and ticks[1]["damage"] == 300 and stats["skill_effects"].is_empty(),"shadow curse preserves original progressive percentages and expiration")
	StatusEffects.add(stats,90115,1,5,true,{"defense_add":1400})
	StatusEffects.add(stats,90115,1,10,true,{"defense_add":1400})
	check(stats["skill_effects"].size() == 1 and StatusEffects.modifiers(stats)["defense_add"] == 1400,"refreshing the same shield cannot stack repeated defense")
	StatusEffects.add(stats,90134,1,5,false,{"rooted":1.0})
	check(StatusEffects.speed_multiplier(stats) == 0.0 and StatusEffects.cleanse(stats,false,1,100) == 1 and StatusEffects.speed_multiplier(stats) == 1.0,"freeze constrains movement and cleanse removes only negative effects")
	check(StatusEffects.validate(JSON.parse_string(JSON.stringify(stats))),"skill cooldowns and effects survive valid JSON representation")
	stats["skill_effects"][0]["remaining"] = -10
	check(not StatusEffects.validate(stats),"malformed saved status rejected")
	print("SKILL_RULES_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
