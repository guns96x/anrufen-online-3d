class_name GameMenu
extends Control

var hud: Node
var player: Node
var items: InventorySystem
var services: GameServices
var pets: CompanionSystem
var _content: VBoxContainer
var _heading: Label
var _notice: Label
var _tab: String = "inventory"
var _waiting_key: String = ""
var network: Node
var _drafts: Dictionary = {}
var _social_target: int = 0
var _trade_draft_id: int = 0
var _trade_item_draft: Dictionary = {}
var _shop_filter: String = "all"
var _last_world_controls: String = ""
const TABS: Dictionary = {"inventory":"Сумка", "equipment":"Спорядження", "character":"Персонаж", "skills":"Навички", "journal":"Щоденник", "map":"Карта й пошук", "shop":"Торгівля", "warehouse":"Склад", "crafting":"Синтез", "pets":"Магічні звірі", "social":"Мережа та спільнота", "settings":"Налаштування"}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.015,0.025,0.035,0.97)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",32)
	margin.add_theme_constant_override("margin_right",32)
	margin.add_theme_constant_override("margin_top",20)
	margin.add_theme_constant_override("margin_bottom",20)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	margin.add_child(layout)
	var top: HBoxContainer = HBoxContainer.new()
	layout.add_child(top)
	_heading = Label.new()
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_heading.add_theme_font_size_override("font_size",23)
	_heading.add_theme_color_override("font_color",Color("e3c882"))
	top.add_child(_heading)
	_button(top,"Повернутися до гри",close_menu,220)
	var body: HBoxContainer = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",22)
	layout.add_child(body)
	var navigation: ScrollContainer = ScrollContainer.new()
	navigation.custom_minimum_size.x = 200
	navigation.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(navigation)
	var nav: VBoxContainer = VBoxContainer.new()
	navigation.add_child(nav)
	for key: String in TABS:
		_button(nav,TABS[key],func() -> void: open_tab(key),190)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ContentScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation",10)
	scroll.add_child(_content)
	_notice = Label.new()
	_notice.add_theme_color_override("font_color",Color("e7b56a"))
	_notice.custom_minimum_size.y = 26
	layout.add_child(_notice)
	hide()
	network = get_tree().root.get_node("NetworkManager")
	network.state_updated.connect(_network_updated)
	network.notice.connect(show_notice)
	if network.has_signal("world_updated"):
		network.connect("world_updated",_world_updated)

func _network_updated(_snapshot: Dictionary) -> void:
	if visible and _tab == "social":
		call_deferred("render")

func _world_updated(packet: Dictionary) -> void:
	# World positions update frequently. Rebuild social controls only when their
	# policy/invitation state changes, preserving chat/mail/trade draft editing.
	var signature: String = JSON.stringify(_world_control_state(packet))
	if signature == _last_world_controls:
		return
	_last_world_controls = signature
	if visible and _tab == "social":
		call_deferred("render")

func _world_control_state(packet: Dictionary, account: int = 0) -> Dictionary:
	var own: int = account if account != 0 else int(packet.get("own_id",0))
	var state: Dictionary = packet.get("state",{}) if packet.get("state",{}) is Dictionary else {}
	var actors: Dictionary = state.get("actors",{}) if state.get("actors",{}) is Dictionary else {}
	var actor: Dictionary = actors.get(own,actors.get(str(own),{}))
	var duels: Dictionary = state.get("duels",{}) if state.get("duels",{}) is Dictionary else {}
	var requests: Dictionary = state.get("duel_requests",{}) if state.get("duel_requests",{}) is Dictionary else {}
	var request: Dictionary = requests.get(own,requests.get(str(own),{}))
	return {"pk_mode":str(actor.get("pk_mode",packet.get("profile",{}).get("pk_mode","peaceful"))),"opponent":int(duels.get(own,duels.get(str(own),0))),"inviter":int(request.get("from",0))}

func bind_player(actor: Node, inventory: InventorySystem, game_services: GameServices, companions: CompanionSystem) -> void:
	player = actor
	items = inventory
	services = game_services
	pets = companions
	items.feedback.connect(show_notice)
	services.feedback.connect(show_notice)
	pets.feedback.connect(show_notice)

