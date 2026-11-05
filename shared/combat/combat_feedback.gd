class_name CombatFeedback
extends RefCounted

static func arc(parent: Node3D, origin: Vector3, yaw: float, color: Color, radius: float = 2.0) -> void:
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for i: int in 18:
		var a: float = -1.1 + float(i) / 18.0 * 2.2
		var b: float = a + 2.2 / 18.0
		var v1: Vector3 = Vector3(sin(a), 0, -cos(a))
		var v2: Vector3 = Vector3(sin(b), 0, -cos(b))
		for v: Vector3 in [v1 * radius * 0.62, v1 * radius, v2 * radius, v1 * radius * 0.62, v2 * radius, v2 * radius * 0.62]:
			mesh.surface_add_vertex(v)
	mesh.surface_end()
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	visual.global_position = origin + Vector3(0, 0.9, 0)
	visual.rotation.y = yaw
	var tween: Tween = visual.create_tween().set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.22)
	tween.tween_property(visual, "rotation:y", yaw + 0.6, 0.22)
	tween.finished.connect(visual.queue_free)

static func sound(parent: Node, clip: String, volume: float = -15.0) -> void:
	var path: String = "res://assets/audio/%s.wav" % clip
	if not ResourceLoader.exists(path):
		return
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.stream = load(path)
	audio.bus = "Effects"
	audio.volume_db = volume
	audio.pitch_scale = randf_range(0.94, 1.06)
	parent.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()
