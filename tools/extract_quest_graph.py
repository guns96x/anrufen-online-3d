"""Recover every quest text and verified actor/next-task links without inventing rewards."""
import hashlib
import json
import struct
from pathlib import Path
from extract_original_tables import DEFAULT_SOURCE, ROOT, payload_records, records, strings


def extract():
    archive = DEFAULT_SOURCE/'all_task.godat'
    rows, metadata = payload_records(archive)
    scene_ids = {r['id'] for r in records(DEFAULT_SOURCE/'all_scene.godat')[0]}
    citizen_ids = {r['id'] for r in records(DEFAULT_SOURCE/'all_citizen.godat')[0]}
    quest_ids = {r['id'] for r in rows if 80000 <= r['id'] < 90000}
    result = {}
    for row in rows:
        if row['id'] not in quest_ids: continue
        payload = row['payload']
        spans = strings(payload,with_spans=True)
        texts = [x['text'] for x in spans]
        entry = {'id':row['id'],'source_title':texts[0] if texts else '',
                 'source_strings':texts,'payload_sha256':hashlib.sha256(payload).hexdigest(),
                 'next_id':0,'giver_id':0,'turnin_id':0,'giver_scene':0,'turnin_scene':0}
        if len(spans) >= 2 and spans[1]['end']+8 <= len(payload):
            entry['source_progress_words'] = list(struct.unpack_from('<II',payload,spans[1]['end']))
        for first, second in zip(spans,spans[1:]):
            gap = payload[first['end']:second['start']]
            if len(gap) != 32: continue
            values = struct.unpack('<8I',gap)
            if values[4] in scene_ids and values[5] in citizen_ids and values[6] in scene_ids and values[7] in citizen_ids:
                entry.update(giver_scene=values[4],giver_id=values[5],turnin_scene=values[6],turnin_id=values[7])
        if spans:
            tail = payload[spans[-1]['end']:]
            if len(tail)%4 == 0:
                entry['footer_words'] = list(struct.unpack('<'+'I'*(len(tail)//4),tail))
                if len(entry['footer_words']) > 1 and entry['footer_words'][1] in quest_ids:
                    entry['next_id'] = entry['footer_words'][1]
        result[str(row['id'])] = entry
    assert len(result) == 712
    assert result['80004']['next_id'] == 80591
    assert result['80004']['giver_id'] == 50164 and result['80004']['turnin_id'] == 50179
    assert result['80591']['next_id'] == 80552 and result['80006']['next_id'] == 80007
    return {'archive_sha256':metadata['sha256'],'quests':result}


def batches(graph):
    preferred = [80004,80591,80552,80005,80006,80007,80010,80011,80012,80013]
    remaining = [int(key) for key in graph['quests'] if int(key) not in preferred]
    order = preferred + sorted(remaining)
    output = ROOT/'data/original/quest_batches'
    output.mkdir(parents=True,exist_ok=True)
    for index in range(0,len(order),10):
        entries = [dict(id=id,strings=graph['quests'][str(id)]['source_strings']) for id in order[index:index+10]]
        target = output/f'{index//10+1:03d}.json'
        target.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    graph = extract()
    target = ROOT/'data/original/quest_graph.json'
    target.write_text(json.dumps(graph,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    batches(graph)
    rows = list(graph['quests'].values())
    print(f'QUEST_GRAPH: {len(rows)} records, {sum(r["next_id"]!=0 for r in rows)} next-task links, {sum(r["giver_id"]!=0 for r in rows)} actor routes')
