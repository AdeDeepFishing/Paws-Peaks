# Day 1 — River Prototype Handoff

## Contents

- [Current scope](#current-scope)
- [Files and ownership](#files-and-ownership)
- [AI integration](#ai-integration)
- [Rules and lifecycle](#rules-and-lifecycle)
- [Art and audio replacement](#art-and-audio-replacement)
- [Verification](#verification)
- [Remaining work](#remaining-work)

## Current scope

Updated with the team on September 12 for issue #1: use third-person movement, a lower-right
sketchbook with an E shortcut, and a bridge before considering a raft. This supersedes the
earlier first-person prototype decision.
The first encounter is the river; the otter remains Stage 4.

The startup scene is `3d_game/scenes/river/river_crossing.tscn`. The original dungeon
is still available at `3d_game/main.tscn`. Godot resource paths below resolve inside `3d_game/`.

Implemented: near/far banks, simple scenery, grounded jump and sprint, eight coins,
interaction trigger, drawing/undo/clear, immutable PNG export, mock response selection,
background request state, item inspection, a collidable bridge, paper-sketch display,
fall recovery, completion/restart, and synthesized SFX with mute.

This is explicitly **PROTOTYPE · NO AI**. Any nonempty drawing can get the selected
mock result. No real image recognition, network call, API credential, or AI cost is involved.

## Files and ownership

| File | Responsibility |
|---|---|
| `scenes/river/river_crossing.tscn` | Editable placeholder world, collision, trigger, coins, bridge, player, request node |
| `scenes/river/river_player.tscn` | Editable neutral geometric hiker, capsule collision, and SpringArm3D camera rig |
| `scripts/river/river_player.gd` | Reuses Brackeys input settings/helpers; camera-relative movement, visual facing, orbit, input locks, and respawn |
| `scripts/river/drawing_surface.gd` | Logical 512 × 512 strokes, UI drawing, undo/clear, PNG rasterization |
| `scripts/river/river_level.gd` | First-stage UI, encounter outcome, collection/progression, placeholder sounds |
| `scripts/river/drawing_request.gd` | Beichun's integration boundary; mock transport, request identity, deadline, result validation |
| `tests/river_smoke.gd` | Agent-runnable checks of the actual scene and request/drawing code |

Yanwen owns the canvas, player-side integration, and first stage. Beichun owns the real
AI/backend request and validated response. Coordinate changes to the shared request script;
the actual HTTP transport can be a separate node connected to its signals.

## AI integration

1. Set `mock_mode = false` on the `DrawingRequest` node **before running**.
2. Connect `request_prepared(payload: Dictionary)` to the transport.
3. Send the payload to the agreed backend. No provider API key belongs in Godot or the browser.
4. Parse the JSON as a dictionary, then call `accept_response(response: Dictionary)` on the same node.
5. Map transport errors to the versioned error response below using the original request ID.

Do not directly modify the player, bridge, or UI from the network callback.
The request node emits `state_changed(state)` and the level reacts to it.

Request:

```json
{
  "schema_version": 2,
  "request_id": "E01-unique-id",
  "encounter_id": "E01",
  "locale": "en",
  "image_base64": "<base64 PNG bytes, without a data URL prefix>"
}
```

The image is 512 × 512, dark ink on a light background, with a 1 MiB maximum.
`DrawingSurface.snapshot_png()` also exposes the raw `PackedByteArray` for local tests.
The latest submitted PNG is written to `user://drawings/E01-latest.png`; use Godot's
Open User Data Folder command to retrieve it. This local copy is overwritten on submission
and is not committed. The signal payload is the primary integration interface.

Recognized response:

```json
{
  "schema_version": 2,
  "request_id": "E01-unique-id",
  "status": "recognized",
  "item": {
    "name": "Paper bridge",
    "description": "A long, sturdy idea to carry you across.",
    "type": "TOOL",
    "attack_power": 0,
    "range": 8.0,
    "speed": 1.0,
    "durability": 3,
    "tags": ["LONG_REACH", "STURDY"]
  }
}
```

Uncertain response: use the same version/request ID, `"status": "uncertain"`, and `"item": null`.
Service failure: use the same version/request ID and `"error": {"code": "SERVICE_UNAVAILABLE"}`.
The current client displays a generic service-failure message; per-error-code UX can be refined later.

All five required item fields are validated against SPEC bounds. Unknown types/tags,
missing fields, out-of-range/nonfinite values, and invalid numeric types are rejected.
Integer-valued JSON numbers are accepted for attack power and durability, since JSON parsing
may represent numbers as floats. Names/descriptions are displayed as plain text.

## Rules and lifecycle

- Camera input is confirmed: click to capture, move the mouse to orbit, and release for UI.
- WASD movement follows camera yaw, without pitch affecting ground speed. The visual character
  turns toward travel; idle camera orbit leaves character facing unchanged.
- Camera pivot height is 1.25 units, normal distance 5 units, initial pitch about -16 degrees,
  with pitch clamped from -55 to +15 degrees. These feel parameters can be tuned during playtesting.
- A sphere-cast SpringArm3D shortens the camera distance around collidable geometry, excludes the
  player's own collider, and restores distance when clear. The model hides only when the camera
  is closer than 0.8 units, preventing an inside-the-body view in very tight spaces.
- The capsule physics body remains upright. Replace the placeholder meshes under `Model` when
  final character art is ready; keep the rig and collision node paths. The current limb swing
  is procedural placeholder animation, not a final rigged character animation set.

- The drawing area unlocks the book. E opens it when grounded; drawing stops movement/look.
- Escape closes UI and releases the cursor. E or the Close button restores captured exploration.
- Submitting closes the panel, takes an independent PNG snapshot, and returns movement immediately.
- One request is pending at a time. A second submission cannot silently replace it.
- Default mock delay: 3 seconds. Default deadline: 20 seconds, measured with monotonic elapsed time.
- Response request IDs must match the active request. Canceled, timed-out, or pre-restart responses are ignored.
- Ready/failure feedback is non-modal. Opening a pending panel permits explicit cancellation.
- Closing the book preserves strokes; later edits do not mutate the submitted image.
- A failed new request preserves the previous usable idea via **View previous idea**.
- Bridge rule: `LONG_REACH` + `STURDY`, positive durability, grounded player within 5 units of the
  near-bank post, and no bridge already built. These are prototype rules for designer review.
- Bridge dimensions are authored; Range is displayed but does not determine bridge length.
  Attack power and Speed are informational in this prototype. One successful use spends one durability.
- The river gap exceeds the current sprint-jump reach. Falling returns the player to the near bank,
  keeping coins, request identity, the drawing, and the bridge. No scene reload is used for falling.
- Coin IDs prevent repeat pickups. Six coins are on the near bank, two on the far bank; drawing is free.
- Walking onto the far bank after building the bridge completes the stage. Play again resets the session.

## Art and audio replacement

Character direction confirmed with Yanwen: a gender-neutral abstract hiker, with no hair,
a round mint-colored head rather than a human complexion, simple dot eyes, and rounded
clothing shapes. Keep the backpack and scarf; final art should preserve this neutral direction.

The graybox scene is authored as ordinary editable Godot nodes. Replace each object's
`Visual` mesh/material while retaining its parent transform and collision unless changing
level design deliberately. `Bridge/Deck/CollisionShape3D` controls walkability;
`Bridge/Sketch` displays the user's actual submitted drawing. Preserve those node paths.

Trees, rocks, river, sign, banks, and bridge are geometric placeholders. Final illustrated
assets can be swapped in without changing the request/canvas code. Collision should stay simple.

The UI is currently built in `river_level.gd` with a cream/green palette and a short panel fade.
The small sketchbook previews the draft after closing. Final UI styling can be separated into
a reusable scene later, after the interaction is agreed.

Coin/submit/ready/bridge sounds are synthesized in code, with a Sound toggle. They are temporary
feedback, not the planned soundtrack. BGM, voiced narrator/NPC dialogue, separate audio buses,
and final audio mixing are not implemented here.

## Verification

From the repository root:

```sh
godot --headless --path 3d_game --script res://tests/river_smoke.gd
```

The checks instantiate the actual level, produce a PNG through drawing input, verify UI
movement locking and immutable request payloads, collect during a pending request, fall/respawn,
reject stale/malformed results, build the bridge, and walk across its collision to completion.
They also check idle orbit, camera-relative movement and facing, pitch clamps, normalized
diagonal sprint, camera retraction/recovery against a physical wall, modal camera locking,
restart, unsuitable ideas, timeouts, and all four mock outcomes.

For local render inspection on macOS:

```sh
godot --path 3d_game --script res://tests/river_smoke.gd -- --visual
```

This captures the game's own viewport to `/private/tmp/paws-river-*.png`. It is a desktop
render check; it does not verify a hosted browser build or subjective movement feel.

## Remaining work

- Connect and test the real AI backend with varied sketches; agree on tag interpretation and error codes.
- Playtest mouse capture, sketchbook positioning, movement feel, and the bridge reveal with the team.
- Add final river art, music, English narration/dialogue, and audio controls.
- Confirm alternative solutions and actual item-stat use in later encounters.
- Implement E02–E05, bounded pushing/climbing, and stage transitions.
- Adapt the project from Forward Plus to the Web target and test exported/hosted input, audio,
  image submission, latency, and respawn in supported browsers. Browser compatibility is not claimed yet.
