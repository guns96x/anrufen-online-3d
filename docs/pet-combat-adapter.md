# Pet combat planning adapter

`PetSkillRules` is a pure planner over `data/original/pet_rules.json`. It covers
13 source innate skills,40 random skills (including9 self passives and21 auras),
and exposes Ukrainian `label` / `description_uk` alongside original
`source_name` / `source_description`. Legacy `name` / `description` also retain
original text. Definitions and plans return fresh dictionaries; input snapshots
are not modified and no random generator is called.

## API

```gdscript
PetSkillRules.definitions() -> Dictionary # integer skill IDs
PetSkillRules.definition(id: int) -> Dictionary # {} if unknown
PetSkillRules.passive_modifiers(pet: Dictionary) -> Dictionary
PetSkillRules.build(pet: Dictionary, owner: Dictionary, enemy: Dictionary,
                   context: Dictionary = {}) -> Dictionary
```

Pet input requires `species_id`, `level`1..100, `hp`, `max_hp`. Optional `mp`
defaults0, `max_mp`40, `hunger`100, `skills`[], `summoned`true. `skills` contains
at most3 distinct original **random** skill IDs, as integral JSON numbers.
Innates are derived from verified species records; a supplied `innate_skill_id`
cannot replace that relation. `skill_cooldowns` maps ID strings (or integer IDs)
to remaining nonnegative seconds. The caller owns decrementing these timers.

Owner and hostile enemy snapshots require `hp`/`max_hp`; level defaults1.
Optional `is_dead:true` is respected. Combat/base values must be finite and
bounded. Attack power uses `base_attack` / `base_magic_attack` when supplied,
otherwise `attack` / `magic_attack`. Missing physical power has the explicitly
modern fallback `8+3*pet.level`; missing magical power uses physical power.
Source percentage healing/innate additions use each snapshot's `base_max_hp`
or `base_max_mp`, with current maxima as fallback. `account_id` and pet `uid`
allow additional owner/self-target rejection when present.

Context:

| Key | Meaning |
| --- | --- |
| selected_skill_id | Explicit owned random or verified innate;0/absent selects automatically |
| triggered_innate | If no explicit ID, select the species innate; no innate fails |
| distance | Required finite pet-to-enemy distance for hostile actions |
| target_is_monster | Authoritative monster classification, permits hostile planning |
| hostile_allowed | Authoritative PK permission for a player; defaults false |
| target_is_ally | Always rejects hostile action even if another permission was set |
| owner_distance | Pet-to-owner distance; defaults0 for a near-owner snapshot |
| controls_blocked | Stops all actions while true |
| roll | Required for90157, finite0..1; success iff roll<0.5 |
| owner_hurt | Accepted advisory flag; actual HP, not this flag, determines healing need |
| elapsed | Accepted finite metadata; does not advance cooldowns or bypass them |

Also reject `enemy.is_ally:true`. The planner does not know the map, PK modes,
line of sight, teams or account authority. The adapter must supply validated
snapshots, current distances and server-derived hostile permissions. It must
not accept client profile uploads or a client-authored `hostile_allowed` flag.

Automatic choice is deterministic: needed owned healing, available owned aura,
then owned offensive skills, preserving stored order inside each category.
Unavailable, out-of-range, cooling or unaffordable choices are skipped. Innates
are separately scheduled through `triggered_innate` or an explicit ID.
No available action returns failure; no unowned fallback skill is fabricated.

## Result and application

Success includes `ok:true`, `actions`, `mp_cost`, `skill_id`, `cooldown`,
`cast_seconds`, `source_candidate_mp_cost`. Failure always has `ok:false`,
an explanatory `error`, empty actions, zero cost and zero cooldown.
Explicit passive selection succeeds with empty actions, `passive:true` and
its real `modifiers`; `passive_modifiers()` sums owned passive modifiers.
No action cost or health change is spent here.

Actions use `kind` and `recipient`, one of `self`, `owner`, `enemy`:

| Kind | Fields / adapter responsibility |
| --- | --- |
| damage | `damage_type`: CombatFormulas IDs1physical/2fire/3water(ice); `base` is raw pre-defense power, with `base_stat`, `attack_rate`, `flat`, `hp_max_rate`, `mp_max_rate`, `level_rate`, `target_level_rate` evidence. Resolve defense, resistance, hits and criticals once in the authoritative combat adapter. |
| heal_hp | `amount` is already clamped to living recipient's missing HP; `hp_max_rate` preserves source evidence. Recheck and clamp again at commit if snapshots can be stale. |
| effect | Positive `modifiers`, `duration`, `while_summoned`. Apply using plan skill ID and a rank representing constant behavior, not raw rank limit. Refresh the same effect instead of stacking it on every plan. |
| threat | `amount`, `toward:self`, `monster_only:true`; monster threat only, not a forced player target switch. |
| dispel | `positive:true`, `maximum:1`, `chance:0.5`, supplied `roll` and resolved `succeeded`. Remove at most one beneficial enemy effect only if succeeded; never roll again. Failed attempts still spend the successful plan's cost/cooldown. |

The current53 source skills do not demonstrate poison, regeneration, shields,
mana healing or friendly cleansing. No such actions are invented. Ice90035 and
90038 do not gain an undocumented freeze merely from their names.

Most modifier names match `StatusEffects`: `attack_rate`, `magic_attack_rate`,
`max_hp_rate`, `crit_rate_add`, `defense_rate`, `accuracy_add`, `evasion_add`,
`attack_add`, `magic_attack_add`, `defense_add`, `resist_add`.
Three deliberate extensions require adapter/stat/validator support:
`crit_resist_add` (critical-hit mitigation probability), `fire_resist_rate`,
`water_resist_rate` (element-specific resistance multipliers). Do not broaden
an elemental resistance aura into resistance to all elements. Generic attack
auras are mapped to both physical and magical attack; this is a documented
modern interpretation of the unspecific original attack wording.

`StatusEffects.validate()` currently recognizes player skill IDs; integration
must extend its catalog validation before persisting pet effects on an owner.
Likewise preserve source provenance without passing raw pet rank30 as an
executable rank into a validator limited to15.

To apply a plan, recheck authority, liveness, range, cooldown and mana at commit;
deduct `mp_cost` once; resolve/apply actions; set cooldown once. Do not deduct on
failure. Resolve monster kills through the existing owner-credit path exactly
once; the planner does not award XP, quest progress or loot. Cancel pending
hostile plans when ownership/target conditions change. Remove `while_summoned`
effects on dismiss/death and refresh them only while the pet is summoned and
the recipient remains in range.

## Source evidence versus modern tuning

All singleton Lua constants are used as supplied, never multiplied by rank or
pet level except where the original description explicitly specifies a level
formula. `raw_rank_limit` remains evidence (1,15 or30), not scaling logic.
Original active cooldown and cast fields are kept in seconds from raw
milliseconds. Fire/ice90035 follows the original ice description despite the
misleading Lua `add_fire_dam_rate` key. HealingIII90057 remains25%, matching the
source instead of inventing a larger tier. Healing uses integer floor, another
explicit adapter rounding choice.

Candidate raw MP costs remain exposed as `source_candidate_mp_cost` with their
uncertainty. Playable cost is `ceil(raw/20)` for positive candidates and0 for
source zero; missing candidates on passives/auras are assigned modern zero.
Examples: raw40→2,50→3,200→10,500→25, appropriate to current40MP pets.

World-space ranges are modern: melee2.5m, ranged magic10m, owner support12m.
Original range values remain `source_range_raw` and are not claimed to be
meters. Owner effects are omitted beyond12m; self effects still apply. Aura
leases last10s and refresh after5s, explicitly overriding their35s raw header
cooldown as a continuous-summon presentation. `source_cooldown` preserves that
35s value. Only aura lease/refresh uses modern time; other effects retain
source5s/60s durations and active cooldowns.

Passive duplicates are rejected. Different owned skill IDs add their passive
modifiers; simultaneous related tiers follow this modern additive policy.
The adapter must choose its probability caps and avoid applying self passives
twice when it also supplies an explicitly selected passive plan.

Focused verification:

```powershell
godot --headless --path . --script res://tests/pet_skill_rules_test.gd
```

The test preloads the module, checks every53 definition and supported action,
source coefficients, ownership/range/mana/cooldown guards, owner+self effects,
fixed-roll determinism, input immutability and unchanged global RNG sequence.
