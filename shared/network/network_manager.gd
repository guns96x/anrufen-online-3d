extends Node

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 64

signal player_joined(peer_id: int, player_data: Dictionary)
signal player_left(peer_id: int)
signal connected_ok()
signal connection_err()

var players: Dictionary = {}
var is_server: bool = false
var local_player_data: Dictionary = {
	"name": "Novice Hero",
	"class_id": 130001, # Novice Warrior
	"level": 1,
	"hp": 100,
	"max_hp": 100,
	"mp": 50,
	"max_mp": 50,
	"attack": 18,
	"defense": 8,
	"crit_rate": 0.12,
	"accuracy": 0.95,
	"evasion": 0.05,
	"element": 1 # PHY
}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_fail)

func start_server(port: int = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("[Network] Failed to start server on port %d: %s" % [port, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_server = true
	print("[Network] Authoritative Dedicated Server started on port %d" % port)
	return true

func start_client(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("[Network] Failed to connect to %s:%d: %s" % [ip, port, err])
		return false
	multiplayer.multiplayer_peer = peer
	is_server = false
	print("[Network] Connecting to server at %s:%d..." % [ip, port])
	return true

func _on_peer_connected(id: int) -> void:
	print("[Network] Peer connected: %d" % id)
	if is_server:
		# Server registers player
		rpc_id(id, "sync_world_state", players)

func _on_peer_disconnected(id: int) -> void:
	print("[Network] Peer disconnected: %d" % id)
	if players.has(id):
		players.erase(id)
		player_left.emit(id)
		if is_server:
			rpc("notify_player_left", id)

func _on_connected_ok() -> void:
	print("[Network] Successfully connected to game server!")
	var my_id = multiplayer.get_unique_id()
	rpc_id(1, "register_player", my_id, local_player_data)
	connected_ok.emit()

func _on_connection_fail() -> void:
	push_error("[Network] Connection to server failed!")
	connection_err.emit()

@rpc("any_peer", "call_local", "reliable")
func register_player(peer_id: int, pdata: Dictionary) -> void:
	if not is_server:
		return
	players[peer_id] = pdata
	print("[Server] Registered player %d: %s" % [peer_id, pdata.get("name", "Unknown")])
	rpc("notify_player_joined", peer_id, pdata)

@rpc("authority", "call_local", "reliable")
func notify_player_joined(peer_id: int, pdata: Dictionary) -> void:
	players[peer_id] = pdata
	player_joined.emit(peer_id, pdata)

@rpc("authority", "call_local", "reliable")
func notify_player_left(peer_id: int) -> void:
	if players.has(peer_id):
		players.erase(peer_id)
		player_left.emit(peer_id)

@rpc("authority", "call_local", "reliable")
func sync_world_state(current_players: Dictionary) -> void:
	for pid in current_players:
		players[pid] = current_players[pid]
		player_joined.emit(pid, current_players[pid])
