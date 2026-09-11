# Paws & Peaks — Game Jam Specification

> Version: 0.1 | Updated: 2026-09-12 | Status: Working draft
>
> Team: Four Otters — two designers and two developers, all new to Godot.
> Delivery window: four competition days. Day 1–4 below are relative milestones, not calendar dates.
> This document specifies planned work. It does not claim that these features already exist.

## 1. Product vision

**Explore a storybook mountain trail, draw objects, and use your creations to help animals and solve encounters.**

The moment we want players to remember:

> “The thing I drew actually solved this problem.”

Working tagline: **Draw something. Help someone.**

Drawing to solve encounters is the core mechanic. A confrontation may appear as an encounter, but a separate real-time combat system is outside the baseline scope.

### Design principles

1. Drawing skill is not a requirement. Rough sketches are welcome, and recognition failures do not consume opportunities.
2. Keep the player's artwork visible. The resulting object retains the original drawing in its card and use sequence.
3. Support multiple reasonable solutions. Each major encounter has at least two supported solution routes.
4. Explain the outcome. Success and unsuccessful attempts communicate why the object did or did not help.
5. Keep trying inexpensive. No drawing currency, durability, or resource loop can block progress.
6. Combine open expression with finite mechanics. The player draws freely; the game executes a small set of implemented effects.
7. Let the player explore. Walking through the world and approaching problems are part of the experience.
8. Make sound part of the experience from the first playable build.

### Audience and session

- First-time judges and casual players; no drawing or game expertise required.
- Target first playthrough: approximately 5–10 minutes, to be checked with actual playtests.
- Primary target: desktop browser, keyboard and mouse or trackpad.
- No player account, personal API key, or installation required for the intended Web release.
- Mobile controls, pen pressure, controllers, and full keyboard-only drawing are outside the baseline unless competition rules require them.
- All game text, repository documentation, code, comments, and textual asset content must be in English. Team conversation with the assistant may remain in Chinese.

## 2. Decisions and current status

| Topic | Status | Decision or working assumption |
|---|---|---|
| Game name | Confirmed | Paws & Peaks |
| Team name | Existing team identity | Four Otters |
| Team and schedule | Confirmed | Two designers, two developers, four days, Godot beginners |
| Engine | Confirmed | Godot; current starter uses 4.7.2 Standard |
| Core mechanic | Confirmed | Draw objects to solve encounters |
| Exploration | Confirmed | The player can freely walk and explore within the playable area |
| World presentation | Original direction; implementation proposal below | Small 3D storybook environment, potentially using flat illustrated characters and props |
| Camera and movement bindings | Proposed | Fixed-angle camera with bounded follow; WASD/arrow keys and proximity interaction |
| Language | Confirmed | English throughout the game and repository |
| Audio mood | Confirmed | Warm, comforting, and slightly playful |
| Background music and SFX | Confirmed | Required, with player volume controls |
| Voice acting | Default proposal | No spoken narration or voiced dialogue in the baseline |
| Otter NPC | Included in baseline | Tutorial character and one later act of help |
| Web submission | Expected, not yet verified | Confirm the official submission rules |
| Hosting | Open | Vercel is a candidate; sponsorship does not establish deployment access or credits |
| Encounters and story details | Proposed | Three encounters described in Section 6, subject to team review |
| AI provider, model, and budget | Open | Select and test early on Day 1 |

### Existing project

- Repository: <https://github.com/AdeDeepFishing/Paws-Peaks>
- Local folder: `/Users/yanwenchen/GodotProjects/Paws-Peaks`
- Board: <https://github.com/users/AdeDeepFishing/projects/1/views/1>
- Existing files include `project.godot`, `scenes/main.tscn`, README, and Git configuration.
- The starter currently displays a static title scene. Movement, drawing, encounters, AI, audio, and Web deployment have not been implemented.
- Board linking, teammate permissions, export templates, API access, and hosting must be verified separately.

## 3. Release scope

### P0 — Required for the baseline submission

| ID | Feature | Minimum definition of done |
|---|---|---|
| F01 | Start and ending | Start button, concise controls, clear ending, credits, and restart |
| F02 | Free walking | Controllable character, readable camera, collisions, bounded exploration, and reliable movement |
| F03 | Proximity interaction | Approach an encounter, see a prompt, and interact with one clear target |
| F04 | Drawing canvas | One pen, undo last stroke, clear, submit, and back |
| F05 | Real AI interpretation | Normal online mode recognizes actual player sketches and returns validated data |
| F06 | Original-art object | Original sketch, object name, short interpretation, and visible use feedback |
| F07 | Three short encounters | Tutorial, middle encounter, and finale; at least two supported routes per encounter |
| F08 | Otter | Tutorial guidance and one visible contribution in the finale |
| F09 | Recovery | Invalid objects, uncertainty, timeout, network failure, and repeated input cannot soft-lock play |
| F10 | Audio | One looping BGM track, essential SFX, global mute, and separate music/SFX volume |
| F11 | Web delivery | Hosted build supports movement, drawing, requests, sound, and a complete playthrough |
| F12 | Readability | Legible text, clear interaction prompts, and visual/text equivalents for necessary audio information |
| F13 | Submission package | Playable link, run instructions, asset credits, known limitations, and demonstration backup |

