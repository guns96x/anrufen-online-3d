class_name SkillActionPlan
extends RefCounted

# Callers supply legal, in-range targets. Planning never changes any profile.
# Source constants/semantics are shared by the offline and server adapters.
static func build(stats: Dictionary, id: int, rank: int, self_target: Dictionary, targets: Array[Dictionary], allies: Array[Dictionary]) -> Dictionary:
	var definitions: Dictionary = SkillRules.player_definitions()
	if not definitions.has(id) or id in SkillRules.PASSIVES or rank < 1 or rank > int(definitions[id]["max_rank"]): return _fail("Ця навичка не є доступною активною дією.")
	if float(stats.get("skill_cooldowns",{}).get(str(id),0)) > 0.0: return _fail("Навичка відновлюється.")
	var needs_enemy: bool = id not in SkillRules.SELF_SKILLS and id not in SkillRules.PARTY_SKILLS
	if needs_enemy and targets.is_empty(): return _fail("Немає доступної цілі в межах дії.")
	if id == 90139 and targets[0].get("kind") != "player": return _fail("Прокляття тіні діє лише на гравців.")
	var mp: int = int(stats.get("mp",0)) if id == 90113 else int(definitions[id]["mp"])
	if int(stats.get("mp",0)) < mp or (id == 90113 and mp == 0): return _fail("Недостатньо мани.")
	var actions: Array[Dictionary] = []
	var phy: float = float(stats.get("attack",1))
	var mag: float = float(stats.get("magic_attack",stats.get("attack",1)))
	var value: Callable = func(key: String) -> float: return SkillRules.value(id,key,rank)
	match id:
		90020: _damage(actions,stats,targets[0],phy+value.call("add_phy"),1)
		90095:
			_damage(actions,stats,targets[0],phy+value.call("add_phy"),1)
			_buff(actions,self_target,id,rank,value.call("buff_duration"),true,{"attack_add":value.call("buff_phy")})
		90021: _damage(actions,stats,targets[0],phy*value.call("phy_basic")/100.0+value.call("add_phy"),1)
		90044:
			_damage(actions,stats,targets[0],phy*(1.0+value.call("add_phy_rate")/100.0),1)
			_damage(actions,stats,targets[0],value.call("add_holy"),4)
		90104,90131,90135:
			var key: String = "max_hp_add" if id == 90104 else "max_mp_add" if id == 90131 else "resist_add"
			var source: String = "add_hp_max" if id == 90104 else "add_mp_max" if id == 90131 else "add_resist"
			var duration: float = value.call("buff_duration")*(60.0 if id in [90104,90131] else 1.0)
			for ally: Dictionary in allies: _buff(actions,ally,id,rank,duration,true,{key:value.call(source)})
		90084: _buff(actions,self_target,id,rank,value.call("buff_duration"),true,{"speed_add":value.call("add_speed")})
		90105: actions.append({"type":"drain","target":_target(targets[0]),"amount":roundi(phy*value.call("add_phy_rate")/100.0+value.call("damage_mp"))})
		90117: _damage(actions,stats,targets[0],phy*(1.0+value.call("add_phy_rate")/100.0)+value.call("add_phy"),1)
		90119: actions.append({"type":"cleanse","target":_target(self_target),"positive":false,"maximum":int(value.call("rem_buff_num")),"chance":value.call("rem_buff_rate")})
		90120: _buff(actions,self_target,id,rank,value.call("buff_duration"),true,{"attack_rate":value.call("add_phy_rate")/100.0,"max_hp_add":value.call("add_hp_max"),"defense_rate":-value.call("sub_def")/100.0,"resist_rate":-value.call("sub_def")/100.0})
		90121:
			_damage(actions,stats,targets[0],phy+value.call("add_phy1"),1)
			_damage(actions,stats,targets[0],phy+value.call("add_phy2"),1)
			_damage(actions,stats,targets[0],phy*(1.0+value.call("add_phy_rate")/100.0)+value.call("add_phy3"),1,value.call("add_fatal_rate")/100.0)
		90106:
			if targets[0].get("kind") != "monster": return _fail("Провокація діє на монстрів.")
			actions.append({"type":"taunt","target":_target(targets[0]),"hate":value.call("add_hate")})
		90113: _damage(actions,stats,targets[0],float(mp)*value.call("tran_rate"),4,0.0,value.call("add_hit")/100.0)
		90115: _buff(actions,self_target,id,rank,value.call("buff_duration"),true,{"defense_add":value.call("add_resist"),"resist_add":value.call("add_resist")})
		90116: actions.append({"type":"cleanse","target":_target(targets[0]),"positive":true,"maximum":int(value.call("rem_buff_num")),"chance":value.call("rem_buff_rate")})
		90122: _damage(actions,stats,targets[0],mag+value.call("add_fire"),2)
		90126: actions.append({"type":"heal","target":_target(self_target),"amount":int(value.call("add_hp"))})
		90123: _damage(actions,stats,targets[0],mag+value.call("add_water"),3,value.call("add_fatal")/100.0)
		90127: _damage(actions,stats,targets[0],mag*(1.0+value.call("add_fire_rate")/100.0)+value.call("add_fire_val"),2)
		90129: _buff(actions,self_target,id,rank,30.0,true,{"shield_rate":value.call("work_rate"),"shield_ratio":value.call("mp_trans_hp")})
		90128:
			for target: Dictionary in targets: _damage(actions,stats,target,mag*value.call("basic_attack_rate")/100.0+value.call("add_water"),3)
		90132:
			for ally: Dictionary in allies: actions.append({"type":"heal","target":_target(ally),"amount":roundi(float(ally["stats"].get("base_max_hp",ally["stats"].get("max_hp",1)))*value.call("add_hp_rate")/100.0)})
		90134:
			_damage(actions,stats,targets[0],mag*(1.0+value.call("add_water_rate")/100.0)+value.call("add_water"),3)
			if not actions[-1]["result"].get("is_miss",false) and randf()*100.0 < value.call("buff_rate"):
				_buff(actions,targets[0],id,rank,value.call("buff_duration"),false,{"rooted":1.0})
		90136,90137,90140:
			var element: int = 2 if id == 90136 else 5
			var flat: String = "add_fire" if id == 90136 else "add_dark"
			var rate: String = "add_fire_rate" if id == 90136 else "add_dark_rate"
			for target: Dictionary in targets: _damage(actions,stats,target,mag*(1.0+value.call(rate)/100.0)+value.call(flat),element,value.call("add_fatal")/100.0)
		90138:
			for target: Dictionary in targets: _buff(actions,target,id,rank,value.call("debuff_duration"),false,{"defense_rate":-value.call("ignore_per")/100.0,"resist_rate":-value.call("ignore_per")/100.0})
		90139:
			var periodic: Dictionary = {"interval":value.call("buff_interval"),"next":value.call("buff_interval"),"step":0,"rates":SkillRules.catalog()[id]["constants"]["damage_rate"].duplicate()}
			_buff(actions,targets[0],id,rank,value.call("buff_duration"),false,{},periodic)
		_: return _fail("Виконання цієї навички ще не під'єднане.")
	return {"ok":true,"error":"","actions":actions,"mp":mp,"cooldown":float(definitions[id]["cooldown"]),"skill_id":id,"rank":rank}

