extends Node3D

## Title screen and hero creation over a dusk diorama of Guanlin: a lit house,
## a campfire and the hero who changes as race and class are chosen.

const TOWN: String = "res://client/scenes/world/guanlin_town.tscn"
const NAMES: Array[String] = ["Арден", "Ліра", "Тарас", "Мірена", "Ворон", "Ельвін", "Яра", "Остап"]
const CLASS_INFO: Dictionary = {
	130001: ["Воїн", "broadsword", "Сталь і щит. Тримає удар, веде загін у бій."],
	130002: ["Маг", "wizard-staff", "Вогонь і крига. Б'є здалеку, лікує союзників."],
}
const RACE_INFO: Dictionary = {
	250001: ["Людина", "visored-helm", "Діти Ґуаньліня: витривалі й уперті, як дуби Сонячного лісу."],
	250002: ["Нічний ельф", "pointy-hat", "Вартові сутінок із бузковою шкірою, що бачать крізь темряву."],
}

var ui: CanvasLayer
var title_box: VBoxContainer
var create_box: Control
var stage: Node3D
var hero_holder: Node3D
var camera: Camera3D
var race_id: int = 250001
var class_id: int = 130001
var name_edit: LineEdit
var _cards: Dictionary = {}
var _time: float = 0.0

func _ready() -> void:
	_build_stage()
	_build_ui()
	_show_title()

# ------------------------------------------------------------------ Stage ---

func _build_stage() -> void:
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	var sky: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("1d2440")
	sky.sky_horizon_color = Color("d9875a")
	sky.ground_horizon_color = Color("5a3b33")
	sky.ground_bottom_color = Color("15131a")
	var s: Sky = Sky.new()
	s.sky_material = sky
	e.background_mode = Environment.BG_SKY
	e.sky = s
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.fog_enabled = true
	e.fog_light_color = Color("c9805a")
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, -55, 0)
	sun.light_color = Color("ffb074")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)
	stage = Node3D.new()
	add_child(stage)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80, 80)
	var meadow: ShaderMaterial = ShaderMaterial.new()
	meadow.shader = preload("res://client/shaders/meadow.gdshader")
	meadow.set_shader_parameter("paving", preload("res://assets/textures/cobble.png"))
	plane.material = meadow
	ground.mesh = plane
	ground.position = Vector3(0, 0, 30)   # shader roads sit at world x=0; keep the hero on grass
	stage.add_child(ground)
	var builder: TownBuilder = TownBuilder.new()
	stage.add_child(builder)
	builder.house(Vector3(-7.5, 0, -11), 25.0, 3, 3, 2, {"roof": "Roof_RoundTiles_6x6", "gable": "Roof_Front_Brick6", "chimney": true})
	builder.house(Vector3(8.5, 0, -14), -20.0, 3, 4, 2, {"base": "Plaster", "roof": "Roof_RoundTiles_6x8", "gable": "Roof_Front_Brick6"})
	for x: float in [-12.0, 12.0, -16.0, 15.0]:
		var tree: Node3D = preload("res://assets/models/v2/oak.glb").instantiate()
		tree.position = Vector3(x, 0, -14 + absf(x) * 0.3)
		tree.scale = Vector3.ONE * 1.8
		stage.add_child(tree)
	var fire: OmniLight3D = OmniLight3D.new()
	fire.light_color = Color("ff9a4a")
	fire.light_energy = 2.4
	fire.omni_range = 7.0
	fire.position = Vector3(1.6, 0.6, 1.2)
	fire.name = "Campfire"
	stage.add_child(fire)
	var embers: GPUParticles3D = GPUParticles3D.new()
	embers.amount = 60
	embers.lifetime = 2.2
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, 0.2, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	pm.color = Color("ffb35a")
	embers.process_material = pm
	var spark: QuadMesh = QuadMesh.new()
	spark.size = Vector2(0.06, 0.06)
	var spark_mat: StandardMaterial3D = StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.emission_enabled = true
	spark_mat.emission = Color("ff9a4a")
	spark_mat.emission_energy_multiplier = 4.0
	spark.material = spark_mat
	embers.draw_pass_1 = spark
	embers.position = fire.position
	stage.add_child(embers)
	var logs: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.4
	cyl.bottom_radius = 0.5
	cyl.height = 0.18
	var coal: StandardMaterial3D = StandardMaterial3D.new()
	coal.albedo_color = Color("2a1b12")
	coal.emission_enabled = true
	coal.emission = Color("ff6a2a")
	coal.emission_energy_multiplier = 1.6
	cyl.material = coal
	logs.mesh = cyl
	logs.position = Vector3(1.6, 0.09, 1.2)
	stage.add_child(logs)
	hero_holder = Node3D.new()
	stage.add_child(hero_holder)
	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	camera.make_current()
	_refresh_hero()

