class_name Proportions
extends SkeletonModifier3D

## Runs after the AnimationPlayer each frame and reshapes KayKit's chibi body into
## slimmer anime proportions: smaller head, longer legs, narrower or broader
## shoulders. Works on any clip because it scales the animated pose, not the rest.

const LOOK: Dictionary = {
	# name: [head, legs, torso, shoulders, hips, arms, hands, waist]
	"hero": [0.66, 1.65, 1.12, 1.0, 1.0, 1.3, 0.8, 0.94],
	"heroine": [0.64, 1.75, 1.1, 0.86, 1.06, 1.3, 0.72, 0.84],
	"man": [0.7, 1.5, 1.1, 1.0, 1.0, 1.25, 0.82, 0.96],
	"woman": [0.66, 1.65, 1.08, 0.84, 1.08, 1.28, 0.72, 0.84],
	"brute": [0.64, 1.4, 1.18, 1.2, 1.05, 1.25, 0.95, 1.05],
	"child": [0.9, 1.05, 1.0, 1.0, 1.0, 1.0, 0.9, 1.0],
}

var head: float = 1.0
var legs: float = 1.0
var torso: float = 1.0
var shoulders: float = 1.0
var hips_w: float = 1.0
var arms: float = 1.0
var hands: float = 1.0
var waist: float = 1.0
var _bones: Dictionary = {}

## Adds the modifier to the model's skeleton and returns how much taller the
## figure became, so callers can keep feet on the ground (the hips bone is raised).
static func apply(model: Node, look: String) -> Proportions:
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null or not LOOK.has(look):
		return null
	for c: Node in skel.get_children():
		if c is Proportions:
			c.queue_free()
	var p: Proportions = Proportions.new()
	var v: Array = LOOK[look]
	p.head = v[0]
	p.legs = v[1]
	p.torso = v[2]
	p.shoulders = v[3]
	p.hips_w = v[4]
	p.arms = v[5]
	p.hands = v[6]
	p.waist = v[7]
	p.name = "Proportions"
	skel.add_child(p)
	return p

func _ready() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null:
		return
	for b: String in ["hips", "spine", "chest", "head", "upperarm.l", "upperarm.r", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "foot.l", "foot.r", "lowerarm.l", "lowerarm.r", "wrist.l", "wrist.r", "hand.l", "hand.r"]:
		_bones[b] = skel.find_bone(b)

func _id(b: String) -> int:
	return int(_bones.get(b, -1))

func _process_modification() -> void:
	var skel: Skeleton3D = get_skeleton()
	if skel == null or _bones.is_empty():
		return
	# Head: uniform shrink (hats and helmets follow, they hang off this bone).
	var h: int = _id("head")
	if h >= 0:
		skel.set_bone_pose_scale(h, skel.get_bone_pose_scale(h) * head)
	# Torso: stretch spine along its length, then undo at the chest so arms and
	# head keep their shape.
	var sp: int = _id("spine")
	var ch: int = _id("chest")
	if sp >= 0 and ch >= 0 and torso != 1.0:
		skel.set_bone_pose_position(ch, skel.get_bone_pose_position(ch) * torso)
	# Waist: thin the spine sideways and undo it at the chest.
	if sp >= 0 and ch >= 0 and waist != 1.0:
		var w: Vector3 = Vector3(waist, 1.0, waist * 0.5 + 0.5)
		skel.set_bone_pose_scale(sp, skel.get_bone_pose_scale(sp) * w)
		skel.set_bone_pose_scale(ch, skel.get_bone_pose_scale(ch) / w)
	# Shoulders: push the upper arms out or in.
	for side: String in ["l", "r"]:
		var ua: int = _id("upperarm." + side)
		if ua >= 0 and shoulders != 1.0:
			var pos: Vector3 = skel.get_bone_pose_position(ua)
			pos.x *= shoulders
			skel.set_bone_pose_position(ua, pos)
		for b: String in ["lowerarm." + side, "wrist." + side]:
			var ai: int = _id(b)
			if ai >= 0 and arms != 1.0:
				skel.set_bone_pose_position(ai, skel.get_bone_pose_position(ai) * arms)
		var hd: int = _id("hand." + side)
		if hd >= 0 and hands != 1.0:
			skel.set_bone_pose_scale(hd, skel.get_bone_pose_scale(hd) * hands)
		var ul: int = _id("upperleg." + side)
		if ul >= 0 and hips_w != 1.0:
			var lp: Vector3 = skel.get_bone_pose_position(ul)
			lp.x *= hips_w
			skel.set_bone_pose_position(ul, lp)
		# Legs: lengthen by moving knee and ankle further along each bone.
		for b: String in ["lowerleg." + side, "foot." + side]:
			var id: int = _id(b)
			if id >= 0 and legs != 1.0:
				skel.set_bone_pose_position(id, skel.get_bone_pose_position(id) * legs)
	# Raise the hips by the extra leg length so the feet stay on the floor.
	var hp: int = _id("hips")
	var ul0: int = _id("upperleg.l")
	var ll0: int = _id("lowerleg.l")
	var ft0: int = _id("foot.l")
	if hp >= 0 and ll0 >= 0 and ft0 >= 0 and legs != 1.0:
		var extra: float = (skel.get_bone_rest(ll0).origin.length() + skel.get_bone_rest(ft0).origin.length()) * (legs - 1.0)
		var hpos: Vector3 = skel.get_bone_pose_position(hp)
		hpos.y += extra
		skel.set_bone_pose_position(hp, hpos)
