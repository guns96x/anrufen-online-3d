"""build_characters.py - Master CLI and build pipeline for Batch-1 Godot Anime Characters.

Executes procedural mesh generation, texture atlas creation, humanoid rigging,
animation authoring, and GLB export for 8 hero variants and 6 cast NPCs.

CLI Usage (within Blender):
  blender --background --python art_src/build_characters.py -- --root . --model all --renders
"""

from __future__ import annotations
import argparse
import json
import math
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Any

try:
    import bpy
except ImportError:
    bpy = None

# Ensure local art_src modules can be imported
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR.parent) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR.parent))

from art_src.character_geometry import (
    create_character_atlas,
    build_anime_head_mesh,
    build_anime_body_meshes,
    build_hero_gear_meshes,
    build_npc_prop_meshes,
    compute_mesh_skin_weights,
    compute_prop_rigid_weights,
    create_blender_mesh_object,
)
from art_src.character_animation import (
    create_humanoid_armature,
    author_all_character_animations,
    create_shared_rig_blend,
    author_idle_character,
    push_action_to_nla,
)


# ==============================================================================
# 1. CHARACTER SPECIFICATIONS REGISTRY (8 HEROES + 6 CAST NPCS)
# ==============================================================================

CHARACTER_REGISTRY: Dict[str, Dict[str, Any]] = {
    # ------------------ HEROES (8 VARIANTS) ------------------
    'human_warrior_m': {
        'kind': 'hero',
        'height': 1.85,
        'sex': 'm',
        'race': 'human',
        'role': 'warrior',
        'hair_style': 'short_swept',
        'palette_skin': (252, 230, 218, 255),
        'palette_skin_shd': (235, 198, 185, 255),
        'palette_hair': (55, 42, 35, 255),
        'palette_hair_high': (95, 75, 65, 255),
        'palette_hair_shd': (35, 25, 20, 255),
        'palette_eye': (40, 85, 150, 255),
        'palette_primary': (35, 55, 90, 255),     # Deep blue gambeson
        'palette_secondary': (115, 125, 138, 255), # Steel grey
        'palette_gold': (215, 175, 70, 255),      # Gold trim
        'palette_metal': (110, 118, 130, 255),
        'palette_leather_dark': (50, 36, 26, 255),
        'palette_accent': (35, 55, 90, 255),
    },
    'human_warrior_f': {
        'kind': 'hero',
        'height': 1.72,
        'sex': 'f',
        'race': 'human',
        'role': 'warrior',
        'hair_style': 'ponytail',
        'palette_skin': (254, 234, 222, 255),
        'palette_skin_shd': (238, 202, 190, 255),
        'palette_hair': (65, 48, 38, 255),
        'palette_hair_high': (110, 85, 70, 255),
        'palette_hair_shd': (40, 28, 22, 255),
        'palette_eye': (45, 95, 165, 255),
        'palette_primary': (35, 55, 90, 255),
        'palette_secondary': (115, 125, 138, 255),
        'palette_gold': (215, 175, 70, 255),
        'palette_metal': (110, 118, 130, 255),
        'palette_leather_dark': (50, 36, 26, 255),
        'palette_accent': (35, 55, 90, 255),
    },
    'human_mage_m': {
        'kind': 'hero',
        'height': 1.80,
        'sex': 'm',
        'race': 'human',
        'role': 'mage',
        'hair_style': 'wavy',
        'palette_skin': (250, 228, 215, 255),
        'palette_skin_shd': (232, 195, 182, 255),
        'palette_hair': (75, 50, 40, 255),
        'palette_hair_high': (120, 85, 70, 255),
        'palette_hair_shd': (45, 30, 24, 255),
        'palette_eye': (55, 110, 80, 255),
        'palette_primary': (115, 28, 42, 255),    # Burgundy robe
        'palette_secondary': (238, 228, 210, 255), # Cream
        'palette_gold': (175, 120, 60, 255),      # Bronze
        'palette_metal': (160, 115, 65, 255),
        'palette_leather_dark': (48, 34, 25, 255),
        'palette_accent': (115, 28, 42, 255),
    },
    'human_mage_f': {
        'kind': 'hero',
        'height': 1.68,
        'sex': 'f',
        'race': 'human',
        'role': 'mage',
        'hair_style': 'side_swept',
        'palette_skin': (252, 232, 220, 255),
        'palette_skin_shd': (235, 200, 188, 255),
        'palette_hair': (80, 52, 42, 255),
        'palette_hair_high': (130, 92, 75, 255),
        'palette_hair_shd': (48, 32, 25, 255),
        'palette_eye': (60, 120, 90, 255),
        'palette_primary': (115, 28, 42, 255),
        'palette_secondary': (238, 228, 210, 255),
        'palette_gold': (175, 120, 60, 255),
        'palette_metal': (160, 115, 65, 255),
        'palette_leather_dark': (48, 34, 25, 255),
        'palette_accent': (115, 28, 42, 255),
    },
    'elf_warrior_m': {
        'kind': 'hero',
        'height': 1.88,
        'sex': 'm',
        'race': 'elf',
        'role': 'warrior',
        'hair_style': 'braid',
        'palette_skin': (248, 232, 228, 255),     # Light neutral (game tints lavender)
        'palette_skin_shd': (228, 205, 202, 255),
        'palette_hair': (180, 160, 205, 255),     # Lilac silver
        'palette_hair_high': (225, 215, 240, 255),
        'palette_hair_shd': (135, 115, 160, 255),
        'palette_eye': (120, 90, 180, 255),
        'palette_primary': (28, 32, 65, 255),     # Night blue
        'palette_secondary': (195, 200, 210, 255), # Silver leaf plates
        'palette_gold': (170, 150, 205, 255),     # Lilac trim
        'palette_metal': (190, 195, 205, 255),
        'palette_leather_dark': (42, 38, 55, 255),
        'palette_accent': (155, 135, 190, 255),
    },
    'elf_warrior_f': {
        'kind': 'hero',
        'height': 1.76,
        'sex': 'f',
        'race': 'elf',
        'role': 'warrior',
        'hair_style': 'long_braid',
        'palette_skin': (250, 235, 230, 255),
        'palette_skin_shd': (230, 208, 205, 255),
        'palette_hair': (185, 165, 210, 255),
        'palette_hair_high': (230, 220, 245, 255),
        'palette_hair_shd': (140, 120, 165, 255),
        'palette_eye': (125, 95, 185, 255),
        'palette_primary': (28, 32, 65, 255),
        'palette_secondary': (195, 200, 210, 255),
        'palette_gold': (170, 150, 205, 255),
        'palette_metal': (190, 195, 205, 255),
        'palette_leather_dark': (42, 38, 55, 255),
        'palette_accent': (155, 135, 190, 255),
    },
    'elf_mage_m': {
        'kind': 'hero',
        'height': 1.84,
        'sex': 'm',
        'race': 'elf',
        'role': 'mage',
        'hair_style': 'short_swept',
        'palette_skin': (248, 232, 228, 255),
        'palette_skin_shd': (228, 205, 202, 255),
        'palette_hair': (230, 232, 240, 255),     # Silver
        'palette_hair_high': (255, 255, 255, 255),
        'palette_hair_shd': (180, 185, 195, 255),
        'palette_eye': (90, 160, 230, 255),
        'palette_primary': (155, 135, 190, 255),  # Lilac mantle
        'palette_secondary': (245, 245, 250, 255), # White robe
        'palette_gold': (175, 160, 215, 255),
        'palette_metal': (190, 195, 205, 255),
        'palette_leather_dark': (42, 38, 55, 255),
        'palette_accent': (155, 135, 190, 255),
        'palette_rune': (150, 220, 255, 255),     # Pale blue glow runes
    },
    'elf_mage_f': {
        'kind': 'hero',
        'height': 1.72,
        'sex': 'f',
        'race': 'elf',
        'role': 'mage',
        'hair_style': 'side_swept',
        'palette_skin': (250, 235, 230, 255),
        'palette_skin_shd': (230, 208, 205, 255),
        'palette_hair': (235, 236, 245, 255),
        'palette_hair_high': (255, 255, 255, 255),
        'palette_hair_shd': (185, 190, 200, 255),
        'palette_eye': (95, 165, 235, 255),
        'palette_primary': (155, 135, 190, 255),
        'palette_secondary': (245, 245, 250, 255),
        'palette_gold': (175, 160, 215, 255),
        'palette_metal': (190, 195, 205, 255),
        'palette_leather_dark': (42, 38, 55, 255),
        'palette_accent': (155, 135, 190, 255),
        'palette_rune': (150, 220, 255, 255),
    },

    # ------------------ TOWN CAST (6 NPCS) ------------------
    'mayor': {
        'kind': 'cast',
        'height': 1.78,
        'sex': 'm',
        'heavy': True,
        'race': 'human',
        'role': 'mayor',
        'hair_style': 'mayor_hair',
        'palette_skin': (245, 220, 205, 255),
        'palette_skin_shd': (220, 185, 170, 255),
        'palette_hair': (190, 190, 195, 255),     # Grey plaited beard
        'palette_hair_high': (230, 230, 235, 255),
        'palette_hair_shd': (140, 140, 145, 255),
        'palette_eye': (80, 60, 45, 255),
        'palette_primary': (72, 85, 48, 255),     # Olive waistcoat with town crest
        'palette_secondary': (88, 48, 32, 255),   # Chestnut
        'palette_gold': (185, 110, 60, 255),      # Copper keys/buttons
        'palette_metal': (185, 110, 60, 255),
        'palette_leather_dark': (55, 40, 30, 255),
        'palette_accent': (72, 85, 48, 255),
    },
    'militia_captain': {
        'kind': 'cast',
        'height': 1.88,
        'sex': 'm',
        'heavy': False,
        'race': 'human',
        'role': 'captain',
        'hair_style': 'short_swept',
        'palette_skin': (238, 212, 198, 255),
        'palette_skin_shd': (212, 178, 162, 255),
        'palette_hair': (42, 32, 28, 255),
        'palette_hair_high': (75, 58, 50, 255),
        'palette_hair_shd': (28, 20, 18, 255),
        'palette_eye': (65, 75, 85, 255),
        'palette_primary': (155, 35, 35, 255),    # Red gambeson & ragged cloak
        'palette_secondary': (88, 95, 105, 255),  # Iron brigandine
        'palette_gold': (165, 125, 65, 255),
        'palette_metal': (90, 95, 105, 255),
        'palette_leather_dark': (68, 46, 32, 255),
        'palette_accent': (155, 35, 35, 255),
    },
    'widow_anna': {
        'kind': 'cast',
        'height': 1.70,
        'sex': 'f',
        'heavy': False,
        'race': 'human',
        'role': 'widow',
        'hair_style': 'bun',
        'palette_skin': (252, 238, 232, 255),     # Pale sad beauty
        'palette_skin_shd': (232, 205, 198, 255),
        'palette_hair': (35, 32, 38, 255),
        'palette_hair_high': (65, 60, 72, 255),
        'palette_hair_shd': (22, 20, 25, 255),
        'palette_eye': (70, 65, 85, 255),
        'palette_primary': (45, 45, 52, 255),     # Graphite mourning dress
        'palette_secondary': (95, 70, 115, 255),  # Violet shawl
        'palette_gold': (190, 195, 205, 255),     # Silver flower pendant
        'palette_metal': (190, 195, 205, 255),
        'palette_leather_dark': (40, 35, 42, 255),
        'palette_accent': (95, 70, 115, 255),
    },
    'gourmand': {
        'kind': 'cast',
        'height': 1.75,
        'sex': 'm',
        'heavy': True,
        'race': 'human',
        'role': 'gourmand',
        'hair_style': 'gourmand_hair',
        'palette_skin': (252, 222, 210, 255),     # Rosy cheeks
        'palette_skin_shd': (235, 185, 172, 255),
        'palette_hair': (85, 55, 38, 255),
        'palette_hair_high': (130, 90, 65, 255),
        'palette_hair_shd': (50, 32, 22, 255),
        'palette_eye': (75, 55, 40, 255),
        'palette_primary': (195, 145, 55, 255),   # Ochre broad sash
        'palette_secondary': (185, 45, 35, 255),  # Tomato red
        'palette_gold': (215, 175, 70, 255),
        'palette_metal': (140, 140, 145, 255),
        'palette_leather_dark': (80, 52, 35, 255),
        'palette_accent': (185, 45, 35, 255),
    },
    'smuggler': {
        'kind': 'cast',
        'height': 1.74,
        'sex': 'm',
        'heavy': False,
        'race': 'human',
        'role': 'smuggler',
        'hair_style': 'smuggler_hair',
        'palette_skin': (246, 224, 210, 255),
        'palette_skin_shd': (222, 190, 175, 255),
        'palette_hair': (55, 45, 38, 255),
        'palette_hair_high': (95, 78, 68, 255),
        'palette_hair_shd': (35, 28, 24, 255),
        'palette_eye': (60, 95, 90, 255),
        'palette_primary': (75, 52, 38, 255),     # Brown leather coat with pockets
        'palette_secondary': (195, 175, 135, 255), # Sand tunic
        'palette_gold': (215, 175, 70, 255),      # Coin
        'palette_metal': (120, 125, 135, 255),
        'palette_leather_dark': (55, 38, 28, 255),
        'palette_accent': (59, 122, 114, 255),    # Murky turquoise sash/lining
    },
    'ranger': {
        'kind': 'cast',
        'height': 1.74,
        'sex': 'f',
        'heavy': False,
        'race': 'human',
        'role': 'ranger',
        'hair_style': 'ranger_hair',
        'palette_skin': (250, 230, 218, 255),
        'palette_skin_shd': (230, 196, 182, 255),
        'palette_hair': (160, 74, 38, 255),       # Vibrant red braid
        'palette_hair_high': (210, 115, 65, 255),
        'palette_hair_shd': (115, 45, 22, 255),
        'palette_eye': (30, 145, 75, 255),        # Emerald eyes
        'palette_primary': (30, 107, 67, 255),    # Emerald green tunic
        'palette_secondary': (92, 56, 30, 255),   # Leather corset
        'palette_gold': (160, 74, 38, 255),       # Rust trims
        'palette_metal': (130, 135, 142, 255),
        'palette_leather_dark': (58, 36, 22, 255),
        'palette_accent': (160, 74, 38, 255),
    },
}


