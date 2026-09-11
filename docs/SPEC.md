# Paws & Peaks — Game Jam Specification

> Version: 0.2 | Updated: 2026-09-12 | Status: Working draft
>
> Team: Four Otters — two designers and two developers, all new to Godot.
> Delivery window: four competition days. Day 1–4 below are relative milestones, not calendar dates.
> This document specifies planned work. It does not claim that these features already exist.

## Table of contents

1. [Product vision](#1-product-vision)
2. [Decisions and current status](#2-decisions-and-current-status)
3. [Release scope](#3-release-scope)
4. [Exploration, traversal, camera, and coins](#4-exploration-traversal-camera-and-coins)
5. [Player flow and asynchronous state](#5-player-flow-and-asynchronous-state)
6. [Encounter content proposals](#6-encounter-content-proposals)
7. [Drawing and object presentation](#7-drawing-and-object-presentation)
8. [AI contract and reliability](#8-ai-contract-and-reliability)
9. [Art, interface, and asset delivery](#9-art-interface-and-asset-delivery)
10. [Music, effects, narration, and dialogue](#10-music-effects-narration-and-dialogue)
11. [Technical structure and Web delivery](#11-technical-structure-and-web-delivery)
12. [Team responsibilities and collaboration](#12-team-responsibilities-and-collaboration)
13. [Four-day schedule and scope control](#13-four-day-schedule-and-scope-control)
14. [Backlog ready for tickets](#14-backlog-ready-for-tickets)
15. [Acceptance and playtesting](#15-acceptance-and-playtesting)
16. [Open decisions](#16-open-decisions)
17. [Reuse strategy and researched candidates](#17-reuse-strategy-and-researched-candidates)
18. [References and changes](#18-references-and-changes)

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
5. Keep trying inexpensive. Coins reward exploration; a lack of coins or an exhausted item must never block the next essential drawing.
6. Combine open expression with finite mechanics. The player draws freely; the game executes a small set of implemented effects.
7. Let the player explore. Walking through the world and approaching problems are part of the experience.
8. Make music, sound effects, English narration, and dialogue part of the experience.
9. Keep AI processing non-blocking. Players can explore and collect coins while a submitted drawing is being analyzed.

### Audience and session

- First-time judges and casual players; no drawing or game expertise required.
- Target main-path playthrough: approximately 5–10 minutes; optional coin exploration may extend this. Check both with actual playtests.
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
| Movement abilities | Requested | Walking, jumping, sprinting, physics pushing, and climbing; bounded implementations in Section 4 |
| Camera and input details | Proposed | WASD/arrows, Space, Shift, mouse-controlled camera/UI; designated climb points and small pushable crates |
| Coins and AI waiting | Requested | Collect along routes and in nearby activity areas while AI runs in the background |
| Coin spending | Open | Default proposal: collection count and an ending reward; essential drawings stay free |
| Language | Confirmed | English throughout the game and repository |
| Audio mood | Confirmed | Warm, comforting, and slightly playful |
| Background music and SFX | Confirmed | Required, with player volume controls |
| Narration and dialogue | Confirmed correction | English spoken narration and key NPC dialogue, with English subtitles |
| Voice production | Available option | User has an ElevenLabs subscription; proposed pre-generated audio, with exact voice/plan/credits still to verify |
| AI item fields | Required | Type, Attack power, Range, Speed, Durability, plus identification and encounter-effect tags |
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
| F02 | Traversal | Walk, jump, sprint, mouse camera, one bounded pushable-crate interaction, and a designated climb route |
| F03 | Proximity interaction | Approach an encounter, see a prompt, and interact with one clear target |
| F04 | Drawing canvas | One pen, undo last stroke, clear, submit, and back |
| F05 | Real AI interpretation | Analyze actual drawings and return validated type, attack_power, range, speed, durability, name, description, and tags |
| F06 | Original-art object | Original sketch, interpretation, a readable stat card, and visible use feedback |
| F07 | Three short encounters | Tutorial, middle encounter, and finale; at least two supported routes per encounter |
| F08 | Otter | Tutorial guidance and one visible contribution in the finale |
| F09 | Recovery | Invalid objects, uncertainty, timeout, network failure, and repeated input cannot soft-lock play |
| F10 | Audio and voice | Looping BGM, essential SFX, narrated story beats, key NPC dialogue, subtitles, global mute, and Music/SFX/Voice volume |
| F11 | Web delivery | Hosted build supports movement, drawing, requests, sound, and a complete playthrough |
| F12 | Readability | Legible text, clear interaction prompts, and visual/text equivalents for necessary audio information |
| F13 | Submission package | Playable link, run instructions, asset/code credits, known limitations, and demonstration backup |
| F14 | Coins | Route and nearby activity pickups, session counter, one-time collection, and ending tally |
| F15 | Background interpretation | Move and collect during processing; receive a non-modal ready/error notification and inspect when safe |

### P1 — Only after P0 works end to end

- A second music track, nature ambience, and distinctive animal or item sounds.
- Extra solution routes, richer descriptions, and more object-specific feedback.
- Additional camera transitions, reveal effects, and small environmental details.
- A closing gallery of player drawings.
- Simple confrontation actions that reuse existing effects.
- A few optional scenic inspection points with short text and no new quest system.

### Out of scope

- Arbitrary sketch-to-3D mesh generation, rigging, generated collision, or unique generated mechanics.
- A large open world, unrestricted wall climbing, advanced parkour, swimming controls, moving-platform puzzles, or arbitrary physics construction. Basic jump/sprint, limited mouse orbit, designated climbing, and bounded crate pushing are included.
- A full real-time combat framework, equipment progression, or deep weapon balancing. Required item statistics are included; they do not imply a complete combat system.
- Mandatory paid drawing attempts, a full shop/trading system, and a crafting economy. Collectible coins are included; optional spending remains a separate decision.
- Multiplayer, accounts, leaderboards, cloud saves, and mandatory persistent progress.
- Free-form NPC chat, player voice input, runtime music generation, and mandatory runtime speech synthesis of every generated item. Pre-generated narration and key NPC dialogue are included.
- Pet progression, a general companion navigation system, or dynamically simulated bridges and water.

## 4. Exploration, traversal, camera, and coins

**Free exploration, coin collection, and something to do during AI processing are baseline requirements.** The requested traversal abilities are included as small, testable implementations rather than an unrestricted parkour system.

### World layout

- One compact 3D trail with three ordered encounter zones and a summit destination. Previously opened areas remain accessible.
- Place coins along the route between encounters and in optional pockets near each drawing interaction.
- Each processing area offers a short loop: a few ground coins, a low jump ledge, or a reusable traversal toy. Players can start exploring immediately after submission.
- Place at least one small pushable crate and one marked climb route in the game. These are optional coin detours, so controller problems cannot block the main drawing path.
- Keep the main route readable through landmarks, NPC placement, and visible gates; do not require a minimap.
- Keep main-route travel short, initially about 10–20 seconds between encounters. Optional detours should be nearby, not lengthy distractions from the result.
- Route gates must remain effective against sprint-jumps and crate-assisted jumps. Validate maximum reach when setting their geometry.
- Use static authored scenery and simple collision. No generated terrain, physical bridge simulation, or mandatory precision platforming.

### Controls proposal

| Action | Input | Behavior |
|---|---|---|
| Move | WASD or arrow keys | Camera-relative ground movement |
| Jump | Space | One reliable grounded jump; no double jump required |
| Sprint | Hold Shift while moving | Fixed faster speed; no stamina meter |
| Camera | Hold right mouse button and drag | Limited third-person orbit; clamp pitch and keep the player visible |
| Interact | E near a highlighted target, or click its in-range prompt | Open the relevant encounter or climb interaction |
| Push crate | Walk into a marked small crate | Apply bounded force; do not push every scenery object |
| Climb | E at a marked ladder/vine, then W/S | Follow the authored climb route; E exits at a safe location |
| Draw and UI | Left mouse button | Buttons and canvas strokes; UI consumes clicks before world interactions |
| Inspect result | I or click the ready notification | Open the item card when not mid-jump, climbing, or in another modal |
| Back / cancel | Visible button; Escape shortcut | Close the current UI; canceling an AI request is a separate explicit action |
| Sound | Visible sound button | Music, SFX, Voice, and global mute |

WASD/arrows move the character; mouse input controls the camera, interactions, and drawing. Click-to-move pathfinding is not implied by mouse support and remains optional.

### Traversal acceptance boundaries

- Use named input actions. Normalize diagonal input and release movement/camera input when focus is lost or a modal opens.
- Jump and sprint should be forgiving; optional short input buffering/coyote time may be reused from a controller but must be verified.
- Camera dragging cannot draw on the canvas. Keep the cursor available for UI; permanent pointer lock is not required. Disable the browser context menu within the game surface if it conflicts with right-drag controls.
- Pushable crates have limited mass/force, simple collision, and a bounded area. Reset displaced crates to an authored position when needed; prevent launches, gate bypasses, and permanent blockage.
- Climbing means designated ladders/vines with safe entry and exit. Arbitrary mountain-wall climbing is not assumed and remains a question for the user.
- Falling or becoming stuck returns the player to a safe checkpoint, preserving collected coins, solved encounters, and the active AI request. Do not reload the entire scene or restart the network call.
- The otter can appear at scripted locations; a companion navigation system is not required.

### Coin rules

- Working name: Coins. Use original artwork/audio or properly licensed assets; Mario is a reference for the collection feel, not an asset source.
- Each coin has a stable ID and can be collected once per session. Pickup increments a visible counter and triggers brief visual and audio feedback.
- Proposed initial layout: 24 coins across the three zones, roughly five on each route and three in a nearby optional pocket. Counts are tuning values, not a content promise before grayboxing.
- Coins are present regardless of whether AI is processing. Do not spawn rewards only after submitting or respawn them when a request retries.
- Default proposal pending user feedback: use coins for a completion tally and an ending badge/message. No mandatory drawing fee, no loss on failed recognition, no lives system, and no hard coin gate.
- If spending is later chosen, basic drawings remain free; spending may buy optional cosmetic or bonus opportunities. That economy requires an explicit update before implementation.
- Canceling, timing out, receiving a result, and respawning do not erase collected coins. Full New Game resets them.
- Once nearby coins are collected, players can still traverse or revisit the crate/climb interaction. Coins are a pleasant activity, not a substitute for latency reduction or failure recovery.
- Never delay an already-ready AI result to make the player finish collecting coins. Coin detours remain available afterward.

## 5. Player flow and asynchronous state

```text
Start -> Narration -> Explore / collect -> Approach NPC -> Dialogue -> Draw
                                                                         |
                                                                       Submit
                                                                         |
                                             +---------------------------+--------------------+
                                             |                                                |
                                   AI analyzes snapshot                           Player explores / collects
                                             |                                                |
                                      Ready or failed ----------------> Non-modal HUD notification
                                                                                              |
                                                                              Inspect when safe; return to target
                                                                                              |
                                                                                Use -> Outcome -> Route opens
                                                                                              |
                                                                                Explore next zone -> Summit
```

### Two independent state systems

The previous blocking INTERPRETING game state is removed. **A pending network request is independent of character exploration.**

| Player/UI state | Behavior |
|---|---|
| EXPLORING | Walk, jump, sprint, collect, push, climb, and inspect scenery |
| DIALOGUE / OBSERVING | Read/listen to encounter dialogue; open drawing or return |
| DRAWING | Edit a draft; movement and camera input are suspended |
| ITEM_VIEW | Read artwork, interpretation, and stats; close, redraw, or use if near the correct target |
| RESOLVING | Watch a short authored result; player movement is temporarily suspended |
| ENDING | Read/listen to conclusion, see coin tally, view credits, or restart |

| Request state | Behavior |
|---|---|
| IDLE | A valid drawing may be submitted |
| PENDING | Analyze the captured image; show a small status indicator while normal exploration continues |
| READY | Keep the item stored for its originating encounter; show a persistent notification |
| FAILED / UNCERTAIN | Keep exploration enabled; show retry or manual-purpose options |
| CANCELED | Ignore late delivery; allow a new deliberate submission |

### Required synchronization rules

- Submitting captures the image and originating encounter, closes the canvas, and returns player control after a brief acknowledgement. Drawing and modal dialogue still pause movement; AI processing does not.
- Keep only one AI request pending. A second encounter or redraw cannot silently replace it; explain the pending request and offer explicit cancel if needed.
- Bind each request to a request ID, originating encounter ID, and local session generation. Store request state outside transient encounter UI nodes.
- Walking into a previously solved area is not cancellation. The response belongs to its original encounter even if the player is elsewhere when it arrives.
- A result never teleports the player, opens a blocking panel, starts a cutscene, or steals the camera. Show a small ready message and a short cue.
- Queue an Inspect action until the player is grounded and outside climbing/other modal states. The notification remains available until handled.
- Inspecting is allowed away from the encounter. Applying the item requires returning to its originating unsolved target and being within interaction range; otherwise disable Use and explain where to return.
- If a voice line is already playing, defer or soften the ready cue and avoid a second simultaneous spoken announcement.
- Cancel/restart invalidates old results. Check the session/request identity on every completion. A local fall/respawn preserves the same identity.
- A valid new item replaces the old item only for the same active encounter. Failed requests do not delete an existing usable item.
- Closing and reopening the drawing panel preserves its draft. Canceling a UI panel is distinct from canceling a submitted request.
- Solved encounters and coin IDs persist throughout the session. Full restart resets progress, items, drafts, coins, pending context, and one-shot dialogue flags.
- Keep an upper bound on waiting even while the player is occupied. Re-evaluate deadlines when the browser regains focus; hidden-tab suspension must not leave a request pending indefinitely.
- No required persistent save in this release. Refresh may restart the session; record that limitation in the README.

## 6. Encounter content proposals

**These scenarios make the scope concrete; they are not yet final story decisions. Replacements should preserve three short encounters, reusable effects, and two routes per encounter.**

### E01 — The otter's drifting bag

- Situation: the otter's bag has drifted into a shallow stream beyond reach from the bank.
- Introduction: the player walks to the otter, hears a short subtitled exchange, and follows a prompt to open the drawing canvas. After submitting, a nearby coin loop introduces background processing without requiring a detour.
- Route A: draw a long pole or long-handled net; `LONG_REACH` with validated `range >= 2.0` retrieves the bag. The bag is staged about two world units from the interaction point; this threshold is a tuning proposal.
- Route B: draw a raft or flotation board; `FLOATS` supports a preset sequence in which the otter retrieves the bag.
- Outcome: the otter thanks the player and promises to help later. Set `otter_helped = true` and open the onward route.
- Level dressing must explain why the onward route is initially unavailable; its exact obstacle is a design task.
- Acceptance: a new player completes a real drawing-to-outcome loop, can move and collect during processing, and understands both solution routes. Narration/dialogue can be skipped without skipping required game state.

### E02 — The crow and the missing direction

- Situation: a crow has taken the arrow from the trail sign and refuses to leave its perch.
- Route A: `FOOD` lures the crow away.
- Route B: `SOUND` uses a bell, drum, or similar object to attract its attention elsewhere.
- Outcome: the sign is restored and the route forward becomes accessible; a coin trail guides the next walk. A short subtitle/voice cue acknowledges the solution.
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
- Ending: a warm narrated exchange at the summit, followed by completion text, collected-coin tally, credits, and restart.
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

- Show the original sketch, a short English name, a one-sentence interpretation, Type, Attack power, Range, Speed, Durability, Use, and Draw again. Mark combat-only fields as informational where no matching action exists; do not imply every item can attack.
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

- AI: analyze the drawing and propose an object type, attack power, range, speed, durability, name, short interpretation, and allowed effect tags.
- Server: call the provider, validate and normalize all fields into game-approved ranges and type budgets, enforce request limits, and protect credentials.
- Godot: own game state, validate usable data, evaluate encounter rules, and execute predefined effects.

The model proposes bounded item statistics; it cannot directly apply damage, declare victory, execute scripts, choose resource paths/filenames, or select the next scene. Text drawn inside an image is input content, not authority to override application rules.

### Proposed endpoint

Both developers must agree on this contract before implementing their respective sides. The provider and model remain open.

`POST /api/interpret-drawing`

```json
{
  "schema_version": 2,
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
  "schema_version": 2,
  "request_id": "unique-request-id",
  "status": "recognized",
  "item": {
    "name": "A sturdy plank",
    "description": "A long wooden board that looks strong enough to support you.",
    "type": "TOOL",
    "attack_power": 8,
    "range": 3.0,
    "speed": 0.8,
    "durability": 5,
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
  "schema_version": 2,
  "request_id": "unique-request-id",
  "error": {
    "code": "SERVICE_UNAVAILABLE"
  }
}
```

- Minimum error codes: INVALID_INPUT, RATE_LIMITED, SERVICE_UNAVAILABLE, INVALID_MODEL_OUTPUT.
- Proposed HTTP mapping: 400/413 for invalid input, 429 for limits, 502/503 for provider or output failures. Final mapping must be agreed during integration.
- The client uses local English error messages instead of displaying provider errors or stack traces.

### Required item fields and units

Use lowercase snake_case JSON keys; the UI uses the human-readable labels requested by the team. All five fields are mandatory for every recognized item, including FOOD, ANIMAL, and UNKNOWN types.

| UI label | JSON key | Proposed domain | Meaning |
|---|---|---|---|
| Type | `type` | SWORD, HAMMER, SPEAR, SHIELD, BOW, MAGIC, TOOL, FOOD, ANIMAL, UNKNOWN | Closest primary object category; mixed capabilities belong in tags |
| Attack power | `attack_power` | Integer 0–100 | Potential strength for an implemented attack/break action; zero is valid for a non-attacking item |
| Range | `range` | Finite number 0–8 | Maximum effective reach in world units; world scale convention is one unit approximately one meter |
| Speed | `speed` | Finite number 0.5–2.0 | Item-action speed multiplier relative to a base action of 1.0; not the player's walking/sprint speed |
| Durability | `durability` | Integer 1–10 | Maximum successful uses; client tracks remaining uses separately |

- These are initial balancing bounds, not measurements recovered reliably from a drawing. Final per-type budgets are a Day 1 design task.
- Require correct data types; reject missing fields, invalid enum values, NaN/infinite values, and malformed output. Normalize finite numeric proposals to approved global and per-type bounds before sending the accepted response to Godot.
- Godot checks the same contract and displays only the accepted numbers. No raw model output directly changes the game.
- UNKNOWN is an item type; OTHER is an exclusive effect tag. They are different fields. Uncertain recognition still returns `item: null` rather than inventing an item.
- Type is not a winning-answer lookup. Keep effect tags because FOOD versus ANIMAL, or MAGIC versus SWORD, can overlap semantically.
- P0 includes all stats in real AI output, validation, and the item card. E01's reach solution demonstrates `range`; `speed` can adjust an implemented use sequence within a comfortable duration; `durability` decrements only after a successful use commits once.
- Failed attempts, inspection, drawing, network errors, and canceled actions never spend durability. An exhausted item can always be replaced with a free basic drawing; no progression soft-lock.
- Attack power is informational until an explicit attack/break action is implemented. Do not build an entire combat system merely to consume that field. Any later action must use a pre-authored behavior and damage budget.
- Do not derive an overall Power Score yet. Keep each field interpretable and avoid rewarding unrealistic text written into the sketch.
- Manual mode creates items through the same type/stat templates and tag rules, with clear manual provenance; it must not return an incompatible object shape.

### Waiting, cancellation, and fallback

- Initial experience target: normal interpretation within 8 seconds. Measure it; it is not a provider guarantee. The game must already be playable during this interval.
- Initial client timeout: 15 seconds, then show a non-modal failure notification with retry/manual options. Movement and collection remain available before and after timeout.
- No infinite automatic retries. A retry is a deliberate click; repeated failure makes fallback prominent.
- Disable repeated submission while waiting, not player movement. Ignore canceled/obsolete replies while preserving valid replies received after ordinary exploration.
- Client cancellation does not guarantee the provider stopped processing or charging.
- Manual mode allows players to select a supported purpose and uses the same encounter rules. Label it “Manual mode” or equivalent; never imply AI recognized the image.
- Fallback must allow completion, but it cannot count as proof that the real AI integration works. Do not artificially extend processing to match a coin route or a voice clip.

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
- Establish character scale, ground contact point, facing convention, and idle/run/jump/climb appearance before final assets. Reuse suitable controller animations and allow simple pose changes to keep production bounded.

### Required interface

- Title: game name, Start, controls preview, sound control, and Credits.
- World: proximity prompt, current objective, coin counter, non-modal AI pending/ready/error status, and sound control.
- Encounter panel: problem, Draw, current item if available, and Back.
- Canvas: drawing area, Undo, Clear, Submit, and Back/Cancel.
- Item card: sketch, name, interpretation, five required item fields, Use, and Draw again.
- Feedback: outcome and the next available action.
- Ending: narrated completion, coin tally, Restart, and Credits.
- Sound panel: Music, SFX, and Voice sliders, plus global mute; retain values during the session. English subtitles remain available when Voice is muted.

### Asset requirements

- Agree on aspect ratio, export dimensions, naming, and pivots before batch production.
- Initial layout target: 16:9; also check usability in 1280 × 720 and 1440 × 900 browser windows.
- Use placeholders first. Gameplay must not depend on final texture dimensions.
- Prefer transparent PNGs for illustrated characters and props. Use real English UI text rather than text baked into images.
- Example names: `otter_idle.png`, `crow_perched.png`, `bg_stream.png`.
- Use a small set of character poses before considering full animation sets.
- Record asset author, source, license or usage basis, and required attribution for images, fonts, and audio in a future `docs/CREDITS.md` (repository-relative path).
- Check competition rules for AI-generated and pre-existing assets and disclose their use when required.

## 10. Music, effects, narration, and dialogue

**Background music, SFX, spoken narration, and key NPC dialogue are P0.** The mood is warm, comforting, and slightly playful. All spoken and written content is English.

### Voice production plan

- The user has an ElevenLabs subscription and can arrange voice production. Verify the selected voice, available credits, and intended usage for that account before generation; this document does not claim access or consume credits.
- Create the approved script first, then pre-generate short audio files and include them as game assets. Runtime requests are for sketch analysis, not mandatory speech generation.
- Start with one narrator and one otter voice; the same narrator may cover other animals. Extra character voices are optional polish.
- Proposed voice budget: 12–16 short clips, usually one or two sentences each, with approximately 60–90 seconds of speech across the main route. Calibrate after script approval.
- Required coverage: opening narration, otter introduction, drawing instructions, one line explaining background processing, encounter introductions, short success responses, otter's finale help, and the ending.
- Random AI item names and descriptions remain English text in P0. Fixed voice lines must avoid claiming an exact generated object name that the audio cannot know.
- Deliver a line manifest with stable line ID, speaker, exact English subtitle, audio path, measured duration, trigger, priority, and replay policy. Suggested file names: `narrator_intro_01.ogg`, `otter_draw_01.ogg`.
- Exported source audio can be downloaded from ElevenLabs and converted if required for the chosen Godot pipeline. Listen to the actual import and Web playback; do not assume a subscription alone provides every voice or format.

### Voice and subtitle behavior

- Subtitles are enabled by default, show the speaker, and match the recorded line exactly. No essential information is audio-only.
- Introductory NPC conversations can be modal; environmental narration and the processing acknowledgement should allow movement when safe.
- Provide Next/Skip for dialogue. Skipping stops the current clip and advances exactly once without bypassing a required gameplay condition.
- Use actual audio duration or a playback-finished signal. If audio is absent or muted, allow manual advance and use a readable text duration if auto-advance is enabled.
- Prevent overlapping spoken lines. Important dialogue takes priority; queue or drop stale ambient comments instead of playing them much later out of context.
- When an AI result arrives during narration, retain a visual notification and a restrained cue; it must not cut off the current line or force a modal.
- Lower Music while Voice plays, then restore the player's chosen level. Use explicit volume changes that are verified in the Web build rather than depending on untested bus effects.
- One-shot lines do not replay on every proximity trigger. Revisit lines, if present, are short and have a cooldown.
- Full restart clears story flags. Local fall/respawn does not restart narration or lose a pending result.

### Minimum audio events

| Asset or event | Priority | Trigger and purpose | Acceptance |
|---|---|---|---|
| `bgm_journey` | P0 | Approximately 60–90 second instrumental loop | Two loops without a noticeable seam, volume jump, or duplicate player |
| `voice_story` | P0 | Narrator and key NPC lines from the approved manifest | Subtitled, skippable, never unintentionally overlapping |
| `sfx_ui_confirm` | P0 | Main button actions | No hover or pointer-motion spam |
| `sfx_footstep` | P0 | Actual grounded movement | Controlled cadence; stops when blocked, airborne, or in a modal |
| `sfx_pencil` | P0 | Drawing a stroke | Once per stroke or one controlled loop, never new playback per frame |
| `sfx_item_reveal` | P0 | Inspect a finished drawing's item | Short, once per reveal |
| `sfx_item_use` | P0 | Apply an item | Shared sound is sufficient initially |
| `sfx_success` | P0 | Encounter success or ending | Matches the visual outcome |
| `sfx_try_again` | P0 | Unsuitable object or recoverable input | Gentle and brief |
| `sfx_coin_pickup` | P0 | First collection of a coin ID | Responsive; rapid pickups have bounded voices/volume |
| `sfx_jump_land` | P0 | Takeoff/landing | No ground-contact jitter retrigger; reuse a suitable sound if needed |
| `sfx_ai_ready` | P0 | Background analysis completes | One restrained cue; does not interrupt Voice |
| `ambience_nature` | P1 | Wind, water, birds | Quiet and consistent with mute controls |
| `bgm_finale` | P1 | Additional finale/summit track | Clean transition, no unintended overlap |
| Distinct push/climb/animal sounds | P1 | Extra traversal and character feedback | Add only after core sound works |

Minimum delivery: **one BGM track, ten SFX event categories, and the agreed narration/dialogue clips**. Events may share source files; unique recordings for every event are not required.

### Playback and delivery requirements

- Start audio from the player's Start click to satisfy browser interaction requirements.
- Use a shared AudioManager with Master, Music, SFX, and Voice. Keep individual sliders and a visible global mute; subtitles stay usable while muted.
- Keep BGM continuous across panels, asynchronous requests, and encounter transitions.
- Limit SFX voices and tune levels by listening: footsteps/pencil remain subtle, pickups pleasant, dialogue intelligible.
- Tab hide/show should suspend/resume once, respect mute, and avoid duplicate music or stale queued voice.
- Audio failure must not block collection, dialogue progression, or encounter completion.
- Prefer compressed music/voice and suitable short effect files; test loop points, import formats, leading/trailing silence, and perceived loudness in the Web build.
- Record source, author/voice, usage basis, and required attribution for every external or generated asset in `docs/CREDITS.md` (repository-relative path).
- No voice cloning or additional voice service integration is required for this release.

## 11. Technical structure and Web delivery

### Implementation approach

- Godot 4.7.2 Standard and GDScript, with a shared engine version across the team.
- Compatibility rendering and an initial single-threaded Web export.
- A small 3D world with bounded jump/sprint, limited mouse camera, a small pushable crate, and a designated climb route; drawing remains a separate 2D UI.
- Reuse one suitable CharacterBody3D-based controller/starter after a compatibility spike. Validate movement, coins, camera, and respawn in a graybox; do not combine several complete controller frameworks.
- Godot owns the game. A lightweight server endpoint owns the model call.
- Vercel is a deployment candidate; verify hosting configuration, function limits, payload sizes, timeouts, and credits before choosing it.
- Keep exported builds and `.godot/` cache out of source commits.

### Suggested modules

| Module | Owns | Does not own |
|---|---|---|
| Main / GameFlow | Active encounter, progress, restart, ending, session generation | Provider prompts |
| PlayerController | Walk/jump/sprint, camera input, bounded push/climb, safe respawn, modal movement locks | Encounter solutions |
| InteractionController | Nearby target and interaction prompt | Model calls |
| DrawingCanvas | Strokes, undo, clear, PNG snapshot | Correct-answer rules |
| AIClient / RequestManager | Background lifecycle, originating encounter, timeout, errors, full stat validation, ready notification | Movement locks or scene progression |
| EncounterController | Tag rules, result sequence, route unlocking | Generated code execution |
| ItemCard | Original artwork, text, Use and Redraw actions | Credentials |
| AudioManager | Music, SFX, Voice, mixing, volume, mute | Gameplay success |
| CoinManager | Collected IDs, counter, session reset, ending tally | AI retries or drawing permission |
| DialogueController | Line IDs, subtitles, recorded clips, Next/Skip and replay policy | Provider credentials or invented live speech |

Suggested folders, to create only when needed:

```text
project.godot
README.md
AGENTS.md
scenes/             # World, player, encounters, canvas, and UI
scripts/            # GDScript implementation
data/               # Encounter definitions and supported tags
assets/
  art/
  audio/music/
  audio/sfx/
  audio/voice/
docs/               # Specifications, research, and planning documents
  SPEC.md
  REUSE_RESEARCH.md
  CREDITS.md        # Planned asset attribution and team credits
```

Decide the server code location after selecting the hosting approach. Fixed responses may unblock early integration, but must be marked as test mode and replaced with a real call in the Day 1 vertical slice.

### Web acceptance environment

- Verify the actual HTTPS deployment, not only F5 inside Godot.
- Open it on another team member's device to expose local-path or developer-session dependencies.
- Initial primary acceptance browser: desktop Chrome. Perform a basic Safari smoke check and record differences.
- If the competition mandates a browser or embedded player, test that exact environment as well.
- Verify movement/jump/sprint, mouse drag, push/climb, focus changes, canvas coordinates, route gates, and coin collection while a real request is pending.
- Confirm endpoint origin and cross-origin configuration for the final URL.
- Confirm Music/SFX/Voice after Start, subtitles/Skip, independent volumes, mute/unmute, long looping, pickups, and tab changes.
- Keep test modes, internal errors, and secrets out of the public player experience.
- Record download size and initial load time early. Simplify art and audio when later builds regress noticeably.
- Aim for at least 30 FPS during walking on an agreed team laptop, then document its browser/device and observed result. No universal performance guarantee is implied.
- A demo recording is useful backup material, not a replacement for a playable Web build.

## 12. Team responsibilities and collaboration

| Role | Primary ownership | Earliest deliverable |
|---|---|---|
| Developer A | Reused traversal foundation, camera, coins, bounded push/climb, encounter progression, integration | Walk/jump/sprint, collect, and respawn without losing session state |
| Developer B | Canvas, AI client/server, background request state, full item schema, Web delivery, reusable dialogue integration | Submit a real drawing and keep exploring while a validated item is prepared |
| Designer A | Art direction, player/NPC assets, compact level and coin-route layout | One readable zone with an optional nearby coin pocket |
| Designer B | Encounter rules/stat budgets, English script, ElevenLabs voice production, music/SFX, playtests | Solution/stat matrix, short script manifest, and audio samples |

- Roles are proposals; name owners at kickoff. Developer A is proposed integration owner, while Developer B owns dialogue/voice playback wiring and its shared AudioManager interface.
- Both developers agree on session/request identity, item schema, pickup persistence, and input locking before separate implementation.
- Use a single movement base. Compare reuse candidates in an isolated spike rather than merging whole starter games into the main project.
- Assign each shared scene to one editor. Integrate at least twice daily with short-lived branches and verification notes.
- Godot can save files while external tools edit them; coordinate ownership and review reload prompts to avoid overwriting changes.
- Every ticket has an owner, priority, dependencies, and acceptance condition. A repository license applies to its covered files, not automatically to every bundled asset.

## 13. Four-day schedule and scope control

The v0.2 request expands the plan materially. Reuse reduces implementation effort only after integration and Web compatibility are demonstrated; it does not remove testing or content work.

| Day | Main work | Exit condition |
|---|---|---|
| Day 1 | Verify rules/access; time-box reuse spike; Web export; basic walk/jump/sprint and coins; canvas; real AI/stat response; one voice sample | Hosted slice lets the player submit, move/collect during analysis, inspect the full item, return, and solve one encounter; BGM and a subtitled voice clip work |
| Day 2 | Complete encounters/end; non-modal result lifecycle; safe respawn; limited crate/climb; dialogue controls | Beginning-to-ending build with all requested baseline systems represented; jumping/respawn/late replies cannot lose coins or progress |
| Day 3 | Final level/art, coin placement, recorded lines, sound mix, stats/hints tuning, outside tests | Required content integrated and principal usability/blocking issues corrected |
| Day 4 | Freeze features; regression on final host; credits, licenses, submission and backup | Playable final URL with verified audio, traversal, AI, state recovery, and submission materials |

### Decision gates

- Early Day 1: verify permitted pre-existing code/assets, competition times, browser requirements, API ownership, and a minimal Web export.
- Time-box the initial controller/reuse spike to approximately 2–3 hours. If it fails, isolate the failing dependency and choose the simpler documented candidate; do not spend the competition upgrading multiple frameworks.
- End of Day 1: if background drawing-to-item does not work, stop growing content and resolve that loop. Reduce scenery and the footprint of optional traversal areas.
- End of Day 2: if the full loop is incomplete, simplify the finale, reduce recording length and visual polish, and raise any required scope reduction explicitly.
- Jump/sprint, bounded pushing/climbing, coins during processing, narration/dialogue, English content, and five item fields are now requested scope. Do not silently return to the v0.1 exclusions.

### Cut order and limits

Cut extra voices beyond narrator/otter, a second music track, ambience, additional camera effects, additional coin routes, and extra solution variants before removing required systems.

Keep at least one small crate interaction and one safe marked climbing route unless the user agrees otherwise. Arbitrary-wall climbing and elaborate physics puzzles are not assumed.

If even the bounded feature set cannot be completed, record the tradeoff and request a decision about encounter count or movement scope. The document must not label an unimplemented requirement as delivered.

Keep a real AI call, five-field validation, original artwork, non-blocking processing, subtitle/voice basics, failure recovery, a clear ending, and actual Web verification.

## 14. Backlog ready for tickets

These are proposed tasks, not issues already created on GitHub.

| ID | Priority | Task | Owner | Dependencies | Acceptance |
|---|---|---|---|---|---|
| T01 | P0 | Rules, access, engine version, API/voice owners | Team | None | Shared starter runs; external-code rules and budget owners recorded |
| T02 | P0 | Reuse spike and minimal Web deployment | Both devs | T01 | Pinned candidate runs in 4.7.2 Compatibility on the actual host; licenses recorded |
| T03 | P0 | Walk/jump/sprint, mouse camera, interaction, checkpoint | Dev A | T02 | Grounded controls work; safe reset preserves session state |
| T04 | P0 | Canvas, snapshot, undo/clear | Dev B | T01 | Valid PNG submission; no empty calls or cursor conflicts |
| T05 | P0 | AI type/stats/tags contract and server bounds | Dev B + Designer B | T04 | All five requested fields returned and validated; malformed data is recoverable |
| T06 | P0 | Coin IDs, route pickups, counter and tally | Dev A + Designer A | T03 | Each coin counts once; fall/retry does not reset or duplicate it |
| T07 | P0 | Background request and non-modal ready/error lifecycle | Dev B | T03–T06 | Move/collect while pending; late reply, respawn, cancel and restart handled correctly |
| T08 | P0 | One integrated encounter and original-art stat card | Both devs | T05, T07 | Real drawing solves E01 after returning from a coin detour |
| T09 | P0 | Bounded crate pushing and designated climb route | Dev A | T03, T06 | Safe optional traversal, no gate bypass or permanent blockage |
| T10 | P0 | Three encounter rules, gates, hints and stat budgets | Designer B + Dev A | T08 | Two routes each, stat units clear, one range-dependent example |
| T11 | P0 | English script and ElevenLabs production | Designer B | T10 | Approved line manifest and narrator/NPC clips; no runtime TTS dependency |
| T12 | P0 | Dialogue, subtitles, Voice channel and skip/ducking | Dev B | T11 | Next/Skip, missing audio, mute, and simultaneous ready notification behave correctly |
| T13 | P0 | BGM and ten SFX event categories | Designer B + Dev A | T06–T09 | Comfortable loop, pickup, traversal and AI-ready feedback without sound spam |
| T14 | P0 | Remaining world, otter payoff, ending and final assets | Designer A + Dev A | T09, T10 | Complete safe route; coin tally and ending reachable |
| T15 | P0 | Limits, manual mode and final browser playtests | Both devs; Designer B coordinates | T12–T14 | Section 15 results recorded; real and simulated slow/failing requests tested |
| T16 | P0 | Licenses, README, credits, submission and demo | Submission owner | T15 | Final URL and required acknowledgements complete |

## 15. Acceptance and playtesting

### Functional checks

| Case | Expected result |
|---|---|
| First visit and Start | Controls, narration and subtitles are clear; sound starts without login |
| WASD/arrows, jump, sprint, mouse camera | Consistent movement; no diagonal speed boost, UI input leakage, or right-drag context-menu conflict |
| Small crate and marked climb route | Bounded push force, safe climb entry/exit, no launches or permanent blocks |
| Walls, water edge, gates, and sprint-jumps | Cannot bypass unsolved gates even with crate assistance; falls recover at a safe checkpoint |
| Approach/leave an NPC | One relevant prompt appears and clears at the right range |
| Open/close panels while holding movement | Character stops during panels and does not resume from stale input |
| First real drawing | Original artwork plus all five required typed/bounded fields and tags become an item |
| Submit and continue playing | Canvas closes; walk/jump/sprint/collect work while the request stays pending |
| AI returns during jumping, climbing, or dialogue | Non-modal notification persists; no camera theft, teleport, or speech interruption |
| Leave origin area and revisit solved ground while pending | Result stays bound to the original encounter and can be inspected later |
| Fall/respawn while pending | Request, coin IDs, solved states and narration flags remain valid |
| Coins on path and near station | Collection works without a pending request; retry/timeout does not create extra coins |
| All nearby coins collected or AI finishes immediately | No forced wait; progression and optional traversal remain available |
| Empty drawing | No network call; useful feedback |
| Release pointer outside canvas | Stroke ends correctly; other controls remain usable |
| Undo, clear, and reopen canvas | Draft behavior matches Section 7; progress is unchanged |
| Two valid routes in each encounter | At least six successful routes have understandable outcomes |
| Unrelated recognized item | Contextual retry message, no resource penalty |
| Invalid/missing type or stat, unknown tag, NaN, infinite or oversized text | Agreed validation/normalization prevents broken UI or unbounded game effects |
| Range, item speed and remaining durability | Range uses world units, speed never changes player sprint, and only a committed successful use spends durability once |
| Uncertain recognition | Redraw or clearly labeled purpose selection is available |
| Timeout, offline, 429, or provider error | Waiting ends; retry/manual mode remains available |
| Cancel/restart followed by late response | Old data cannot replace current state or advance the game; ordinary walking does not invalidate a valid request |
| Rapid Submit or Use clicks | One pending request and one resolution; no duplicate effects |
| Revisit solved encounter | Progress stays solved; rewards/sequences do not repeat |
| Both final crossing routes | Safe destination, working collision, reachable summit |
| Ending and restart | Narrated ending and coin tally; full restart resets world/items/draft/coins/request generation and story flags |
| Muted playthrough | All required information remains understandable; SOUND tags still work |
| Two BGM loops, sustained drawing, rapid clicks | No obvious seam, duplicate music, clipping from piled-up sounds, or SFX spam |
| Walk, stop, push against wall, open panel | Footsteps reflect actual movement and stop correctly |
| Music/SFX/Voice volumes and mute/unmute | Independent levels and chosen values respected; English subtitles remain available |
| Dialogue Next/Skip, missing voice, repeat trigger | No duplicate progression or stuck panel; subtitle remains accurate; one-shot clips do not spam |
| Voice plus coin/AI-ready cues | Dialogue remains intelligible; no overlapping spoken lines; music returns to its chosen volume |
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
- Are traversal and coins enjoyable during a deliberately slow test response? Do players notice readiness and know how to return to their encounter?
- Does the wait remain acceptable when local coins are already gone, and can the player recover from failure without coaching?
- Are narration/dialogue understandable and skippable? Are music, footsteps, pencil and coin sounds comfortable, and are Voice/mute controls easy to find?
- Does the main path roughly fit 5–10 minutes, with optional coin exploration extending it naturally?

These are design targets. Record actual results and never mark untested behavior as passed.

### Definition of done

A task is done when it is integrated, checked in the relevant target environment, has no blocking failure, and includes its required text, visual feedback, and sound hooks.

The game is done when P0 passes or an explicit scope revision has been recorded, the final deployment is playable, and credits, limitations, and submission materials are complete.

## 16. Open decisions

| Question | Current proposal | Decide by |
|---|---|---|
| Exact competition start/end and rules | Not supplied | Before scheduling competition work or assuming pre-work is allowed |
| Required submission format, browser, and online AI availability | Web expected; desktop Chrome proposed | Early Day 1 |
| Camera feel and player appearance | Third-person trail with limited mouse orbit; illustrated or low-detail character | During controller spike |
| Coin purpose | Count and ending reward; optional spending remains undecided | Before economy/UI implementation |
| Climbing scope | Marked ladder/vine plus small crates; not arbitrary walls | Before traversal implementation |
| Use the three encounter stories in Section 6? | Otter bag, crow sign, broken crossing | After the first prototype playtest |
| Location and story flavor | Fictional mountain trail; Fuji-inspired scenery optional | Before final environment art |
| Narrator/otter voices and exact script | Pre-generated ElevenLabs clips, English subtitles, warm/playful delivery | Before voice generation |
| Audio references and sources | Instrumental BGM, SFX and scripted voices | Before final audio selection |
| Item stat budgets and action coverage | Bounds and units in Section 8; attack power informational without an implemented attack | Day 1 integration |
| AI provider/model, account owner, and spending cap | Not selected | Before real integration and public access |
| Named owners and final submission owner | Role split in Section 12 | Kickoff |

## 17. Reuse strategy and researched candidates

See [REUSE_RESEARCH.md](REUSE_RESEARCH.md) for source links, version pins, license distinctions, maintenance evidence, and missing features. These are researched candidates, not dependencies already installed or tested in our game.

- Initial movement/coin candidate: [Kenney 3D Platformer Starter Kit](https://github.com/KenneyNL/Starter-Kit-3D-Platformer). Reuse its narrow movement/collection foundation after the Web spike, not the entire game unchanged.
- Controller alternative: [GDQuest Godot 4 third-person controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller). Inspect code separately from assets; asset permissions differ from the code license.
- Dialogue candidate: [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager). Evaluate for authored conversations; line-based voice playback/subtitles still need integration.
- Drawing and texture references: [Godot official demos](https://github.com/godotengine/godot-demo-projects). Copy only a relevant example after verifying its engine/API version and license.

### Adoption gate

1. Choose a specific commit/release; retain the code license and check bundled art/audio separately.
2. Test in an isolated copy using our exact Godot version and Compatibility renderer.
3. Verify Web export, mouse/UI switching, jump/sprint, pickup persistence, and checkpoint respawn.
4. Keep request and coin state outside reloadable scenes. Replace any starter's whole-scene reload on falling.
5. Add bounded push/climb only where missing; do not assume the chosen starter includes them.
6. Verify drawing snapshot/undo and prerecorded voice needs separately. A platformer base does not supply sketch interpretation.
7. Record adopted upstream pins, local changes, licenses and required notices. Import no whole repository solely because it appears mature or popular.

## 18. References and changes

- [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): rendering, export, browser networking, and audio constraints. Recheck against the team's installed version during implementation.
- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): starting point for script-controlled movement and collision.
- [Godot InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html): named input actions.
- [ElevenLabs Text to Speech](https://elevenlabs.io/docs/overview/capabilities/text-to-speech): voice-generation capability; exact account access remains unverified.
- [ElevenLabs audio downloads](https://help.elevenlabs.io/hc/en-us/articles/14129286847505-How-do-I-download-generated-files-from-Text-to-Speech): exporting generated clips for an asset workflow.
- [Reuse research](REUSE_RESEARCH.md): verified candidate evidence and adaptation limits.
- [Repository](https://github.com/AdeDeepFishing/Paws-Peaks)
- [Four Otters - Dev Board](https://github.com/users/AdeDeepFishing/projects/1/views/1)

This file is the shared scope reference. Update it when the team resolves open choices or changes scope. A new feature needs an owner, an acceptance condition, and an explicit explanation of what it displaces within four days.

| Version | Date | Change |
|---|---|---|
| 0.2 | 2026-09-12 | Added voiced narration/dialogue, background AI with playable coin collection, jump/sprint/bounded push/climb and mouse controls, five required item fields, reuse research, and corresponding milestones/tests |
| 0.1 | 2026-09-12 | Initial English specification; confirmed free walking, English-only project content, and warm/playful audio; encounter stories and camera details remain proposals |
