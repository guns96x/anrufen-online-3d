"""Reproduce audited pet source data without executing Lua or writing by default.

Run with python -B. Only --write replaces data/original/pet_rules.json.
Unknown source fields and disputed units are retained, never balanced here.
"""
import argparse
import hashlib
import json
import struct
from collections import Counter
from pathlib import Path

from extract_original_tables import DEFAULT_SOURCE, payload_records, strings
import extract_skill_rules

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'data/original/pet_rules.json'
TIMESTAMP_ID = 10000001
TABLES = ('all_pet', 'all_petData', 'all_character', 'all_skill', 'all_prop',
          'all_task', 'all_citizen', 'AnbufenUI')


class Reader:
    def __init__(self, payload):
        self.payload = payload
        self.position = 0
        self.source_strings = []

    def u32(self):
        if self.position + 4 > len(self.payload):
            raise ValueError(f'truncated u32 at {self.position}')
        value = struct.unpack_from('<I', self.payload, self.position)[0]
        self.position += 4
        return value

    def text(self):
        count = self.u32()
        end = self.position + count * 2
        if end > len(self.payload):
            raise ValueError(f'truncated string at {self.position - 4}')
        value = self.payload[self.position:end].decode('utf-16-le')
        self.position = end
        self.source_strings.append(value)
        return value

    def finish(self):
        if self.position != len(self.payload):
            raise ValueError(f'unconsumed payload: {self.position}/{len(self.payload)}')


def _record_meta(row, consumed):
    return {'id': row['id'], 'source_record_offset': row['offset'],
            'source_index_name': row['name'], 'payload_bytes': len(row['payload']),
            'payload_sha256': hashlib.sha256(row['payload']).hexdigest(),
            'consumed_bytes': consumed}


def _appearance(reader):
    count = reader.u32()
    if count != 1:
        raise ValueError(f'unreviewed appearance count {count}')
    # The fourth field is an actual length-prefixed string, often empty.
    fields = [reader.text() for _ in range(4)]
    metadata = [reader.u32(), reader.u32()]
    speech_count = reader.u32()
    speech = [reader.text() for _ in range(speech_count)]
    return {'appearance_count_raw': count, 'strings_raw': fields,
            'model_resource': fields[0], 'summon_effect': fields[1],
            'icon_resource': fields[2], 'additional_text': fields[3],
            'speech_metadata_raw': metadata, 'speech_count_raw': speech_count,
            'dialogues': speech}


def parse_species(row):
    reader = Reader(row['payload'])
    record_type = reader.u32()
    name = reader.text()
    base = _appearance(reader)
    form_count = reader.u32()
    forms = []
    for _ in range(form_count):
        index = reader.u32()
        form_name = reader.text()
        forms.append({'index_raw': index, 'name': form_name,
                      **_appearance(reader)})
    tail = [reader.u32() for _ in range(7)]
    reader.finish()
    return {**_record_meta(row, reader.position), 'record_type_raw': record_type,
            'name': name, 'base': base, 'form_count_raw': form_count,
            'forms': forms, 'tail_raw': tail, 'lifespan_raw': tail[1],
            'lifespan_unit': None,
            'lifespan_interpretation': 'structural inference; units and drain rule unknown',
            'template_id': tail[4], 'innate_count_raw': tail[5],
            'innate_skill_id': tail[6], 'source_strings': reader.source_strings}


def parse_template(row):
    reader = Reader(row['payload'])
    name = reader.text()
    count = reader.u32()
    triples = [[reader.u32() for _ in range(3)] for _ in range(count)]
    reader.finish()
    return {**_record_meta(row, reader.position), 'name': name,
            'row_count_raw': count, 'columns': ['index_raw', 'unknown_1', 'unknown_2'],
            'triples_raw': triples, 'source_strings': reader.source_strings}


def parse_personality(row):
    reader = Reader(row['payload'])
    name, label = reader.text(), reader.text()
    metadata = [reader.u32(), reader.u32()]
    count = reader.u32()
    dialogues = [reader.text() for _ in range(count)]
    reader.finish()
    return {**_record_meta(row, reader.position), 'name': name, 'label': label,
            'speech_metadata_raw': metadata, 'speech_count_raw': count,
            'dialogues': dialogues, 'source_strings': reader.source_strings}


