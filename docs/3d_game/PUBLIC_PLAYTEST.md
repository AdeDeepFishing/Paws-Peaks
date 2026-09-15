# September 15 playtest fixes (#72)

## Player-facing changes

- River initial and recovery positions move to `(-5.1, 1.5, -4.1)`, keeping the
  standing character below the narration banner and beside the path.
- Hide generation mode selectors and duplicate in-scene back buttons. The menu
  retains navigation. Test code can still explicitly select offline modes.
- All five scene adapters default to Live AI, including the explicit Chapter 4
  override. No automatic test run is allowed to spend provider credits.
- The otter's microphone gift uses the same full-color painted microphone texture
  as the speech button, with the existing gift particles and timing.
- Show the Storykeeper mood meter after reveal and update its percentage from
  narrator state. Hide it during drawing, chapter transitions and the ending.
- Remove the Chapter 5 stop-generation button. Request cancellation on lifecycle
  boundaries remains available in code.
- A submitted drawing no longer writes to the player's speech caption or revives
  an earlier transcript while busy. Actual spoken text still uses that caption.

## Chapter 5 entry diagnosis

A focused offline Forward+ map-to-Chapter-5 reproduction measured a 593 ms
maximum frame. The scene resource retrieval took about 0.02 ms and page capture
about 25 ms; environment initialization accounted for roughly 474 ms. The hero
setup was about 7 ms. This identified synchronous environment preparation rather
than a provider request as the main source of the observed pause.

The 81 fixed terrain/rock/trunk collision shapes are now precomputed in
`models/stage05/collision_shapes.res`. Fixed forest setup yields between batches,
and both the chapter page and grounded entrance wait for preparation. The boss
also waits for this terrain before raycasting its ground position. Daybreak
textures are scene dependencies instead of synchronous setup loads.

The same route measured a final maximum frame of 236 ms, approximately 60% lower.
A short first-render/upload pause remains: this is not a claim of stutter-free
60 FPS or browser performance. The regression guard uses 350 ms to catch a return
to the measured half-second freeze; the earlier exploratory 150 ms target was not
met. Timing varies with GPU, filesystem cache and concurrent applications.

Rebuild the collision resource after modifying the Chapter 5 mesh delivery:

```sh
godot --headless --path 3d_game --script res://tools/bake_forest_collision.gd
```

## Focused verification

- `public_playtest_smoke.gd`: PASS, with rendered captures. Checks all scene AI
  defaults, river banner clearance, hidden duplicate controls, matching microphone
  texture, visible/updating mood, grounded entry, drawing submission without a
  player speech caption, and preservation of actual speech captions.
- `chapter5_transition_smoke.gd`: PASS against the 350 ms regression budget;
  final recorded maximum 236 ms. The isolated transition probe emits an exit
  resource warning, so it does not establish leak-free repeated journeys.
- No backend suite or paid provider calls were run for these changes.

## Hosting boundary

This is desktop playtest preparation. Generation still uses the desktop Python
worker/mailbox transport; narrator startup is disabled in Web builds. A browser
backend transport and public hosting configuration are separate release work.
Defaulting to Live AI does not establish a working Vercel-hosted AI game.
