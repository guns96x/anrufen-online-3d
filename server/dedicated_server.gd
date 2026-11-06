extends Node

## Headless dedicated server: hosts the shared world without a local player.
## Godot_v4.7.2-stable_win64_console.exe --headless --path . res://server/dedicated_server.tscn -- --port 7777
## Saves accounts and the world to user://dedicated/lan_server_v1.json (atomic
## tmp/bak), apart from the file tests and the in-game host use.

var _status_timer: float = 0.0

func _ready() -> void:
	var port: int = NetworkManager.DEFAULT_PORT
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--port")
	if at >= 0 and at + 1 < args.size():
		port = int(args[at + 1])
	NetworkManager.notice.connect(func(text: String) -> void: _log(text))
	NetworkManager.player_joined.connect(func(peer: int, data: Dictionary) -> void: _log("Увійшов гравець %d: %s" % [peer, str(data.get("name", ""))]))
	NetworkManager.player_left.connect(func(peer: int) -> void: _log("Вийшов гравець %d" % peer))
	Engine.max_fps = 60
	_use_own_save()
	if not NetworkManager.start_dedicated(port):
		_log("Не вдалося запустити сервер на порту %d" % port)
		get_tree().quit(1)
		return
	_log("Сервер Covenant Chronicles працює. Порт %d, дані: %s" % [port, ProjectSettings.globalize_path(NetworkManager.server_state_path)])

## The live server keeps its accounts in its own folder, so test runs and a
## host started from the game can never touch real players. The first start
## moves the old shared file over.
func _use_own_save() -> void:
	DirAccess.make_dir_recursive_absolute("user://dedicated")
	var target: String = "user://dedicated/lan_server_v1.json"
	if not FileAccess.file_exists(target) and FileAccess.file_exists("user://lan_server_v1.json"):
		DirAccess.copy_absolute(ProjectSettings.globalize_path("user://lan_server_v1.json"), ProjectSettings.globalize_path(target))
		_log("Дані сервера перенесено в %s" % ProjectSettings.globalize_path(target))
	NetworkManager.server_state_path = target

func _process(delta: float) -> void:
	_status_timer += delta
	if _status_timer >= 300.0:
		_status_timer = 0.0
		var online: int = 0
		for entry: Variant in NetworkManager.players.values():
			online += 1
		_log("Онлайн: %d" % online)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if NetworkManager.is_server and NetworkManager.has_method("_persist"):
			NetworkManager._persist()

func _log(text: String) -> void:
	print("[%s] %s" % [Time.get_datetime_string_from_system(false, true), text])
