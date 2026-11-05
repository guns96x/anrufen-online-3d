"""Builds the forest creatures as animated GLB files for Godot.

Run: blender -b --python tools/build_creatures.py -- <quaternius_dir>
  boar   <- Quaternius Farm Animals "Pig" (CC0) + tusks, bristles, darker hide
  jackal <- Quaternius Animal Pack Vol.2 "Wolf" (CC0) recoloured sandy
  spider <- modelled here: rigid parts on an armature
Every creature ends up with Idle, Walk, Attack, Hit and Death actions.
"""
import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "creatures"
OUT.mkdir(parents=True, exist_ok=True)
SRC = Path(sys.argv[sys.argv.index("--") + 1])
PIG = SRC / "animals/Farm_Animals_by_Quaternius/Farm Animals by @Quaternius/FBX/Pig.fbx"
WOLF = SRC / "animals/Animal_Pack_Vol.2_by_Quaternius/Animal Pack Vol.2 by @Quaternius/FBX/Wolf.fbx"
FPS = 24


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS


def material(name, color, rough=0.8, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = rough
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def pose_action(arm, name, length, keys):
    """keys: {frame: {bone: (rx, ry, rz) degrees or ('loc', x, y, z)}}"""
    action = bpy.data.actions.new(name)
    arm.animation_data_create()
    arm.animation_data.action = action
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    for frame in sorted(keys):
        for bone, value in keys[frame].items():
            pb = arm.pose.bones.get(bone)
            if pb is None:
                continue
            if value and value[0] == "loc":
                pb.location = Vector(value[1:])
                pb.keyframe_insert("location", frame=frame)
            else:
                pb.rotation_euler = tuple(math.radians(v) for v in value)
                pb.keyframe_insert("rotation_euler", frame=frame)
    action.frame_range = (1, length)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    return action


def keep_imported_actions(arm, rename):
    arm.animation_data_create()
    for action in list(bpy.data.actions):
        short = action.name.split("|")[-1]
        if short in rename:
            action.name = rename[short]
            track = arm.animation_data.nla_tracks.new()
            track.name = action.name
            track.strips.new(action.name, int(action.frame_range[0]), action)
    arm.animation_data.action = None


def export(name):
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
                              export_animation_mode="NLA_TRACKS", export_yup=True, export_apply=False)
    print("EXPORTED", name)


def quad_gait(frames, legs, swing, lift_bone=None):
    """Alternating diagonal gait for four legs: legs = [FL, FR, BL, BR]."""
    keys = {}
    for f in range(1, frames + 2, max(1, frames // 4)):
        t = (f - 1) / frames * math.tau
        k = {}
        for i, bone in enumerate(legs):
            phase = 0 if i in (0, 3) else math.pi
            k[bone] = (math.sin(t + phase) * swing, 0, 0)
        if lift_bone:
            k[lift_bone] = ("loc", 0, abs(math.sin(t)) * 0.08, 0)
        keys[f] = k
    return keys


def build_boar():
    reset()
    bpy.ops.import_scene.fbx(filepath=str(PIG))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    hide = material("BoarHide", (0.07, 0.04, 0.025))
    snout = material("BoarSnout", (0.2, 0.11, 0.09))
    ivory = material("Tusk", (0.93, 0.88, 0.74), 0.35)
    for i, slot in enumerate(body.material_slots):
        slot.material = hide if i == 0 else snout
    head = arm.data.bones["Head"]
    head_world = arm.matrix_world @ head.head_local
    for side in (-1, 1):
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.22, depth=1.6,
                                        location=head_world + Vector((side * 0.55, -1.5, -0.55)))
        tusk = bpy.context.active_object
        tusk.rotation_euler = (math.radians(-60), 0, math.radians(side * 18))
        tusk.data.materials.append(ivory)
        _parent_to_bone(tusk, arm, "Head")
    for i in range(7):
        bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=0.22, depth=0.75,
                                        location=head_world + Vector((0, 1.1 + i * 0.75, 0.9 - i * 0.05)))
        spike = bpy.context.active_object
        spike.rotation_euler = (math.radians(-25), 0, 0)
        spike.data.materials.append(material("Bristle", (0.08, 0.05, 0.03)))
        _parent_to_bone(spike, arm, "Back" if i > 2 else "Shoulders")
    keep_imported_actions(arm, {"Idle": "Idle"})
    legs = ["FrontUpLeg.L", "FrontUpLeg.R", "BackUpLeg.L", "BackUpLeg.R"]
    pose_action(arm, "Walk", 20, quad_gait(20, legs, 28))
    pose_action(arm, "Attack", 16, {1: {"Neck": (0, 0, 0), "Head": (0, 0, 0), "Body": ("loc", 0, 0, 0)},
                                    6: {"Neck": (-25, 0, 0), "Head": (-20, 0, 0), "Body": ("loc", 0, 0, 0.25)},
                                    9: {"Neck": (30, 0, 0), "Head": (25, 0, 0), "Body": ("loc", 0, 0, -0.9)},
                                    16: {"Neck": (0, 0, 0), "Head": (0, 0, 0), "Body": ("loc", 0, 0, 0)}})
    pose_action(arm, "Hit", 10, {1: {"Body": (0, 0, 0)}, 4: {"Body": (12, 0, 8)}, 10: {"Body": (0, 0, 0)}})
    pose_action(arm, "Death", 24, {1: {"Body": (0, 0, 0), "FrontUpLeg.L": (0, 0, 0), "BackUpLeg.L": (0, 0, 0)},
                                   10: {"Body": (0, 40, 0)},
                                   18: {"Body": (0, 90, 0), "FrontUpLeg.L": (40, 0, 0), "BackUpLeg.L": (-35, 0, 0)},
                                   24: {"Body": (0, 88, 0), "FrontUpLeg.L": (45, 0, 0), "BackUpLeg.L": (-40, 0, 0)}})
    export("boar")


