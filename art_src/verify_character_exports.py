"""Additional delivery checks beyond tools/validate_models.py (no dependencies)."""
import json
import math
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
NAMES = [f'{race}_{role}_{sex}' for race in ('human', 'elf')
         for role in ('warrior', 'mage') for sex in ('m', 'f')]
NAMES += ['mayor', 'militia_captain', 'widow_anna', 'gourmand', 'smuggler', 'ranger']
BONES = 'Hips Spine Chest UpperChest Neck Head LeftShoulder LeftUpperArm LeftLowerArm LeftHand RightShoulder RightUpperArm RightLowerArm RightHand LeftUpperLeg LeftLowerLeg LeftFoot LeftToes RightUpperLeg RightLowerLeg RightFoot RightToes handslot.l handslot.r'.split()
CLIPS = 'Idle Walking_A Running_A 1H_Melee_Attack_Slice_Diagonal 1H_Melee_Attack_Chop 1H_Melee_Attack_Slice_Horizontal 1H_Melee_Attack_Stab 2H_Melee_Idle 2H_Melee_Attack_Slice 2H_Melee_Attack_Chop 2H_Melee_Attack_Spin Spellcast_Shoot Dodge_Forward Hit_A Death_A Death_A_Pose Blocking Interact Cheer Sit_Chair_Idle Idle_Character'.split()
GEAR = {
    'warrior': '1H_Sword 2H_Sword Round_Shield Badge_Shield Rectangle_Shield Spike_Shield Knight_Helmet Knight_Cape'.split(),
    'mage': '1H_Wand 2H_Staff Mage_Hat Mage_Cape Spellbook'.split(),
}
PROPS = {'mayor': ['Prop_Ledger'], 'militia_captain': ['1H_Sword', 'Round_Shield'],
         'widow_anna': ['Prop_Basket'], 'gourmand': ['Prop_Ladle']}


