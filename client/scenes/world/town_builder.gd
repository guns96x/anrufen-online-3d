class_name TownBuilder
extends Node3D

## Assembles Guanlin Town buildings from the CC0 Quaternius modular village kit
## (assets/village, 2 m wall cells, 3 m storeys) following GuanlinLayout.

const KIT: String = "res://assets/village/%s.gltf"
const CELL: float = 2.0
const STOREY: float = 3.0

var _cache: Dictionary = {}

func piece(name: String) -> Node3D:
	if not _cache.has(name):
		_cache[name] = load(KIT % name)
	return (_cache[name] as PackedScene).instantiate()

func place(parent: Node3D, name: String, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	var node: Node3D = piece(name)
	node.position = pos
	node.rotation.y = deg_to_rad(yaw_deg)
	parent.add_child(node)
	return node

## A rectangular house of w x d wall cells and the given storeys.
## spec keys: base ("UnevenBrick" | "Plaster"), upper ("Plaster" | "UnevenBrick"),
## door (cell index on the front side), roof (kit roof name or ""), gable (front piece),
## chimney (bool), windows ("Wide_Round" etc.).
func house(pos: Vector3, yaw_deg: float, w: int, d: int, storeys: int, spec: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.position = pos
	root.rotation.y = deg_to_rad(yaw_deg)
	add_child(root)
	var hw: float = w * CELL * 0.5
	var hd: float = d * CELL * 0.5
	var sides: Array = [
		[Vector3(0, 0, hd), 0.0, w, Vector3(1, 0, 0)],      # front (+Z)
		[Vector3(0, 0, -hd), 180.0, w, Vector3(-1, 0, 0)],  # back
		[Vector3(hw, 0, 0), 90.0, d, Vector3(0, 0, -1)],    # right (+X)
		[Vector3(-hw, 0, 0), -90.0, d, Vector3(0, 0, 1)],   # left
	]
	var window: String = spec.get("windows", "Wide_Round")
	for s: int in storeys:
		var y: float = s * STOREY
		var style: String = spec.get("base", "UnevenBrick") if s == 0 else spec.get("upper", "Plaster")
		for side_i: int in sides.size():
			var side: Array = sides[side_i]
			var count: int = side[2]
			for c: int in count:
				var offset: float = (c - (count - 1) * 0.5) * CELL
				var p: Vector3 = side[0] + side[3] * offset + Vector3(0, y, 0)
				var kind: String = "Straight"
				if s == 0 and side_i == 0 and c == int(spec.get("door", count / 2)):
					kind = "Door_Round"
				elif (c + side_i) % 2 == 1:
					kind = "Window_" + window
				var name: String = "Wall_%s_%s" % [style, kind]
				if style == "Plaster" and kind == "Straight" and spec.get("timber", true):
					name = "Wall_Plaster_WoodGrid"
				place(root, name, p, side[1])
				if kind == "Door_Round":
					place(root, "Door_1_Round", p + side[3] * -0.53 + Vector3(0, 0, 0.02), side[1])
				elif kind.begins_with("Window"):
					place(root, "Window_" + window + "1", p, side[1])
		for corner: Vector3 in [Vector3(hw, 0, hd), Vector3(-hw, 0, hd), Vector3(hw, 0, -hd), Vector3(-hw, 0, -hd)]:
			place(root, "Corner_Exterior_Wood" if style == "Plaster" else "Corner_Exterior_Brick", corner + Vector3(0, y, 0))
		if s > 0:
			for side: Array in sides:
				for c: int in side[2]:
					var off: float = (c - (side[2] - 1) * 0.5) * CELL
					place(root, "Wall_BottomCover", side[0] + side[3] * off + Vector3(0, y, 0), side[1])
	var top: float = storeys * STOREY
	var roof: String = spec.get("roof", "")
	if roof != "":
		place(root, roof, Vector3(0, top, 0), spec.get("roof_yaw", 0.0))
		var gable: String = spec.get("gable", "")
		if gable != "":
			place(root, gable, Vector3(0, top, hd), 0.0)
			place(root, gable, Vector3(0, top, -hd), 180.0)
	if spec.get("chimney", false):
		place(root, "Prop_Chimney", Vector3(hw - 1.0, top + 1.0, -hd + 1.0))
	_solid(root, Vector3(0, top * 0.5, 0), Vector3(w * CELL, top, d * CELL))
	bake(root)
	return root

const BAKE_VERSION: int = 2
const BAKE_CACHE: String = "user://bake_cache"

## Merges every kit piece under root into one mesh per texture set, so a house
## costs a handful of draw calls on mobile instead of one per wall surface.
## The merged mesh (with its LODs) is cached on disk, keyed by the pieces and
## their placement, so later launches skip the merge and LOD generation. On
## phones the first automatic LOD becomes the full-detail mesh: the kit's
## bevels are invisible at phone size and it halves the triangle count.
func bake(root: Node3D) -> void:
	var mobile: bool = OS.has_feature("mobile") or OS.get_environment("COVENANT_MOBILE_LOD") == "1"
	var cache_path: String = "%s/%s_%s.res" % [BAKE_CACHE, String(root.name).validate_filename(), _bake_digest(root, mobile)]
	if ResourceLoader.exists(cache_path):
		var cached: ArrayMesh = load(cache_path) as ArrayMesh
		if cached:
			_replace_with(root, _bake_pieces(root), cached)
			return
	var tools: Dictionary = {}
	var materials: Dictionary = {}
	var pieces: Array[Node] = []
	for child: Node in root.get_children():
		if child is StaticBody3D or child is Light3D or child is Label3D or child.name == "Baked" 				or not child.find_children("*", "Label3D", true, false).is_empty() 				or not child.find_children("*", "Light3D", true, false).is_empty():
			continue
		pieces.append(child)
		var meshes: Array[Node] = child.find_children("*", "MeshInstance3D", true, false)
		if child is MeshInstance3D: meshes.append(child)
		for node: Node in meshes:
			if not node is MeshInstance3D:
				continue
			var mi: MeshInstance3D = node
			var xf: Transform3D = _relative_transform(mi, root)
			for surface: int in mi.mesh.get_surface_count():
				var mat: Material = mi.get_active_material(surface)
				var key: String = _material_key(mat)
				if not tools.has(key):
					var st: SurfaceTool = SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = st
					materials[key] = mat
				(tools[key] as SurfaceTool).append_from(mi.mesh, surface, xf)
	# ImporterMesh keeps automatic LODs for the merged geometry, so distant houses stay cheap.
	var importer: ImporterMesh = ImporterMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key]
		st.index()
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, materials[key])
	importer.generate_lods(25.0, 60.0, [])
	if mobile:
		importer = _drop_top_lod(importer)
	var merged: ArrayMesh = importer.get_mesh()
	DirAccess.make_dir_recursive_absolute(BAKE_CACHE)
	ResourceSaver.save(merged, cache_path)
	_replace_with(root, pieces, merged)

