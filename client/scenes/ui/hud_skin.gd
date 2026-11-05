class_name HudSkin
extends Node

## Dark-fantasy skin for the combat HUD (docs/ui-mockup): portrait with bars,
## target frame, gold-rimmed minimap and quest tracker, a thumb-sized skill ring
## with radial cooldowns, potions and an icon menu bar. Gameplay wiring stays in
## GameHUD; this node restyles its controls and adds press feedback.

const GOLD: Color = Color("d8b66a")
const GOLD_LIGHT: Color = Color("f3dfa4")
const GLASS: Color = Color(0.047, 0.059, 0.086, 0.78)
const ICONS: String = "res://assets/ui/icons/%s.svg"
const TITLE_FONT: Font = preload("res://assets/ui/fonts/CormorantSC-Bold.ttf")
const BODY_FONT_FILE: Font = preload("res://assets/ui/fonts/Inter.ttf")

const SKILL_ICONS: Dictionary = {
	90020: "sword-slice", 90014: "shield-bash", 90036: "fire-ring", 90122: "fire-ring",
	90035: "ice-spear", 90123: "ice-spear", 90041: "healing", 90126: "healing",
	90021: "crossed-swords", 90095: "whirlwind", 90129: "shield-reflect", 90104: "magic-swirl",
	90131: "magic-swirl", 90132: "heart-plus", 90135: "lightning-tree", 90139: "skull-crossed-bones",
}
const MENU: Array = [
	["inventory", "knapsack"], ["equipment", "battle-gear"], ["skills", "spell-book"],
	["journal", "scroll-quill"], ["pets", "dragon-head"], ["social", "three-friends"], ["settings", "cog"],
]
const HP_POTION: int = 30016
const MP_POTION: int = 30645

var hud: GameHUD
var body_font: FontVariation
var theme: Theme
var level_badge: Label
var target_frame: PanelContainer
var target_name: Label
var target_bar: ProgressBar
var target_icon: TextureRect
var zone_label: Label
var potion_counts: Dictionary = {}
var _dials: Dictionary = {}       # Button -> CooldownDial
var _icons: Dictionary = {}       # Button -> TextureRect
var _was_cooling: Dictionary = {}
var _extra_hit: Array[Control] = []

static func apply(owner_hud: GameHUD) -> HudSkin:
	var skin: HudSkin = HudSkin.new()
	skin.name = "HudSkin"
	skin.hud = owner_hud
	owner_hud.add_child(skin)
	return skin

func _ready() -> void:
	body_font = FontVariation.new()
	body_font.base_font = BODY_FONT_FILE
	body_font.variation_opentype = {"wght": 600}
	theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = 16
	_style_player_frame()
	_style_quest_tracker()
	_style_minimap()
	_build_target_frame()
	_style_skill_ring()
	_build_potions()
	_build_menu_bar()
	_style_dialogue()
	_style_joystick()
	hud.menu_button.position = Vector2(-1000, -1000)

# ---------------------------------------------------------------- Styling ---

static func panel_style(bg: Color = GLASS, border: Color = GOLD, radius: int = 12, width: int = 1) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 6
	box.anti_aliasing = true
	return box

static var _cjk_part: RegEx = RegEx.create_from_string("\\s*[·(（]?\\s*[\\x{4e00}-\\x{9fff}][^)）·\\n]*[)）]?")

## Removes Chinese source fragments (" · 名字", "(名字)") from on-screen text.
static func clean(text: String) -> String:
	return _cjk_part.sub(text, "", true).strip_edges()

static func icon(name: String) -> Texture2D:
	return load(ICONS % name)

func _title(label: Label, size: int, color: Color = GOLD_LIGHT) -> void:
	label.add_theme_font_override("font", TITLE_FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)

func _body(label: Label, size: int, color: Color = Color(0.92, 0.93, 0.96)) -> void:
	label.add_theme_font_override("font", body_font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)

func _bar_style(bar: ProgressBar, fill: Color, height: float) -> void:
	var bg: StyleBoxFlat = panel_style(Color(0.08, 0.09, 0.12, 0.95), Color.BLACK, 3)
	bg.shadow_size = 0
	var fg: StyleBoxFlat = panel_style(fill, fill.lightened(0.35), 3)
	fg.shadow_size = 0
	fg.border_width_bottom = 0
	fg.border_width_left = 0
	fg.border_width_right = 0
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.custom_minimum_size.y = height
	bar.show_percentage = false

