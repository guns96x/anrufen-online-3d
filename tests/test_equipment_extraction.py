"""Meaningful source/reconstruction checks for the read-only equipment decoder."""
import hashlib
import json
import struct
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import extract_equipment_rules as decoder
from extract_original_tables import payload_records


def pack_uints(values):
    return struct.pack(f"<{len(values)}I", *values) if values else b""


def prefix_bytes(record):
    source = record["source"]
    result = bytearray(record["footer_offset"])
    occupied = bytearray(len(result))
    for span in source["strings"]:
        if span["start"] >= len(result):
            continue
        raw = span["text"].encode("utf-16-le")
        encoded = struct.pack("<I", len(raw) // 2) + raw
        result[span["start"]:span["end"]] = encoded
        occupied[span["start"]:span["end"]] = b"\1" * len(encoded)
    for segment in source["prefix_unknown_segments"]:
        raw = bytes.fromhex(segment["hex"])
        start = segment["offset"]
        result[start:start + len(raw)] = raw
        occupied[start:start + len(raw)] = b"\1" * len(raw)
    if not all(occupied):
        raise AssertionError("prefix has unrepresented bytes")
    return bytes(result)


def requirement_bytes(requirements):
    return struct.pack("<I", len(requirements)) + b"".join(pack_uints(r["raw"]) for r in requirements)


class EquipmentExtractionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.outputs = decoder.build_outputs()
        cls.gear = {r["id"]: r for r in cls.outputs["equipment_rules"]["records"]}
        cls.properties = {r["id"]: r for r in cls.outputs["property_rules"]["records"]}
        cls.suits = {r["id"]: r for r in cls.outputs["suit_rules"]["records"]}
        cls.affixes = {r["id"]: r for r in cls.outputs["affix_rules"]["records"]}
        cls.raw = {}
        for table in decoder.OUTPUTS.values():
            if table not in cls.raw:
                rows, _ = payload_records(decoder.DEFAULT_SOURCE / f"{table}.godat")
                cls.raw[table] = {r["id"]: r["payload"] for r in rows}

    def test_all_real_record_counts(self):
        self.assertEqual((len(self.gear), len(self.properties), len(self.suits), len(self.affixes)), (777, 1626, 41, 44))
        self.assertEqual(sum(len(r["bonuses"]) for r in self.suits.values()), 202)

    def test_every_record_is_sorted_and_fully_consumed(self):
        for output in self.outputs.values():
            ids = [r["id"] for r in output["records"]]
            self.assertEqual(ids, sorted(set(ids)))
            for row in output["records"]:
                self.assertEqual(row["decoded_end"], row["source"]["payload_size"])

    def test_archival_manifest_hashes_and_headers(self):
        for name, output in self.outputs.items():
            table = decoder.OUTPUTS[name]
            archive = (decoder.DEFAULT_SOURCE / f"{table}.godat").read_bytes()
            self.assertEqual(output["source_manifest"][table]["sha256"], hashlib.sha256(archive).hexdigest())
            for row in output["records"]:
                raw = self.raw[table][row["id"]]
                self.assertEqual(row["source"]["payload_sha256"], hashlib.sha256(raw).hexdigest())
                self.assertEqual(row["source"]["archive_header_raw"], list(struct.unpack_from("<4I", archive, row["source"]["archive_offset"])))

    def test_equipment_lossless_reconstruction_all_777(self):
        for row in self.gear.values():
            footer = pack_uints(row["raw_first_five"]) + requirement_bytes(row["requirements"])
            footer += b"".join(struct.pack("<I", len(group)) + pack_uints(group) for group in row["property_id_groups"])
            self.assertEqual(prefix_bytes(row) + footer, self.raw["all_equip"][row["id"]], row["id"])
            self.assertEqual(len(row["property_id_groups"]), 6)
            self.assertEqual(len(row["requirements"]), 1)

    def test_property_lossless_signed_reconstruction_all_1626(self):
        for row in self.properties.values():
            self.assertEqual(len(row["values"]), 11)
            self.assertEqual(row["value_encoding"], "signed_int32_le")
            self.assertEqual(struct.pack("<13i", *row["raw_ints"]), self.raw["all_property"][row["id"]])

    def test_property_references_and_zero_sentinels(self):
        refs = [p for row in self.gear.values() for group in row["property_id_groups"] for p in group]
        self.assertEqual(len(refs), 1446)
        self.assertEqual(refs.count(0), 12)
        self.assertTrue(all(p == 0 or p in self.properties for p in refs))
        self.assertTrue(all(not group for row in self.gear.values() for group in row["property_id_groups"][1:]))

    def test_exact_longsword_and_novice_values(self):
        sword = self.gear[10010]
        self.assertEqual(sword["name"], "长剑")
        self.assertEqual(sword["buy_price"], 200)
        self.assertEqual(sword["sell_price"], 20)
        self.assertEqual(sword["raw_first_five"], [200, 20, 1, 1, 0])
        self.assertEqual(sword["requirements"][0]["raw"], [10, 0, 130001, 0, 0, 0, 0])
        self.assertTrue(sword["requirements"][0]["level_candidate_is_inferred"])
        self.assertEqual(self.gear[10003]["property_id_groups"][0], [22264])
        self.assertEqual(self.properties[22264]["values"], [260, 286, 338, 390, 423, 455, 520, 585, 650, 715, 780])
        self.assertNotIn("max_durability", sword)
        self.assertNotIn("required_level", sword)

    def test_numeric_slots_override_two_misleading_icons(self):
        self.assertEqual(self.outputs["equipment_rules"]["summary"]["slot_hint_mismatches"], [10165, 10313])
        for item in (10165, 10313):
            self.assertEqual(self.gear[item]["slot"], "necklace")
            self.assertEqual(self.gear[item]["source_slot_id"], 7)
            self.assertEqual(self.gear[item]["icon_slot_hint"], "ring")

    def test_nonmonotonic_curves_preserved_not_interpolated(self):
        self.assertEqual(sum(r["nonmonotonic"] for r in self.properties.values()), 176)
        self.assertEqual(self.properties[21410]["values"], [10000, 10000, 10900, 10000, 0, 0, 0, 0, 0, 0, 0])
        self.assertEqual(self.properties[21413]["values"], [10, 15, 20, 30, 45, 60, 1, 1, 1, 1, 1])
        self.assertEqual(self.outputs["property_rules"]["summary"]["unknown_attribute_ids"], [115, 117])

    def test_suit_lossless_reconstruction_all_41(self):
        for row in self.suits.values():
            name = row["name"].encode("utf-16-le")
            raw = struct.pack("<I", len(name) // 2) + name + struct.pack("<I", len(row["members"]))
            for member in row["members"]:
                text = member["name"].encode("utf-16-le")
                raw += struct.pack("<II", member["item_id"], len(text) // 2) + text
            raw += struct.pack("<I", len(row["bonuses"]))
            raw += b"".join(bytes.fromhex(effect["raw_hex"]) for effect in row["bonuses"])
            self.assertEqual(raw, self.raw["all_suit"][row["id"]])
            for bonus in row["bonuses"]:
                self.assertEqual(bonus["suit_id"], row["id"])
                self.assertEqual(bonus["value_encoding"], "float64_le")

    def test_suit_placeholders_and_footer_disagreement_preserved(self):
        summary = self.outputs["suit_rules"]["summary"]
        self.assertEqual(len(summary["placeholder_suit_ids"]), 10)
        self.assertEqual(self.suits[40014]["members"], [{"item_id": 0, "name": "", "placeholder": True, "equipment_footer_suit_id": None}])
        self.assertEqual(len(summary["explicit_member_footer_mismatches"]), 34)
        member = next(m for m in self.suits[40026]["members"] if m["item_id"] == 10117)
        self.assertEqual(member["equipment_footer_suit_id"], 0)
        self.assertIn(10117, self.gear)
        self.assertEqual(self.suits[40026]["gear_footer_members"], [])

    def test_exact_set_piece_bonuses(self):
        suit = self.suits[40035]
        self.assertEqual([m["item_id"] for m in suit["members"]], [10323, 10324, 10603, 10760])
        self.assertEqual([(b["attribute_id"], b["value"], b["required_piece_count"]) for b in suit["bonuses"]], [(20, 300.0, 2), (51, 300.0, 4), (108, 200.0, 3)])

    def test_affix_lossless_reconstruction_all_44(self):
        for row in self.affixes.values():
            footer = pack_uints(row["raw_first_seven"]) + requirement_bytes(row["requirements"])
            footer += struct.pack("<I", len(row["effects"]))
            footer += b"".join(bytes.fromhex(effect["raw_hex"]) for effect in row["effects"])
            footer += pack_uints(row["raw_terminators"])
            self.assertEqual(prefix_bytes(row) + footer, self.raw["all_prop"][row["id"]])
        self.assertEqual([id for id, row in self.affixes.items() if row["is_test"]], [30007, 30008])
        self.assertEqual(self.affixes[30007]["requirements"], [])
        self.assertEqual(self.affixes[30008]["requirements"], [])
        self.assertEqual(sum(r["side"] == "prefix" for r in self.affixes.values()), 22)
        self.assertEqual(sum(r["side"] == "suffix" for r in self.affixes.values()), 22)

    def test_exact_affix_effects_and_raw_flags(self):
        prefix = self.affixes[30251]
        self.assertEqual(prefix["affix_name"], "寒霜之")
        self.assertEqual(prefix["requirements"][0]["raw"], [30, 0, 0, 0, 0, 0, 0])
        self.assertEqual((prefix["effects"][0]["attribute_id"], prefix["effects"][0]["value"]), (61, 25.0))
        self.assertEqual(prefix["effects"][0]["raw_post_value"], [0, 0, 0, 0, 1, 0, 0, 0])
        suffix = self.affixes[30333]
        self.assertEqual((suffix["effects"][0]["attribute_id"], suffix["effects"][0]["value"]), (20, 92.0))
        self.assertEqual(self.affixes[30345]["effects"][0]["value"], 185.0)

    def test_checked_exports_are_deterministic(self):
        for name, output in self.outputs.items():
            serialized = decoder.encode(output)
            self.assertEqual((ROOT / "data/original" / f"{name}.json").read_bytes(), serialized.encode("utf-8"))
            self.assertEqual(decoder.encode(json.loads(serialized)), serialized)

    def test_truncated_binary_cannot_silently_parse(self):
        reader = decoder.Reader(b"\0\0\0")
        with self.assertRaises(decoder.DecodeError):
            reader.uint()
        reader = decoder.Reader(struct.pack("<I", 12001))
        with self.assertRaises(decoder.DecodeError):
            reader.text()
        reader = decoder.Reader(b"remaining")
        with self.assertRaises(decoder.DecodeError):
            reader.done()


if __name__ == "__main__":
    unittest.main()
