# Stage 04: Sunset Cove integration

Updated: 2026-09-13. Implements the environment and transition requested in
issue #31. E04 otter interaction and drawing rules remain separate work.
The Stage 5 environment and cave exit are added by #32.

## Route and controls

- In Stage 3, move right toward the large rock beside the right-hand tree.
  Reaching world **x >= 9.5** enters Sunset Cove automatically. The boundary sits
  just before the rock's solid edge so the player can walk through without jumping
  onto the rock. It covers every Z position and height, including nearby grass
  and airborne movement. Stopping before the boundary keeps Stage 3 active.
- Stage 3's main progression is horizontal; forward/back movement remains available.
  The shared exit marker supports world -Z for Stage 2 and world +X for Stage 3.
- Direct entry: `3d_game/scenes/sunset_cove/sunset_cove.tscn`.
- Stage 4 uses the shared Moonlit Wanderer at visual scale 1.08 (25% smaller than
  the previous 1.44 appearance), with walking,
  sprinting, jumping and the existing keyboard/controller controls.
- Spawn is on the near beach at (0, 2, 6), with a short drop onto the sand.
  The delivered 53-degree camera keeps its orientation and pulls back three units
  to frame the character. It follows ground movement without mouse orbit.
- **Back to Wind Hill** returns to a fresh Stage 3 preview. Scene changes preserve
  the existing GenerationWorker autoload; no AI request is made by these previews.
- Continue right to the cave approach at world x>=5.5 to enter Moonlit Forest.
  The boundary covers all Z positions and heights, including the surrounding
  grass; no jump or narrow tunnel entry is required. See
  [Stage 05 integration](STAGE05_INTEGRATION.md).
- Sand, river banks, cave surfaces, solid rocks and main trunks have collision.
  Water, distant scenery, painted foliage and the background ground underlay do not.
  Falling below y=-4 returns to the beach. Water is not a walkable floor.

![Sunset Cove in Godot](../assets/stage04/gameplay.png)

## Project-owned assets

The source is the user's `Downloads/stage4-sunset-cove-unified/sunset-cove.glb`
(revision 11). It is copied unchanged to `3d_game/models/stage04/sunset_cove.glb`.
SHA-256: `e4d8655bf1d37b6448b67f09b5a5883fa80f40bc174b8ac8bb8728fe8996cd9f`.

The GLB contains 1,305 meshes, approximately 1.20 million triangles, ten embedded
PNG textures, the reference camera, and a 16-second animation with 945 source
channels. Godot removes three immutable tracks during import. All ten extracted
project textures were checked against their embedded bytes. There are no external
URI dependencies or runtime references to Downloads. Keep the GLB, extracted PNGs,
import metadata and scripts together. The original delivery remains untouched.

The delivery describes generated surface textures and a user-supplied transparent
brush atlas. Source authorship and asset usage terms were not supplied. Three.js
vendor code is not included in the game; the original delivery retains its license
and source files.

## Materials and motion

- The GLB already stores the correct texture V orientation; no image replacement
  or vertical texture flip is applied.
- The import script preserves vertex colors and unlit painted materials. Godot's
  standard material cannot reproduce the source's mirrored-repeat sampling, so
  seven painted material families use a small native shader that folds positive
  and negative UVs. This fixes stretched stripe artifacts on the sky, sand and rocks.
- The sky mirrors horizontally and clamps vertically. Its shader renders both
  sides of the sphere and drifts the painted clouds gently.
- Water blends two continuously advancing samples of the delivered painted texture
  at 0.48 and 0.69 world units per second. This is a native Godot approximation.
- A live planar reflection mirrors the gameplay camera across the water at
  y=-0.07. A SubViewport shares the existing World3D, including the protagonist,
  animated foliage and painted sky. Water and its overlays, plus the background
  ground underlay, use visual layer 20 and are excluded from the reflection camera
  to prevent feedback and underlay occlusion. The gameplay camera still sees them.
  The water mixes the reflection with its painted color at 29–51% depending on
  viewing angle, with small moving UV ripples adapted from the source renderer.
- Reflection updates run after camera follow. The render target preserves the
  gameplay aspect ratio on resize and is capped at 1280 by 720 pixels. A local
  camera-axis flip keeps a valid camera basis; the shader reverses the image flip.
  The scene owns its water material and viewport, which are freed on exit. This
  adds a second scenery render pass; it does not duplicate geometry or physics.
  See Godot's [viewport documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/viewports.html)
  for shared worlds and camera cull masks.
- The imported `Handpainted_Breeze_And_Water` clip plays on a 16-second loop,
  retaining the source's 12 fps node animation. Godot consumes the `_Loop` suffix
  as an import hint. Leaves, grass, tree branches and exported water details animate.
- The browser-only dynamic painted shadows, extra surface glazes and expanding
  contact-ripple shader are not ported. Contact waterlines
  retain their exported appearance. The Godot preview does not claim exact visual
  parity with the original HTML renderer.

## Verification

Godot 4.7.2 Forward+ on Apple M1 rendered the final scene without gameplay or shader
errors. `sunset_cove_smoke.gd` checks actual horizontal walking from Stage 3 into
Stage 4 without jumping, grounded beach spawn, camera and character framing,
animation transform changes, material/texture preservation, selected collisions,
walking/jumping/landing, fall recovery, return navigation and persistent autoload.

`wind_hill_exit_smoke.gd` samples near/far Z positions and airborne height on both
sides of the +X boundary. The existing `woodland_exit_smoke.gd`,
`stage_transition_smoke.gd`, `woodland_smoke.gd` and `wind_hill_smoke.gd` cover the
earlier scenes and unchanged -Z boundary. Scene-count assertions now count 3D
worlds while allowing the GenerationWorker added by PR #30 to persist.

`water_reflection_smoke.gd` checks shared-world rendering, water/underlay exclusion,
camera projection after movement, resize aspect ratio and resolution cap, viewport
cleanup and scene re-entry. Its rendered mode uses a live magenta probe over open
water, checks the reflection camera's projected pixel, and verifies that enabling
reflection changes the corresponding water pixel. It also captures the gameplay
view and resized view for visual inspection.

Run from the repository root:

```sh
godot --headless --path 3d_game --script res://tests/sunset_cove_smoke.gd
godot --headless --path 3d_game --script res://tests/wind_hill_exit_smoke.gd
godot --path 3d_game --script res://tests/water_reflection_smoke.gd -- --visual
```

Add `-- --visual` to the first command, and omit `--headless`, to capture Stage 3's
rock approach and Stage 4's gameplay view in `/private/tmp/`.

The headless sandbox emits macOS certificate and log/editor-settings permission
messages. These are separate from gameplay assertions. Web export, browser
performance and final collision optimization have not been verified. The 64 MiB
GLB and roughly 1.20 million triangles require a separate Web budget pass.
