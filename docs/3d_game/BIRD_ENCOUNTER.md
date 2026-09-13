# Stage 3: giant bird encounter (#34)

Current global presentation: construction tents have been replaced by sketch-local
particles and soft blur. See [Generation presentation](GENERATION_PRESENTATION.md).
Existing camera timing and encounter reactions remain in place.

Updated September 13, 2026. This implements the bird encounter in Wind Hill.
The user's latest direction is **one very large bird**, replacing the earlier
multiple-crow premise. The backend stage identity remains `E03` / `crows`.

## Playthrough

- A single Moonwing waits beside the path, takes flight, circles the protagonist
  and periodically swoops near them. Its supplied model is scaled fourfold:
  approximately 6.8 units tall in its source pose, compared with the hero's 3.3.
  The breathing and flapping representations are never visible together.
- The protagonist automatically ducks and leans away during each swoop. This is
  a visual reaction, with no health loss, forced displacement or timing challenge.
  Walking and jumping still work. The rightward boundary at x=6 stops all bypasses,
  including jumps and either shoulder, until the encounter finishes.
- Press E or click Draw, then sketch an umbrella or shield over nearby terrain.
  The canvas freezes the bird and protagonist, and hides the normal HUD.
- Live generation uses the existing desktop worker and the four-field item
  contract. DEFENCE is the supported solution. BOW, MAGIC and UNKNOWN remain
  recognized backend categories but give a contextual retry in this encounter.
- Soft particles and local blur surround the sketch at its ground contact. The camera moves
  above the grass into a close-up over two seconds and holds while processing.
  Early interpretation/reference previews use the shared generation overlay.
  After the model appears, the view holds two seconds and returns over one second.
- The finished model replaces the sketch overlay. The protection rises above the
  protagonist and expands to a ten-unit width, comparable with the giant bird's
  wingspan. The bird approaches above the actual canopy height, recoils and flies away. Only after departure
  does movement resume and the Stage 4 exit open. The model remains equipped and
  follows the protagonist; it is not a loose obstacle on the ground.
- Stop waiting / Escape, service errors, unclear drawings, unsupported items and
  invalid model files restore control and keep the latest canvas draft for retry.
  Late and duplicate responses cannot unlock the exit or replay the resolution.
  Falling preserves solved progress. Re-entering the scene begins a fresh encounter.

## Assets and code

User-supplied assets, copied unchanged from Downloads/bird:

- `Moonwing-FlapLoop-15k-Handpainted.glb` -> `models/bird/flap.glb`
- `Moonwing-BreathingIdle-15k-Handpainted.glb` -> `models/bird/idle.glb`

The original painted material, normal map and skinned animation are retained.
Godot extracts project-local texture files beside the GLBs. Source authorship and
usage terms were not included with this delivery; no third-party license claim is
made. Downloads is not needed to run the committed project.

`bird_guard.gd` owns flight and reaction state. `bird_encounter.gd` owns drawing,
protection and progression. The shared reveal controller now accepts an
optional encounter pause hook and close-up transform; Stage 2 keeps its existing
camera and pause behavior. Only terrain receives the drawing raycast layer, so
swaying foliage and tree branches cannot become a placement surface.

The scene defaults to the existing AI mode, which makes paid calls only when the
player submits a drawing. Its **Mock outcomes · No AI** option provides explicit
umbrella/shield stand-ins and failure cases without backend requests. These shapes
are test stand-ins, not recognition or generated art. All scenes share the latest
single draft archive. No backend source or credentials are included in this change.

## Verification

Run `godot --headless --path 3d_game --script res://tests/bird_encounter_smoke.gd`.
Add `-- --visual` and omit `--headless` for a rendered playthrough and captures.
The smoke covers a single giant bird, arrival/swoop/duck, drawing pause, full-width
gating, uncertainty/error/unsupported retries, cancellation, late and duplicate
replies, missing model, umbrella and shield success, an existing committed generated
umbrella, fall recovery, and the transition to Stage 4. Test drafts use /private/tmp.

Related regression checks are `wind_hill_smoke.gd`, `wind_hill_exit_smoke.gd` and
`dog_presentation_smoke.gd`. The exit test now explicitly starts with completion
when testing the old exit geometry; the encounter smoke checks its lock separately.
Desktop visual checks cover the giant bird, duck, raised reveal camera, equipped
protection and departure. These are offline checks: they do not establish new paid
recognition accuracy, browser backend support or Web performance.

`bird_grounding_smoke.gd` checks that raising and enlarging the existing generated
umbrella never lifts either the player capsule or its visual. The measured maximum
capsule lift was 0.0 units. A reported apparent launch during an automated preview
was reproduced by its intentional fall/recovery test (1.72 units); that debug
recovery is not part of the protection sequence. Use the ordinary scene for player
review, rather than displaying automated traversal/recovery tests as gameplay.
