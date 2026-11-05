# Pure equipment adapter contract

`shared/items/equipment_rules.gd` reads the four checked source exports. It does not own items, spend money, consume materials, save, roll random numbers, or alter actor stats. Runtime ownership and atomic persistence remain the caller's responsibility.

## Source and instance state

`definition(id)` returns an independent deep copy of the complete source row, including names, descriptions, seven-int requirements, source numeric slot, price, quality, curves, provenance, and `raw_unknown_scalar2`. Unknown IDs return `{}`. The unknown scalar has no assigned durability meaning. Numeric source slots override icon paths, including necklace IDs 10165/10313.

Instance state is `{upgrade:0, durability:100, max_durability:100, prefix_id:0, suffix_id:0}`. Missing fields receive those **provisional modern** defaults. Whole JSON numbers are accepted, fractional/nonfinite numbers rejected. Upgrade must be 0..10; maximum durability 1..100; current durability 0..maximum. Affix IDs must be production IDs of the corresponding side. Unrecognized extra state fields are retained and deeply copied, allowing a future instance UID.

`can_equip(stats,id)` checks actor `level` against source `level_candidate` and `class_id` against `SkillRules.ANCESTORS`. Treating the source threshold as actor level is an inference, exposed in source definitions. Nonzero unknown requirement constraints fail closed; all current source rows have zero there. This predicate does not claim bag ownership, alive status, or quest permission.

## Raw and modern bonuses

`raw_properties(id,upgrade)` sums all six source property groups at the exact requested index, omits zero sentinels, and returns source attribute IDs as string keys. Invalid IDs/indices return `{}`. Nonmonotonic curves are preserved.

`bonuses(id,state)` adds exact affix float64 values to the raw curve, then returns numeric runtime bonus keys alongside `raw_bonus`, `unsupported_raw`, `conversion_is_provisional:true`, and `active`. Broken items suppress numeric runtime contributions while retaining their raw values. Invalid state returns `{}`.

The default conversion is explicitly modern tuning, not recovered original units:

| Source IDs | Runtime keys | Divisor |
| --- | --- | --- |
| 20,21,22,23 | attack,defense,magic_attack,magic_defense | 10 |
| 30,31 | max_hp,max_mp | 10 |
| 41,43,44 | crit_rate,accuracy,evasion | 10000 |

All other attributes stay in `unsupported_raw`, including elemental resistances, reflection, absorption, attribute points, regeneration, attack/defense percentages, and unknown source attributes. The current combat system has no faithful representation for many of these effects. Generic `resist` must not silently substitute for six elemental resistances. The parent runtime must explicitly wire each numeric key into its recalculation; returning a key does not activate it in combat. Preserve floats until final actor rounding. Never add dictionary or boolean metadata as numeric bonuses.

`suit_bonuses(equipment,states)` uses the union of explicit nonzero suit members and equipment-footer membership. Each distinct item ID counts once, even when supplied under several slots or found by both membership paths. Each source bonus applies once at its own piece threshold. `states` resolves string item ID, integer item ID, then equipment slot key; missing state means defaults. Broken/invalid states do not count. Output adds `suit_piece_counts` and `applied_suit_effects`. Actual ownership, slot compatibility, duplicate-instance prevention, and equip permissions must be validated before calling it.

## Transaction plans

All three services return `{ok,error,state,copper_cost,consume}`. Rejection returns empty state/consumption and zero cost. Success returns an independent proposed state. `consume` uses string source IDs. `ok:true` on a failed upgrade means a valid paid attempt, not upgrade success; inspect `success`.

`stats` supplies integer `copper` (0..1e9), `inventory` (flat string-ID counts), `bag_capacity` (default32), and actor `level` for affixes. Material counts must exist. Bag entries must resolve through ItemCatalog and respect stack limits. Corrupt overcapacity bags are rejected; a valid full bag is accepted because these operations create no bag entry. No planned resources are reserved.

Upgrade materials follow exact source quality families: ordinary 30064/30482; excellent 30065/30810; highest 30066. Maximum is +10. Failure loses one upgrade, floored at zero. Protection 30067/30697 prevents maximum-durability loss only. Boost 30068/30483 increases chance. Caller supplies a finite roll in [0,1); success is `roll < success_chance`.

Modern provisional balance: cost `10*(old_upgrade+1)`; chance `max(.10,.90-.07*old_upgrade)`, plus .10 for boost, capped .99; failure loses 5 maximum durability, floored at1, and clamps current durability. Every requested material/rune is consumed once on either valid outcome. These quantities and the formula are not original source facts.

Affix installation consumes one production material for provisional cost30. IDs30007/30008 are test materials and rejected. One prefix and one suffix can be installed, and neither can be replaced. Its source requirement threshold gates **actor** level as an explicit inference; there is no invented item-level restriction. Effect modifiers retain exact source doubles. `material_actor_level_gate_is_inferred:true` marks that policy.

Repair costs a provisional 2 copper per missing durability point, restores current to the remaining maximum, and consumes no material. It does not undo maximum-durability degradation; an already repaired item is rejected.

The caller must verify the exact owned instance, quest locks, authority, and revision, then revalidate resources and commit state/copper/material changes in one save transaction. Do not apply a stale/replayed plan, separately save individual deductions, or let the client select a favorable roll in an authoritative multiplayer service. No inventory or persistence integration is included here.