func _style_player_frame() -> void:
	var frame: Control = hud.get_node("TopLeft")
	frame.offset_left = 20
	frame.offset_top = 16
	frame.offset_right = 430
	frame.offset_bottom = 150
	frame.get_node("Panel").hide()
	var plate: Panel = Panel.new()
	plate.add_theme_stylebox_override("panel", panel_style(Color(0.047, 0.059, 0.086, 0.7), Color(0.85, 0.71, 0.42, 0.55), 10))
	plate.position = Vector2(84, 8)
	plate.size = Vector2(330, 96)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(plate)
	frame.move_child(plate, 0)
	var portrait: Panel = Panel.new()
	var ring: StyleBoxFlat = panel_style(Color("1a202c"), GOLD, 56, 3)
	ring.shadow_size = 10
	portrait.add_theme_stylebox_override("panel", ring)
	portrait.size = Vector2(108, 108)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var face: TextureRect = TextureRect.new()
	face.texture = icon("visored-helm")
	face.modulate = GOLD_LIGHT
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.position = Vector2(20, 18)
	face.size = Vector2(68, 68)
	portrait.add_child(face)
	level_badge = Label.new()
	level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_badge.add_theme_stylebox_override("normal", panel_style(Color("1b150c"), GOLD, 11, 2))
	_body(level_badge, 15, GOLD_LIGHT)
	level_badge.position = Vector2(32, 92)
	level_badge.size = Vector2(44, 24)
	portrait.add_child(level_badge)
	var vbox: VBoxContainer = frame.get_node("VBox")
	vbox.offset_left = 120
	vbox.offset_top = 16
	vbox.offset_right = -24
	vbox.add_theme_constant_override("separation", 5)
	_title(hud.player_name_lbl, 21)
	_bar_style(hud.hp_bar, Color("c8352e"), 17)
	_bar_style(hud.mp_bar, Color("2f6fd6"), 15)
	_body(hud.get_node("TopLeft/VBox/HPBar/HPLbl"), 11)
	_body(hud.get_node("TopLeft/VBox/MPBar/MPLbl"), 11)
	for lbl: Label in [hud.get_node("TopLeft/VBox/HPBar/HPLbl"), hud.get_node("TopLeft/VBox/MPBar/MPLbl")]:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hud.exp_bar:
		_bar_style(hud.exp_bar, GOLD, 5)
	if hud.exp_lbl:
		_body(hud.exp_lbl, 11, Color(0.95, 0.88, 0.62))

func _style_quest_tracker() -> void:
	var tracker: Control = hud.get_node("TopRight")
	tracker.offset_left = -300
	tracker.offset_right = -20
	tracker.offset_top = 252
	var panel: Panel = hud.get_node("TopRight/QuestPanel")
	var style: StyleBoxFlat = panel_style(Color(0.047, 0.059, 0.086, 0.62), GOLD, 8, 0)
	style.border_width_right = 3
	style.shadow_size = 0
	panel.add_theme_stylebox_override("panel", style)
	_title(hud.quest_title_lbl, 18)
	_body(hud.quest_obj_lbl, 13)
	hud.quest_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.quest_obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _style_minimap() -> void:
	var mm: Minimap = hud.minimap
	mm.offset_left = -214
	mm.offset_right = -20
	mm.offset_top = 16
	mm.offset_bottom = 210
	mm.gold_rim = true
	zone_label = Label.new()
	zone_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zone_label.offset_left = -214
	zone_label.offset_right = -20
	zone_label.offset_top = 212
	zone_label.offset_bottom = 248
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title(zone_label, 17)
	hud.add_child(zone_label)
	var shortcuts: VBoxContainer = VBoxContainer.new()
	shortcuts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	shortcuts.offset_left = -270
	shortcuts.offset_right = -224
	shortcuts.offset_top = 22
	shortcuts.add_theme_constant_override("separation", 10)
	hud.add_child(shortcuts)
	for entry: Array in [["map", "treasure-map"], ["social", "envelope"], ["character", "swords-emblem"]]:
		var b: Button = _icon_button(entry[1], Vector2(46, 46), 23)
		b.pressed.connect(_open_menu.bind(entry[0]))
		shortcuts.add_child(b)
	_extra_hit.append(shortcuts)

func _build_target_frame() -> void:
	target_frame = PanelContainer.new()
	target_frame.add_theme_stylebox_override("panel", panel_style(GLASS, Color(0.85, 0.71, 0.42, 0.6), 30))
	target_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_frame.offset_left = -170
	target_frame.offset_right = 170
	target_frame.offset_top = 18
	target_frame.offset_bottom = 78
	target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.hide()
	hud.add_child(target_frame)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	target_frame.add_child(row)
	target_icon = TextureRect.new()
	target_icon.custom_minimum_size = Vector2(44, 44)
	target_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	target_icon.texture = icon("boar")
	target_icon.modulate = Color("ffb3a8")
	row.add_child(target_icon)
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	target_name = Label.new()
	_title(target_name, 17, Color("ffb3a8"))
	col.add_child(target_name)
	target_bar = ProgressBar.new()
	_bar_style(target_bar, Color("c8352e"), 14)
	col.add_child(target_bar)

