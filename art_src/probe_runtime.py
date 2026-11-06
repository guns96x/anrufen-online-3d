"""Inspect exporter API in an isolated factory-startup Blender process."""
import bpy
import json
from pathlib import Path

exporter = bpy.ops.export_scene.gltf.get_rna_type().properties
names = ['export_animation_mode', 'export_nla_strips', 'export_force_sampling',
         'export_def_bones', 'export_skins', 'export_all_influences',
         'export_influence_nb', 'export_yup', 'use_selection', 'export_apply',
         'export_image_format', 'export_materials']
report = {'version': bpy.app.version_string, 'engine': bpy.context.scene.render.engine,
          'exporter': {}}
for name in names:
    if name in exporter:
        p = exporter[name]
        report['exporter'][name] = {'type': p.type, 'default': p.default}
        if p.type == 'ENUM':
            report['exporter'][name]['options'] = [i.identifier for i in p.enum_items]
print(json.dumps(report, indent=2))
Path(__file__).with_name('runtime.json').write_text(json.dumps(report, indent=2))
