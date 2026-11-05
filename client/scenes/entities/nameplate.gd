class_name Nameplate
extends RefCounted

## World-space labels and health bars over NPCs and enemies, in the HUD's style:
## Inter with a dark outline, and a gold-rimmed bar that only shows once hurt.

const BAR_W: int = 120
const BAR_H: int = 10

static var _frame: ImageTexture
static var _fill: ImageTexture

static func style(label: Label3D, color: Color, size: int = 30) -> void:
	var font: FontVariation = FontVariation.new()
	font.base_font = HudSkin.BODY_FONT_FILE
	font.variation_opentype = {"wght": 700}
	label.font = font
	label.font_size = size
	label.pixel_size = 0.0048
	label.modulate = color
	label.outline_size = 9
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.no_depth_test = false
	label.double_sided = true

static func _textures() -> void:
	if _frame != null:
		return
	var frame: Image = Image.create(BAR_W + 4, BAR_H + 4, false, Image.FORMAT_RGBA8)
	frame.fill(Color(0.85, 0.71, 0.42, 0.95))
	frame.fill_rect(Rect2i(1, 1, BAR_W + 2, BAR_H + 2), Color(0, 0, 0, 0.9))
	frame.fill_rect(Rect2i(2, 2, BAR_W, BAR_H), Color(0.12, 0.08, 0.08, 0.95))
	_frame = ImageTexture.create_from_image(frame)
	var fill: Image = Image.create(BAR_W, BAR_H, false, Image.FORMAT_RGBA8)
	for y: int in BAR_H:
		var shade: float = 1.0 - absf(float(y) / BAR_H - 0.35) * 0.9
		fill.fill_rect(Rect2i(0, y, BAR_W, 1), Color(0.85, 0.18, 0.14).lightened(0.25 * shade).darkened(0.25 * (1.0 - shade)))
	_fill = ImageTexture.create_from_image(fill)

static func _sprite(tex: Texture2D, height: float) -> Sprite3D:
	var s: Sprite3D = Sprite3D.new()
	s.texture = tex
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.pixel_size = 0.009
	s.shaded = false
	s.no_depth_test = false
	s.position.y = height
	return s

## Adds a health bar to an enemy; returns the fill sprite to update.
static func health_bar(parent: Node3D, height: float) -> Sprite3D:
	_textures()
	var back: Sprite3D = _sprite(_frame, height)
	back.name = "HealthFrame"
	parent.add_child(back)
	var fill: Sprite3D = _sprite(_fill, 0.0)
	fill.name = "HealthFill"
	fill.centered = false
	fill.offset = Vector2(-BAR_W / 2.0, -BAR_H / 2.0)
	fill.region_enabled = true
	fill.region_rect = Rect2(0, 0, BAR_W, BAR_H)
	fill.render_priority = 1
	back.add_child(fill)
	back.hide()
	return fill

static func set_fraction(fill: Sprite3D, fraction: float) -> void:
	fill.region_rect = Rect2(0, 0, maxf(1.0, BAR_W * clampf(fraction, 0.0, 1.0)), BAR_H)
	fill.get_parent().visible = fraction < 0.999 and fraction > 0.0
