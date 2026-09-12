# Stage 02: woodland path integration

Updated: 2026-09-12. This is a playable environment preview. The E02 dog confrontation,
accepted drawing actions, combat rules and progression to E03 are still unspecified
or unimplemented; this scene does not claim those mechanics are complete.

## Source and project ownership

The user supplied `Downloads/Stage 2/woodland_path.glb`, edition V4. It is copied
unchanged into `3d_game/models/stage02/woodland_path.glb`.
SHA-256: `7f2bffbbc0bfc1651b972c257b006abb70e02f46cc35856f6d3ae19008acace4`.

All ten textures are embedded; Godot extracts project-local copies next to the GLB.
The game has no runtime reference to Downloads. Keep the GLB, extracted textures,
import metadata and scene scripts together. Source build scripts and reference media
remain in the original delivery/ZIP. Source authorship/license details were not supplied.

The supplied metadata reports 498 objects, 261,699 triangles, 182 animated objects,
and an eight-second loop. Distant hills and tree silhouettes are painted scenery,
not a fully modeled open world.

## Gameplay preview

- Entry: `3d_game/scenes/woodland/woodland_path.tscn`.
- Crossing Stage 1 keeps movement enabled. Reaching the lower-right path exit at x>=18, z=-8.5..-3.5
  enters Stage 2 automatically; there is no completion modal. The camera settles back to the original
  overview on the far bank so this exit stays near the screen edge. Stage 2 provides
  **Back to river** for comparing scenes; this starts a fresh river stage.
- Reuses the animated [Moonlit Wanderer protagonist](HERO_INTEGRATION.md), WASD/arrows,
  jump, sprint and idle hop cue.
- Uses the delivered Player_spawn marker, with a short settling drop onto terrain.
- Preserves the reference camera's perspective, 49-degree vertical FOV and orientation.
  The camera is pulled back six units so the hiker fits completely in frame, and
  follows horizontal player movement without mouse orbit.
- Terrain, main tree trunks, solid rocks and the wooden fence have mesh collision.
  Foliage, paint strokes, baked shadows, distant scenery and lake remain visual-only.
  Falling off the walkable terrace returns to spawn.
- Reuses the vertex-color post-import fix from Stage 1 to preserve painted materials.
- Plays `Breeze_8s_24fps`, including morph-target wind and the 96-frame baked shadow loop.

## Verification

`res://tests/woodland_smoke.gd` verifies grounded spawn, path movement, fall recovery,
fixed camera orientation, full-character framing, vertex-color materials, wind playback,
and one active baked-shadow frame at five points in the loop. A rendered screenshot
was inspected in Godot 4.7.2 Forward+ on Apple M1. The back button was exercised. `stage_transition_smoke.gd` walks across the
bridge, checks that stopping leaves control available, then continues walking
and verifies automatic transition with the old scene removed.

The Godot importer emits zero-basis quaternion warnings for the source's hidden
shadow frames (zero scales); runtime playback and the one-active-shadow checks pass.
The source GLB was preserved instead of rewriting the designer's animation data.
Web performance and final collision simplification have not been verified.

## Can the Stage 1 Downloads folder be removed?

The project-owned Stage 1 GLB is byte-identical to the supplied file, contains its
textures, and has no external URI dependencies. Removing `Downloads/Stag01` does not
break the game. The project does not archive every original generation script, video
or reference image; retain the delivery ZIP or another source backup if those are needed.
No Downloads files were deleted during this integration.
