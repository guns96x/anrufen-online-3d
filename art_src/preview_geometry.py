"""Independent early visual check of geometry before a full animated export."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import character_geometry as geo

bpy.ops.wm.read_factory_settings(use_empty=True)
spec = {'name': 'human_warrior_m', 'height': 1.85, 'sex': 'm', 'race': 'human',
        'role': 'warrior', 'hair_style': 'short_swept'}
out = HERE / 'renders'
out.mkdir(exist_ok=True)
atlas = out / 'preview_atlas.png'
geo.create_character_atlas(str(atlas), spec)
mat = bpy.data.materials.new('Preview_Albedo')
mat.use_nodes = True
shader = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
shader.inputs['Roughness'].default_value = 0.85
tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
tex.image = bpy.data.images.load(str(atlas))
mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
for name, mesh in geo.build_anime_body_meshes(spec).items():
    geo.create_blender_mesh_object(mesh, name, mat)
geo.create_blender_mesh_object(geo.build_anime_head_mesh(spec), 'Head', mat)

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=768
scene.render.resolution_y=1024
scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Preview_World')
scene.world.use_nodes=True
next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND').inputs[0].default_value=(0.18,0.2,0.24,1)
for name,position,power,size in [('Key',(2,-4,5),450,4),('Fill',(-3,-1,3),250,3),('Rim',(1,3,4),450,3)]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj)
    obj.location=position; obj.rotation_euler=(Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('ReviewCamera'); camera=bpy.data.objects.new('ReviewCamera',camdata)
scene.collection.objects.link(camera); scene.camera=camera
camera.location=(0,-5,1.0); camera.rotation_euler=(Vector((0,0,0.96))-camera.location).to_track_quat('-Z','Y').to_euler()
camdata.type='ORTHO'; camdata.ortho_scale=2.35
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(out/'preview_geometry.png')
bpy.ops.render.render(write_still=True)
