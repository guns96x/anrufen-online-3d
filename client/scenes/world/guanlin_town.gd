class_name GuanlinTown
extends Node3D

@onready var hud: GameHUD = $HUD
@onready var local_player: Player = $Player
@onready var elder_npc: NPC = $NPC_Elder

var _target_ring: MeshInstance3D
var forage: ForestForage = ForestForage.new()
var forage_patches: Dictionary = {}

func _ready() -> void:
	# Add HUD to group so floating damage numbers and quest kills can access it
	hud.add_to_group("hud")

	# Procedural set dressing (grass, forest border, lamps, water, bounds)
	var decor: WorldDecor = WorldDecor.new()
	decor.name = "WorldDecor"
	add_child(decor)
	var presentation: VillagePresentation = VillagePresentation.new()
	presentation.name = "VillagePresentation"
	add_child(presentation)
	_configure_citizens()
	_spawn_bandits()
	_dress_creatures()
	for id: int in ForestForage.POINTS:
		var patch: ForagePatch = ForagePatch.new()
		patch.name = "WildVegetables%d" % id
		patch.point_id = id
		patch.position = ForestForage.POINTS[id]
		add_child(patch)
		forage_patches[id] = patch
	for monster: Node in get_tree().get_nodes_in_group("monsters"):
		monster.monster_died.connect(_on_monster_defeated)
	call_deferred("_bind_companion")

	# Wire HUD controls to player
	hud.joystick.joystick_updated.connect(local_player.set_move_vector)
	hud.attack_pressed.connect(local_player.perform_attack)
	hud.skill_1_pressed.connect(local_player.perform_skill_1)
	hud.assigned_skill_pressed.connect(local_player.perform_assigned_skill)
	hud.skill_2_pressed.connect(local_player.perform_skill_2)
	hud.interact_pressed.connect(_on_interact)
	local_player.ui_hit_test = hud.is_point_over_ui
	local_player.leveled_up.connect(func(lv: int) -> void: hud.show_banner("Level Up! Lv.%d" % lv))

	_build_target_ring()
	var bridge: NetworkWorldBridge = NetworkWorldBridge.new()
	bridge.world = self
	add_child(bridge)
	_update_hud_stats()
	if NewHero.play_intro:
		NewHero.play_intro = false
		call_deferred("_play_intro")
	else:
		hud.show_banner("Ґуаньлінь", Color(1.0, 0.92, 0.7))
	print("[GuanlinTown] 3D World initialized. Ready for player!")

var intro: IntroCinematic

func _play_intro() -> void:
	intro = IntroCinematic.new()
	intro.world = self
	intro.hero_name = str(local_player.stats.get("name", "Мандрівник"))
	add_child(intro)

func _bind_companion() -> void:
	var follower: CompanionFollower = CompanionFollower.new()
	follower.owner_player = local_player
	follower.companions = hud.pets
	follower.position = local_player.position + Vector3(1,0,1)
	add_child(follower)
	SettingsStore.current().apply_all()

func _on_monster_defeated(monster: Monster, killer: Node3D) -> void:
	if killer != local_player:
		return
	var uid: String = str(local_player.stats.get("summoned_pet",""))
	if not uid.is_empty():
		hud.pets.gain_exp(uid,maxi(1,monster.exp_reward/3))
	var loot: GroundLoot = GroundLoot.new()
	loot.position = monster.global_position + Vector3(0,0.2,0)
	loot.copper = 4 if monster.monster_id == 70071 else 2
	if monster.monster_id == 70073:
		loot.contents = {"30037":1}
	elif monster.monster_id == 70076:
		loot.contents = {"30038":1}
	elif randf() < 0.3:
		loot.contents = {"30016":1}
	add_child(loot)
	if SettingsStore.current().get_value("auto_loot"):
		var kinds: Array[String] = ["coins_only"]
		if SettingsStore.current().get_value("loot_equipment"):
			kinds.append_array(["equipment","mount"])
		if SettingsStore.current().get_value("loot_supplies"):
			kinds.append_array(["consumable","pet_food","pet_potion"])
		if SettingsStore.current().get_value("loot_materials"):
			kinds.append_array(["material","pet_egg"])
		loot.pickup(hud.items,kinds)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("game_menu"):
		if hud.is_modal_active():
			hud.close_dialogue()
		else:
			hud.game_menu.open_tab("inventory")
		return
	if hud.is_modal_active():
		return
	for entry: Array in [["bag","inventory"],["character","character"],["skills","skills"],["journal","journal"],["map","map"]]:
		if event.is_action_pressed("game_"+entry[0]):
			hud.game_menu.open_tab(entry[1])
			return
	if event.is_action_pressed("game_interact"):
		_on_interact()
	elif event.is_action_pressed("game_attack"):
		local_player.perform_attack()
	elif event.is_action_pressed("game_fire"):
		local_player.perform_skill_1()
	elif event.is_action_pressed("game_dash"):
		local_player.perform_skill_2()
	for slot: String in ["2","3","4"]:
		if event.is_action_pressed("game_slot_"+slot): local_player.perform_assigned_skill(slot)

