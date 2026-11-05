class_name SessionStore
extends RefCounted

var path: String = "user://lan_server_v1.json"
var error: String = ""
var blocked: bool = false

static func token_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for i: int in value.length():
		if value.substr(i,1) not in "0123456789abcdef":
			return false
	return true

static func _int(value: Variant, low: int = 0, high: int = 2147483647) -> bool:
	return SocialState._integer(value,low,high)

func _map(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		error = "Некоректна таблиця сервера."
		return result
	for key: Variant in value:
		if not key is String or not key.is_valid_int() or str(int(key)) != key or int(key) <= 0 or not value[key] is Dictionary:
			error = "Некоректний ідентифікатор у сховищі."
			return {}
		result[int(key)] = value[key].duplicate(true)
	return result

func _ids(value: Variant, players: Dictionary, cap: int = 1000) -> bool:
	if not value is Array or value.size() > cap:
		return false
	var seen: Array[int] = []
	for id: Variant in value:
		if not _int(id,1) or not players.has(int(id)) or int(id) in seen:
			return false
		seen.append(int(id))
	return true

func _normalize_ids(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values:
		result.append(int(value))
	return result

func normalize(value: Variant) -> Dictionary:
	error = ""
	if not value is Dictionary or not _int(value.get("version"),1,1) or not value.get("registry") is Dictionary or not value.get("state") is Dictionary or not _int(value.get("next_account"),1):
		error = "Невідома версія або схема сховища."
		return {}
	var raw: Dictionary = value["state"]
	var state: Dictionary = {}
	for key: String in ["players","parties","guilds","mails","listings","bounties"]:
		state[key] = _map(raw.get(key,{}))
		if not error.is_empty():
			return {}
	var players: Dictionary = state["players"]
	if players.size() > 1000 or state["parties"].size() > 1000 or state["guilds"].size() > 1000 or state["mails"].size() > 5000:
		error = "Перевищено місткість сховища."
		return {}
	var registry: Dictionary = {}
	var seen: Array[int] = []
	for hash_key: Variant in value["registry"]:
		var id: Variant = value["registry"][hash_key]
		if not token_valid(hash_key) or not _int(id,1) or not players.has(int(id)) or int(id) in seen:
			error = "Некоректний реєстр персонажів."
			return {}
		registry[hash_key] = int(id)
		seen.append(int(id))
	if registry.size() != players.size() or (not seen.is_empty() and int(value["next_account"]) <= seen.max()):
		error = "Реєстр персонажів не узгоджено зі сховищем."
		return {}
	var validator: InventorySystem = InventorySystem.new()
	for id: int in players:
		var account: Dictionary = players[id]
		if not _int(account.get("id"),id,id) or not SocialState._name(account.get("name")) or not account.get("profile") is Dictionary:
			error = "Некоректний профіль."
			return {}
		var profile: Dictionary = account["profile"]
		ProfileCodec.normalize(profile)
		if account.has("journal"):
			if not account["journal"] is Dictionary:
				error = "Некоректний журнал персонажа."
				return {}
			var progression: ProgressionController = ProgressionController.new()
			var envelope: Dictionary = account["journal"].duplicate(true)
			envelope["version"] = ProgressionController.SAVE_VERSION
			envelope["player_stats"] = profile
			var valid: bool = progression.validate_save_data(envelope)
			progression.free()
			if not valid:
				error = "Некоректний бойовий профіль або журнал."
				return {}
		var copy: Dictionary = profile.duplicate(true)
		copy["equipment"] = {}
		if not validator.validate_state(copy) or not _int(profile.get("level"),1,100) or not _int(profile.get("max_hp"),1,1000000) or not _int(profile.get("hp"),0,int(profile["max_hp"])):
			error = "Некоректна економіка персонажа."
			return {}
		for field: String in ["friends","requests","blocked"]:
			if not _ids(account.get(field),players) or id in account[field]:
				error = "Некоректні контакти."
				return {}
			account[field] = _normalize_ids(account[field])
		for field: String in ["party","guild"]:
			if not _int(account.get(field)):
				error = "Некоректне членство."
				return {}
		account["id"] = id
		account["party"] = int(account["party"])
		account["guild"] = int(account["guild"])
		account["online"] = false
		for field: String in ["copper","level","hp","max_hp","bag_capacity"]:
			profile[field] = int(profile[field])
		for key: String in profile["inventory"]:
			profile["inventory"][key] = int(profile["inventory"][key])
	for field: String in ["party","guild"]:
		var groups: Dictionary = state["parties" if field == "party" else "guilds"]
		for id: int in groups:
			var group: Dictionary = groups[id]
			if field == "guild":
				if not SocialState._text(group.get("declaration",""),0,500):
					error = "Некоректне оголошення гільдії."
					return {}
				group["declaration"] = group.get("declaration","")
			if not _int(group.get("id"),id,id) or not _ids(group.get("members"),players,4 if field == "party" else 20) or group["members"].is_empty() or not _ids(group.get("invites"),players):
				error = "Некоректний склад групи."
				return {}
			group["members"] = _normalize_ids(group["members"])
			group["invites"] = _normalize_ids(group["invites"])
			if not _int(group.get("leader"),1) or int(group["leader"]) not in group["members"] or (field == "guild" and not SocialState._name(group.get("name"))):
				error = "Некоректний лідер."
				return {}
			group["id"] = id
			group["leader"] = int(group["leader"])
			for member: Variant in group["members"]:
				if int(players[int(member)][field]) != id:
					error = "Неузгоджене членство."
					return {}
		for id: int in players:
			var group: int = int(players[id][field])
			if group != 0 and (not groups.has(group) or id not in groups[group]["members"]):
				error = "Неузгоджений профіль учасника."
				return {}
	var largest: int = 0
	for key: String in ["parties","guilds","mails","listings","bounties"]:
		for id: int in state[key]:
			largest = maxi(largest,id)
	if not _validate_bounties(state["bounties"],players):
		return {}
	if state["listings"].size() > 1000:
		error = "Забагато лотів."
		return {}
	for id: int in state["listings"]:
		var listing: Dictionary = state["listings"][id]
		if not _int(listing.get("id"),id,id) or not _int(listing.get("seller"),1) or not players.has(int(listing["seller"])) or not _int(listing.get("item_id"),1,99999999) or not _int(listing.get("price"),1,1000000000) or not _number(listing.get("time")):
			error = "Некоректний лот."
			return {}
		var item: Dictionary = ItemCatalog.get_item(int(listing["item_id"]))
		if item.is_empty() or not _int(listing.get("count"),1,int(item["max_stack"])):
			error = "Некоректний предмет у лоті."
			return {}
		for field: String in ["id","seller","item_id","price","count"]:
			listing[field] = int(listing[field])
	for id: int in state["mails"]:
		var mail: Dictionary = state["mails"][id]
		if not _int(mail.get("id"),id,id) or not _int(mail.get("from"),1) or not players.has(int(mail["from"])) or not _int(mail.get("to"),1) or not players.has(int(mail["to"])) or not SocialState._text(mail.get("subject"),1,60) or not SocialState._text(mail.get("body"),1,1000) or not mail.get("read") is bool:
			error = "Некоректний лист."
			return {}
		mail["id"] = id
		mail["from"] = int(mail["from"])
		mail["to"] = int(mail["to"])
		if not SocialState._name(mail.get("from_name")) or not _number(mail.get("time")):
			error = "Некоректний автор або час листа."
			return {}
	if not raw.get("chat") is Array or raw["chat"].size() > 100:
		error = "Некоректний журнал чату."
		return {}
	state["chat"] = []
	for value_chat: Variant in raw["chat"]:
		if not value_chat is Dictionary:
			error = "Некоректне повідомлення."
			return {}
		var message: Dictionary = value_chat.duplicate(true)
		if not _int(message.get("id"),1) or not _int(message.get("from"),1) or not players.has(int(message["from"])) or not SocialState._name(message.get("name")) or not SocialState._text(message.get("text"),1,300) or message.get("channel") not in ["global","party","guild","whisper"] or not _ids(message.get("recipients"),players) or not _number(message.get("time")):
			error = "Некоректне повідомлення чату."
			return {}
		message["id"] = int(message["id"])
		message["from"] = int(message["from"])
		message["recipients"] = _normalize_ids(message["recipients"])
		largest = maxi(largest,message["id"])
		state["chat"].append(message)
	if not _int(raw.get("next_id"),largest+1):
		error = "Некоректний лічильник операцій."
		return {}
	state["next_id"] = int(raw["next_id"])
	return {"version":1,"registry":registry,"next_account":int(value["next_account"]),"state":state}

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0 and float(value) < 1000000000000.0

func _validate_bounties(bounties: Dictionary, players: Dictionary) -> bool:
	if bounties.size() > 250:
		error = "Забагато записів полювання."
		return false
	var active: int = 0
	var hunters: Array[int] = []
	for id: int in bounties:
		var bounty: Dictionary = bounties[id]
		if not _int(bounty.get("id"),id,id) or not _int(bounty.get("creator"),1) or not _int(bounty.get("target"),1) or not _int(bounty.get("hunter"),0) or not _int(bounty.get("reward"),1,100000000) or not _int(bounty.get("min_level"),1,100) or not _int(bounty.get("required"),1,10) or not _int(bounty.get("kills"),0,10) or not bounty.get("paid") is bool or bounty.get("state") not in ["available","accepted","completed","cancelled"]:
			error = "Некоректне замовлення полювання."
			return false
		for key: String in ["id","creator","target","hunter","reward","min_level","required","kills"]:
			bounty[key] = int(bounty[key])
		if not players.has(bounty["creator"]) or not players.has(bounty["target"]) or bounty["creator"] == bounty["target"]:
			error = "Некоректні учасники полювання."
			return false
		if bounty["state"] in ["available","cancelled"]:
			if bounty["hunter"] != 0 or bounty["kills"] != 0 or bounty["paid"]:
				error = "Некоректний стан вільного замовлення."
				return false
		else:
			if not players.has(bounty["hunter"]) or bounty["hunter"] in [bounty["creator"],bounty["target"]] or bounty["kills"] > bounty["required"] or (bounty["state"] == "completed") != bounty["paid"] or (bounty["state"] == "completed") != (bounty["kills"] == bounty["required"]):
				error = "Неузгоджений прогрес полювання."
				return false
		if bounty["state"] in ["available","accepted"]: active += 1
		if bounty["state"] == "accepted":
			if bounty["hunter"] in hunters:
				error = "Один мисливець має кілька активних замовлень."
				return false
			hunters.append(bounty["hunter"])
	if active > 50:
		error = "Перевищено місткість дошки полювання."
		return false
	return true

func load_state() -> Dictionary:
	error = ""
	var target: String = path
	if not FileAccess.file_exists(target) and FileAccess.file_exists(target+".bak"):
		target += ".bak"
	if not FileAccess.file_exists(target):
		return {}
	var file: FileAccess = FileAccess.open(target,FileAccess.READ)
	if file == null or file.get_length() > 16777216:
		error = "Не вдалося прочитати сховище сервера."
		blocked = true
		return {}
	var parser: JSON = JSON.new()
	var status: Error = parser.parse(file.get_as_text())
	file.close()
	var data: Dictionary = normalize(parser.data if status == OK else null)
	if data.is_empty():
		blocked = true
	return data

func commit(state: SocialState, registry: Dictionary, next_account: int) -> bool:
	if blocked:
		return false
	var data: Dictionary = {"version":1,"registry":registry,"next_account":next_account,"state":state.persistent_state()}
	var json: String = JSON.stringify(data)
	var parser: JSON = JSON.new()
	if parser.parse(json) != OK or normalize(parser.data).is_empty():
		return false
	var file: FileAccess = FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		error = "Не вдалося записати сховище сервера."
		return false
	file.store_string(json)
	file.close()
	var existed: bool = FileAccess.file_exists(path)
	if existed:
		if FileAccess.file_exists(path+".bak"):
			DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak") != OK:
			return false
	var result: Error = DirAccess.rename_absolute(path+".tmp",path)
	if result != OK and existed:
		DirAccess.rename_absolute(path+".bak",path)
	return result == OK