func _refresh_hero() -> void:
	for child: Node in hero_holder.get_children():
		child.queue_free()
	var model: Node3D = HeroAvatar.preview_model({"class_id": class_id, "race_id": race_id, "level": 12})
	model.rotation.y = deg_to_rad(-20)
	hero_holder.add_child(model)

func _process(delta: float) -> void:
	_time += delta
	var creating: bool = (create_box != null and create_box.visible) or (slots_box != null and (slots_box.visible or settings_box.visible))
	var target: Vector3 = Vector3(-1.6, 1.25, 4.6) if creating else Vector3(1.4 + sin(_time * 0.15) * 0.8, 2.2, 9.5)
	camera.position = camera.position.lerp(target, minf(1.0, delta * 2.0))
	camera.look_at(Vector3(0.2 if creating else 0.0, 1.0 if creating else 1.4, 0))
	var fire: OmniLight3D = stage.get_node("Campfire")
	fire.light_energy = 2.2 + sin(_time * 13.0) * 0.25 + sin(_time * 7.0) * 0.2
	if hero_holder.get_child_count() > 0:
		hero_holder.get_child(0).rotation.y = deg_to_rad(-20) + sin(_time * 0.6) * 0.25

# --------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuSkin.theme()
	ui.add_child(root)
	var shade: TextureRect = TextureRect.new()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color(0.02, 0.02, 0.04, 0.85), Color(0.02, 0.02, 0.04, 0.0)])
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.6, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	title_box = VBoxContainer.new()
	title_box.position = Vector2(80, 120)
	title_box.custom_minimum_size = Vector2(420, 0)
	title_box.add_theme_constant_override("separation", 14)
	root.add_child(title_box)
	var logo: Label = MenuSkin.title("Covenant\nChronicles", 76)
	logo.add_theme_constant_override("line_spacing", -18)
	logo.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	logo.add_theme_constant_override("outline_size", 10)
	title_box.add_child(logo)
	var sub: Label = MenuSkin.title("Хроніки Завіту", 28)
	sub.add_theme_color_override("font_color", HudSkin.GOLD)
	title_box.add_child(sub)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	title_box.add_child(gap)
	_menu_button("Грати", _show_slots, true)
	_menu_button("Налаштування", _show_settings)
	if not OS.has_feature("mobile"):
		_menu_button("Вихід", func() -> void: get_tree().quit())
	var version: Label = Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	version.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.position = Vector2(24, -36)
	root.add_child(version)
	_build_create(root)
	slots_box = _side_panel(root, "Герої")
	settings_box = _side_panel(root, "Налаштування")

# ------------------------------------------------------- Slots & settings ---

var slots_box: Control
var settings_box: Control
var _create_slot: int = 0

