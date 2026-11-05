extends SceneTree
var failures: int = 0
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var actor: ProfileActor = ProfileActor.new()
	var stats: Dictionary = {"name":"Source Hero","class_name":"Воїн","level":20,"exp":0,"exp_to_next":100000,"hp":100,"max_hp":100,"mp":50,"max_mp":50,"attack":22,"defense":8,"accuracy":0.95,"crit_rate":0.15,"evasion":0.05,"element":1,"copper":500,"inventory":{}}
	actor.bind_profile(stats)
	stats["skill_points"] = 20
	check(stats["skills"] == {"90020":1} and stats["hotbar"] == {"1":90020},"new warrior starts with original free sword skill")
	var points: int = int(stats["skill_points"])
	check(not CharacterSystem.learn_skill(stats,90095) and stats["skill_points"] == points,"charged swing requires original Might rank five before spending")
	for i: int in 4: CharacterSystem.learn_skill(stats,90020)
	for i: int in 5: CharacterSystem.learn_skill(stats,90042)
	check(CharacterSystem.learn_skill(stats,90095),"satisfied source prerequisite unlocks charged swing")
	check(not CharacterSystem.learn_skill(stats,90122),"warrior cannot learn mage branch")
	for i: int in 5: CharacterSystem.learn_skill(stats,90042)
	check(stats["skills"]["90042"] == 10 and not CharacterSystem.learn_skill(stats,90042),"source rank-ten health limit enforced")
	CharacterSystem.learn_skill(stats,90022)
	CharacterSystem.rebuild_stats(stats)
	check(stats["max_hp"] == 100+19*15+2590 and stats["attack"] == 22+19*3+20,"real Lua passive health and attack bonuses affect character")
	stats["hp"] = stats["max_hp"]
	CharacterSystem.rebuild_stats(stats)
	check(stats["hp"] == stats["max_hp"],"repeated rebuild cannot truncate health supplied by passive")
	check(CharacterSystem.validate(stats),"rank-ten source skills validate in persisted profile")
	check(CharacterSystem.respec_skills(stats) and stats["skill_points"] == 20 and stats["skills"] == {"90020":1} and stats["copper"] == 400,"paid respec refunds spent ranks and keeps one free basic skill")
	check(not CharacterSystem.respec_skills(stats) and stats["skill_points"] == 20 and stats["copper"] == 400,"repeated respec cannot mint a free basic point or spend cash")
	for i: int in 4: CharacterSystem.learn_skill(stats,90020)
	for i: int in 10: CharacterSystem.learn_skill(stats,90042)
	actor.inventory.add_item(30092)
	check(actor.inventory.use_item(30092) and stats["skill_points"] == 20 and stats["skills"] == {"90020":1},"original reset book supports source ranks above the old prototype cap")
	check(CharacterSystem.choose_class(stats,130006,250001) and CharacterSystem.learn_skill(stats,90106),"advanced knight can learn its real source taunt")
	check(CharacterSystem.choose_class(stats,130007,250001) and not stats["skills"].has("90106") and stats["skill_points"] == 20,"branch change removes incompatible skill and returns its invested point")
	var bad: Dictionary = stats.duplicate(true)
	bad["skills"]["090022"] = 1
	check(not CharacterSystem.validate(bad),"noncanonical skill keys cannot duplicate a passive bonus")
	bad = stats.duplicate(true)
	bad["skills"]["90137"] = 1
	check(not CharacterSystem.validate(bad),"saved cross-class passive or active skill rejected")
	actor.free()
	var scene: GuanlinTown = load("res://client/scenes/world/guanlin_town.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var controller: ProgressionController = scene.hud.progression
	var path: String = "res://build/source-migrate-%d.json" % OS.get_process_id()
	controller.save_file_path = path
	check(controller.save_to_file(),"new source profile writes version-five schema")
	var previous: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	previous["version"] = 4
	previous["player_stats"]["skills"] = {"90014":1,"90036":1}
	previous["player_stats"]["hotbar"] = {"1":90036}
	for key: String in ["free_starter_skill","skill_effects","skill_cooldowns"]: previous["player_stats"].erase(key)
	var raw: String = JSON.stringify(previous)
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(raw)
	file.close()
	check(controller.load_from_file() and scene.local_player.stats["skills"] == {"90014":1,"90036":1},"version-four prototype hotbar loads with owned legacy abilities intact")
	check(FileAccess.get_file_as_string(path+".pre-v5") == raw,"migration preserves exact previous profile in independent backup")
	controller.save_to_file()
	controller.save_to_file()
	check(FileAccess.get_file_as_string(path+".pre-v5") == raw,"later rolling backups cannot overwrite pre-migration snapshot")
	for suffix: String in ["",".bak",".tmp",".pre-v5"]:
		if FileAccess.file_exists(path+suffix): DirAccess.remove_absolute(path+suffix)
	scene.queue_free()
	await process_frame
	await process_frame
	print("SOURCE_CHARACTER_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
