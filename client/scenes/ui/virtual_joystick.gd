class_name TouchJoystick
extends Control

signal joystick_updated(output: Vector2)

@export var max_radius: float = 64.0
@export var deadzone: float = 0.1

var is_pressed: bool = false
var touch_index: int = -1
var center_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var output: Vector2 = Vector2.ZERO

@onready var base_circle: Control = $Base
@onready var knob: Control = $Base/Knob

func _ready() -> void:
	center_pos = base_circle.position + base_circle.size / 2.0
	current_pos = center_pos
	_update_knob()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if touch is in bottom-left screen quadrant
			var vp_size = get_viewport_rect().size
			if event.position.x < vp_size.x * 0.45 and event.position.y > vp_size.y * 0.4:
				touch_index = event.index
				is_pressed = true
				center_pos = event.position
				base_circle.global_position = center_pos - base_circle.size / 2.0
				current_pos = center_pos
				_handle_motion(event.position)
		elif event.index == touch_index:
			_reset()
			
	elif event is InputEventScreenDrag:
		if event.index == touch_index and is_pressed:
			_handle_motion(event.position)

func _handle_motion(pos: Vector2) -> void:
	var diff = pos - center_pos
	var dist = diff.length()
	if dist > max_radius:
		diff = diff.normalized() * max_radius
	current_pos = center_pos + diff
	
	var norm = diff / max_radius
	if norm.length() < deadzone:
		output = Vector2.ZERO
	else:
		output = norm
	_update_knob()
	joystick_updated.emit(output)

func _reset() -> void:
	is_pressed = false
	touch_index = -1
	output = Vector2.ZERO
	current_pos = center_pos
	_update_knob()
	joystick_updated.emit(Vector2.ZERO)

func _update_knob() -> void:
	if knob:
		knob.global_position = current_pos - knob.size / 2.0