func _on_interact() -> void:
	if local_player.is_dead:
		return
	if local_player.get_meta("network_world",false) and get_node("/root/NetworkManager").world_snapshot.get("state",{}).get("loot",{}).size() > 0:
		for entry: Dictionary in get_node("/root/NetworkManager").world_snapshot["state"]["loot"].values():
			if int(entry["owner"]) == int(get_node("/root/NetworkManager").world_snapshot["own_id"]) and local_player.global_position.distance_to(entry["position"]) < 3.0:
				get_node("/root/NetworkManager").request("game_pickup",{"id":entry["id"]})
				return
	var loot: GroundLoot = _closest_loot()
	if loot:
		loot.pickup(hud.items)
		return
	var patch: ForagePatch = _closest_forage()
	if patch:
		if local_player.get_meta("network_world",false):
			get_node("/root/NetworkManager").request("game_forage",{"id":patch.point_id})
		elif forage.harvest(patch.point_id,local_player.global_position,hud.items,Time.get_ticks_msec()/1000.0):
			hud.show_banner("Зібрано дику зелень")
		return
	if local_player.nearby_npc:
		local_player.nearby_npc.interact(hud)
	else:
		var npc: NPC = _closest_npc(4.0)
		if npc:
			npc.interact(hud)

func _closest_loot() -> GroundLoot:
	var best: GroundLoot = null
	var distance: float = 3.0
	for node: Node in get_tree().get_nodes_in_group("ground_loot"):
		var candidate: float = local_player.global_position.distance_to(node.global_position)
		if candidate < distance:
			best = node
			distance = candidate
	return best

func _closest_forage() -> ForagePatch:
	var best: ForagePatch = null
	var distance: float = 2.8
	for patch: ForagePatch in forage_patches.values():
		if patch.available and local_player.global_position.distance_to(patch.global_position) < distance:
			best = patch
			distance = local_player.global_position.distance_to(patch.global_position)
	return best

func _closest_npc(max_dist: float) -> NPC:
	var best: NPC = null
	var best_d: float = max_dist
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if n is NPC:
			var d: float = local_player.global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	return best

## Ukrainian display names for the original Guanlin citizens (GuanlinLayout.CITIZENS).
const CITIZEN_NAMES: Dictionary = {
	"mayor": "Староста Ґуаньліня", "ranger": "Лісовий рейнджер",
	"militia_captain": "Капітан ополчення", "gourmand": "Ласун",
	"widow_anna": "Вдова Анна", "smuggler": "Контрабандист",
	"madman": "Божевільний", "madmans_wife": "Дружина божевільного",
	"tribune": "Трибун", "tom": "Том", "jessie": "Джессі",
	"alchemist": "Алхімік", "breeder": "Садівник-селекціонер",
	"doctor_jack": "Лікар Джек", "mailbox": "Поштова скринька",
	"jeweller": "Ювелір", "beast_tamer": "Дресирувальник",
	"weapon_merchant": "Торговець зброєю", "item_merchant": "Крамар",
	"resident": "Мешканець", "stable_master": "Господар станції",
	"mystery_merchant": "Таємничий торговець", "arena_steward": "Розпорядник арени",
	"consign_gems": "Комісія: самоцвіти", "consign_weapons": "Комісія: зброя",
	"consign_armor": "Комісія: обладунки", "consign_jewelry": "Комісія: прикраси",
	"consign_beasts": "Комісія: звірі", "consign_goods": "Комісія: крам",
	"armor_merchant": "Торговець обладунками", "accessory_merchant": "Торговка прикрасами",
}
const CITIZEN_QUESTS: Dictionary = {50164: 80004, 50166: 80552, 50179: 80591, 50167: 80006, 50168: 80012, 50169: 80010}
## Scene node names kept stable for saves, tests and tools.
const CITIZEN_NODES: Dictionary = {50164: "NPC_Elder", 50166: "NPC_Militia", 50179: "NPC_Weaponsmith",
	50167: "NPC_Gourmand", 50168: "NPC_Anna", 50169: "NPC_Smuggler", 50180: "NPC_Breeder",
	50182: "NPC_Jeweler", 50184: "NPC_Postmaster"}

func _configure_citizens() -> void:
	var used: Dictionary = {}
	for entry: Array in GuanlinLayout.CITIZENS:
		var id: int = entry[0]
		var base_name: String = CITIZEN_NODES.get(id, "NPC_%s" % String(entry[1]).to_pascal_case())
		used[base_name] = used.get(base_name, 0) + 1
		var node_name: String = base_name if used[base_name] == 1 else base_name + str(used[base_name])
		var npc: NPC = get_node_or_null(node_name)
		if npc == null:
			npc = preload("res://client/scenes/entities/npc.tscn").instantiate()
			npc.name = node_name
			add_child(npc)
		npc.position = entry[2]
		npc.rotation.y = atan2(-npc.position.x, -(npc.position.z - GuanlinLayout.TOWN_Z)) if absf(npc.position.x) > 0.5 else 0.0
		npc.configure_npc(CITIZEN_NAMES.get(entry[1], String(entry[1])), "", CITIZEN_QUESTS.get(id, 0), id)
		_dress_citizen(npc, entry[1], used[base_name] - 1)

