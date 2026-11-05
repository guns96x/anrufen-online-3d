class_name OnlineSession
extends RefCounted

## Client side of playing on the dedicated server: which server, which hero slot
## (each slot has its own device token, so its own server account) and a local
## card cache so the slot screen can show heroes while offline.

const CONFIG: String = "user://online.cfg"
const DEFAULT_ADDRESS: String = "100.82.252.86"   # the "asus" PC on Tailscale

static var enabled: bool = true
static var slot: int = 0

static func address() -> String:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG)
	return str(cfg.get_value("server", "address", DEFAULT_ADDRESS))

static func set_address(value: String) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("server", "address", value.strip_edges())
	cfg.save(CONFIG)

static func identity_path(index: int) -> String:
	return "user://lan_identity.token" if index == 0 else "user://lan_identity_slot%d.token" % (index + 1)

## Remembers what the server last said about this slot's hero.
static func remember(index: int, profile: Dictionary) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("slot%d" % index, "hero", {"name": str(profile.get("name", "")), "race_id": int(profile.get("race_id", 250001)),
		"class_id": int(profile.get("class_id", 130001)), "level": int(profile.get("level", 1))})
	cfg.save(CONFIG)

static func summary(index: int) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG)
	return cfg.get_value("slot%d" % index, "hero", {})

## Forgets a slot: drops the cached card and the device token, so the next hero
## in this slot becomes a new server account. The old account stays on the server.
static func forget(index: int) -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(CONFIG)
	if cfg.has_section("slot%d" % index):
		cfg.erase_section("slot%d" % index)
	cfg.save(CONFIG)
	var token: String = ProjectSettings.globalize_path(identity_path(index))
	if FileAccess.file_exists(identity_path(index)):
		DirAccess.rename_absolute(token, token + ".deleted")

## Points the network layer at this slot's identity and the chosen hero.
static func prepare(net: Node, hero: Dictionary = {}) -> void:
	net.identity_path = identity_path(slot)
	net.set("_identity", "")
	net.pending_hero = hero
	if hero.has("name"):
		net.local_player_data["name"] = str(hero["name"])
	else:
		net.local_player_data["name"] = str(summary(slot).get("name", "Мандрівник"))
