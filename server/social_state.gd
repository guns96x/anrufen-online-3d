class_name SocialState
extends RefCounted

## Trusted LAN session state. Text/menu features follow original UI evidence;
## capacities/prices are provisional. No offline profile or client currency import.
var players: Dictionary = {}
var parties: Dictionary = {}
var guilds: Dictionary = {}
var mails: Dictionary = {}
var trades: Dictionary = {}
var listings: Dictionary = {}
## UI10038 proves target ID, reward, acceptance level and kill count. These
## bounds are modern provisional limits, not recovered original balance.
var bounties: Dictionary = {}
var chat: Array[Dictionary] = []
var _next_id: int = 1

func _id() -> int:
	var value: int = _next_id
	_next_id += 1
	return value

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

static func _text(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is String or value.strip_edges().length() < minimum or value.length() > maximum:
		return false
	for i: int in value.length():
		if value.unicode_at(i) < 32 and value.unicode_at(i) not in [9,10]:
			return false
	return true

static func _name(value: Variant) -> bool:
	return _text(value,2,24) and not "\n" in value and not "\t" in value

func join(peer: int, name: String) -> bool:
	if peer < 1 or players.has(peer) or players.size() >= 1000 or not _name(name):
		return false
	players[peer] = {"id":peer,"online":true,"name":name.strip_edges(),"profile":{"name":name.strip_edges(),"level":1,"hp":100,"max_hp":100,"copper":100,"inventory":{"30016":3,"30645":2},"bag_capacity":32},"friends":[],"requests":[],"blocked":[],"party":0,"guild":0}
	return true

func reconnect(account: int, name: String) -> bool:
	if not players.has(account) or players[account].get("online",false) or not _name(name):
		return false
	players[account]["online"] = true
	players[account]["name"] = name.strip_edges()
	players[account]["profile"]["name"] = name.strip_edges()
	return true

func detach(account: int) -> void:
	if players.has(account):
		players[account]["online"] = false
		_cancel_trade_for(account)

func leave(peer: int) -> void:
	if not players.has(peer):
		return
	# Hard deletion is refused atomically if target removal would overflow an
	# issuer's refund. detach() remains available and keeps the escrow intact.
	var refunds: Dictionary = {}
	for bounty: Dictionary in bounties.values():
		var creator: int = int(bounty["creator"])
		if int(bounty["target"]) == peer and creator != peer and bounty["state"] in ["available","accepted"]:
			refunds[creator] = int(refunds.get(creator,0)) + int(bounty["reward"])
	for creator: int in refunds:
		if int(players[creator]["profile"]["copper"]) + int(refunds[creator]) > 1000000000:
			return
	_leave_group(peer,parties,"party")
	_leave_group(peer,guilds,"guild")
	_cancel_trade_for(peer)
	_cleanup_bounties_for_deleted_account(peer)
	for data: Dictionary in players.values():
		for field: String in ["friends","requests","blocked"]:
			data[field].erase(peer)
	for group: Dictionary in parties.values():
		group["invites"].erase(peer)
	for group: Dictionary in guilds.values():
		group["invites"].erase(peer)
	for id: Variant in mails.keys():
		if int(mails[id]["to"]) == peer:
			mails.erase(id)
	for id: Variant in listings.keys():
		if int(listings[id]["seller"]) == peer:
			listings.erase(id)
	players.erase(peer)

func _ok() -> Dictionary:
	return {"ok":true,"error":""}

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _pair(a: int, b: int) -> bool:
	return a != b and players.has(a) and players.has(b) and b not in players[a]["blocked"] and a not in players[b]["blocked"]

func _target(payload: Dictionary) -> int:
	return int(payload["target"]) if _integer(payload.get("target"),1,2147483647) else 0

func act(peer: int, action: String, payload: Dictionary = {}) -> Dictionary:
	if not players.has(peer) or not players[peer].get("online",true):
		return _fail("Спочатку приєднайся до сеансу.")
	if action.length() > 40 or payload.size() > 8:
		return _fail("Некоректний запит.")
	var target: int = _target(payload)
	if action in ["party_invite","guild_invite","trade_request"] and (not players.has(target) or not players[target].get("online",true)):
		return _fail("Гравець зараз поза мережею.")
	match action:
		"chat": return _chat(peer,payload)
		"friend_request":
			if not _pair(peer,target) or target in players[peer]["friends"] or peer in players[target]["requests"]:
				return _fail("Запит дружби недоступний.")
			players[target]["requests"].append(peer)
		"friend_accept":
			if not _pair(peer,target) or target not in players[peer]["requests"]:
				return _fail("Немає такого запиту дружби.")
			players[peer]["requests"].erase(target)
			players[target]["requests"].erase(peer)
			players[peer]["friends"].append(target)
			players[target]["friends"].append(peer)
		"friend_remove":
			if not players.has(target) or target not in players[peer]["friends"]:
				return _fail("Гравця немає у друзях.")
			players[peer]["friends"].erase(target)
			players[target]["friends"].erase(peer)
		"block":
			if not players.has(target) or target == peer or target in players[peer]["blocked"]:
				return _fail("Неможливо заблокувати гравця.")
			players[peer]["blocked"].append(target)
			players[peer]["friends"].erase(target)
			players[target]["friends"].erase(peer)
			players[peer]["requests"].erase(target)
			players[target]["requests"].erase(peer)
			var trade: Dictionary = _trade_for(peer)
			if not trade.is_empty() and target in trade["participants"]:
				trades.erase(trade["id"])
		"unblock":
			if target not in players[peer]["blocked"]:
				return _fail("Гравця не заблоковано.")
			players[peer]["blocked"].erase(target)
		"party_invite": return _invite(peer,target,parties,"party")
		"party_accept": return _accept_group(peer,payload.get("party_id"),parties,"party")
		"party_leave":
			if int(players[peer]["party"]) == 0:
				return _fail("Ти не в групі.")
			_leave_group(peer,parties,"party")
		"party_kick": return _kick(peer,target,parties,"party")
		"guild_create":
			var name: Variant = payload.get("name")
			if not _name(name) or int(players[peer]["guild"]) != 0 or int(players[peer]["profile"]["copper"]) < 50:
				return _fail("Створення гільдії коштує 50 міді; назва має 2–24 символи.")
			for guild: Dictionary in guilds.values():
				if str(guild["name"]).to_lower() == str(name).strip_edges().to_lower():
					return _fail("Назву гільдії вже зайнято.")
			var id: int = _id()
			guilds[id] = {"id":id,"name":str(name).strip_edges(),"leader":peer,"members":[peer],"invites":[],"declaration":""}
			players[peer]["guild"] = id
			players[peer]["profile"]["copper"] -= 50
		"guild_invite": return _invite(peer,target,guilds,"guild")
		"guild_accept": return _accept_group(peer,payload.get("guild_id"),guilds,"guild")
		"guild_leave":
			if int(players[peer]["guild"]) == 0:
				return _fail("Ти не в гільдії.")
			_leave_group(peer,guilds,"guild")
		"guild_kick": return _kick(peer,target,guilds,"guild")
		"guild_declaration": return _guild_declaration(peer,payload.get("text"))
		"bounty_create": return _bounty_create(peer,target,payload)
		"bounty_accept": return _bounty_accept(peer,payload.get("bounty_id"))
		"bounty_cancel": return _bounty_cancel(peer,payload.get("bounty_id"))
		"mail_send": return _mail_send(peer,target,payload)
		"mail_read", "mail_delete":
			var id: Variant = payload.get("mail_id")
			if not _integer(id,1,2147483647) or not mails.has(int(id)) or int(mails[int(id)]["to"]) != peer:
				return _fail("Лист недоступний.")
			if action == "mail_delete":
				mails.erase(int(id))
			else:
				mails[int(id)]["read"] = true
		"trade_request": return _trade_request(peer,target)
		"auction_list", "auction_buy", "auction_cancel": return _auction(peer,action,payload)
		"trade_accept", "trade_offer", "trade_confirm", "trade_cancel": return _trade_action(peer,action,payload)
		_:
			return _fail("Невідома дія.")
	return _ok()

func _auction(peer: int, action: String, payload: Dictionary) -> Dictionary:
	var profile: Dictionary = players[peer]["profile"]
	if action == "auction_list":
		var item: Variant = payload.get("id")
		var count: Variant = payload.get("count")
		var price: Variant = payload.get("price")
		if listings.size() >= 1000 or not _integer(item,1,99999999) or not _integer(count,1,99999) or not _integer(price,1,1000000000):
			return _fail("Некоректна пропозиція продажу.")
		var definition: Dictionary = ItemCatalog.get_item(int(item))
		var key: String = str(int(item))
		if definition.is_empty() or _protected(profile,int(item)) or int(count) > int(definition["max_stack"]) or int(profile["inventory"].get(key,0)) < int(count):
			return _fail("Недостатньо предметів для продажу.")
		profile["inventory"][key] -= int(count)
		if int(profile["inventory"][key]) == 0:
			profile["inventory"].erase(key)
		var id: int = _id()
		listings[id] = {"id":id,"seller":peer,"item_id":int(item),"count":int(count),"price":int(price),"time":Time.get_unix_time_from_system()}
		_cancel_trade_for(peer)
		return _ok()
	var id: Variant = payload.get("listing_id")
	if not _integer(id,1,2147483647) or not listings.has(int(id)):
		return _fail("Цей лот уже недоступний.")
	var listing: Dictionary = listings[int(id)]
	var seller: int = int(listing["seller"])
	var key: String = str(listing["item_id"])
	var count: int = int(listing["count"])
	if action == "auction_cancel" and seller != peer:
		return _fail("Скасувати лот може лише продавець.")
	if action == "auction_buy" and (seller == peer or int(profile["copper"]) < int(listing["price"])):
		return _fail("Не можна купити власний лот або бракує міді.")
	var bag: Dictionary = profile["inventory"].duplicate(true)
	bag[key] = int(bag.get(key,0)) + count
	if bag.size() > int(profile["bag_capacity"]) or int(bag[key]) > int(ItemCatalog.get_item(int(key))["max_stack"]):
		return _fail("Звільни місце у сумці.")
	if action == "auction_buy":
		if int(players[seller]["profile"]["copper"]) + int(listing["price"]) > 1000000000:
			return _fail("Продавець не може прийняти оплату.")
		profile["copper"] -= int(listing["price"])
		players[seller]["profile"]["copper"] += int(listing["price"])
	profile["inventory"] = bag
	MountSystem.register_acquisition(profile,int(key))
	listings.erase(int(id))
	_cancel_trade_for(peer)
	_cancel_trade_for(seller)
	return _ok()

func _chat(peer: int, payload: Dictionary) -> Dictionary:
	var text: Variant = payload.get("text")
	var channel: Variant = payload.get("channel","global")
	if not _text(text,1,300) or not channel is String or channel not in ["global","party","guild","whisper"]:
		return _fail("Повідомлення має містити 1–300 символів.")
	var recipients: Array = []
	if channel == "global":
		recipients = players.keys()
	elif channel in ["party","guild"]:
		var group_id: int = int(players[peer][channel])
		var groups: Dictionary = parties if channel == "party" else guilds
		if group_id == 0 or not groups.has(group_id):
			return _fail("Ти не належиш до цього каналу.")
		recipients = groups[group_id]["members"].duplicate()
	else:
		var target: int = _target(payload)
		if not _pair(peer,target):
			return _fail("Приватне повідомлення недоступне.")
		recipients = [peer,target]
	chat.append({"id":_id(),"from":peer,"name":players[peer]["name"],"channel":channel,"text":str(text).strip_edges(),"recipients":recipients,"time":Time.get_unix_time_from_system()})
	while chat.size() > 100:
		chat.pop_front()
	return _ok()

func _guild_declaration(peer: int, text: Variant) -> Dictionary:
	# UI10056: 公会宣言 is an announcement, not a declaration of war.
	var id: int = int(players[peer]["guild"])
	if id == 0 or not guilds.has(id) or int(guilds[id]["leader"]) != peer:
		return _fail("Оголошення гільдії змінює лише її лідер.")
	if not _text(text,0,500):
		return _fail("Оголошення: до 500 символів.")
	guilds[id]["declaration"] = str(text).strip_edges()
	return _ok()

func _bounty_create(peer: int, target: int, payload: Dictionary) -> Dictionary:
	var reward: Variant = payload.get("reward")
	var minimum: Variant = payload.get("min_level",1)
	var required: Variant = payload.get("required",1)
	if not _pair(peer,target) or not players[target].get("online",false):
		return _fail("Ціль недоступна або заблокована.")
	if not _integer(reward,1,100000000) or not _integer(minimum,1,100) or not _integer(required,1,10):
		return _fail("Нагорода 1–100000000 міді, рівень 1–100, перемог 1–10.")
	var active: int = 0
	for bounty: Dictionary in bounties.values():
		if bounty["state"] in ["available","accepted"]:
			active += 1
	if active >= 50 or int(players[peer]["profile"]["copper"]) < int(reward):
		return _fail("Недостатньо міді або дошка має 50 активних завдань.")
	# Bounded terminal history; IDs are never reused, so pruning cannot repay.
	while bounties.size() >= 250:
		for old: Variant in bounties.keys():
			if bounties[old]["state"] in ["completed","cancelled"]:
				bounties.erase(old)
				break
	var id: int = _id()
	# The complete reward is escrowed once. No invented publication fee.
	players[peer]["profile"]["copper"] -= int(reward)
	bounties[id] = {"id":id,"creator":peer,"target":target,"reward":int(reward),"hunter":0,"state":"available","paid":false,"min_level":int(minimum),"required":int(required),"kills":0}
	return {"ok":true,"error":"","bounty_id":id}

func _bounty_accept(peer: int, value: Variant) -> Dictionary:
	if not _integer(value,1,2147483647) or not bounties.has(int(value)):
		return _fail("Завдання не існує.")
	var bounty: Dictionary = bounties[int(value)]
	var creator: int = int(bounty["creator"])
	var target: int = int(bounty["target"])
	if bounty["state"] != "available" or not _pair(peer,creator) or not _pair(peer,target):
		return _fail("Це завдання недоступне для прийняття.")
	if not players[creator].get("online",false) or not players[target].get("online",false):
		return _fail("Автор або ціль зараз поза мережею.")
	if int(players[peer]["profile"].get("level",1)) < int(bounty["min_level"]):
		return _fail("Недостатній рівень мисливця.")
	for other: Dictionary in bounties.values():
		if other["state"] == "accepted" and int(other["hunter"]) == peer:
			return _fail("Спочатку заверши вже прийняте завдання.")
	bounty["hunter"] = peer
	bounty["state"] = "accepted"
	return _ok()

func _bounty_cancel(peer: int, value: Variant) -> Dictionary:
	if not _integer(value,1,2147483647) or not bounties.has(int(value)):
		return _fail("Завдання не існує.")
	var bounty: Dictionary = bounties[int(value)]
	if int(bounty["creator"]) != peer or bounty["state"] != "available":
		return _fail("Автор може скасувати лише ще не прийняте завдання.")
	if int(players[peer]["profile"]["copper"]) + int(bounty["reward"]) > 1000000000:
		return _fail("Звільни місце у гаманці для повернення застави.")
	players[peer]["profile"]["copper"] += int(bounty["reward"])
	bounty["state"] = "cancelled"
	return _ok()

## Trusted server-only entry point, deliberately absent from act(). The host
## calls it once for each authoritative non-duel death; clients cannot report
## kills. No event ID is available, so the host must not replay an intermediate
## kill of a multi-kill bounty. Completed records independently block repayout.
func record_player_defeat(killer: int, victim: int, duel: bool = false) -> Dictionary:
	var result: Dictionary = {"ok":true,"error":"","completed":[],"progressed":[],"reward":0}
	if duel or killer == victim or not players.has(killer) or not players.has(victim):
		result["ok"] = false
		result["error"] = "Дуелі, власні та невідомі перемоги не зараховуються."
		return result
	for bounty: Dictionary in bounties.values():
		if bounty["state"] != "accepted" or bool(bounty["paid"]) or int(bounty["hunter"]) != killer or int(bounty["target"]) != victim:
			continue
		var final_kill: bool = int(bounty["kills"]) + 1 >= int(bounty["required"])
		if final_kill and int(players[killer]["profile"]["copper"]) + int(bounty["reward"]) > 1000000000:
			result["ok"] = false
			result["error"] = "Гаманець мисливця переповнений; застава залишається у завданні."
			continue
		bounty["kills"] += 1
		result["progressed"].append(int(bounty["id"]))
		if final_kill:
			players[killer]["profile"]["copper"] += int(bounty["reward"])
			bounty["state"] = "completed"
			bounty["paid"] = true
			result["completed"].append(int(bounty["id"]))
			result["reward"] += int(bounty["reward"])
	return result

func _cleanup_bounties_for_deleted_account(peer: int) -> void:
	# detach() intentionally does not call this: offline accounts retain escrow,
	# accepted hunts and progress. Hard deletion removes historical references.
	for key: Variant in bounties.keys():
		var bounty: Dictionary = bounties[key]
		if int(bounty["creator"]) == peer or int(bounty["target"]) == peer:
			if bounty["state"] in ["available","accepted"] and int(bounty["creator"]) != peer:
				players[int(bounty["creator"])]["profile"]["copper"] += int(bounty["reward"])
			bounties.erase(key)
		elif int(bounty["hunter"]) == peer:
			if bounty["state"] == "accepted":
				bounty["state"] = "available"
				bounty["hunter"] = 0
				bounty["kills"] = 0
			else:
				bounties.erase(key)

func _invite(peer: int, target: int, groups: Dictionary, field: String) -> Dictionary:
	if not _pair(peer,target) or int(players[target][field]) != 0:
		return _fail("Запрошення недоступне.")
	var id: int = int(players[peer][field])
	if id == 0:
		if field == "guild":
			return _fail("Спочатку створи гільдію.")
		id = _id()
		groups[id] = {"id":id,"leader":peer,"members":[peer],"invites":[]}
		players[peer][field] = id
	var group: Dictionary = groups[id]
	if int(group["leader"]) != peer or target in group["invites"] or group["members"].size() >= (4 if field == "party" else 20):
		return _fail("Запрошувати може лідер; перевір кількість учасників.")
	group["invites"].append(target)
	return _ok()

func _accept_group(peer: int, id: Variant, groups: Dictionary, field: String) -> Dictionary:
	if not _integer(id,1,2147483647) or not groups.has(int(id)) or int(players[peer][field]) != 0:
		return _fail("Запрошення застаріло.")
	var group: Dictionary = groups[int(id)]
	if peer not in group["invites"] or not _pair(peer,int(group["leader"])) or group["members"].size() >= (4 if field == "party" else 20):
		return _fail("Запрошення недоступне.")
	group["invites"].erase(peer)
	group["members"].append(peer)
	players[peer][field] = int(id)
	for other: Dictionary in groups.values():
		other["invites"].erase(peer)
	return _ok()

func _leave_group(peer: int, groups: Dictionary, field: String) -> void:
	var id: int = int(players[peer][field])
	if id == 0 or not groups.has(id):
		return
	var group: Dictionary = groups[id]
	group["members"].erase(peer)
	players[peer][field] = 0
	if group["members"].is_empty():
		groups.erase(id)
	elif int(group["leader"]) == peer:
		group["leader"] = group["members"][0]

func _kick(peer: int, target: int, groups: Dictionary, field: String) -> Dictionary:
	var id: int = int(players[peer][field])
	if not players.has(target) or id == 0 or int(groups[id]["leader"]) != peer or target == peer or int(players[target][field]) != id:
		return _fail("Недостатньо прав для виключення.")
	_leave_group(target,groups,field)
	return _ok()

func _mail_send(peer: int, target: int, payload: Dictionary) -> Dictionary:
	if not _pair(peer,target) or not _text(payload.get("subject"),1,60) or not _text(payload.get("body"),1,1000):
		return _fail("Лист: тема 1–60, текст 1–1000 символів.")
	var count: int = 0
	for mail: Dictionary in mails.values():
		if int(mail["to"]) == target:
			count += 1
	if count >= 50:
		return _fail("Поштова скринька адресата заповнена.")
	var id: int = _id()
	mails[id] = {"id":id,"from":peer,"from_name":players[peer]["name"],"to":target,"subject":str(payload["subject"]).strip_edges(),"body":str(payload["body"]).strip_edges(),"read":false,"time":Time.get_unix_time_from_system()}
	return _ok()

func _trade_for(peer: int) -> Dictionary:
	for trade: Dictionary in trades.values():
		if peer in trade["participants"]:
			return trade
	return {}

func _cancel_trade_for(peer: int) -> void:
	var trade: Dictionary = _trade_for(peer)
	if not trade.is_empty():
		trades.erase(trade["id"])

func _trade_request(peer: int, target: int) -> Dictionary:
	if not _pair(peer,target) or not _trade_for(peer).is_empty() or not _trade_for(target).is_empty():
		return _fail("Гравець зайнятий або недоступний для обміну.")
	var id: int = _id()
	trades[id] = {"id":id,"participants":[peer,target],"accepted":false,"offers":{peer:{"copper":0,"items":{}},target:{"copper":0,"items":{}}},"confirmed":[]}
	return _ok()

func _trade_action(peer: int, action: String, payload: Dictionary) -> Dictionary:
	var id: Variant = payload.get("trade_id")
	if not _integer(id,1,2147483647) or not trades.has(int(id)):
		return _fail("Обмін уже завершено або скасовано.")
	var trade: Dictionary = trades[int(id)]
	if peer not in trade["participants"]:
		return _fail("Ти не учасник цього обміну.")
	if action == "trade_cancel":
		trades.erase(int(id))
		return _ok()
	if action == "trade_accept":
		if trade["accepted"] or peer != int(trade["participants"][1]):
			return _fail("Запрошення вже прийнято або адресоване іншому гравцеві.")
		trade["accepted"] = true
		return _ok()
	if not trade["accepted"]:
		return _fail("Дочекайся згоди іншого учасника.")
	if action == "trade_offer":
		var items: Variant = payload.get("items",{})
		var copper: Variant = payload.get("copper",0)
		if not items is Dictionary or items.size() > 32 or not _integer(copper,0,1000000000):
			return _fail("Некоректна пропозиція обміну.")
		var normalized: Dictionary = {}
		for key: Variant in items:
			if not key is String or not key.is_valid_int() or str(int(key)) != key or ItemCatalog.get_item(int(key)).is_empty() or not _integer(items[key],1,99999):
				return _fail("Невідомий предмет або кількість.")
			normalized[key] = int(items[key])
		var profile: Dictionary = players[peer]["profile"]
		if not _owns_offer(profile,{"copper":int(copper),"items":normalized}):
			return _fail("Недостатньо предметів або міді.")
		trade["offers"][peer] = {"copper":int(copper),"items":normalized}
		trade["confirmed"].clear()
		return _ok()
	if action == "trade_confirm":
		if peer in trade["confirmed"]:
			return _fail("Пропозицію вже підтверджено.")
		trade["confirmed"].append(peer)
		if trade["confirmed"].size() == 2:
			var result: Dictionary = _commit_trade(trade)
			if not result["ok"]:
				trade["confirmed"].clear()
				return result
			trades.erase(int(id))
		return _ok()
	return _fail("Невідома дія обміну.")

func _owns_offer(profile: Dictionary, offer: Dictionary) -> bool:
	if int(profile["copper"]) < int(offer["copper"]):
		return false
	for key: String in offer["items"]:
		if _protected(profile,int(key)) or int(profile["inventory"].get(key,0)) < int(offer["items"][key]):
			return false
	return true

func _protected(profile: Dictionary, id: int) -> bool:
	return id in profile.get("locked_items",[]) or id in profile.get("quest_item_locks",[]) or (profile.get("mounted",false) and int(profile.get("mount_id",0)) == id) or float(ItemCatalog.get_item(id).get("duration_seconds",0)) > 0.0

func _commit_trade(trade: Dictionary) -> Dictionary:
	var peers: Array = trade["participants"]
	var results: Dictionary = {}
	for index: int in 2:
		var peer: int = int(peers[index])
		var other: int = int(peers[1-index])
		if not _pair(peer,other):
			return _fail("Учасник обміну від'єднався.")
		var profile: Dictionary = players[peer]["profile"]
		var offer: Dictionary = trade["offers"][peer]
		var incoming: Dictionary = trade["offers"][other]
		if not _owns_offer(profile,offer):
			return _fail("Предмети або мідь змінилися; підтвердьте пропозицію знову.")
		var bag: Dictionary = profile["inventory"].duplicate(true)
		for key: String in offer["items"]:
			bag[key] = int(bag[key]) - int(offer["items"][key])
			if int(bag[key]) == 0:
				bag.erase(key)
		for key: String in incoming["items"]:
			bag[key] = int(bag.get(key,0)) + int(incoming["items"][key])
			if int(bag[key]) > int(ItemCatalog.get_item(int(key))["max_stack"]):
				return _fail("Стос предметів переповнений.")
		var copper: int = int(profile["copper"]) - int(offer["copper"]) + int(incoming["copper"])
		if bag.size() > int(profile["bag_capacity"]) or copper < 0 or copper > 1000000000:
			return _fail("У сумці немає місця або перевищено ліміт міді.")
		results[peer] = {"inventory":bag,"copper":copper}
	# No state is changed until both final bags have validated.
	for peer: int in results:
		players[peer]["profile"]["inventory"] = results[peer]["inventory"]
		for key: String in results[peer]["inventory"]:
			MountSystem.register_acquisition(players[peer]["profile"],int(key))
		players[peer]["profile"]["copper"] = results[peer]["copper"]
	return _ok()

func snapshot_for(peer: int) -> Dictionary:
	if not players.has(peer):
		return {}
	var own: Dictionary = players[peer]
	var online: Array[Dictionary] = []
	for id: int in players:
		if players[id].get("online",true):
			online.append({"id":id,"name":players[id]["name"]})
	var visible_chat: Array[Dictionary] = []
	for message: Dictionary in chat:
		if peer in message["recipients"] and int(message["from"]) not in own["blocked"]:
			var copy: Dictionary = message.duplicate(true)
			copy.erase("recipients")
			visible_chat.append(copy)
	var inbox: Array[Dictionary] = []
	for mail: Dictionary in mails.values():
		if int(mail["to"]) == peer:
			inbox.append(mail.duplicate(true))
	var invitations: Dictionary = {"party":[],"guild":[]}
	for entry: Array in [[parties,"party"],[guilds,"guild"]]:
		for group: Dictionary in entry[0].values():
			if peer in group["invites"]:
				invitations[entry[1]].append({"id":group["id"],"leader":group["leader"],"name":group.get("name","Група")})
	var party: Dictionary = parties.get(int(own["party"]),{}).duplicate(true)
	var guild: Dictionary = guilds.get(int(own["guild"]),{}).duplicate(true)
	party.erase("invites")
	guild.erase("invites")
	var known: Dictionary = {}
	for id: int in players:
		if players[id].get("online",false) or id in own["friends"] or id in own["requests"] or id in party.get("members",[]) or id in guild.get("members",[]):
			known[id] = players[id]["name"]
	var auctions: Array[Dictionary] = []
	for listing: Dictionary in listings.values():
		var copy: Dictionary = listing.duplicate(true)
		copy["seller_name"] = players[int(copy["seller"])]["name"]
		auctions.append(copy)
	var board: Array[Dictionary] = []
	for bounty: Dictionary in bounties.values():
		if bounty["state"] not in ["available","accepted"] and peer not in [bounty["creator"],bounty["hunter"],bounty["target"]]:
			continue
		var copy: Dictionary = bounty.duplicate(true)
		for role: String in ["creator","target","hunter"]:
			copy[role + "_name"] = players.get(int(copy[role]),{}).get("name","")
		board.append(copy)
	return {"own_id":peer,"name":own["name"],"profile":own["profile"].duplicate(true),"onlineplayers":online,"players":online,"known_names":known,"chat":visible_chat,"friends":own["friends"].duplicate(),"friendrequests":own["requests"].duplicate(),"blocked":own["blocked"].duplicate(),"party":party,"guild":guild,"invitations":invitations,"mail":inbox,"inbox":inbox.duplicate(true),"trade":_trade_for(peer).duplicate(true),"auctions":auctions,"bounties":board}

func persistent_state() -> Dictionary:
	var profiles: Dictionary = players.duplicate(true)
	for value: Dictionary in profiles.values():
		value["online"] = false
	return {"players":profiles,"parties":parties.duplicate(true),"guilds":guilds.duplicate(true),"mails":mails.duplicate(true),"listings":listings.duplicate(true),"bounties":bounties.duplicate(true),"chat":chat.duplicate(true),"next_id":_next_id}

func restore_state(data: Dictionary) -> void:
	players = data["players"].duplicate(true)
	parties = data["parties"].duplicate(true)
	guilds = data["guilds"].duplicate(true)
	mails = data["mails"].duplicate(true)
	listings = data.get("listings",{}).duplicate(true)
	bounties = data.get("bounties",{}).duplicate(true)
	chat.assign(data["chat"])
	_next_id = int(data["next_id"])
	trades = data.get("trades",{}).duplicate(true)

func checkpoint() -> Dictionary:
	return {"players":players.duplicate(true),"parties":parties.duplicate(true),"guilds":guilds.duplicate(true),"mails":mails.duplicate(true),"listings":listings.duplicate(true),"bounties":bounties.duplicate(true),"chat":chat.duplicate(true),"trades":trades.duplicate(true),"next_id":_next_id}
