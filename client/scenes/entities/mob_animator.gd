class_name MobAnimator
extends Node

## Drives a rigged enemy model from Monster state: idle/walk/run by speed and
## one-shot attack, hit and death clips. Clip names come from the rig family.

const RIGS: Dictionary = {
	"kaykit": {"idle": "Idle", "walk": "Walking_A", "run": "Running_A", "attack": ["1H_Melee_Attack_Stab", "Dualwield_Melee_Attack_Slice", "1H_Melee_Attack_Chop"], "hit": "Hit_A", "death": "Death_A", "dead": "Death_A_Pose"},
}

var monster: Monster
var anim: AnimationPlayer
var clips: Dictionary
var _action_left: float = 0.0
var _combo: int = 0
var _dead: bool = false

static func attach(owner_monster: Monster, rig: String = "kaykit") -> MobAnimator:
	var animator: MobAnimator = MobAnimator.new()
	animator.monster = owner_monster
	animator.clips = RIGS[rig]
	animator.anim = owner_monster.visual_root.find_child("AnimationPlayer", true, false)
	owner_monster.add_child(animator)
	owner_monster.animator = animator
	# Rigged humanoids are taller than the old beasts: lift name and health above the head.
	owner_monster.name_label.position.y = 2.75
	owner_monster.hp_bar_3d.position.y = 2.5
	for loop: String in [animator.clips["idle"], animator.clips["walk"], animator.clips["run"], animator.clips["dead"]]:
		if animator.anim and animator.anim.has_animation(loop):
			animator.anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	return animator

func _one_shot(name: String, speed: float = 1.0) -> void:
	if anim == null or not anim.has_animation(name):
		return
	anim.play(name, 0.08, speed)
	anim.seek(0.0, true)
	_action_left = anim.get_animation(name).length / speed * 0.9

func attack(windup: float) -> void:
	var pool: Array = clips["attack"]
	var name: String = pool[_combo % pool.size()]
	_combo += 1
	if anim and anim.has_animation(name):
		# Stretch the strike so its hit frame lands when the windup resolves.
		_one_shot(name, clampf(anim.get_animation(name).length * 0.55 / maxf(windup, 0.1), 0.6, 2.0))

func hit() -> void:
	if not _dead and _action_left <= 0.0:
		_one_shot(clips["hit"], 1.5)

func die() -> void:
	_dead = true
	_one_shot(clips["death"], 1.0)

func revive() -> void:
	_dead = false
	_action_left = 0.0
	if anim: anim.play(clips["idle"], 0.05)

func _process(delta: float) -> void:
	if anim == null:
		return
	if _action_left > 0.0:
		_action_left -= delta
		return
	if _dead:
		if anim.current_animation != clips["dead"] and anim.has_animation(clips["dead"]):
			anim.play(clips["dead"], 0.0)
		return
	var speed: float = Vector2(monster.velocity.x, monster.velocity.z).length()
	var clip: String = clips["run"] if speed > 2.6 else clips["walk"] if speed > 0.3 else clips["idle"]
	if anim.current_animation != clip:
		anim.play(clip, 0.15)