# ==============================================================================
# 2. BLENDER SCENE SETUP & MATERIAL BINDING
# ==============================================================================

def reset_blender_scene() -> None:
    """Cleans all existing objects, meshes, and materials in Blender."""
    if bpy is None:
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.render.fps = 30
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0


def create_toon_atlas_material(name: str, texture_path: str, is_emissive: bool = False) -> Any:
    """Creates a clean Principled BSDF flat-albedo material with texture bound and packed."""
    if bpy is None:
        return None

    mat = bpy.data.materials.new(name=f"M_{name}_Atlas")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    # Principled BSDF & Output
    bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
    bsdf.location = (200, 0)
    bsdf.inputs['Roughness'].default_value = 0.9
    bsdf.inputs['Metallic'].default_value = 0.0

    output = nodes.new(type='ShaderNodeOutputMaterial')
    output.location = (500, 0)
    links.new(bsdf.outputs['BSDF'], output.inputs['Surface'])

    # Image Texture node
    tex_node = nodes.new(type='ShaderNodeTexImage')
    tex_node.location = (-200, 0)
    if os.path.exists(texture_path):
        img = bpy.data.images.load(str(texture_path))
        img.pack()
        tex_node.image = img
        links.new(tex_node.outputs['Color'], bsdf.inputs['Base Color'])
        if is_emissive and 'Emission Color' in bsdf.inputs:
            links.new(tex_node.outputs['Color'], bsdf.inputs['Emission Color'])
            if 'Emission Strength' in bsdf.inputs:
                bsdf.inputs['Emission Strength'].default_value = 1.0

    return mat