### P1 — Only after P0 works end to end

- A second music track, nature ambience, and distinctive animal or item sounds.
- Extra solution routes, richer descriptions, and more object-specific feedback.
- Additional camera transitions, reveal effects, and small environmental details.
- A closing gallery of player drawings.
- Simple confrontation actions that reuse existing effects.
- A few optional scenic inspection points with short text and no new quest system.

### Out of scope

- Arbitrary sketch-to-3D mesh generation, rigging, generated collision, or unique generated mechanics.
- A large open world, free camera rotation, jumping challenges, climbing, swimming controls, or complex terrain traversal.
- A real-time combat framework, damage statistics, durability, equipment progression, or weapon balancing.
- Drawing tokens, shops, trading, inventory economy, or crafting recipes.
- Multiplayer, accounts, leaderboards, cloud saves, and mandatory persistent progress.
- Free-form NPC chat, voice input, spoken narration, and runtime music generation.
- Pet progression, a general companion navigation system, or dynamically simulated bridges and water.

## 4. Exploration, camera, and controls

**Free walking is a baseline requirement. It must not silently become a sequence of static click-only screens.**

### World layout proposal

- One compact trail with three encounter zones and a summit destination.
- Players can walk around each zone and revisit accessible ground. Progression between major zones is ordered.
- Use shallow terrain variation, simple ground, and visible boundaries. Avoid precision movement.
- Paths, landmarks, and NPC placement should make the next destination readable without a minimap.
- A locked route has a visible reason and useful feedback. Decorative paths must not lead to accidental escape or unseen blockers.
- Keep walking between encounters short; roughly 10–20 seconds is an initial pacing target, not a hard rule.
- A fixed-angle camera may follow the player within limits. Camera rotation and manual zoom are not required.
- Do not hide the character or interactable objects behind scenery. Simplify scenery before building an occlusion system.
- A simple character model or illustrated sprite on a 3D body is sufficient; final appearance remains an art decision.

### Proposed controls

| Action | Input | Behavior |
|---|---|---|
| Move | WASD or arrow keys | Move along the walkable ground using a consistent camera-relative mapping |
| Interact | E near the highlighted target | Open the encounter panel |
| Draw | Click Draw in the panel | Open the canvas and suspend character movement |
| Draw stroke | Hold left mouse button and move | Add a stroke inside the canvas |
| Undo / clear / submit | Visible buttons | Edit or submit the current drawing |
| Use item | Click Use in the encounter panel | Apply the object to that encounter's known target |
| Back / cancel | Visible button; Escape as an optional shortcut | Close the panel or cancel waiting safely |
| Sound controls | Visible sound button | Open Music, SFX, and global mute controls |

- Use named input actions instead of scattering key checks across scripts.
- Normalize diagonal input so diagonal travel is not faster.
- Stop movement when the browser loses focus and when a modal panel opens.
- Keep the mouse cursor visible; no pointer lock is required.
- Only the nearest eligible target shows an active interaction prompt.
- Walking into a trigger does not automatically submit drawings or skip dialogue.
- Ground and boundaries prevent falling out of the map. Add a safe-position reset if an out-of-bounds state nevertheless occurs.
- Jumping, sprinting, physics pushing, and player-controlled climbing are not required.

## 5. Player flow and state

```text
Title -> Start -> Walk to the otter -> Interact
                                      |
                           Observe the problem
                                      |
                            Open canvas -> Draw
                                      |
                           Submit -> Interpretation
                                      |
                      Original sketch becomes an item
                                      |
                             Use on the encounter
                              /                \
                    Does not help            Solves it
                    Explain; retry           Show outcome
                                                  |
                                    Return to walking; route opens
                                                  |
                                     Next encounter -> Summit -> Ending
```

### State responsibilities

