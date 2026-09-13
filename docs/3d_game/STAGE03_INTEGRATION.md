# Stage 03: Wind Hill integration

Updated: 2026-09-13. Wind Hill now includes the single giant bird encounter in
[#34](BIRD_ENCOUNTER.md). Its defence drawing and bird departure gate the existing
transition to Stage 4. The environment details below remain applicable.

## Entry and controls

- In Stage 2, walk along the lakeside path to the white birch area to enter Stage 3
  automatically. The user selected this location in a screenshot; the exit begins
  at z=-28 across the entire X axis, including both sides of the path and jumps.
  The temporary preview button has been removed.
- Alternatively, run `3d_game/scenes/wind_hill/wind_hill.tscn` directly in Godot.
- **Back to woodland** returns to a fresh Stage 2 preview. Returning resets that encounter. Forward progression requires resolving each encounter.
- Continue horizontally right to the large rock beside the tree to enter Sunset
  Cove at x>=9.5. This vertical screen boundary covers all Z positions and heights;
  jumping onto the rock is unnecessary. The giant bird must first be sent away with protection. See [Stage 04 integration](STAGE04_INTEGRATION.md).
- Uses the shared Moonlit Wanderer, walking, jumping, sprinting and controller input.
- September 13 visual adjustment: the Stage 3 protagonist uses scale 1.8216,
  a further 10% increase from 1.656. Movement and capsule collision retain
  their shared settings.
- Spawns on the central path at x=0, z=-0.5. The authored 49-degree perspective
  camera retains its initial position and orientation, then follows ground movement.
- Terrain, rocks and the base-pose tree trunks have mesh collision. The path is a
  visual overlay on the terrain; foliage, shadows and distant scenery have no collision.
- Falling below y=-4 returns to spawn. Solved bird progress is preserved.

Stage 2 and Stage 3 share the configurable preview controller in
`3d_game/scripts/woodland/woodland_level.gd`; each scene owns its art integration.

## Wind setting

The user's requested setting is slightly below maximum: **80% of the delivered
strong-wind deformation**. `wind_strength = 0.8` is exposed on `Stage03Art`.
The imported `Strong_Wind_16s` clip is duplicated at runtime and its blend-shape
weights are scaled, retaining the 16-second timing. This softens branches, leaves,
grass, flowers, shadows and cloud deformation without accumulating reductions when
the scene is re-entered. Feather trajectories retain source timing. Cloud motion uses the separate
continuous cycle described below.

Tree collision stays in its base pose while the upper branches sway. No dynamic
collision or wind force on the player is implied.

### Continuous clouds (#50, September 13)

The supplied 16-second clip resets both the 11 cloud layers' positions and their
baked morph poses. At the repeat boundary a layer jumped 36.898 world units in
one 60 FPS frame. Fixing translation alone still left a visible shape reset
(the sampled deformed vertex moved 1.036 units in one frame).

The runtime now disables only cloud position and blend-shape tracks in the
copied wind animation, and plays those tracks in a separate **64-second drift**.
A cosine time mapping moves through the original cloud poses and back, easing
to a stop at each turn. Both endpoints match, including the baked shape.
The motion stays within the delivered cloud positions, and never teleports to
an origin or abruptly reverses. The cloud's existing 80% deformation is retained;
trees, grass, flowers, shadows and feathers keep their original 16-second clock.
The imported GLB and its shared animation resource are unchanged.

`wind_hill_cloud_loop_smoke.gd` runs the actual runtime animation players through
two complete cloud cycles at 60 FPS. It checks all 11 layers for translation
jumps, abrupt velocity changes, baked vertex jumps and frozen motion. The test
failed on the original loop and on the incomplete translation-only fix. With
the complete fix, the largest position step is 0.030212 units, sampled deformed
vertex step 0.031518 units, and per-frame velocity change 0.001484 units/frame.

```sh
godot --headless --path 3d_game --script res://tests/wind_hill_cloud_loop_smoke.gd
```

For rendered boundary comparisons, omit `--headless` and append `-- --visual`.
This runs the full stage and saves six `/private/tmp/paws-stage03-cloud-*.png`
frames around 16 seconds (the old reset), 32 seconds (the far turn), and
64 seconds (the new repeat). Forward+ frames were inspected on Apple M1;
the sky remains continuous at these boundaries. The existing Stage 3 traversal
smoke also passes, including source wind amplitude, movement, jump and recovery.
These checks do not establish Web rendering or browser performance.

## Source and texture repair

User-supplied sources:

- `Downloads/Stage 3/Wind-Hill-Animation (2)/Wind-Hill-Animated.glb`
- `Downloads/Stage 3/Wind-Hill-Game-Assets (6)/textures/*.png`

The source has 109 meshes, 30 embedded images, one camera and a 16-second animation
with 63 channels. Its embedded PNGs contain blank black images; the separately
delivered PNGs contain the actual painted artwork. The project-owned
`3d_game/models/stage03/wind_hill.glb` therefore replaces all 30 embedded images
with those original PNGs. Geometry, materials, camera and animation metadata are
unchanged. Every replacement was verified byte-for-byte, and the repaired GLB has
no external URI dependencies. Downloads is not needed at runtime.

- Source SHA-256: `51e7fa12914d8cedc92059c409887d20ac6b0842308dfc1be25a8a05fcc6ecfd`
- Repaired SHA-256: `5a9c8db67dd103954742be2aaf9273ecba2abd64578b1c762d84c773b996f5c8`

The repair is reproducible from the repository root:

```sh
python3 3d_game/scripts/wind_hill/prepare_asset.py \
  --source "$HOME/Downloads/Stage 3/Wind-Hill-Animation (2)/Wind-Hill-Animated.glb" \
  --textures "$HOME/Downloads/Stage 3/Wind-Hill-Game-Assets (6)/textures" \
  --output 3d_game/models/stage03/wind_hill.glb
godot --headless --path 3d_game --editor --import
```

The Stage 3 post-import script also preserves vertex colors, adjusts the texture V
origin for the original Canvas PNGs, and renders the sky dome's inside faces.
Godot extracts named project-local PNGs next to the repaired GLB. Keep those files,
their import metadata and the integration scripts together.

The original delivery and ZIP remain untouched. Source author and asset usage
terms were not supplied. The delivery identifies generated image textures and
procedural scene artwork; its Three.js vendor code is not copied into the game.

## Verification

Godot 4.7.2 Forward+ on Apple M1 rendered the corrected scene for visual inspection.
`res://tests/wind_hill_smoke.gd` verifies walking from Stage 2 into the lakeside exit
and returning, no early transition at spawn, stopping before
the exit, one active scene,
grounded spawn, character framing, movement, jumping, fall recovery, authored lens,
wind playback and morph changes, 80% amplitude, collision selection, vertex colors
and unlit materials. It passed with desktop rendering.

The existing `woodland_smoke.gd` and `stage_transition_smoke.gd` checks also passed.
`woodland_exit_smoke.gd` covers crossing the boundary at five X positions from
-59 to 59, including the lakeside shoulder and terrain edges, and confirms that
stopping before the boundary does not transition. This regression initially
failed at all four positions outside the old narrow path trigger.
Headless sandbox runs emit macOS certificate and user-log/editor-settings permission
messages; the desktop Stage 3 check completed without engine errors.
Web rendering and performance budgets are not verified. Bird encounter checks
are recorded separately in [Bird encounter](BIRD_ENCOUNTER.md).
