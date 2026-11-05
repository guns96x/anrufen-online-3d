"""Source fidelity checks; run python -B -m unittest discover -s tests -p test_pet_extraction.py."""
import copy
import hashlib
import json
import struct
import subprocess
import sys
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import extract_pet_rules as pet
from extract_original_tables import DEFAULT_SOURCE, payload_records


def encode_appearance(value):
    result = struct.pack('<I', value['appearance_count_raw'])
    for field in value['strings_raw']:
        result += encode_text(field)
    result += struct.pack('<3I', *value['speech_metadata_raw'], value['speech_count_raw'])
    return result + b''.join(encode_text(text) for text in value['dialogues'])


def encode_text(text):
    raw = text.encode('utf-16-le')
    return struct.pack('<I', len(raw) // 2) + raw


class PetExtractionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = pet.extract()
        cls.tables = {}
        for table in ['all_pet', 'all_petData', 'all_character', 'all_skill']:
            cls.tables[table] = {row['id']: row for row in payload_records(DEFAULT_SOURCE / f'{table}.godat')[0]}

    def test_exact_counts(self):
        self.assertEqual(self.data['counts'], {'species': 27, 'templates': 4, 'personalities': 12,
            'pet_skills': 53, 'innate_skills': 13, 'random_skills': 40,
            'all_skill_real_records': 165, 'lua_total_bindings': 97, 'lua_total_arrays': 171})

    def test_all_real_pet_template_personality_payloads_consumed(self):
        for key, table in [('species', 'all_pet'), ('templates', 'all_petData'), ('personalities', 'all_character')]:
            records = self.data[key]
            self.assertEqual({int(id) for id in records}, set(self.tables[table]) - {10000001})
            for id, row in records.items():
                with self.subTest(table=table, id=id):
                    original = self.tables[table][int(id)]['payload']
                    self.assertEqual(row['consumed_bytes'], len(original))
                    self.assertEqual(row['payload_bytes'], len(original))
                    self.assertEqual(row['payload_sha256'], hashlib.sha256(original).hexdigest())

    def test_every_species_field_roundtrips_original_bytes(self):
        for id, row in self.data['species'].items():
            payload = struct.pack('<I', row['record_type_raw']) + encode_text(row['name'])
            payload += encode_appearance(row['base']) + struct.pack('<I', row['form_count_raw'])
            for form in row['forms']:
                payload += struct.pack('<I', form['index_raw']) + encode_text(form['name']) + encode_appearance(form)
            payload += struct.pack('<7I', *row['tail_raw'])
            with self.subTest(id=id):
                self.assertEqual(payload, self.tables['all_pet'][int(id)]['payload'])

    def test_all_template_fields_roundtrip(self):
        for id, row in self.data['templates'].items():
            payload = encode_text(row['name']) + struct.pack('<I', row['row_count_raw'])
            payload += b''.join(struct.pack('<3I', *triple) for triple in row['triples_raw'])
            self.assertEqual(payload, self.tables['all_petData'][int(id)]['payload'])

    def test_all_personality_fields_roundtrip_without_stat_bonuses(self):
        for id, row in self.data['personalities'].items():
            payload = encode_text(row['name']) + encode_text(row['label'])
            payload += struct.pack('<3I', *row['speech_metadata_raw'], row['speech_count_raw'])
            payload += b''.join(encode_text(text) for text in row['dialogues'])
            self.assertEqual(payload, self.tables['all_character'][int(id)]['payload'])
            self.assertNotIn('bonuses', row)
        self.assertEqual(self.data['personalities']['190014']['name'], '谨慎')

    def test_base_and_seven_forms_in_every_species(self):
        for row in self.data['species'].values():
            self.assertEqual(row['record_type_raw'], 1001)
            self.assertEqual(row['form_count_raw'], 7)
            self.assertEqual([form['index_raw'] for form in row['forms']], list(range(1, 8)))
            self.assertEqual(len(row['base']['strings_raw']), 4)

    def test_nonempty_fourth_form_string(self):
        form = self.data['species']['140017']['forms'][0]
        self.assertEqual(form['additional_text'], '最牛魔法兽')
        self.assertEqual(form['strings_raw'][3], '最牛魔法兽')

    def test_duplicate_chicken_duck_differences_preserved(self):
        for original, duplicate in [('140000', '140021'), ('140007', '140022')]:
            self.assertEqual(self.data['species'][original]['name'], self.data['species'][duplicate]['name'])
            self.assertEqual(self.data['species'][original]['forms'][-1]['model_resource'], '')
            self.assertEqual(self.data['species'][duplicate]['forms'][-1]['model_resource'], '高级魔法兽-火凤')
            self.assertNotEqual(self.data['species'][original]['payload_sha256'], self.data['species'][duplicate]['payload_sha256'])

    def test_lifespan_exceptions_and_unknown_units(self):
        exceptions = {id for id, row in self.data['species'].items() if row['lifespan_raw'] == 9000}
        self.assertEqual(exceptions, {'140040', '140046', '140049'})
        for id, row in self.data['species'].items():
            self.assertEqual(row['lifespan_raw'], 9000 if id in exceptions else 18000)
            self.assertIsNone(row['lifespan_unit'])

    def test_template_zero_species_and_type_counts(self):
        counts = Counter(row['template_id'] for row in self.data['species'].values())
        self.assertEqual(counts, {300001: 6, 300005: 5, 300006: 5, 300007: 7, 0: 4})
        self.assertEqual({id for id, row in self.data['species'].items() if not row['template_id']},
                         {'140048', '140040', '140046', '140049'})

    def test_template_unknown_columns_remain_uninterpreted(self):
        for row in self.data['templates'].values():
            self.assertEqual(row['columns'], ['index_raw', 'unknown_1', 'unknown_2'])
            self.assertEqual(row['triples_raw'], [[i, 200, v] for i, v in enumerate([25, 45, 65, 85, 95, 105, 115], 1)])

    def test_all_53_skill_payloads_lossless(self):
        for id, row in self.data['skills'].items():
            with self.subTest(id=id):
                raw = self.tables['all_skill'][int(id)]['payload']
                self.assertEqual(pet.reconstruct_segments(row['payload_segments']), raw)
                self.assertEqual(row['consumed_bytes'], len(raw))
                self.assertEqual(list(struct.unpack_from('<17I', raw, row['header_offset'])), row['header_17_u32_raw'])

    def test_exact_innate_random_separation(self):
        innates = {int(id) for id, row in self.data['skills'].items() if row['kind'] == 'innate'}
        self.assertEqual(innates, set(range(90145, 90158)))
        self.assertEqual(Counter(row['kind'] for row in self.data['skills'].values()), {'innate': 13, 'random': 40})
        for hero in ['90020', '90022', '90126', '90080', '90144', '90158']:
            self.assertNotIn(hero, self.data['skills'])

    def test_innate_references_and_zero_are_preserved(self):
        self.assertEqual(sum(row['innate_skill_id'] == 0 for row in self.data['species'].values()), 12)
        self.assertEqual(self.data['species']['140001']['innate_skill_id'], 90150)
        self.assertEqual(self.data['species']['140052']['innate_skill_id'], 90147)
        for row in self.data['species'].values():
            if row['innate_skill_id']:
                self.assertEqual(self.data['skills'][str(row['innate_skill_id'])]['kind'], 'innate')

    def test_singleton_lua_constants_separate_from_rank_limits(self):
        self.assertEqual(Counter(row['max_rank'] for row in self.data['skills'].values()), {1: 12, 15: 1, 30: 40})
        for row in self.data['skills'].values():
            self.assertEqual(row['raw_rank_limit'], row['max_rank'])
            for key, values in row['constants'].items():
                self.assertEqual(len(values), 1)
                self.assertEqual(row['lua_constant_lengths'][key], 1)
        self.assertEqual(self.data['skills']['90157']['max_rank'], 15)
        self.assertEqual(self.data['skills']['90145']['constants']['app_hp_max_rate'], [0.02])
        self.assertIn('add_fire_dam_rate', self.data['skills']['90035']['constants'])

    def test_candidate_mana_anchors_and_all_blocks(self):
        self.assertEqual({id: self.data['skills'][id]['mana_cost_candidate'] for id in ['90014', '90036', '90157']},
                         {'90014': 0, '90036': 40, '90157': 200})
        candidates = [row for row in self.data['skills'].values() if row['mana_cost_candidate'] is not None]
        self.assertEqual(len(candidates), 23)
        for row in candidates:
            anchor = row['mana_cost_candidate_evidence']
            payload = self.tables['all_skill'][row['id']]['payload']
            self.assertEqual(list(struct.unpack_from('<7I', payload, anchor['block_offset'])),
                             [3, 0, 10, row['mana_cost_candidate'], 0, 0, 1])
            self.assertEqual(anchor['block_offset'] + 28, anchor['description_offset'])
            self.assertIn('not fully decoded', anchor['inference'])
        self.assertIsNone(self.data['skills']['90023']['mana_cost_candidate'])

    def test_semantic_consumable_indexes_and_talent_amounts(self):
        items = self.data['consumables']
        for stat, (ids, amount) in pet.TALENT_FOODS.items():
            for id in ids:
                self.assertEqual(items[str(id)]['talent_increment'], {'stat': stat, 'amount': amount})
        self.assertIn('capacity_plus_one', items['30595']['groups'])
        self.assertIn('transformation_failure_protection', items['30731']['groups'])
        self.assertIn('primary_replacement_slot_2', items['30023']['groups'])
        self.assertIn('donor_skill_slot_3', items['30753']['groups'])
        self.assertTrue(all(row['source_strings'] and row['name'] == row['source_strings'][0] for row in items.values()))

    def test_source_semantics_do_not_invent_tactic_ids_or_success_delta(self):
        self.assertEqual(len(self.data['tactics']), 5)
        source = self.data['semantic_index']['source_records']['all_task']['80593']['source_strings'][13]
        for tactic in self.data['tactics'].values():
            self.assertIsNone(tactic['source_numeric_id'])
            self.assertIn(tactic['source_text'], source)
        transformation = self.data['semantic_index']['transformation']
        self.assertTrue(transformation['both_pets_resting'])
        self.assertTrue(transformation['secondary_consumed_on_success_or_failure'])
        self.assertEqual(transformation['failure_primary_rank_change'], -1)
        self.assertNotIn('success_primary_rank_change', transformation)
        transfer = self.data['semantic_index']['skill_transfer']
        self.assertTrue(transfer['same_type_required'] and transfer['secondary_consumed'])
        self.assertEqual(transfer['random_skill_count_at_hatch']['max'], 3)

    def test_timestamp_exclusion_and_hash_provenance(self):
        for group in ['species', 'templates', 'personalities', 'skills']:
            self.assertNotIn('10000001', self.data[group])
        for name, record in self.data['provenance'].items():
            path = DEFAULT_SOURCE / name if name.endswith('.godat') else ROOT / name
            self.assertEqual(record['sha256'], hashlib.sha256(path.read_bytes()).hexdigest())
        for table in ['all_pet', 'all_petData', 'all_character', 'all_skill']:
            self.assertEqual(self.data['excluded_timestamp_records'][table]['id'], 10000001)

    def test_trailing_and_truncated_structural_data_rejected(self):
        for table, parser in [('all_pet', pet.parse_species), ('all_petData', pet.parse_template), ('all_character', pet.parse_personality)]:
            row = next(row for id, row in self.tables[table].items() if id != 10000001)
            for payload in [row['payload'][:-1], row['payload'] + b'\0\0\0\0']:
                malformed = {**row, 'payload': payload}
                with self.assertRaises((ValueError, UnicodeError)):
                    parser(malformed)

    def test_validation_rejects_count_and_form_mutation(self):
        bad = copy.deepcopy(self.data)
        bad['species']['140001']['forms'][0]['index_raw'] = 0
        with self.assertRaises(ValueError):
            pet.validate(bad)
        bad = copy.deepcopy(self.data)
        bad['counts']['species'] = 28
        with self.assertRaises(ValueError):
            pet.validate(bad)

    def test_deterministic_committed_json(self):
        encoded = pet.serialize(self.data)
        self.assertEqual(encoded, pet.serialize(pet.extract()))
        self.assertEqual(pet.OUTPUT.read_bytes(), encoded.encode('utf-8'))
        self.assertEqual(json.loads(encoded)['species']['140001']['name'], '野猪')

    def test_default_and_check_are_read_only(self):
        before = pet.OUTPUT.stat().st_mtime_ns
        digest = hashlib.sha256(pet.OUTPUT.read_bytes()).hexdigest()
        for args in [[], ['--check']]:
            result = subprocess.run([sys.executable, '-B', str(ROOT / 'tools/extract_pet_rules.py'), *args],
                                    cwd=ROOT, capture_output=True, text=True, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('no files written', result.stdout)
        self.assertEqual(pet.OUTPUT.stat().st_mtime_ns, before)
        self.assertEqual(hashlib.sha256(pet.OUTPUT.read_bytes()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