| State | Available behavior | Exit condition |
|---|---|---|
| EXPLORING | Walk, inspect surroundings, approach a target | Interact with an eligible target |
| OBSERVING | Read the problem, open canvas, use an existing item, or return | Draw, Use, or Back |
| DRAWING | Draw, undo, clear, submit, or back | Submit a nonempty drawing or return |
| INTERPRETING | Read waiting feedback, adjust sound, or cancel | Valid response, uncertainty, failure, timeout, or cancel |
| ITEM_READY | Inspect the object, use it, redraw, or return | Use, Draw again, or Back |
| RESOLVING | Watch the result; sound controls remain available | Sequence finishes |
| SOLVED | Read the result and continue | Continue returns control and opens the route |
| ENDING | View completion, credits, or restart | Restart resets the session |

- Character movement is suspended during encounter panels, drawing, interpretation, and result sequences.
- Maintain one current item and one draft for the active encounter. A new valid item replaces the old item; a failed request does not delete it.
- Closing and reopening the active encounter preserves its draft and item. Starting the next unsolved encounter clears them.
- Cross-encounter inventory is not required. A player can redraw the same reasonable object; rules should remain consistent.
- Solved encounters do not reset or replay rewards when revisited.
- Only one interpretation request can be pending. Late responses after cancellation, restart, or context changes are ignored.
- Each encounter can resolve only once. Closing a panel cannot skip the required resolution sequence or leave movement disabled.
- Keep progress in the current session. Refreshing may restart the game; explain this limitation in the README.

## 6. Encounter content proposals

**These scenarios make the scope concrete; they are not yet final story decisions. Replacements should preserve three short encounters, reusable effects, and two routes per encounter.**

### E01 — The otter's drifting bag

- Situation: the otter's bag has drifted into a shallow stream beyond reach from the bank.
- Introduction: the player walks to the otter and follows a short prompt to open the drawing canvas.
- Route A: draw a long pole or long-handled net; `LONG_REACH` retrieves the bag.
- Route B: draw a raft or flotation board; `FLOATS` supports a preset sequence in which the otter retrieves the bag.
- Outcome: the otter thanks the player and promises to help later. Set `otter_helped = true` and open the onward route.
- Level dressing must explain why the onward route is initially unavailable; its exact obstacle is a design task.
- Acceptance: a new player can complete one full drawing-to-outcome loop without a developer explaining it; both routes work.

### E02 — The crow and the missing direction

- Situation: a crow has taken the arrow from the trail sign and refuses to leave its perch.
- Route A: `FOOD` lures the crow away.
- Route B: `SOUND` uses a bell, drum, or similar object to attract its attention elsewhere.
- Outcome: the sign is restored and the route forward becomes accessible.
- An unrelated object receives specific feedback. For example, a long pole is unhelpful because the crow keeps hopping out of reach.
- The crow's attention to food or sound should be suggested visually or through hints.
- Muting the game does not disable a sound-producing item's gameplay effect.
- Acceptance: both routes have understandable outcomes; unsuccessful attempts consume no opportunities.

### E03 — The broken crossing

- Situation: the last crossing before the summit is broken. The player and the otter need a way across.
- Route A: `FLOATS` creates a floating aid; the otter guides it through the shallow crossing in a preset sequence.
- Route B: `LONG_REACH` and `STURDY` together create a temporary span; the otter secures the far end.
- Use fixed sequences and simple route changes. Do not simulate structural strength, water currents, or free platform placement.
- The floating route may reposition the player safely across the water after its sequence. The span route can enable a predefined walkable crossing.
- Both routes lead to the same reachable summit destination with no collision traps.
- Helping the otter earlier has a visible payoff here. Companion following and pathfinding are not necessary; the otter appears at scripted encounter positions.
- Ending: a warm shared moment at the summit, followed by completion text, credits, and restart.
- Acceptance: both routes reach the ending; otter help is visible; walking after resolution works reliably.

### Supported effects and consistency

| Tag | Meaning | Example |
|---|---|---|
| LONG_REACH | Suitable for extending reach or spanning a distance | Long pole, long board |
| FLOATS | Interpreted as a flotation aid | Raft, flotation ring |
| FOOD | Something an animal could reasonably be attracted to as food | Fruit, fish |
| SOUND | An object intended to produce noticeable sound | Bell, drum |
| STURDY | Suitable as a firm support in the story's simplified rules | Solid wooden board |
| OTHER | Recognized or described, but no supported effect applies | An unrelated decorative object |

- Each item has one or two supported tags. OTHER is exclusive and cannot accompany other tags.
- The bridge route requires both LONG_REACH and STURDY. A flimsy long object does not automatically make a bridge.
- Tags describe game affordances, not physically accurate material analysis. Rough drawings may not make length, strength, or buoyancy clear.
- Test at least 12 varied sketches before locking the tag set. Include rough, ambiguous, combined, unrelated, and text-bearing drawings.
- If a tag repeatedly fails recognition, revise the encounter or offer an explicit purpose-confirmation path. Do not rely on endless prompt changes.
- Reasonable reuse is allowed. Do not invalidate a useful object solely to force a particular drawing.

