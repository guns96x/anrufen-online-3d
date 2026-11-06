"""character_animation.py - Humanoid rig and animation clip authoring for Blender 4.x / 5.x.

Creates standard Godot SkeletonProfileHumanoid armature (with handslot.l and handslot.r),
authors the 20 shared handoff clips + per-character Idle_Character, and manages
NLA tracks with Blender 5.x layered Action compatibility.
"""

from __future__ import annotations
import math
from typing import Dict, List, Tuple, Optional, Any

try:
    import bpy
    import mathutils
except ImportError:
    bpy = None
    mathutils = None


# ==============================================================================
# 1. BONE HIERARCHY & REST SPECIFICATION (1.80m A-POSE HUMANOID)
# ==============================================================================

# Godot SkeletonProfileHumanoid + weapon slots
BONE_HIERARCHY: Dict[str, Optional[str]] = {
    'Hips': None,
    'Spine': 'Hips',
    'Chest': 'Spine',
    'UpperChest': 'Chest',
    'Neck': 'UpperChest',
    'Head': 'Neck',
    'LeftShoulder': 'UpperChest',
    'LeftUpperArm': 'LeftShoulder',
    'LeftLowerArm': 'LeftUpperArm',
    'LeftHand': 'LeftLowerArm',
    'handslot.l': 'LeftHand',
    'RightShoulder': 'UpperChest',
    'RightUpperArm': 'RightShoulder',
    'RightLowerArm': 'RightUpperArm',
    'RightHand': 'RightLowerArm',
    'handslot.r': 'RightHand',
    'LeftUpperLeg': 'Hips',
    'LeftLowerLeg': 'LeftUpperLeg',
    'LeftFoot': 'LeftLowerLeg',
    'LeftToes': 'LeftFoot',
    'RightUpperLeg': 'Hips',
    'RightLowerLeg': 'RightUpperLeg',
    'RightFoot': 'RightLowerLeg',
    'RightToes': 'RightFoot',
}

# Standard 1.80m A-pose joint coordinates (Head, Tail, Roll)
# Facing Blender -Y, +Z Up, floor at Z=0
BONE_REST_POSITIONS: Dict[str, Tuple[Tuple[float, float, float], Tuple[float, float, float], float]] = {
    # Torso column
    'Hips': ((0.0, 0.0, 0.98), (0.0, 0.0, 1.08), 0.0),
    'Spine': ((0.0, 0.0, 1.08), (0.0, 0.0, 1.20), 0.0),
    'Chest': ((0.0, 0.0, 1.20), (0.0, 0.0, 1.35), 0.0),
    'UpperChest': ((0.0, 0.0, 1.35), (0.0, 0.0, 1.48), 0.0),
    'Neck': ((0.0, 0.0, 1.48), (0.0, 0.0, 1.58), 0.0),
    'Head': ((0.0, 0.0, 1.58), (0.0, 0.0, 1.80), 0.0),

    # Left Arm (A-pose ~35 deg down)
    'LeftShoulder': ((0.04, 0.0, 1.45), (0.16, 0.0, 1.45), 0.0),
    'LeftUpperArm': ((0.16, 0.0, 1.45), (0.42, 0.02, 1.22), 0.0),
    'LeftLowerArm': ((0.42, 0.02, 1.22), (0.66, 0.04, 1.00), 0.0),
    'LeftHand': ((0.66, 0.04, 1.00), (0.76, 0.04, 0.92), 0.0),
    'handslot.l': ((0.76, 0.02, 0.92), (0.76, -0.12, 0.92), 0.0),

    # Right Arm (A-pose ~35 deg down)
    'RightShoulder': ((-0.04, 0.0, 1.45), (-0.16, 0.0, 1.45), 0.0),
    'RightUpperArm': ((-0.16, 0.0, 1.45), (-0.42, 0.02, 1.22), 0.0),
    'RightLowerArm': ((-0.42, 0.02, 1.22), (-0.66, 0.04, 1.00), 0.0),
    'RightHand': ((-0.66, 0.04, 1.00), (-0.76, 0.04, 0.92), 0.0),
    'handslot.r': ((-0.76, 0.02, 0.92), (-0.76, -0.12, 0.92), 0.0),

    # Left Leg
    'LeftUpperLeg': ((0.12, 0.0, 0.95), (0.12, -0.01, 0.52), 0.0),
    'LeftLowerLeg': ((0.12, -0.01, 0.52), (0.12, 0.0, 0.10), 0.0),
    'LeftFoot': ((0.12, 0.0, 0.10), (0.12, -0.12, 0.03), 0.0),
    'LeftToes': ((0.12, -0.12, 0.03), (0.12, -0.18, 0.0), 0.0),

    # Right Leg
    'RightUpperLeg': ((-0.12, 0.0, 0.95), (-0.12, -0.01, 0.52), 0.0),
    'RightLowerLeg': ((-0.12, -0.01, 0.52), (-0.12, 0.0, 0.10), 0.0),
    'RightFoot': ((-0.12, 0.0, 0.10), (-0.12, -0.12, 0.03), 0.0),
    'RightToes': ((-0.12, -0.12, 0.03), (-0.12, -0.18, 0.0), 0.0),
}


