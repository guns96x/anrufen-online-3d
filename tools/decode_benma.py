import json
import struct
import sys
from pathlib import Path

sys.path.insert(0, 'tools')
from extract_original_tables import payload_records

# 1. Extract benma.wim
mapfile_city_path = Path(r'C:\Users\pavlo\anrufen_extracted\private\A000BA0E\mapfile_city.godat')
recs, _ = payload_records(mapfile_city_path)
benma_wim_rec = next(r for r in recs if r['name'] == 'city\\city-benmacheng.wim')
wim_payload = benma_wim_rec['payload']

out_dir = Path('docs/reference/benma')
out_dir.mkdir(parents=True, exist_ok=True)

wim_out = out_dir / 'benma.wim'
wim_out.write_bytes(wim_payload)
print(f"Saved {wim_out} ({len(wim_payload)} bytes)")

# 2. Extract catalog
catalog = {}
with open('docs/reference/resource_catalog.tsv', 'r', encoding='utf-8', errors='ignore') as f:
    for line in f:
        parts = line.strip().split('\t')
        if len(parts) >= 2:
            catalog[parts[0]] = {
                'file': parts[1],
                'id1': parts[2] if len(parts) > 2 else '0',
                'id2': parts[3] if len(parts) > 3 else '0',
                'pal': parts[4] if len(parts) > 4 else '0'
            }

# 3. Extract citizens
with open('data/original/all_citizen.json', 'r', encoding='utf-8') as f:
    all_cit = {c['id']: c for c in json.load(f)}

benma_cit_tiles = [
    (50186, '奔马城城主', 17, 25),
    (50187, '兽人警卫队长', 12, 7),
    (50189, '侏儒商队首领', 9, 28),
    (50190, '兽人兄', 43, 45),
    (50191, '兽人妹', 45, 45),
    (50192, '幸运的卡卡', 12, 28),
    (50193, '战争铁匠', 14, 15),
    (50194, '城主秘书', 15, 25),
    (50195, '国王特使', 32, 10),
    (50197, '兽人村民', 32, 51),
    (50198, '兽人村民', 42, 55),
    (50199, '侏儒村民', 8, 39),
    (50200, '侏儒村民', 15, 49),
    (50201, '人类村民', 20, 41),
    (50202, '人类村民', 27, 36),
    (50183, '人类信箱', 49, 26),
    (50181, '珍奇宝石寄售商人', 20, 4),
    (50180, '驯兽师（人类）', 44, 20),
    (50178, '道具商人（人类）', 39, 11),
    (50424, '驿站老板（人类）', 32, 43),
    (50188, '皇家骑士特使', 32, 21),
    (50490, '武器寄售商人', 14, 4),
    (50492, '防具寄售商人', 17, 4),
    (50493, '饰品寄售商人', 25, 10),
    (50494, '魔法兽寄售商人', 12, 10),
    (50495, '杂货寄售商人', 28, 10),
    (50030, '饰品商人（人类）', 14, 19),
    (50039, '武器商人（人类）', 49, 18),
    (50044, '宝石匠（人类）', 49, 11),
    (50041, '防具商人（人类）', 44, 11),
    (50061, '魔法储物箱', 29, 18),
]

npcs_list = []
for cid, name, x, y in benma_cit_tiles:
    c = all_cit.get(cid, {})
    strs = c.get('strings', [])
    sprite = strs[1] if len(strs) > 1 else 'NPC-居民'
    cat = catalog.get(sprite)
    if cat:
        res_base = cat.get('file', '').replace('.godat', '')
        res_id = cat.get('id1', '0')
        res = f"{res_base}__{res_id}" if res_id != '0' else res_base
        pal = cat.get('pal', '0')
    else:
        # Explicitly handle non-catalog/unresolved resources rather than fabricating an npc_res default
        res = f"unresolved__{sprite}"
        pal = '0'
    npcs_list.append({
        'name': name,
        'id': cid,
        'x': x,
        'y': y,
        'sprite': sprite,
        'res': res,
        'pal': pal
    })

npcs_out = out_dir / 'benma_npcs.json'
npcs_out.write_text(json.dumps(npcs_list, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
print(f"Saved {npcs_out} ({len(npcs_list)} NPCs)")
