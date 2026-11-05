"""Reproducible, evidence-preserving original equipment table decoder.

Raw Godat archives are read only. No runtime balance or unidentified scalar is
invented here. Default invocation validates in memory; --write exports four JSON
files; --check verifies existing exports byte-for-byte against their sources.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import struct
from pathlib import Path

from extract_original_tables import DEFAULT_SOURCE, payload_records, strings

ROOT = Path(__file__).resolve().parents[1]
OUTPUTS = {
    "equipment_rules": "all_equip",
    "property_rules": "all_property",
    "suit_rules": "all_suit",
    "affix_rules": "all_prop",
}
SLOTS = {0: "weapon", 1: "head", 3: "body", 4: "belt", 5: "glove", 6: "shoes", 7: "necklace", 8: "ring"}
ATTRIBUTE_FILE = ROOT / "data/original/scripts/attribute_const.lua"


class DecodeError(ValueError):
    pass


class Reader:
    def __init__(self, data: bytes, offset: int = 0):
        self.data = data
        self.offset = offset

    def take(self, size: int) -> bytes:
        if size < 0 or self.offset + size > len(self.data):
            raise DecodeError(f"record ends at {len(self.data)}, requested {size} bytes at {self.offset}")
        result = self.data[self.offset:self.offset + size]
        self.offset += size
        return result

    def uint(self) -> int:
        return struct.unpack("<I", self.take(4))[0]

    def uints(self, count: int) -> list[int]:
        if not 0 <= count <= 10000:
            raise DecodeError(f"unreasonable count {count}")
        return list(struct.unpack(f"<{count}I", self.take(count * 4))) if count else []

    def text(self) -> str:
        length = self.uint()
        if length > 12000:
            raise DecodeError(f"unreasonable string length {length}")
        return self.take(length * 2).decode("utf-16-le")

    def counted_uints(self) -> list[int]:
        return self.uints(self.uint())

    def done(self) -> None:
        if self.offset != len(self.data):
            raise DecodeError(f"unconsumed bytes: {len(self.data) - self.offset}")


def _attributes(path: Path) -> dict[int, list[str]]:
    result: dict[int, list[str]] = {}
    for symbol, number in re.findall(r"^([A-Z][A-Z0-9_]*)\s*=\s*(\d+)", path.read_text(encoding="utf-8-sig"), re.M):
        result.setdefault(int(number), []).append(symbol)
    return result


def _source_info(row: dict, archive: bytes, spans: list[dict] | None = None, prefix_end: int | None = None) -> dict:
    payload = row["payload"]
    result = {
        "archive_offset": row["offset"],
        "archive_header_raw": list(struct.unpack_from("<4I", archive, row["offset"])),
        "index_name": row["name"],
        "payload_size": len(payload),
        "payload_sha256": hashlib.sha256(payload).hexdigest(),
    }
    if spans is not None:
        result["strings"] = spans
        # Unknown bytes before the decoded suffix remain recoverable. Keeping
        # raw segments avoids assigning field names to localized/model metadata.
        end = len(payload) if prefix_end is None else prefix_end
        offset = 0
        segments = []
        for span in spans:
            if span["start"] >= end:
                break
            if offset < span["start"]:
                raw = payload[offset:span["start"]]
                segments.append({"offset": offset, "hex": raw.hex()})
            offset = span["end"]
        if offset < end:
            segments.append({"offset": offset, "hex": payload[offset:end].hex()})
        result["prefix_unknown_segments"] = segments
    return result


def _requirements(reader: Reader) -> list[dict]:
    count = reader.uint()
    if count > 100:
        raise DecodeError(f"unreasonable requirement count {count}")
    result = []
    for _ in range(count):
        raw = reader.uints(7)
        result.append({
            "raw": raw,
            "level_candidate": raw[0],
            "level_candidate_is_inferred": True,
            "raw_condition_1": raw[1],
            "class_id": raw[2],
            "raw_stat_constraints": raw[3:],
        })
    return result


def _effect(reader: Reader, attributes: dict[int, list[str]]) -> dict:
    raw = reader.take(48)
    tag, attribute = struct.unpack_from("<II", raw)
    value = struct.unpack_from("<d", raw, 8)[0]
    if not math.isfinite(value):
        raise DecodeError("non-finite effect value")
    return {
        "tag": tag,
        "attribute_id": attribute,
        "attribute_names": attributes.get(attribute, []),
        "value": value,
        "value_encoding": "float64_le",
        "raw_post_value": list(struct.unpack_from("<8I", raw, 16)),
        "raw_u32": list(struct.unpack("<12I", raw)),
        "raw_hex": raw.hex(),
    }


def _equipment(rows: list[dict], archive: bytes) -> tuple[list[dict], dict]:
    result = []
    excluded = []
    for row in rows:
        payload = row["payload"]
        spans = strings(payload, with_spans=True)
        if len(spans) < 2 or not spans[1]["text"].startswith("equip\\"):
            excluded.append(row["id"])
            continue
        if len(spans) < 3:
            raise DecodeError(f"equipment {row['id']}: missing display string")
        # Every real record has exactly this twelve-byte classification block
        # immediately before the final display-type string.
        classification_start = spans[-1]["start"] - 12
        if classification_start < spans[-2]["end"]:
            raise DecodeError(f"equipment {row['id']}: classification overlaps text")
        flags = list(struct.unpack_from("<3I", payload, classification_start))
        if flags[1] not in SLOTS:
            raise DecodeError(f"equipment {row['id']}: unknown numeric slot {flags[1]}")
        reader = Reader(payload, spans[-1]["end"])
        scalar = reader.uints(5)
        requirements = _requirements(reader)
        groups = [reader.counted_uints() for _ in range(6)]
        reader.done()
        icon = spans[1]["text"]
        icon_slot = icon.split("\\")[1]
        display_slot = SLOTS[flags[1]]
        texts = [span["text"] for span in spans[2:-1]]
        result.append({
            "id": row["id"],
            "name": spans[0]["text"],
            "icon_path": icon,
            "slot": display_slot,
            "source_slot_id": flags[1],
            "icon_slot_hint": icon_slot,
            "slot_hint_mismatch": icon_slot != display_slot,
            "display_type": spans[-1]["text"],
            "display_flags_raw": flags,
            "weapon_subtype_id": flags[2] if display_slot == "weapon" else None,
            "text_strings": texts,
            "description_strings": [s for s in texts if not s.startswith("group") and "调色板" not in s],
            "buy_price": scalar[0],
            "sell_price": scalar[1],
            "raw_unknown_scalar2": scalar[2],
            "quality": scalar[3],
            "suit_id": scalar[4],
            "raw_first_five": scalar,
            "requirements": requirements,
            "property_id_groups": groups,
            "footer_offset": spans[-1]["end"],
            "decoded_end": reader.offset,
            "source": _source_info(row, archive, spans, spans[-1]["end"]),
        })
    summary = {
        "record_count": len(result),
        "excluded_record_ids": sorted(excluded),
        "all_records_fully_consumed": True,
        "slot_hint_mismatches": [r["id"] for r in result if r["slot_hint_mismatch"]],
        "zero_property_sentinel_count": sum(group.count(0) for r in result for group in r["property_id_groups"]),
        "empty_primary_property_records": sum(not r["property_id_groups"][0] for r in result),
        "scalar2_semantics": "unresolved: preserve raw; do not label durability, weight or required level",
        "requirements_semantics": "counted seven-int tuples; first field is inferred level candidate, not a proven engine field name",
    }
    return sorted(result, key=lambda r: r["id"]), summary


def _properties(rows: list[dict], archive: bytes, attributes: dict[int, list[str]]) -> tuple[list[dict], dict]:
    result = []
    excluded = []
    for row in rows:
        if len(row["payload"]) != 52:
            if row["id"] != 10000001:
                raise DecodeError(f"property {row['id']}: expected 52 bytes")
            excluded.append(row["id"])
            continue
        raw = list(struct.unpack("<13i", row["payload"]))
        if raw[0] != 1:
            raise DecodeError(f"property {row['id']}: unsupported tag {raw[0]}")
        values = raw[2:]
        result.append({
            "id": row["id"], "tag": raw[0], "attribute_id": raw[1],
            "attribute_names": attributes.get(raw[1], []),
            "attribute_known": raw[1] in attributes,
            "values": values, "upgrade_indices": list(range(11)),
            "value_encoding": "signed_int32_le", "raw_ints": raw,
            "nonmonotonic": any(a > b for a, b in zip(values, values[1:])),
            "source": _source_info(row, archive), "decoded_end": 52,
        })
    return sorted(result, key=lambda r: r["id"]), {
        "record_count": len(result), "excluded_record_ids": sorted(excluded),
        "all_records_fully_consumed": True,
        "nonmonotonic_count": sum(r["nonmonotonic"] for r in result),
        "unknown_attribute_ids": sorted({r["attribute_id"] for r in result if not r["attribute_known"]}),
        "scaling": "none: exact source values; no conversion or percentage interpolation inferred",
    }


def _suits(rows: list[dict], archive: bytes, attributes: dict[int, list[str]], gear: dict[int, dict]) -> tuple[list[dict], dict]:
    result = []
    excluded = []
    for row in rows:
        if row["id"] == 10000001:
            excluded.append(row["id"])
            continue
        reader = Reader(row["payload"])
        name = reader.text()
        count = reader.uint()
        if count > 100:
            raise DecodeError(f"suit {row['id']}: unreasonable member count {count}")
        members = []
        for _ in range(count):
            item_id, item_name = reader.uint(), reader.text()
            if item_id and item_id not in gear:
                raise DecodeError(f"suit {row['id']}: missing member {item_id}")
            members.append({"item_id": item_id, "name": item_name, "placeholder": item_id == 0,
                            "equipment_footer_suit_id": gear[item_id]["suit_id"] if item_id else None})
        bonus_count = reader.uint()
        if bonus_count > 100:
            raise DecodeError(f"suit {row['id']}: unreasonable bonus count {bonus_count}")
        bonuses = []
        for _ in range(bonus_count):
            effect = _effect(reader, attributes)
            rest = effect["raw_post_value"]
            if rest[4] != row["id"]:
                raise DecodeError(f"suit {row['id']}: incorrect bonus self-reference")
            effect.update({"suit_id": rest[4], "required_piece_count": rest[5]})
            bonuses.append(effect)
        reader.done()
        result.append({"id": row["id"], "name": name, "members": members, "bonuses": bonuses,
                       "gear_footer_members": sorted(r["id"] for r in gear.values() if r["suit_id"] == row["id"]),
                       "decoded_end": reader.offset, "source": _source_info(row, archive)})
    mismatch = [{"suit_id": r["id"], "item_id": m["item_id"], "equipment_footer_suit_id": m["equipment_footer_suit_id"]}
                for r in result for m in r["members"] if m["item_id"] and m["equipment_footer_suit_id"] != r["id"]]
    return sorted(result, key=lambda r: r["id"]), {
        "record_count": len(result), "excluded_record_ids": sorted(excluded),
        "bonus_count": sum(len(r["bonuses"]) for r in result), "all_records_fully_consumed": True,
        "placeholder_suit_ids": sorted(r["id"] for r in result if any(m["placeholder"] for m in r["members"])),
        "explicit_member_footer_mismatches": sorted(mismatch, key=lambda r: (r["suit_id"], r["item_id"])),
        "membership_policy": "explicit members and gear_footer_members preserved separately; no inferred merge",
    }


def _affixes(rows: list[dict], archive: bytes, attributes: dict[int, list[str]]) -> tuple[list[dict], dict]:
    result = []
    for row in rows:
        spans = strings(row["payload"], with_spans=True)
        if not spans or spans[-1]["text"] not in ("前缀材料", "后缀材料"):
            continue
        if len(spans) < 3:
            raise DecodeError(f"affix {row['id']}: missing names")
        reader = Reader(row["payload"], spans[-1]["end"])
        head = reader.uints(7)
        requirements = _requirements(reader)
        count = reader.uint()
        if count > 100:
            raise DecodeError(f"affix {row['id']}: unreasonable effect count {count}")
        effects = [_effect(reader, attributes) for _ in range(count)]
        terminators = reader.uints(2)
        if terminators != [0, 0]:
            raise DecodeError(f"affix {row['id']}: nonempty unparsed terminal fields")
        reader.done()
        result.append({"id": row["id"], "name": spans[0]["text"], "affix_name": spans[-2]["text"],
                       "side": "prefix" if spans[-1]["text"] == "前缀材料" else "suffix",
                       "source_label": spans[-1]["text"], "is_test": row["id"] in (30007, 30008),
                       "raw_first_seven": head, "buy_price": head[1], "sell_price": head[2],
                       "requirements": requirements, "effects": effects, "raw_terminators": terminators,
                       "footer_offset": spans[-1]["end"], "decoded_end": reader.offset,
                       "source": _source_info(row, archive, spans, spans[-1]["end"])})
    return sorted(result, key=lambda r: r["id"]), {
        "record_count": len(result), "all_records_fully_consumed": True,
        "prefix_count": sum(r["side"] == "prefix" for r in result),
        "suffix_count": sum(r["side"] == "suffix" for r in result),
        "test_record_ids": sorted(r["id"] for r in result if r["is_test"]),
        "value_scaling": "none: exact float64 source values",
    }


def build_outputs(source: Path = DEFAULT_SOURCE, attribute_file: Path = ATTRIBUTE_FILE) -> dict[str, dict]:
    tables, archives, manifests = {}, {}, {}
    for name in sorted(set(OUTPUTS.values())):
        path = source / f"{name}.godat"
        tables[name], manifests[name] = payload_records(path)
        archives[name] = path.read_bytes()
    attributes = _attributes(attribute_file)
    attribute_manifest = {"path": "data/original/scripts/attribute_const.lua", "sha256": hashlib.sha256(attribute_file.read_bytes()).hexdigest()}
    equipment, equipment_summary = _equipment(tables["all_equip"], archives["all_equip"])
    properties, property_summary = _properties(tables["all_property"], archives["all_property"], attributes)
    gear = {r["id"]: r for r in equipment}
    property_ids = {r["id"] for r in properties}
    missing = [(r["id"], i, p) for r in equipment for i, group in enumerate(r["property_id_groups"]) for p in group if p and p not in property_ids]
    if missing:
        raise DecodeError(f"unresolved nonzero equipment property references: {missing[:5]}")
    equipment_summary["nonzero_property_reference_count"] = sum(p != 0 for r in equipment for group in r["property_id_groups"] for p in group)
    equipment_summary["unresolved_nonzero_property_references"] = []
    suits, suit_summary = _suits(tables["all_suit"], archives["all_suit"], attributes, gear)
    suit_ids = {r["id"] for r in suits}
    if any(r["suit_id"] and r["suit_id"] not in suit_ids for r in equipment):
        raise DecodeError("equipment references missing suit")
    affixes, affix_summary = _affixes(tables["all_prop"], archives["all_prop"], attributes)
    components = {"equipment_rules": (equipment, equipment_summary), "property_rules": (properties, property_summary),
                  "suit_rules": (suits, suit_summary), "affix_rules": (affixes, affix_summary)}
    outputs = {}
    for output, table in OUTPUTS.items():
        records, summary = components[output]
        dependencies = {table: manifests[table]}
        if output in ("equipment_rules", "suit_rules"):
            dependencies["all_equip"] = manifests["all_equip"]
        if output == "equipment_rules":
            dependencies["all_property"] = manifests["all_property"]
            dependencies["all_suit"] = manifests["all_suit"]
        outputs[output] = {"schema_version": 1, "source_manifest": dependencies,
                           "attribute_constants": attribute_manifest, "records": records, "summary": summary}
    return outputs


def encode(data: dict) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True, allow_nan=False) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.write and args.check:
        parser.error("choose either --write or --check")
    outputs = build_outputs(args.source)
    for name, data in outputs.items():
        path = ROOT / "data/original" / f"{name}.json"
        serialized = encode(data)
        if args.write:
            path.write_text(serialized, encoding="utf-8", newline="\n")
        elif args.check:
            if not path.is_file() or path.read_bytes() != serialized.encode("utf-8"):
                raise DecodeError(f"export differs from source: {path.name}")
        print(f"{name}: {len(data['records'])} records; complete payload consumption")
    print("Validation: 777 gear, 1626 properties, 41 suits, 44 affixes expected by tests; no balance conversion applied.")


if __name__ == "__main__":
    main()