# ==============================================================================
# 2. QUATERNION & ROTATION MATH
# ==============================================================================

def euler_to_quaternion(pitch_x_deg: float, roll_y_deg: float, yaw_z_deg: float) -> Tuple[float, float, float, float]:
    """Converts Euler angles in degrees (XYZ order) to a unit quaternion (w, x, y, z)."""
    if mathutils is not None:
        return tuple(mathutils.Euler(tuple(math.radians(x) for x in
                     (pitch_x_deg, roll_y_deg, yaw_z_deg)), 'XYZ').to_quaternion())
    rx = math.radians(pitch_x_deg) * 0.5
    ry = math.radians(roll_y_deg) * 0.5
    rz = math.radians(yaw_z_deg) * 0.5

    cx, sx = math.cos(rx), math.sin(rx)
    cy, sy = math.cos(ry), math.sin(ry)
    cz, sz = math.cos(rz), math.sin(rz)

    w = cx * cy * cz - sx * sy * sz
    x = sx * cy * cz + cx * sy * sz
    y = cx * sy * cz - sx * cy * sz
    z = cx * cy * sz + sx * sy * cz

    l = math.sqrt(w * w + x * x + y * y + z * z)
    if l > 1e-7:
        return (w / l, x / l, y / l, z / l)
    return (1.0, 0.0, 0.0, 0.0)


# ==============================================================================
# 3. BLENDER ARMATURE BUILDER
# ==============================================================================

