class_name Vfx
extends RefCounted

## Bright, additive one-shot effects in the anime style: spark bursts, shock
## rings and a level-up pillar. HDR colours (>1) feed the town's bloom.

static func _spark_material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(color.r * 1.25, color.g * 1.25, color.b * 1.25, 1.0)
	mat.albedo_texture = _soft_dot()
	mat.no_depth_test = false
	return mat

## Round soft-edged sprite so sparks read as glowing motes, not squares.
static func _soft_dot() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex

## Radial burst of glowing sparks that fade out.
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 24, speed: float = 4.0, size: float = 0.14, lifetime: float = 0.55, gravity: float = -6.0, upward: bool = false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: GPUParticles3D = GPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = amount
	p.lifetime = lifetime
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0 if upward else 180.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _spark_material(color)
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.get_tree().create_timer(lifetime + 0.3).timeout.connect(p.queue_free)

## Expanding glowing ring on the ground.
static func ring(parent: Node, at: Vector3, color: Color, radius: float = 2.2, time: float = 0.4) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 4
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.9)
	torus.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = torus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 0.1, 0)
	mi.scale = Vector3(0.2, 0.05, 0.2)
	var tween: Tween = mi.create_tween().set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(radius, 0.05, radius), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, time)
	tween.finished.connect(mi.queue_free)

## Golden column of light with rising sparkles for a level-up.
static func pillar(parent: Node, at: Vector3, color: Color = Color(1.0, 0.82, 0.35)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var beam: CylinderMesh = CylinderMesh.new()
	beam.top_radius = 0.55
	beam.bottom_radius = 0.75
	beam.height = 6.0
	beam.cap_top = false
	beam.cap_bottom = false
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r * 1.15, color.g * 1.0, color.b * 0.8, 0.5)
	beam.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = beam
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = at + Vector3(0, 3.0, 0)
	mi.scale = Vector3(0.2, 1, 0.2)
	var tween: Tween = mi.create_tween()
	tween.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tween.finished.connect(mi.queue_free)
	burst(parent, at + Vector3(0, 0.3, 0), color, 46, 5.0, 0.32, 1.4, 1.5, true)
	ring(parent, at, color, 3.0, 0.6)

## Named presets used by combat.
static func hit(parent: Node, at: Vector3, critical: bool = false) -> void:
	burst(parent, at, Color(1.0, 0.85, 0.5) if not critical else Color(1.0, 0.45, 0.15), 16 if not critical else 30, 5.0 if not critical else 7.0, 0.28 if not critical else 0.36)

static func fire(parent: Node, at: Vector3) -> void:
	burst(parent, at, Color(1.0, 0.38, 0.08), 40, 6.0, 0.42, 0.65, 2.0)
	ring(parent, at - Vector3(0, 0.9, 0), Color(1.0, 0.5, 0.15), 2.6)

static func ice(parent: Node, at: Vector3) -> void:
	burst(parent, at, Color(0.35, 0.75, 1.0), 34, 5.0, 0.34, 0.75, -3.0)
	ring(parent, at - Vector3(0, 0.9, 0), Color(0.6, 0.9, 1.0), 2.2)

static func heal(parent: Node, at: Vector3) -> void:
	burst(parent, at + Vector3(0, 0.2, 0), Color(0.3, 1.0, 0.45), 36, 2.5, 0.3, 1.1, 2.0, true)
	ring(parent, at, Color(0.5, 1.0, 0.6), 1.8, 0.5)

static func death(parent: Node, at: Vector3) -> void:
	burst(parent, at + Vector3(0, 0.6, 0), Color(0.65, 0.45, 1.0), 30, 3.0, 0.36, 0.9, 1.0, true)
