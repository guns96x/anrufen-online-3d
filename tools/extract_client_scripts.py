"""Decode variable-filename Godat index; never execute recovered Lua."""
import hashlib
import json
import struct
import zlib
from pathlib import Path, PureWindowsPath
from extract_original_tables import DEFAULT_SOURCE, ROOT


def extract():
    archive = (DEFAULT_SOURCE/'clt_script.godat').read_bytes()
    count, index_size = struct.unpack_from('<II',archive,15)
    position = 23
    entries = []
    for _ in range(count):
        record_id, offset, length = struct.unpack_from('<III',archive,position)
        position += 12
        name = archive[position:position+length].decode('gbk')
        position += length
        entries.append((record_id,offset,name))
    assert position == 23+index_size
    manifest = {}
    for record_id, offset, name in entries:
        if not name: continue
        relative = PureWindowsPath(name)
        assert not relative.is_absolute() and '..' not in relative.parts and relative.suffix in ['.lua','.ini']
        _,_,size,unpacked = struct.unpack_from('<IIII',archive,offset)
        assert offset+16+size <= len(archive)
        payload = archive[offset+16:offset+16+size]
        if unpacked:
            payload = zlib.decompress(payload)
            assert len(payload) == unpacked
        text = payload.decode('gbk')
        target = ROOT/'data/original/scripts'/Path(*relative.parts)
        target.parent.mkdir(parents=True,exist_ok=True)
        target.write_text(text,encoding='utf-8')
        manifest[name] = {'id':record_id,'payload_sha256':hashlib.sha256(payload).hexdigest(),'payload_encoding':'gbk','export_encoding':'utf-8','bytes':len(payload)}
        print(f'{record_id}: {name}, {len(payload)} source bytes')
    (ROOT/'docs/original-script-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    return manifest


if __name__ == '__main__':
    extract()
