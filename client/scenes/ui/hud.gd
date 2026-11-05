class_name GameHUD
extends CanvasLayer

signal attack_pressed()
signal skill_1_pressed()
signal skill_2_pressed()
signal assigned_skill_pressed(slot: String)
signal interact_pressed()
signal quest_accepted(quest_id: int)
signal quest_completed(quest_id: int, exp_reward: int, attack_bonus: int)
signal dialogue_opened()
signal dialogue_closed()

enum QuestState { NONE, ACTIVE, READY, DONE }

## Backward compatible dictionary of quests for Guanlin Town.
## Keys include both authentic source IDs and legacy prototype IDs.
const QUESTS: Dictionary = QuestData.DEFINITIONS

@onready var hp_bar: ProgressBar = $TopLeft/VBox/HPBar
@onready var mp_bar: ProgressBar = $TopLeft/VBox/MPBar
@onready var player_name_lbl: Label = $TopLeft/VBox/NameLabel
@onready var joystick: TouchJoystick = $BottomLeft/VirtualJoystick
@onready var quest_title_lbl: Label = $TopRight/QuestPanel/VBox/QuestTitle
@onready var quest_obj_lbl: Label = $TopRight/QuestPanel/VBox/QuestObjectives

@onready var attack_btn: Button = $BottomRight/AttackButton
@onready var skill1_btn: Button = $BottomRight/Skill1Button
@onready var skill2_btn: Button = $BottomRight/Skill2Button
@onready var interact_btn: Button = $BottomRight/InteractButton

# Dialogue Window
@onready var dialogue_box: Control = $DialogueBox
@onready var npc_name_lbl: Label = $DialogueBox/Panel/NPCName
@onready var dialogue_text_lbl: Label = $DialogueBox/Panel/DialogueScroll/DialogueText
@onready var accept_btn: Button = $DialogueBox/Panel/AcceptButton
@onready var close_btn: Button = $DialogueBox/Panel/CloseButton

var progression: ProgressionController
var quest_states: Dictionary = {}   # quest_id -> QuestState (backward compat)
var quest_kills: Dictionary = {}    # quest_id -> int
var active_quest_id: int = 0

var _current_dialogue_action: String = "none"
var _current_dialogue_qid: int = 0
var _modal_backdrop: Control

var exp_bar: ProgressBar
var exp_lbl: Label
var minimap: Minimap
var death_overlay: ColorRect
var death_lbl: Label
var items: InventorySystem = InventorySystem.new()
var pets: CompanionSystem = CompanionSystem.new()
var services: GameServices = GameServices.new()
var game_menu: GameMenu
var menu_button: Button
var _save_queued: bool = false
var _potion_timer: float = 0.0
var _auto_medicine_sent: Dictionary = {}
var _service_button: Button
var skin: HudSkin

var _action_buttons: Array[Button] = []
var _button_labels: Dictionary = {}
var _button_cooldown_keys: Dictionary = {}

