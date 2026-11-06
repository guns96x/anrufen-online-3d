class_name WorldPerf
extends RefCounted

## Phone-friendly rendering for the town, measured on the Guanlin scene:
## before: ~750 draw calls, ~900k triangles a frame (half of both was the sun's
## shadow pass, a third of the calls were NPCs drawn with outlines and shadows).
## - the sun's shadow only covers the 32 m around the camera, in two splits;
## - grass, flowers, small props never cast shadows;
## - NPCs, monsters and other players get a soft blob shadow instead of a real
##   one, fade out past 55 m, and stop animating while off screen;
## - buildings, trees and props fade out past the fog line.

const NPC_RANGE: float = 55.0
const PROP_RANGE: float = 90.0
const SMALL: float = 2.5

static func tune_world(world: Node3D, sun: DirectionalLight3D) -> void:
	if sun:
		sun.directional_shadow_max_distance = 32.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_fade_start = 0.75
	for name: String in ["WorldDecor", "VillagePresentation"]:
		var root: Node = world.get_node_or_null(name)
		if root == null:
			continue
		for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
			var g: GeometryInstance3D = node
			var size: float = g.get_aabb().get_longest_axis_size() * g.global_transform.basis.get_scale().x
			if g is MultiMeshInstance3D:
				# Grass, flowers, fence posts, trees: only big instances shade.
				var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
				if mm and mm.mesh and mm.mesh.get_aabb().get_longest_axis_size() < SMALL * 1.6:
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				continue
			if size < SMALL:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				g.visibility_range_end = PROP_RANGE * 0.6
			else:
				g.visibility_range_end = PROP_RANGE * 2.0
			g.visibility_range_end_margin = 6.0
			g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF

## A character other than the local hero: blob shadow, distance fade, and no
## animation while off screen.
static func tune_character(body: Node3D, visual: Node3D, radius: float = 0.55) -> void:
	if visual == null:
		return
	for node: Node in visual.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = node
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = NPC_RANGE
		g.visibility_range_end_margin = 5.0
		g.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	if body.get_node_or_null("BlobShadow") == null:
		var blob: MeshInstance3D = MeshInstance3D.new()
		blob.name = "BlobShadow"
		var quad: PlaneMesh = PlaneMesh.new()
		quad.size = Vector2(radius * 2.0, radius * 2.0)
		quad.material = _blob()
		blob.mesh = quad
		blob.position.y = 0.04
		blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blob.visibility_range_end = NPC_RANGE * 0.7
		body.add_child(blob)
	if body.get_node_or_null("AnimCulling") == null:
		var notifier: VisibleOnScreenNotifier3D = VisibleOnScreenNotifier3D.new()
		notifier.name = "AnimCulling"
		notifier.aabb = AABB(Vector3(-0.8, 0.0, -0.8), Vector3(1.6, 2.6, 1.6))
		body.add_child(notifier)
		notifier.screen_entered.connect(_set_animated.bind(visual, true))
		notifier.screen_exited.connect(_set_animated.bind(visual, false))

static func _set_animated(visual: Node3D, on: bool) -> void:
	if not is_instance_valid(visual):
		return
	for node: Node in visual.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).active = on
	for node: Node in visual.find_children("*", "SkeletonModifier3D", true, false):
		(node as SkeletonModifier3D).active = on
	for node: Node in visual.find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).emitting = on

static func _blob() -> StandardMaterial3D:
	if true:
		var g: Gradient = Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.5), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0)])
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = -1
		return mat
	return null