# ==============================================================================
# 3. GLB EXPORT WITH RNA-VERIFIED ARGUMENTS
# ==============================================================================

def export_character_glb(filepath: Path, export_objects: List[Any], armature_obj: Any) -> None:
    """Exports clean GLB adhering to model-handoff-codex.md specs."""
    if bpy is None:
        return

    # Deselect all and select only character components + rig
    for obj in bpy.context.scene.objects:
        obj.select_set(False)

    armature_obj.select_set(True)
    for obj in export_objects:
        obj.select_set(True)

    bpy.context.view_layer.objects.active = armature_obj

    # Ensure parent output folder exists
    filepath.parent.mkdir(parents=True, exist_ok=True)

    op = bpy.ops.export_scene.gltf
    rna = op.get_rna_type()
    props = {p.identifier for p in rna.properties}

    kwargs = {
        'filepath': str(filepath),
        'export_format': 'GLB',
        'use_selection': True,
        'export_yup': True,
        'export_apply': True,
        'export_skins': True,
        'export_all_influences': False,  # Max 4 influences
        'export_influence_nb': 4,
        'export_def_bones': False,
        'export_force_sampling': True,
        'export_rest_position_armature': True,
        'export_draco_mesh_compression_enable': False,
        'export_animations': True,
    }

    if 'export_nla_strips' in props:
        kwargs['export_nla_strips'] = True
    if 'export_animation_mode' in props:
        kwargs['export_animation_mode'] = 'NLA_TRACKS'
    if 'export_image_format' in props:
        kwargs['export_image_format'] = 'AUTO'
    if 'export_optimize_animation_size' in props:
        kwargs['export_optimize_animation_size'] = False

    valid_kwargs = {k: v for k, v in kwargs.items() if k in props}
    op(**valid_kwargs)