func _replace_with(root: Node3D, pieces: Array[Node], merged: ArrayMesh) -> void:
	for piece: Node in pieces:
		root.remove_child(piece)
		piece.queue_free()
	var baked: MeshInstance3D = MeshInstance3D.new()
	baked.name = "Baked"
	baked.mesh = merged
	root.add_child(baked)

## The pieces bake() would merge (everything but colliders, lights, labels).
func _bake_pieces(root: Node3D) -> Array[Node]:
	var pieces: Array[Node] = []
	for child: Node in root.get_children():
		if child is StaticBody3D or child is Light3D or child is Label3D or child.name == "Baked" 				or not child.find_children("*", "Label3D", true, false).is_empty() 				or not child.find_children("*", "Light3D", true, false).is_empty():
			continue
		pieces.append(child)
	return pieces

## Identifies a bake by which meshes sit where, so any layout change re-bakes.
func _bake_digest(root: Node3D, mobile: bool) -> String:
	var parts: PackedStringArray = PackedStringArray([str(BAKE_VERSION), "m" if mobile else "d"])
	for piece: Node in _bake_pieces(root):
		var meshes: Array[Node] = piece.find_children("*", "MeshInstance3D", true, false)
		if piece is MeshInstance3D: meshes.append(piece)
		for node: Node in meshes:
			var mi: MeshInstance3D = node
			if mi.mesh == null:
				continue
			var o: Vector3 = _relative_transform(mi, root).origin
			parts.append("%s@%d,%d,%d" % [mi.mesh.resource_path if mi.mesh.resource_path != "" else str(mi.mesh.get_surface_count()), roundi(o.x * 100), roundi(o.y * 100), roundi(o.z * 100)])
	return str(hash(",".join(parts)))

func _drop_top_lod(src: ImporterMesh) -> ImporterMesh:
	var out: ImporterMesh = ImporterMesh.new()
	for s: int in src.get_surface_count():
		var arrays: Array = src.get_surface_arrays(s)
		var lods: Dictionary = {}
		var count: int = src.get_surface_lod_count(s)
		if count > 0:
			arrays[Mesh.ARRAY_INDEX] = src.get_surface_lod_indices(s, 0)
			for i: int in range(1, count):
				lods[src.get_surface_lod_size(s, i)] = src.get_surface_lod_indices(s, i)
		out.add_surface(src.get_surface_primitive_type(s), arrays, [], lods, src.get_surface_material(s), src.get_surface_name(s))
	return out

func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf

func _material_key(mat: Material) -> String:
	var base: BaseMaterial3D = mat as BaseMaterial3D
	if base and base.albedo_texture:
		return base.albedo_texture.resource_path + str(base.transparency)
	return str(mat.get_instance_id()) if mat else "none"

func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	var col: CollisionShape3D = CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