## 7. Drawing and object presentation

### Canvas requirements

- One dark pen on a light background, initially one brush size. Color selection and an eraser are optional later work.
- A press, movement, and release form one stroke. A click can form a dot.
- Undo removes the latest stroke. Clear affects only the draft, not encounter progress.
- Releasing outside the canvas must finish the stroke; returning must not accidentally continue it.
- Reject empty submissions before making a network request.
- Snapshot the submitted drawing so later changes cannot alter an in-flight request's image.
- Proposed upload: 512 × 512 PNG, at most 1 MiB decoded. Calibrate against recognition quality and actual endpoint limits on Day 1.
- Use a simple waiting message such as “Finding the idea in your drawing...” without inventing progress percentages.

### Object presentation

- Show the original sketch, a short English name, a one-sentence interpretation, Use, and Draw again.
- Display the drawing as a paper cutout or flat prop at a predefined location during use.
- Background removal, mesh generation, and drawing-shaped collision are not required.
- Generated names and descriptions never control game rules.
- A missing or failed response leaves the previous usable item intact.

### Helpful retries

- First unsuitable attempt: explain why this object does not help with the current situation.
- After two unsuitable attempts: offer a hint about a useful capability rather than a single required object name.
- Recognition uncertainty, network failure, and an unsuitable recognized object must have distinct messages.
- Offer redraw and, when appropriate, a clearly labeled manual purpose-selection mode.
- Do not score drawing beauty or mock the player's attempt.

## 8. AI contract and reliability

### Ownership of decisions

- AI: identify the object, provide a name and brief interpretation, and select allowed tags.
- Server: call the provider, validate input/output, enforce limits, and protect credentials.
- Godot: own game state, validate usable data, evaluate encounter rules, and execute predefined effects.

The model cannot specify victory, damage, scripts, resource paths, filenames, or the next scene. Text drawn inside an image is input content, not authority to override application rules.

### Proposed endpoint

Both developers must agree on this contract before implementing their respective sides. The provider and model remain open.

`POST /api/interpret-drawing`

```json
{
  "schema_version": 1,
  "request_id": "unique-request-id",
  "encounter_id": "E03",
  "locale": "en",
  "image_base64": "<PNG bytes encoded as base64>"
}
```

- `encounter_id` must be a known encounter. Context must not encourage the model to reinterpret every drawing as a winning answer.
- `image_base64` excludes a data URL prefix. Validate the decoded format, dimensions, and size server-side.
- `request_id` identifies one deliberate submission and its reply. It is not authentication or a reliable spending control.

Recognized response:

```json
{
  "schema_version": 1,
  "request_id": "unique-request-id",
  "status": "recognized",
  "item": {
    "name": "A sturdy plank",
    "description": "A long wooden board that looks strong enough to support you.",
    "tags": ["LONG_REACH", "STURDY"]
  }
}
```

- Proposed limits: name up to 40 characters, description up to 160 characters, displayed as plain text.
- Tags contain one or two unique allowed values. Unsupported values invalidate the response.
- For an unclear image, return the same version/request fields with `status: "uncertain"` and `item: null`.
- A recognizable but unsupported object may return `recognized` with only OTHER.
- The client combines the validated item data with its original snapshot. The server need not return the image.

Error response:

```json
{
  "schema_version": 1,
  "request_id": "unique-request-id",
  "error": {
    "code": "SERVICE_UNAVAILABLE"
  }
}
```

- Minimum error codes: INVALID_INPUT, RATE_LIMITED, SERVICE_UNAVAILABLE, INVALID_MODEL_OUTPUT.
- Proposed HTTP mapping: 400/413 for invalid input, 429 for limits, 502/503 for provider or output failures. Final mapping must be agreed during integration.
- The client uses local English error messages instead of displaying provider errors or stack traces.

### Waiting, cancellation, and fallback

- Initial experience target: normal interpretation within 8 seconds. Measure it; it is not a provider guarantee.
- Initial client timeout: 15 seconds, then restore options to retry or use manual mode.
- No infinite automatic retries. A retry is a deliberate click; repeated failure makes fallback prominent.
- Disable repeated submission while waiting. Ignore results belonging to canceled or obsolete requests.
- Client cancellation does not guarantee the provider stopped processing or charging.
- Manual mode allows players to select a supported purpose and uses the same encounter rules. Label it “Manual mode” or equivalent; never imply AI recognized the image.
- Fallback must allow completion, but it cannot count as proof that the real AI integration works.

### Credentials, spending, and images

