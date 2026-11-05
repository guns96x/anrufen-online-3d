extends SceneTree
const Menu = preload("res://client/scenes/ui/game_menu.gd")
class FakePlayer:
	extends Node3D
	var current_target: Node3D
	var stats: Dictionary = {"name":"Tester","class_name":"Воїн","level":1,"hp":40,"max_hp":100,"mp":20,"max_mp":50,"attack":22,"defense":8,"accuracy":1.0,"crit_rate":0.0,"evasion":0.0,"element":1,"exp":0,"exp_to_next":100,"copper":1000,"inventory":{"10010":1,"30016":3,"10018":1,"30029":1,"30015":1},"equipment":{},"bag_capacity":32,"warehouse":{"30037":2},"stat_points":2,"skill_points":1}
class FakeJoystick:
	extends Node
	func _reset() -> void:
		pass
class FakeHUD:
	extends Node
	var changes: int = 0
	var joystick: FakeJoystick
	var dialogue_box: Control
	func _init() -> void:
		joystick = FakeJoystick.new()
		dialogue_box = Control.new()
		add_child(joystick)
		add_child(dialogue_box)
	func on_systems_changed() -> void:
		changes += 1
class FakeNetwork:
	extends Node
	var requests: Array[Dictionary] = []
	var social_snapshot: Dictionary = {}
	var world_snapshot: Dictionary = {}
	var world_enabled: bool = true
	func request(action: String,payload: Dictionary = {}) -> void:
		requests.append({"action":action,"payload":payload.duplicate(true)})
class FakeCitizen:
	extends Node3D
	var citizen_id: int = 50179
	var npc_name: String = "Merchant"
var failures: int = 0
var menu: GameMenu
var actor: FakePlayer
var fake_network: FakeNetwork
var fake_hud: FakeHUD

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool,label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func show_tab(tab: String) -> void:
	menu._tab = tab
	menu.show()
	menu.render()

func press(text: String, row_contains: String = "") -> bool:
	for node: Node in menu._content.find_children("*","Button",true,false):
		var button: Button = node
		if button.text != text:
			continue
		if not row_contains.is_empty():
			var labels: Array[Node] = button.get_parent().find_children("*","Label",false,false)
			if labels.is_empty() or not row_contains in str(labels[0].text):
				continue
		button.pressed.emit()
		return true
	check(false,"button exists: " + text)
	return false

func expect(action: String,payload: Dictionary,label: String) -> void:
	check(not fake_network.requests.is_empty() and fake_network.requests[-1] == {"action":"game_"+action,"payload":payload},label)

func edit_with_placeholder(placeholder: String) -> LineEdit:
	for node: Node in menu._content.find_children("*","LineEdit",true,false):
		if node.placeholder_text == placeholder:
			return node
	return null

