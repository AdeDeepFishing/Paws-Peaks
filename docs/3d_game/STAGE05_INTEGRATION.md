# Stage 05: Moonlit Forest integration

> Test consolidation: test names and results below describe historical verification. See [Testing](TESTING.md) for the current stage suites and coverage; retired scripts are no longer runnable.

Updated: 2026-09-14. Uses the designer's V5 replacement for issue #32.
The giant Storykeeper visual and idle loop (#36) are integrated; see
[Boss integration](BOSS_INTEGRATION.md). Personality/agent work (#63) and
encounter drawing rules remain separate.
The dawn ending (#52) is connected through a temporary exploration shortcut;
see [Ending integration](ENDING_INTEGRATION.md).

## Entry and traversal

- In Sunset Cove, walk right toward the cave entrance shown in the supplied
  screenshot. Reaching world **x >= 5.5** enters Moonlit Forest. This boundary
  covers every Z position and height, so walking beside the cave or jumping also
  triggers the transition. The player does not need to climb onto a rock or enter
  the narrow tunnel. The existing Stage 2 and Stage 3 exit boundaries are unchanged.
- Direct entry: `3d_game/scenes/moonlit_forest/moonlit_forest.tscn`.
- The shared Moonlit Wanderer retains Stage 4's visual scale of 1.08. Walking,
  sprinting, jumping and controller movement use the existing player controller.
- Spawn is (0, 2, 4), with a short drop onto the central forest clearing. The
  delivered 52-degree camera keeps its angle and pulls back three world units
  for gameplay framing; it follows the player's ground movement.
- Terrain, rounded rocks, embedded trail stones, main and midground trunks and buttress roots
  have mesh collision. Clouds, grass, leaves, mushrooms, fireflies and distant
  scenery are decorative. Falling below y=-4 returns to the clearing.
- **Back to Sunset Cove** returns to Stage 4's beach spawn, safely before its
  exit boundary. The GenerationWorker autoload persists across scene changes;
  entering a preview does not submit an AI request. The drawing button remains
  disabled until a Stage 5 encounter is implemented.

![Moonlit Forest in Godot](../assets/stage05/gameplay.png)

![Stage 4 cave approach before the exit boundary](../assets/stage05/cave-approach.png)

Walk around the Storykeeper and continue deeper into the clearing to world **z <= -12** to enter the dawn ending.
Like the Stage 2 exit, this boundary covers every X position and jump height.
This is a preview shortcut, not a completed boss encounter.

## Assets and provenance

The source is the user's `Downloads/moonlit-forest-v5/` delivery, replacing V4
throughout the Stage 5 environment. The file
`moonlit-forest-painted.glb` is copied unchanged to
`3d_game/models/stage05/moonlit_forest.glb`.

SHA-256: `82a71569b5543089a44228f5651a372abb8f03bda1b31713e281e14f62d7f15e`.

The 92,461,636-byte GLB contains 514 meshes, 884,728 triangles, nine embedded PNGs,
a reference camera, 20 lights and a 12-second animation with 346 source channels.
All nine Godot-extracted PNG files match the embedded image bytes. The game has
no runtime dependency on Downloads, Blender, the supplied HTML or Three.js.

V5 replaces the ancient tree shapes and bark, adds nine midground trees and
layered watercolor hills/woodland, and supplies a new painted night sky with
12 cloud layers and eight wisps. According to the delivery notes, the foliage
uses a user-supplied brush atlas; V5 adds generated night pigment textures while
retaining some earlier ground and rock paint. The source retains
its editable Blender file, build scripts and Three.js MIT notice. Vendor code
and Chinese browser interface text are not included in the game. No additional
asset license grant was supplied with the delivery.

## Materials, lighting and motion

- The shared GLB import script retains vertex colors, original textures,
  alpha-cutout foliage, emission and camera/light data.
- The V5 sky uses a native shader to restore mirrored-repeat sampling across
  its authored 5 by 2.6 texture tiling. StandardMaterial3D otherwise clamps
  this sampler, turning large parts of the painted sky into a flat color.
  The same correction applies to V5 bark's 1 by 2.35 tiling, with its original
  lit paint and emission retained across trunks, branches and roots.
  Sky, moon, clouds and firefly bodies restore the source's disabled shadow
  casting, which the GLB does not encode.
- A native foliage shader reads the authored material `windStrength` metadata
  and reproduces its UV-rooted vertex sway. The atlas scale/offset, color,
  emission and alpha thresholds remain intact. Shader deformation affects
  foliage rendering and shadows; scenery collision stays static.
- The imported animation moves the canopies, 20 cloud layers/wisps and 62 fireflies,
  including nine moving lights. Its source paths are not seamless at 12 seconds,
  so playback reverses at each end instead of teleporting back to frame zero.
  This produces a 24-second forward/back cycle rather than the browser's
  continuously advancing cloud paths.
- Native ambient light, distance fog, moon shadows and gentle bloom establish
  the night setting. The sky, moon and clouds opt out of fog as in the source.
  Directional lights use 50% and local lights 30% of the imported energy to
  compensate for the renderer's lighting response. Firefly bodies emit light
  into bloom; their actual moving point lights remain attached to the same nodes.
- Browser sprite halos and time-varying light pulses are not reproduced exactly.
  This integration preserves the delivered scene's composition and painted
  assets, without claiming pixel parity with Blender or the HTML renderer.

## Verification

Godot 4.7.2 Forward+ on Apple M1 rendered the scene for visual inspection.
`moonlit_forest_smoke.gd` walks from Stage 4 into Stage 5 without jumping, checks
spawn and collision (including the nine new tree trunks), the V5 mesh/cloud/firefly counts, camera, animated clouds
and flight paths, repeat continuity, foliage atlas/wind settings, movement,
jump/landing, fall recovery, return navigation and persistent worker retention.
`sunset_cove_exit_smoke.gd` checks both sides of the new boundary at multiple
depths and an airborne height. Stage 4 traversal and reflection lifecycle tests
cover regressions in the preceding scene.

```sh
godot --headless --path 3d_game --script res://tests/sunset_cove_exit_smoke.gd
godot --headless --path 3d_game --script res://tests/water_reflection_smoke.gd
```

For screenshots, omit `--headless` and add `-- --visual` to the first command.
It writes `/private/tmp/paws-stage04-cave-exit.png` and
`/private/tmp/paws-stage05.png`. Headless execution does not validate rendered
pixels. Web export, browser performance and the final boss encounter have not been tested
or implemented by this scene integration; the large asset still needs a Web
delivery budget pass.

## Drawings become objects

Submitting a Stage 5 sketch now starts live 3D generation and the existing boss
narrative response. The shared sketch/reference mist stays visible while generation
runs, and Stop generating object cancels the model request independently of dialogue.
The completed object appears on nearby terrain using AI mass and placement. A new
successful result replaces the previous object. Failure or cancellation retains the
sketch for retry. Spawning an object does not itself clear the boss.
