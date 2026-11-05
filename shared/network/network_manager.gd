extends Node

const DEFAULT_PORT: int = 7777
const MAX_PLAYERS: int = 64
const SocialModel = preload("res://server/social_state.gd")
signal player_joined(peer_id: int, player_data: Dictionary)
signal player_left(peer_id: int)
signal connected_ok()
signal connection_err()
signal state_updated(snapshot: Dictionary)
signal notice(text: String)
signal world_updated(snapshot: Dictionary)
signal world_event(event: Dictionary)

var players: Dictionary = {}
var is_server: bool = false
var local_player_data: Dictionary = {"name":"Мандрівник"}
var social_snapshot: Dictionary = {}
var _server_state: SocialModel
var _rates: Dictionary = {}
var _connecting: bool = false
var persistence_enabled: bool = true
var identity_path: String = "user://lan_identity.token"
var server_state_path: String = "user://lan_server_v1.json"
var _identity: String = ""
var _store: SessionStore
var _registry: Dictionary = {}
var _next_account: int = 1
var _peer_accounts: Dictionary = {}
var _account_peers: Dictionary = {}
var world_enabled: bool = true
var world_snapshot: Dictionary = {}
var simulation: WorldSimulation
var _sessions: Dictionary = {}
var _world_timer: float = 0.0
var _checkpoint_timer: float = 0.0
var _world_frozen: bool = false
var _loots: Dictionary = {}
var _next_loot: int = 1

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	persistence_enabled = not ("--test-mode" in args or "--transport-host" in args or "--transport-client" in args or "--review" in args)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connection_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## Dedicated mode: the process only hosts; peer 1 is not admitted as a player.
var dedicated: bool = false

func start_dedicated(port: int = DEFAULT_PORT) -> bool:
	dedicated = true
	return start_server(port)

func start_server(port: int = DEFAULT_PORT) -> bool:
	if port < 1 or port > 65535:
		return false
	disconnect_session(false)
	var token: String = _identity_token()
	if token.is_empty():
		return false
	_store = SessionStore.new()
	_store.path = server_state_path
	_server_state = SocialModel.new()
	_registry = {}
	_next_account = 1
	if persistence_enabled:
		var loaded: Dictionary = _store.load_state()
		if _store.blocked:
			notice.emit("Сховище сервера пошкоджене. Оригінал захищено.")
			return false
		if not loaded.is_empty():
			var legacy_profiles: bool = false
			var legacy_quests: bool = false
			for account: Dictionary in loaded["state"]["players"].values():
				legacy_profiles = legacy_profiles or not account["profile"].has("free_starter_skill")
				legacy_quests = legacy_quests or (account.has("journal") and not account["journal"].has("quest_revision"))
			if legacy_quests and not FileAccess.file_exists(server_state_path+".pre-v6"):
				var backup_source: String = server_state_path if FileAccess.file_exists(server_state_path) else server_state_path+".bak"
				if DirAccess.copy_absolute(backup_source,server_state_path+".pre-v6") != OK:
					notice.emit("Не вдалося захистити попередній журнал сервера.")
					return false
			if legacy_profiles and not FileAccess.file_exists(server_state_path+".pre-v5"):
				var backup_source: String = server_state_path if FileAccess.file_exists(server_state_path) else server_state_path+".bak"
				if DirAccess.copy_absolute(backup_source,server_state_path+".pre-v5") != OK:
					notice.emit("Не вдалося захистити попереднє серверне збереження.")
					return false
			_registry = loaded["registry"]
			_next_account = int(loaded["next_account"])
			_server_state.restore_state(loaded["state"])
	if world_enabled:
		simulation = WorldSimulation.new()
		simulation.bind_social(_server_state)
		simulation.monster_defeated.connect(_monster_reward)
		simulation.combat_event.connect(_combat_event)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_server(port,MAX_PLAYERS)
	if error != OK:
		notice.emit("Не вдалося запустити сервер: " + error_string(error))
		return false
	multiplayer.multiplayer_peer = peer
	is_server = true
	if not dedicated and not _admit(1,_safe_name(local_player_data.get("name"),1),token):
		disconnect_session(false)
		return false
	_broadcast()
	connected_ok.emit()
	notice.emit("Сервер відкрито, порт %d. Мережеві персонажі зберігаються окремо." % port)
	return true