func _icon_button(icon_name: String, size: Vector2, radius: int, tint: Color = GOLD_LIGHT) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = size
	b.size = size
	b.focus_mode = Control.FOCUS_NONE
	var normal: StyleBoxFlat = panel_style(GLASS, GOLD, radius, 1)
	var pressed: StyleBoxFlat = panel_style(Color(0.85, 0.71, 0.42, 0.3), GOLD_LIGHT, radius, 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var art: TextureRect = TextureRect.new()
	art.texture = icon(icon_name)
	art.modulate = tint
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = size.x * 0.2
	art.offset_top = size.y * 0.2
	art.offset_right = -size.x * 0.2
	art.offset_bottom = -size.y * 0.2
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	b.button_down.connect(func() -> void: feedback(b))
	return b

func _style_skill_ring() -> void:
	var ring: Control = hud.get_node("BottomRight")
	ring.offset_left = -372
	ring.offset_top = -372
	ring.offset_right = -20
	ring.offset_bottom = -20
	var layout: Dictionary = {
		hud.attack_btn: [Vector2(220, 220), 132.0, "broadsword", ""],
		hud.skill1_btn: [Vector2(124, 266), 78.0, "sword-slice", "1"],
		hud.skill2_btn: [Vector2(64, 112), 62.0, "sprint", ""],
		hud.interact_btn: [Vector2(-176, 128), 0.0, "talk", ""],
	}
	var slots: Array[Vector2] = [Vector2(132, 170), Vector2(192, 98), Vector2(276, 76)]
	for i: int in 3:
		var b: Button = ring.get_node("AssignedSkill%d" % (i + 2))
		layout[b] = [slots[i], 76.0, "magic-swirl", str(i + 2)]
	for b: Button in layout:
		var spec: Array = layout[b]
		var diameter: float = spec[1]
		b.set_anchors_preset(Control.PRESET_TOP_LEFT)
		b.position = spec[0]
		b.add_theme_color_override("font_color", Color(0, 0, 0, 0))
		b.add_theme_color_override("font_pressed_color", Color(0, 0, 0, 0))
		b.add_theme_color_override("font_hover_color", Color(0, 0, 0, 0))
		var art: TextureRect = TextureRect.new()
		art.texture = icon(spec[2])
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if b == hud.interact_btn:
			b.size = Vector2(156, 46)
			var pill: StyleBoxFlat = panel_style(Color("c9a65e"), GOLD_LIGHT, 23, 1)
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(state, pill)
			art.modulate = Color("1a1206")
			art.position = Vector2(10, 7)
			art.size = Vector2(32, 32)
			var caption: Label = Label.new()
			caption.text = "Говорити"
			_body(caption, 16, Color("1a1206"))
			caption.remove_theme_constant_override("outline_size")
			caption.position = Vector2(48, 10)
			caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(caption)
		else:
			b.size = Vector2(diameter, diameter)
			var style: StyleBoxFlat = panel_style(Color("141c2a") if b != hud.attack_btn else Color("2a1b12"), GOLD, int(diameter / 2.0), 3 if b == hud.attack_btn else 2)
			style.shadow_size = 8
			for state: String in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(state, style)
			art.modulate = GOLD_LIGHT
			var pad: float = diameter * 0.2
			art.position = Vector2(pad, pad)
			art.size = Vector2(diameter - pad * 2.0, diameter - pad * 2.0)
			var dial: CooldownDial = CooldownDial.new()
			dial.size = b.size
			dial.font = body_font
			dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(dial)
			_dials[b] = dial
			if spec[3] != "":
				var key: Label = Label.new()
				key.text = spec[3]
				key.add_theme_stylebox_override("normal", panel_style(Color.BLACK, GOLD, 6, 1))
				_body(key, 11, GOLD_LIGHT)
				key.position = Vector2(diameter - 18, diameter - 16)
				key.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(key)
		b.add_child(art)
		b.move_child(art, 0)
		b.pivot_offset = b.size / 2.0
		_icons[b] = art

func _build_potions() -> void:
	var ring: Control = hud.get_node("BottomRight")
	var x: float = -196.0
	for entry: Array in [[HP_POTION, "health-potion", Color("ff6a5a")], [MP_POTION, "magic-potion", Color("6aa7ff")]]:
		var b: Button = _icon_button(entry[1], Vector2(58, 58), 14, entry[2])
		b.position = Vector2(x, 200)
		b.pressed.connect(func() -> void:
			if hud.items.count_item(entry[0]) <= 0 or not hud.items.use_item(entry[0]):
				deny(b))
		ring.add_child(b)
		var count: Label = Label.new()
		_body(count, 13)
		count.position = Vector2(30, 36)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(count)
		potion_counts[entry[0]] = count
		_extra_hit.append(b)
		x += 68.0

func _build_menu_bar() -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", panel_style(GLASS, Color(0.85, 0.71, 0.42, 0.5), 16))
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -205
	bar.offset_right = 205
	bar.offset_top = -72
	bar.offset_bottom = -14
	hud.add_child(bar)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)
	for entry: Array in MENU:
		var b: Button = _icon_button(entry[1], Vector2(48, 44), 10)
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.pressed.connect(_open_menu.bind(entry[0]))
		row.add_child(b)
	_extra_hit.append(bar)