func _button(parent: Node, title: String, callback: Callable, width: float = 100.0) -> Button:
	var button: Button = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(width,44)
	button.add_theme_font_size_override("font_size",16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _text(text: String, size: int = 17) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	_content.add_child(label)
	return label

func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation",8)
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240
	row.add_child(label)
	_content.add_child(row)
	return row

func show_notice(text: String) -> void:
	_notice.text = text

func close_menu() -> void:
	_waiting_key = ""
	hide()
	if hud:
		hud.joystick._reset()

func open_tab(tab: String = "inventory") -> void:
	if not is_instance_valid(player):
		return
	_tab = tab if TABS.has(tab) else "inventory"
	_waiting_key = ""
	show()
	if hud:
		hud.move_child(self,hud.get_child_count()-1)
		hud.dialogue_box.hide()
		hud.joystick._reset()
	render()

func refresh() -> void:
	if visible:
		render()

func _game_action(action: String, payload: Dictionary, callback: Callable) -> void:
	var remote: Variant = player.get_meta("network_world",false) if is_instance_valid(player) else false
	if typeof(remote) == TYPE_BOOL and remote:
		if not is_instance_valid(network) or not network.has_method("request"):
			show_notice("Сервер недоступний. Дію не застосовано локально.")
			return
		show_notice("Запит до сервера…")
		network.request("game_" + action,payload.duplicate(true))
		return
	_perform(callback)

func _perform(callback: Callable) -> void:
	var result: Variant = callback.call()
	if result is bool and not result:
		show_notice("Дію не виконано. Перевір рівень, вільне місце та ресурси.")
	if result is Dictionary: show_notice(str(result.get("message",result.get("error",""))))
	hud.on_systems_changed()

func render() -> void:
	if _content == null or player == null:
		return
	_heading.text = "%s · Рів. %d · %d міді · Сумка %d/%d" % [TABS[_tab], player.stats["level"], player.stats.get("copper",0),items.used_slots(),player.stats.get("bag_capacity",32)]
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match _tab:
		"inventory": _inventory()
		"equipment": _equipment()
		"character": _character()
		"skills": _skills()
		"journal": _journal()
		"map": _map()
		"shop": _shop()
		"warehouse": _warehouse()
		"crafting": _crafting()
		"pets": _pets()
		"settings": _settings()
		"social": _social()

func _inventory() -> void:
	_text("Предмети можна використати, одягнути, покласти на склад або захистити замком.")
	var bar: HBoxContainer = _row("Розширення сумки: +5 комірок")
	_button(bar,"Розширити",func() -> void: _game_action("expand_bag",{},services.expand_bag),140)
	var keys: Array = player.stats["inventory"].keys()
	keys.sort_custom(func(a: Variant,b: Variant) -> bool: return str(ItemCatalog.get_item(int(a)).get("label",a)) < str(ItemCatalog.get_item(int(b)).get("label",b)))
	if keys.is_empty():
		_text("Сумка порожня. Здобувай предмети з ворогів або відвідай торговця.")
	for key: String in keys:
		var id: int = int(key)
		var item: Dictionary = ItemCatalog.get_item(id)
		var locked: bool = id in items.locked_items
		var row: HBoxContainer = _row("%s%s ×%d" % ["🔒 " if locked else "",item.get("label",item.get("name",key)),items.count_item(id)])
		row.tooltip_text = str(item.get("description",""))
		if item.get("kind") == "equipment":
			_button(row,"Одягнути",func() -> void: _game_action("equip",{"id":id},func() -> bool: return items.equip_item(id)))
		elif item.get("kind") == "mount":
			_button(row,"Осідлати",func() -> void: _game_action("mount",{"id":id},func() -> bool: return MountSystem.mount(player.stats,id)))
		elif item.get("kind") == "consumable" or (item.get("kind") in ["pet_potion","pet_food"] and item.has("effect")):
			_button(row,"Вжити",func() -> void: _game_action("use",{"id":id},func() -> bool: return items.use_item(id)))
		_button(row,"Замок",func() -> void: _game_action("lock",{"id":id},func() -> bool: return services.lock_item(id)),80)
		_button(row,"Склад",func() -> void: _game_action("deposit",{"id":id},func() -> bool: return _deposit_nearby(id)),80)
		_button(row,"Викинути 1",func() -> void: _game_action("discard",{"id":id},func() -> bool: return items.discard_item(id)),115)

func _equipment() -> void:
	_text("Екіпірування впливає на бойові характеристики. При заміні річ повертається в сумку.")
	var equipment: Dictionary = player.stats.get("equipment",{})
	if equipment.is_empty():
		_text("Нічого не одягнено. Вибери річ у сумці.")
	for slot: String in equipment:
		var item: Dictionary = ItemCatalog.get_item(int(equipment[slot]))
		var row: HBoxContainer = _row("%s · %s\n%s" % [slot,item.get("label",item.get("name","")),_bonuses(item.get("bonuses",{}))])
		_button(row,"Зняти",func() -> void: _game_action("unequip",{"slot":slot},func() -> bool: return items.unequip_item(slot)))
	_text("Разом: " + _bonuses(items.bonus_totals()))
	if player.stats.get("mounted",false):
		_button(_content,"Спішитися",func() -> void: _game_action("dismount",{},func() -> void: MountSystem.dismount(player.stats)),240)

func _bonuses(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: String in values:
		parts.append("%s +%s" % [{"attack":"Атака","defense":"Захист","max_hp":"Здоров'я","max_mp":"Мана"}.get(key,key),str(values[key])])
	return ", ".join(parts)

func _character() -> void:
	var stats: Dictionary = player.stats
	_text("%s · %s\n%s" % [stats["name"],"Людина" if int(stats["race_id"]) == 250001 else "Нічний ельф",CharacterSystem.CLASSES[int(stats["class_id"])]],23)
	_text("Фізична атака %d · Магічна атака %d\nЗахист %d · Опір %d · Критичний удар %d%%\nЗдоров'я %d/%d · Мана %d/%d" % [stats["attack"],stats.get("magic_attack",stats["attack"]),stats["defense"],roundi(float(stats.get("resist",0))),roundi(float(stats["crit_rate"])*100),stats["hp"],stats["max_hp"],stats["mp"],stats["max_mp"]])
	_text("Титул: " + TitleSystem.label(int(stats.get("title_id",0))))
	for effect: Dictionary in stats.get("skill_effects",[]):
		_text("%s · %s · %.1f с" % ["Посилення" if effect["positive"] else "Ослаблення",SkillRules.LABELS.get(int(effect["skill_id"]),"Ефект"),float(effect["remaining"])],15)
	for value: Variant in stats.get("owned_titles",[]):
		var id: int = int(value)
		_button(_content,"Обрати титул · " + TitleSystem.label(id),func() -> void: _game_action("title",{"id":id},func() -> bool: return TitleSystem.select(stats,id)),400)
	_text("Вільні очки характеристик: %d" % stats["stat_points"])
	for attribute: String in CharacterSystem.ATTRIBUTES:
		var row: HBoxContainer = _row("%s · %d" % [CharacterSystem.ATTRIBUTES[attribute],stats["attributes"][attribute]])
		_button(row,"+1",func() -> void: _game_action("allocate",{"attribute":attribute},func() -> bool: return CharacterSystem.allocate(stats,attribute)),70)
	var name: LineEdit = LineEdit.new()
	name.placeholder_text = "Ім'я персонажа (2–24 символи)"
	name.max_length = 24
	_content.add_child(name)
	_button(_content,"Змінити ім'я",func() -> void:
		var value: String = name.text.strip_edges()
		if value.length() >= 2:
			_game_action("rename",{"name":value},func() -> bool:
				stats["name"] = value
				return true),180)
	if int(stats["level"]) == 1:
		_text("Початковий клас і раса")
		for race: int in [250001,250002]:
			for id: int in [130001,130002]:
				_button(_content,("Людина" if race == 250001 else "Нічний ельф") + " · " + CharacterSystem.CLASSES[id],func() -> void: _game_action("choose_class",{"class_id":id,"race_id":race},func() -> bool: return CharacterSystem.choose_class(stats,id,race)),320)
	else:
		_text("Подальша професія: від 10-го рівня, навчання 200 міді.")
		for id: int in [130004,130005,130006,130007,130008,130009]:
			_button(_content,CharacterSystem.CLASSES[id],func() -> void: _game_action("choose_class",{"class_id":id,"race_id":int(stats["race_id"])},func() -> bool: return CharacterSystem.choose_class(stats,id,int(stats["race_id"]))),220)

func _skills() -> void:
	_text("Очки навичок: %d · За рівень додається одне очко." % player.stats["skill_points"])
	for id: int in CharacterSystem.available_skills(player.stats):
		var skill: Dictionary = CharacterSystem.SKILLS[id]
		var rank: int = int(player.stats["skills"].get(str(id),0))
		var row: HBoxContainer = _row("%s · %d/%d · Рів. %d" % [skill["name"],rank,skill["max_rank"],skill["level"]])
		var required: int = int(skill.get("prerequisite_skill",0))
		if required != 0: row.tooltip_text = "Потрібно: %s · ранг %d" % [CharacterSystem.SKILLS.get(required,{}).get("name",required),int(skill.get("prerequisite_rank",1))]
		var learn: Button = _button(row,"Вивчити +1",func() -> void: _game_action("learn_skill",{"id":id},func() -> bool: return CharacterSystem.learn_skill(player.stats,id)),125)
		learn.disabled = rank >= int(skill["max_rank"]) or int(player.stats["skill_points"]) <= 0 or int(player.stats["level"]) < int(skill["level"]) or (required != 0 and int(player.stats["skills"].get(str(required),0)) < int(skill.get("prerequisite_rank",1)))
		if not str(skill["effect"]).begins_with("passive"):
			_button(row,"На кнопку 1",func() -> void: _game_action("assign_skill",{"slot":"1","id":id},func() -> bool: return CharacterSystem.assign_skill(player.stats,"1",id)),145)
			if SkillRules.catalog().has(id):
				for slot: String in ["2","3","4"]:
					var button: Button = _button(row,slot,func() -> void: _game_action("assign_skill",{"slot":slot,"id":id},func() -> bool: return CharacterSystem.assign_skill(player.stats,slot,id)),48)
					button.tooltip_text = "Призначити на кнопку "+slot
		if SkillRules.catalog().has(id):
			_text(SkillRules.describe(id,maxi(1,rank)),15)
			if required != 0: _text(row.tooltip_text,14)
	_button(_content,"Скинути навички · 100 міді",func() -> void: _game_action("respec",{},func() -> bool: return CharacterSystem.respec_skills(player.stats)),300)

func _journal() -> void:
	var states: Dictionary = {0:"Недоступне",1:"Можна прийняти",2:"Виконується",3:"Готове до здавання",4:"Завершено"}
	for id: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[id]
		_text("%s · %s" % [q["title_uk"],states[hud.progression.quest_states[id]]],20)
		_text(str(q["progress_text"]))
		_text("Досвід: %d · Мідь: %d" % [q["exp"],q["copper"]],15)
		var row: HBoxContainer = _row("Виконано: %d/%d" % [hud.progression.quest_kills[id],q["required"]])
		_button(row,"Знайти NPC",func() -> void: _navigate_citizen(int(q["turnin_id"])),145)

func _map() -> void:
	_text("Ґуаньлінь · пошук жителів і маршрут",23)
	_text("Почни рух за блакитним вказівником. Ручне керування скасовує маршрут.")
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		var row: HBoxContainer = _row(str(node.npc_name))
		_button(row,"Йти",func() -> void: _navigate_citizen(int(node.citizen_id)))
	_button(_content,"Скасувати маршрут",func() -> void: player.cancel_navigation(),220)

func _navigate_citizen(citizen: int) -> void:
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if int(node.citizen_id) == citizen:
			player.navigate_to(node.global_position + Vector3(0,0,2.0))
			close_menu()
			return

func _near_citizen(ids: Array) -> bool:
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		if int(node.citizen_id) in ids and player.global_position.distance_to(node.global_position) <= 5.0:
			return true
	return false

func _shop() -> void:
	if not _near_citizen([50179,50167,50168,50180]):
		_text("Для торгівлі підійди до торговця зброєю або торгових яток.")
		_button(_content,"Знайти торговця",func() -> void: _navigate_citizen(50179),240)
		return
	_text("Купівля",22)
	var filters: HBoxContainer = HBoxContainer.new()
	_content.add_child(filters)
	for entry: Array in [["all","Усе"],["equipment","Спорядження"],["consumable","Припаси"],["pets","Звірі"],["mount","Їзда"]]:
		_button(filters,entry[1],func() -> void: _shop_filter = entry[0]; render(),100)
	for id: int in ItemCatalog.shop_items():
		var item: Dictionary = ItemCatalog.get_item(id)
		var kind: String = str(item.get("kind",""))
		if _shop_filter != "all" and kind != _shop_filter and not (_shop_filter == "pets" and kind.begins_with("pet_")):
			continue
		var row: HBoxContainer = _row("%s · %d міді · Рів. %d" % [item.get("label",item.get("name","")),item.get("buy_price",0),item.get("required_level",1)])
		_button(row,"Купити 1",func() -> void: _game_action("buy",{"id":id},func() -> bool: return items.buy_item(id)))
	_text("Продаж із сумки",22)
	for key: String in player.stats["inventory"]:
		var id: int = int(key)
		var item: Dictionary = ItemCatalog.get_item(id)
		var row: HBoxContainer = _row("%s ×%d · Продаж %d міді" % [item.get("label",item.get("name",key)),items.count_item(id),item.get("sell_price",0)])
		_button(row,"Продати 1",func() -> void: _game_action("sell",{"id":id},func() -> bool: return items.sell_item(id)))

func _warehouse() -> void:
	if not _near_citizen([50179]):
		_text("Склад доступний у торговця зброєю.")
		_button(_content,"Знайти торговця",func() -> void: _navigate_citizen(50179),240)
		return
	_text("Склад · %d/%d видів предметів" % [player.stats["warehouse"].size(),player.stats.get("warehouse_capacity",64)],23)
	for key: String in player.stats["warehouse"]:
		var id: int = int(key)
		var row: HBoxContainer = _row("%s ×%d" % [ItemCatalog.get_item(id).get("label",key),player.stats["warehouse"][key]])
		_button(row,"Забрати 1",func() -> void: _game_action("withdraw",{"id":id},func() -> bool: return services.withdraw(id)))
	_text("Покласти річ можна з вкладки «Сумка».")

func _crafting() -> void:
	if not _near_citizen([50179,50167]):
		_text("Синтез припасів доступний біля торговця або Ласуна.")
		return
	for index: int in GameServices.RECIPES.size():
		var recipe: Dictionary = GameServices.RECIPES[index]
		var row: HBoxContainer = _row("%s · 2 кістки вепра + %d міді → %d шт." % [recipe["name"],recipe["copper"],recipe["count"]])
		_button(row,"Створити",func() -> void: _game_action("craft",{"recipe":index},func() -> bool: return services.craft(index)))

func _pets() -> void:
	_text("Магічні звірі · інкубація, догляд, розвиток",23)
	_text("Яйця можна придбати в торговця. Інкубація триває 60 секунд.")
	for key: String in player.stats["inventory"]:
		var id: int = int(key)
		if id in pets.available_eggs():
			_button(_content,"Інкубувати · " + str(ItemCatalog.get_item(id).get("label",id)),func() -> void: _game_action("pet_start_incubation",{"egg_id":id},func() -> bool: return pets.start_incubation(id)),340)
	for index: int in player.stats.get("incubations",[]).size():
		var row: HBoxContainer = _row("Інкубація #%d" % (index+1))
		_button(row,"Вилупити",func() -> void: _game_action("pet_hatch",{"index":index},func() -> bool: return pets.hatch(index)))
	for pet: Dictionary in player.stats.get("companions",[]):
		var uid: String = str(pet["uid"])
		var row: HBoxContainer = _row("%s · Рів. %d · Здоров'я %d/%d · Ситість %d" % [pet["name"],pet["level"],pet["hp"],pet["max_hp"],pet["hunger"]])
		_button(row,"Покликати",func() -> void: _game_action("pet_summon",{"uid":uid},func() -> bool: return pets.summon(uid)),130)
		_button(row,"Годувати",func() -> void: _game_action("pet_feed",{"uid":uid},func() -> bool: return pets.feed(uid,30022)),115)
		_button(row,"Лікувати",func() -> void: _game_action("pet_heal",{"uid":uid},func() -> bool: return pets.heal(uid,30020)),115)
		_text("Мана: %d/%d" % [pet.get("mp",40),pet.get("max_mp",40)],15)
		_text("Тип: %s · Форма: %d/%d" % [SourcePetCatalog.TYPE_LABELS.get(SourcePetCatalog.type_id(int(pet["species_id"])),"Особливий"),pet.get("form_rank",0),PetDevelopment.MAX_FORM],15)
		var tactics: Array[Dictionary] = []
		for key: String in PetDevelopment.TACTICS: tactics.append({"value":key,"label":PetDevelopment.TACTICS[key]})
		var tactic: String = str(_pet_choice("tactic_"+uid,"Тактика",tactics,pet.get("tactic","attack_owner_target")))
		_button(_content,"Застосувати тактику",func() -> void: _game_action("pet_tactic",{"uid":uid,"tactic":tactic},func() -> bool: return pets.set_tactic(uid,tactic)),270)
		for key: String in SourcePetCatalog.data().get("consumables",{}):
			var food_id: int = int(key)
			if items.count_item(food_id) > 0 and not SourcePetCatalog.consumable(food_id).get("talent_increment",{}).is_empty():
				_button(_content,"Талант · "+str(ItemCatalog.get_item(food_id).get("label",food_id)),func() -> void: _game_action("pet_talent",{"uid":uid,"id":food_id},func() -> bool: return pets.feed_talent(uid,food_id)),340)
		for kind: String in ["pet_hp","pet_mp"]:
			for item_id: int in AutoMedicine.PRIORITIES[kind]:
				if item_id == 30020 or items.count_item(item_id) <= 0: continue
				_button(_content,"Зілля · "+str(ItemCatalog.get_item(item_id).get("label",item_id)),func() -> void: _game_action("pet_medicate",{"uid":uid,"id":item_id},func() -> bool: return pets.medicate(uid,item_id)),340)
		var names: PackedStringArray = []
		for value: Variant in pet["skills"]:
			names.append(str(CharacterSystem.SKILLS.get(int(value),{}).get("name",str(value))))
		_text("Вік: %s · Навички: %s" % [pets.life_stage(uid),", ".join(names)],15)
		for item_id: int in [30015,30988,30989]:
			if items.count_item(item_id) > 0:
				_button(_content,"Омолодити · " + str(ItemCatalog.get_item(item_id).get("label",item_id)),func() -> void: _game_action("pet_rejuvenate",{"uid":uid,"item_id":item_id},func() -> bool: return pets.rejuvenate(uid,item_id)),360)
		for item_id: int in [30025,30703]:
			if items.count_item(item_id) > 0 and int(pet["hp"]) <= 0:
				_button(_content,"Воскресити · " + str(ItemCatalog.get_item(item_id).get("label",item_id)),func() -> void: _game_action("pet_revive",{"uid":uid,"item_id":item_id},func() -> bool: return pets.revive(uid,item_id)),360)
		_button(_content,"Відпустити звіра",func() -> void: _game_action("pet_release",{"uid":uid},func() -> bool: return pets.release_pet(uid)),240)
		var rename: LineEdit = LineEdit.new()
		rename.placeholder_text = "Нове ім'я звіра"
		rename.max_length = 24
		_content.add_child(rename)
		_button(_content,"Перейменувати",func() -> void: _game_action("pet_rename",{"uid":uid,"name":rename.text},func() -> bool: return pets.rename_pet(uid,rename.text)),200)
	_text("Звірів: %d/%d · Видів: %d · Яєць: %d" % [player.stats["companions"].size(),player.stats.get("pet_capacity",CompanionSystem.MAX_PETS),pets.species().size(),pets.available_eggs().size()])
	_button(_content,"Відкликати звіра",func() -> void: _game_action("pet_dismiss",{},func() -> void: pets.dismiss()),240)
	var pets_list: Array = player.stats.get("companions",[])
	if pets_list.size() >= 2:
		_text("Розведення та передача навичок",23)
		var choices: Array[Dictionary] = []
		for pet: Dictionary in pets_list:
			choices.append({"value":pet["uid"],"label":pet["name"]})
		var first: String = str(_pet_choice("pet_source","Допоміжний звір · донор",choices,choices[0]["value"]))
		var second: String = str(_pet_choice("pet_target","Головний звір · отримувач",choices,choices[1]["value"]))
		_button(_content,"Розведення · 100 міді",func() -> void: _game_action("pet_breed",{"first":first,"second":second},func() -> bool: return pets.breed(first,second)),280)
		_text("Руни фіксують комірку навички; без руни вибір випадковий.",15)
		_text("Передача можлива між звірами одного типу. Після передачі або перетворення допоміжний звір ЗНИКАЄ.",15)
		var learning_choices: Array[Dictionary] = [{"value":0,"label":"Без руни навчання"}]
		var inheritance_choices: Array[Dictionary] = [{"value":0,"label":"Без руни спадкування"}]
		for id: int in CompanionSystem.LEARNING_RUNES:
			if items.count_item(id) > 0: learning_choices.append({"value":id,"label":ItemCatalog.get_item(id).get("label",id)})
		for id: int in CompanionSystem.INHERITANCE_RUNES:
			if items.count_item(id) > 0: inheritance_choices.append({"value":id,"label":ItemCatalog.get_item(id).get("label",id)})
		var learning: int = int(_pet_choice("pet_learning","Замінити в головного",learning_choices,0))
		var inheritance: int = int(_pet_choice("pet_inheritance","Взяти в допоміжного",inheritance_choices,0))
		_button(_content,"Передати навичку з рунами · 50 міді",func() -> void: _game_action("pet_transfer_runes",{"from_uid":first,"to_uid":second,"learning":learning,"inheritance":inheritance},func() -> bool: return pets.transfer_with_runes(first,second,learning,inheritance)),430)
		var boosts: Array[Dictionary] = [{"value":0,"label":"Без посилення"}]
		var protection_items: Array[Dictionary] = [{"value":0,"label":"Без захисту форми"}]
		for id: int in PetDevelopment.TRANSFORM_BOOSTS:
			if items.count_item(id) > 0: boosts.append({"value":id,"label":ItemCatalog.get_item(id).get("label",id)})
		for id: int in PetDevelopment.TRANSFORM_PROTECTION:
			if items.count_item(id) > 0: protection_items.append({"value":id,"label":ItemCatalog.get_item(id).get("label",id)})
		var boost: int = int(_pet_choice("pet_transform_boost","Підсилювач перетворення",boosts,0))
		var protection: int = int(_pet_choice("pet_transform_protection","Захист форми",protection_items,0))
		_button(_content,"Перетворити · використати донора · 100 міді",func() -> void: _game_action("pet_transform",{"uid":second,"donor":first,"boost":boost,"protection":protection},func() -> Dictionary: return pets.transform(second,first,boost,protection)),510)

func _pet_choice(key: String, label: String, values: Array[Dictionary], fallback: Variant) -> Variant:
	var selected: Variant = _drafts.get(key,fallback)
	var valid: bool = false
	for row: Dictionary in values:
		if row["value"] == selected: valid = true
	if not valid: selected = fallback
	_drafts[key] = selected
	var row: HBoxContainer = _row(label)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(300,44)
	row.add_child(choice)
	for index: int in values.size():
		choice.add_item(str(values[index]["label"]))
		if values[index]["value"] == selected: choice.selected = index
	choice.item_selected.connect(func(index: int) -> void: _drafts[key] = values[index]["value"]; call_deferred("render"))
	return selected

func _settings() -> void:
	_text("Звук",23)
	for entry: Array in [["master_volume","Загальна гучність"],["music_volume","Музика й оточення"],["effects_volume","Ефекти"]]:
		_slider(entry[0],entry[1],0.0,1.0,0.05)
	_text("Зображення",23)
	_choice("quality","Якість",["low","medium","high"],["Низька","Середня","Висока"])
	_choice("fps_limit","Кадрів за секунду",[30,60,120],["30","60","120"])
	_toggle("show_names","Показувати імена")
	_toggle("show_damage","Показувати шкоду")
	_text("Керування",23)
	_slider("camera_sensitivity","Чутливість камери",0.2,3.0,0.1)
	_slider("joystick_opacity","Видимість джойстика",0.1,1.0,0.05)
	_toggle("invert_camera_y","Інвертувати камеру по вертикалі")
	for action: String in SettingsStore.current().bindings:
		var row: HBoxContainer = _row({"move_forward":"Рух уперед","move_back":"Рух назад","move_left":"Рух ліворуч","move_right":"Рух праворуч","attack":"Удар","fire":"Навичка 1","slot_2":"Навичка 2","slot_3":"Навичка 3","slot_4":"Навичка 4","dash":"Ривок","interact":"Взаємодія","bag":"Сумка","character":"Персонаж","skills":"Навички","journal":"Щоденник","map":"Карта","menu":"Меню"}.get(action,action))
		_button(row,OS.get_keycode_string(int(SettingsStore.current().bindings[action])),func() -> void: _waiting_key = action; show_notice("Натисни нову клавішу. Esc — скасувати."),180)
	_text("Бойові опції",23)
	_toggle("auto_loot","Підбирати здобич автоматично")
	_toggle("loot_equipment","Підбирати спорядження")
	_toggle("loot_supplies","Підбирати зілля та припаси")
	_toggle("loot_materials","Підбирати матеріали й яйця")
	_toggle("auto_potion","Зілля здоров'я гравця автоматично")
	_slider("potion_threshold","Поріг здоров'я гравця",0.0,1.0,0.05)
	_toggle("auto_mp","Зілля мани гравця автоматично")
	_slider("mp_potion_threshold","Поріг мани гравця",0.0,1.0,0.05)
	_toggle("auto_pet_hp","Лікувати покликаного звіра автоматично")
	_slider("pet_hp_potion_threshold","Поріг здоров'я звіра",0.0,1.0,0.05)
	_toggle("auto_pet_mp","Зілля мани покликаного звіра автоматично")
	_slider("pet_mp_potion_threshold","Поріг мани звіра",0.0,1.0,0.05)
	_button(_content,"Відновити стандартні налаштування",func() -> void: SettingsStore.current().reset_defaults(); render(),400)

func _slider(key: String, title: String, low: float, high: float, step: float) -> void:
	var row: HBoxContainer = _row(title)
	var slider: HSlider = HSlider.new()
	slider.custom_minimum_size = Vector2(290,44)
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(SettingsStore.current().get_value(key))
	row.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void: SettingsStore.current().set_value(key,value))

func _toggle(key: String, title: String) -> void:
	var box: CheckButton = CheckButton.new()
	box.text = title
	box.custom_minimum_size.y = 44
	box.button_pressed = bool(SettingsStore.current().get_value(key))
	_content.add_child(box)
	box.toggled.connect(func(value: bool) -> void: SettingsStore.current().set_value(key,value))

func _choice(key: String, title: String, values: Array, labels: Array) -> void:
	var row: HBoxContainer = _row(title)
	var choice: OptionButton = OptionButton.new()
	choice.custom_minimum_size = Vector2(240,44)
	for index: int in labels.size():
		choice.add_item(labels[index])
		if values[index] == SettingsStore.current().get_value(key):
			choice.selected = index
	row.add_child(choice)
	choice.item_selected.connect(func(index: int) -> void: SettingsStore.current().set_value(key,values[index]))

func _input(event: InputEvent) -> void:
	if visible and not _waiting_key.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			if not SettingsStore.current().set_binding(_waiting_key,event.physical_keycode):
				show_notice("Ця клавіша вже використовується.")
		_waiting_key = ""
		get_viewport().set_input_as_handled()
		render()

func _draft_line(key: String, placeholder: String, width: float = 0.0) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = str(_drafts.get(key,""))
	edit.max_length = 300
	edit.custom_minimum_size = Vector2(width,44)
	_content.add_child(edit)
	edit.text_changed.connect(func(value: String) -> void: _drafts[key] = value)
	return edit

func _request(action: String, payload: Dictionary = {}) -> void:
	network.request(action,payload)

func _social() -> void:
	var snapshot: Dictionary = network.social_snapshot
	if snapshot.is_empty():
		_text("Гра з іншими гравцями",23)
		_text("Створи сервер спільного світу або введи адресу іншого сервера. Рух, бій, предмети й мідь мережевого персонажа зберігає та перевіряє сервер." if network.get("world_enabled") == true else "Створи локальний сеанс спільноти або введи адресу сервера іншого гравця.")
		var address: LineEdit = _draft_line("server_address","Адреса сервера: 127.0.0.1 або Tailscale IP")
		var row: HBoxContainer = _row("Порт: 7777")
		_button(row,"Створити сервер",func() -> void:
			network.local_player_data["name"] = player.stats["name"]
			network.start_server()
			render(),230)
		_button(row,"Приєднатися",func() -> void:
			network.local_player_data["name"] = player.stats["name"]
			network.start_client(address.text.strip_edges() if not address.text.strip_edges().is_empty() else "127.0.0.1")
			show_notice("Підключення до сервера…"),190)
		return
	var own: int = int(snapshot.get("own_id",0))
	var profile: Dictionary = snapshot.get("profile",{})
	var title: HBoxContainer = _row("Мережевий персонаж: %s · %d міді" % [snapshot.get("name",""),profile.get("copper",0)])
	_button(title,"Від'єднатися",func() -> void: network.disconnect_session(); render(),180)
	var peers: Array = snapshot.get("onlineplayers",snapshot.get("players",[]))
	var choose: OptionButton = OptionButton.new()
	choose.custom_minimum_size.y = 44
	for peer: Dictionary in peers:
		var id: int = int(peer["id"])
		if id != own:
			choose.add_item(str(peer["name"]),id)
			if _social_target == 0:
				_social_target = id
			if _social_target == id:
				choose.select(choose.item_count-1)
	for friend: Variant in snapshot.get("friends",[]):
		var id: int = int(friend)
		var exists: bool = false
		for index: int in choose.item_count:
			if choose.get_item_id(index) == id:
				exists = true
		if not exists and id != own:
			choose.add_item(_social_name(id) + " · офлайн",id)
			if id == _social_target:
				choose.select(choose.item_count-1)
	_content.add_child(choose)
	choose.item_selected.connect(func(index: int) -> void: _social_target = choose.get_item_id(index))
	_world_combat_controls(own)
	var actions: HBoxContainer = _row("Обраний гравець")
	for entry: Array in [["Друг","friend_request"],["Група","party_invite"],["Гільдія","guild_invite"],["Обмін","trade_request"]]:
		_button(actions,entry[0],func() -> void: _request(entry[1],{"target":_social_target}),100)
	for id: Variant in snapshot.get("friendrequests",[]):
		var row: HBoxContainer = _row("Запит у друзі: " + _social_name(int(id)))
		_button(row,"Прийняти",func() -> void: _request("friend_accept",{"target":int(id)}))
	for friend: Variant in snapshot.get("friends",[]):
		var id: int = int(friend.get("id",0)) if friend is Dictionary else int(friend)
		var row: HBoxContainer = _row("Друг: " + _social_name(id))
		_button(row,"Видалити",func() -> void: _request("friend_remove",{"target":id}))
	_text(_group_title("Група",snapshot.get("party",{})))
	_button(_content,"Вийти з групи",func() -> void: _request("party_leave"),230)
	if int(snapshot.get("party",{}).get("leader",0)) == int(snapshot["own_id"]):
		_button(_content,"Виключити обраного з групи",func() -> void: _request("party_kick",{"target":_social_target}),340)
	var invitations: Dictionary = snapshot.get("invitations",{})
	for invitation: Variant in invitations.get("party",[]):
		var id: int = int(invitation.get("party_id",invitation.get("id",0))) if invitation is Dictionary else int(invitation)
		_button(_content,"Прийняти запрошення до групи",func() -> void: _request("party_accept",{"party_id":id}),400)
	_text(_group_title("Гільдія",snapshot.get("guild",{})))
	var own_guild: Dictionary = snapshot.get("guild",{})
	if not own_guild.is_empty():
		_text("Оголошення: " + str(own_guild.get("declaration","")),17)
		if int(own_guild.get("leader",0)) == int(snapshot["own_id"]):
			var declaration: LineEdit = _draft_line("guild_declaration","Оголошення гільдії")
			declaration.max_length = 500
			_button(_content,"Оновити оголошення",func() -> void: _request("guild_declaration",{"text":declaration.text}),300)
			_button(_content,"Виключити обраного з гільдії",func() -> void: _request("guild_kick",{"target":_social_target}),340)
	var guild: LineEdit = _draft_line("guild_name","Назва нової гільдії")
	_button(_content,"Створити гільдію · 50 міді",func() -> void: _request("guild_create",{"name":guild.text}),330)
	_button(_content,"Вийти з гільдії",func() -> void: _request("guild_leave"),230)
	for invitation: Variant in invitations.get("guild",[]):
		var id: int = int(invitation.get("guild_id",invitation.get("id",0))) if invitation is Dictionary else int(invitation)
		_button(_content,"Прийняти запрошення до гільдії",func() -> void: _request("guild_accept",{"guild_id":id}),400)
	_bounty_board(snapshot)
	_text("Чат",23)
	for message: Dictionary in snapshot.get("chat",[]):
		_text("[%s] %s: %s" % [message.get("channel",""),message.get("name",message.get("from","")),message.get("text","")],15)
	var channel: OptionButton = OptionButton.new()
	for value: String in ["Загальний","Група","Гільдія","Приватний"]:
		channel.add_item(value)
	channel.custom_minimum_size.y = 44
	channel.selected = int(_drafts.get("chat_channel",0))
	channel.item_selected.connect(func(index: int) -> void: _drafts["chat_channel"] = index)
	_content.add_child(channel)
	var message: LineEdit = _draft_line("chat_text","Повідомлення")
	_button(_content,"Надіслати",func() -> void: _request("chat",{"channel":["global","party","guild","whisper"][channel.selected],"text":message.text,"target":_social_target}),180)
	_text("Пошта",23)
	var subject: LineEdit = _draft_line("mail_subject","Тема листа")
	var body: LineEdit = _draft_line("mail_body","Текст листа")
	_button(_content,"Надіслати обраному гравцю",func() -> void: _request("mail_send",{"target":_social_target,"subject":subject.text,"body":body.text}),340)
	for mail: Dictionary in snapshot.get("mail",snapshot.get("inbox",[])):
		var id: int = int(mail.get("id",mail.get("mail_id",0)))
		var row: HBoxContainer = _row("%s · %s" % [mail.get("subject",""),mail.get("body","")])
		_button(row,"Прочитано",func() -> void: _request("mail_read",{"mail_id":id}),130)
		_button(row,"Видалити",func() -> void: _request("mail_delete",{"mail_id":id}))
	var trade: Dictionary = snapshot.get("trade",{})
	if not trade.is_empty():
		_text("Обмін",23)
		var trade_id: int = int(trade.get("id",trade.get("trade_id",0)))
		for peer_id: Variant in trade.get("offers",{}):
			var offer: Dictionary = trade["offers"][peer_id]
			var parts: PackedStringArray = []
			for key: String in offer.get("items",{}):
				parts.append("%s ×%d" % [ItemCatalog.get_item(int(key)).get("label",key),offer["items"][key]])
			_text("%s · %d міді · %s" % [_social_name(int(peer_id)),offer.get("copper",0),", ".join(parts)])
		_button(_content,"Прийняти запрошення до обміну",func() -> void: _request("trade_accept",{"trade_id":trade_id}),380)
		if _trade_draft_id != trade_id:
			_trade_draft_id = trade_id
			var own_offer: Dictionary = trade.get("offers",{}).get(own,{})
			_trade_item_draft = own_offer.get("items",{}).duplicate(true)
			_drafts["trade_copper"] = str(own_offer.get("copper",0))
		var amount: LineEdit = _draft_line("trade_copper","Мідь у пропозиції")
		var offered: Dictionary = _trade_item_draft
		for key: String in profile.get("inventory",{}):
			var id: int = int(key)
			var row: HBoxContainer = _row(str(ItemCatalog.get_item(id).get("label",key)))
			var count: SpinBox = SpinBox.new()
			count.min_value = 0
			count.max_value = int(profile["inventory"][key])
			count.value = mini(int(offered.get(key,0)),int(count.max_value))
			count.custom_minimum_size = Vector2(130,44)
			row.add_child(count)
			count.value_changed.connect(func(value: float) -> void:
				if value > 0:
					offered[key] = int(value)
				else:
					offered.erase(key))
		_button(_content,"Оновити пропозицію",func() -> void: _request("trade_offer",{"trade_id":trade_id,"copper":amount.text.to_int(),"items":offered}),280)
		var row: HBoxContainer = _row("Потрібні підтвердження обох гравців")
		_button(row,"Підтвердити",func() -> void: _request("trade_confirm",{"trade_id":trade_id}),180)
		_button(row,"Скасувати",func() -> void: _request("trade_cancel",{"trade_id":trade_id}),150)
	_text("Комісійна торгівля",23)
	var item_choice: OptionButton = OptionButton.new()
	item_choice.custom_minimum_size.y = 44
	for key: String in profile.get("inventory",{}):
		item_choice.add_item("%s ×%d" % [ItemCatalog.get_item(int(key)).get("label",key),profile["inventory"][key]],int(key))
	_content.add_child(item_choice)
	var auction_count: LineEdit = _draft_line("auction_count","Кількість у лоті")
	var auction_price: LineEdit = _draft_line("auction_price","Ціна всього лота в міді")
	_button(_content,"Виставити лот",func() -> void:
		if item_choice.item_count > 0:
			_request("auction_list",{"id":item_choice.get_selected_id(),"count":auction_count.text.to_int(),"price":auction_price.text.to_int()}),230)
	var search: LineEdit = _draft_line("auction_search","Пошук предмета")
	_button(_content,"Шукати",render,160)
	for listing: Dictionary in snapshot.get("auctions",[]):
		var label: String = str(ItemCatalog.get_item(int(listing["item_id"])).get("label",""))
		if not search.text.strip_edges().is_empty() and not search.text.to_lower() in label.to_lower():
			continue
		var row: HBoxContainer = _row("%s ×%d · %d міді · %s" % [label,listing["count"],listing["price"],listing.get("seller_name","")])
		var listing_id: int = int(listing["id"])
		_button(row,"Зняти лот" if int(listing["seller"]) == own else "Купити лот",func() -> void: _request("auction_cancel" if int(listing["seller"]) == own else "auction_buy",{"listing_id":listing_id}),170)
	var blocking: HBoxContainer = _row("Приватність")
	_button(blocking,"Заблокувати",func() -> void: _request("block",{"target":_social_target}),190)
	_button(blocking,"Розблокувати",func() -> void: _request("unblock",{"target":_social_target}),190)

func _social_name(id: int) -> String:
	var snapshot: Dictionary = network.social_snapshot
	var known: Dictionary = snapshot.get("known_names",{})
	if known.has(id) or known.has(str(id)):
		return str(known.get(id,known.get(str(id),"Гравець")))
	for peer: Dictionary in snapshot.get("onlineplayers",[]):
		if int(peer["id"]) == id:
			return str(peer["name"])
	return "Друг поза мережею"

func _bounty_board(snapshot: Dictionary) -> void:
	_text("Полювання за винагороду",23)
	_text("Замовлення на обраного гравця. Винагорода резервується до завершення.",15)
	var reward: SpinBox = _draft_number("bounty_reward","Винагорода в міді",1,100000000,20)
	var level: SpinBox = _draft_number("bounty_level","Мінімальний рівень мисливця",1,100,1)
	var required: SpinBox = _draft_number("bounty_required","Потрібно перемог",1,10,1)
	_button(_content,"Опублікувати замовлення",func() -> void: _request("bounty_create",{"target":_social_target,"reward":int(reward.value),"min_level":int(level.value),"required":int(required.value)}),320)
	for bounty: Dictionary in snapshot.get("bounties",[]):
		var id: int = int(bounty["id"])
		var status: String = {"available":"Вільне","accepted":"Виконується","completed":"Виконане","cancelled":"Скасоване"}.get(bounty["state"],bounty["state"])
		var row: HBoxContainer = _row("%s · %s · %d міді · %d/%d · Мисливець: %s" % [bounty.get("target_name",bounty["target"]),status,bounty["reward"],bounty["kills"],bounty["required"],bounty.get("hunter_name","—")])
		if bounty["state"] == "available":
			if int(bounty["creator"]) == int(snapshot["own_id"]):
				_button(row,"Скасувати",func() -> void: _request("bounty_cancel",{"bounty_id":id}),130)
			elif int(bounty["target"]) != int(snapshot["own_id"]):
				_button(row,"Взяти",func() -> void: _request("bounty_accept",{"bounty_id":id}),120)

func _draft_number(key: String, label: String, low: int, high: int, initial: int) -> SpinBox:
	var row: HBoxContainer = _row(label)
	var input: SpinBox = SpinBox.new()
	input.name = key
	input.min_value = low
	input.max_value = high
	input.step = 1
	input.value = clampi(int(_drafts.get(key,initial)),low,high)
	input.custom_minimum_size = Vector2(240,44)
	row.add_child(input)
	input.value_changed.connect(func(value: float) -> void: _drafts[key] = int(value))
	return input

func _world_combat_controls(account: int) -> void:
	var enabled: Variant = network.get("world_enabled")
	if typeof(enabled) != TYPE_BOOL or not enabled:
		return
	var packet: Variant = network.get("world_snapshot")
	var state: Dictionary = _world_control_state(packet if packet is Dictionary else {},account)
	_text("Бій між гравцями та дуелі",23)
	_button(_content,"Обрати гравця ціллю у світі",_select_online_target,380)
	var row: HBoxContainer = _row("PK-режим")
	var modes: Array[String] = ["peaceful","party","guild","free"]
	var labels: Array[String] = ["Мирний","Група","Гільдія","Вільний"]
	var choice: OptionButton = OptionButton.new()
	choice.name = "PKMode"
	choice.custom_minimum_size = Vector2(240,44)
	for index: int in modes.size():
		choice.add_item(labels[index])
		if state["pk_mode"] == modes[index]:
			choice.selected = index
	row.add_child(choice)
	choice.item_selected.connect(func(index: int) -> void: _request("game_pk_mode",{"mode":modes[index]}))
	if int(state["opponent"]) != 0:
		var duel: HBoxContainer = _row("Дуель із гравцем: " + _social_name(int(state["opponent"])))
		_button(duel,"Припинити дуель",func() -> void: _request("game_duel_cancel",{}),220)
	else:
		_button(_content,"Запросити обраного гравця на дуель",func() -> void: _request("game_duel_request",{"target":_social_target}),420)
	var inviter: int = int(state["inviter"])
	if inviter != 0:
		var invitation: HBoxContainer = _row("Запрошення на дуель: " + _social_name(inviter))
		_button(invitation,"Прийняти дуель",func() -> void: _request("game_duel_accept",{"target":inviter}),190)
		_button(invitation,"Відхилити",func() -> void: _request("game_duel_decline",{"target":inviter}),150)

func _select_online_target() -> void:
	if not is_instance_valid(player) or _social_target <= 0:
		show_notice("Спочатку обери гравця зі списку.")
		return
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is Node3D and node != player and node.has_meta("network_account") and int(node.get_meta("network_account")) == _social_target:
			player.current_target = node
			close_menu()
			return
	show_notice("Цього гравця зараз немає у спільному світі.")

func _group_title(kind: String, group: Dictionary) -> String:
	if group.is_empty():
		return kind + ": немає"
	var names: PackedStringArray = []
	for id: Variant in group.get("members",[]):
		names.append(_social_name(int(id)))
	return "%s %s · %s" % [kind,group.get("name",""),", ".join(names)]

func _deposit_nearby(id: int) -> bool:
	if not _near_citizen([50179]):
		show_notice("Підійди до торговця, щоб відкрити склад.")
		return false
	return services.deposit(id)
