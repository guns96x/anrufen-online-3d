class_name Atmosphere
extends Node3D

## Time of day and air for the town, in the anime style:
## - an anime sky (anime_sky.gdshader) with drifting clouds, sun or moon, stars;
## - a day cycle shared by every player (it follows the clock): morning, noon,
##   golden hour, dusk, a blue moonlit night, dawn. Lamps and braziers light up
##   at dusk;
## - aerial perspective: distant mountain ridges fade into blue haze;
## - air particles around the camera: petals and leaves by day, glowing pollen,
##   fireflies at night.
## Set COVENANT_TIME=0..1 to freeze the cycle (screenshots).

const CYCLE_SECONDS: float = 1440.0   # one in-game day = 24 real minutes

## [phase, sky top, horizon, sun colour, sun energy, elevation°, azimuth°,
##  ambient energy, fog colour, lamps 0..1, stars 0..1, exposure]
const KEYS: Array = [
	[0.00, Color("6fa8e8"), Color("ffd9c0"), Color("ffe2c4"), 1.0, 14.0, 80.0, 0.55, Color("f4dccc"), 0.15, 0.0, 0.95],
	[0.12, Color("3d8ff0"), Color("c4e6ff"), Color("fff3dc"), 1.25, 42.0, 120.0, 0.62, Color("d2eaff"), 0.0, 0.0, 0.95],
	[0.28, Color("2f86f2"), Color("bfe3ff"), Color("fff6e6"), 1.3, 62.0, 180.0, 0.65, Color("cfe8ff"), 0.0, 0.0, 0.95],
	[0.44, Color("5a86cc"), Color("ffb070"), Color("ffa050"), 1.2, 13.0, 245.0, 0.52, Color("ffc898"), 0.0, 0.0, 0.98],
	[0.52, Color("4a5aa8"), Color("ff9a7a"), Color("ff8a5a"), 0.75, 3.0, 262.0, 0.45, Color("e8a4a0"), 0.7, 0.1, 1.0],
	[0.58, Color("22306e"), Color("6a5aa8"), Color("aab8ff"), 0.45, 30.0, 70.0, 0.42, Color("5a68a8"), 1.0, 0.6, 1.05],
	[0.78, Color("101c48"), Color("34508e"), Color("b8c8ff"), 0.55, 50.0, 150.0, 0.45, Color("3e5288"), 1.0, 1.0, 1.08],
	[0.92, Color("1e2c66"), Color("6a6aa8"), Color("c0c8ff"), 0.45, 25.0, 230.0, 0.42, Color("6a70a8"), 1.0, 0.6, 1.05],
	[0.97, Color("5a78c8"), Color("ffb8a8"), Color("ffc8a8"), 0.7, 4.0, 75.0, 0.48, Color("f0b8b0"), 0.6, 0.1, 1.0],
	[1.00, Color("6fa8e8"), Color("ffd9c0"), Color("ffe2c4"), 1.0, 14.0, 80.0, 0.55, Color("f4dccc"), 0.15, 0.0, 0.95],
]

var environment: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var phase: float = 0.2
var fixed_phase: float = -1.0
var _lights: Array = []
var _bulbs: Array = []
var _air: Node3D
var _petals: GPUParticles3D
var _motes: GPUParticles3D
var _fireflies: GPUParticles3D

static func install(parent: Node3D, env: Environment, light: DirectionalLight3D) -> Atmosphere:
	var a: Atmosphere = Atmosphere.new()
	a.name = "Atmosphere"
	a.environment = env
	a.sun = light
	parent.add_child(a)
	return a

func _ready() -> void:
	var forced: String = OS.get_environment("COVENANT_TIME")
	if forced != "":
		fixed_phase = clampf(forced.to_float(), 0.0, 1.0)
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://client/shaders/anime_sky.gdshader")
	var s: Sky = Sky.new()
	s.sky_material = sky_mat
	s.process_mode = Sky.PROCESS_MODE_REALTIME if OS.has_feature("mobile") else Sky.PROCESS_MODE_AUTOMATIC
	s.radiance_size = Sky.RADIANCE_SIZE_64
	environment.sky = s
	environment.background_mode = Environment.BG_SKY
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.0075
	environment.fog_aerial_perspective = 0.85
	environment.fog_sky_affect = 0.0
	environment.fog_height = 6.0
	environment.fog_height_density = 0.02
	call_deferred("_collect_lights")
	_build_ridges()
	if DisplayServer.get_name() != "headless":
		_build_air()
	_apply(_current_phase())

