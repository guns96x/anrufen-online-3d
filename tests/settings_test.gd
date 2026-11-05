extends SceneTree
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var settings: SettingsStore = SettingsStore.new()
	settings.persistence_enabled = false
	settings.config_path = "res://build/settings-test.cfg"
	check(settings.set_value("music_volume",0.0),"music mute accepted")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),"music bus actually muted")
	check(not settings.set_value("master_volume",2.0),"invalid volume rejected")
	check(not settings.set_value("camera_sensitivity",NAN),"NaN setting rejected")
	check(not settings.set_value("quality","ultra-fake"),"invalid quality rejected")
	check(settings.set_value("camera_sensitivity",1.7),"camera sensitivity changes")
	check(not settings.set_binding("attack",KEY_W),"conflicting binding rejected")
	check(settings.set_binding("attack",KEY_F),"attack key remapped")
	var key: InputEventKey = InputMap.action_get_events("game_attack")[0]
	check(key.physical_keycode == KEY_F,"InputMap uses remapped attack")
	check(settings.save_settings(),"settings saved to disk")
	var loaded: SettingsStore = SettingsStore.new()
	loaded.config_path = settings.config_path
	check(loaded.load_settings(),"settings loaded")
	check(loaded.bindings["attack"] == KEY_F and is_equal_approx(float(loaded.values["camera_sensitivity"]),1.7),"keys and options survive restart")
	loaded.persistence_enabled = false
	loaded.reset_defaults()
	check(loaded.bindings["attack"] == KEY_SPACE and loaded.values["music_volume"] == 0.6,"restore defaults resets keys and values")
	settings.free()
	loaded.free()
	DirAccess.remove_absolute("res://build/settings-test.cfg")
	SettingsStore.current().reset_defaults()
	print("SETTINGS_SUITE: ","PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