- Keep provider keys in server-side environment variables, never in Git, Godot resources, or browser bundles.
- Set upload limits, server-side request limits, and a spending ceiling before sharing a public URL. The account owner must choose the actual quota and budget.
- Do not treat an embedded client token, CORS, or a freely recreated client ID as sufficient abuse prevention.
- Avoid logging or permanently storing raw drawings by default; send only the image and necessary context.
- Verify the provider's separate retention policy before making any privacy promise.
- Briefly disclose near the first submission that the drawing is sent to an AI service. No personal information is required.

## 9. Art, interface, and asset delivery

### Visual direction

- A warm storybook mountain environment with streams, trees, wooden signs, and a summit view.
- Gentle, playful stakes; no realistic violence required.
- Use simple 3D scenery with illustrated characters or props where helpful. Keep the camera and asset pipeline achievable for beginners.
- Paper framing or soft shadows can integrate rough player artwork into the scene.
- A readable walking character is required. Two-dimensional illustration frames on a 3D body are acceptable; complex rigging is not required.
- Establish character scale, ground contact point, facing convention, and idle/moving appearance before producing final assets.

### Required interface

- Title: game name, Start, controls preview, sound control, and Credits.
- World: proximity prompt, concise current objective, and sound control.
- Encounter panel: problem, Draw, current item if available, and Back.
- Canvas: drawing area, Undo, Clear, Submit, and Back/Cancel.
- Item card: sketch, name, interpretation, Use, and Draw again.
- Feedback: outcome and the next available action.
- Ending: completion, Restart, and Credits.
- Sound panel: Music and SFX sliders, plus global mute; retain values during the session.

### Asset requirements

- Agree on aspect ratio, export dimensions, naming, and pivots before batch production.
- Initial layout target: 16:9; also check usability in 1280 × 720 and 1440 × 900 browser windows.
- Use placeholders first. Gameplay must not depend on final texture dimensions.
- Prefer transparent PNGs for illustrated characters and props. Use real English UI text rather than text baked into images.
- Example names: `otter_idle.png`, `crow_perched.png`, `bg_stream.png`.
- Use a small set of character poses before considering full animation sets.
- Record asset author, source, license or usage basis, and required attribution for images, fonts, and audio in a future `CREDITS.md`.
- Check competition rules for AI-generated and pre-existing assets and disclose their use when required.

## 10. Background music and sound effects

**Audio is part of P0 and must appear in the first integrated prototype.** The confirmed mood is warm, comforting, and slightly playful. Instrumental music is the default; voice acting is not planned.

### Minimum sound list

| Asset or event | Priority | Trigger and purpose | Acceptance |
|---|---|---|---|
| `bgm_journey` | P0 | One approximately 60–90 second instrumental loop for the journey | Two consecutive loops without an obvious seam, volume jump, or duplicate playback |
| `sfx_ui_confirm` | P0 | Confirm important button actions | No sound spam on hover or pointer movement |
| `sfx_footstep` | P0 | Light walking feedback | Plays at a controlled cadence only while actually moving; stops in panels and when blocked |
| `sfx_pencil` | P0 | Subtle paper/pen feedback during drawing | Once per stroke or one controlled loop; never one new sound per frame |
| `sfx_item_reveal` | P0 | A successful interpretation reveals the object | Short and clear; once per reveal |
| `sfx_item_use` | P0 | Apply the object to the encounter | One shared effect is sufficient initially |
| `sfx_success` | P0 | Solve an encounter | Matches visual feedback; may also serve the ending |
| `sfx_try_again` | P0 | An unsuitable object or correctable action | Gentle and brief; never loops during a request |
| `ambience_nature` | P1 | Wind, stream, or birds | Quiet, unobtrusive, and consistent with mute controls |
| `bgm_finale` | P1 | A second track for the final encounter or summit | Clean transition with no accidental double playback |
| Distinct animal/item sounds | P1 | Crow, bell, board, and similar details | Add only after the minimum set works |

Minimum delivery: **one BGM track and seven SFX event categories**, including walking. Events may reuse appropriate source files; unique recordings for every event are not required.

### Playback and mixing

- Start audio in response to the player's Start click to accommodate browser autoplay restrictions.
- Use a shared audio manager with Master, Music, and SFX controls; add Ambience only if needed.
- Music and SFX volumes are independent. Keep global mute easy to find throughout gameplay and waiting states.
- Keep BGM continuous across panels and encounters rather than restarting on each UI change.
- Tune default levels by listening in the actual Web build: music sets the mood, pencil and footsteps stay subtle, success remains clear without being loud.
- Limit simultaneous SFX voices. Repeated clicks or sustained drawing must not create an audio pile-up.
- Use source assets and player volume controls for baseline mixing; do not depend on unverified Web bus effects or spatial audio.
- Suspend or reduce playback when the browser tab is hidden and resume once when it returns, respecting the player's mute choice.
- Restart and ending transitions reuse the audio manager and cannot create another BGM instance.
- Missing audio must not block gameplay. Every essential cue also has visual or textual feedback.

