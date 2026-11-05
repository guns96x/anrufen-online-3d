class_name OriginalSkillController
extends RefCounted

var player: Node

func tick(delta: float) -> void:
	var had_effects: bool = not player.stats.get("skill_effects",[]).is_empty()
	for event: Dictionary in StatusEffects.tick(player.stats,delta):
		if not player.is_dead: player.take_damage(int(event["damage"]))
	if had_effects: CharacterSystem.rebuild_stats(player.stats,CharacterSystem.equipment_bonuses(player.stats))
	var selected: int = int(player.stats.get("hotbar",{}).get("1",0))
	if SkillRules.catalog().has(selected): player.cooldowns["fire"] = float(player.stats["skill_cooldowns"].get(str(selected),0))

func cast(slot: String = "1") -> bool:
	var stats: Dictionary = player.stats
	var id: int = int(stats.get("hotbar",{}).get(slot,0))
	var definitions: Dictionary = SkillRules.player_definitions()
	if not definitions.has(id): return false
	var definition: Dictionary = definitions[id]
	var rank: int = int(stats.get("skills",{}).get(str(id),0))
	if rank <= 0 or not SkillRules.allowed(int(stats.get("class_id",130001)),id) or int(stats.get("level",1)) < int(definition["level"]): return _fail("Навичка недоступна цій професії або рівню.")
	var self_target: Dictionary = {"kind":"player","id":0,"stats":stats}
	var allies: Array[Dictionary] = [self_target]
	var targets: Array[Dictionary] = []
	if id not in SkillRules.SELF_SKILLS and id not in SkillRules.PARTY_SKILLS:
		if not MountSystem.can_attack(stats): return _fail("Верха атакувати не можна.")
		var selected: Monster = null
		if is_instance_valid(player.current_target) and player.current_target is Monster and not player.current_target.is_dead(): selected = player.current_target
		else: selected = player._nearest_monster(float(definition["range"]))
		if selected == null or player.global_position.distance_to(selected.global_position) > float(definition["range"]): return _fail("Ціль надто далеко.")
		player.current_target = selected
		if id in SkillRules.AREA_SKILLS:
			for monster: Monster in player.get_tree().get_nodes_in_group("monsters"):
				if not monster.is_dead() and selected.global_position.distance_to(monster.global_position) <= 5.0:
					targets.append({"kind":"monster","id":str(monster.name),"stats":monster.stats})
		else:
			targets.append({"kind":"monster","id":str(selected.name),"stats":selected.stats})
	var plan: Dictionary = SkillActionPlan.build(stats,id,rank,self_target,targets,allies)
	if not plan["ok"]: return _fail(str(plan["error"]))
	stats["mp"] -= int(plan["mp"])
	stats["skill_cooldowns"][str(id)] = float(plan["cooldown"])
	if slot == "1": player.cooldowns["fire"] = float(plan["cooldown"])
	player.time_since_combat = 0.0
	for action: Dictionary in plan["actions"]: _apply(action,id)
	var color: Color = Color.SKY_BLUE if id >= 90122 or id == 90105 else Color.GOLD
	CombatFeedback.arc(player.get_parent(),player.global_position,player.visual_root.rotation.y,color,2.4)
	if player._motion: player._motion.strike_left = 0.35
	player._float_text(player.global_position+Vector3.UP*2,str(definition["name"]),color)
	return true

func _apply(action: Dictionary, id: int) -> void:
	var target: Dictionary = action["target"]
	var monster: Monster = null
	var stats: Dictionary = player.stats
	if target["kind"] == "monster":
		for candidate: Monster in player.get_tree().get_nodes_in_group("monsters"):
			if str(candidate.name) == str(target["id"]): monster = candidate; break
		if monster == null or monster.is_dead(): return
		stats = monster.stats
	match action["type"]:
		"damage":
			if monster: monster.take_damage(action["result"],player)
		"heal":
			var amount: int = mini(int(stats["max_hp"])-int(stats["hp"]),int(action["amount"]))
			stats["hp"] += amount
			player._float_text(player.global_position+Vector3.UP*1.5,"+%d" % amount,Color.GREEN)
		"buff": StatusEffects.add(stats,id,int(action["rank"]),float(action["duration"]),bool(action["positive"]),action["modifiers"],0,action.get("periodic",{}))
		"cleanse": StatusEffects.cleanse(stats,bool(action["positive"]),int(action["maximum"]),float(action["chance"]))
		"drain": stats["mp"] = maxi(0,int(stats.get("mp",0))-int(action["amount"]))
		"taunt":
			if monster:
				monster.add_threat(player,float(action["hate"]))
				monster.state = Monster.State.CHASE
	if action["type"] in ["buff","cleanse"]:
		if monster: monster.refresh_status_stats()
		else: CharacterSystem.rebuild_stats(stats,CharacterSystem.equipment_bonuses(stats))

func _fail(text: String) -> bool:
	player._float_text(player.global_position+Vector3.UP*2,text,Color.SALMON)
	return false
