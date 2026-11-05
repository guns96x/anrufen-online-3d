# Codex task: batch 1 character models (Blender → GLB)

Read first: `docs/model-handoff-codex.md` (rig, clip names, budgets, gear mesh names) and
`docs/character-sheet.md` (whole cast). One spec per model in this folder:

| Order | Spec | Output |
|---|---|---|
| 1 | `hero.md` | `assets/characters/hero/{human,elf}_{warrior,mage}_{m,f}.glb` (8 files) |
| 2 | `mayor.md` | `assets/characters/cast/mayor.glb` |
| 3 | `militia_captain.md` | `assets/characters/cast/militia_captain.glb` |
| 4 | `widow_anna.md` | `assets/characters/cast/widow_anna.glb` |
| 5 | `gourmand.md` | `assets/characters/cast/gourmand.glb` |
| 6 | `smuggler.md` | `assets/characters/cast/smuggler.glb` |
| 7 | `ranger.md` | `assets/characters/cast/ranger.glb` |

## Rules

- Work only in `assets/` and in your own Blender source folder `art_src/` (create it;
  keep one `.blend` per model plus a build script if you script it). Do not edit any
  `.gd`, `.tscn`, `project.godot` or test files. Claude integrates.
- All designs are original. Do not copy characters, costumes or logos from Genshin
  Impact or any other game; "Genshin" only describes the rendering style.
- Everyone is an adult except the children in later batches. Attractive characters are
  shown through silhouette, outfit and pose; nothing explicit, no exposed underwear,
  target store rating 12+.
- Build one shared humanoid armature first (`art_src/rig/humanoid.blend`), then every
  humanoid uses it. Author the shared animation set once on that rig and reuse it.
- Style: clean anime topology, big readable shapes, hand-painted flat albedo (one
  atlas per model), no baked lighting/AO, no normal maps needed. The game adds toon
  lighting, rim light and outlines.
- Face +Z, origin between the feet, metres, Y up. Apply all transforms before export.

## Export (Blender glTF exporter)

Format GLB · Include: selected objects + armature · Transform: +Y up · Data: apply
modifiers, UVs, normals, materials (export images) · Animation: NLA tracks / actions,
always sample, group by NLA track · Skinning on, max 4 influences · Compression off.

## Done means

1. `python tools/validate_models.py` prints OK for every new file.
2. A turnaround render (front, side, back) and one action frame per model saved to
   `art_src/renders/<name>_*.png`.
3. Commit only `assets/` and `art_src/` with a message listing the files; tell Pavlo.
