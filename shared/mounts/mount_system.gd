class_name MountSystem
extends RefCounted

# Mount IDs, faster movement, creature-damage reduction and the prohibition on
# mounted attacks are evidenced in original equipment text. Exact multipliers
# are provisional modern tuning, not decoded original numerical balance.
const SPEED_MULTIPLIER: float = 1.6
const DAMAGE_MULTIPLIER: float = 0.5

static func ensure_stats(stats: Dictionary) -> void:
	if not stats.has("mount_id"):
		stats["mount_id"] = 0
	if not stats.has("mounted"):
		stats["mounted"] = false
	if not stats.has("mount_acquired_at"):
		stats["mount_acquired_at"] = {}

static func mount(stats: Dictionary, id: int, now: float = -1.0) -> bool:
	ensure_stats(stats)
	if typeof(stats["mounted"]) != TYPE_BOOL or not _integer(stats["mount_id"],0,999999):
		return false
	if ItemCatalog.get_item(id).get("kind") != "mount" or not stats.get("inventory") is Dictionary:
		return false
	if not _integer(stats.get("hp"),1,1000000000) or not _integer(stats["inventory"].get(str(id)),1,1):
		return false
	if stats["mounted"] == true and int(stats["mount_id"]) == id:
		return false
	if not stats["mount_acquired_at"].has(str(id)):
		register_acquisition(stats,id,now)
	if seconds_left(stats,id,now) <= 0.0:
		return false
	stats["mount_id"] = id
	stats["mounted"] = true
	return true

static func register_acquisition(stats: Dictionary, id: int, now: float = -1.0) -> void:
	ensure_stats(stats)
	if ItemCatalog.get_item(id).get("kind") == "mount" and not stats["mount_acquired_at"].has(str(id)):
		stats["mount_acquired_at"][str(id)] = Time.get_unix_time_from_system() if now < 0.0 else now

static func seconds_left(stats: Dictionary, id: int, now: float = -1.0) -> float:
	var duration: float = float(ItemCatalog.get_item(id).get("duration_seconds",0))
	if duration <= 0.0:
		return INF
	var current: float = Time.get_unix_time_from_system() if now < 0.0 else now
	return maxf(0.0,float(stats.get("mount_acquired_at",{}).get(str(id),current)) + duration - current)

static func dismount(stats: Dictionary) -> void:
	ensure_stats(stats)
	stats["mounted"] = false

static func speed_multiplier(stats: Dictionary) -> float:
	return SPEED_MULTIPLIER if _active(stats) else 1.0

static func damage_multiplier(stats: Dictionary) -> float:
	return DAMAGE_MULTIPLIER if _active(stats) else 1.0

static func can_attack(stats: Dictionary) -> bool:
	return not _active(stats)

static func _active(stats: Dictionary, check_expiry: bool = true) -> bool:
	if typeof(stats.get("mounted")) != TYPE_BOOL or not stats["mounted"]:
		return false
	var id: Variant = stats.get("mount_id")
	return _integer(id,1,999999) and ItemCatalog.get_item(int(id)).get("kind") == "mount" and stats.get("inventory") is Dictionary and _integer(stats["inventory"].get(str(int(id))),1,1) and _integer(stats.get("hp"),1,1000000000) and (not check_expiry or seconds_left(stats,int(id)) > 0.0)

static func validate(stats: Dictionary) -> bool:
	if not _integer(stats.get("mount_id"),0,999999) or typeof(stats.get("mounted")) != TYPE_BOOL:
		return false
	var id: int = int(stats["mount_id"])
	if id != 0 and ItemCatalog.get_item(id).get("kind") != "mount":
		return false
	if not stats.get("mount_acquired_at",{}) is Dictionary:
		return false
	for key: Variant in stats.get("mount_acquired_at",{}):
		var value: Variant = stats["mount_acquired_at"][key]
		if not key is String or not key.is_valid_int() or str(int(key)) != key or ItemCatalog.get_item(int(key)).get("kind") != "mount" or (not value is int and not value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1000000000000.0:
			return false
	return not stats["mounted"] or _active(stats,false)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and floor(float(value)) == float(value) and float(value) >= low and float(value) <= high