func _dress_citizen(npc: NPC, role: String, variant: int) -> void:
	for child: Node in npc.visual_root.get_children():
		child.free()
	npc.visual_root.add_child(CitizenLook.mailbox() if role == "mailbox" else CitizenLook.build(role, variant))

## Forest creatures built by tools/build_creatures.py: [model, scale, yaw degrees].
const CREATURES: Dictionary = {
	"вепр": ["res://assets/creatures/boar.glb", 0.17, 180.0],
	"павук": ["res://assets/creatures/spider.glb", 0.75, 0.0],
	"шакал": ["res://assets/creatures/jackal.glb", 0.15, 90.0],
}

func _dress_creatures() -> void:
	for node: Node in $Monsters.get_children():
		var monster: Monster = node as Monster
		if monster == null or monster.animator != null:
			continue
		var key: String = ""
		for word: String in CREATURES:
			if word in monster.monster_name.to_lower():
				key = word
		if key.is_empty():
			continue
		for child: Node in monster.visual_root.get_children():
			child.free()
		var model: Node3D = (load(CREATURES[key][0]) as PackedScene).instantiate()
		model.scale = Vector3.ONE * float(CREATURES[key][1])
		model.rotation.y = deg_to_rad(float(CREATURES[key][2]))
		monster.visual_root.add_child(model)
		MobAnimator.attach(monster, "creature")

func _spawn_bandits() -> void:
	var index: int = 0
	for spot: Vector3 in [Vector3(27, 0, 28), Vector3(30, 0, 39), Vector3(-29, 0, 27), Vector3(-31, 0, 47), Vector3(28, 0, 57)]:
		var bandit: Monster = preload("res://client/scenes/entities/monster.tscn").instantiate()
		index += 1
		bandit.name = "Bandit%d" % index
		bandit.monster_id = 70071
		bandit.monster_name = "Розбійник банди Гадюки"
		bandit.max_hp = 70
		bandit.attack_damage = 14
		bandit.position = spot
		$Monsters.add_child(bandit)
		for child: Node in bandit.visual_root.get_children():
			child.free()
		bandit.visual_root.add_child(CitizenLook.build("viper_brute" if index % 3 == 0 else "viper_bandit"))
		MobAnimator.attach(bandit)

func _process(delta: float) -> void:
	local_player.controls_blocked = hud.is_modal_active()
	_read_keyboard_movement()
	_update_hud_stats()
	hud.update_cooldowns(local_player)
	var online: bool = local_player.get_meta("network_world",false)
	var states: Dictionary = get_node("/root/NetworkManager").world_snapshot.get("state",{}).get("forage",{}) if online else forage.snapshot(Time.get_ticks_msec()/1000.0)
	for id: int in forage_patches: forage_patches[id].set_available(bool(states.get(str(id),false)))
	hud.set_interact_available(local_player.nearby_npc != null or _closest_npc(4.0) != null or _closest_loot() != null or _closest_forage() != null)
	hud.show_death(local_player.is_dead, local_player.respawn_timer)
	_update_target_ring(delta)

var _kb_was_moving: bool = false

func _read_keyboard_movement() -> void:
	if is_instance_valid(intro):
		local_player.controls_blocked = true
	if local_player.controls_blocked:
		local_player.set_move_vector(Vector2.ZERO)
		return
	if hud.joystick.is_pressed:
		_kb_was_moving = false
		return
	var v: Vector2 = Input.get_vector("game_move_left","game_move_right","game_move_forward","game_move_back")
	if v.length() > 0.05:
		local_player.set_move_vector(v.normalized())
		_kb_was_moving = true
	elif _kb_was_moving:
		local_player.set_move_vector(Vector2.ZERO)
		_kb_was_moving = false

func _update_hud_stats() -> void:
	if local_player and hud:
		hud.update_player_stats(local_player.stats)

func _build_target_ring() -> void:
	_target_ring = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 24
	_target_ring.mesh = torus
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.3, 0.2)
	_target_ring.material_override = mat
	_target_ring.scale = Vector3(1, 0.05, 1)
	_target_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_target_ring.hide()
	add_child(_target_ring)

func _update_target_ring(delta: float) -> void:
	var t: Node3D = local_player.current_target
	var valid: bool = t != null and is_instance_valid(t)
	if valid and t is Monster and t.is_dead():
		valid = false
	_target_ring.visible = valid
	if valid:
		_target_ring.global_position = t.global_position + Vector3(0, 0.08, 0)
		_target_ring.rotate_y(delta * 1.5)
		var mat: StandardMaterial3D = _target_ring.material_override
		mat.albedo_color = Color(1.0, 0.3, 0.2) if t is Monster else Color(1.0, 0.85, 0.3)