func _ready() -> void:
	# Instantiate source-backed progression controller
	progression = ProgressionController.new()
	progression.auto_save_enabled = not ("--review" in OS.get_cmdline_user_args() or "--test-mode" in OS.get_cmdline_user_args())
	progression.name = "ProgressionController"
	add_child(progression)

	progression.quest_accepted.connect(_on_progression_quest_accepted)
	progression.quest_completed.connect(_on_progression_quest_completed)

	for qid: int in QUESTS:
		quest_states[qid] = QuestState.NONE
		quest_kills[qid] = 0

	_action_buttons = [attack_btn, skill1_btn, skill2_btn, interact_btn]
	_button_cooldown_keys = { attack_btn: "attack", skill1_btn: "fire", skill2_btn: "dash" }
	for slot: int in [2,3,4]:
		var button: Button = skill1_btn.duplicate()
		button.name = "AssignedSkill%d" % slot
		button.set_meta("skill_slot",str(slot))
		$BottomRight.add_child(button)
		button.offset_left = -250
		button.offset_right = -186
		button.offset_top = -72-(slot-2)*88
		button.offset_bottom = button.offset_top+64
		button.hide()
		_action_buttons.append(button)
		_button_cooldown_keys[button] = "slot%d" % slot
	for b: Button in _action_buttons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
		b.pivot_offset = b.size / 2.0
		_button_labels[b] = b.text

	_setup_dialogue_modal()
	dialogue_box.hide()

	_build_exp_bar()
	_build_minimap()
	_build_death_overlay()
	game_menu = GameMenu.new()
	game_menu.hud = self
	add_child(game_menu)
	menu_button = Button.new()
	menu_button.text = "МЕНЮ / СУМКА"
	menu_button.position = Vector2(24,164)
	menu_button.custom_minimum_size = Vector2(174,46)
	menu_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu_button)
	items.changed.connect(on_systems_changed)
	pets.changed.connect(on_systems_changed)
	services.changed.connect(on_systems_changed)
	SettingsStore.current().changed.connect(func(_key: String,_value: Variant) -> void: joystick.base_circle.modulate.a = float(SettingsStore.current().get_value("joystick_opacity")))

	skin = HudSkin.apply(self)
	call_deferred("_bind_player_from_group")
	update_quest_tracker()

func _process(delta: float) -> void:
	if menu_button:
		menu_button.visible = not is_modal_active()
	if progression and progression.player_ref == null:
		_bind_player_from_group()
	if is_instance_valid(progression.player_ref):
		if not progression.player_ref.get_meta("network_world",false):
			pets.tick(delta)
		_potion_timer = maxf(0.0,_potion_timer-delta)
		if _potion_timer <= 0 and not progression.player_ref.is_dead:
			_potion_timer = 0.25
			var now: float = Time.get_unix_time_from_system()
			for intent: Dictionary in AutoMedicine.intents(progression.player_ref.stats,SettingsStore.current().values,now):
				var action: String = intent["action"]
				var payload: Dictionary = intent["payload"]
				if progression.player_ref.get_meta("network_world",false):
					if now-float(_auto_medicine_sent.get(intent["group"],0)) < 1.5: continue
					_auto_medicine_sent[intent["group"]] = now
					get_node("/root/NetworkManager").request("game_"+action,payload)
				elif action == "use": items.use_item(int(payload["id"]))
				else: pets.medicate(str(payload["uid"]),int(payload["id"]))

func _bind_player_from_group() -> void:
	var player: Node = get_tree().get_first_node_in_group("players")
	if not player or not progression or progression.player_ref == player:
		return
	CharacterSystem.ensure_stats(player.stats)
	items.bind_player(player)
	pets.bind_player(player)
	services.bind_player(player,items)
	player.stats["starter_supplies_granted"] = false
	progression.bind_player(player)
	if not player.stats["starter_supplies_granted"]:
		items.add_item(30016,3)
		items.add_item(30645,2)
		player.stats["starter_supplies_granted"] = true
	game_menu.bind_player(player,items,services,pets)
	on_systems_changed()
	update_quest_tracker()
	SettingsStore.current().apply_all()

func on_systems_changed() -> void:
	if not is_instance_valid(progression.player_ref):
		return
	items.locked_items.clear()
	for value: Variant in progression.player_ref.stats.get("locked_items",[]):
		items.locked_items.append(int(value))
	for id: int in progression.quest_item_locks():
		if id not in items.locked_items: items.locked_items.append(id)
	if progression.player_ref.stats.get("mounted",false):
		var mount_id: int = int(progression.player_ref.stats.get("mount_id",0))
		if mount_id not in items.locked_items:
			items.locked_items.append(mount_id)
	CharacterSystem.rebuild_stats(progression.player_ref.stats,items.bonus_totals())
	progression.refresh_available_quests()
	update_quest_tracker()
	if game_menu:
		game_menu.refresh()
	if not _save_queued:
		_save_queued = true
		call_deferred("_save_systems")

func _save_systems() -> void:
	_save_queued = false
	progression._save_if_enabled()

