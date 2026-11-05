# Hero (8 variants)

Player character. Same rig and animation set for all eight; differences are body,
outfit and gear. Gear meshes must use the exact names in `model-handoff-codex.md` and
start hidden-ready (separate objects; the game toggles visibility).

| File | Body | Outfit (base, always visible) | Palette |
|---|---|---|---|
| `human_warrior_m` | 1.85 m, broad shoulders, short swept hair, light stubble | padded gambeson, leather belt with buckle, bracers, boots; cloak over one shoulder is the `Knight_Cape` mesh | steel grey, deep blue, gold trim |
| `human_warrior_f` | 1.72 m, athletic, high ponytail | fitted gambeson with flared hem, corset belt, thigh-high boots | same |
| `human_mage_m` | 1.80 m, slim, longer wavy hair | high-collar robe split at the front over trousers, chain with book clasp at hip | burgundy, cream, bronze |
| `human_mage_f` | 1.68 m, slender, long side-swept hair | high-collar robe-dress with side slit (trousers/leggings under), wide sleeves | same |
| `elf_warrior_m` | 1.88 m, lean, pointed ears, long braid | leaf-plated narrow armour (light), sash | silver, lilac, night blue |
| `elf_warrior_f` | 1.76 m, long braid to waist, pointed ears | same line, fitted, tasset skirt over leggings | same |
| `elf_mage_m` | 1.84 m, silver hair, rune tattoos on forearms (texture, emissive) | asymmetric mantle, high boots | lilac, white, pale blue glow |
| `elf_mage_f` | 1.72 m, silver hair, rune tattoos | asymmetric robe-dress with side slit, open shoulder on one side | same |

Elf skin: light lavender tint is applied by the game to meshes ending in `_Head`,
`_ArmLeft`, `_ArmRight`, so paint skin neutral and keep those suffixes.

Gear meshes (all variants of the class carry all of them):
- Warrior: `1H_Sword` (straight arming sword), `2H_Sword` (long greatsword),
  `Round_Shield` (wood + iron rim), `Badge_Shield` (heater with crest), `Rectangle_Shield`
  (kite, painted), `Spike_Shield` (dark steel with spikes), `Knight_Helmet` (open-face, does
  not hide the face), `Knight_Cape`.
- Mage: `1H_Wand` (crystal tip), `2H_Staff` (crescent head), `Mage_Hat` (wide-brim, feather),
  `Mage_Cape` (short mantle), `Spellbook` (book on a chain at the hip).

Idle_Character: warrior flips the sword once and rests it; mage spins a small orb of
light over the palm. Budget 12 000 triangles with all gear visible.
