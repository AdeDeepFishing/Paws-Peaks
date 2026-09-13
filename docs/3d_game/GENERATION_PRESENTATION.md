# Shared sketch generation atmosphere

Updated September 13, 2026. The user's global playtest direction replaces the
construction tent with particles and soft blur around the submitted sketch.
This supersedes older cloth-cover descriptions in the stage integration notes.

## Player experience

- On submission, small pearl-white particles with pale mint, pink and gold highlights
  drift around the sketch. A softly masked local blur makes the nearby scene hazy
  with a denser pearl-white center (88% cover opacity), while keeping the drawing
  and interpretation readable.
- The atmosphere follows the submitted sketch's world contact as the camera moves
  and zooms. River now anchors its preview to the drawing plane as well; Dog and
  Bird retain their existing terrain anchors. The endpoint is the same location
  used by the drawing preview, not a separate tent or construction prop.
- Woodland fits its 40-degree close-up to the protagonist, dog, model and sketch,
  with at most 30% sketch enlargement and smooth group tracking. Wind Hill instead
  uses a closer 32-degree shot with up to 65% sketch enlargement, fitted to the
  protagonist and drawing/model. After the initial move it stays fixed, regardless
  of bird movement, through processing and the result hold. Both retain mist margins
  and widen for large drawings; Wind Hill stays above the foreground hill.
- Early interpretation and reference images keep their existing lifecycle. The
  effect remains until the finished model is actually presented, including the
  short interval after the backend reports READY.
- Model presentation removes the sketch, particles and local blur together. The
  two-second completed-model hold and zoom-out timing stay intact, followed by each
  encounter's reaction. Cancel, failure, timeout and scene exit remove the effect.
- Normal controls remain available while processing after the initial focus.
  The local overlay ignores pointer input and introduces no collision or movement.

## Shared implementation

`generation_preview.gd` owns one reusable `generation_mist.gd` control. Every scene
using the common generation preview gets the same presentation, currently River,
Woodland and Wind Hill. Environment-only stages without drawing do not emit an
unrelated effect; future encounters inherit this when they attach the shared preview.
The River and Dog/Bird camera controllers no longer create tent geometry.

The renderer uses 64 bounded CPU particles with a generated radial glow texture,
plus a 25-tap local Gaussian screen blur with feathered elliptical edges. The mist
is drawn on a separate layer behind the normal HUD, sketch and interpretation card,
so labels and controls remain crisp. It adds no image generation,
new downloaded assets, persistent draft copies or backend calls.

## Verification

- `generation_mist_smoke.gd`: actual offline submissions in all three scenes,
  active particles, sketch-relative bounds and camera anchoring, no remaining tent,
  persistence through READY, model cleanup and cancellation. Its `--visual` mode
  captures each scene using Forward+.
- `dog_offering_framing_smoke.gd`: small, large, wide and tall sketch framing,
  mist margins, and a revealed offering that remains still when the dog approaches.
- Existing `encounter_flow_smoke.gd` and `dog_presentation_smoke.gd`: generation
  focus, completed-result hold, camera restoration and failure/cancel recovery.
- `bird_encounter_smoke.gd`: enlarged defence and giant bird progression with the
  new shared atmosphere.

Offline desktop verification does not establish Web renderer support or browser
performance. No new paid provider requests are required by these checks.
