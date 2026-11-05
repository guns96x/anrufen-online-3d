# Original Anrufen feature audit — v0.5 functional checkpoint

This is an implementation audit, not a claim of complete original parity. Source
IDs below refer to decoded `data/original/AnbufenUI.json` or named source tables.
Raw binaries are read-only. `tools/extract_original_tables.py --write` reproduces
the derived tables; `original-archive-manifest.json` records hashes and counts.

| Original feature evidence | Current executable behavior | Remaining fidelity work |
|---|---|---|
| UI10008 character/equipment/attributes/title/race/class | Name, two races, eight classes, attribute points, nine gear slots, derived stats | Original numeric attributes and advancement thresholds |
| UI10032 bag/skills/tasks/PK/loot | Twelve-section menu with actual mutations; separate offline and server profiles | Final art/UI layout |
| UI10021 skill points; all_skill / all_skilltree; original Lua | 44 class skills, four hotbar slots, source constants/cooldowns/ranks/skill prerequisites, physical/magic stats, passive effects, combos, group auras/heal, shield, freeze, dispel, periodic curse, threat and respec | Original MP costs, full unlock conditions, hit/evasion/resistance conversion; pet/monster skills outside the player catalog |
| UI10023 tasks; original quest texts | Seven verified opening records, original actors/targets and ten-kill reports | Later quests and exact binary prerequisites/rewards |
| UI10026 sound/display/network/keys/reset | Persisted working audio buses, graphics scaling/shadows, FPS, camera, rebind/reset | Physical S24 touch/performance verification |
| UI10035 pickup filters | Actual nearby ground loot and independent category filters | Full original loot tables and rarity |
| UI10037 world map / find NPC / path | Minimap, citizen search, collision-aware A* routes | Original full world geography, exits and other zones |
| UI10016 player trade | Recipient consent, bilateral offers/confirmation, atomic capacities/wallet checks, item locks | Item-instance metadata and original fees |
| UI10034 friends / party / guild | Requests, blocking, invite/accept/leave/kick and leader succession | Guild rank/contribution/level/guard systems |
| UI10055 create guild; UI10056 公会宣言 | Paid guild creation, leader announcement, member visibility | 公会宣言 means announcement; no invented war feature is claimed |
| UI10047 mail | Private text inbox, read/delete/recipient checks | Original attachment semantics if evidenced |
| UI10072 consignment search | Server escrow listings, buy/cancel, offline seller payment | Rich filters, deadlines and exact original fees |
| UI10038 hunt/bounty task | Target, reserved reward, minimum hunter level, required kills, accept/cancel, server-death progress and once-only payment | Original task templates, publication fees and exact limits |
| UI10049 synthesis; all_combine | Atomic two-recipe material/currency crafting at service NPC | Decode and implement all original recipes |
| all_citizen merchant equipment tutorial | Equip/unequip/buy/sell/lock, bank and bag expansion | Source explicitly mentions upgrade to +10, failure, durability, prefix/suffix strengthening: NOT yet executable |
| all_suit (41 real records) | Source catalog recovered | Set bonuses not implemented |
| UI10036 incubation; all_pet (27 real species) | Twenty-three eggs, timed hatch, owned pets, summon/follow/combat | Correct original incubation duration, egg genetics and all species models |
| UI10018 pet attributes/skills/raising | HP, hunger, XP/level, names, source skill IDs, elemental attack effects | Full talents, MP, resistances, gender/personality/taming/transformation and natural lifespan rules |
| UI10043 breeding | Two selected pets, price/hunger checks, egg incubation and skill inheritance | Original bilateral player breeding/consent, genetics and fees |
| UI10066 skill transfer; rune props30749/30023/30750/30751/30752/30753 | Main/donor selection, rune-selected source/target slots, atomic consumption, 3-skill limit | Original random probability and donor fate; current donor loses the transferred skill |
| Props30015/30988/30989,30025/30703 | Lifespan reset or one-stage rejuvenation; revival consumables | Stage duration and HP are provisional; no automatic age death |
| all_equip six mounts, including three-day variants | Ride model, speed/reduction, no mounted attacks, dismount/death, nonrenewable lease/bank preservation | Two-seat co-riding and all distinct mount models |
| all_title (137 real records) | Source catalog, owned title validation/selection, class title unlocks | All original title earning conditions and bonuses; class unlocks are modern adaptation |
| Original online game | Shared ENet movement, creatures, combat, inventory/quests, PK and consensual duel | Public service/account security, shard scaling, original server protocol and full source authority rules |
| UI10069 phone/account recovery | Stable local token and server account ID | Legacy phone/SMS recovery requires a real provider and service; not simulated |

The presence of a recovered catalog is not an implemented gameplay mechanic.
User priority remains functional parity before expanding locations and story.

Source skill extraction: `tools/extract_skill_rules.py` reads 97 bindings and 171
arrays; 44 bindings belong to the eight player classes. `source_requirement` is
retained as raw evidence, not silently interpreted: advanced values 80/90/105
require verification with the overall progression model. Character-level gates
are currently modern tuning. The separate `extract_client_scripts.py` recovers
all nine named Lua/INI files from the variable-length archive index without
executing them. These include original attribute IDs, mount-affinity thresholds,
and automatic potion lists, which are still being integrated.
