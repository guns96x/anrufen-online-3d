"""Checks delivered GLB models against docs/model-handoff-codex.md.

python tools/validate_models.py [file.glb ...]   (default: all hero, cast and creature GLBs)
"""
import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HUMANOID_BONES = ['Hips', 'Spine', 'Chest', 'Neck', 'Head', 'LeftUpperArm', 'LeftLowerArm', 'LeftHand',
                  'RightUpperArm', 'RightLowerArm', 'RightHand', 'LeftUpperLeg', 'LeftLowerLeg', 'LeftFoot',
                  'RightUpperLeg', 'RightLowerLeg', 'RightFoot', 'handslot.l', 'handslot.r']
HUMANOID_CLIPS = ['Idle', 'Walking_A', 'Running_A', '1H_Melee_Attack_Slice_Diagonal', 'Spellcast_Shoot',
                  'Dodge_Forward', 'Hit_A', 'Death_A', 'Interact']
CREATURE_CLIPS = ['Idle', 'Walk', 'Attack', 'Hit', 'Death']
BUDGET = {'hero': 12000, 'cast': 8000, 'creatures': 6000}


def gltf_json(path: Path) -> dict:
    data = path.read_bytes()
    length = struct.unpack('<I', data[12:16])[0]
    return json.loads(data[20:20 + length])


def triangles(doc: dict) -> int:
    total = 0
    for mesh in doc.get('meshes', []):
        for prim in mesh['primitives']:
            if 'indices' in prim:
                total += doc['accessors'][prim['indices']]['count'] // 3
            else:
                total += doc['accessors'][prim['attributes']['POSITION']]['count'] // 3
    return total


def check(path: Path) -> list:
    problems = []
    kind = 'creatures' if path.parent.name == 'creatures' else path.parent.name
    doc = gltf_json(path)
    tris = triangles(doc)
    if tris > BUDGET.get(kind, 12000):
        problems.append(f'{tris} triangles > {BUDGET.get(kind)}')
    clips = {a.get('name', '') for a in doc.get('animations', [])}
    needed = CREATURE_CLIPS if kind == 'creatures' else HUMANOID_CLIPS
    missing = [c for c in needed if c not in clips]
    if missing:
        problems.append('missing clips: ' + ', '.join(missing))
    if kind in ('hero', 'cast'):
        bones = {doc['nodes'][j].get('name', '') for skin in doc.get('skins', []) for j in skin['joints']}
        absent = [b for b in HUMANOID_BONES if b not in bones]
        if absent:
            problems.append('missing bones: ' + ', '.join(absent))
    if len(doc.get('materials', [])) > 3:
        problems.append(f"{len(doc['materials'])} materials > 3")
    return problems


files = [Path(p) for p in sys.argv[1:]] or sorted(
    list((ROOT / 'assets/characters/hero').glob('*.glb')) + list((ROOT / 'assets/characters/cast').glob('*.glb'))
    + list((ROOT / 'assets/creatures').glob('*.glb')))
failed = 0
for f in files:
    issues = check(f)
    print(('OK   ' if not issues else 'FAIL ') + str(f.relative_to(ROOT) if f.is_absolute() else f) + ('' if not issues else ' — ' + '; '.join(issues)))
    failed += bool(issues)
print(f'MODELS: {len(files) - failed}/{len(files)} pass')
sys.exit(1 if failed else 0)