func _collect_lights() -> void:
	for node: Node in get_parent().find_children("*", "OmniLight3D", true, false):
		var light: OmniLight3D = node
		_lights.append([light, light.light_energy])
	for node: Node in get_parent().find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if mi.mesh is SphereMesh and (mi.mesh as SphereMesh).material is StandardMaterial3D:
			var m: StandardMaterial3D = (mi.mesh as SphereMesh).material
			if m.emission_enabled and not _bulbs.has(m):
				_bulbs.append(m)

func _current_phase() -> float:
	if fixed_phase >= 0.0:
		return fixed_phase
	return fmod(Time.get_unix_time_from_system() / CYCLE_SECONDS, 1.0)

## True between dusk and dawn (NPC schedules, sounds).
func is_night() -> bool:
	return phase > 0.55 and phase < 0.95

func _sample(p: float) -> Array:
	p = clampf(p, 0.0, 0.9999)
	for i: int in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if p >= a[0] and p <= b[0]:
			var t: float = smoothstep(0.0, 1.0, (p - a[0]) / maxf(0.0001, b[0] - a[0]))
			var out: Array = [p]
			for k: int in range(1, a.size()):
				if a[k] is Color:
					out.append((a[k] as Color).lerp(b[k], t))
				elif k == 6:
					out.append(lerp_angle(deg_to_rad(a[k]), deg_to_rad(b[k]), t))
				else:
					out.append(lerpf(a[k], b[k], t))
			return out
	return KEYS[0]

func _apply(p: float) -> void:
	phase = p
	var k: Array = _sample(p)
	var top: Color = k[1]
	var horizon: Color = k[2]
	var sun_col: Color = k[3]
	var elevation: float = deg_to_rad(float(k[5]))
	var azimuth: float = float(k[6])
	var dir: Vector3 = Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation))
	if sun:
		sun.light_color = sun_col
		sun.light_energy = float(k[4])
		sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	var night: float = float(k[10])
	sky_mat.set_shader_parameter("top_color", top)
	sky_mat.set_shader_parameter("horizon_color", horizon)
	sky_mat.set_shader_parameter("ground_color", horizon.darkened(0.35))
	sky_mat.set_shader_parameter("sun_color", sun_col)
	sky_mat.set_shader_parameter("celestial_dir", dir)
	sky_mat.set_shader_parameter("star_amount", night)
	sky_mat.set_shader_parameter("sun_size", lerpf(0.035, 0.022, night))
	sky_mat.set_shader_parameter("glow_amount", lerpf(0.75, 0.25, night))
	sky_mat.set_shader_parameter("cloud_light", Color.WHITE.lerp(sun_col, 0.35).lerp(Color("8a9ac8"), night * 0.7))
	sky_mat.set_shader_parameter("cloud_shadow", horizon.lerp(top, 0.4).darkened(0.08))
	environment.ambient_light_energy = float(k[7])
	environment.fog_light_color = k[8]
	environment.tonemap_exposure = float(k[11])
	# Night grade: cooler and calmer, so roofs and cloth stop shouting.
	environment.adjustment_saturation = lerpf(1.38, 0.95, night)
	environment.adjustment_brightness = lerpf(1.0, 0.9, night)
	environment.ambient_light_sky_contribution = lerpf(0.45, 0.8, night)
	var lamps: float = float(k[9])
	for pair: Array in _lights:
		if is_instance_valid(pair[0]):
			(pair[0] as OmniLight3D).light_energy = float(pair[1]) * lerpf(0.25, 2.0, lamps)
			(pair[0] as OmniLight3D).visible = lamps > 0.05
	for m: StandardMaterial3D in _bulbs:
		m.emission_energy_multiplier = lerpf(1.2, 6.0, lamps)
	if _petals:
		_petals.amount_ratio = 1.0 - night
		_motes.amount_ratio = 1.0 - night * 0.8
		_fireflies.amount_ratio = night
		_fireflies.emitting = night > 0.05