### Audio delivery

- Prefer compressed music; short effects may use WAV. Verify actual import, playback, and loop settings in the Web export.
- Check leading/trailing silence, loop points, peaks, and perceived loudness by listening, not merely by checking that files exist.
- Avoid unnecessarily large uncompressed music files in the final download.
- Use original, suitably licensed, or competition-permitted generated assets. Runtime generation is unnecessary.
- Record all sources and required attribution in `CREDITS.md` alongside visual assets.

## 11. Technical structure and Web delivery

### Implementation approach

- Godot 4.7.2 Standard and GDScript, with a shared engine version across the team.
- Compatibility rendering and an initial single-threaded Web export.
- A small 3D world, simple player collision, and a fixed-angle camera; drawing remains a separate 2D UI.
- A CharacterBody3D-based player is the initial implementation proposal; validate movement and ground behavior in a small graybox first.
- Godot owns the game. A lightweight server endpoint owns the model call.
- Vercel is a deployment candidate; verify hosting configuration, function limits, payload sizes, timeouts, and credits before choosing it.
- Keep exported builds and `.godot/` cache out of source commits.

### Suggested modules

| Module | Owns | Does not own |
|---|---|---|
| Main / GameFlow | Active encounter, progress, restart, ending | Provider prompts |
| PlayerController | Movement, collision, movement locking | Encounter solutions |
| InteractionController | Nearby target and interaction prompt | Model calls |
| DrawingCanvas | Strokes, undo, clear, PNG snapshot | Correct-answer rules |
| AIClient | Request lifecycle, timeout, errors, response validation | Scene progression |
| EncounterController | Tag rules, result sequence, route unlocking | Generated code execution |
| ItemCard | Original artwork, text, Use and Redraw actions | Credentials |
| AudioManager | Music, SFX, volume, mute | Gameplay success |

Suggested folders, to create only when needed:

```text
project.godot
SPEC.md
README.md
AGENTS.md
scenes/             # World, player, encounters, canvas, and UI
scripts/            # GDScript implementation
data/               # Encounter definitions and supported tags
assets/
  art/
  audio/music/
  audio/sfx/
CREDITS.md          # Asset attribution and team credits
```

Decide the server code location after selecting the hosting approach. Fixed responses may unblock early integration, but must be marked as test mode and replaced with a real call in the Day 1 vertical slice.

### Web acceptance environment

- Verify the actual HTTPS deployment, not only F5 inside Godot.
- Open it on another team member's device to expose local-path or developer-session dependencies.
- Initial primary acceptance browser: desktop Chrome. Perform a basic Safari smoke check and record differences.
- If the competition mandates a browser or embedded player, test that exact environment as well.
- Verify movement keys, focus changes, canvas coordinates after resizing, upload behavior, and route collisions.
- Confirm endpoint origin and cross-origin configuration for the final URL.
- Confirm audio after Start, independent volumes, mute/unmute, long looping, and tab changes.
- Keep test modes, internal errors, and secrets out of the public player experience.
- Record download size and initial load time early. Simplify art and audio when later builds regress noticeably.
- Aim for at least 30 FPS during walking on an agreed team laptop, then document its browser/device and observed result. No universal performance guarantee is implied.
- A demo recording is useful backup material, not a replacement for a playable Web build.

## 12. Team responsibilities and collaboration

| Role | Primary ownership | Earliest deliverable |
|---|---|---|
| Developer A | Player, camera, world, encounters, progression, integration, audio playback | Walk to a graybox encounter and solve it with a fixed item |
| Developer B | Drawing UI, AI client/server, reliability, Web export/deployment | An actual drawing becomes validated item data in a hosted build |
| Designer A | Art direction, player/NPC appearance, environment and UI assets | Player/otter placeholders and one import-ready encounter style |
| Designer B | Encounter design, English copy, audio sourcing, playtest coordination | Tutorial flow, solution matrix, BGM/SFX samples and source records |

- These are role proposals, not named assignments. Confirm owners at kickoff.
- Developer A is the proposed integration owner; designate a final submission owner separately.
- Both developers agree on input/output contracts and error cases before separating implementation work.
- Assign each shared `.tscn` to one primary editor. Compose independent scenes instead of editing the main scene simultaneously.
- Integrate at least twice daily. Keep the main branch runnable and temporary placeholders explicit.
- Pull before work, use short-lived branches, and include a verification note when handing off changes.
- Godot can save scenes/settings while external tools edit them. Coordinate file ownership, inspect reload prompts, and do not overwrite a teammate's changes.
- Each board ticket needs an owner, priority, dependencies, and an observable completion condition.

