"""Read-only Godat source decoder; export records without guessing numeric fields.

GodReport archive index: count@15, entries(id, offset, flags)@23, 12 bytes each.
Record header: four uint32 values, stored size third, unpacked size fourth.
Strings are uint32 character count followed by UTF-16LE, even when the enclosing
record has odd alignment. The older byte-run heuristic could swallow adjacent
numeric bytes into names. Never scan for a zlib marker inside another record.
"""
import argparse
import hashlib
import json
import struct
import unicodedata
import zlib
from pathlib import Path

DEFAULT_SOURCE = Path(r'C:\Users\pavlo\anrufen_extracted\private\A000BA0E')
ROOT = Path(__file__).resolve().parents[1]
TABLES = ['all_prop', 'all_pet', 'all_petData', 'all_title', 'all_skill',
          'all_skilltree', 'all_shop', 'all_combine', 'all_buff', 'all_guarder',
          'all_union', 'all_citizen', 'all_suit', 'all_role', 'all_race', 'AnbufenUI',
          'all_task', 'all_equip', 'all_monster', 'all_scene', 'all_character', 'all_property']


def strings(payload, with_spans=False):
    found = []
    offset = 0
    while offset + 8 <= len(payload):
        length = struct.unpack_from('<I', payload, offset)[0]
        end = offset + 4 + length * 2
        if 2 <= length <= 12000 and end <= len(payload):
            try:
                value = payload[offset+4:end].decode('utf-16-le')
            except UnicodeDecodeError:
                value = ''
            allowed = value and all(c.isprintable() or c in '\r\n\t' for c in value)
            allowed = allowed and not any(unicodedata.category(c) in {'Co', 'Cs', 'Cn'} for c in value)
            if allowed and any(c.isalpha() for c in value):
                found.append({'start':offset,'end':end,'text':value} if with_spans else value)
                offset = end
                continue
        offset += 1
    return found


def payload_records(path):
    data = path.read_bytes()
    if len(data) < 23:
        raise ValueError(f'{path.name}: truncated index')
    count, index_size = struct.unpack_from('<II', data, 15)
    if count > 100000 or 23 + count * 12 > len(data):
        raise ValueError(f'{path.name}: invalid record count')
    result = []
    seen = set()
    position = 23
    for index in range(count):
        record_id, offset, name_length = struct.unpack_from('<III', data, position)
        position += 12
        name = data[position:position+name_length].decode('gbk')
        position += name_length
        if record_id in seen or offset < 23+index_size or offset+16 > len(data):
            raise ValueError(f'{path.name}: invalid/duplicate entry {record_id}')
        seen.add(record_id)
        first, second, size, unpacked = struct.unpack_from('<IIII', data, offset)
        if offset+16+size > len(data):
            raise ValueError(f'{path.name}: record {record_id} overruns archive')
        payload = data[offset+16:offset+16+size]
        if unpacked:
            payload = zlib.decompress(payload)
            if len(payload) != unpacked:
                raise ValueError(f'{path.name}: record {record_id} size mismatch')
        result.append({'id': record_id, 'offset': offset, 'name':name, 'payload':payload})
    if position != 23+index_size:
        raise ValueError(f'{path.name}: incorrect index size')
    return result, {'records': count, 'sha256': hashlib.sha256(data).hexdigest()}


def records(path):
    rows, metadata = payload_records(path)
    return [{'id':row['id'],'offset':row['offset'],'strings':strings(row['payload'])} for row in rows], metadata


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    manifest = {}
    for name in TABLES:
        rows, manifest[name] = records(args.source / f'{name}.godat')
        target = ROOT / 'data/original' / f'{name}.json'
        old = json.loads(target.read_text(encoding='utf-8')) if target.exists() else []
        old_by_id = {r['id']: r.get('strings', []) for r in old}
        changed = sum(old_by_id.get(r['id']) != r['strings'] for r in rows)
        print(f'{name}: {len(rows)} records, {changed} string records changed')
        if args.write:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(json.dumps(rows, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    if args.write:
        (ROOT / 'docs/original-archive-manifest.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