def _parent_to_bone(obj, arm, bone):
    bpy.context.view_layer.update()   # pending rotations must reach matrix_world first
    world = obj.matrix_world.copy()
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    obj.matrix_world = world


def build_jackal():
    reset()
    bpy.ops.import_scene.fbx(filepath=str(WOLF))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    body = next(o for o in bpy.data.objects if o.type == "MESH")
    for slot in body.material_slots:
        bsdf = slot.material.node_tree.nodes.get("Principled BSDF") if slot.material.use_nodes else None
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (0.42, 0.27, 0.12, 1)
    keep_imported_actions(arm, {"Idle": "Idle", "Walking": "Walk"})
    spine = ["Bone", "Bone.001", "Bone.002", "Bone.003"]
    pose_action(arm, "Attack", 14, {1: {spine[2]: (0, 0, 0), spine[3]: (0, 0, 0)},
                                    5: {spine[2]: (0, 0, 18), spine[3]: (0, 0, 22)},
                                    8: {spine[2]: (0, 0, -22), spine[3]: (0, 0, -28)},
                                    14: {spine[2]: (0, 0, 0), spine[3]: (0, 0, 0)}})
    pose_action(arm, "Hit", 10, {1: {spine[0]: (0, 0, 0)}, 4: {spine[0]: (14, 0, 0)}, 10: {spine[0]: (0, 0, 0)}})
    pose_action(arm, "Death", 22, {1: {spine[0]: (0, 0, 0)}, 12: {spine[0]: (60, 0, 0)}, 22: {spine[0]: (88, 0, 0)}})
    export("jackal")