def read_glb(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and length == len(raw), 'invalid GLB header'
    chunks = {}
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        chunks[kind] = raw[offset:offset + size]
        offset += size
    return json.loads(chunks[0x4E4F534A]), chunks.get(0x004E4942, b'')


def accessor(doc, data, index):
    a = doc['accessors'][index]
    assert 'sparse' not in a, 'sparse accessor requires explicit inspection'
    view = doc['bufferViews'][a['bufferView']]
    kinds = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
    dimensions = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
    fmt = '<' + kinds[a['componentType']] * dimensions[a['type']]
    step = view.get('byteStride', struct.calcsize(fmt))
    start = view.get('byteOffset', 0) + a.get('byteOffset', 0)
    values = [struct.unpack_from(fmt, data, start + i * step) for i in range(a['count'])]
    if a.get('normalized') and a['componentType'] in (5121, 5123):
        divisor = 255 if a['componentType'] == 5121 else 65535
        values = [tuple(x / divisor for x in row) for row in values]
    return values


def check(path):
    doc, data = read_glb(path)
    issues = []
    def require(ok, reason):
        if not ok:
            issues.append(reason)
    hero = path.parent.name == 'hero'
    nodes = doc.get('nodes', [])
    names = {n.get('name', '') for n in nodes}
    skins = doc.get('skins', [])
    require(bool(skins), 'no skin')
    bone_names = {nodes[j].get('name') for s in skins for j in s['joints']}
    require(set(BONES) <= bone_names, 'missing bones: ' + ','.join(sorted(set(BONES)-bone_names)))
    clips = {a.get('name'): a for a in doc.get('animations', [])}
    require(set(CLIPS) <= set(clips), 'missing clips: ' + ','.join(sorted(set(CLIPS)-set(clips))))
    for name, clip in clips.items():
        require(bool(clip.get('channels')), 'empty clip ' + str(name))
        require(all(max(row[0] for row in accessor(doc, data, sampler['input'])) > 0
                    for sampler in clip.get('samplers', [])), 'zero duration clip ' + str(name))
    required = PROPS.get(path.stem, [])
    for role, gear in GEAR.items():
        if hero and role in path.stem:
            required += gear
    require(set(required) <= names, 'missing objects: ' + ','.join(sorted(set(required)-names)))
    parent_ids={c:i for i,n in enumerate(nodes) for c in n.get('children',[])}
    expected_mounts={'1H_Sword':'handslot.r','2H_Sword':'handslot.r',
                     '1H_Wand':'handslot.r','2H_Staff':'handslot.r',
                     'Knight_Helmet':'Head','Mage_Hat':'Head',
                     'Prop_Ledger':'handslot.l','Prop_Basket':'handslot.l','Prop_Ladle':'Hips'}
    for i,node in enumerate(nodes):
        name=node.get('name')
        if name in expected_mounts:
            parent_name=nodes[parent_ids[i]].get('name') if i in parent_ids else None
            require(parent_name==expected_mounts[name], f'{name} mount is {parent_name}')
    if hero:
        for suffix in ('_Body', '_Head', '_ArmLeft', '_ArmRight', '_LegLeft', '_LegRight'):
            require(any(n.endswith(suffix) for n in names), 'missing suffix ' + suffix)
    mesh_triangles = []
    weighted_vertices = 0
    for mesh in doc.get('meshes', []):
        mesh_triangles.append(0)
        for prim in mesh.get('primitives', []):
            require(prim.get('mode', 4) == 4, 'non-triangle geometry')
            attrs = prim['attributes']
            mesh_triangles[-1] += doc['accessors'][prim.get('indices', attrs['POSITION'])]['count'] // 3
            require('TEXCOORD_0' in attrs, 'UV missing: ' + mesh.get('name', ''))
            require('NORMAL' in attrs, 'normals missing: ' + mesh.get('name', ''))
            require('WEIGHTS_1' not in attrs, 'more than four skin influences')
            if 'WEIGHTS_0' in attrs:
                weights = accessor(doc, data, attrs['WEIGHTS_0'])
                weighted_vertices += len(weights)
                require(all(abs(sum(w)-1.0)<0.015 and min(w)>=0 for w in weights), 'invalid skin weight sums')
            require(all(all(math.isfinite(x) for x in v) for v in accessor(doc, data, attrs['POSITION'])), 'nonfinite vertices')
    triangles = sum(mesh_triangles[n['mesh']] for n in nodes if 'mesh' in n)
    require(triangles <= (12000 if hero else 8000), f'{triangles} triangles exceeds budget')
    materials = doc.get('materials', [])
    require(0 < len(materials) <= 3, f'{len(materials)} materials')
    require(sum(m.get('alphaMode') == 'BLEND' for m in materials) <= 1, 'too many blended materials')
    images = doc.get('images', [])
    require(len(images) == 1, f'expected one embedded atlas, got {len(images)} images')
    for image in images:
        require('bufferView' in image, 'external texture')
        if 'bufferView' in image:
            v = doc['bufferViews'][image['bufferView']]
            png = data[v.get('byteOffset', 0):v.get('byteOffset', 0)+v['byteLength']]
            require(png[:8] == b'\x89PNG\r\n\x1a\n', 'atlas not PNG')
            if png[:8] == b'\x89PNG\r\n\x1a\n':
                width,height = struct.unpack_from('>II', png, 16)
                require(max(width,height) <= (2048 if hero else 1024), 'atlas exceeds resolution budget')
    # Compare rest hierarchies independently of mesh variations.
    joint_ids = {j for skin in skins for j in skin['joints']}
    parents = {child: i for i,n in enumerate(nodes) for child in n.get('children', [])}
    signature = {}
    for i in joint_ids:
        n = nodes[i]
        p = parents.get(i)
        signature[n.get('name')] = {'parent': nodes[p].get('name') if p in joint_ids else None,
                                  **{k: n[k] for k in ('translation','rotation','scale','matrix') if k in n}}
    for view in ('front','side','back','action'):
        require((ROOT/'art_src/renders'/f'{path.stem}_{view}.png').is_file(), 'missing render ' + view)
    require((ROOT/'art_src/models'/f'{path.stem}.blend').is_file(), 'missing Blender source')
    return {'name':path.stem,'triangles':triangles,'materials':len(materials),'clips':len(clips),
            'weighted_vertices':weighted_vertices,'issues':issues}, signature


def main():
    paths = [Path(p) for p in sys.argv[1:]]
    if not paths:
        paths = [ROOT/'assets/characters'/('hero' if i<8 else 'cast')/(name+'.glb')
                 for i,name in enumerate(NAMES)]
    reports=[]
    reference=None
    for path in paths:
        try:
            report, signature=check(path)
            if reference is None:
                reference=signature
            elif reference!=signature:
                report['issues'].append('shared rig rest transforms differ')
        except Exception as exc:
            report={'name':path.stem,'issues':[str(exc)]}
        reports.append(report)
        print(('FAIL ' if report['issues'] else 'OK ')+json.dumps(report,ensure_ascii=False))
    (ROOT/'art_src/export_verification.json').write_text(json.dumps(reports,indent=2),encoding='utf-8')
    raise SystemExit(int(any(r['issues'] for r in reports)))


if __name__ == '__main__':
    main()
