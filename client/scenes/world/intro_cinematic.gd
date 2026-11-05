class_name IntroCinematic
extends Node

## First-entry fly-over of Guanlin with story captions, played once after hero
## creation. Hides the HUD, can be skipped, then hands the camera back.

signal finished()

const SHOTS: Array = [
	# [camera from, camera to, look from, look to, caption]
	[Vector3(26, 22, 40), Vector3(10, 12, 24), Vector3(0, 2, 10), Vector3(0, 2, 0), "Ґуаньлінь. Містечко на краю Сонячного лісу."],
	[Vector3(12, 8, -12), Vector3(6, 6, -20), Vector3(0, 1, -30), Vector3(-6, 2, -36), "Відколи банда Гадюки прийшла з півдня, ліс став небезпечним."],
	[Vector3(-12, 5, -36), Vector3(-6, 4, -44), Vector3(-26, 4, -44), Vector3(4, 2, -49)],
	[Vector3(6, 3.2, 10), Vector3(3, 2.6, 7.5), Vector3(0, 1, 3), Vector3(0, 1.1, 3.6), ""],
]
const SHOT_TIME: float = 3.6

var world: Node3D
var hero_name: String = ""
var camera: Camera3D
var caption: Label
var skip_button: Button
var layer: CanvasLayer
var _time: float = 0.0
var _done: bool = false

func _ready() -> void:
	world.hud.hide()
	camera = Camera3D.new()
	camera.fov = 50
	world.add_child(camera)
	camera.make_current()
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var bars: Array[ColorRect] = []
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 70)
		if not top:
			bar.offset_top = -70
		layer.add_child(bar)
		bars.append(bar)
	caption = Label.new()
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -150
	caption.offset_bottom = -84
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", HudSkin.TITLE_FONT)
	caption.add_theme_font_size_override("font_size", 34)
	caption.add_theme_color_override("font_color", HudSkin.GOLD_LIGHT)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	caption.add_theme_constant_override("outline_size", 10)
	layer.add_child(caption)
	skip_button = Button.new()
	skip_button.text = "Пропустити ›"
	skip_button.theme = MenuSkin.theme()
	skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_button.offset_left = -190
	skip_button.offset_right = -24
	skip_button.offset_top = 14
	skip_button.offset_bottom = 56
	skip_button.pressed.connect(finish)
	layer.add_child(skip_button)

func caption_for(index: int) -> String:
	match index:
		2: return "Староста шукає того, хто наведе в окрузі лад."
		3: return "%s, твоя історія починається тут." % hero_name
	return str(SHOTS[index][4])

func _process(delta: float) -> void:
	if _done:
		return
	_time += delta
	var index: int = int(_time / SHOT_TIME)
	if index >= SHOTS.size():
		finish()
		return
	var t: float = smoothstep(0.0, 1.0, fmod(_time, SHOT_TIME) / SHOT_TIME)
	var shot: Array = SHOTS[index]
	camera.global_position = (shot[0] as Vector3).lerp(shot[1], t)
	camera.look_at((shot[2] as Vector3).lerp(shot[3], t))
	var local: float = fmod(_time, SHOT_TIME)
	caption.text = caption_for(index)
	caption.modulate.a = clampf(minf(local / 0.6, (SHOT_TIME - local) / 0.5), 0.0, 1.0)

func finish() -> void:
	if _done:
		return
	_done = true
	world.hud.show()
	world.local_player.camera.make_current()
	camera.queue_free()
	world.hud.show_banner("Ґуаньлінь")
	finished.emit()
	queue_free()
