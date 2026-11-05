# Original equipment source schema

`tools/extract_equipment_rules.py` reads the original Godat archives without
modifying them. It uses the existing `payload_records()` and
`strings(with_spans=True)` helpers from `extract_original_tables.py`.
It generates evidence, not a new balance model or a runtime inventory migration.

```powershell
python -B tools/extract_equipment_rules.py          # decode/validate in memory
python -B tools/extract_equipment_rules.py --write  # write the four JSON exports
python -B tools/extract_equipment_rules.py --check  # compare exports with source
python -B -m unittest discover -s tests -p test_equipment_extraction.py -v
```

The default archive directory is
`C:\Users\pavlo\anrufen_extracted\private\A000BA0E`. `--source` may select
another read-only archive directory. `--write` always writes only the four
named JSON files under this project's `data/original` directory. No Godot
editor or export is needed.

## Export envelope and provenance

Every output contains `schema_version`, `source_manifest`, `attribute_constants`,
`records` and `summary`. Records are sorted by numeric source ID. JSON keys use
stable ordering; there are no timestamps or machine-specific source paths.
The manifests contain archive SHA-256 and indexed record counts, plus the
SHA-256 of `data/original/scripts/attribute_const.lua`.

Each record preserves its archive offset, original four-word archive header,
index name, payload size and SHA-256. Gear/affix prefixes preserve decoded
length-delimited strings with byte spans and the intervening unknown bytes as
hex segments. This representation reconstructs the original payload exactly,
without naming unknown model/flag fields. Parsed suffixes include
`decoded_end`, which must equal the payload size.

The exported files are:

| Export | Real records | Source |
|---|---:|---|
| equipment_rules.json | 777 | all_equip.godat (787 indexed records) |
| property_rules.json | 1,626 | all_property.godat (1,627 indexed records) |
| suit_rules.json | 41 | all_suit.godat (42 indexed records) |
| affix_rules.json | 44 | selected all_prop.godat records (1,036 indexed records) |

Metadata/non-equipment record IDs are listed where excluded. Raw source tables
and existing runtime catalogs are not changed.

## Equipment suffix

After the final length-prefixed UTF-16 display-type string:

```text
five uint32 scalars
uint32 requirement_count
requirement_count * seven uint32 values
six times: uint32 count followed by count uint32 property IDs
```

All 777 real records parse to the end with one requirement tuple. The five
scalars are exported as `buy_price`, `sell_price`, `raw_unknown_scalar2`,
`quality`, `suit_id`, and additionally as `raw_first_five`.

**Scalar 2 remains unidentified.** It is not exported as durability, weight or
required level. Its observed range is 1–163. The tuple's first number is exposed
as `level_candidate` with `level_candidate_is_inferred: true`; this is a
level-like threshold rather than a proved native field name. The complete tuple
is preserved in `requirements[].raw`:

```text
[threshold, raw_condition_1, class_id, four raw stat constraints]
```

For item **10010 长剑**, the first five scalars are `[200,20,1,1,0]`; its tuple
is `[10,0,130001,0,0,0,0]`. No numeric conversion is applied.

The twelve bytes preceding the display string are preserved as
`display_flags_raw`. The middle integer is the numeric slot authority:
weapon 0, head 1, body 3, belt 4, glove 5, shoes 6, necklace 7, ring 8.
For weapons, the final integer identifies longsword 1, greataxe 2, staff 3.
The first integer remains unnamed. Items **10165** and **10313** have ring icon
paths but numeric necklace slots; both facts and the mismatch are retained.

Only property array zero is nonempty. Its 1,446 entries include 12 zero
sentinels across 10 gear records; all 1,434 nonzero entries resolve to the
property export. The other five arrays are empty throughout. All six arrays
and the zero sentinels are retained, not silently discarded.

## Property curves

Each real property payload is exactly 52 bytes, decoded with `<13i`:
leading raw tag 1, attribute ID, eleven signed int32 values. `values` and
`upgrade_indices` preserve the upgrade 0–10 curve exactly.

Property **22264**, physical attack 20, is
`[260,286,338,390,423,455,520,585,650,715,780]`.
Do not replace curves with a percentage formula: **176 are nonmonotonic**.
For example **21410** contains
`[10000,10000,10900,10000,0,0,0,0,0,0,0]`. Attributes **115** and **117**
(property IDs 21413–21415) are absent from the extracted attribute constants;
they remain numeric with empty `attribute_names` and `attribute_known: false`.

## Suit records

```text
UTF16 name
uint32 member_count
members: uint32 item ID + UTF16 item name (including empty names)
uint32 bonus_count
bonuses: <II d 8I>, 48 bytes each
```

The 202 bonuses contain a tag, attribute ID, **float64** value, and eight raw
post-value uint32 fields. In this table the raw post-value fields are
`[1,0,0,0,suit_id,required_piece_count,0,0]`. These are retained both structurally
and as raw words/hex; every bonus self-reference matches its enclosing suit.

Suit **40035 漆黑套装** explicitly lists items 10323, 10324, 10603 and 10760.
Its bonuses are attack 20 +300 at two pieces, emit damage 51 +300 at four,
and hit enhancement 108 +200 at three.

Membership sources are deliberately separate: `members` is the explicit source
list, while `gear_footer_members` is the gear-table cross-reference. Ten suits
contain placeholder member `(0, "")`; 34 explicit members have gear suit ID
zero. For example suit 40026 explicitly contains item 10117 although the
item's footer suit ID is zero. There are no dangling explicit member IDs.
The extractor does not invent a union/membership activation policy.

## Prefix/suffix materials

Source labels `前缀材料` and `后缀材料` select 22 prefix and 22 suffix records.
IDs **30007** and **30008** are explicitly `is_test: true`, leaving 42 production
records. The source string immediately preceding the label is `affix_name`.

After the final label, all 44 records fully parse as seven raw uint32 fields,
counted seven-int requirements, a counted array of 48-byte effects, then two
zero terminators. Production requirements contain one tuple whose threshold is
30, 60, 80 or 100; the test records contain no requirements. Effect values are
float64, with all remaining words preserved in `raw_post_value`, `raw_u32` and
`raw_hex`. No effect scaling is inferred.

Examples: prefix **30251 冰晶矿** adds fire resistance 61 +25; prefix **30319**
adds physical defence 21 +28. Suffix **30333 铁化石** adds physical attack 20
+92; **30345 龙铁化石** adds attack +185 with threshold candidate 80.

## Upgrade/repair limits of this evidence

The original merchant 50179 text confirms +10 maximum, failure reducing one
upgrade level and maximum durability, and one immutable prefix and suffix per
piece. Upgrade ingots are 30064/30482 (ordinary), 30065/30810 (excellent),
30066 (highest quality). Runes 30067/30697 protect maximum durability;
30068/30483 increase success probability. The exact probability, durability
loss, currency cost and repair formula are not decoded here. No dedicated
repair consumable was verified. Do not label provisional runtime formulas as
original source rules.

## Verification

The focused suite has 16 tests. It reconstructs **every** real gear, property,
suit and affix payload byte-for-byte, checks complete suffix consumption and
SHA provenance, validates cross-references with explicit zero-sentinel handling,
and checks numerical examples, nonmonotonic curves, misleading icon slots,
suit placeholders/disagreements, test materials and deterministic checked exports.
