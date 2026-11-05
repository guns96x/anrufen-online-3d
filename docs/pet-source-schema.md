# Reproducible pet source dataset

`tools/extract_pet_rules.py` generates `data/original/pet_rules.json` from the
read-only `anrufen_extracted/private/A000BA0E` archives. It does not execute Lua,
balance gameplay, or change the running game. The dataset has 27 species,
4 numerical templates, 12 personalities and 53 pet skills. Each archive also
has a timestamp record10000001, retained separately and excluded from counts.

```powershell
python -B tools/extract_pet_rules.py
python -B tools/extract_pet_rules.py --write
python -B tools/extract_pet_rules.py --check
python -B -m unittest discover -s tests -p test_pet_extraction.py -v
```

Default mode parses and validates in memory. `--check` additionally compares the
generated UTF8 bytes against the committed JSON. Only `--write` writes the fixed
JSON destination. `-B` prevents Python cache files. Output uses sorted keys,
original Unicode strings, LF endings, no generation timestamp and no NaN values.
SHA256 provenance covers eight archives, the original GBK numeric Lua source,
the skill-string JSON used by the existing skill extractor, and attribute Lua.

## Stable integration fields

The six primary dictionaries are `species`, `templates`, `personalities`,
`skills`, `consumables`, `tactics`. Numeric IDs are JSON string keys. Tactics
have descriptive string keys because their original numeric values are unknown.

| Dictionary | Useful fields |
| --- | --- |
| species | `id`, `name`, `template_id`, `innate_skill_id`, `base`, `forms`, `lifespan_raw`, `lifespan_unit:null` |
| templates | `id`, `name`, `row_count_raw`, `columns`, `triples_raw` |
| personalities | `id`, `name`, `label`, `speech_metadata_raw`, `dialogues` |
| skills | `id`, `kind` (`innate`/`random`), `constants`, `max_rank`, `raw_rank_limit`, `lua_constant_lengths`, `mana_cost_candidate` |
| consumables | `id`, `name`, `groups`, `source_strings`; talent food additionally has `talent_increment:{stat,amount}` |
| tactics | `source_numeric_id:null`, `source_text`, exact tutorial evidence reference |

Every structured record retains payload size, consumed size, archive offset and
payload SHA256. All species/template/personality fields round-trip to the exact
original bytes. Skill records preserve an audited header plus lossless contiguous
string/raw-byte segments; their complete effect grammar is **not** decoded.
`source_strings` retains source text without translation. Species appearance
strings also retain empty fields, including empty final-form resources.

## Binary structure established by full consumption

All integers below are little-endian uint32. `str` is a character count followed
by that many UTF16LE code units, including zero-length strings.

```text
species:
  u32(1001), str(name), appearance,
  u32(7), 7 * {u32(index1..7), str(form_name), appearance},
  7*u32 tail

appearance:
  u32(1), 4*str, 2*u32 metadata, u32(dialogue_count), dialogue_count*str

numerical template:
  str(name), u32(7), 7 * {u32, u32, u32}

personality:
  str(name), str(label), 2*u32 metadata,
  u32(dialogue_count), dialogue_count*str
```

The appearance string quartet contains model, summon effect, icon and additional
text. The fourth string is often empty but140017 form1 contains `最牛魔法兽`.
Each species has a base plus seven additional presentations. The original
chicken/duck records140000/140007 have empty final model resources; duplicates
140021/140022 provide `高级魔法兽-火凤`. No reliable egg-to-duplicate foreign
key has been recovered, so the extractor does not invent one.

Tail values are `[0, lifespan_raw, 0, 0, template_id, 1, innate_skill_id]`.
The lifespan interpretation is structural inference, with **unknown units and
drain behavior**. Values are18000 for24 records and9000 for140040/140046/140049.
Templates are300001 physical (6 species),300005 magic (5),300006 defense (5),
300007 support (7). Special species140048/140040/140046/140049 reference0.
Template triples are `(1..7,200,25/45/65/85/95/105/115)` in every template.
The last two columns intentionally remain `unknown_1` and `unknown_2`.
The early60/120 values occur beside dialogue counts and do not establish an
incubation duration. Both chicken records have120; other species have60.

## Skills: facts and candidates

The existing `extract_skill_rules.extract()` supplies97 Lua bindings and171
numeric arrays:44 player bindings and53 pet bindings. Pets divide into13 innate
skills90145..90157 and40 random skills (4 physical,3 magic,9 passive,24 combat
support). Unbound monster/internal/racial records are not reclassified as pets.

`constants` preserves original Lua keys and singleton arrays. `max_rank` and
`raw_rank_limit` both preserve the binary header value:1 for12 innates,15 for
90157,30 for all40 random skills. Array length is not substituted for rank
limit, and no rank-scaling formula is invented. Source inconsistencies remain:
90035's ice description has a Lua key `add_fire_dam_rate`; medical skill90057
has the same25% constant as90049. Personality dialogue containing a claimed
20% efficiency bonus is not an executable stat rule.

For23 active pet skills, a seven-u32 block immediately before the second
description copy is `[3,0,10,cost,0,0,1]`. `mana_cost_candidate` stores that cost
and `mana_cost_candidate_evidence` stores the exact offset, raw block and inference
warning. Anchors include90014=0,90036=40,90157=200. The other30 skills have null,
not an assumed zero. Source range values remain raw; no pixel-to-meter conversion
is claimed. Cast/cooldown header values remain milliseconds.

## Mechanics supported by original prose

`semantic_index.source_records` retains complete original strings with table,
record ID and string-index references. Consumable source rows reside in the
top-level `consumables` dictionary.

- NPC50180, string10: both pets must rest for transformation. Success raises
  primary transformation rank; failure lowers it by1. The secondary disappears
  on either outcome. Exact success increment/probability is not encoded as fact.
- NPC50180, string12: skill transfer requires the same type, randomly selects
  the transferred skill, and consumes the secondary. Comparing numerical
  template IDs is a plausible implementation field, explicitly a candidate.
- Quests80601/80606, string6:1..3 random skills are fixed at hatch.
- Quests80593/80594, string13: owner-target attack, retaliate against the owner's
  attacker, support-only, free attack of visible enemies, standby/follow.
- UI10043: two-player breeding, both confirmations, gender/generation displays
  and an auxiliary-item slot. Eligibility/inheritance formulas are absent.

Consumable indexes preserve exact IDs and prose. Talent increments are explicit:
physical/magic +10, HP/MP +60, defense/resistance +5, accuracy +6, evasion +3.
Contract stones30595/30727 add one ownership slot, without proving baseline
capacity. Revival30025/30703, experience30006 and incubator-quality descriptions
do not state their numerical restoration/experience/talent formulas.

Transformation boosters30164/30694/30730 and protection30731/30696 have no
recovered probability values.30253 says `幻化等级三以下的宠物100%幻化成功`;
the threshold wording is retained without choosing an inclusive/exclusive
boundary in code. Replacement runes30749/30023/30750 choose primary slots1/2/3;
inheritance30751/30752/30753 choose donor slots1/2/3. Missing referenced slots are
invalid according to their descriptions.

Lifespan fruit30015/30988 returns a pet to juvenile age, including dead pets;
30989 reverses one age stage. Quest80612/80613's three-day expiry refers to the
gifted fruit, not to natural pet lifespan.

Unresolved: lifespan units/drain, incubation timing, baseline capacity, talents
and caps, gender/personality probabilities, taming progression, breeding rules,
transformation level requirements/probabilities and complete skill execution.
These are research data, not a claim of complete original gameplay parity.