def create_humanoid_armature(armature_name: str = "Armature") -> Any:
    """Builds and returns the shared humanoid armature object in Blender."""
    if bpy is None:
        return None

    arm_data = bpy.data.armatures.new(armature_name)
    arm_obj = bpy.data.objects.new(armature_name, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj

    # Enter Edit Mode
    bpy.ops.object.mode_set(mode='EDIT')
    edit_bones = arm_data.edit_bones

    for bone_name, (head, tail, roll) in BONE_REST_POSITIONS.items():
        eb = edit_bones.new(bone_name)
        eb.head = head
        eb.tail = tail
        eb.roll = roll
        eb.use_deform = True

    # Assign hierarchy
    for bone_name, parent_name in BONE_HIERARCHY.items():
        if parent_name and parent_name in edit_bones:
            edit_bones[bone_name].parent = edit_bones[parent_name]

    # Return to Object Mode
    bpy.ops.object.mode_set(mode='OBJECT')

    # Initialize Pose Bones rotation mode
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = 'QUATERNION'

    return arm_obj


# ==============================================================================
# 4. KEYFRAME SETTER & ACTION UTILITIES
# ==============================================================================

def set_bone_pose(arm_obj: Any, bone_name: str, frame: int,
                  rot_quat: Optional[Tuple[float, float, float, float]] = None,
                  loc: Optional[Tuple[float, float, float]] = None) -> None:
    """Sets pose bone quaternion and location keyframes."""
    if bpy is None or arm_obj is None:
        return
    if bone_name not in arm_obj.pose.bones:
        return
    pb = arm_obj.pose.bones[bone_name]

    if rot_quat is not None:
        # Authors specify character/world axes, not each bone's rolled local axes.
        rest = pb.bone.matrix_local.to_quaternion()
        pb.rotation_quaternion = rest.inverted() @ mathutils.Quaternion(rot_quat) @ rest
        pb.keyframe_insert(data_path="rotation_quaternion", frame=frame)

    if loc is not None:
        pb.location = pb.bone.matrix_local.to_3x3().inverted() @ mathutils.Vector(loc)
        pb.keyframe_insert(data_path="location", frame=frame)


def push_action_to_nla(arm_obj: Any, action: Any, track_name: str) -> None:
    """Pushes an Action onto its own NLA track with Blender 5.x layered slot support."""
    if bpy is None or arm_obj is None or action is None:
        return

    anim_data = arm_obj.animation_data
    if not anim_data:
        anim_data = arm_obj.animation_data_create()

    track = anim_data.nla_tracks.new()
    track.name = track_name
    track.mute = True

    # Determine strip start frame
    start_frame = int(action.frame_range[0])
    strip = track.strips.new(track_name, start_frame, action)
    strip.name = track_name

    # Blender 5 layered action slot assignment
    if hasattr(strip, "action_slot") and hasattr(action, "slots") and len(action.slots) > 0:
        strip.action_slot = action.slots[0]

    # Clear active action so NLA tracks evaluate properly
    arm_obj.animation_data.action = None


# ==============================================================================
# 5. AUTHORS OF ALL 20 SHARED CLIPS + IDLE_CHARACTER
# ==============================================================================

def create_action(arm_obj: Any, name: str) -> Any:
    if bpy is None:
        return None
    action = bpy.data.actions.new(name=name)
    if not arm_obj.animation_data:
        arm_obj.animation_data_create()
    arm_obj.animation_data.action = action
    # Every clip starts from its own rest state. Otherwise untouched bones retain
    # the preceding clip's pose and NLA stacks can contaminate sampled exports.
    for track in arm_obj.animation_data.nla_tracks:
        track.mute = True
    for pb in arm_obj.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
        pb.keyframe_insert(data_path='rotation_quaternion', frame=1)
        pb.keyframe_insert(data_path='location', frame=1)
    return action


def author_idle(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Idle")
    # 60 frames (2.0s), gentle breathing cycle
    for f in (1, 30, 60):
        t = 1.0 if f == 30 else 0.0
        # Subtle chest rise/fall
        chest_pitch = 1.5 * t
        spine_pitch = 0.5 * t
        head_pitch = -0.8 * t
        set_bone_pose(arm_obj, 'Chest', f, euler_to_quaternion(chest_pitch, 0, 0))
        set_bone_pose(arm_obj, 'Spine', f, euler_to_quaternion(spine_pitch, 0, 0))
        set_bone_pose(arm_obj, 'Head', f, euler_to_quaternion(head_pitch, 0, 0))
        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(0, 0, 0), (0, 0, 0.005 * t))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(0, 39, -3))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(0, -39, 3))
    return action