# ==============================================================================
# 4. TURNAROUND RENDERS (FRONT, SIDE, BACK, ACTION)
# ==============================================================================

def render_character_views(name: str, render_dir: Path, armature_obj: Any) -> None:
    """Renders 768x1024 neutral editorial turnaround PNGs."""
    if bpy is None:
        return

    render_dir.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    scene.render.resolution_x = 768
    scene.render.resolution_y = 1024

    from mathutils import Vector
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('Review_World')
    scene.world.use_nodes = True
    bg = next(n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (0.18, 0.20, 0.24, 1)
    bg.inputs[1].default_value = 0.45
    scene.view_settings.view_transform = 'Standard'
    scene.view_settings.look = 'None'
    temporary = []
    for label, position, power, size in [('Key',(2,-4,5),450,4),
                                          ('Fill',(-3,-1,3),200,3),
                                          ('Rim',(1,3,4),450,3)]:
        data = bpy.data.lights.new('Review_'+label, 'AREA')
        data.energy, data.size = power, size
        light = bpy.data.objects.new('Review_'+label, data)
        scene.collection.objects.link(light)
        light.location = position
        light.rotation_euler = (Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
        temporary.append(light)
    cam_data=bpy.data.cameras.new('Review_Camera')
    cam_data.type='ORTHO'
    cam_data.ortho_scale=2.85
    camera=bpy.data.objects.new('Review_Camera',cam_data)
    scene.collection.objects.link(camera)
    scene.camera=camera
    temporary.append(camera)
    hidden={obj:obj.hide_render for obj in scene.objects if obj.type=='MESH'}
    # Preview toon lighting is deliberately temporary. The shipped materials
    # remain portable flat albedo for Godot's own ToonStyle implementation.
    original_materials = {}
    preview_materials = {}
    for obj in hidden:
        for slot_index,slot in enumerate(obj.material_slots):
            source_mat = slot.material
            if source_mat is None:
                continue
            original_materials[(obj,slot_index)] = source_mat
            if source_mat not in preview_materials:
                preview = source_mat.copy()
                preview.name = 'Review_'+source_mat.name
                nodes,links=preview.node_tree.nodes,preview.node_tree.links
                texture=next(n for n in nodes if n.type=='TEX_IMAGE')
                output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
                diffuse=nodes.new('ShaderNodeBsdfDiffuse')
                diffuse.inputs['Color'].default_value=(1,1,1,1)
                rgb=nodes.new('ShaderNodeShaderToRGB')
                ramp=nodes.new('ShaderNodeValToRGB')
                ramp.color_ramp.interpolation='CONSTANT'
                ramp.color_ramp.elements[0].position=.10
                ramp.color_ramp.elements[0].color=(.42,.45,.57,1)
                ramp.color_ramp.elements[1].position=.72
                ramp.color_ramp.elements[1].color=(1,1,1,1)
                middle=ramp.color_ramp.elements.new(.40)
                middle.color=(.73,.75,.83,1)
                multiply=nodes.new('ShaderNodeMixRGB')
                multiply.blend_type='MULTIPLY'; multiply.inputs[0].default_value=1
                emission=nodes.new('ShaderNodeEmission')
                links.new(diffuse.outputs[0],rgb.inputs[0])
                links.new(rgb.outputs[0],ramp.inputs[0])
                links.new(texture.outputs['Color'],multiply.inputs[1])
                links.new(ramp.outputs[0],multiply.inputs[2])
                links.new(multiply.outputs[0],emission.inputs[0])
                links.new(emission.outputs[0],output.inputs['Surface'])
                preview_materials[source_mat]=preview
            slot.material=preview_materials[source_mat]
    variants = {'2H_Sword','Badge_Shield','Rectangle_Shield','Spike_Shield','Knight_Helmet',
                '1H_Wand','Mage_Hat'}
    for obj in hidden:
        if obj.name in variants:
            obj.hide_render=True
    for track in armature_obj.animation_data.nla_tracks:
        track.mute=True
    def pose(clip, frame):
        armature_obj.animation_data.action=bpy.data.actions[clip]
        if len(bpy.data.actions[clip].slots):
            armature_obj.animation_data.action_slot=bpy.data.actions[clip].slots[0]
        scene.frame_set(frame)
        bpy.context.view_layer.update()
    for view,position in [('front',(0,-5,1.0)),('side',(5,0,1.0)),
                          ('back',(0,5,1.0)),('action',(3,-4,1.9))]:
        if view=='action':
            spec=CHARACTER_REGISTRY[name]
            clip=('1H_Melee_Attack_Slice_Diagonal' if spec['role']=='warrior' else
                  'Spellcast_Shoot' if spec['role']=='mage' else 'Idle_Character')
            pose(clip,16 if spec['kind']=='hero' else 25)
        else:
            pose('Idle',1)
        camera.location=position
        camera.rotation_euler=(Vector((0,0,0.98))-camera.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(render_dir/f'{name}_{view}.png')
        bpy.ops.render.render(write_still=True)
    for obj,value in hidden.items():
        obj.hide_render=value
    for (obj,index),material in original_materials.items():
        obj.material_slots[index].material=material
    for preview in preview_materials.values():
        bpy.data.materials.remove(preview)
    armature_obj.animation_data.action=None
    scene.frame_set(1)
    for bone in armature_obj.pose.bones:
        bone.rotation_quaternion=(1,0,0,0)
        bone.location=(0,0,0)
    scene.camera=None
    for obj in temporary:
        bpy.data.objects.remove(obj,do_unlink=True)


# ==============================================================================
# 5. SINGLE MODEL BUILD PIPELINE
# ==============================================================================

def place_gear_geometry(raw: Any, name: str, spec: Dict[str, Any]) -> None:
    """Bake mount offsets into vertices, keeping exported object transforms clean."""
    from mathutils import Vector, Matrix
    factor=spec['height']/1.8
    offset=Vector((0,0,0))
    rotation=Matrix.Identity(3)
    if name in ('1H_Sword','2H_Sword','1H_Wand','2H_Staff'):
        offset=Vector((-.71,.02,.96))
        if name=='2H_Staff':
            offset.z=.45
        if spec['role']=='captain':
            offset=Vector((-.23,-.02,.97))
            rotation=Matrix.Rotation(math.pi,3,'Y')
    elif name.endswith('Shield'):
        offset=Vector((.68,-.05,.98))
        if name in ('Round_Shield','Spike_Shield'):
            rotation=Matrix.Rotation(math.pi/2,3,'X')
        if spec['role']=='captain':
            offset=Vector((0,.20,1.2))
    elif name=='Knight_Helmet':
        offset=Vector((0,0,1.60))
    elif name=='Mage_Hat':
        offset=Vector((0,0,1.76))
    elif name in ('Knight_Cape','Mage_Cape'):
        if max(v[2] for v in raw.vertices)<.8:
            offset=Vector((0,.07,1.45))
    elif name=='Spellbook':
        offset=Vector((.23,-.05,.98))
    elif name=='Prop_Ledger':
        offset=Vector((.65,-.04,1.01))
    elif name=='Prop_Basket':
        offset=Vector((.70,.01,.82))
    elif name=='Prop_Ladle':
        offset=Vector((-.24,-.18,1.10))
        rotation=Matrix.Rotation(-.3,3,'Y')
    elif name=='Prop_Coin':
        offset=Vector((-.73,-.02,.95))
    elif name=='Prop_Bow':
        offset=Vector((.13,.23,1.18))
        rotation=Matrix.Rotation(-.35,3,'Y')
    raw.vertices=[tuple((rotation@Vector(v)+offset)*factor) for v in raw.vertices]


def build_single_model(name: str, root_dir: Path, do_renders: bool = False) -> Dict[str, Any]:
    """Builds a single character model, rig, animations, and exports GLB."""
    spec = CHARACTER_REGISTRY[name]
    spec['name'] = name
    kind = spec['kind']
    height = spec['height']
    role = spec['role']

    # File paths
    textures_dir = root_dir / 'art_src' / 'textures'
    models_dir = root_dir / 'art_src' / 'models'
    renders_dir = root_dir / 'art_src' / 'renders'
    glb_dir = root_dir / 'assets' / 'characters' / ('hero' if kind == 'hero' else 'cast')

    textures_dir.mkdir(parents=True, exist_ok=True)
    models_dir.mkdir(parents=True, exist_ok=True)
    glb_dir.mkdir(parents=True, exist_ok=True)

    atlas_path = textures_dir / f"{name}_albedo.png"
    blend_path = models_dir / f"{name}.blend"
    glb_path = glb_dir / f"{name}.glb"

    print(f"\n[BUILD] Building character: {name} ({kind}, {role}, {height}m)...")

    # Step 1: Render Flat Albedo Texture Atlas
    atlas_res = 2048 if kind == 'hero' else 1024
    create_character_atlas(str(atlas_path), spec, width=atlas_res, height=atlas_res)

    if bpy is None:
        # Non-Blender environment (e.g. testing)
        return {
            'model': name,
            'kind': kind,
            'status': 'OK (Static Parse / Texture Only)',
            'atlas': str(atlas_path)
        }

    # Step 2: Reset Scene & Material Setup
    reset_blender_scene()
    mat = create_toon_atlas_material(name, str(atlas_path), is_emissive=False)

    # Step 3: Shared Humanoid Armature
    # Append the authored rig and its common actions, rather than regenerating
    # motion for each character. Bone rest transforms stay byte-for-byte equal.
    rig_path = root_dir / 'art_src/rig/humanoid.blend'
    with bpy.data.libraries.load(str(rig_path), link=False) as (source, target):
        target.objects = ['Humanoid']
    arm_obj = target.objects[0]
    arm_obj.name = 'Armature'
    bpy.context.collection.objects.link(arm_obj)

    # Step 4: Generate Head & Body Meshes with exact suffixes
    all_mesh_objects: List[Any] = []

    # Head
    head_raw = build_anime_head_mesh(spec)
    compute_mesh_skin_weights(head_raw, 'Head', height)
    head_obj = create_blender_mesh_object(head_raw, f"{name}_Head", mat, arm_obj)
    head_obj.parent = arm_obj
    all_mesh_objects.append(head_obj)

    # Torso & Limbs
    body_parts_raw = build_anime_body_meshes(spec)
    for part_name, part_mesh in body_parts_raw.items():
        compute_mesh_skin_weights(part_mesh, part_name, height)
        obj_name = f"{name}_{part_name}"
        b_obj = create_blender_mesh_object(part_mesh, obj_name, mat, arm_obj)
        b_obj.parent = arm_obj
        all_mesh_objects.append(b_obj)

    # Step 5: Gear & Props
    gear_parent_bones: Dict[str, str] = {
        '1H_Sword': 'handslot.r',
        '2H_Sword': 'handslot.r',
        'Round_Shield': 'handslot.l' if role == 'warrior' else 'Chest',
        'Badge_Shield': 'handslot.l',
        'Rectangle_Shield': 'handslot.l',
        'Spike_Shield': 'handslot.l',
        'Knight_Helmet': 'Head',
        'Knight_Cape': 'UpperChest',
        '1H_Wand': 'handslot.r',
        '2H_Staff': 'handslot.r',
        'Mage_Hat': 'Head',
        'Mage_Cape': 'UpperChest',
        'Spellbook': 'Hips',
        'Prop_Ledger': 'handslot.l',
        'Prop_Basket': 'handslot.l',
        'Prop_Ladle': 'Hips',
        'Prop_Coin': 'handslot.r',
        'Prop_Bow': 'Chest',
    }

    if kind == 'hero':
        gear_meshes = build_hero_gear_meshes(role)
    else:
        gear_meshes = build_npc_prop_meshes(role)

    for gear_name, gear_raw in gear_meshes.items():
        place_gear_geometry(gear_raw, gear_name, spec)
        parent_b = gear_parent_bones.get(gear_name, 'Hips')
        # Literal bone attachment keeps gear independently toggleable. Bake the
        # rest mount into its vertices, leaving the object's basis transforms I.
        from mathutils import Matrix, Vector
        g_obj = create_blender_mesh_object(gear_raw, gear_name, mat, None)
        g_obj.parent = arm_obj
        g_obj.parent_type = 'BONE'
        g_obj.parent_bone = parent_b
        g_obj.matrix_basis = Matrix.Identity(4)
        g_obj.matrix_parent_inverse = Matrix.Identity(4)
        bpy.context.view_layer.update()
        inverse_mount = g_obj.matrix_world.inverted()
        for vertex in g_obj.data.vertices:
            vertex.co = inverse_mount @ vertex.co
        g_obj['mount_bone'] = parent_b
        g_obj['toggleable'] = True
        all_mesh_objects.append(g_obj)

    collection = bpy.data.collections.new('COL_'+name+'_Export')
    bpy.context.scene.collection.children.link(collection)
    for obj in [arm_obj, *all_mesh_objects]:
        for old_collection in list(obj.users_collection):
            old_collection.objects.unlink(obj)
        collection.objects.link(obj)

    # Step 6: Author Animations & NLA Tracks
    # Keep the twenty shared motions from humanoid.blend. Only the role idle is
    # replaced, preserving the exact exported clip name.
    for track in list(arm_obj.animation_data.nla_tracks):
        if track.name == 'Idle_Character':
            old = track.strips[0].action
            arm_obj.animation_data.nla_tracks.remove(track)
            if old.users == 0:
                bpy.data.actions.remove(old)
    character_idle = author_idle_character(arm_obj, role)
    push_action_to_nla(arm_obj, character_idle, 'Idle_Character')
    authored_clips = [t.name for t in arm_obj.animation_data.nla_tracks]
    for pb in arm_obj.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)

    # Step 7: Optional Review Renders
    if do_renders:
        # Hide extra shields/weapons temporarily so review render is clean
        print(f"  Rendering turnaround views to art_src/renders/{name}_*.png...")
        render_character_views(name, renders_dir, arm_obj)

    # Step 8: Save Blender Source File
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))

    # Step 9: Export GLB
    export_character_glb(glb_path, all_mesh_objects, arm_obj)

    # Step 10: Collect Statistics & Validate Budgets
    total_triangles = sum(sum(len(p.vertices)-2 for p in m.data.polygons) for m in all_mesh_objects)
    total_verts = sum(len(m.data.vertices) for m in all_mesh_objects)
    tri_budget = 12000 if kind == 'hero' else 8000
    if total_triangles > tri_budget:
        raise RuntimeError(f'{name}: {total_triangles} triangles > {tri_budget}')

    report_entry = {
        'model': name,
        'kind': kind,
        'role': role,
        'height': height,
        'glb': str(glb_path.relative_to(root_dir)),
        'blend': str(blend_path.relative_to(root_dir)),
        'triangles': total_triangles,
        'budget': tri_budget,
        'vertices': total_verts,
        'materials': [f"M_{name}_Atlas"],
        'texture_res': atlas_res,
        'bones': len(arm_obj.pose.bones),
        'clips': authored_clips,
        'gear_objects': list(gear_meshes.keys()),
        'status': 'OK' if total_triangles <= tri_budget else f'OVER BUDGET ({total_triangles} > {tri_budget})'
    }

    print(f"  [DONE] {name}: {total_triangles} tris (budget {tri_budget}), {len(authored_clips)} clips, GLB exported.")
    return report_entry


