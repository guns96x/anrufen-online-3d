# Opening story: evidence and implementation

The opening uses these original Anrufen records from `data/quests.json`, also
preserved in `docs/verified-opening-records.json` with the source file SHA-256.
The original datasets have not been edited.

| Quest | Verified narrative and objective | Current giver / destination |
|---|---|---|
| 80004 | Meet the weapons merchant on the mayor's errand | Mayor -> merchant |
| 80591 | Buy a longsword and bring it back to the mayor | Merchant -> mayor |
| 80552 | Go to the militia captain | Mayor -> captain |
| 80005 | Investigate the forest, obtain three witness reports, reach level 8 | Captain |
| 80006 | Viper Gang bandits stole the Gourmand's snacks; kill 10 for his report | Gourmand |
| 80010 | Wild boars attacked the smuggler's merchandise; kill 10 for his report | Smuggler |
| 80012 | Spiders killed Anna's husband while they gathered mushrooms; kill 10 for her report | Widow Anna |

Citizen IDs 50167 (Gourmand), 50168 (Anna), 50169 (Smuggler) were independently
checked by decompressing records from `private/A000BA0E/all_citizen.godat`.
The archive has count at offset 15; 12-byte table entries begin at offset 23,
with citizen ID followed by payload offset. Payloads contain zlib data.
Mayor 50164, captain 50166 and merchant 50179 are carried over from the initial
extraction. Monster identifiers are corroborated by `data/monsters.json`:
70071 Viper Gang Bandit, 70073 Wild Boar, 70076 Spider.
The actual longsword is item **10010**, `长剑`, in `data/equipment.json`.

## Adaptation boundaries

The playable graph is `80004 -> 80591 -> 80552 -> 80005`, with all three
witness quests available while 80005 is active. The narrative, witness roles,
ten-kill objectives and level-eight turn-in requirement are supported by the
original text. The exact binary prerequisite fields have not been decoded;
this graph is an implementation of the narrative, not a verified binary copy.

Prices, initial currency (100 copper), EXP, copper rewards, combat stats,
cooldowns and progression formulas are provisional tuning. They must not be
presented as original numerical balance. Ukrainian dialogue is a paraphrase.
Generated Chinese dialogue was removed because it was not a verbatim source
transcript. The earlier invented jackal/forged-blade quest was removed entirely.
Jackals remain ambient wildlife and grant combat experience.

## Implementation and persistence

`QuestData` owns the seven definitions. `ProgressionController` is the single
owner of currency, inventory, objective state and rewards. HUD emits completion
once and the world does not grant the reward a second time. NPCs use explicit
citizen IDs. Quest 80591 requires purchase of item 10010 and consumes it on
handover. Quest 80005 requires three completed witness quests and level >= 8.

A new v2 profile uses `user://guanlin_v2.json`. Earlier prototype
`savegame.json` files are left untouched because their quest graph differs.
Saves use a temporary file and rename, retaining `.bak`; if interrupted between
renames, binding recovers the backup when the main file is absent. This is a
recoverable replacement protocol, not a multi-file atomic transaction.
Malformed saves are preserved and block autosave. Stats and the entire quest
ledger are validated before applying them. Saved death restores safe health.
Android application pause, desktop close, kills, purchases, rewards, level-up
and a periodic timer save progress. `--review` and `--test-mode` suppress profile
loading and automatic writes in HUD-driven test runs.

## Verification

- `tests/combat_flow.gd`: enemy warning, out-of-range miss, dash, modal combat
  lock, once-only experience, death cancellation and respawn.
- `tests/progression_all_test.gd`: prerequisites, actual purchase and handover,
  wrong turn-in, partial kill progress, level-eight gate, disk round trip,
  recoverable save replacement and malformed data preservation.
- `tests/world_flow.gd -- --test-mode`: all six citizens and enemies in the real
  scene, the entire seven-quest route through HUD actions, exactly one completion
  signal per quest, live modal movement lock.

This first area compresses the town and forest into one playable scene. The
original zone geography, later story, classes, trading, equipment, authoritative
multiplayer and full Android device QA are still separate production work.
