extends SceneTree
const Social = preload("res://server/social_state.gd")
var failures: int = 0
func _initialize() -> void:
	if "--transport-host" in OS.get_cmdline_user_args():
		call_deferred("transport_host")
	elif "--transport-client" in OS.get_cmdline_user_args():
		call_deferred("transport_client")
	else:
		call_deferred("run")
func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ",label)
	else:
		failures += 1
		push_error("FAIL: "+label)
func command(state: Social, peer: int, action: String, data: Dictionary = {}) -> bool:
	return bool(state.act(peer,action,data).get("ok",false))
func trade_id(state: Social, peer: int) -> int:
	return int(state.snapshot_for(peer)["trade"]["id"])
func run() -> void:
	var state: Social = Social.new()
	check(state.join(1,"Alice") and state.join(2,"Bohdan") and state.join(3,"Claire"),"three server-owned profiles admitted")
	check(not state.join(1,"Alias") and not state.join(4,"x"),"duplicate peer and invalid nickname rejected")
	check(state.snapshot_for(1)["profile"]["copper"] == 100,"authoritative starter currency")
	check(not command(state,99,"chat",{"text":"bad"}),"unadmitted sender rejected")
	check(command(state,1,"friend_request",{"target":2}),"friend request delivered")
	check(state.snapshot_for(2)["friendrequests"] == [1] and state.snapshot_for(3)["friendrequests"].is_empty(),"friend request is private")
	check(not command(state,3,"friend_accept",{"target":1}),"cannot accept another player's friendship")
	check(command(state,2,"friend_accept",{"target":1}) and state.snapshot_for(1)["friends"] == [2],"accepted friendship is mutual")
	check(not command(state,2,"friend_accept",{"target":1}),"friend acceptance cannot replay")
	check(command(state,1,"chat",{"channel":"whisper","target":2,"text":"private-message"}),"whisper sent")
	check(state.snapshot_for(2)["chat"].size() == 1 and state.snapshot_for(3)["chat"].is_empty(),"whisper does not leak to third player")
	check(not command(state,1,"chat",{"channel":"party","text":"not a member"}),"nonmember cannot send party chat")
	check(command(state,1,"party_invite",{"target":2}),"leader creates party invite")
	var party: int = int(state.snapshot_for(2)["invitations"]["party"][0]["id"])
	check(not command(state,3,"party_accept",{"party_id":party}),"party invite cannot be stolen")
	check(command(state,2,"party_accept",{"party_id":party}),"party invite accepted")
	check(not command(state,2,"party_invite",{"target":3}),"party member cannot invite as leader")
	check(command(state,1,"chat",{"channel":"party","text":"party-only"}),"party chat sent")
	check(state.snapshot_for(3)["chat"].is_empty(),"party chat stays private")
	check(command(state,1,"guild_create",{"name":"Forest Guild"}) and state.snapshot_for(1)["profile"]["copper"] == 50,"guild creation charges exactly once")
	check(not command(state,1,"guild_create",{"name":"Another"}) and state.snapshot_for(1)["profile"]["copper"] == 50,"duplicate guild creation does not deduct again")
	check(command(state,1,"guild_invite",{"target":2}),"guild invitation")
	var guild: int = int(state.snapshot_for(2)["invitations"]["guild"][0]["id"])
	check(command(state,2,"guild_accept",{"guild_id":guild}),"guild acceptance")
	check(not command(state,2,"guild_kick",{"target":1}),"guild member cannot kick leader")
	check(command(state,1,"mail_send",{"target":2,"subject":"Hello","body":"Private letter"}),"mail delivered")
	var mail: int = int(state.snapshot_for(2)["mail"][0]["id"])
	check(state.snapshot_for(3)["mail"].is_empty() and not command(state,3,"mail_read",{"mail_id":mail}) and not command(state,3,"mail_delete",{"mail_id":mail}),"foreign mailbox cannot be read or deleted")
	check(command(state,2,"mail_read",{"mail_id":mail}) and state.snapshot_for(2)["mail"][0]["read"],"owner marks mail read")
	check(command(state,2,"mail_delete",{"mail_id":mail}) and state.snapshot_for(2)["mail"].is_empty(),"owner deletes mail")
	check(command(state,1,"trade_request",{"target":2}),"trade request")
	var id: int = trade_id(state,1)
	check(not command(state,1,"trade_confirm",{"trade_id":id}),"trade requires recipient consent")
	check(not command(state,3,"trade_accept",{"trade_id":id}),"foreign peer cannot accept trade")
	check(command(state,2,"trade_accept",{"trade_id":id}),"recipient accepts trade")
	check(not command(state,1,"trade_offer",{"trade_id":id,"copper":-10,"items":{}}),"negative currency rejected")
	check(not command(state,1,"trade_offer",{"trade_id":id,"copper":0,"items":{"99999999":1}}),"unknown item rejected")
	check(command(state,1,"trade_offer",{"trade_id":id,"copper":10,"items":{"30016":1}}),"valid first offer")
	check(command(state,1,"trade_confirm",{"trade_id":id}),"first side confirms")
	check(command(state,2,"trade_offer",{"trade_id":id,"copper":5,"items":{"30645":1}}) and state.snapshot_for(1)["trade"]["confirmed"].is_empty(),"changed offer clears both confirmations")
	var before_a: Dictionary = state.snapshot_for(1)["profile"]
	var before_b: Dictionary = state.snapshot_for(2)["profile"]
	check(command(state,1,"trade_confirm",{"trade_id":id}) and state.snapshot_for(1)["profile"] == before_a,"one confirmation transfers nothing")
	check(command(state,2,"trade_confirm",{"trade_id":id}),"second confirmation commits trade")
	var after_a: Dictionary = state.snapshot_for(1)["profile"]
	var after_b: Dictionary = state.snapshot_for(2)["profile"]
	check(after_a["copper"] == before_a["copper"]-5 and after_b["copper"] == before_b["copper"]+5,"currency conservation")
	check(after_a["inventory"]["30016"] == 2 and after_b["inventory"]["30016"] == 4 and after_a["inventory"]["30645"] == 3,"items transferred atomically")
	check(not command(state,2,"trade_confirm",{"trade_id":id}) and state.snapshot_for(1)["profile"] == after_a,"completed trade token cannot replay")
	# Force a capacity limit in authoritative state, not by client payload.
	state.players[2]["profile"]["bag_capacity"] = 2
	state.players[1]["profile"]["inventory"]["30037"] = 1
	command(state,1,"trade_request",{"target":2})
	id = trade_id(state,1)
	command(state,2,"trade_accept",{"trade_id":id})
	command(state,1,"trade_offer",{"trade_id":id,"items":{"30037":1}})
	before_a = state.snapshot_for(1)["profile"]
	before_b = state.snapshot_for(2)["profile"]
	command(state,1,"trade_confirm",{"trade_id":id})
	check(not command(state,2,"trade_confirm",{"trade_id":id}) and state.snapshot_for(1)["profile"] == before_a and state.snapshot_for(2)["profile"] == before_b,"full recipient bag rejects entire trade atomically")
	state.leave(2)
	check(state.snapshot_for(1)["trade"].is_empty() and state.snapshot_for(1)["profile"] == before_a,"disconnect cancels escrow without item loss")
	check(state.snapshot_for(1)["party"]["members"] == [1] and state.snapshot_for(1)["guild"]["members"] == [1],"disconnect removes group memberships")
	check(command(state,3,"block",{"target":1}) and not command(state,1,"friend_request",{"target":3}) and not command(state,1,"mail_send",{"target":3,"subject":"No","body":"No"}),"blocking prevents direct contact")
	check(not command(state,1,"chat",{"text":"x".repeat(301)}) and not command(state,1,"guild_create",{"name":"Bad","copper":-100}),"oversized text and untrusted currency cannot bypass rules")
	print("SOCIAL_STATE_SUITE: ","PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(0 if failures == 0 else 1)

var _transport_replied: bool = false
var _transport_done: bool = false

func transport_host() -> void:
	var net: Node = root.get_node("NetworkManager")
	net.local_player_data = {"name":"LAN Host"}
	net.state_updated.connect(func(snapshot: Dictionary) -> void:
		if snapshot.is_empty() or _transport_replied:
			return
		for message: Dictionary in snapshot.get("chat",[]):
			if message["text"] == "transport-client":
				_transport_replied = true
				net.request("friend_accept",{"target":int(message["from"])})
				net.request("chat",{"channel":"global","text":"transport-host"})
				_transport_done = true
	)
	if not net.start_server(17877):
		print("TRANSPORT_HOST: FAIL start")
		quit(1)
		return
	print("TRANSPORT_HOST_READY")
	await create_timer(8.0).timeout
	print("TRANSPORT_HOST: ","PASS" if _transport_done else "FAIL timeout")
	net.disconnect_session()
	quit(0 if _transport_done else 1)

func transport_client() -> void:
	var net: Node = root.get_node("NetworkManager")
	# These fields are not uploaded. Only a bounded nickname is admitted.
	net.local_player_data = {"name":"LAN Client","copper":9999999,"inventory":{"10010":99}}
	net.state_updated.connect(func(snapshot: Dictionary) -> void:
		if snapshot.is_empty() or _transport_done:
			return
		if not _transport_replied and snapshot.get("onlineplayers",[]).size() == 2:
			_transport_replied = true
			check(snapshot["profile"]["copper"] == 100 and not snapshot["profile"]["inventory"].has("10010"),"transport rejects client currency/inventory upload")
			net.request("friend_request",{"target":1})
			net.request("chat",{"channel":"global","text":"transport-client"})
		for message: Dictionary in snapshot.get("chat",[]):
			if message["text"] == "transport-host" and 1 in snapshot["friends"]:
				_transport_done = true
	)
	if not net.start_client("127.0.0.1",17877):
		print("TRANSPORT_CLIENT: FAIL start")
		quit(1)
		return
	await create_timer(5.0).timeout
	print("TRANSPORT_CLIENT: ","PASS" if _transport_done and failures == 0 else "FAIL timeout")
	net.disconnect_session()
	quit(0 if _transport_done and failures == 0 else 1)
