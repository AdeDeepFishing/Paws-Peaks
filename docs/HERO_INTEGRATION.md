# Moonlit Wanderer protagonist

Integrated 2026-09-12 into the shared player scene used by the river and woodland.

## Delivery

The user supplied three skinned GLBs in
`Downloads/Meshy_AI_Moonlit_Wanderer_biped/`. The filename prefix is
`Meshy_AI_Moonlit_Wanderer_biped_Animation_`; copies in `3d_game/models/hero/` map as follows:

| Delivery suffix | Project file | Animation |
|---|---|---|
| `Stand_and_Chat_withSkin.glb` | `idle.glb` | Idle, 5.23 seconds |
| `Walking_withSkin.glb` | `walk.glb` | Walk, 1.03 seconds |
| `Running_withSkin.glb` | `run.glb` | Run, 0.70 seconds |

GLB bytes are preserved. Each includes its skeleton and three embedded textures;
Godot extracts project-local JPEG copies. Keep assets and import metadata together.
The game does not read anything from Downloads at runtime.

## Runtime behavior

`hero_visual.gd` uses one visible skinned model and copies the full animation from
each delivery into a shared library, ignoring the extra two-frame reset clips.
Horizontal Hips translation is pinned to its rest position so authored animation
cannot move the model away from the gameplay capsule. Vertical bounce is retained.
The 1.7-unit source is scaled to 1.8 units and rotated from +Z to controller-forward -Z.

Actual horizontal motion selects walking; after more than three continuous grounded
seconds it selects the run animation and increases movement speed from 4.0 to 7.5
world units per second (87.5% faster). Shift can request the same faster speed manually
but does not bypass the three-second animation delay, including after a stop. Stopping, jumping, focus loss and input locks reset the timer.

Ordinary idle uses a constant clip of the first standing pose. The animation player
continues advancing so outgoing run blends finish instead of freezing and reappearing
when movement resumes. The three-hop locator starts only after
five idle seconds, then rests twelve seconds between bursts. It remains visual-only.
Drawing entry plays the delivered Stand and Chat clip at 70% speed as a thinking
stand-in; this delivery does not contain a dedicated thinking clip. Cancel or submit
ends that animation. Camera locks do not trigger it. Active clips loop and transitions
blend over 0.15 seconds.

Stage 2 sets the shared player's `appearance_scale` to 1.2 for a twenty-percent larger
visual. Stage 1 retains 1.0. Feet stay anchored to the existing capsule; collision
geometry and the designer camera remain unchanged.
No jump clip was delivered: airborne movement temporarily holds the first idle pose,
then resumes the appropriate grounded animation on landing. Drawing and camera
locks suppress locomotion animation. Collision shape and level geometry retain their existing values.

## Verification

Run `godot --path 3d_game --script res://tests/hero_smoke.gd -- --visual` for animation
transitions, jump/landing, input locks, skeleton count and horizontal animation drift.
The test captures river and woodland screenshots for material and framing inspection.
Run `res://tests/stage_transition_smoke.gd` and `res://tests/river_smoke.gd` for crossing,
scene transition and river gameplay regression checks. Desktop rendering was checked;
Web export and a dedicated jump animation remain unverified or unavailable.

Issue #22 covers the stage-specific size, calmer idle timing, automatic run animation
and drawing-time thinking stand-in. The hero smoke test checks these behaviors in
addition to the original integration checks.

Restart regression: `res://tests/hero_restart_smoke.gd` compares bone rotations after
run → long idle → walk against a character starting from fresh idle. Previously,
freezing AnimationPlayer speed also froze outgoing run blends; the regression failed
both at rest and on restarting. The constant standing clip keeps blends advancing.
The movement test also covers restarting with Shift held and verifies the full delay.