func run() -> void:
	actor = FakePlayer.new()
	root.add_child(actor)
	CharacterSystem.ensure_stats(actor.stats)
	TitleSystem.ensure_stats(actor.stats)
	MountSystem.ensure_stats(actor.stats)
	var items: InventorySystem = InventorySystem.new()
	items.bind_player(actor)
	var services: GameServices = GameServices.new()
	services.bind_player(actor,items)
	var pets: CompanionSystem = CompanionSystem.new()
	pets.bind_player(actor)
	actor.stats["companions"] = [{"uid":"one","name":"One","species_id":140001,"level":5,"hp":60,"max_hp":100,"hunger":50,"exp":0,"born_at":1000.0,"skills":[90014]},{"uid":"two","name":"Two","species_id":140052,"level":5,"hp":60,"max_hp":100,"hunger":50,"exp":0,"born_at":1000.0,"skills":[90035]}]
	actor.stats["incubations"] = [{"uid":"egg","species_id":140001,"egg_id":30029,"started_at":0.0,"hatch_at":60.0,"parents":[]}]
	fake_hud = FakeHUD.new()
	root.add_child(fake_hud)
	fake_network = FakeNetwork.new()
	root.add_child(fake_network)
	menu = Menu.new()
	menu.hud = fake_hud
	fake_hud.add_child(menu)
	menu.network = fake_network
	menu.bind_player(actor,items,services,pets)
	var citizen: FakeCitizen = FakeCitizen.new()
	root.add_child(citizen)
	citizen.add_to_group("npcs")
	actor.set_meta("network_world",true)
	var before: Dictionary = actor.stats.duplicate(true)
	show_tab("inventory")
	press("Одягнути","Довгий меч")
	expect("equip",{"id":10010},"equipment button sends server intent")
	press("Вжити","Мале зілля здоров'я")
	expect("use",{"id":30016},"use button sends server intent")
	press("Осідлати","Зелений гриф")
	expect("mount",{"id":10018},"mount button sends server intent")
	press("Замок","Довгий меч")
	expect("lock",{"id":10010},"item lock button sends server intent")
	press("Склад","Довгий меч")
	expect("deposit",{"id":10010},"deposit button sends server intent")
	press("Викинути 1","Довгий меч")
	expect("discard",{"id":10010},"discard button sends server intent")
	press("Розширити")
	expect("expand_bag",{},"bag expansion sends server intent")
	check(actor.stats == before and fake_hud.changes == 0,"network bag actions never mutate local profile or save callback")
	actor.stats["equipment"] = {"weapon":10010}
	actor.stats["mounted"] = true
	actor.stats["mount_id"] = 10018
	before = actor.stats.duplicate(true)
	show_tab("equipment")
	press("Зняти")
	expect("unequip",{"slot":"weapon"},"unequip sends server slot")
	press("Спішитися")
	expect("dismount",{},"dismount sends server intent")
	check(actor.stats == before,"network equipment actions remain unapplied locally")
	show_tab("character")
	press("+1","Сила")
	expect("allocate",{"attribute":"strength"},"attribute sends server intent")
	press("Обрати титул · " + TitleSystem.label(int(actor.stats["owned_titles"][0])))
	expect("title",{"id":int(actor.stats["owned_titles"][0])},"title sends server intent")
	var name: LineEdit = edit_with_placeholder("Ім'я персонажа (2–24 символи)")
	name.text = "NetworkHero"
	press("Змінити ім'я")
	expect("rename",{"name":"NetworkHero"},"character rename sends name without writing local profile")
	press("Людина · Учень мага")
	expect("choose_class",{"class_id":130002,"race_id":250001},"class and race send explicit server IDs")
	check(actor.stats == before,"network character mutations remain unapplied locally")
	show_tab("skills")
	press("Вивчити +1","Базове фехтування")
	expect("learn_skill",{"id":90020},"skill training sends real class skill ID")
	press("На кнопку 1","Базове фехтування")
	expect("assign_skill",{"slot":"1","id":90020},"hotbar assignment sends source skill and slot")
	press("Скинути навички · 100 міді")
	expect("respec",{},"skill respec sends intent")
	check(actor.stats == before,"network skill actions do not spend local points or money")
	show_tab("shop")
	press("Купити 1","Довгий меч")
	expect("buy",{"id":10010},"shop buy sends server item")
	press("Продати 1","Довгий меч")
	expect("sell",{"id":10010},"shop sell sends server item")
	show_tab("warehouse")
	press("Забрати 1","Кістка вепра")
	expect("withdraw",{"id":30037},"warehouse withdrawal sends server item")
	show_tab("crafting")
	press("Створити","Лікувальні припаси")
	expect("craft",{"recipe":0},"crafting sends recipe index")
	check(actor.stats == before,"network economy actions do not move local items or money")
	show_tab("pets")
	press("Інкубувати · Яйце вепра")
	expect("pet_start_incubation",{"egg_id":30029},"egg incubation sends source item ID")
	press("Вилупити")
	expect("pet_hatch",{"index":0},"hatching sends queue index")
	press("Покликати","One")
	expect("pet_summon",{"uid":"one"},"summon sends unique pet ID")
	press("Годувати","One")
	expect("pet_feed",{"uid":"one"},"feeding sends unique pet ID")
	press("Лікувати","One")
	expect("pet_heal",{"uid":"one"},"healing sends unique pet ID")
	press("Омолодити · " + str(ItemCatalog.get_item(30015).get("label",30015)))
	expect("pet_rejuvenate",{"uid":"one","item_id":30015},"rejuvenation sends pet and source item")
	press("Відпустити звіра")
	expect("pet_release",{"uid":"one"},"release sends unique pet ID")
	var pet_name: LineEdit = edit_with_placeholder("Нове ім'я звіра")
	pet_name.text = "NewPet"
	press("Перейменувати")
	expect("pet_rename",{"uid":"one","name":"NewPet"},"pet rename sends unique ID and name")
	press("Відкликати звіра")
	expect("pet_dismiss",{},"dismiss sends server intent")
	press("Розведення · 100 міді")
	expect("pet_breed",{"first":"one","second":"two"},"breeding sends both unique IDs")
	press("Передати навичку з рунами · 50 міді")
	expect("pet_transfer_runes",{"from_uid":"one","to_uid":"two","learning":0,"inheritance":0},"runic transfer sends both pet IDs and selected rune intent")
	check(actor.stats == before,"network companion actions do not mutate local pets or inventory")
	fake_network.social_snapshot = {"own_id":101,"name":"Tester","profile":actor.stats.duplicate(true),"onlineplayers":[{"id":101,"name":"Tester"},{"id":202,"name":"Other"}]}
	fake_network.world_snapshot = {"own_id":101,"profile":actor.stats.duplicate(true),"state":{"actors":{101:{"pk_mode":"peaceful"}},"duels":{},"duel_requests":{101:{"from":202,"remaining":30.0}}}}
	fake_network.world_enabled = false
	show_tab("social")
	check(menu._content.find_child("PKMode",true,false) == null,"legacy social sessions do not show shared-world combat controls")
	fake_network.world_enabled = true
	show_tab("social")
	var pk: OptionButton = menu._content.find_child("PKMode",true,false)
	check(pk != null,"shared-world session exposes authoritative PK selector")
	pk.item_selected.emit(3)
	expect("pk_mode",{"mode":"free"},"PK selector sends authoritative mode request")
	press("Запросити обраного гравця на дуель")
	expect("duel_request",{"target":202},"duel request names selected stable account")
	press("Прийняти дуель")
	expect("duel_accept",{"target":202},"duel acceptance names requesting account")
	press("Відхилити")
	expect("duel_decline",{"target":202},"duel decline names requesting account")
	fake_network.world_snapshot["state"]["duels"] = {101:202,202:101}
	show_tab("social")
	press("Припинити дуель")
	expect("duel_cancel",{},"active duel can be cancelled")
	var chat: LineEdit = edit_with_placeholder("Повідомлення")
	chat.text = "Keep this draft"
	chat.text_changed.emit(chat.text)
	menu._network_updated(fake_network.social_snapshot)
	await process_frame
	check(edit_with_placeholder("Повідомлення").text == "Keep this draft","social snapshot refresh preserves chat draft")
	menu._world_updated(fake_network.world_snapshot)
	await process_frame
	var edit_id: int = edit_with_placeholder("Повідомлення").get_instance_id()
	fake_network.world_snapshot["state"]["actors"][101]["position"] = Vector3(8,0,0)
	menu._world_updated(fake_network.world_snapshot)
	await process_frame
	check(edit_with_placeholder("Повідомлення").get_instance_id() == edit_id,"position-only world updates do not rebuild draft editors")
	var remote_avatar: Node3D = Node3D.new()
	remote_avatar.set_meta("network_account",202)
	root.add_child(remote_avatar)
	remote_avatar.add_to_group("players")
	press("Обрати гравця ціллю у світі")
	check(actor.current_target == remote_avatar and not menu.visible,"mobile social selection targets matching online avatar and returns to world")
	remote_avatar.queue_free()
	actor.set_meta("network_world",false)
	actor.stats["mounted"] = false
	actor.stats["hp"] = 40
	actor.stats["inventory"]["30016"] = 1
	var request_count: int = fake_network.requests.size()
	menu._game_action("use",{"id":30016},func() -> bool: return items.use_item(30016))
	check(actor.stats["hp"] == 90 and items.count_item(30016) == 0 and fake_hud.changes == 1 and fake_network.requests.size() == request_count,"offline action still applies locally once")
	actor.set_meta("network_world",true)
	var missing: Node = Node.new()
	menu.network = missing
	var called: Array[int] = [0]
	menu._game_action("use",{"id":30016},func() -> void: called[0] += 1)
	check(called[0] == 0,"missing server never falls back to mutating network profile")
	missing.free()
	menu.network = fake_network
	citizen.queue_free()
	actor.queue_free()
	fake_hud.queue_free()
	fake_network.queue_free()
	await process_frame
	await process_frame
	print("MENU_COMMANDS_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)