def author_walking_a(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Walking_A")
    # 30 frames (1.0s) contact walk cycle
    for f in range(1, 32):
        phase = (f - 1) / 30.0 * 2.0 * math.pi
        leg_l = math.sin(phase) * 25.0
        leg_r = -leg_l
        arm_l = -leg_l * 0.8
        arm_r = -arm_l

        # Hips vertical bounce
        bounce = math.cos(phase * 2.0) * 0.015

        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(0, math.sin(phase) * 3.0, 0), (0, 0, bounce))
        set_bone_pose(arm_obj, 'LeftUpperLeg', f, euler_to_quaternion(leg_l, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperLeg', f, euler_to_quaternion(leg_r, 0, 0))
        set_bone_pose(arm_obj, 'LeftLowerLeg', f, euler_to_quaternion(max(0.0, -leg_l * 0.9), 0, 0))
        set_bone_pose(arm_obj, 'RightLowerLeg', f, euler_to_quaternion(max(0.0, -leg_r * 0.9), 0, 0))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(arm_l, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(arm_r, 0, 0))
    return action


def author_running_a(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Running_A")
    # 20 frames (0.66s) dynamic sprint
    for f in range(1, 22):
        phase = (f - 1) / 20.0 * 2.0 * math.pi
        leg_l = math.sin(phase) * 45.0
        leg_r = -leg_l
        arm_l = -leg_l * 1.1
        arm_r = -arm_l
        bounce = math.cos(phase * 2.0) * 0.035

        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(12.0, 0, 0), (0, 0, bounce))
        set_bone_pose(arm_obj, 'Spine', f, euler_to_quaternion(8.0, 0, 0))
        set_bone_pose(arm_obj, 'LeftUpperLeg', f, euler_to_quaternion(leg_l, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperLeg', f, euler_to_quaternion(leg_r, 0, 0))
        set_bone_pose(arm_obj, 'LeftLowerLeg', f, euler_to_quaternion(max(0.0, -leg_l * 1.2), 0, 0))
        set_bone_pose(arm_obj, 'RightLowerLeg', f, euler_to_quaternion(max(0.0, -leg_r * 1.2), 0, 0))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(arm_l, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(arm_r, 0, 0))
    return action


def author_1h_slice_diag(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "1H_Melee_Attack_Slice_Diagonal")
    # Frames: 1 Ready -> 10 Windup -> 16 Slash -> 22 Hold -> 30 Recover
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 10, euler_to_quaternion(-60, 25, 45))  # Raised back
    set_bone_pose(arm_obj, 'Spine', 10, euler_to_quaternion(0, 0, -20))
    set_bone_pose(arm_obj, 'RightUpperArm', 16, euler_to_quaternion(45, -35, -55))  # Slashed across
    set_bone_pose(arm_obj, 'Spine', 16, euler_to_quaternion(10, 0, 30))
    set_bone_pose(arm_obj, 'RightUpperArm', 30, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Spine', 30, euler_to_quaternion(0, 0, 0))
    return action


def author_1h_chop(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "1H_Melee_Attack_Chop")
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 10, euler_to_quaternion(-85, 0, 10))  # High overhead
    set_bone_pose(arm_obj, 'Chest', 10, euler_to_quaternion(-15, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 15, euler_to_quaternion(60, 0, -10))  # Slam down
    set_bone_pose(arm_obj, 'Chest', 15, euler_to_quaternion(20, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 30, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Chest', 30, euler_to_quaternion(0, 0, 0))
    return action


def author_1h_slice_horiz(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "1H_Melee_Attack_Slice_Horizontal")
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 8, euler_to_quaternion(0, 45, 65))
    set_bone_pose(arm_obj, 'Spine', 8, euler_to_quaternion(0, 0, -35))
    set_bone_pose(arm_obj, 'RightUpperArm', 15, euler_to_quaternion(0, -45, -70))
    set_bone_pose(arm_obj, 'Spine', 15, euler_to_quaternion(0, 0, 45))
    set_bone_pose(arm_obj, 'RightUpperArm', 30, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Spine', 30, euler_to_quaternion(0, 0, 0))
    return action


def author_1h_stab(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "1H_Melee_Attack_Stab")
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 8, euler_to_quaternion(25, 0, 15))
    set_bone_pose(arm_obj, 'RightLowerArm', 8, euler_to_quaternion(60, 0, 0))
    # Thrust forward
    set_bone_pose(arm_obj, 'RightUpperArm', 14, euler_to_quaternion(-75, 0, -5))
    set_bone_pose(arm_obj, 'RightLowerArm', 14, euler_to_quaternion(5, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 30, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightLowerArm', 30, euler_to_quaternion(0, 0, 0))
    return action


def author_2h_idle(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "2H_Melee_Idle")
    for f in (1, 20, 40):
        t = 1.0 if f == 20 else 0.0
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(-35 + 2 * t, 0, -30))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(-35 + 2 * t, 0, 30))
        set_bone_pose(arm_obj, 'Chest', f, euler_to_quaternion(5 + 1.5 * t, 0, 0))
    return action


def author_2h_slice(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "2H_Melee_Attack_Slice")
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 12, euler_to_quaternion(-50, 40, 50))
    set_bone_pose(arm_obj, 'LeftUpperArm', 12, euler_to_quaternion(-40, 20, 40))
    set_bone_pose(arm_obj, 'Spine', 12, euler_to_quaternion(0, 0, -40))
    set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(40, -40, -60))
    set_bone_pose(arm_obj, 'LeftUpperArm', 20, euler_to_quaternion(30, -20, -50))
    set_bone_pose(arm_obj, 'Spine', 20, euler_to_quaternion(10, 0, 40))
    set_bone_pose(arm_obj, 'RightUpperArm', 40, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'LeftUpperArm', 40, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Spine', 40, euler_to_quaternion(0, 0, 0))
    return action


def author_2h_chop(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "2H_Melee_Attack_Chop")
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 12, euler_to_quaternion(-85, 0, 15))
    set_bone_pose(arm_obj, 'LeftUpperArm', 12, euler_to_quaternion(-85, 0, -15))
    set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(65, 0, -10))
    set_bone_pose(arm_obj, 'LeftUpperArm', 20, euler_to_quaternion(65, 0, 10))
    set_bone_pose(arm_obj, 'RightUpperArm', 40, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'LeftUpperArm', 40, euler_to_quaternion(0, 0, 0))
    return action


def author_2h_spin(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "2H_Melee_Attack_Spin")
    # Whirlwind 360 rotation
    for f in range(1, 47):
        t = (f - 1) / 45.0
        yaw = t * 360.0
        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(0, 0, yaw))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(-30, 0, -70))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(-30, 0, 70))
    return action


