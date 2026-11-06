class_name CharacterMerge
extends RefCounted

## Joins a KayKit character's visible skinned parts (arms, body, head, legs:
## six meshes sharing one skin) into one mesh with one surface per material.
## Each part used to cost two draw calls (body + ink outline) plus its shadow,
## so an NPC drops from ~12 calls to ~2. Only for looks that never change
## (citizens, bandits); the hero keeps separate parts for gear swaps.

const CHANNELS: Array[int] = [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR,
	Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]

static func merge(model: Node) -> MeshInstance3D:
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return null
	var parts: Array[MeshInstance3D] = []
	var skin: Skin = null
	for child: Node in skel.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if not mi.visible or mi.skin == null or mi.mesh == null or mi.transform != Transform3D.IDENTITY:
				continue
			if skin == null:
				skin = mi.skin
			elif mi.skin != skin:
				continue
			parts.append(mi)
	if parts.size() < 2:
		return null
	# material -> accumulated arrays
	var groups: Dictionary = {}
	var order: Array = []
	var format_ref: int = -1
	for mi: MeshInstance3D in parts:
		for s: int in mi.mesh.get_surface_count():
			var fmt: int = mi.mesh.surface_get_format(s) & (Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_TEX_UV2 | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
			if format_ref == -1:
				format_ref = fmt
			elif fmt != format_ref:
				return null   # mixed vertex layouts: leave the parts alone
			var mat: Material = mi.get_active_material(s)
			if not groups.has(mat):
				groups[mat] = {"arrays": [], "index": PackedInt32Array(), "count": 0}
				order.append(mat)
			var g: Dictionary = groups[mat]
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			if g["arrays"].is_empty():
				g["arrays"].resize(Mesh.ARRAY_MAX)
				for c: int in CHANNELS:
					g["arrays"][c] = arrays[c].duplicate() if arrays[c] != null else null
			else:
				var acc: Array = g["arrays"]
				for c: int in CHANNELS:
					if arrays[c] != null and acc[c] != null:
						var joined: Variant = acc[c]
						joined.append_array(arrays[c])
						acc[c] = joined
			var base: int = int(g["count"])
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()))
			var shifted: PackedInt32Array = PackedInt32Array()
			shifted.resize(idx.size())
			for i: int in idx.size():
				shifted[i] = idx[i] + base
			var all_idx: PackedInt32Array = g["index"]
			all_idx.append_array(shifted)
			g["index"] = all_idx
			g["count"] = base + (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var mesh: ArrayMesh = ArrayMesh.new()
	var flags: int = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if (format_ref & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) else 0
	for mat: Material in order:
		var g: Dictionary = groups[mat]
		var arrays: Array = g["arrays"]
		arrays[Mesh.ARRAY_INDEX] = g["index"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var merged: MeshInstance3D = MeshInstance3D.new()
	merged.name = "MergedBody"
	merged.mesh = mesh
	merged.skin = skin
	skel.add_child(merged)
	merged.skeleton = merged.get_path_to(skel)
	for mi: MeshInstance3D in parts:
		skel.remove_child(mi)
		mi.queue_free()
	return merged