func _side_panel(root: Control, heading: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = HudSkin.panel_style(Color(0.05, 0.065, 0.09, 0.92), HudSkin.GOLD, 16, 1)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -620
	panel.offset_right = -36
	panel.clip_contents = true
	panel.offset_top = 36
	panel.offset_bottom = -36
	panel.hide()
	root.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.name = "Column"
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var top: HBoxContainer = HBoxContainer.new()
	col.add_child(top)
	var title: Label = MenuSkin.title(heading, 36)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close: Button = Button.new()
	close.text = "Назад"
	close.custom_minimum_size = Vector2(120, 46)
	close.pressed.connect(_show_title)
	top.add_child(close)
	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	return panel

func _body(panel: Control) -> VBoxContainer:
	var body: VBoxContainer = panel.get_node("Column/Body")
	for child: Node in body.get_children():
		child.queue_free()
	return body

func _show_slots() -> void:
	title_box.hide()
	create_box.hide()
	settings_box.hide()
	slots_box.show()
	var body: VBoxContainer = _body(slots_box)
	for slot: int in HeroSlots.COUNT:
		var first: Dictionary = _slot_summary(slot)
		if first:
			race_id = int(first["race_id"])
			class_id = int(first["class_id"]) if int(first["class_id"]) in CLASS_INFO else (130002 if int(first["class_id"]) in HeroAvatar.MAGE_CLASSES else 130001)
			_refresh_hero()
			break
	for slot: int in HeroSlots.COUNT:
		var hero: Dictionary = _slot_summary(slot)
		var card: PanelContainer = PanelContainer.new()
		var frame: StyleBoxFlat = HudSkin.panel_style(Color(0.09, 0.11, 0.15, 0.95), Color(0.85, 0.71, 0.42, 0.55 if hero else 0.25), 12, 1)
		frame.shadow_size = 0
		frame.content_margin_left = 16
		frame.content_margin_right = 16
		frame.content_margin_top = 14
		frame.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", frame)
		body.add_child(card)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var portrait: TextureRect = TextureRect.new()
		portrait.custom_minimum_size = Vector2(54, 54)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.texture = HudSkin.icon(("wizard-staff" if int(hero.get("class_id", 0)) in HeroAvatar.MAGE_CLASSES else "visored-helm") if hero else "knapsack")
		portrait.modulate = HudSkin.GOLD_LIGHT if hero else Color(0.45, 0.47, 0.52)
		row.add_child(portrait)
		var text: VBoxContainer = VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		if hero:
			text.add_child(MenuSkin.title(str(hero["name"]), 26))
			var meta: Label = Label.new()
			meta.text = "%s · %s · рівень %d" % [NewHero.RACES.get(int(hero["race_id"]), ""), CharacterSystem.CLASSES.get(int(hero["class_id"]), ""), int(hero["level"])]
			meta.add_theme_color_override("font_color", Color(0.7, 0.73, 0.8))
			meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			meta.custom_minimum_size.x = 160
			text.add_child(meta)
			var play: Button = Button.new()
			play.text = "Грати"
			play.custom_minimum_size = Vector2(110, 48)
			play.add_theme_stylebox_override("normal", MenuSkin.theme().get_stylebox("pressed", "Button"))
			play.add_theme_color_override("font_color", Color("1a1206"))
			play.pressed.connect(_play_slot.bind(slot))
			row.add_child(play)
			var remove: Button = Button.new()
			remove.text = "✕"
			remove.tooltip_text = "Видалити героя"
			remove.custom_minimum_size = Vector2(48, 48)
			remove.pressed.connect(_confirm_delete.bind(slot, remove))
			row.add_child(remove)
		else:
			text.add_child(MenuSkin.title("Вільний слот", 24))
			var hint: Label = Label.new()
			hint.text = "Створи нового героя"
			hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
			text.add_child(hint)
			var create: Button = Button.new()
			create.text = "Створити"
			create.custom_minimum_size = Vector2(130, 48)
			create.pressed.connect(func() -> void:
				_create_slot = slot
				_show_create())
			row.add_child(create)

func _confirm_delete(slot: int, button: Button) -> void:
	if button.text != "Точно?":
		button.text = "Точно?"
		button.custom_minimum_size.x = 96
		return
	if OnlineSession.enabled:
		OnlineSession.forget(slot)
	else:
		HeroSlots.delete(slot)
	_show_slots()

func _slot_summary(slot: int) -> Dictionary:
	return OnlineSession.summary(slot) if OnlineSession.enabled else HeroSlots.summary(slot)

func _play_slot(slot: int) -> void:
	HeroSlots.active = slot
	OnlineSession.slot = slot
	CombatFeedback.sound(self, "ui_ready", -10.0)
	get_tree().change_scene_to_file(TOWN)

func _show_settings() -> void:
	title_box.hide()
	create_box.hide()
	slots_box.hide()
	settings_box.show()
	var body: VBoxContainer = _body(settings_box)
	var settings: SettingsStore = SettingsStore.current()
	for entry: Array in [["master_volume", "Загальна гучність"], ["music_volume", "Музика й оточення"], ["effects_volume", "Ефекти"], ["camera_sensitivity", "Чутливість камери"], ["joystick_opacity", "Видимість джойстика"]]:
		var row: HBoxContainer = HBoxContainer.new()
		body.add_child(row)
		var label: Label = Label.new()
		label.text = entry[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var slider: HSlider = HSlider.new()
		slider.custom_minimum_size = Vector2(240, 40)
		slider.min_value = 0.2 if entry[0] == "camera_sensitivity" else 0.0
		slider.max_value = 3.0 if entry[0] == "camera_sensitivity" else 1.0
		slider.step = 0.05
		slider.value = float(settings.get_value(entry[0]))
		slider.value_changed.connect(func(value: float) -> void: settings.set_value(entry[0], value))
		row.add_child(slider)
	for entry: Array in [["quality", "Якість графіки", ["low", "medium", "high"], ["Низька", "Середня", "Висока"]], ["fps_limit", "Кадрів за секунду", [30, 60, 120], ["30", "60", "120"]]]:
		var row: HBoxContainer = HBoxContainer.new()
		body.add_child(row)
		var label: Label = Label.new()
		label.text = entry[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var choice: OptionButton = OptionButton.new()
		choice.custom_minimum_size = Vector2(240, 44)
		for index: int in entry[3].size():
			choice.add_item(entry[3][index])
			if entry[2][index] == settings.get_value(entry[0]):
				choice.selected = index
		choice.item_selected.connect(func(index: int) -> void: settings.set_value(entry[0], entry[2][index]))
		row.add_child(choice)
	for entry: Array in [["show_names", "Показувати імена"], ["show_damage", "Показувати шкоду"], ["invert_camera_y", "Інвертувати камеру по вертикалі"]]:
		var box: CheckButton = CheckButton.new()
		box.text = entry[1]
		box.custom_minimum_size.y = 44
		box.button_pressed = bool(settings.get_value(entry[0]))
		box.toggled.connect(func(value: bool) -> void: settings.set_value(entry[0], value))
		body.add_child(box)
	var server_row: HBoxContainer = HBoxContainer.new()
	body.add_child(server_row)
	var server_label: Label = Label.new()
	server_label.text = "Адреса сервера (Tailscale)"
	server_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_row.add_child(server_label)
	var server_edit: LineEdit = LineEdit.new()
	server_edit.text = OnlineSession.address()
	server_edit.custom_minimum_size = Vector2(240, 44)
	server_edit.text_changed.connect(func(value: String) -> void: OnlineSession.set_address(value))
	server_row.add_child(server_edit)
	var offline: CheckButton = CheckButton.new()
	offline.text = "Офлайн-режим (лише для тестів)"
	offline.custom_minimum_size.y = 44
	offline.button_pressed = not OnlineSession.enabled
	offline.toggled.connect(func(value: bool) -> void: OnlineSession.enabled = not value)
	body.add_child(offline)
	var note: Label = Label.new()
	note.text = "Клавіші, бойові опції й авто-зілля — у меню гри, розділ «Налаштування»."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
	note.add_theme_font_size_override("font_size", 13)
	body.add_child(note)

func _menu_button(text: String, action: Callable, primary: bool = false) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 58)
	b.add_theme_font_override("font", HudSkin.TITLE_FONT)
	b.add_theme_font_size_override("font_size", 26)
	if primary:
		b.add_theme_stylebox_override("normal", MenuSkin.theme().get_stylebox("pressed", "Button"))
		b.add_theme_color_override("font_color", Color("1a1206"))
	b.pressed.connect(func() -> void:
		CombatFeedback.sound(self, "ui_click", -12.0)
		action.call())
	title_box.add_child(b)
	return b

func _build_create(root: Control) -> void:
	create_box = Control.new()
	create_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	create_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(create_box)
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = HudSkin.panel_style(Color(0.05, 0.065, 0.09, 0.9), HudSkin.GOLD, 16, 1)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -560
	panel.offset_right = -36
	panel.offset_top = 36
	panel.offset_bottom = -36
	create_box.add_child(panel)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(MenuSkin.title("Новий герой", 36))
	col.add_child(_section("Раса"))
	var races: HBoxContainer = HBoxContainer.new()
	races.add_theme_constant_override("separation", 10)
	col.add_child(races)
	for id: int in RACE_INFO:
		races.add_child(_choice_card("race", id, RACE_INFO[id]))
	col.add_child(_section("Клас"))
	var classes: HBoxContainer = HBoxContainer.new()
	classes.add_theme_constant_override("separation", 10)
	col.add_child(classes)
	for id: int in CLASS_INFO:
		classes.add_child(_choice_card("class", id, CLASS_INFO[id]))
	col.add_child(_section("Ім'я"))
	name_edit = LineEdit.new()
	name_edit.text = NAMES[randi() % NAMES.size()]
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(0, 48)
	name_edit.add_theme_font_size_override("font_size", 20)
	col.add_child(name_edit)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var back: Button = Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(130, 56)
	back.pressed.connect(_show_slots)
	row.add_child(back)
	var start: Button = Button.new()
	start.text = "Почати пригоду"
	start.custom_minimum_size = Vector2(0, 56)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.add_theme_font_override("font", HudSkin.TITLE_FONT)
	start.add_theme_font_size_override("font_size", 26)
	start.add_theme_stylebox_override("normal", MenuSkin.theme().get_stylebox("pressed", "Button"))
	start.add_theme_color_override("font_color", Color("1a1206"))
	start.pressed.connect(_start_adventure)
	row.add_child(start)
	_update_cards()

func _section(text: String) -> Label:
	var l: Label = Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", HudSkin.GOLD)
	l.add_theme_font_size_override("font_size", 13)
	return l

func _choice_card(kind: String, id: int, info: Array) -> Button:
	var b: Button = Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 132)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_contents = true
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_top = 10
	box.offset_right = -12
	box.offset_bottom = -10
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head)
	var art: TextureRect = TextureRect.new()
	art.texture = HudSkin.icon(info[1])
	art.custom_minimum_size = Vector2(34, 34)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(art)
	var name_label: Label = MenuSkin.title(info[0], 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(name_label)
	var about: Label = Label.new()
	about.text = info[2]
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.add_theme_font_size_override("font_size", 13)
	about.add_theme_color_override("font_color", Color("c9b88a"))
	about.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(about)
	b.pressed.connect(func() -> void:
		if kind == "race": race_id = id
		else: class_id = id
		CombatFeedback.sound(self, "ui_click", -12.0)
		_update_cards()
		_refresh_hero())
	_cards[b] = [kind, id, art]
	return b

func _update_cards() -> void:
	for b: Button in _cards:
		var kind: String = _cards[b][0]
		var on: bool = _cards[b][1] == (race_id if kind == "race" else class_id)
		b.button_pressed = on
		var frame: StyleBoxFlat = HudSkin.panel_style(Color(0.85, 0.71, 0.42, 0.18) if on else Color(0.09, 0.11, 0.15, 0.95), HudSkin.GOLD_LIGHT if on else Color(0.85, 0.71, 0.42, 0.4), 12, 2 if on else 1)
		frame.shadow_size = 10 if on else 0
		frame.shadow_color = Color(0.85, 0.71, 0.42, 0.3)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, frame)
		(_cards[b][2] as TextureRect).modulate = HudSkin.GOLD_LIGHT if on else Color(0.6, 0.62, 0.68)

func _show_title() -> void:
	title_box.show()
	create_box.hide()
	if slots_box:
		slots_box.hide()
		settings_box.hide()

func _show_create() -> void:
	title_box.hide()
	slots_box.hide()
	settings_box.hide()
	create_box.show()

func _start_adventure() -> void:
	var hero_name: String = name_edit.text.strip_edges()
	if hero_name.length() < 2:
		hero_name = NAMES[0]
	OnlineSession.slot = _create_slot
	NewHero.begin(hero_name, race_id, class_id, _create_slot)
	if OnlineSession.enabled:
		# The server creates and keeps the hero; the local save is left untouched.
		NetworkManager.pending_hero = NewHero.pending.duplicate()
		NewHero.pending = {}
	CombatFeedback.sound(self, "ui_ready", -10.0)
	get_tree().change_scene_to_file(TOWN)