func _setup_dialogue_modal() -> void:
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_STOP

	# Fullscreen input blocker backdrop behind the dialogue panel to guarantee modal blocking
	_modal_backdrop = Control.new()
	_modal_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_box.add_child(_modal_backdrop)
	dialogue_box.move_child(_modal_backdrop, 0)

	accept_btn.pressed.connect(_on_dialogue_accept)
	close_btn.pressed.connect(close_dialogue)

	# Touch target optimization: ensure at least 46px height for mobile fingers
	accept_btn.custom_minimum_size = Vector2(170, 46)
	close_btn.custom_minimum_size = Vector2(110, 46)
	_service_button = Button.new()
	_service_button.position = Vector2(24,232)
	_service_button.size = Vector2(240,46)
	_service_button.text = "Торгівля та склад"
	_service_button.pressed.connect(func() -> void: game_menu.open_tab("shop"))
	$DialogueBox/Panel.add_child(_service_button)
	_service_button.hide()

# ------------------------------------------------------------ Modal API ---

## Returns true if the dialogue window is currently open (blocking gameplay).
func is_dialogue_open() -> bool:
	return dialogue_box != null and dialogue_box.visible

## Expose method for Codex world / player wiring to query modal blocking state.
func is_modal_active() -> bool:
	return is_dialogue_open() or (game_menu != null and game_menu.visible)

func close_dialogue() -> void:
	if game_menu and game_menu.visible:
		game_menu.close_menu()
	if dialogue_box.visible:
		dialogue_box.hide()
		dialogue_closed.emit()

# ------------------------------------------------------------ Touch input ---

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and menu_button and menu_button.get_global_rect().has_point(event.position) and not is_modal_active():
		game_menu.open_tab("inventory")
		get_viewport().set_input_as_handled()
		return
	if is_modal_active():
		return

	if event is InputEventScreenTouch and event.pressed:
		for b: Button in _action_buttons:
			if b.visible and _button_hit(b, event.position):
				_press_button(b)
				get_viewport().set_input_as_handled()
				return

func _button_hit(b: Button, pos: Vector2) -> bool:
	var rect: Rect2 = b.get_global_rect().grow(10.0)
	return rect.has_point(pos)

## True when a screen position is over an on-screen control (so the world should ignore it).
func is_point_over_ui(pos: Vector2) -> bool:
	if menu_button and menu_button.get_global_rect().has_point(pos):
		return true
	if is_modal_active():
		return true
	for b: Button in _action_buttons:
		if b.visible and _button_hit(b, pos):
			return true
	if minimap and minimap.get_global_rect().has_point(pos):
		return true
	if skin and skin.is_over(pos):
		return true
	return false

func _press_button(b: Button) -> void:
	if skin:
		skin.feedback(b)
	if b.has_meta("skill_slot"):
		assigned_skill_pressed.emit(str(b.get_meta("skill_slot")))
	elif b == attack_btn:
		attack_pressed.emit()
	elif b == skill1_btn:
		skill_1_pressed.emit()
	elif b == skill2_btn:
		skill_2_pressed.emit()
	elif b == interact_btn:
		interact_pressed.emit()

# ------------------------------------------------------------- Player UI ---

func update_player_stats(stats: Dictionary) -> void:
	var hp: int = stats.get("hp", 100)
	var max_hp: int = stats.get("max_hp", 100)
	var mp: int = stats.get("mp", 50)
	var max_mp: int = stats.get("max_mp", 50)
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	$TopLeft/VBox/HPBar/HPLbl.text = "%d / %d" % [hp, max_hp]
	mp_bar.max_value = max_mp
	mp_bar.value = mp
	$TopLeft/VBox/MPBar/MPLbl.text = "%d / %d" % [mp, max_mp]
	player_name_lbl.text = "Рів. %d · %s" % [stats.get("level", 1), stats.get("name", "Мандрівник")]
	if exp_bar and exp_lbl:
		exp_bar.max_value = stats.get("exp_to_next", 100)
		exp_bar.value = stats.get("exp", 0)
		exp_lbl.text = "Досвід %d/%d · Мідь %d%s" % [stats.get("exp", 0), stats.get("exp_to_next", 100), stats.get("copper", 0), " · Меч ✓" if progression.has_sword() else ""]

