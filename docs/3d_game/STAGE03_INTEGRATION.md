# Stage 03: Wind Hill integration

Updated: 2026-09-12. This is a playable environment preview. The E03 crow
encounter, drawing rules and success condition remain open. The environment
transition to Stage 4 is now available through issue #31.

## Entry and controls

- In Stage 2, walk along the lakeside path to the white birch area to enter Stage 3
  automatically. The user selected this location in a screenshot; the exit begins
  at z=-28 across the entire X axis, including both sides of the path and jumps.
  The temporary preview button has been removed.
- Alternatively, run `3d_game/scenes/wind_hill/wind_hill.tscn` directly in Godot.
- **Back to woodland** returns to a fresh Stage 2 preview. Environment transitions
  do not represent completing the dog or crow encounters.
- Continue horizontally right to the large rock beside the tree to enter Sunset
  Cove at x>=9.5. This vertical screen boundary covers all Z positions and heights;
  jumping onto the rock is unnecessary. See [Stage 04 integration](STAGE04_INTEGRATION.md).
- Uses the shared Moonlit Wanderer, walking, jumping, sprinting and controller input.
- September 13 visual adjustment: the Stage 3 protagonist uses scale 1.656,
  a further 15% increase from 1.44. Movement and capsule collision retain
  their shared settings.
- Spawns on the central path at x=0, z=-0.5. The authored 49-degree perspective
  camera retains its initial position and orientation, then follows ground movement.
- Terrain, rocks and the base-pose tree trunks have mesh collision. The path is a
  visual overlay on the terrain; foliage, shadows and distant scenery have no collision.
- Falling below y=-4 returns to spawn. There is no encounter progress to preserve yet.

Stage 2 and Stage 3 share the configurable preview controller in
`3d_game/scripts/woodland/woodland_level.gd`; each scene owns its art integration.

## Wind setting

The user's requested setting is slightly below maximum: **80% of the delivered
strong-wind deformation**. `wind_strength = 0.8` is exposed on `Stage03Art`.
The imported `Strong_Wind_16s` clip is duplicated at runtime and its blend-shape
weights are scaled, retaining the 16-second timing. This softens branches, leaves,
grass, flowers, shadows and cloud deformation without accumulating reductions when
the scene is re-entered. Cloud travel and feather trajectories retain source timing.

The delivery warns that cloud travel may reset visibly at the loop boundary.
Tree collision stays in its base pose while the upper branches sway. These remain
preview limitations; no dynamic collision or wind force on the player is implied.

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
Web rendering, performance budgets and the crow encounter are not verified.
