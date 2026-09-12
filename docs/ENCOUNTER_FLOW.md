# Construction, rewards, and accessible crossing

## Agreed flow

Submitting a drawing starts generation immediately. The drawing's screen-space bounds
are projected onto the encounter plane to place a temporary construction cloth.
The camera keeps its orientation, moves toward that position and zooms from the
normal size to 12 units (0.55 seconds), holds for 0.7 seconds, then returns (0.55
seconds). Input and the regular HUD pause only during these short presentations.

Eight coins drop onto random clear ground on the near bank after the opening shot
returns. Sampling covers x=-15..-6.2, z=-16..1, with at least 3.2 units between
coins and 2.8 units from the player. Downward terrain rays and standing-capsule
checks reject water, tree/rock tops, steep ground, and cramped positions. There are no
coins at initial spawn. Coins give the player something to do while generation runs;
collecting them neither gates completion nor guarantees that the provider is ready.
Retrying cannot duplicate rewards. Restart resets them. Hidden coins cannot be collected.

Once a valid result is ready, a second shot focuses on the placed object, removes the
cloth and reveals the result, holds for 0.9 seconds, and returns control. A fast result
waits for the opening sequence. Failure or cancellation restores the camera and input,
removes the cloth, and prevents canceled animations from releasing coins later.

## Movement

The stage retains a fixed overhead angle and keyboard movement relative to that angle.
Near the bridge, input is projected onto the crossing axis with gentle lateral
centering. One right/down input toward the far bank can cross; release stops, reverse
walks back. Land movement stays free. The generated visual is aligned using its dominant
horizontal surface rather than the highest railing, and the authored collision width
is adjusted to the model. Collision remains a simplified gameplay deck, not an exact
reconstruction of arbitrary curved meshes.

The old stage boundary at z=2 blocked walking at approximately z=1.33 even though the
imported meadow continued beyond it. Boundaries now sit near the imported terrain's
outer extent. The camera pans when the player approaches the screen edges while
preserving its overhead angle. Rocks, tree trunks, water, and map edges still constrain
movement intentionally; no global removal of terrain or prop collision was made.

## Backend update

Merged PR #17 locally and preserved the desktop progress callback and output folder
contract. The current default is OpenAI 816px image editing followed by Meshy T2.
The teammate's documented comparison measured 26.664s versus 19.700s for one pair
of runs; this is not a latency guarantee. No paid generation was needed for this change.

## Verification

- 44 offline Python tests after the PR #17 merge.
- `river_smoke.gd`: drawing, immutable PNG transport, request lifecycle, and crossing.
- `desktop_generation_smoke.gd`: a real fixture worker, returned GLB placement, single-key
  crossing, cancellation/stale results, and missing-backend errors.
- `encounter_flow_smoke.gd`: construction/reveal camera shots, fast-result ordering,
  reward timing/standing room, stop/reverse/cross input, cancel/failure recovery,
  reset, and the formerly blocked meadow route.

These are local changes pending playtesting. Web generation remains separate.
