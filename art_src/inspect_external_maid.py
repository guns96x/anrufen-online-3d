"""Inspect the downloaded CC0 candidate in a clean, non-executing import."""
from pathlib import Path
import json
import bpy

root=Path(__file__).resolve().parent/'external_sources/anime-maid-413games'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root/'Maid.fbx'),use_anim=False)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
rigs=[o for o in bpy.context.scene.objects if o.type=='ARMATURE']
report={'source':'https://413games.itch.io/maid-character',
        'license_file':'License.txt','license':'CC0 1.0',
        'candidate_only':True,'imported_in_blender':bpy.app.version_string,
        'meshes':[{'name':o.name,'vertices':len(o.data.vertices),
                   'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
                   'materials':[m.name for m in o.data.materials if m],
                   'shape_keys':len(o.data.shape_keys.key_blocks) if o.data.shape_keys else 0}
                  for o in meshes],
        'rigs':[{'name':o.name,'bones':len(o.data.bones)} for o in rigs],
        'materials':len(bpy.data.materials),
        'textures':[p.name for p in (root/'Textures').glob('*.png')]}
report['total_triangles']=sum(x['triangles'] for x in report['meshes'])
(root/'inspection.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('CANDIDATE',report['total_triangles'],'triangles',len(meshes),'meshes',
      len(bpy.data.materials),'materials',len(rigs),'rigs',
      sum(x['shape_keys'] for x in report['meshes']),'shape keys')