func update_cooldowns(player: Player) -> void:
	for b: Button in _button_cooldown_keys:
		if b.has_meta("skill_slot"):
			var slot: String = str(b.get_meta("skill_slot"))
			b.visible = int(player.stats.get("hotbar",{}).get(slot,0)) > 0
		var left: float = player.get_cooldown_left(_button_cooldown_keys[b])
		if left > 0.05 and _button_cooldown_keys[b] != "attack":
			b.text = "%.1f" % left
		else:
			b.text = _button_labels[b]
			if b == skill1_btn:
				var id: int = int(player.stats.get("hotbar",{}).get("1",0))
				b.text = _skill_short_name(id)
				b.tooltip_text = str(CharacterSystem.SKILLS.get(id,{}).get("name","Навичка"))
			elif b.has_meta("skill_slot"):
				var slot: String = str(b.get_meta("skill_slot"))
				var id: int = int(player.stats.get("hotbar",{}).get(slot,0))
				b.text = slot+"\n"+_skill_short_name(id)
				b.tooltip_text = str(CharacterSystem.SKILLS.get(id,{}).get("name","Навичка"))

func _skill_short_name(id: int) -> String:
	return str({90014:"УДАР+",90036:"ВОГОНЬ",90035:"КРИГА",90041:"ЛІКУВ.",90020:"МЕЧ",90021:"КИНДЖ.",90095:"РОЗМАХ",90122:"ВОГОНЬ",90123:"КРИГА",90126:"ЛІКУВ.",90129:"ЩИТ",90104:"АУРА",90131:"АУРА",90132:"ГРУПА",90135:"СТИХІЇ",90139:"ПРОКЛ."}.get(id,str(CharacterSystem.SKILLS.get(id,{}).get("name","НАВИЧКА")).get_slice(" ",0).left(7).to_upper()))

func set_interact_available(available: bool) -> void:
	interact_btn.visible = available

func show_death(is_dead: bool, seconds_left: float = 0.0) -> void:
	death_overlay.visible = is_dead
	if is_dead:
		close_dialogue()
		death_lbl.text = "Ти впав у бою...\nВідродження за %d" % ceili(seconds_left)

func show_banner(text: String, color: Color = Color.GOLD) -> void:
	if is_modal_active():
		return
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", HudSkin.TITLE_FONT)
	lbl.add_theme_font_size_override("font_size", 38)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = 170.0
	lbl.offset_bottom = 220.0
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	add_child(lbl)
	var tween: Tween = create_tween()
	tween.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.finished.connect(lbl.queue_free)

# ---------------------------------------------------------------- Quests ---

## Shows dialogue using the NPC node directly for full branching state resolution.
func show_dialogue_npc(npc_node: Node) -> void:
	_service_button.hide()
	var citizen: int = int(npc_node.get("citizen_id"))
	if citizen in [50180,50182,50184]:
		game_menu.open_tab({50180:"pets",50182:"crafting",50184:"social"}[citizen])
		return
	if citizen == 50179:
		_service_button.show()
	if progression:
		var interaction: Dictionary = progression.get_npc_interaction(npc_node)
		_display_dialogue(
			interaction.get("speaker", "Citizen"),
			interaction.get("text", ""),
			interaction.get("quest_id", 0),
			interaction.get("action", "none"),
			interaction.get("action_button_text", "Accept"),
			interaction.get("close_button_text", "Close")
		)
	else:
		var s: String = npc_node.get("npc_name") if npc_node.get("npc_name") != null else "Citizen"
		var t: String = npc_node.get("dialogue_text") if npc_node.get("dialogue_text") != null else ""
		var q: int = npc_node.get("quest_id") if npc_node.get("quest_id") != null else 0
		show_dialogue(s, t, q)