func _style_joystick() -> void:
	var base: Panel = hud.joystick.base_circle
	var knob: Panel = hud.joystick.knob
	var ring: StyleBoxFlat = panel_style(Color(0.02, 0.03, 0.05, 0.35), Color(0.85, 0.71, 0.42, 0.55), int(base.size.x / 2.0), 2)
	ring.shadow_size = 0
	base.add_theme_stylebox_override("panel", ring)
	var thumb: StyleBoxFlat = panel_style(Color("2a3142"), GOLD, int(knob.size.x / 2.0), 2)
	knob.add_theme_stylebox_override("panel", thumb)

func _style_dialogue() -> void:
	var panel: Panel = hud.get_node("DialogueBox/Panel")
	var style: StyleBoxFlat = panel_style(Color(0.06, 0.075, 0.105, 0.95), GOLD, 16, 1)
	style.shadow_size = 18
	panel.add_theme_stylebox_override("panel", style)
	_title(hud.npc_name_lbl, 24)
	_body(hud.dialogue_text_lbl, 16)
	var primary: StyleBoxFlat = panel_style(Color("c9a65e"), GOLD_LIGHT, 12, 1)
	var secondary: StyleBoxFlat = panel_style(Color(0.08, 0.09, 0.12, 0.9), GOLD, 12, 1)
	for pair: Array in [[hud.accept_btn, primary, Color("1a1206")], [hud.close_btn, secondary, GOLD_LIGHT]]:
		var b: Button = pair[0]
		for state: String in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, pair[1])
		b.add_theme_font_override("font", body_font)
		b.add_theme_color_override("font_color", pair[2])
		b.add_theme_color_override("font_hover_color", pair[2])
		b.button_down.connect(func() -> void: feedback(b))

# --------------------------------------------------------------- Feedback ---

## Press feel: squash, gold flash, click and a short haptic pulse.
func feedback(b: Control) -> void:
	b.pivot_offset = b.size / 2.0
	var tween: Tween = b.create_tween()
	tween.tween_property(b, "scale", Vector2(0.86, 0.86), 0.05)
	tween.tween_property(b, "scale", Vector2(1.06, 1.06), 0.07)
	tween.tween_property(b, "scale", Vector2.ONE, 0.08)
	b.self_modulate = Color(1.6, 1.4, 0.9)
	b.create_tween().tween_property(b, "self_modulate", Color.WHITE, 0.25)
	CombatFeedback.sound(hud, "ui_click", -14.0)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(18)

func deny(b: Control) -> void:
	var x: float = b.position.x
	var tween: Tween = b.create_tween()
	for offset: float in [8.0, -7.0, 5.0, -3.0, 0.0]:
		tween.tween_property(b, "position:x", x + offset, 0.035)
	CombatFeedback.sound(hud, "ui_deny", -16.0)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(40)

func ready_flash(b: Button) -> void:
	b.pivot_offset = b.size / 2.0
	var tween: Tween = b.create_tween()
	tween.tween_property(b, "scale", Vector2(1.14, 1.14), 0.09)
	tween.tween_property(b, "scale", Vector2.ONE, 0.16)
	b.self_modulate = Color(1.8, 1.6, 1.0)
	b.create_tween().tween_property(b, "self_modulate", Color.WHITE, 0.4)
	CombatFeedback.sound(hud, "ui_ready", -22.0)

func _open_menu(tab: String) -> void:
	if hud.is_modal_active():
		return
	CombatFeedback.sound(hud, "ui_open", -16.0)
	hud.game_menu.open_tab(tab)