def author_spellcast_shoot(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Spellcast_Shoot")
    # 35 frames: Channel -> Release -> Savor
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 12, euler_to_quaternion(-20, 20, 40))  # Charge
    set_bone_pose(arm_obj, 'LeftUpperArm', 12, euler_to_quaternion(-30, -10, -20))
    set_bone_pose(arm_obj, 'RightUpperArm', 18, euler_to_quaternion(-75, 0, -10))  # Thrust blast
    set_bone_pose(arm_obj, 'Chest', 18, euler_to_quaternion(-8, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 35, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'LeftUpperArm', 35, euler_to_quaternion(0, 0, 0))
    return action


def author_dodge_forward(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Dodge_Forward")
    # Quick combat roll/dash forward
    set_bone_pose(arm_obj, 'Hips', 1, euler_to_quaternion(0, 0, 0), (0, 0, 0))
    set_bone_pose(arm_obj, 'Hips', 12, euler_to_quaternion(180, 0, 0), (0, -0.6, -0.35))
    set_bone_pose(arm_obj, 'Hips', 25, euler_to_quaternion(360, 0, 0), (0, -1.2, 0))
    return action


def author_hit_a(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Hit_A")
    # 15 frames sharp flinch
    set_bone_pose(arm_obj, 'Chest', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Chest', 5, euler_to_quaternion(-25, 0, 0))
    set_bone_pose(arm_obj, 'Head', 5, euler_to_quaternion(-20, 0, 0))
    set_bone_pose(arm_obj, 'Chest', 15, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'Head', 15, euler_to_quaternion(0, 0, 0))
    return action


def author_death_a(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Death_A")
    # 45 frames collapse ending prone still on floor
    set_bone_pose(arm_obj, 'Hips', 1, euler_to_quaternion(0, 0, 0), (0, 0, 0))
    set_bone_pose(arm_obj, 'Hips', 20, euler_to_quaternion(45, 0, 0), (0, -0.2, -0.35))
    # Prone on floor
    set_bone_pose(arm_obj, 'Hips', 45, euler_to_quaternion(88, 0, 0), (0, -0.5, -0.88))
    set_bone_pose(arm_obj, 'Spine', 45, euler_to_quaternion(5, 0, 0))
    set_bone_pose(arm_obj, 'Head', 45, euler_to_quaternion(10, 20, 0))
    return action


def author_death_a_pose(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Death_A_Pose")
    # Static 10-frame prone death pose
    for f in (1, 10):
        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(88, 0, 0), (0, -0.5, -0.88))
        set_bone_pose(arm_obj, 'Spine', f, euler_to_quaternion(5, 0, 0))
        set_bone_pose(arm_obj, 'Head', f, euler_to_quaternion(10, 20, 0))
    return action


def author_blocking(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Blocking")
    # Raised shield guard stance
    for f in (1, 15, 30):
        t = 1.0 if f == 15 else 0.0
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(-45 + t, -20, 35))
        set_bone_pose(arm_obj, 'LeftLowerArm', f, euler_to_quaternion(65 + t, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(-20, 0, -20))
        set_bone_pose(arm_obj, 'Chest', f, euler_to_quaternion(8 + t, 0, -10))
    return action


def author_interact(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Interact")
    # Reach forward with right hand, examine, return
    set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 15, euler_to_quaternion(-55, 0, -15))
    set_bone_pose(arm_obj, 'RightLowerArm', 15, euler_to_quaternion(30, 0, 0))
    set_bone_pose(arm_obj, 'Head', 15, euler_to_quaternion(12, 0, 0))
    set_bone_pose(arm_obj, 'RightUpperArm', 30, euler_to_quaternion(0, 0, 0))
    set_bone_pose(arm_obj, 'RightLowerArm', 30, euler_to_quaternion(0, 0, 0))
    return action


def author_cheer(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Cheer")
    # Both arms raised in triumph
    for f in (1, 18, 35):
        t = 1.0 if f == 18 else 0.0
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(-120 - 10 * t, 0, -30))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(-120 - 10 * t, 0, 30))
        set_bone_pose(arm_obj, 'Head', f, euler_to_quaternion(-20 - 5 * t, 0, 0))
        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(0, 0, 0), (0, 0, 0.05 * t))
    return action


def author_sit_chair_idle(arm_obj: Any) -> Any:
    action = create_action(arm_obj, "Sit_Chair_Idle")
    # Seated relaxed pose
    for f in (1, 30, 60):
        t = 1.0 if f == 30 else 0.0
        set_bone_pose(arm_obj, 'Hips', f, euler_to_quaternion(0, 0, 0), (0, 0, -0.50 + 0.005 * t))
        set_bone_pose(arm_obj, 'LeftUpperLeg', f, euler_to_quaternion(-85, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperLeg', f, euler_to_quaternion(-85, 0, 0))
        set_bone_pose(arm_obj, 'LeftLowerLeg', f, euler_to_quaternion(85, 0, 0))
        set_bone_pose(arm_obj, 'RightLowerLeg', f, euler_to_quaternion(85, 0, 0))
        set_bone_pose(arm_obj, 'LeftUpperArm', f, euler_to_quaternion(-25, 0, 15))
        set_bone_pose(arm_obj, 'RightUpperArm', f, euler_to_quaternion(-25, 0, -15))
    return action


def author_idle_character(arm_obj: Any, role: str) -> Any:
    action = create_action(arm_obj, "Idle_Character")
    # 60 frames distinct role animation
    if role == 'warrior':
        # Warrior sword flip & catch
        set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(-45, 0, -20))
        for f, angle in ((20, 0), (26, 120), (32, 240), (38, 360)):
            set_bone_pose(arm_obj, 'RightHand', f, euler_to_quaternion(0, angle, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', 60, euler_to_quaternion(0, 0, 0))
    elif role == 'mage':
        # Mage light orb spin above hand
        set_bone_pose(arm_obj, 'RightUpperArm', 1, euler_to_quaternion(0, 0, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', 25, euler_to_quaternion(-40, 20, -15))
        set_bone_pose(arm_obj, 'RightLowerArm', 25, euler_to_quaternion(55, 0, 0))
        set_bone_pose(arm_obj, 'RightHand', 35, euler_to_quaternion(15, 45, 0))
        set_bone_pose(arm_obj, 'RightUpperArm', 60, euler_to_quaternion(0, 0, 0))
    elif role == 'mayor':
        # Push spectacles, open ledger, sigh
        set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(-75, 0, 25))
        set_bone_pose(arm_obj, 'LeftUpperArm', 35, euler_to_quaternion(-35, 0, 30))
        set_bone_pose(arm_obj, 'Chest', 45, euler_to_quaternion(8, 0, 0))  # Deep sigh
    elif role == 'captain':
        # Hand on hip sword, shift weight, scan gate
        set_bone_pose(arm_obj, 'RightUpperArm', 15, euler_to_quaternion(-15, 0, -35))
        set_bone_pose(arm_obj, 'Head', 30, euler_to_quaternion(0, 0, 35))  # Scan gate
        set_bone_pose(arm_obj, 'Head', 50, euler_to_quaternion(0, 0, -20))
    elif role == 'widow':
        # Clutch pendant, look at forest, lower eyes
        set_bone_pose(arm_obj, 'RightUpperArm', 25, euler_to_quaternion(-55, 0, 20))
        set_bone_pose(arm_obj, 'Head', 25, euler_to_quaternion(-12, 0, -15))
        set_bone_pose(arm_obj, 'Head', 50, euler_to_quaternion(18, 0, 0))  # Lower sorrowful eyes
    elif role == 'gourmand':
        # Taste from ladle, pat belly, happy nod
        set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(-85, 0, 15))  # Spoon to mouth
        set_bone_pose(arm_obj, 'LeftUpperArm', 35, euler_to_quaternion(-20, 0, 25))   # Pat belly
        set_bone_pose(arm_obj, 'Head', 45, euler_to_quaternion(15, 0, 0))             # Happy nod
    elif role == 'smuggler':
        # Coin toss & catch, sly glance
        set_bone_pose(arm_obj, 'RightUpperArm', 20, euler_to_quaternion(-30, 0, -20))
        set_bone_pose(arm_obj, 'RightHand', 30, euler_to_quaternion(-35, 0, 0))  # Coin flip
        set_bone_pose(arm_obj, 'Head', 40, euler_to_quaternion(0, 0, 25))        # Sly look
    elif role == 'ranger':
        # Test bowstring tension, sight arrow, ease
        set_bone_pose(arm_obj, 'LeftUpperArm', 25, euler_to_quaternion(-65, 0, 25))  # Hold bow
        set_bone_pose(arm_obj, 'RightUpperArm', 25, euler_to_quaternion(-55, 0, -20)) # Draw string
        set_bone_pose(arm_obj, 'Head', 30, euler_to_quaternion(5, 0, -15))           # Sight
    else:
        # Default subtle shift
        set_bone_pose(arm_obj, 'Chest', 30, euler_to_quaternion(3, 0, 0))

    # Close the character-specific idle without leaving a raised arm or twisted
    # wrist behind when the game loops it or transitions to another animation.
    for bone in arm_obj.pose.bones:
        set_bone_pose(arm_obj, bone.name, 60, euler_to_quaternion(0, 0, 0), (0, 0, 0))

    return action


# ==============================================================================
# 6. MASTER ANIMATION PIPELINE
# ==============================================================================

def author_all_character_animations(arm_obj: Any, role: str) -> List[str]:
    """Authors all 20 shared handoff clips + Idle_Character, pushing each to NLA."""
    clip_builders = [
        author_idle,
        author_walking_a,
        author_running_a,
        author_1h_slice_diag,
        author_1h_chop,
        author_1h_slice_horiz,
        author_1h_stab,
        author_2h_idle,
        author_2h_slice,
        author_2h_chop,
        author_2h_spin,
        author_spellcast_shoot,
        author_dodge_forward,
        author_hit_a,
        author_death_a,
        author_death_a_pose,
        author_blocking,
        author_interact,
        author_cheer,
        author_sit_chair_idle,
    ]

    built_names = []
    for builder in clip_builders:
        act = builder(arm_obj)
        if act is not None:
            push_action_to_nla(arm_obj, act, act.name)
            built_names.append(act.name)

    # Character-specific idle
    char_act = author_idle_character(arm_obj, role)
    if char_act is not None:
        push_action_to_nla(arm_obj, char_act, "Idle_Character")
        built_names.append("Idle_Character")

    return built_names


def create_shared_rig_blend(filepath: str) -> None:
    """Builds the canonical shared humanoid armature with all 20 clips and saves it."""
    if bpy is None:
        return

    # Reset scene
    bpy.ops.wm.read_factory_settings(use_empty=True)

    arm_obj = create_humanoid_armature("Humanoid")
    author_all_character_animations(arm_obj, "warrior")

    arm_obj.animation_data.action = None
    for bone in arm_obj.pose.bones:
        bone.location = (0, 0, 0)
        bone.rotation_quaternion = (1, 0, 0, 0)
    bpy.context.scene.render.fps = 30
    bpy.context.preferences.filepaths.save_version = 0

    bpy.ops.wm.save_as_mainfile(filepath=str(filepath))
