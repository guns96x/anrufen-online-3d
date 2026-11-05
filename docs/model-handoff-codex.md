# Model brief for Codex (Blender → Godot)

Design source: `docs/character-sheet.md`. Style: anime cel-shading (the game adds toon
lighting, rim and ink outlines itself via `ToonStyle`), so textures carry flat colour and
painted detail, no baked lighting or AO. All characters are original; do not copy any
existing game's characters.

Deliver GLB files only. Do not edit game code; the integration reads the files below.
Check every file with `python tools/validate_models.py` before handing over.

## Files

| Kind | Path | Names |
|---|---|---|
| Hero | `assets/characters/hero/` | `human_warrior_m.glb`, `human_warrior_f.glb`, `human_mage_m.glb`, `human_mage_f.glb`, `elf_warrior_m.glb`, `elf_warrior_f.glb`, `elf_mage_m.glb`, `elf_mage_f.glb` |
| Town cast | `assets/characters/cast/` | role ids from `GuanlinLayout.CITIZENS`: `mayor.glb`, `militia_captain.glb`, `widow_anna.glb`, `gourmand.glb`, `smuggler.glb`, `ranger.glb`, `alchemist.glb`, `jeweller.glb`, `mystery_merchant.glb`, … ; residents `resident_1.glb` … `resident_4.glb`; consignment clerks `consign_1.glb` … `consign_6.glb` |
| Monsters | `assets/creatures/` | replace `boar.glb`, `spider.glb`, `jackal.glb`; add `bandit.glb`, `brute.glb` |

Order of work: the eight hero files and the six quest NPCs first (mayor, militia_captain,
widow_anna, gourmand, smuggler, ranger), then the rest of the town, then monsters.

## Scale, orientation, budgets

- 1 unit = 1 m; adult height 1.65–1.95 m (anime proportion, ~7 heads); children ~1.3 m.
- Character faces **+Z** (glTF forward), origin between the feet, Y up.
- Triangles: hero ≤ 12 000, NPC ≤ 8 000, monster ≤ 6 000. Materials ≤ 3 per file,
  textures ≤ 2048 for heroes, ≤ 1024 otherwise. Mobile renderer: no alpha-blended hair
  (use alpha scissor), no more than 1 transparent material.

## Skeleton

Humanoids use **one shared rig** with Godot `SkeletonProfileHumanoid` bone names so every
animation is shared: `Hips, Spine, Chest, UpperChest, Neck, Head, LeftShoulder,
LeftUpperArm, LeftLowerArm, LeftHand, RightShoulder, RightUpperArm, RightLowerArm,
RightHand, LeftUpperLeg, LeftLowerLeg, LeftFoot, LeftToes, RightUpperLeg, RightLowerLeg,
RightFoot, RightToes` (fingers optional, same profile). Add `handslot.l` and `handslot.r`
child bones of the hands for weapons and shields.

## Animations (exact clip names)

Humanoids — the game already plays these names:

`Idle`, `Walking_A`, `Running_A`, `1H_Melee_Attack_Slice_Diagonal`, `1H_Melee_Attack_Chop`,
`1H_Melee_Attack_Slice_Horizontal`, `1H_Melee_Attack_Stab`, `2H_Melee_Idle`,
`2H_Melee_Attack_Slice`, `2H_Melee_Attack_Chop`, `2H_Melee_Attack_Spin`, `Spellcast_Shoot`,
`Dodge_Forward`, `Hit_A`, `Death_A`, `Death_A_Pose`, `Blocking`, `Interact`, `Cheer`,
`Sit_Chair_Idle`. Each cast member also gets its own idle from the sheet named
`Idle_Character` (the captain watching the gate, the Gourmand tasting from the spoon…).

Monsters: `Idle`, `Walk`, `Attack`, `Hit`, `Death` (Death ends lying still).

## Gear meshes on the hero

Separate mesh objects parented to the hand slots or head bone, named exactly as the
game toggles them: `1H_Sword`, `2H_Sword`, `Round_Shield`, `Badge_Shield`,
`Rectangle_Shield`, `Spike_Shield`, `Knight_Helmet`, `Knight_Cape` for warriors;
`1H_Wand`, `2H_Staff`, `Mage_Hat`, `Mage_Cape`, `Spellbook` for mages. Body meshes end
in `_Body`, `_Head`, `_ArmLeft`, `_ArmRight`, `_LegLeft`, `_LegRight` (the race tint and
armour-rarity tint look for these suffixes).
