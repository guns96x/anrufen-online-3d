# Original Anrufen: what is ported, v0.9.15 (2026-11-06)

Counts come from the decoded archive (`docs/original-archive-manifest.json`,
`data/original/*`) and from the running game. "Catalog" means the data is
recovered and loaded. It does not mean the mechanic is playable.

## Content: how much of the original world is playable

| Original data | In archive | Playable now | Gap |
|---|---|---|---|
| Quests (all_task) | 713 | 10 (Guanlin opening chain) | ~700 quests, mostly tied to other locations |
| Locations (all_scene) | 227 | 1 town + its forest edge | all other towns, fields, dungeons, exits |
| Citizens (all_citizen) | 455 | 34 in Guanlin | the rest live in other locations |
| Monsters (all_monster) | 384 | 4 kinds (boar, spider, jackal, Viper Gang bandits) | 380 kinds, their skills and loot |
| Synthesis recipes (all_combine) | 17 | 2 | 15 |
| Shops (all_shop) | 32 | starter shop and Guanlin merchants | shop lists of other locations |

## Systems

| System (UI id) | State | What is missing |
|---|---|---|
| Character, races, classes, attributes (UI10008) | playable: 2 races, 8 classes, 9 slots | original advancement thresholds |
| Class skills (UI10021, all_skill) | playable: 44 skills, 4 hotbar slots, ranks, prerequisites, combos, auras | original MP costs, full unlock conditions |
| Equipment: buy/sell/equip/lock, bank, bag expansion | playable | — |
| Equipment: +10 upgrade, durability and repair, prefix/suffix, 41 sets (all_suit) | **rules coded (`EquipmentRules`: upgrade_plan, affix_plan, repair_plan, suit_bonuses) but not reachable from any menu or the server** | wire to the smith NPC, the server and stat calculation |
| Pets (UI10018/10036/10043/10066, all_pet 28) | playable: 23 eggs, hatching, summon, combat, breeding, skill transfer runes | talents, gender/personality, taming, transformation, lifespan, exact incubation times |
| Mounts (all_equip, 6) | playable: riding, speed, leases | two-seat co-riding |
| Titles (all_title 138) | catalog plus selection | how each title is earned and its bonus |
| Player trade, mail, consignment, bounty (UI10016/10047/10072/10038) | playable, on the server | original fees and deadlines |
| Friends, party, guild (UI10034/10055/10056) | playable: invites, leader, announcement | guild ranks, contribution, level, guard |
| Loot and pickup filters (UI10035) | playable | original loot tables and rarity |
| World map, NPC search, routes (UI10037) | playable for Guanlin | the other locations |
| Online (server-authoritative world) | playable: movement, combat, PK, duels, inventory, quests | sharding, account recovery (UI10069 needs SMS) |
| Story and balance maths | our model built on the original constants (`docs/balance-model.md`) | the original server formulas are not in the client archive |

## Changes in v0.9.x that the original did not have

- Anime toon look and modern UI.
- Unique gear looks and weapon element effects.
- Day and night cycle.
- Interpolated online movement.
- Phone performance pass.

## Suggested order

1. **Equipment upgrades, repair, affixes and sets.** The rules exist and need
   wiring: smith dialogue, server action, stat bonus.
2. **Titles.** Add earning conditions and bonuses from all_title.
3. **The next location from the story.** Its quests, citizens, monsters and
   recipes, in the format Guanlin already uses. Repeat location by location.
4. **Pet depth.** Talents, lifespan, taming.