var _accum: float = 0.0
func _process(delta: float) -> void:
	_accum += delta
	if _accum > 0.25:
		_accum = 0.0
		_apply(_current_phase())
	var cam: Camera3D = get_viewport().get_camera_3d()
	if _air and cam:
		_air.global_position = cam.global_position

# ------------------------------------------------------------ Distance ---

## Three rings of low-poly ridges far outside the palisade; the fog's aerial
## perspective turns the far ones into pale blue silhouettes.
func _build_ridges() -> void:
	var rings: Array = [[150.0, 18.0, Color("4f7a5a"), 7], [210.0, 34.0, Color("4a6a72"), 5], [300.0, 60.0, Color("5a6e8a"), 4]]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7071
	for ring: Array in rings:
		var radius: float = ring[0]
		var height: float = ring[1]
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments: int = 96
		var heights: PackedFloat32Array = PackedFloat32Array()
		var phase_a: float = rng.randf() * TAU
		for i: int in segments + 1:
			var a: float = float(i % segments) / segments * TAU
			var hgt: float = height * (0.55 + 0.3 * sin(a * float(ring[3]) + phase_a) + 0.25 * sin(a * 13.0 + phase_a * 2.0) * rng.randf_range(0.6, 1.0))
			heights.append(maxf(height * 0.2, hgt))
		heights[segments] = heights[0]
		var centre: Vector3 = Vector3(0, 0, GuanlinLayout.TOWN_Z)
		for i: int in segments:
			var a0: float = float(i) / segments * TAU
			var a1: float = float(i + 1) / segments * TAU
			var p0: Vector3 = centre + Vector3(sin(a0), 0, cos(a0)) * radius
			var p1: Vector3 = centre + Vector3(sin(a1), 0, cos(a1)) * radius
			var t0: Vector3 = p0 + Vector3(0, heights[i], 0)
			var t1: Vector3 = p1 + Vector3(0, heights[i + 1], 0)
			p0.y = -2.0
			p1.y = -2.0
			for v: Vector3 in [p0, t0, t1, p0, t1, p1]:
				st.set_normal((centre - v).normalized() + Vector3.UP * 0.6)
				st.add_vertex(v)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = st.commit()
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = ring[2]
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

# ----------------------------------------------------------------- Air ---

func _air_particles(color: Color, amount: int, size: float, extents: Vector3, gravity: Vector3, spin: bool, glow: bool) -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.gravity = gravity
	pm.direction = Vector3(1, 0, 0.3)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.2
	pm.turbulence_noise_scale = 4.0
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	if spin:
		pm.angular_velocity_min = -120.0
		pm.angular_velocity_max = 120.0
		pm.angle_min = 0.0
		pm.angle_max = 360.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var fade: Gradient = Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.85, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var ramp: GradientTexture1D = GradientTexture1D.new()
	ramp.gradient = fade
	pm.color_ramp = ramp
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size * (0.7 if spin else 1.0))
	if glow:
		quad.material = Vfx._spark_material(color)
	else:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = color
		m.albedo_texture = Vfx._soft_dot()
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_air.add_child(p)
	return p

func _build_air() -> void:
	_air = Node3D.new()
	_air.top_level = true
	add_child(_air)
	_petals = _air_particles(Color(1.0, 0.82, 0.88), 46, 0.12, Vector3(14, 5, 14), Vector3(0.25, -0.35, 0.1), true, false)
	_petals.position.y = 3.0
	_motes = _air_particles(Color(1.0, 0.95, 0.7), 34, 0.06, Vector3(12, 3, 12), Vector3(0, 0.05, 0), false, true)
	_motes.position.y = 1.5
	_fireflies = _air_particles(Color(0.75, 1.0, 0.45), 48, 0.09, Vector3(16, 2, 16), Vector3(0, 0.02, 0), false, true)
	_fireflies.position.y = 1.2
	_fireflies.emitting = false