func start_client(ip: String = "127.0.0.1", port: int = DEFAULT_PORT) -> bool:
	if ip.strip_edges().is_empty() or ip.length() > 255 or port < 1 or port > 65535:
		return false
	disconnect_session(false)
	if _identity_token().is_empty():
		return false
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error: Error = peer.create_client(ip.strip_edges(),port)
	if error != OK:
		notice.emit("Не вдалося під'єднатися: " + error_string(error))
		return false
	multiplayer.multiplayer_peer = peer
	_connecting = true
	return true

func disconnect_session(announce: bool = true) -> void:
	var had_session: bool = not social_snapshot.is_empty() or _connecting or is_server
	if is_server and _server_state != null:
		_persist()
	is_server = false
	_connecting = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_server_state = null
	for session: Node in _sessions.values():
		session.queue_free()
	_sessions.clear()
	simulation = null
	world_snapshot.clear()
	_loots.clear()
	_world_frozen = false
	_rates.clear()
	_peer_accounts.clear()
	_account_peers.clear()
	players.clear()
	social_snapshot.clear()
	state_updated.emit({})
	world_updated.emit({})
	if announce and had_session:
		notice.emit("Сеанс завершено. Локальний персонаж не змінений.")

func request(action: String, payload: Dictionary = {}) -> void:
	if is_server and _server_state != null:
		_handle_request(1,action,payload)
	elif not _connecting and not social_snapshot.is_empty() and multiplayer.multiplayer_peer != null:
		rpc_id(1,"_server_request",action,payload)
	else:
		notice.emit("Спочатку під'єднайся до LAN-сеансу.")

func _safe_name(value: Variant, peer: int) -> String:
	if value is String and SocialModel._name(value):
		return value.strip_edges()
	return "Гравець %d" % peer

func _on_peer_connected(_peer: int) -> void:
	# The new transport connection has no profile until its name-only admission.
	pass

func _on_peer_disconnected(peer: int) -> void:
	_rates.erase(peer)
	if is_server and _server_state != null and _peer_accounts.has(peer):
		var account: int = int(_peer_accounts[peer])
		_remove_session(account)
		_server_state.detach(account)
		_peer_accounts.erase(peer)
		_account_peers.erase(account)
		_persist()
		_broadcast()

func _on_connected_ok() -> void:
	_connecting = false
	rpc_id(1,"_server_join",_safe_name(local_player_data.get("name"),multiplayer.get_unique_id()),_identity_token())
	connected_ok.emit()

func _on_connection_fail() -> void:
	disconnect_session(false)
	connection_err.emit()
	notice.emit("З'єднання не встановлено. Перевір адресу, порт і Tailscale.")

func _on_server_disconnected() -> void:
	disconnect_session(false)
	notice.emit("Сервер завершив сеанс. Незавершений обмін скасовано.")