def build_spider():
    reset()
    chitin = material("Chitin", (0.09, 0.07, 0.07), 0.45)
    stripe = material("Stripe", (0.55, 0.12, 0.08), 0.5)
    eyes = material("Eyes", (1.0, 0.15, 0.05), 0.2, emit=3.0)
    bpy.ops.object.armature_add(location=(0, 0, 0))
    arm = bpy.context.active_object
    arm.name = "SpiderRig"
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    eb[0].name = "Body"
    eb["Body"].head = (0, 0, 0.55)
    eb["Body"].tail = (0, 0.5, 0.55)
    legs = []
    for side in (-1, 1):
        for i in range(4):
            y = 0.25 - i * 0.22
            up = eb.new(f"Leg{i}{'L' if side < 0 else 'R'}_Up")
            up.head = (side * 0.28, y, 0.6)
            up.tail = (side * 0.75, y + (0.25 - i * 0.15), 0.95)
            up.parent = eb["Body"]
            low = eb.new(up.name.replace("_Up", "_Low"))
            low.head = up.tail
            low.tail = (side * 1.15, y + (0.35 - i * 0.22), 0.0)
            low.parent = up
            legs.append((up.name, low.name))
    bpy.ops.object.mode_set(mode="OBJECT")

    def part(mesh_op, bone, mat, **kw):
        mesh_op(**kw)
        obj = bpy.context.active_object
        obj.data.materials.append(mat)
        bpy.ops.object.shade_smooth()
        _parent_to_bone(obj, arm, bone)
        return obj

    abdomen = part(bpy.ops.mesh.primitive_uv_sphere_add, "Body", chitin, radius=0.55, location=(0, -0.55, 0.75), segments=16, ring_count=10)
    abdomen.scale = (1.0, 1.25, 0.85)
    part(bpy.ops.mesh.primitive_uv_sphere_add, "Body", stripe, radius=0.3, location=(0, -0.75, 1.12), segments=12, ring_count=8).scale = (0.9, 1.4, 0.4)
    part(bpy.ops.mesh.primitive_uv_sphere_add, "Body", chitin, radius=0.36, location=(0, 0.3, 0.62), segments=14, ring_count=8)
    for x in (-0.12, 0.12):
        part(bpy.ops.mesh.primitive_uv_sphere_add, "Body", eyes, radius=0.07, location=(x, 0.62, 0.75), segments=8, ring_count=6)
        part(bpy.ops.mesh.primitive_cone_add, "Body", chitin, radius1=0.06, depth=0.3, location=(x * 0.8, 0.68, 0.45), vertices=6).rotation_euler = (math.radians(200), 0, 0)
    for up, low in legs:
        for bone_name in (up, low):
            bone = arm.data.bones[bone_name]
            head = arm.matrix_world @ bone.head_local
            tail = arm.matrix_world @ bone.tail_local
            d = tail - head
            bpy.ops.mesh.primitive_cylinder_add(radius=0.055 if "Up" in bone_name else 0.04, depth=d.length,
                                                location=(head + tail) / 2, vertices=6)
            seg = bpy.context.active_object
            seg.rotation_mode = "QUATERNION"
            seg.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(d)
            seg.data.materials.append(chitin)
            _parent_to_bone(seg, arm, bone_name)

    ups = [u for u, _ in legs]
    walk = {}
    for f in range(1, 18, 4):
        t = (f - 1) / 16 * math.tau
        k = {"Body": ("loc", 0, 0, abs(math.sin(t * 2)) * 0.04)}
        for i, bone in enumerate(ups):
            phase = math.pi if (i % 2) ^ (i >= 4) else 0
            k[bone] = (math.sin(t + phase) * 14, 0, math.cos(t + phase) * 18)
        walk[f] = k
    idle = {1: {u: (0, 0, 0) for u in ups}, 20: {u: (4 if j % 2 else -4, 0, 0) for j, u in enumerate(ups)}, 40: {u: (0, 0, 0) for u in ups}}
    front = [ups[0], ups[4]]
    attack = {1: {"Body": (0, 0, 0), front[0]: (0, 0, 0), front[1]: (0, 0, 0)},
              6: {"Body": (-18, 0, 0), front[0]: (-55, 0, 0), front[1]: (-55, 0, 0)},
              9: {"Body": (12, 0, 0), front[0]: (35, 0, 0), front[1]: (35, 0, 0)},
              16: {"Body": (0, 0, 0), front[0]: (0, 0, 0), front[1]: (0, 0, 0)}}
    hit = {1: {"Body": (0, 0, 0)}, 4: {"Body": (10, 0, 6)}, 10: {"Body": (0, 0, 0)}}
    death = {1: {"Body": ("loc", 0, 0, 0), **{u: (0, 0, 0) for u in ups}},
             12: {"Body": ("loc", 0, 0, -0.25), **{u: (-50, 0, 0) for u in ups}},
             24: {"Body": ("loc", 0, 0, -0.4), **{u: (-80, 0, 0) for u in ups}}}
    pose_action(arm, "Idle", 40, idle)
    pose_action(arm, "Walk", 16, walk)
    pose_action(arm, "Attack", 16, attack)
    pose_action(arm, "Hit", 10, hit)
    pose_action(arm, "Death", 24, death)
    export("spider")


build_boar()
build_jackal()
build_spider()
