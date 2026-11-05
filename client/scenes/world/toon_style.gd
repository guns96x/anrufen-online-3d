class_name ToonStyle
extends RefCounted

## Anime-style look (cel lighting, coloured rim, ink outlines) applied to the
## materials of loaded models, plus the matching sky and grade for the town.

const OUTLINE_COLOR: Color = Color(0.09, 0.06, 0.08)
const RIM_TINT: float = 0.55

## Cel-shades every surface under root; characters also get an outline pass.
static func apply(root: Node, outline: bool = false, outline_width: float = 0.018) -> void:
	if DisplayServer.get_name() == "headless":
		return   # the dummy renderer rejects duplicated toon materials; nothing is drawn anyway
	var nodes: Array[Node] = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.append(root)
	for node: Node in nodes:
		if node is MeshInstance3D:
			var mi: MeshInstance3D = node
			if mi.mesh == null:
				continue
			for s: int in mi.mesh.get_surface_count():
				var toon: Material = _toon(mi.get_active_material(s), outline, outline_width)
				if toon:
					mi.set_surface_override_material(s, toon)
		elif node is MultiMeshInstance3D:
			var mm: MultiMesh = (node as MultiMeshInstance3D).multimesh
			if mm and mm.mesh:
				for s: int in mm.mesh.get_surface_count():
					var toon: Material = _toon(mm.mesh.surface_get_material(s), false, 0.0)
					if toon:
						mm.mesh.surface_set_material(s, toon)

static func _toon(source: Material, outline: bool, width: float) -> Material:
	var base: BaseMaterial3D = source as BaseMaterial3D
	if base == null or base.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or base.get_meta("toon", false):
		return null
	var mat: BaseMaterial3D = base.duplicate()
	mat.set_meta("toon", true)
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = maxf(mat.roughness, 0.55)
	mat.metallic = minf(mat.metallic, 0.2)
	mat.rim_enabled = true
	mat.rim = 0.6
	mat.rim_tint = RIM_TINT
	if outline and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		var ink: StandardMaterial3D = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = OUTLINE_COLOR
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = width
		ink.set_meta("toon", true)
		mat.next_pass = ink
	return mat

## Bright anime sky, punchier grade and bloom for the town scene.
static func grade(environment: Environment, sun: DirectionalLight3D) -> void:
	var sky: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("3d8ff0")
	sky.sky_horizon_color = Color("bfe3ff")
	sky.sky_curve = 0.18
	sky.ground_horizon_color = Color("bfe3ff")
	sky.ground_bottom_color = Color("4a7a52")
	sky.sun_angle_max = 25.0
	var s: Sky = Sky.new()
	s.sky_material = sky
	environment.sky = s
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.45
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.95
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.05
	environment.glow_bloom = 0.12
	environment.glow_hdr_threshold = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("cfe8ff")
	environment.fog_density = 0.0012
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.16
	environment.adjustment_saturation = 1.38
	if sun:
		sun.light_color = Color("fff1d6")
		sun.light_energy = 1.25
		sun.shadow_blur = 0.6
