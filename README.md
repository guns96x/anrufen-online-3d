# Covenant Chronicles 3D — build v0.7.0

Godot 4.7.2, Android landscape and Windows. This build upgrades the first playable
area and its RPG systems; it is not a finished MMO. Original source archives and
the initial data/*.json files remain unchanged. Recovered records are exported
separately under data/original with a reproducible decoder and SHA-256 manifest.

## Play

Windows: run `Play_Game.bat`.

Android: install `build/covenant_chronicles_v0.7.0.apk` (arm64, same debug signing
identity, package `com.covenant.chronicles`, version code 7).

Desktop controls: WASD/arrows move, E talk, Space/J attack, 1/K assigned skill,
2/3/4 cast other assigned skills, Shift/L dash, right mouse drag rotates the camera, mouse wheel zooms. Keys can
be rebound in Settings. The Menu button opens twelve functional sections.
Android: floating left joystick, right-side camera drag, pinch zoom, target tap,
and action buttons. Dialogue blocks movement, attacks and camera input.

Start by speaking to the mayor beside the town hall. Meet the weapons merchant,
buy the longsword and deliver it to the mayor, then report to the militia captain.
The captain's investigation opens three witness quests from the Gourmand, widow
Anna and the smuggler. Finish their ten-enemy objectives and reach level eight
before returning all three reports. The quest tracker and minimap indicate the
next available giver and turn-in destination.

## v0.7.0 — Guanlin Town rebuilt

- Town plan follows the original `city_guanlinzhen.wim` (decoded, see `docs/reference/`):
  crossroads plaza, chapel with tower, tavern, homes, alchemy, smithy, inn, market and
  consignment arcade, log palisade and a forest gate (`shared/world/guanlin_layout.gd`).
- Buildings are assembled from the CC0 Quaternius Medieval Village kit (`assets/village`)
  by `TownBuilder` and baked into one mesh per texture with generated LODs.
- All 34 original citizens stand at their source tiles with their roles, dressed from
  the CC0 KayKit Adventurers (`CitizenLook`).
- The hero is a KayKit knight (mage for magic classes) with gear tiers every 10 levels and
  real locomotion, strike, cast, dodge, hit and death animations (`HeroAvatar`).
- Renders: `tools/capture_town.gd`, `tools/capture_hero.gd`. Original art decoders:
  `tools/original_art/`.
- Known: `companions_test` and `pet_runes_test` were already failing before v0.7.0.

## Changes in v0.5.0

- Inventory, nine equipment slots, item locks, shop, bank, synthesis, potions,
  gradual food, bag/bank expansion and skill-reset books; 1,722 catalog entries.
- Character names, two races, eight class IDs, attribute/skill allocation,
  four active hotbar slots, respec, selected titles and six mounts with ride rules.
- Forty-four actual class skills use 171 recovered Lua arrays, binary cooldowns,
  rank caps and prerequisite skill/rank fields. Shared local/server action plans
  implement multi-hit/elemental attacks, self/party healing and auras, mana shield,
  taunt/threat, cleanse/dispel, freeze, periodic curse and passive stat/recovery.
- Twenty-three original egg items, incubation, summons, following/combat,
  feeding/healing/revival, rejuvenation, breeding and runic skill transfer.
- Real audio, graphics, FPS, camera, keybind, joystick, names/damage,
  auto-loot filters and auto-potion settings with persistence.
- Map/NPC search and A* routes around world collisions.
- Durable LAN/Tailscale profiles, chat, friends, blocking, parties, guilds and
  announcements, private text mail, bilateral trade, consignment and bounties.
- Shared server-authoritative movement, sixteen monsters, combat/skills,
  rewards/quests, pet attacks, respawns, PK modes and consented duels. Client
  menus use the same server-owned inventory, equipment, wallet and bank.
- Offline/online profile isolation; server restart restores online identity,
  inventory, quest progress and accepted bounties without regranting supplies.
- UV textured timber/plaster buildings, slate roofs, a stone fountain, oak forest,
  articulated characters, bandits and a jackal model. Original models retained.
- Wind in the grass, animated water, ambience and short combat sounds.
- Building/fountain collisions and camera obstruction.
- Enemy attack windups, warning rings, range checks and dash evasion.
- Seven opening quests based on original texts, real copper/sword purchase,
  prerequisites, three witness reports and once-only rewards.
- Ukrainian HUD and scrollable dialogue.
- Recoverable saves to `user://guanlin_v2.json`, with a previous `.bak` file.
  Earlier prototype profiles are left untouched. Corrupt saves are protected.

Narrative evidence and adaptation boundaries: `docs/anrufen-opening-sources.md`.
Feature-by-feature fidelity and outstanding work: `docs/original-feature-parity.md`.
Networking and persistence: `docs/lan-social.md`.
Art pipeline, saved generated texture paths and Imagegen prompt:
`docs/art-direction.md`. The material images were generated with built-in
Imagegen; models and sounds use reproducible local scripts.

## Validation

Run each command from the project directory using the Godot console executable:

```powershell
python tools/run_checks.py
python tools/check_transport.py
python tools/check_world_transport.py
python tools/extract_original_tables.py
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug Android build/covenant_chronicles_v0.5.0.apk
python tools/verify_apk.py
```

`tools/capture_review.gd -- --review` captures the actual rendered scene, HUD and
long dialogue in `build/review-*.png` without loading or saving the player profile.
`tools/capture_functions.gd` captures menus; `tools/capture_network.gd` captures
the shared world and social screen, also using `-- --review`.
Physical Android performance and touch playthrough still need device verification.

## Scope remaining

Full original parity remains open. Prices, EXP rewards, gear bonuses, base stats,
MP costs, world ranges and some unlock requirements remain provisional. Class
skill constants, cooldowns, caps and skill prerequisites now use recovered data;
hit/evasion/resistance conversion still needs original-formula verification.
Owned v0.4 prototype abilities remain compatible while new heroes start with a
real class skill. Version-five migration preserves a separate `.pre-v5` snapshot.
The archive also contains pet/monster skills outside the 44 player skills. Equipment
upgrade/durability/affixes, set bonuses, two-seat co-riding, full pet talents/aging,
all title conditions and later narrative/zones remain outstanding. The present
scene compresses the town and forest into one test area. See the parity matrix.