## Legacy / public signature for showing NPC dialogue.
func show_dialogue(speaker: String, text: String, quest_id: int = 0) -> void:
	if quest_id == 0:
		_display_dialogue(speaker, text, 0, "none", "", "Закрити")
		return
	var npc: NPC = NPC.new()
	npc.npc_name = speaker
	npc.quest_id = quest_id
	show_dialogue_npc(npc)
	npc.free()

func _display_dialogue(speaker: String, text: String, qid: int, action: String, action_btn_txt: String, close_btn_txt: String) -> void:
	# Stop joystick when modal opens so player does not keep walking
	if joystick:
		if joystick.has_method("_reset"):
			joystick._reset()
		else:
			joystick.is_pressed = false

	npc_name_lbl.text = speaker
	dialogue_text_lbl.text = text
	active_quest_id = qid
	_current_dialogue_qid = qid
	_current_dialogue_action = action

	close_btn.text = close_btn_txt
	if action != "none" and not action_btn_txt.is_empty():
		accept_btn.text = action_btn_txt
		accept_btn.show()
	else:
		accept_btn.hide()

	dialogue_box.show()
	dialogue_opened.emit()

func _on_dialogue_accept() -> void:
	var qid: int = _current_dialogue_qid
	var action: String = _current_dialogue_action
	close_dialogue()
	if is_instance_valid(progression.player_ref) and progression.player_ref.get_meta("network_world",false):
		get_node("/root/NetworkManager").request("game_quest",{"qid":qid,"citizen":progression._last_citizen_id,"action":action})
		return
	match action:
		"accept":
			if progression.accept_quest(qid):
				show_banner("Нове доручення: " + QuestData.DEFINITIONS[qid]["title_uk"], Color(0.65, 0.9, 1.0))
		"complete":
			var result: Dictionary = progression.complete_quest(qid)
			if result.get("success", false):
				show_banner("Виконано · +%d досвіду · +%d міді" % [result["exp"], result["copper"]])
			else:
				show_banner(str(result.get("error","Завдання ще не виконане.")),Color.SALMON)
		"buy":
			if progression.buy_sword():
				show_banner("Куплено довгий меч. Віднеси його старості.")
			else:
				show_banner("Для купівлі потрібно %d міді та місце в сумці." % QuestData.PROVISIONAL_SWORD_PRICE_COPPER, Color.SALMON)
	on_systems_changed()

func _on_progression_quest_accepted(qid: int) -> void:
	quest_states[qid] = QuestState.ACTIVE
	quest_accepted.emit(qid)
	update_quest_tracker()

func _on_progression_quest_completed(qid: int, exp_reward: int, attack_bonus: int) -> void:
	quest_states[qid] = QuestState.DONE
	quest_completed.emit(qid, exp_reward, attack_bonus)
	update_quest_tracker()

func add_monster_kill(monster_id: int) -> void:
	if progression:
		var newly_ready: Array[int] = progression.add_monster_kill(monster_id)
		for qid: int in newly_ready:
			var q: Dictionary = QuestData.get_definition(qid)
			var title: String = q.get("title_uk", q.get("title", ""))
			show_banner("%s: objective complete! / Ціль виконано!" % title, Color.SPRING_GREEN)
		# Update legacy quest_kills for backward compatibility
		for qid: int in progression.quest_kills:
			quest_kills[qid] = progression.quest_kills[qid]
			if progression.quest_states.get(qid) == QuestData.QuestState.READY:
				quest_states[qid] = QuestState.READY
	else:
		for qid: int in QUESTS:
			if quest_states[qid] != QuestState.ACTIVE:
				continue
			var q: Dictionary = QUESTS[qid]
			if monster_id in q["targets"]:
				quest_kills[qid] = mini(q["required"], quest_kills[qid] + 1)
				if quest_kills[qid] >= q["required"]:
					quest_states[qid] = QuestState.READY
					show_banner("%s: objective complete!" % q["title"], Color.SPRING_GREEN)

	update_quest_tracker()

