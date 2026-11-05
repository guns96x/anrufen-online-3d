class_name SettingsStore
extends Node

signal changed(key: String, value: Variant)

const DEFAULTS: Dictionary = {
	"master_volume": 0.85, "music_volume": 0.6, "effects_volume": 0.8,
	"quality": "medium", "fps_limit": 60, "camera_sensitivity": 1.0,
	"invert_camera_y": false, "joystick_opacity": 0.65,
	"auto_loot": true, "auto_potion": false, "potion_threshold": 0.3,
	"auto_mp":false,"mp_potion_threshold":0.3,
	"auto_pet_hp":false,"pet_hp_potion_threshold":0.3,"auto_pet_mp":false,"pet_mp_potion_threshold":0.3,
	"loot_equipment": true, "loot_supplies": true, "loot_materials": true,
	"show_damage": true, "show_names": true, "pk_mode": "peaceful",
}
const KEYS: Dictionary = {
	"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
	"move_right": KEY_D, "attack": KEY_SPACE, "fire": KEY_1,
	"slot_2": KEY_2, "slot_3": KEY_3, "slot_4": KEY_4,
	"dash": KEY_SHIFT, "interact": KEY_E, "bag": KEY_B,
	"character": KEY_C, "skills": KEY_N, "journal": KEY_TAB,
	"map": KEY_M, "menu": KEY_ESCAPE,
}
var values: Dictionary = DEFAULTS.duplicate(true)
var bindings: Dictionary = KEYS.duplicate(true)
var config_path: String = "user://settings.cfg"
var persistence_enabled: bool = true

static func current() -> SettingsStore:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameSettings") as SettingsStore

func _ready() -> void:
	persistence_enabled = not ("--test-mode" in OS.get_cmdline_user_args() or "--review" in OS.get_cmdline_user_args())
	if persistence_enabled:
		load_settings()
	_setup_buses()
	_apply_bindings()
	apply_all()

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> bool:
	if not DEFAULTS.has(key) or not _valid(key, value):
		return false
	values[key] = value
	apply_all()
	if persistence_enabled:
		save_settings()
	changed.emit(key, value)
	return true

func _valid(key: String, value: Variant) -> bool:
	match key:
		"master_volume", "music_volume", "effects_volume", "joystick_opacity", "potion_threshold", "mp_potion_threshold", "pet_hp_potion_threshold", "pet_mp_potion_threshold":
			return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= 1.0
		"camera_sensitivity":
			return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.2 and float(value) <= 3.0
		"quality":
			return value in ["low", "medium", "high"]
		"fps_limit":
			return value in [30, 60, 120]
		"pk_mode":
			return value in ["peaceful", "party", "guild", "free"]
	return typeof(value) == TYPE_BOOL

func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	bindings = KEYS.duplicate(true)
	_apply_bindings()
	apply_all()
	if persistence_enabled:
		save_settings()
	changed.emit("reset", true)

func set_binding(action: String, key: int) -> bool:
	if not KEYS.has(action) or key < 32 or key == KEY_NONE:
		return false
	# Do not allow a new binding to shadow another action silently.
	for other: String in bindings:
		if other != action and int(bindings[other]) == key:
			return false
	bindings[action] = key
	_apply_bindings()
	if persistence_enabled:
		save_settings()
	changed.emit("bindings", action)
	return true

func _apply_bindings() -> void:
	for action: String in bindings:
		var name_key: String = "game_" + action
		if not InputMap.has_action(name_key):
			InputMap.add_action(name_key)
		InputMap.action_erase_events(name_key)
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = int(bindings[action])
		InputMap.action_add_event(name_key, event)

func _setup_buses() -> void:
	for bus: String in ["Music", "Effects"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")

func apply_all() -> void:
	for entry: Array in [["Master", "master_volume"], ["Music", "music_volume"], ["Effects", "effects_volume"]]:
		var index: int = AudioServer.get_bus_index(entry[0])
		if index >= 0:
			var volume: float = float(values[entry[1]])
			AudioServer.set_bus_mute(index, volume <= 0.0)
			AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))
	Engine.max_fps = int(values["fps_limit"])
	if not is_inside_tree():
		return
	var viewport: Viewport = get_viewport()
	viewport.scaling_3d_scale = {"low": 0.65, "medium": 0.85, "high": 1.0}[values["quality"]]
	viewport.msaa_3d = Viewport.MSAA_DISABLED if values["quality"] == "low" else Viewport.MSAA_2X
	var scene: Node = get_tree().current_scene
	if scene:
		var sun: DirectionalLight3D = scene.get_node_or_null("DirectionalLight3D")
		if sun:
			sun.shadow_enabled = values["quality"] != "low"
		for label: Node in scene.find_children("*", "Label3D", true, false):
			if label.name == "NameLabel":
				label.visible = bool(values["show_names"])

func save_settings() -> bool:
	var file: ConfigFile = ConfigFile.new()
	for key: String in values:
		file.set_value("settings", key, values[key])
	for key: String in bindings:
		file.set_value("keys", key, bindings[key])
	return file.save(config_path) == OK

func load_settings() -> bool:
	var file: ConfigFile = ConfigFile.new()
	if file.load(config_path) != OK:
		return false
	for key: String in DEFAULTS:
		var value: Variant = file.get_value("settings", key, DEFAULTS[key])
		if _valid(key, value):
			values[key] = value
	var loaded: Dictionary = KEYS.duplicate(true)
	for key: String in KEYS:
		var value: Variant = file.get_value("keys", key, KEYS[key])
		if value is int and value >= 32 and value != KEY_NONE:
			loaded[key] = value
	var unique: Array = []
	for value: Variant in loaded.values():
		if value in unique:
			return true
		unique.append(value)
	bindings = loaded
	return true