func is_over(pos: Vector2) -> bool:
	for c: Control in _extra_hit:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false

# ------------------------------------------------------------------- Live ---

func _process(_delta: float) -> void:
	var player: Node = hud.progression.player_ref if hud.progression else null
	if not is_instance_valid(player):
		return
	var modal: bool = hud.is_modal_active()
	for c: Control in _extra_hit:
		c.visible = not modal
	hud.get_node("BottomRight").visible = not modal
	var stats: Dictionary = player.stats
	level_badge.text = str(stats.get("level", 1))
	hud.player_name_lbl.text = str(stats.get("name", "Мандрівник"))
	var outside: bool = player.global_position.z > GuanlinLayout.GATE_Z
	zone_label.text = "Сонячний ліс" if outside else "Ґуаньлінь"
	for id: int in potion_counts:
		potion_counts[id].text = "×%d" % hud.items.count_item(id)
	var mage: bool = int(stats.get("class_id", 130001)) in HeroAvatar.MAGE_CLASSES
	_icons[hud.attack_btn].texture = icon("wizard-staff" if mage else "broadsword")
	var hotbar: Dictionary = stats.get("hotbar", {})
	_icons[hud.skill1_btn].texture = icon(SKILL_ICONS.get(int(hotbar.get("1", 0)), "magic-swirl"))
	for i: int in 3:
		var b: Button = hud.get_node("BottomRight/AssignedSkill%d" % (i + 2))
		_icons[b].texture = icon(SKILL_ICONS.get(int(hotbar.get(str(i + 2), 0)), "magic-swirl"))
	for b: Button in _dials:
		var key: String = hud._button_cooldown_keys.get(b, "")
		var left: float = player.get_cooldown_left(key) if key != "" else 0.0
		var total: float = maxf(_cooldown_total(player, key), 0.01)
		var cooling: bool = left > 0.05 and key != "attack"
		_dials[b].set_value(clampf(left / total, 0.0, 1.0) if cooling else 0.0, left)
		b.modulate = Color.WHITE
		if _was_cooling.get(b, false) and not cooling:
			ready_flash(b)
		_was_cooling[b] = cooling
	_update_target(player)

func _cooldown_total(player: Node, key: String) -> float:
	match key:
		"dash":
			return Player.DASH_COOLDOWN
		"attack":
			return Player.ATTACK_COOLDOWN
	var slot: String = "1" if key == "fire" else key.trim_prefix("slot")
	var id: int = int(player.stats.get("hotbar", {}).get(slot, 0))
	if CharacterSystem.SKILLS.has(id):
		return float(CharacterSystem.SKILLS[id].get("cooldown", 1.0))
	if SkillRules.catalog().has(id):
		return maxf(1.0, float(SkillRules.catalog()[id].get("cooldown", 1.0)))
	return maxf(1.0, player.get_cooldown_left(key))

func _update_target(player: Node) -> void:
	var t: Variant = player.get("current_target")
	if not (t is Monster) or not is_instance_valid(t) or t.is_dead():
		target_frame.visible = false
		return
	target_frame.visible = not hud.is_modal_active()
	var monster: Monster = t
	target_name.text = clean(monster.monster_name)
	target_bar.max_value = float(monster.max_hp)
	target_bar.value = float(monster.current_hp)
	var lower: String = monster.monster_name.to_lower()
	target_icon.texture = icon("spider-face" if "павук" in lower or "spider" in lower else "bandit" if "розбій" in lower or "bandit" in lower else "wolf-head" if "шакал" in lower or "jackal" in lower else "boar")

## Radial cooldown sweep with the remaining seconds.
class CooldownDial extends Control:
	var fraction: float = 0.0
	var seconds: float = 0.0
	var font: Font

	func set_value(value: float, left: float) -> void:
		if absf(value - fraction) > 0.002 or (value > 0.0 and int(left * 10) != int(seconds * 10)):
			fraction = value
			seconds = left
			queue_redraw()

	func _draw() -> void:
		if fraction <= 0.0:
			return
		var c: Vector2 = size / 2.0
		var r: float = minf(size.x, size.y) / 2.0 - 2.0
		var points: PackedVector2Array = [c]
		var steps: int = 40
		for i: int in steps + 1:
			var a: float = -PI / 2.0 + TAU * fraction * float(i) / steps
			points.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(points, Color(0, 0, 0, 0.62))
		var text: String = "%d" % ceili(seconds) if seconds >= 1.0 else "%.1f" % seconds
		var fs: int = int(r * 0.7)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, c + Vector2(-w / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color.BLACK)
		draw_string(font, c + Vector2(-w / 2.0, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