def payload_segments(payload):
    """Lossless coverage, not a claim to decode unknown skill effect structures."""
    segments = []
    previous = 0
    for span in strings(payload, with_spans=True):
        if previous < span['start']:
            segments.append({'kind': 'raw', 'start': previous, 'end': span['start'],
                             'hex': payload[previous:span['start']].hex()})
        segments.append({'kind': 'string', 'start': span['start'], 'end': span['end'],
                         'value': span['text']})
        previous = span['end']
    if previous < len(payload):
        segments.append({'kind': 'raw', 'start': previous, 'end': len(payload),
                         'hex': payload[previous:].hex()})
    return segments


def reconstruct_segments(segments):
    payload = bytearray()
    for segment in segments:
        if segment['start'] != len(payload):
            raise ValueError('noncontiguous payload segments')
        if segment['kind'] == 'raw':
            part = bytes.fromhex(segment['hex'])
        else:
            encoded = segment['value'].encode('utf-16-le')
            part = struct.pack('<I', len(encoded) // 2) + encoded
        if len(payload) + len(part) != segment['end']:
            raise ValueError('incorrect segment extent')
        payload.extend(part)
    return bytes(payload)


def parse_skill(row, rule):
    payload = row['payload']
    reader = Reader(payload)
    first_strings = [reader.text() for _ in range(4)]
    header_offset = reader.position
    header = [reader.u32() for _ in range(17)]
    original_strings = strings(payload)
    if original_strings[:2] != [rule['source_name'], rule['source_description']]:
        raise ValueError(f'stale all_skill.json for {row["id"]}')
    copies = [span for span in strings(payload, True)
              if span['text'] == rule['source_description']]
    candidate = {'status': 'no_flat_cost_anchor', 'amount': None}
    if len(copies) >= 2 and copies[1]['start'] >= 28:
        start = copies[1]['start'] - 28
        values = list(struct.unpack_from('<7I', payload, start))
        if values[:3] == [3, 0, 10] and values[4:] == [0, 0, 1]:
            candidate = {'status': 'inferred_flat_mana_cost', 'amount': values[3],
                         'block_offset': start, 'block_raw': values,
                         'description_offset': copies[1]['start'],
                         'inference': 'candidate MP cost; block semantics not fully decoded'}
    segments = payload_segments(payload)
    if reconstruct_segments(segments) != payload:
        raise ValueError(f'lossy skill payload {row["id"]}')
    return {**_record_meta(row, len(payload)),
            'kind': 'innate' if rule['section'] == '魔法兽固有技能' else 'random',
            'section': rule['section'], 'name': rule['source_name'],
            'description': rule['source_description'], 'source_strings': original_strings,
            'first_four_strings_raw': first_strings, 'header_offset': header_offset,
            'header_17_u32_raw': header, 'raw_rank_limit': header[0], 'max_rank': header[0],
            'source_requirement_raw': header[2], 'source_range_raw': header[13],
            'cast_milliseconds_raw': header[15], 'cooldown_milliseconds_raw': header[16],
            'constants': rule['constants'],
            'lua_constant_lengths': {key: len(value) for key, value in rule['constants'].items()},
            'mana_cost_candidate': candidate['amount'],
            'mana_cost_candidate_evidence': candidate, 'payload_segments': segments}


TALENT_FOODS = {
    'physical_attack': ([31137, 30780], 10), 'magic_attack': ([31138, 30781], 10),
    'hp': ([31139, 30782], 60), 'mp': ([30661, 30783], 60),
    'defense': ([31140, 30784], 5), 'resistance': ([30662, 30785], 5),
    'accuracy': ([31141, 30786], 6), 'evasion': ([30660, 30787], 3),
}
CONSUMABLES = {
    'food': [30022, 30705], 'revival': [30025, 30703], 'experience': [30006],
    'lifespan_to_juvenile': [30015, 30988], 'lifespan_back_one_stage': [30989],
    'capacity_plus_one': [30595, 30727], 'wooden_incubator': [30166, 30657],
    'metal_incubator': [31147, 30704], 'magic_incubator': [31149],
    'transformation_boost_small': [30164, 30694], 'transformation_boost_large': [30730],
    'transformation_failure_protection': [30731, 30696],
    'transformation_guaranteed_rank_three_threshold': [30253],
    'primary_replacement_slot_1': [30749], 'primary_replacement_slot_2': [30023],
    'primary_replacement_slot_3': [30750], 'donor_skill_slot_1': [30751],
    'donor_skill_slot_2': [30752], 'donor_skill_slot_3': [30753],
    'pet_hp_potions': [30020, 30021, 30485, 31130, 31131, 30729],
    'pet_mp_potions': [30754, 30755, 30756, 30757, 30758, 30778],
}
TACTICS = {
    'attack_owner_target': '攻击模式-攻击主人正在攻击的目标',
    'retaliate_owner_attacker': '反击模式-攻击正在攻击主人的目标',
    'support_only': '辅助模式-只使用辅助技能',
    'free_attack_visible_enemy': '自由攻击-主动攻击进入视野的敌人',
    'standby_follow': '待机模式-跟随主人什么也不干',
}


def semantic_index(tables):
    selected = {'all_prop': set(), 'all_task': {80593, 80594, 80601, 80606, 80253,
                                              80259, 80268, 80410, 80612, 80613},
                'all_citizen': {50180}, 'AnbufenUI': {10018, 10036, 10042, 10043, 10066}}
    for ids in CONSUMABLES.values():
        selected['all_prop'].update(ids)
    for ids, _ in TALENT_FOODS.values():
        selected['all_prop'].update(ids)
    evidence = {}
    for table, ids in selected.items():
        evidence[table] = {}
        for record_id in sorted(ids):
            row = tables[table][record_id]
            evidence[table][str(record_id)] = {
                **_record_meta(row, len(row['payload'])), 'source_strings': strings(row['payload'])}
    tactic_source = evidence['all_task']['80593']['source_strings'][13]
    if not all(value in tactic_source for value in TACTICS.values()):
        raise ValueError('tactic tutorial changed')
    if '副魔法兽都会消失' not in evidence['all_citizen']['50180']['source_strings'][10]:
        raise ValueError('transformation tutorial changed')
    if '只有同类型魔法兽' not in evidence['all_citizen']['50180']['source_strings'][12]:
        raise ValueError('transfer tutorial changed')
    for key, (ids, increment) in TALENT_FOODS.items():
        for record_id in ids:
            if not any(str(increment) in text for text in evidence['all_prop'][str(record_id)]['source_strings']):
                raise ValueError(f'talent increment changed: {key}/{record_id}')
    return {
        'evidence_kind': 'direct_source_text; interpretations summarized without server formulas',
        'consumable_groups': CONSUMABLES,
        'talent_foods': {key: {'ids': ids, 'increment': increment, 'evidence_kind': 'direct_source_text'}
                         for key, (ids, increment) in TALENT_FOODS.items()},
        'tactics': {key: {'source_numeric_id': None, 'source_text': text,
                         'evidence': {'table': 'all_task', 'id': 80593, 'string_index': 13}}
                    for key, text in TACTICS.items()},
        'transformation': {'evidence': {'table': 'all_citizen', 'id': 50180, 'string_index': 10},
                           'both_pets_resting': True, 'secondary_consumed_on_success_or_failure': True,
                           'success_primary_rank_increases': True, 'failure_primary_rank_change': -1,
                           'probability_formula': None},
        'skill_transfer': {'evidence': {'table': 'all_citizen', 'id': 50180, 'string_index': 12},
                           'same_type_required': True, 'type_comparison_field_candidate': 'species.template_id',
                           'secondary_consumed': True,
                           'selection_random_without_rune': True,
                           'random_skill_count_at_hatch': {'min': 1, 'max': 3, 'fixed_at_hatch': True,
                                                         'evidence': {'table': 'all_task', 'id': 80601, 'string_index': 6}}},
        'breeding': {'evidence': {'table': 'AnbufenUI', 'id': 10043},
                    'two_player_confirmation_ui': True, 'gender_and_generation_displayed': True,
                    'eligibility_and_inheritance_formula': None},
        'source_records': evidence,
    }


def extract():
    tables, sources, timestamps = {}, {}, {}
    for name in TABLES:
        rows, metadata = payload_records(DEFAULT_SOURCE / f'{name}.godat')
        tables[name] = {row['id']: row for row in rows}
        sources[f'{name}.godat'] = metadata
        if TIMESTAMP_ID in tables[name]:
            raw = tables[name][TIMESTAMP_ID]['payload']
            timestamps[name] = {'id': TIMESTAMP_ID, 'text_raw': raw.decode('utf-16-le'),
                                'payload_sha256': hashlib.sha256(raw).hexdigest()}
    parsed = {}
    for name, output_key, parser in [('all_pet', 'species', parse_species),
                                     ('all_petData', 'templates', parse_template),
                                     ('all_character', 'personalities', parse_personality)]:
        parsed[output_key] = {str(key): parser(row) for key, row in sorted(tables[name].items())
                              if key != TIMESTAMP_ID}
    rules = extract_skill_rules.extract()
    skills = {key: parse_skill(tables['all_skill'][int(key)], rule)
              for key, rule in sorted(rules['skills'].items(), key=lambda item: int(item[0]))
              if rule['owner'] == 'pet'}
    for relative in ['data/balance/script_5005.lua', 'data/original/all_skill.json',
                     'data/original/scripts/attribute_const.lua']:
        raw = (ROOT / relative).read_bytes()
        sources[relative] = {'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
    semantics = semantic_index(tables)
    consumables = semantics['source_records'].pop('all_prop')
    for key, row in consumables.items():
        row['name'] = row['source_strings'][0]
        row['groups'] = [name for name, ids in CONSUMABLES.items() if int(key) in ids]
        for stat, (ids, amount) in TALENT_FOODS.items():
            if int(key) in ids:
                row['groups'].append('talent_food')
                row['talent_increment'] = {'stat': stat, 'amount': amount}
    tactics = semantics.pop('tactics')
    result = {'schema_version': 1, 'source_archive_root': 'anrufen_extracted/private/A000BA0E',
              'provenance': sources, 'excluded_timestamp_records': timestamps,
              'counts': {'species': len(parsed['species']), 'templates': len(parsed['templates']),
                         'personalities': len(parsed['personalities']), 'pet_skills': len(skills),
                         'innate_skills': sum(s['kind'] == 'innate' for s in skills.values()),
                         'random_skills': sum(s['kind'] == 'random' for s in skills.values()),
                         'all_skill_real_records': len(tables['all_skill']) - 1,
                         'lua_total_bindings': len(rules['skills']), 'lua_total_arrays': rules['arrays']},
              **parsed, 'skills': skills, 'consumables': consumables, 'tactics': tactics,
              'semantic_index': semantics,
              'unresolved': ['lifespan units and drain rules', 'incubation duration', 'starting ownership capacity',
                             'talent generation and caps', 'gender and personality probabilities',
                             'taming and breeding formulas', 'transformation probability and level requirements',
                             'complete skill runtime structure and source rank scaling',
                             'exact mapping of identically named chicken/duck eggs to duplicate species']}
    validate(result)
    return result


def validate(data):
    expected = {'species': 27, 'templates': 4, 'personalities': 12,
                'pet_skills': 53, 'innate_skills': 13, 'random_skills': 40,
                'all_skill_real_records': 165, 'lua_total_bindings': 97, 'lua_total_arrays': 171}
    if data['counts'] != expected:
        raise ValueError(f'unreviewed source counts: {data["counts"]}')
    for group in ['species', 'templates', 'personalities', 'skills']:
        for record in data[group].values():
            if record['consumed_bytes'] != record['payload_bytes']:
                raise ValueError(f'unconsumed {group} record {record["id"]}')
    for pet in data['species'].values():
        if pet['record_type_raw'] != 1001 or pet['form_count_raw'] != 7 or [f['index_raw'] for f in pet['forms']] != list(range(1, 8)):
            raise ValueError(f'unreviewed pet forms: {pet["id"]}')
        if pet['template_id'] and str(pet['template_id']) not in data['templates']:
            raise ValueError('unknown template reference')
        if pet['innate_count_raw'] != 1 or (pet['innate_skill_id'] and data['skills'][str(pet['innate_skill_id'])]['kind'] != 'innate'):
            raise ValueError('unknown innate reference')
    for template in data['templates'].values():
        if template['row_count_raw'] != 7 or template['triples_raw'] != [[i, 200, v] for i, v in enumerate([25, 45, 65, 85, 95, 105, 115], 1)]:
            raise ValueError('unreviewed template triples')
    if Counter(skill['kind'] for skill in data['skills'].values()) != {'innate': 13, 'random': 40}:
        raise ValueError('incorrect skill classification')


def serialize(data):
    return json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--write', action='store_true', help='replace the generated JSON only')
    mode.add_argument('--check', action='store_true', help='also compare generated bytes with committed JSON')
    args = parser.parse_args()
    data = extract()
    encoded = serialize(data)
    if args.write:
        OUTPUT.write_text(encoded, encoding='utf-8', newline='\n')
    elif args.check and (not OUTPUT.exists() or OUTPUT.read_bytes() != encoded.encode('utf-8')):
        raise SystemExit('PET_SOURCE_EXTRACTION: FAIL; run --write to regenerate reviewed data')
    print('PET_SOURCE_EXTRACTION: PASS; 27 species, 4 templates, 12 personalities, 53 pet skills; '
          + ('JSON written' if args.write else 'no files written'))


if __name__ == '__main__':
    main()
