"""Print length-delimited source strings and intervening numeric bytes for audit."""
import argparse
import struct
import zlib
from extract_original_tables import DEFAULT_SOURCE, strings

parser = argparse.ArgumentParser()
parser.add_argument('table')
parser.add_argument('id', type=int)
args = parser.parse_args()
data = (DEFAULT_SOURCE / (args.table+'.godat')).read_bytes()
count = struct.unpack_from('<I',data,15)[0]
entries = [struct.unpack_from('<III',data,23+i*12) for i in range(count)]
offset = next(offset for record_id,offset,_ in entries if record_id == args.id)
_,_,size,unpacked = struct.unpack_from('<IIII',data,offset)
payload = data[offset+16:offset+16+size]
if unpacked: payload = zlib.decompress(payload)
previous = 0
for value in strings(payload):
    pattern = struct.pack('<I',len(value))+value.encode('utf-16-le')
    start = payload.find(pattern,previous)
    if start < 0: continue
    gap = payload[previous:start]
    if gap:
        print(f'NUM @{previous} [{len(gap)} bytes]:', list(struct.unpack('<'+'I'*(len(gap)//4),gap[:len(gap)//4*4])), 'tail',gap[len(gap)//4*4:].hex())
    print(f'STR @{start}:',repr(value[:120]))
    previous = start+len(pattern)
gap = payload[previous:]
print(f'END @{previous} [{len(gap)} bytes]:',list(struct.unpack('<'+'I'*(len(gap)//4),gap[:len(gap)//4*4])), 'tail',gap[len(gap)//4*4:].hex())
