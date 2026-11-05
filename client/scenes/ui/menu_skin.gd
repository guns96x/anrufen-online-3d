class_name MenuSkin
extends RefCounted

## Shared look for the full-screen game menu (docs/ui-mockup/bag.html): a theme
## for every control in all tabs, tab icons, item icons and rarity colours.

const TAB_ICONS: Dictionary = {
	"inventory": "knapsack", "equipment": "battle-gear", "character": "visored-helm", "skills": "spell-book",
	"journal": "scroll-quill", "map": "treasure-map", "shop": "two-coins", "warehouse": "padlock",
	"crafting": "anvil", "pets": "dragon-head", "social": "three-friends", "settings": "cog",
}
const SLOT_ICONS: Dictionary = {
	"head": "visored-helm", "body": "breastplate", "weapon": "broadsword", "shoes": "boots",
	"belt": "leg-armor", "glove": "gauntlet", "necklace": "necklace", "ring": "ring", "shield": "checked-shield",
}
const SLOT_NAMES: Dictionary = {
	"head": "Шолом", "body": "Обладунок", "weapon": "Зброя", "shoes": "Чоботи", "belt": "Пояс",
	"glove": "Рукавиці", "necklace": "Намисто", "ring": "Перстень", "shield": "Щит",
}
const RARITY: Array[Color] = [Color("3a4152"), Color("4f9a52"), Color("3d7fe0"), Color("a45be8"), Color("f0a43a")]
const RARITY_NAMES: Array[String] = ["Звичайне", "Добре", "Рідкісне", "Епічне", "Легендарне"]

static func theme() -> Theme:
	var t: Theme = Theme.new()
	var body: FontVariation = FontVariation.new()
	body.base_font = HudSkin.BODY_FONT_FILE
	body.variation_opentype = {"wght": 600}
	t.default_font = body
	t.default_font_size = 16
	var normal: StyleBoxFlat = HudSkin.panel_style(Color(0.09, 0.11, 0.15, 0.95), Color(0.85, 0.71, 0.42, 0.55), 10, 1)
	normal.shadow_size = 0
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.14, 0.16, 0.21, 0.98)
	hover.border_color = HudSkin.GOLD
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color("c9a65e")
	pressed.border_color = HudSkin.GOLD_LIGHT
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.07, 0.08, 0.1, 0.7)
	disabled.border_color = Color(0.3, 0.32, 0.38, 0.6)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", HudSkin.GOLD_LIGHT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("1a1206"))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.52, 0.58))
	t.set_color("font_color", "Label", Color(0.9, 0.92, 0.95))
	var field: StyleBoxFlat = HudSkin.panel_style(Color(0.05, 0.06, 0.09, 0.95), Color(0.85, 0.71, 0.42, 0.4), 8, 1)
	field.shadow_size = 0
	field.content_margin_left = 10
	field.content_margin_right = 10
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", Color.WHITE)
	t.set_stylebox("normal", "OptionButton", normal)
	t.set_stylebox("hover", "OptionButton", hover)
	t.set_stylebox("pressed", "OptionButton", pressed)
	t.set_stylebox("normal", "SpinBox", field)
	var grabber: StyleBoxFlat = HudSkin.panel_style(HudSkin.GOLD, HudSkin.GOLD, 4, 0)
	grabber.shadow_size = 0
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	var track: StyleBoxFlat = HudSkin.panel_style(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 4, 0)
	track.shadow_size = 0
	t.set_stylebox("scroll", "VScrollBar", track)
	t.set_stylebox("panel", "TooltipPanel", HudSkin.panel_style(Color(0.07, 0.09, 0.12, 0.98), HudSkin.GOLD, 8, 1))
	return t

static func rarity(item: Dictionary) -> int:
	var price: int = int(item.get("buy_price", 0))
	if item.get("kind") != "equipment":
		return 0 if price < 500 else 2
	if price >= 20000: return 4
	if price >= 6000: return 3
	if price >= 1500: return 2
	if price >= 300: return 1
	return 0

static func item_icon(item: Dictionary) -> String:
	var kind: String = str(item.get("kind", ""))
	var label: String = str(item.get("label", item.get("name", ""))).to_lower()
	match kind:
		"equipment":
			return SLOT_ICONS.get(str(item.get("slot", "")), "chest-armor")
		"mount":
			return "horseshoe"
		"pet_egg":
			return "egg-clutch"
		"pet_rune":
			return "rune-stone"
		"pet_food":
			return "meat"
		"pet_potion":
			return "magic-potion"
		"consumable":
			var effect: Dictionary = item.get("effect", {})
			if effect.get("stat") == "mp" or "ман" in label:
				return "magic-potion"
			if effect.get("stat") == "hp" or "зілл" in label:
				return "health-potion"
			return "bread"
	if "рун" in label or "符文" in label: return "rune-stone"
	if "гриб" in label: return "mushroom"
	if "павут" in label or "шовк" in label: return "spider-web"
	if "ікл" in label or "бивн" in label: return "boar-tusks"
	if "зелен" in label or "трав" in label: return "herbs-bundle"
	if "сувій" in label or "книг" in label: return "scroll-unfurled"
	if "камін" in label or "самоцв" in label: return "emerald"
	return "ore"

## A square item tile: rarity frame, icon and stack count.
static func tile(item: Dictionary, count: int, size: float = 76.0) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	var r: int = rarity(item)
	var frame: StyleBoxFlat = HudSkin.panel_style(Color("161b26"), RARITY[r], 12, 2)
	frame.shadow_color = Color(RARITY[r], 0.35) if r > 0 else Color(0, 0, 0, 0.4)
	frame.shadow_size = 6 if r > 0 else 3
	var chosen: StyleBoxFlat = frame.duplicate()
	chosen.border_color = HudSkin.GOLD_LIGHT
	chosen.set_border_width_all(3)
	chosen.bg_color = Color("232a38")
	b.add_theme_stylebox_override("normal", frame)
	b.add_theme_stylebox_override("hover", frame)
	b.add_theme_stylebox_override("pressed", chosen)
	b.add_theme_stylebox_override("hover_pressed", chosen)
	var art: TextureRect = TextureRect.new()
	art.texture = HudSkin.icon(item_icon(item))
	art.modulate = RARITY[r].lightened(0.45) if r > 0 else Color(0.92, 0.88, 0.8)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.offset_left = size * 0.18
	art.offset_top = size * 0.18
	art.offset_right = -size * 0.18
	art.offset_bottom = -size * 0.18
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(art)
	if count > 1:
		var n: Label = Label.new()
		n.text = str(count)
		n.add_theme_font_size_override("font_size", 13)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 4)
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.offset_left = -30
		n.offset_top = -22
		n.offset_right = -6
		n.offset_bottom = -2
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(n)
	return b

static func title(text: String, size: int = 28) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", HudSkin.TITLE_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", HudSkin.GOLD_LIGHT)
	return l