func _allow_request(peer: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var rate: Dictionary = _rates.get(peer,{"start":now,"count":0})
	if now - int(rate["start"]) >= 1000:
		rate = {"start":now,"count":0}
	rate["count"] = int(rate["count"]) + 1
	_rates[peer] = rate
	return int(rate["count"]) <= 20

@rpc("any_peer","call_remote","reliable")
func _server_join(name: Variant, token: Variant = "") -> void:
	if not is_server or _server_state == null:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not _allow_request(sender) or not SessionStore.token_valid(token):
		return
	if _admit(sender,_safe_name(name,sender),str(token)):
		_broadcast()

@rpc("any_peer","call_remote","reliable")
func _server_request(action: Variant, payload: Variant) -> void:
	if not is_server or _server_state == null:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender <= 1 or not action is String or not payload is Dictionary:
		return
	_handle_request(sender,action,payload)

func _handle_request(sender: int, action: String, payload: Dictionary) -> void:
	if not _allow_request(sender):
		_send_notice(sender,"Забагато запитів. Зачекай секунду.")
		return
	# The server supplies sender identity and owns all online money/items.
	if action.length() > 40 or var_to_bytes(payload).size() > 8192:
		_send_notice(sender,"Запит перевищує дозволений розмір.")
		return
	if not _peer_accounts.has(sender):
		return
	var checkpoint: Dictionary = _server_state.checkpoint()
	var account: int = int(_peer_accounts[sender])
	var world_checkpoint: Dictionary = _world_checkpoint()
	var result: Dictionary
	if action.begins_with("game_"):
		if not world_enabled or _world_frozen or not _sessions.has(account):
			_send_notice(sender,"Бойовий світ зараз недоступний.")
			return
		result = _pickup(account,payload) if action == "game_pickup" else _sessions[account].act(action.trim_prefix("game_"),payload)
	else:
		result = _server_state.act(account,action,payload)
	if not result.get("ok",false):
		_send_notice(sender,str(result.get("error","Дію відхилено.")))
		return
	if not _persist():
		_server_state.restore_state(checkpoint)
		_restore_world(world_checkpoint)
		_send_notice(sender,"Не вдалося зберегти дію. Предмети й мідь не змінено.")
		return
	if result.get("message") is String and not result["message"].is_empty(): _send_notice(sender,result["message"])
	_broadcast()
	_broadcast_world()

func _send_notice(peer: int, message: String) -> void:
	if peer == 1:
		notice.emit(message)
	elif peer in multiplayer.get_peers():
		rpc_id(peer,"_receive_notice",message)

func _broadcast() -> void:
	if not is_server or _server_state == null:
		return
	for peer: int in _peer_accounts:
		var snapshot: Dictionary = _server_state.snapshot_for(int(_peer_accounts[peer]))
		snapshot["world_enabled"] = world_enabled
		snapshot["journal"] = _server_state.players[int(_peer_accounts[peer])].get("journal",{}).duplicate(true)
		if peer == 1:
			_apply_snapshot(snapshot)
		elif peer in multiplayer.get_peers():
			rpc_id(peer,"_receive_snapshot",snapshot)

@rpc("authority","call_remote","reliable")
func _receive_snapshot(snapshot: Dictionary) -> void:
	if is_server or multiplayer.get_remote_sender_id() != 1:
		return
	_apply_snapshot(snapshot)

@rpc("authority","call_remote","reliable")
func _receive_notice(message: String) -> void:
	if not is_server and multiplayer.get_remote_sender_id() == 1:
		notice.emit(message)

func _apply_snapshot(snapshot: Dictionary) -> void:
	var next_players: Dictionary = {}
	for row: Dictionary in snapshot.get("onlineplayers",[]):
		next_players[int(row["id"])] = row.duplicate(true)
	for id: int in next_players:
		if not players.has(id):
			player_joined.emit(id,next_players[id])
	for id: int in players:
		if not next_players.has(id):
			player_left.emit(id)
	players = next_players
	social_snapshot = snapshot.duplicate(true)
	state_updated.emit(social_snapshot)

func _identity_token() -> String:
	if not _identity.is_empty():
		return _identity
	if persistence_enabled and FileAccess.file_exists(identity_path):
		var token: String = FileAccess.get_file_as_string(identity_path).strip_edges()
		if not SessionStore.token_valid(token):
			notice.emit("Файл мережевого персонажа пошкоджено. Оригінал збережено.")
			return ""
		_identity = token
		return token
	var token: String = Crypto.new().generate_random_bytes(32).hex_encode()
	if persistence_enabled:
		var file: FileAccess = FileAccess.open(identity_path,FileAccess.WRITE)
		if file == null:
			notice.emit("Не вдалося зберегти мережевого персонажа.")
			return ""
		file.store_string(token)
		file.close()
	_identity = token
	return token

func _admit(peer: int, name: String, token: String) -> bool:
	if _peer_accounts.has(peer) or not SessionStore.token_valid(token):
		return false
	var hash_key: String = token.sha256_text()
	var checkpoint: Dictionary = _server_state.checkpoint()
	var previous_registry: Dictionary = _registry.duplicate(true)
	var previous_counter: int = _next_account
	var account: int = int(_registry.get(hash_key,0))
	if account == 0:
		account = _next_account
		if not _server_state.join(account,name):
			_send_notice(peer,"Сервер не може прийняти нового персонажа.")
			return false
		_next_account += 1
		_registry[hash_key] = account
	elif not _server_state.reconnect(account,name):
		_send_notice(peer,"Цей мережевий персонаж уже підключений.")
		return false
	if world_enabled:
		_add_session(account)
	if not _persist():
		_remove_session(account)
		_server_state.restore_state(checkpoint)
		_registry = previous_registry
		_next_account = previous_counter
		_send_notice(peer,"Не вдалося зберегти мережевого персонажа.")
		return false
	_peer_accounts[peer] = account
	_account_peers[account] = peer
	call_deferred("_broadcast_world")
	return true

func _persist() -> bool:
	for session: ServerGameSession in _sessions.values():
		session.sync()
	return not persistence_enabled or (_store != null and _store.commit(_server_state,_registry,_next_account))

func _add_session(account: int) -> void:
	var session: ServerGameSession = ServerGameSession.new()
	add_child(session)
	session.bind_account(account,_server_state,simulation)
	_sessions[account] = session
	simulation.add_actor(account)

func _remove_session(account: int) -> void:
	if _sessions.has(account):
		_sessions[account].sync()
		_sessions[account].queue_free()
		_sessions.erase(account)
	if simulation:
		simulation.remove_actor(account)

func _physics_process(delta: float) -> void:
	if not is_server or simulation == null or _world_frozen:
		return
	simulation.tick(delta)
	for session: ServerGameSession in _sessions.values():
		if session.actor.stats.get("mounted",false) and MountSystem.seconds_left(session.actor.stats,int(session.actor.stats.get("mount_id",0))) <= 0.0:
			MountSystem.dismount(session.actor.stats)
		ItemEffects.tick(session.actor.stats,delta)
		session.pets.tick(delta)
		session.sync()
		session.tick_pet(delta)
	for id: int in _loots.keys():
		_loots[id]["remaining"] -= delta
		if float(_loots[id]["remaining"]) <= 0.0:
			_loots.erase(id)
	_world_timer += delta
	_checkpoint_timer += delta
	if _world_timer >= 0.1:
		_world_timer = 0.0
		_broadcast_world()
	if _checkpoint_timer >= 2.0:
		_checkpoint_timer = 0.0
		if not _persist():
			_world_frozen = true
			for peer: int in _peer_accounts:
				_send_notice(peer,"Запис сервера недоступний. Світ призупинено до відновлення сховища.")

func send_world_input(direction: Vector2, yaw: float) -> void:
	if is_server and simulation and _peer_accounts.has(1):
		simulation.set_input(int(_peer_accounts[1]),direction,yaw)
	elif not world_snapshot.is_empty() and multiplayer.multiplayer_peer != null:
		rpc_id(1,"_server_input",direction,yaw)

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _server_input(direction: Vector2, yaw: float) -> void:
	if not is_server or simulation == null or _world_frozen:
		return
	var peer: int = multiplayer.get_remote_sender_id()
	if _peer_accounts.has(peer):
		simulation.set_input(int(_peer_accounts[peer]),direction,yaw)

func _broadcast_world() -> void:
	if not is_server or simulation == null:
		return
	var state: Dictionary = simulation.public_snapshot()
	for id: int in _sessions:
		if state["actors"].has(id):
			state["actors"][id]["pet"] = _sessions[id].pet_snapshot()
	state["loot"] = _loots.duplicate(true)
	for peer: int in _peer_accounts:
		var id: int = int(_peer_accounts[peer])
		var packet: Dictionary = {"own_id":id,"state":state,"profile":_server_state.players[id]["profile"].duplicate(true),"journal":_server_state.players[id].get("journal",{}).duplicate(true)}
		if peer == 1:
			_apply_world(packet)
		elif peer in multiplayer.get_peers():
			rpc_id(peer,"_receive_world",packet)

@rpc("authority","call_remote","unreliable_ordered",2)
func _receive_world(packet: Dictionary) -> void:
	if not is_server and multiplayer.get_remote_sender_id() == 1:
		_apply_world(packet)

func _apply_world(packet: Dictionary) -> void:
	world_snapshot = packet.duplicate(true)
	world_updated.emit(world_snapshot)

func _combat_event(event: Dictionary) -> void:
	if event.get("type") == "death" and int(event.get("attacker",0)) > 0 and int(event.get("target",0)) > 0 and _server_state != null:
		_server_state.record_player_defeat(int(event["attacker"]),int(event["target"]),bool(event.get("duel",false)))
	world_event.emit(event)
	for peer: int in _peer_accounts:
		if peer != 1 and peer in multiplayer.get_peers():
			rpc_id(peer,"_receive_world_event",event)

@rpc("authority","call_remote","reliable")
func _receive_world_event(event: Dictionary) -> void:
	if not is_server and multiplayer.get_remote_sender_id() == 1:
		world_event.emit(event)

func _monster_reward(account: int, key: String) -> void:
	if not _sessions.has(account) or not simulation.monsters.has(key):
		return
	var monster: Dictionary = simulation.monsters[key]
	var session: ServerGameSession = _sessions[account]
	var xp: int = int(monster.get("exp", float(monster["max_hp"]) * 0.5 + float(monster["attack_damage"]) * 1.5))
	session.actor.gain_exp(xp)
	session.progression.add_monster_kill(int(monster["monster_id"]))
	var uid: String = str(session.actor.stats.get("summoned_pet",""))
	if not uid.is_empty():
		session.pets.gain_exp(uid,maxi(1,xp/3))
	var contents: Dictionary = {"30037":1} if int(monster["monster_id"]) == 70073 else {"30016":1} if randf() < 0.3 else {}
	if int(monster["monster_id"]) == 70076: contents = {"30038":1}
	_loots[_next_loot] = {"id":_next_loot,"owner":account,"position":monster["position"],"remaining":120.0,"copper":4 if int(monster["monster_id"]) == 70071 else 2,"contents":contents}
	_next_loot += 1
	session.sync()

func _pickup(account: int, payload: Dictionary) -> Dictionary:
	if not SocialState._integer(payload.get("id"),1,2147483647) or not _loots.has(int(payload["id"])):
		return {"ok":false,"error":"Здобич недоступна."}
	var id: int = int(payload["id"])
	var loot: Dictionary = _loots[id]
	var session: ServerGameSession = _sessions[account]
	if int(loot["owner"]) != account or not simulation.actors.has(account) or simulation.actors[account]["dead"] or simulation.actors[account]["position"].distance_to(loot["position"]) > 3.0:
		return {"ok":false,"error":"Здобич надто далеко або належить іншому гравцю."}
	var stats: Dictionary = session.actor.stats
	var allowed: Variant = payload.get("kinds",[])
	if not allowed is Array or allowed.size() > 12:
		return {"ok":false,"error":"Некоректний фільтр здобичі."}
	var gained: bool = false
	if int(stats["copper"]) + int(loot["copper"]) <= 1000000000 and int(loot["copper"]) > 0:
		stats["copper"] += int(loot["copper"])
		loot["copper"] = 0
		gained = true
	for key: String in loot["contents"].keys():
		if not allowed.is_empty() and ItemCatalog.get_item(int(key)).get("kind","") not in allowed:
			continue
		if session.items.add_item(int(key),int(loot["contents"][key])):
			loot["contents"].erase(key)
			gained = true
	if loot["contents"].is_empty() and int(loot["copper"]) == 0:
		_loots.erase(id)
	return {"ok":gained,"error":"" if gained else "Немає місця для цієї здобичі."}

func _world_checkpoint() -> Dictionary:
	return {} if simulation == null else {"actors":simulation.actors.duplicate(true),"monsters":simulation.monsters.duplicate(true),"duels":simulation.duels.duplicate(true),"duel_requests":simulation.duel_requests.duplicate(true),"forage":simulation.forage.ready_at.duplicate(),"loot":_loots.duplicate(true),"next_loot":_next_loot}

func _restore_world(data: Dictionary) -> void:
	if simulation == null or data.is_empty():
		return
	simulation.actors = data["actors"]
	simulation.monsters = data["monsters"]
	simulation.duels = data["duels"]
	simulation.duel_requests = data["duel_requests"]
	simulation.forage.ready_at = data.get("forage",{})
	_loots = data["loot"]
	_next_loot = data["next_loot"]
	for id: int in _sessions:
		_sessions[id].bind_account(id,_server_state,simulation)
