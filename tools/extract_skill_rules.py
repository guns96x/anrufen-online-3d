"""Recover original Lua numeric arrays and per-skill bindings without executing Lua."""
import hashlib
import json
import re
import struct
import zlib
from pathlib import Path
from extract_original_tables import DEFAULT_SOURCE

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'data/balance/script_5005.lua'
SECTION_ROLES = {'见习战士':130001,'战士':130004,'狂战士':130007,'圣骑士':130006,
                 '见习法师':130002,'法师':130005,'元素法师':130008,'暗影法师':130009}


def skill_headers():
    data = (DEFAULT_SOURCE/'all_skill.godat').read_bytes()
    count = struct.unpack_from('<I',data,15)[0]
    headers = {}
    for i in range(count):
        record_id, offset, _ = struct.unpack_from('<III',data,23+i*12)
        if record_id == 10000001: continue
        _,_,size,unpacked = struct.unpack_from('<IIII',data,offset)
        payload = data[offset+16:offset+16+size]
        if unpacked: payload = zlib.decompress(payload)
        position = 0
        for _ in range(4):
            length = struct.unpack_from('<I',payload,position)[0]
            position += 4+length*2
            assert position <= len(payload), record_id
        values = struct.unpack_from('<17I',payload,position)
        headers[record_id] = {'max_rank':values[0],'source_requirement':values[2],'prerequisite_skill':values[3],
            'prerequisite_rank':values[4],'source_range':values[13],
            'cast_seconds':values[15]/1000,'cooldown':values[16]/1000}
    # Explicit source sentence says 45 seconds; this anchors the common field.
    assert headers[90106]['cooldown'] == 45.0
    assert headers[90095]['prerequisite_skill'] == 90042
    return headers


def extract():
    raw = SOURCE.read_bytes()
    text = raw.decode('gbk')
    arrays = {}
    for match in re.finditer(r'(SKILL_CONST_\w+)\s*=\s*\{([^{}]*)\}', text):
        parts = [x.strip() for x in match[2].split(',') if x.strip()]
        assert parts and all(re.fullmatch(r'[+-]?\d+(?:\.\d+)?', x) for x in parts), match[1]
        arrays[match[1]] = [int(x) if '.' not in x else float(x) for x in parts]
    sections = [(m.start(), m[1].strip()) for m in re.finditer(r'-{5,}([^\r\n-]+)-{5,}', text)]
    records = {r['id']: r for r in json.loads((ROOT/'data/original/all_skill.json').read_text(encoding='utf-8'))}
    headers = skill_headers()
    result = {}
    for match in re.finditer(r'TABLE_SKILL_CONST\[(\d+)\]\s*=\s*\{([^{}]*)\}', text):
        skill_id = int(match[1])
        section = next((name for pos, name in reversed(sections) if pos < match.start()), '')
        constants = {}
        pairs = re.findall(r'(\w+)\s*=\s*(SKILL_CONST_\w+)', match[2])
        assert pairs, skill_id
        for key, name in pairs:
            assert name in arrays, (skill_id, name)
            constants[key] = arrays[name]
        source_strings = records[skill_id]['strings']
        result[str(skill_id)] = {'id':skill_id,'source_name':source_strings[0],
            'source_description':source_strings[1] if len(source_strings)>1 else '',
            'owner':'player' if section in SECTION_ROLES else 'pet',
            'class_id':SECTION_ROLES.get(section,0),'section':section,
            'max_rank':max(map(len, constants.values())), 'constants':constants}
        result[str(skill_id)].update(headers[skill_id])
    return {'source':'data/balance/script_5005.lua','source_sha256':hashlib.sha256(raw).hexdigest(),
            'arrays':len(arrays),'skills':result}


if __name__ == '__main__':
    data = extract()
    path = ROOT / 'data/original/skill_rules.json'
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    players = [x for x in data['skills'].values() if x['owner']=='player']
    print(f'SKILL_RULES: {len(data["skills"])} source bindings, {len(players)} player skills, {data["arrays"]} numeric arrays')
    print('Class counts:', {role:sum(x['class_id']==role for x in players) for role in SECTION_ROLES.values()})