static func _target(target: Dictionary) -> Dictionary:
	return {"kind":target["kind"],"id":target["id"]}

static func _damage(actions: Array[Dictionary], stats: Dictionary, target: Dictionary, power: float, element: int, critical: float = 0.0, accuracy: float = 0.0) -> void:
	var attack: Dictionary = stats.duplicate(true)
	attack["attack"] = power
	attack["crit_rate"] = clampf(float(stats.get("crit_rate",0))+critical,0.0,1.0)
	attack["accuracy"] = clampf(float(stats.get("accuracy",0.95))+accuracy,0.0,1.0)
	var defender: Dictionary = target["stats"].duplicate(true)
	if element != 1: defender["defense"] = float(defender.get("magic_defense",defender.get("defense",0)))+float(defender.get("resist",0))
	var result: Dictionary = CombatFormulas.calculate_damage(attack,defender,1.0,element)
	actions.append({"type":"damage","target":_target(target),"result":result})

static func _buff(actions: Array[Dictionary], target: Dictionary, id: int, rank: int, duration: float, positive: bool, modifiers: Dictionary, periodic: Dictionary = {}) -> void:
	actions.append({"type":"buff","target":_target(target),"skill_id":id,"rank":rank,"duration":duration,"positive":positive,"modifiers":modifiers,"periodic":periodic})

static func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message,"actions":[]}