## 13. Four-day schedule and scope control

| Day | Main work | Exit condition |
|---|---|---|
| Day 1 | Rules/access, Web export, graybox movement, one encounter, drawing, real AI, initial audio | Hosted build supports walk -> interact -> draw -> interpret -> original item -> use -> solve; BGM and one result SFX work after Start |
| Day 2 | All encounters, route progression, otter payoff, ending, recovery, audio controls | Playable beginning to end with two routes per encounter; failure and timeout cannot block completion |
| Day 3 | Final art, movement presentation, full sound set, copy, outside playtests | Assets and audio integrated; onboarding and blocking issues corrected; remaining limits recorded |
| Day 4 | Feature freeze, target-environment regression, credits, submission and backup | Final URL works on a teammate device; submission package is complete |

### Decision gates

- Early Day 1: verify competition rules, submission method, shared version, API access, and a minimal Web export. Do not spend the whole first day creating final art.
- End of Day 1: if the vertical slice does not work, stop expanding content. Resolve movement/input/network/export first; simplify scenery and camera behavior.
- End of Day 2: if no complete playthrough exists, shorten the finale and its result sequence to reach an ending.
- Free walking, English content, and essential audio are user requirements. Do not remove them without an explicit scope decision.

### Cut order

Remove optional second music/ambience, extra scenery/camera polish, extra solution routes beyond two, and long finale sequences before cutting core mechanics.

Reduce world area and simplify the player representation before sacrificing walking. A move from 3D to a 2D walkable layout is a possible team-approved fallback, not an automatic change.

If three encounters still cannot fit, explicitly revise the scope to two and update this document, tickets, and acceptance criteria. Do not count an unfinished third encounter as delivered.

Keep original-art objects, clear outcomes, recovery, baseline sound, a real ending, and Web verification.

## 14. Backlog ready for tickets

These are proposed tasks, not issues already created on GitHub.

| ID | Priority | Task | Owner | Dependencies | Acceptance |
|---|---|---|---|---|---|
| T01 | P0 | Confirm rules, version, team permissions, and API owner | Team | None | Teammate can run the starter; constraints and responsible owners recorded |
| T02 | P0 | Minimal Web export and deployment | Dev B | T01 | Title opens on a second device |
| T03 | P0 | Graybox movement, camera, collision, and interaction | Dev A | T01 | Walk to one target, see prompt, enter/exit a panel without input problems |
| T04 | P0 | Canvas and PNG snapshot | Dev B | T01 | Draw/undo/clear/submit work; empty input does not send |
| T05 | P0 | Real AI endpoint and validation | Dev B | T01, T04 | Actual sketches return allowed tags; invalid output is recoverable |
| T06 | P0 | Original-art item and first encounter integration | Dev A + Dev B | T02, T03, T05 | Hosted vertical slice solves one encounter with a real drawing |
| T07 | P0 | Art conventions, player and tutorial assets | Designer A | T03 | Scale, pivots, facing, idle/moving look, and import format agreed |
| T08 | P0 | Finalize encounter and route designs | Designer B | T03 | Each has a problem, two routes, hints, visible gate, and completion rule |
| T09 | P0 | Audio samples and source records | Designer B | T01 | BGM and seven SFX event categories have suitable source plans |
| T10 | P0 | Audio manager and browser playback | Dev A | T02, T09 | Start, looping, walking/pencil cadence, volumes, mute, and restart verified |
| T11 | P0 | Remaining encounters, safe crossings, otter payoff, ending | Dev A | T06, T08 | All three encounters complete; routes unlock once and remain traversable |
| T12 | P0 | Timeout, cancellation, server limits, and manual mode | Dev B | T05, T06 | Offline, late reply, repeated click, and rate-limit cases recover |
| T13 | P0 | Final art, text, and sound integration | Designers + Dev A | T07–T11 | Required placeholders replaced and sound events connected |
| T14 | P0 | Outside playtests and browser regression | Designer B coordinates | T11–T13 | Section 15 has recorded results; blockers fixed |
| T15 | P0 | Credits, README, submission and backup | Assigned submission owner | T14 | Final playable URL and materials ready |

## 15. Acceptance and playtesting

### Functional checks