## Returns quest state compatible with Minimap and NPC quest markers.
func get_quest_state(quest_id: int) -> int:
	if progression:
		return progression.get_hud_quest_state(quest_id)
	return quest_states.get(quest_id, QuestState.NONE)

## Returns marker text ("!" or "?") directly for NPC nodes.
func get_npc_marker(npc_node: Node) -> String:
	if progression:
		return progression.get_npc_marker(npc_node)
	var qid: int = npc_node.get("quest_id") if npc_node.get("quest_id") != null else 0
	match get_quest_state(qid):
		QuestState.NONE:
			return "!"
		QuestState.READY:
			return "?"
	return ""

func update_quest_tracker() -> void:
	if progression == null:
		return
	var lines: PackedStringArray = []
	var done_count: int = 0
	for qid: int in QuestData.get_ordered_quest_ids():
		var q: Dictionary = QuestData.DEFINITIONS[qid]
		match progression.quest_states[qid]:
			QuestData.QuestState.ACTIVE:
				if qid == 80005:
					lines.append("Звіти: %d/3 · Потрібен рівень 8" % progression.quest_kills[qid])
				elif not q.get("targets", []).is_empty() or not q.get("required_items",{}).is_empty():
					lines.append("%s: %d/%d" % [q["title_uk"], progression.quest_kills[qid], q["required"]])
				elif qid == 80591 and not progression.has_sword():
					lines.append("Купи меч у торговця: %d міді" % QuestData.PROVISIONAL_SWORD_PRICE_COPPER)
				else:
					lines.append("%s → %s" % [q["title_uk"], _citizen_title(q["turnin_id"])])
			QuestData.QuestState.READY:
				lines.append("✓ Доповісти: " + _citizen_title(q["turnin_id"]))
			QuestData.QuestState.DONE:
				done_count += 1
	quest_title_lbl.text = "ДОРУЧЕННЯ · %d/%d" % [done_count,QuestData.DEFINITIONS.size()]
	if done_count == QuestData.DEFINITIONS.size():
		quest_obj_lbl.text = "Усі поточні доручення виконано."
	elif lines.is_empty():
		quest_obj_lbl.text = "Поговори з жителем, позначеним !"
	else:
		quest_obj_lbl.text = "\n".join(lines)
	$TopRight.offset_bottom = $TopRight.offset_top + clampf(float(quest_obj_lbl.get_line_count()) * 18.0 + 48.0, 70.0, 240.0)

func _citizen_title(citizen_id: int) -> String:
	return {50164: "Староста", 50166: "Капітан", 50179: "Торговець зброєю", 50167: "Ласун", 50168: "Вдова Анна", 50169: "Контрабандист"}.get(citizen_id, "Житель")

func spawn_floating_text(screen_pos: Vector2, text: String, color: Color = Color.WHITE) -> void:
	if is_modal_active() or not SettingsStore.current().get_value("show_damage"):
		return
	var label: Label = Label.new()
	label.text = text
	label.position = screen_pos + Vector2(randf_range(-20, 20), randf_range(-20, 20))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tween.finished.connect(label.queue_free)

# -------------------------------------------------------------- Builders ---

func _build_exp_bar() -> void:
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.75, 0.2, 0.95)
	fill.set_corner_radius_all(3)
	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(0, 10)
	exp_bar.show_percentage = false
	exp_bar.add_theme_stylebox_override("fill", fill)
	$TopLeft/VBox.add_child(exp_bar)
	exp_lbl = Label.new()
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	$TopLeft/VBox.add_child(exp_lbl)

func _build_minimap() -> void:
	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -184.0
	minimap.offset_right = -24.0
	minimap.offset_top = 24.0
	minimap.offset_bottom = 184.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap)
	minimap.hud = self

func _build_death_overlay() -> void:
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.25, 0.0, 0.0, 0.45)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.hide()
	add_child(death_overlay)
	death_lbl = Label.new()
	death_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_lbl.add_theme_font_size_override("font_size", 36)
	death_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	death_lbl.add_theme_constant_override("outline_size", 8)
	death_overlay.add_child(death_lbl)
	move_child(death_overlay, 0)
