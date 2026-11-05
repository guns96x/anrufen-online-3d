class_name GroundLoot
extends Area3D

signal collected()
signal contents_changed()
signal expired()
var contents: Dictionary = {}
var copper: int = 0
var lifetime: float = 120.0
var _elapsed: float = 0.0
var _finished: bool = false
var _collecting: bool = false
var _label: Label3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("ground_loot")
	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = 3.0
	collision.shape = sphere
	add_child(collision)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.25
	torus.rings = 16
	torus.ring_segments = 5
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.75, 0.16)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.15
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_label = Label3D.new()
	_label.position.y = 0.6
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 20
	_label.modulate = Color.GOLD
	add_child(_label)
	_update_label()

func _process(delta: float) -> void:
	if _finished or not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += delta
	if _elapsed >= lifetime:
		_finished = true
		expired.emit()
		queue_free()

func _update_label() -> void:
	if _label:
		_label.text = "Здобич · %d міді" % copper if copper > 0 else "Здобич · %d речей" % contents.size()

func _valid_contents() -> bool:
	if copper < 0 or copper > 1000000000 or contents.size() > 64:
		return false
	for key: Variant in contents:
		if not key is String or not key.is_valid_int() or str(int(key)) != key:
			return false
		var item: Dictionary = ItemCatalog.get_item(int(key))
		if item.is_empty() or not InventorySystem._integer(contents[key], 1, int(item["max_stack"])):
			return false
	return true

func pickup(items: InventorySystem, allowed_kinds: Array[String] = []) -> bool:
	if _finished or _collecting or items == null or not is_instance_valid(items.player) or not items.player is Node3D:
		return false
	var actor: Node3D = items.player
	var stats: Variant = actor.get("stats")
	if not stats is Dictionary or not InventorySystem._integer(stats.get("copper"), 0, 1000000000) or not InventorySystem._integer(stats.get("hp"), 0, 1000000000):
		return false
	var death_state: Variant = actor.get("is_dead")
	if int(stats["hp"]) <= 0 or (typeof(death_state) == TYPE_BOOL and death_state) or actor.global_position.distance_to(global_position) > 3.0:
		return false
	if not _valid_contents() or int(stats["copper"]) + copper > 1000000000:
		return false
	_collecting = true
	var picked: bool = false
	var awarded_copper: bool = copper > 0
	if awarded_copper:
		stats["copper"] = int(stats["copper"]) + copper
		copper = 0
		picked = true
	for key: String in contents.keys():
		if not allowed_kinds.is_empty() and str(ItemCatalog.get_item(int(key)).get("kind","")) not in allowed_kinds:
			continue
		var count: int = int(contents[key])
		if items.can_add(int(key), count) and items.add_item(int(key), count):
			contents.erase(key)
			picked = true
	if awarded_copper:
		items.changed.emit()
	_collecting = false
	if picked:
		contents_changed.emit()
		_update_label()
	if contents.is_empty() and copper == 0:
		_finished = true
		collected.emit()
		queue_free()
	return picked