| Case | Expected result |
|---|---|
| First visit and Start | Controls and tutorial are clear; sound can start without login |
| WASD/arrows and diagonal movement | Consistent movement, no diagonal speed boost, readable camera |
| Walls, water edge, map boundaries | Player cannot bypass gates or become trapped outside the world |
| Approach/leave an NPC | One relevant prompt appears and clears at the right range |
| Open/close panels while holding movement | Character stops during panels and does not resume from stale input |
| First real drawing | Original artwork and validated interpretation become a usable item |
| Empty drawing | No network call; useful feedback |
| Release pointer outside canvas | Stroke ends correctly; other controls remain usable |
| Undo, clear, and reopen canvas | Draft behavior matches Section 7; progress is unchanged |
| Two valid routes in each encounter | At least six successful routes have understandable outcomes |
| Unrelated recognized item | Contextual retry message, no resource penalty |
| Unknown tags or oversized generated text | Invalid data is rejected or handled by the agreed contract without breaking UI |
| Uncertain recognition | Redraw or clearly labeled purpose selection is available |
| Timeout, offline, 429, or provider error | Waiting ends; retry/manual mode remains available |
| Cancel/restart followed by late response | Old data cannot replace current state or advance the game |
| Rapid Submit or Use clicks | One pending request and one resolution; no duplicate effects |
| Revisit solved encounter | Progress stays solved; rewards/sequences do not repeat |
| Both final crossing routes | Safe destination, working collision, reachable summit |
| Ending and restart | Complete ending; restart resets world, item, draft, and request context |
| Muted playthrough | All required information remains understandable; SOUND tags still work |
| Two BGM loops, sustained drawing, rapid clicks | No obvious seam, duplicate music, clipping from piled-up sounds, or SFX spam |
| Walk, stop, push against wall, open panel | Footsteps reflect actual movement and stop correctly |
| Music/SFX volumes and mute/unmute | Independent levels and previous settings are respected |
| Hide tab, return, and restart | No duplicate music or unwanted unmuting; no stuck movement |
| Two target window sizes | Readable text, accessible controls, correct drawing coordinates |
| Final URL on teammate device | Movement, drawing, AI, audio, and complete playthrough work |

### Outside-player goals

Test with at least two people who did not build the game. Let them begin without a developer explaining it. Record:

- Can they understand walking and find the first interaction in the opening minute?
- Can they reach the first drawing and first successful outcome without coaching?
- Is confusion caused by input, recognition, rules, wayfinding, or wording?
- Do they recognize their artwork in the object and its use?
- Is a reasonable drawing rejected without a satisfying explanation?
- Does at least one outcome create a moment of surprise or delight?
- Are walking and exploration pleasant rather than empty travel?
- Does the music remain comfortable, are footsteps/pencil sounds restrained, and is mute easy to find?
- Does a complete first session roughly fit 5–10 minutes?

These are design targets. Record actual results and never mark untested behavior as passed.

### Definition of done

A task is done when it is integrated, checked in the relevant target environment, has no blocking failure, and includes its required text, visual feedback, and sound hooks.

The game is done when P0 passes or an explicit scope revision has been recorded, the final deployment is playable, and credits, limitations, and submission materials are complete.

## 16. Open decisions

| Question | Current proposal | Decide by |
|---|---|---|
| Exact competition start/end and rules | Not supplied | Before scheduling competition work or assuming pre-work is allowed |
| Required submission format, browser, and online AI availability | Web expected; desktop Chrome proposed | Early Day 1 |
| Camera angle and player appearance | Fixed-angle 3D trail; simple illustrated or low-detail character | Before final art production |
| Use the three encounter stories in Section 6? | Otter bag, crow sign, broken crossing | After the first prototype playtest |
| Location and story flavor | Fictional mountain trail; Fuji-inspired scenery optional | Before final environment art |
| Audio references and asset sources | Warm, comforting, slightly playful instrumental music | Before final audio selection |
| AI provider/model, account owner, and spending cap | Not selected | Before real integration and public access |
| Named owners and final submission owner | Role split in Section 12 | Kickoff |

## 17. References and changes

- [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): rendering, export, browser networking, and audio constraints. Recheck against the team's installed version during implementation.
- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): starting point for script-controlled movement and collision.
- [Godot InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html): named input actions.
- [Repository](https://github.com/AdeDeepFishing/Paws-Peaks)
- [Four Otters - Dev Board](https://github.com/users/AdeDeepFishing/projects/1/views/1)

This file is the shared scope reference. Update it when the team resolves open choices or changes scope. A new feature needs an owner, an acceptance condition, and an explicit explanation of what it displaces within four days.

| Version | Date | Change |
|---|---|---|
| 0.1 | 2026-09-12 | Initial English specification; confirmed free walking, English-only project content, and warm/playful audio; encounter stories and camera details remain proposals |
