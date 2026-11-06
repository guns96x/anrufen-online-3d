# Batch 1 character production

**Status: the user rejected the procedural appearance. No batch-1 model is
approved or ready for integration.** The rejected GLB is preserved under
`rejected/procedural-v1/`, outside the game's asset paths. A new visual direction
is recorded under `visual-targets/target-01/`. The scripts below are retained as
technical work, not an accepted character production solution.

Target: the existing Godot Android project. Scope is `assets/` and `art_src/` only;
game integration belongs to Claude. The task supplied on 2026-11-05 is preserved
under `specs/`, including the engine handoff contract.

## Delivery contract

- Eight heroes: human/elf × warrior/mage × male/female.
- Six NPCs: mayor, militia captain, widow Anna, Gourmand, smuggler, ranger.
- Original anime designs, approximately seven heads tall, with role-specific
  clothing, hair, accessories, silhouette, and palette. No copied game designs.
- Maximum 12,000 triangles per hero including all toggleable equipment; 8,000
  per NPC. Maximum three materials, one flat albedo atlas (hero ≤2048², NPC ≤1024²).
- Shared humanoid hierarchy with the exact bone, hand-slot, animation, mesh and
  equipment names from `specs/model-handoff-codex.md`.
- GLB in metres, Y up, character faces +Z, origin at the floor between the feet.
- One `.blend` source per character, one shared rig source, four review PNGs per
  character (front, side, back, action).

## Source assumptions

`smuggler.md` and `ranger.md` were absent from `C:\AI` when work began. Their designs
come from the supplied complete character sheet: Sai has a raised eyepatch, many
pockets and straps and a coin; Eira has an emerald asymmetric tunic, leather
corset, tall boots, shoulder hood/cape, red braid, jay feather and bow. Neither
absence is treated as approval to change the existing game data.

## Build and review

1. Establish the shared rig and common motion library once.
2. Build independently named meshes, UVs, atlas, skin weights and character idle.
3. Export only the character and armature, with all gear available for toggling.
4. Save editable source and render actual geometry from three sides and an action.
5. Run the existing `python tools/validate_models.py` and the additional
   `python art_src/verify_character_exports.py` against the new GLBs.
6. Import in Godot and inspect actual rendered results before reporting delivery.

`run_build.py` runs a dedicated Blender background process with captured logs and
a bounded timeout. It uses the reviewed windowless runner installed with the
local `blender-setup` skill. It does not modify the interactive Blender scene.

The Blender executable observed in the running application is
`D:\programs\blender\blender.exe` (5.0.1). The official Blender Lab MCP requires
Blender 5.1+, and the live MCP connection did not respond during the initial check.
Any offline build is reported as offline, never as successful MCP execution.

## Modal

The existing Modal environment is `D:\SHORTS\.models\modal-venv` (SDK 1.6.2).
Authentication was verified with a read-only app listing; no cloud job was started
by that check. Credentials remain in the user's existing Modal profile, outside
this repository. They must never be copied into assets, source, logs or Git.

## Acceptance

Automated export validation and rendering demonstrate technical checks. They do
not represent the user's creative approval. Review images and any remaining
artistic or animation limitations must accompany a handoff.