# ==============================================================================
# 6. MASTER CLI & BATCH RUNNER
# ==============================================================================

def parse_cli_args() -> argparse.Namespace:
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = argv[1:]

    parser = argparse.ArgumentParser(description="Batch-1 Anime Character Generator")
    parser.add_argument("--root", default=".", help="Project root directory")
    parser.add_argument("--model", default="all", help="Character model name or 'all'")
    parser.add_argument("--renders", action="store_true", help="Generate turnaround editorial renders")
    return parser.parse_args(argv)


def main() -> None:
    args = parse_cli_args()
    root_dir = Path(args.root).resolve()

    print("======================================================================")
    print(" ANRUFEN ONLINE 3D - BATCH-1 CHARACTER MODEL BUILDER")
    print(f" Root Directory: {root_dir}")
    print(f" Target Model:   {args.model}")
    print(f" Renders:        {args.renders}")
    print("======================================================================")

    # 1. First ensure shared humanoid rig blend is created
    rig_dir = root_dir / 'art_src' / 'rig'
    rig_dir.mkdir(parents=True, exist_ok=True)
    shared_rig_blend = rig_dir / 'humanoid.blend'
    if bpy is not None:
        print("[INIT] Creating shared humanoid rig blend: art_src/rig/humanoid.blend...")
        create_shared_rig_blend(str(shared_rig_blend))

    # 2. Select models to build
    if args.model.lower() == 'all':
        models_to_build = list(CHARACTER_REGISTRY.keys())
    else:
        if args.model not in CHARACTER_REGISTRY:
            print(f"[ERROR] Unknown model '{args.model}'. Available models:")
            for m in CHARACTER_REGISTRY.keys():
                print(f"  - {m}")
            sys.exit(1)
        models_to_build = [args.model]

    # 3. Build models
    build_results: Dict[str, Any] = {}
    for model_name in models_to_build:
        res = build_single_model(model_name, root_dir, do_renders=args.renders)
        build_results[model_name] = res

    # 4. Write Summary Build Report
    report_path = root_dir / 'art_src' / 'build_report.json'
    with open(report_path, 'w', encoding='utf-8') as f:
        json.dump(build_results, f, indent=2)

    print("\n======================================================================")
    print(f" BUILD COMPLETE: {len(build_results)} models processed.")
    print(f" Report written to: {report_path}")
    print("======================================================================")


if __name__ == '__main__':
    main()
