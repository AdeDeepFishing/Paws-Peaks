# Paws & Peaks — Game Jam Specification

> Version: 0.7 | Updated: 2026-09-12 | Status: Working draft
>
> Team: Four Otters — two designers and two developers, all new to Godot.
> Production: September 12–15, 2026 (Asia/Tokyo, JST, UTC+09:00). September 12 is Day 1; production and asset generation may begin now, as confirmed by the team.
> Required submission: a playable game URL and a gameplay video.
> Internal target: submit before September 15 at 21:00 JST. Hard deadline: Tuesday, September 15 at 23:59 JST.
> Any teammate may submit; yanwen checks completion and takes over if submission is still missing at 21:00 JST.
> This document specifies planned work. It does not claim that these features already exist.

## Table of contents

1. [Product vision](#1-product-vision)
2. [Decisions and current status](#2-decisions-and-current-status)
3. [Release scope](#3-release-scope)
4. [Exploration, traversal, camera, and coins](#4-exploration-traversal-camera-and-coins)
5. [Player flow and asynchronous state](#5-player-flow-and-asynchronous-state)
6. [Five-stage progression and design status](#6-five-stage-progression-and-design-status)
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

Drawing to solve encounters is the core mechanic. The confirmed five-stage route includes a large-dog confrontation and a final boss. Their exact action/combat implementation must be defined explicitly; a general-purpose real-time combat framework is not assumed.

### Design principles

1. Drawing skill is not a requirement. Rough sketches are welcome, and recognition failures do not consume opportunities.
2. Keep the player's artwork visible. The resulting object retains the original drawing in its card and use sequence.
3. Support multiple reasonable solutions. The working target remains at least two supported routes per stage; specific routes and thresholds require team agreement and are not established solely by the concept illustration.
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
| Team and schedule | Confirmed | Two designers, two developers, Godot beginners; Day 1 is September 12, production runs through September 15, 2026 |
| Production start | Confirmed by user | Work and asset generation may begin now; this is not a claim that any specific asset license or service access has been verified |
| Hard deadline | Confirmed by user | Tuesday, September 15, 2026 at 23:59 JST (UTC+09:00) |
| Internal submission target | Confirmed | Before September 15 at 21:00 JST |
| Submission responsibility | Confirmed | Any teammate may submit; yanwen verifies and takes over if still unsubmitted at 21:00 JST |
| Engine | Confirmed | Godot; current starter uses 4.7.2 Standard |
| Core mechanic | Confirmed | Draw objects to solve encounters |
| Exploration | Confirmed | The player can freely walk and explore within the playable area |
| World presentation | Original direction; implementation proposal below | Small 3D storybook environment, potentially using flat illustrated characters and props |
| Movement abilities | Requested | Walking, jumping, sprinting, physics pushing, and climbing; bounded implementations in Section 4 |
| Camera and input details | First-stage prototype confirmed | Fixed camera per stage; E01 uses an overhead orthographic view. WASD or arrow keys follow camera yaw; Space, Shift; E/click opens transparent scene drawing at designated locations; drawing locks movement and hides the normal HUD. Later camera compositions follow designer deliveries. Push/climb remain later work |
| Coins and AI waiting | Requested | Collect along routes and in nearby activity areas while AI runs in the background |
| Coin spending | Open | Default proposal: collection count and an ending reward; essential drawings stay free |
| Language | Confirmed | English throughout the game and repository |
| Audio mood | Confirmed | Warm, comforting, and slightly playful |
| Background music and SFX | Confirmed | Required, with player volume controls |
| Narration and dialogue | Confirmed correction | English spoken narration and key NPC dialogue, with English subtitles |
| Voice production | Available option | User has an ElevenLabs subscription; proposed pre-generated audio, with exact voice/plan/credits still to verify |
| AI item fields | Required | Type, Attack power, Range, Speed, Durability, plus identification and encounter-effect tags |
| Otter NPC | Stage 4 confirmed; details open | The fourth stage is an otter encounter. What the player helps with and what the otter does afterward remain undecided |
| Submission deliverables | Confirmed | Playable game URL plus gameplay video so judges can both play and watch; exact portal/video format/browser requirements still need checking |
| Hosting | Open | Vercel is a candidate; sponsorship does not establish deployment access or credits |
| Five-stage route | Confirmed | River crossing -> large dog -> crows -> otter -> final boss |
| First three stage premises | Confirmed | Use the team's Concept 01 reference; exact solution rules, balancing, and English scripts still need implementation decisions |
| Stages 4 and 5 | Intentionally open | Otter task/payoff and final boss identity/details/strategy have not been finalized |
| AI provider, model, and budget | Open | Select and test early on Day 1 |

### Existing project

- Repository: <https://github.com/AdeDeepFishing/Paws-Peaks>
- Local folder: `/Users/yanwenchen/GodotProjects/Paws-Peaks`
- Board: <https://github.com/users/AdeDeepFishing/projects/1/views/1>
- The active Godot project is `3d_game/project.godot`, with `3d_game/scenes/river/river_crossing.tscn` as its startup scene. The Brackeys dungeon remains at `3d_game/main.tscn` as a reference.
- The first stage uses the supplied stag01 storybook creek, a placeholder hiker, camera-relative movement, a fixed overhead orthographic camera, walking/jumping/sprinting, transparent full-viewport drawing with transparent-background PNG export, a background request boundary with explicit mock responses, automatic encounter-object placement, collectible coins, a fixed bridge, fall recovery, and completion/restart. See [DAY1_HANDOFF.md](DAY1_HANDOFF.md). Real AI, final art/audio, push/climb, E02–E05, and Web deployment remain incomplete. GodotPhysics3D is enabled and the old Jolt extension is ignored; Forward Plus remains selected.
- Board linking, teammate permissions, export templates, API access, and hosting must be verified separately.

## 3. Release scope

### P0 — Required for the baseline submission

| ID | Feature | Minimum definition of done |
|---|---|---|
| F01 | Start and ending | Start button, concise controls, clear ending, credits, and restart |
| F02 | Traversal | Walk, jump, sprint, fixed stage camera, one bounded pushable-crate interaction, and a designated climb route |
| F03 | Proximity interaction | Approach an encounter, see a prompt, and interact with one clear target |
| F04 | Drawing canvas | One pen, undo last stroke, clear, submit, and back |
| F05 | Real AI interpretation | Analyze actual drawings and return validated type, attack_power, range, speed, durability, name, description, and tags |
| F06 | Original-art object | Original sketch, interpretation, a readable stat card, and visible use feedback |
| F07 | Five stages | River crossing, large dog, crows, otter, final boss in that order; finalize and implement the solution rules for all five before submission |
| F08 | Otter encounter | A complete fourth-stage interaction after the team defines the task and outcome; no assumed tutorial role or mandatory boss assistance |
| F09 | Recovery | Invalid objects, uncertainty, timeout, network failure, and repeated input cannot soft-lock play |
| F10 | Audio and voice | Looping BGM, essential SFX, narrated story beats, key NPC dialogue, subtitles, global mute, and Music/SFX/Voice volume |
| F11 | Web delivery | Hosted build supports movement, drawing, requests, sound, and a complete playthrough |
| F12 | Readability | Legible text, clear interaction prompts, and visual/text equivalents for necessary audio information |
| F13 | Submission package | Required playable URL and gameplay video, plus instructions, credits/notices, known limitations, and recorded submission confirmation |
| F14 | Coins | Route and nearby activity pickups, session counter, one-time collection, and ending tally |
| F15 | Background interpretation | Move and collect during processing; receive a non-modal ready/error notification and inspect when safe |

### P1 — Only after P0 works end to end

- A second music track, nature ambience, and distinctive animal or item sounds.
- Extra solution routes, richer descriptions, and more object-specific feedback.
- Additional camera transitions, reveal effects, and small environmental details.
- A closing gallery of player drawings.
- Extra confrontation effects beyond the approved large-dog and final-boss mechanics.
- A few optional scenic inspection points with short text and no new quest system.

### Out of scope

- Arbitrary sketch-to-3D mesh generation, rigging, generated collision, or unique generated mechanics.
- A large open world, unrestricted wall climbing, advanced parkour, swimming controls, moving-platform puzzles, or arbitrary physics construction. Basic jump/sprint, fixed stage views, designated climbing, and bounded crate pushing are included.
- A general-purpose real-time combat framework, equipment progression, or deep weapon balancing. The dog confrontation and final boss are required, but their approved mechanics may be compact authored actions; do not assume they can be omitted or require a full combat engine.
- Mandatory paid drawing attempts, a full shop/trading system, and a crafting economy. Collectible coins are included; optional spending remains a separate decision.
- Multiplayer, accounts, leaderboards, cloud saves, and mandatory persistent progress.
- Free-form NPC chat, player voice input, runtime music generation, and mandatory runtime speech synthesis of every generated item. Pre-generated narration and key NPC dialogue are included.
- Pet progression, a general companion navigation system, or dynamically simulated bridges and water.

## 4. Exploration, traversal, camera, and coins

**Free exploration, coin collection, and something to do during AI processing are baseline requirements.** The requested traversal abilities are included as small, testable implementations rather than an unrestricted parkour system.

### World layout

- One compact 3D route with five ordered stage zones: river, large dog, crows, otter, and final boss. Previously opened areas remain accessible; the exact ending location is still a story decision.
- Place coins along the route between encounters and in optional pockets near each drawing interaction.
- Each processing area offers a short loop: a few ground coins, a low jump ledge, or a reusable traversal toy. Players can start exploring immediately after submission.
- Place at least one small pushable crate and one marked climb route in the game. These are optional coin detours, so controller problems cannot block the main drawing path.
- Keep the main route readable through landmarks, NPC placement, and visible gates; do not require a minimap.
- Keep main-route travel short, initially about 10–20 seconds between encounters. Optional detours should be nearby, not lengthy distractions from the result.
- Route gates must remain effective against sprint-jumps and crate-assisted jumps. Validate maximum reach when setting their geometry.
- Use static authored scenery and simple collision. No generated terrain, physical bridge simulation, or mandatory precision platforming.

### Controls — confirmed first-stage prototype and later proposals

| Action | Input | Behavior |
|---|---|---|
| Move | WASD or arrow keys | Camera-relative ground movement; character turns toward travel |
| Jump | Space | One reliable grounded jump; no double jump required |
| Sprint | Hold Shift while moving | Fixed faster speed; no stamina meter |
| Camera | No player camera input | Fixed per-level composition; E01 uses an overhead orthographic camera. Other stages may use different designer-approved angles |
| Interact | E or click the pen prompt with the visible cursor | Inside a designated area, show the drawing prompt. E/click enters drawing while grounded; leaving hides entry. Generation continues while exploring; supported results appear automatically |
| Push crate | Walk into a marked small crate | Apply bounded force; do not push every scenery object |
| Climb | E at a marked ladder/vine, then W/S | Follow the authored climb route; E exits at a safe location |
| Draw and UI | Left mouse button | Buttons and canvas strokes; UI consumes clicks before world interactions |
| Inspect result | E or click the sketchbook | Inspect when grounded; use the item only near its originating encounter |
| Back / cancel | Visible button; Escape shortcut | Close the current UI; canceling an AI request is a separate explicit action |
| Sound | Visible sound button | Music, SFX, Voice, and global mute |

WASD or arrow keys move the character; mouse input controls interactions and drawing; it never rotates the camera. Click-to-move pathfinding is not implied by mouse support and remains optional.

### Traversal acceptance boundaries

- Use named input actions. Normalize diagonal input and release movement/camera input when focus is lost or a modal opens.
- Jump and sprint should be forgiving; optional short input buffering/coyote time may be reused from a controller but must be verified.
- The cursor stays visible during exploration and drawing. Neither mouse motion nor movement changes the stage camera. Drawing suspends player movement; closing or submitting restores it. Verify input focus separately in the browser.
- Pushable crates have limited mass/force, simple collision, and a bounded area. Reset displaced crates to an authored position when needed; prevent launches, gate bypasses, and permanent blockage.
- Climbing means designated ladders/vines with safe entry and exit. Arbitrary mountain-wall climbing is not assumed and remains a question for the user.
- Falling or becoming stuck returns the player to a safe checkpoint, preserving collected coins, solved encounters, and the active AI request. Do not reload the entire scene or restart the network call.
- The otter can appear at scripted locations; a companion navigation system is not required.

### Coin rules

- Working name: Coins. Use original artwork/audio or properly licensed assets; Mario is a reference for the collection feel, not an asset source.
- Each coin has a stable ID and can be collected once per session. Pickup increments a visible counter and triggers brief visual and audio feedback.
- Keep a small total coin budget and distribute it across the five-stage route, including safe activity pockets near drawing interactions. Replan counts after grayboxing; the previous three-zone allocation is retired, and no new fixed total is confirmed.
- Coins are present regardless of whether AI is processing. Do not spawn rewards only after submitting or respawn them when a request retries.
- Default proposal pending user feedback: use coins for a completion tally and an ending badge/message. No mandatory drawing fee, no loss on failed recognition, no lives system, and no hard coin gate.
- If spending is later chosen, basic drawings remain free; spending may buy optional cosmetic or bonus opportunities. That economy requires an explicit update before implementation.
- Canceling, timing out, receiving a result, and respawning do not erase collected coins. Full New Game resets them.
- Once nearby coins are collected, players can still traverse or revisit the crate/climb interaction. Coins are a pleasant activity, not a substitute for latency reduction or failure recovery.
- Never delay an already-ready AI result to make the player finish collecting coins. Coin detours remain available afterward.

## 5. Player flow and asynchronous state

```text
Start -> Narration -> Explore / collect -> Approach stage target -> Observe / dialogue -> Draw
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
                                                                                Next stage -> Final boss -> Ending
```

**Stage order:** E01 River -> E02 Large dog -> E03 Crows -> E04 Otter -> E05 Final boss -> Ending.

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
- Provide safe waiting space around hostile stages. Proposed rule: dog/crow/boss threats do not pursue or damage the player in drawing UI or the marked processing pocket; AI latency must not become a combat penalty. Final encounter behavior must preserve this protection.
- Queue an Inspect action until the player is grounded and outside climbing/other modal states. The notification remains available until handled.
- Inspecting is allowed away from the encounter. Applying the item requires returning to its originating unsolved target and being within interaction range; otherwise disable Use and explain where to return.
- If a voice line is already playing, defer or soften the ready cue and avoid a second simultaneous spoken announcement.
- Cancel/restart invalidates old results. Check the session/request identity on every completion. A local fall/respawn preserves the same identity.
- A valid new item replaces the old item only for the same active encounter. Failed requests do not delete an existing usable item.
- Closing and reopening the drawing panel preserves its draft. Canceling a UI panel is distinct from canceling a submitted request.
- Solved encounters and coin IDs persist throughout the session. Full restart resets progress, items, drafts, coins, pending context, and one-shot dialogue flags.
- Keep an upper bound on waiting even while the player is occupied. Re-evaluate deadlines when the browser regains focus; hidden-tab suspension must not leave a request pending indefinitely.
- No required persistent save in this release. Refresh may restart the session; record that limitation in the README.

## 6. Five-stage progression and design status

**Meeting update, September 12:** retain the five-stage sequence shown in the team's Concept 01 image. The river, large dog, and crows are confirmed stage premises. The otter belongs in Stage 4, and the final boss belongs in Stage 5, but their detailed tasks and solutions remain open.

The image's Japanese writing is reference material only. All shipped titles, narration, dialogue, UI, and repository text remain English. Sketches in the reference suggest example objects; they do not by themselves settle every allowed solution, stat threshold, or combat rule.

### Stage overview

| ID | Working English title | Confirmed content | Still to decide |
|---|---|---|---|
| E01 | Across the River | The player needs to reach the far bank of a river too wide to cross unaided; draw something useful | Supported crossing objects, alternative routes, trigger and reach/size rules |
| E02 | The Large Dog | A large growling dog blocks the path; the player must deal with the confrontation | Exact weapon/action interaction, whether alternatives are supported, damage/retreat conditions, retries |
| E03 | The Crows | A flock descends and blocks or harasses the player; draw an object to deal with them | How shielding/repelling works, accepted alternatives, duration and success condition |
| E04 | Meeting the Otter | The player meets an otter in the fourth stage | What it needs, how the player helps or interacts, and any later help/reward |
| E05 | Final Boss | The fifth stage is the final boss encounter | Final identity/presentation, phases or actions, winning strategy, failure/retry rules, and ending |

E01–E05 now have these meanings in scene configuration, prompt context, fixtures, scripts, and voice manifests. The former otter-bag tutorial, stolen-sign crow scenario, and final broken crossing are superseded; do not implement them as additional levels.

### E01 — Across the River

- **Confirmed premise:** the player wants to reach the other bank, but the river is too wide to cross unaided.
- **Reference example:** the concept shows a raft-like drawing. Preserve the experience of drawing an aid and then using it to cross.
- **Implementation proposal:** use E01 for the first drawing tutorial, guided by the narrator and short English UI prompts. The otter does not appear as the tutorial guide.
- **Confirmed Day 1 implementation:** a fixed, walkable bridge using a long and sturdy idea. The prototype rule accepts LONG_REACH + STURDY and positive remaining durability, then spends one use. Dimensions are authored, not derived from item Range. The raft route is deferred; additional supported solutions remain design work.
- Use authored crossing positions and a safe endpoint instead of simulating water or arbitrary bridge construction. Prevent normal jumps or crate-assisted jumps from bypassing the intended crossing.
- While analysis runs, the player may explore and collect in a safe near-bank pocket. Returning a ready result must not start the crossing automatically.
- **Completion:** using an accepted object gets the player safely to the far bank and opens E02.
- **Acceptance:** the player learns draw -> submit -> explore while waiting -> inspect -> use; approved crossing routes work; failures permit retry without losing coins.

### E02 — The Large Dog

- **Confirmed premise:** a large growling dog stands in the player's way.
- **Reference example:** the image shows the player with a drawn sword. A drawn weapon confronting the dog is the reference direction; exact attack and victory rules have not been specified in the meeting.
- **Implementation proposal:** start with one bounded, pre-authored confrontation action rather than building a general combat engine. The team must decide whether it is a click-to-use sequence, timed action, or short real-time exchange.
- Define which types/tags can trigger the action, how accepted attack_power/range/speed/durability affect it, and how the dog yields, retreats, or is otherwise overcome. Do not invent fixed health values or a final damage formula in this document.
- Food, distraction, intimidation, or other alternatives may be discussed, but none is confirmed merely because the previous spec had FOOD or SOUND tags.
- Provide a safe processing pocket; retries and recognition delays must not expose the player to unavoidable harm.
- **Completion:** the approved resolution clears the dog obstruction and unlocks E03.
- **Acceptance:** the intended drawn object visibly participates in the confrontation; the approved success and failure rules are observable and cannot soft-lock the route.

### E03 — The Crows

- **Confirmed premise:** multiple crows descend, flap around the player, and obstruct the way.
- **Reference examples:** the player holds a shield-like object; the drawing card shows an umbrella. Protection or repelling the flock is the reference direction, not restoring a stolen road sign.
- **Candidate implementation:** a pre-authored protective effect for a shield or umbrella, represented by a proposed PROTECTS tag. The team must decide how this causes the flock to disperse or lets the player pass.
- Other deterrents, such as sound, may be accepted if agreed; they are not automatically finalized alternatives.
- Specify how long the effect must last and whether any interaction/timing is required. Do not assume that all shields, food, or sound objects always succeed.
- **Completion:** the approved action resolves the flock obstruction and opens the route to E04.
- **Acceptance:** the original sketch is visible during protection/repelling; flock feedback makes the outcome clear; waiting and retry remain safe.

### E04 — Meeting the Otter — DETAILS OPEN

- **Confirmed:** the fourth stage features meeting the otter. It follows the crow encounter.
- **Reference tone:** a small otter appears lonely or interested in company. The illustration suggests gifts or play, including fish, flowers, or friendship motifs.
- **Not yet decided:** the actual need/task, accepted drawings, success condition, dialogue, reward, and whether the otter provides later assistance.
- These illustrated possibilities are discussion inputs, not a finalized feeding quest, fetch quest, friendship meter, or combat companion.
- Reserve a stage scene, interaction point, and transition to E05. A development stub may keep integration moving but does not count as a completed submission stage.
- **Decision required before final implementation:** write the player's objective, supported solution routes, visible outcome, and any persisted otter state. Add a later-help dependency only if the team explicitly adopts it.

### E05 — Final Boss — DETAILS OPEN

- **Confirmed:** the fifth stage is a final boss encounter, followed by the ending.
- **Reference concept only:** the illustration labels the boss as the story itself and shows a figure made of pages, with a possible connection to the narrator. Treat that identity/twist and its visual form as a proposal, not a finalized story decision.
- **Not yet decided:** the boss's final identity, behavior, attacks or phases, what the player draws, the winning strategy, role of item statistics, failure/retry behavior, and the ending.
- Do not prescribe a sword-only fight, a health-bar system, a fixed phase count, an otter-assisted victory, or a specific ending without team agreement.
- Reserve a boss scene and ending transition for integration. A placeholder is not a finished boss.
- Preserve safe background processing, original-art use feedback, and valid retry paths regardless of the eventual boss design.
- **Decision required before final implementation:** define one minimum complete boss loop and its ending, then document any alternative solutions. Update affected state flags, tags, stat rules, voice lines, and tests together.

### Effect vocabulary and solution rules

The type/stat JSON contract remains required. Effect tags below are a working vocabulary for interpreting drawings; they do not replace an encounter-specific rule sheet.

| Tag | Meaning | Example / status |
|---|---|---|
| LONG_REACH | Extends reach or spans distance | Long pole or board; candidate for E01 |
| FLOATS | Functions as a flotation aid | Raft or flotation ring; candidate for E01 |
| STURDY | Provides firm support | Solid board; candidate for a crossing solution |
| PROTECTS | Provides cover or shielding | Shield or umbrella; proposed addition for E03, subject to rule confirmation |
| FOOD | Something an animal may consider food | Available vocabulary; no E02/E04 feeding solution is finalized |
| SOUND | Produces noticeable sound | Available vocabulary; deterrent effectiveness must be agreed per stage |
| OTHER | No supported effect applies | Unrelated object |

- Keep one or two tags per item; OTHER is exclusive. Confirm the final allowed tag set before wiring server validation and fixtures.
- E02/E05 may use accepted type and statistics with an authored action; adding a generic weapon tag is not required until a rule needs it.
- The design target remains multiple reasonable solutions. Record accepted examples, rejected examples, action/threshold conditions, and feedback for each finalized route. Do not claim ten implemented routes simply because five stages are planned.
- Test at least 12 varied sketches before locking rules, including raft/bridge candidates, weapons, shields/umbrellas, rough or unrelated shapes, mixed objects, and text-bearing drawings.
- Tags and statistics express simplified game affordances, not reliable physical measurements inferred from a sketch.
- If a tag repeatedly fails recognition, adjust the rule or offer explicit purpose confirmation. A model result alone must not declare the stage solved.

## 7. Drawing and object presentation

### Canvas requirements

- One black pen with a thin light display outline on a transparent full-viewport canvas. Hide the regular HUD during drawing; only the bottom toolbar blocks strokes. The player and camera stay still while water continues animating. Color selection and an eraser are optional later work.
- Each stage configures a drawing trigger area. Entering shows a pen prompt; E/click starts drawing. The trigger gates entry only, not the drawable scene area. Cancel preserves the encounter draft; returning restores it.
- A press, movement, and release form one stroke. A click can form a dot.
- Undo removes the latest stroke. Clear affects only the draft, not encounter progress.
- Releasing outside the canvas must finish the stroke; returning must not accidentally continue it.
- Reject empty submissions before making a network request.
- Snapshot the submitted drawing so later changes cannot alter an in-flight request's image.
- Confirmed export (updated September 12): 512 × 512 transparent-background RGBA PNG containing opaque black ink only. Crop to ink bounds with padding and scale uniformly; omit scenery, HUD, cursor, toolbar and display outline. Draft proportions and export remain unchanged on resize. Keep the existing 1 MiB image limit.
- E01 submission now leads directly to automatic scene-object presentation, with non-modal processing/error feedback. Do not reopen a preview canvas or require Use confirmation, and do not put the PNG on the bridge as a paper texture. The current mock bridge does not establish real GLB generation or delivery.
- Use a simple waiting message such as “Finding the idea in your drawing...” without inventing progress percentages.

### Object presentation

- Show the original sketch, a short English name, a one-sentence interpretation, Type, Attack power, Range, Speed, Durability, Use, and Draw again. Mark combat-only fields as informational where no matching action exists; do not imply every item can attack.
- E01 now presents the resulting object directly at its encounter location; original drawings remain saved as input data, not attached paper props. Other stages’ item/stat presentation remains to be designed.
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
  "encounter_id": "E01",
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
- P0 includes all stats in real AI output, validation, and the item card. Finalize their concrete use in the E02 dog confrontation and E05 boss rule sheets; any E01 span/reach threshold remains a candidate rather than the former bag-retrieval rule. `speed` can scale an approved use sequence; `durability` decrements only after a successful use commits once.
- Failed attempts, inspection, drawing, network errors, and canceled actions never spend durability. An exhausted item can always be replaced with a free basic drawing; no progression soft-lock.
- Define whether and how `attack_power` affects the approved dog/boss actions before implementing those stages. It remains informational for unrelated actions. Do not apply arbitrary model numbers directly to health or invent a full combat engine merely to consume the field.
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

- A warm storybook route with a broad river, a large dog, a flock of crows, an otter area, and a final boss space. Mountain/ruin scenery is a visual direction; the final setting and ending view remain open.
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
- Production and asset generation may begin now, as confirmed by the user on September 12. Continue checking the usage terms and any disclosure requirements for specific external assets or reused code; the production-start confirmation does not settle those details.

## 10. Music, effects, narration, and dialogue

**Background music, SFX, spoken narration, and key NPC dialogue are P0.** The mood is warm, comforting, and slightly playful. All spoken and written content is English.

### Voice production plan

- The user has an ElevenLabs subscription and can arrange voice production. Verify the selected voice, available credits, and intended usage for that account before generation; this document does not claim access or consume credits.
- Create the approved script first, then pre-generate short audio files and include them as game assets. Runtime requests are for sketch analysis, not mandatory speech generation.
- Start with one narrator and one otter voice; the same narrator may cover other animals. Extra character voices are optional polish.
- Proposed voice budget: keep a compact set of short clips, usually one or two sentences each. Re-estimate coverage for five stages before recording; the prior three-stage recording estimate is not a fixed requirement.
- Required coverage: opening narration, E01 drawing instructions, background-processing guidance, E01–E03 introductions/resolutions, and then E04 dialogue plus E05/ending lines once their design is approved. Do not record an otter tutorial, promised boss assistance, or a narrator-as-boss reveal as established facts.
- Random AI item names and descriptions remain English text in P0. Fixed voice lines must avoid claiming an exact generated object name that the audio cannot know.
- Deliver a line manifest with stable line ID, speaker, exact English subtitle, audio path, measured duration, trigger, priority, and replay policy. Suggested file names: `narrator_intro_01.ogg`, `otter_meeting_01.ogg`.
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
- A small 3D world with bounded jump/sprint, fixed stage camera, a small pushable crate, and a designated climb route; drawing remains a separate 2D UI.
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
README.md
AGENTS.md
3d_game/            # Godot project root; res:// paths resolve here
  project.godot
  main.tscn
  scenes/           # World, player, encounters, canvas, and UI
  models/           # Existing template models
  addons/           # Existing template controller
  scripts/          # Planned GDScript implementation
  data/             # Planned encounter definitions and supported tags
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
- Verify movement/jump/sprint, fixed camera, push/climb, focus changes, canvas coordinates, route gates, and coin collection while a real request is pending.
- Confirm endpoint origin and cross-origin configuration for the final URL.
- Confirm Music/SFX/Voice after Start, subtitles/Skip, independent volumes, mute/unmute, long looping, pickups, and tab changes.
- Keep test modes, internal errors, and secrets out of the public player experience.
- Record download size and initial load time early. Simplify art and audio when later builds regress noticeably.
- Aim for at least 30 FPS during walking on an agreed team laptop, then document its browser/device and observed result. No universal performance guarantee is implied.
- Both a playable game URL and a gameplay video are required submission deliverables. The video complements the playable build; neither replaces the other. Verify both links from a judge-like browser session.

## 12. Team responsibilities and collaboration

| Role | Primary ownership | Earliest deliverable |
|---|---|---|
| Yanwen (Developer A) | Movement, camera, drawing canvas and PNG output, first river stage, client-side interaction/integration | Explore, open the sketchbook, draw, submit PNG, and use a returned idea to cross a placeholder bridge |
| Beichun (Developer B) | AI interface, backend requests, image interpretation, validated JSON response | Accept Yanwen's PNG request and return real structured results without blocking exploration |
| Designer A | Art direction, player/NPC assets, compact level and coin-route layout | One readable zone with an optional nearby coin pocket |
| Designer B | Encounter rules/stat budgets, English script, ElevenLabs voice production, music/SFX, playtests | Solution/stat matrix, short script manifest, and audio samples |

- The developer split above is confirmed by the Day 1 task sheet. Designer responsibilities remain proposals. Assign final dialogue/voice wiring and Web deployment ownership explicitly; those are not implemented by the river prototype.
- Any teammate may submit the final package. The submitter posts confirmation and links for the team; yanwen checks the internal target and takes over if submission is still missing at 21:00 JST on September 15.
- Teammates may update this specification as meeting decisions evolve. Preserve the distinction between confirmed stage premises, proposed mechanics, and unresolved E04/E05 design; record the date and affected sections rather than silently treating suggestions as final.
- Both developers agree on session/request identity, item schema, pickup persistence, and input locking before separate implementation.
- Use a single movement base. Compare reuse candidates in an isolated spike rather than merging whole starter games into the main project.
- Assign each shared scene to one editor. Integrate at least twice daily with short-lived branches and verification notes.
- Godot can save files while external tools edit them; coordinate ownership and review reload prompts to avoid overwriting changes.
- Every ticket has an owner, priority, dependencies, and acceptance condition. A repository license applies to its covered files, not automatically to every bundled asset.

## 13. Four-day schedule and scope control

### Confirmed dates and submission ownership

All times are **Asia/Tokyo (JST, UTC+09:00)**.

| Milestone | Confirmed date/time | Meaning |
|---|---|---|
| Day 1 / production begins | Saturday, September 12, 2026 | The team has started; work and asset generation may begin now |
| Internal submission target | Before Tuesday, September 15, 2026 at 21:00 JST | Submit the playable URL and gameplay video before the last-evening rush |
| Submission fallback | September 15 at 21:00 JST if still unsubmitted | yanwen verifies status and takes over coordination/submission |
| Hard deadline | Tuesday, September 15, 2026 at 23:59 JST | Final submission cutoff reported by the user |

Machine-readable hard deadline: `2026-09-15T23:59:00+09:00`. Internal target boundary: `2026-09-15T21:00:00+09:00`; aim to finish before it.

Any teammate may submit. The person who does so should share the submitted URL, video link/file reference, timestamp, and confirmation/receipt in the team's shared channel. A deployed build alone is not proof that the competition submission has been completed.

### Working delivery plan

The five-stage route is now the baseline. E04 and E05 have reserved places but incomplete designs; those decisions are dependencies, not implemented content.

| Day / date | Main work | Exit condition |
|---|---|---|
| Day 1 — Sat, Sep 12 | Reuse/Web spike; controls and coins; drawing and real JSON; E01 river prototype; refine E02/E03 rules; discuss E04/E05 | Hosted E01 drawing-to-crossing loop works with exploration during processing; E02/E03 have concrete next tasks; unresolved E04/E05 choices have named discussion owners |
| Day 2 — Sun, Sep 13 | Complete E01–E03 interactions, safe async handling, traversal, dialogue controls; build E04/E05 from approved rules | First three stages are playable in order; E04/E05 rules are recorded and integrated or explicitly flagged as incomplete, not silently replaced by old scenarios |
| Day 3 — Mon, Sep 14 | Complete all five stages and ending; integrate art/voice; test full route; prepare gameplay recording | Beginning-to-ending five-stage build works; final content, narrated beats, coin tally, and principal blockers are addressed |
| Day 4 — Tue, Sep 15 | Feature freeze; browser regression; final video; license/credits check; submit and verify | Both required deliverables are submitted before 21:00 JST if possible; yanwen takes over any missing submission at 21:00; hard cutoff 23:59 JST |

### Decision gates

- Production may start now. Verify remaining portal, video-format/duration, browser/network, external-code and asset-use details without treating the known deadline or permission to begin as unanswered questions.
- Time-box the initial reuse/controller spike to about 2–3 hours; simplify integration if it fails rather than combining multiple frameworks.
- Proposed design target: settle the minimum E04 task/outcome and E05 boss loop by the end of Day 1, or at the next explicit team decision slot. This is a scheduling recommendation, not a claim that those designs are already approved.
- Until E04/E05 are decided, implement shared interfaces or clearly marked development stubs only. Do not finalize dependent art, voice, or combat rules from an assumed solution.
- End of Day 2: escalate any missing E04/E05 design or core-loop blocker so all five stages can be finished before final-day testing and recording.
- Before the internal submission target, verify the playable URL and video are accessible to judges, record the submission confirmation, and communicate who completed it.

### Cut order and limits

Reduce extra voices, second music, ambience, elaborate scenery, additional coin detours, and optional effects before removing a confirmed stage.

The river, dog, crows, otter, and final boss are the agreed sequence. Reducing the stage count requires an explicit team decision and corresponding spec update; do not silently revert to the earlier three-stage plan.

Preserve the requested traversal scope unless changed by the team, while keeping crates and climbing bounded. Preserve real AI, required JSON fields, original-art feedback, non-blocking processing, subtitles/voice, recovery, a complete boss/ending, and both submission deliverables.

## 14. Backlog ready for tickets

These are proposed tasks, not issues already created on GitHub.

| ID | Priority | Task | Owner | Dependencies | Acceptance |
|---|---|---|---|---|---|
| T01 | P0 | Remaining submission details, access, version, API/voice owners | Team | None | Shared starter runs; known dates recorded; portal/video/browser and external-code details checked |
| T02 | P0 | Reuse spike and minimal Web deployment | Both devs | T01 | Pinned candidate runs in 4.7.2 Compatibility on the actual host; licenses recorded |
| T03 | P0 | Walk/jump/sprint, fixed stage camera, interaction, checkpoint | Dev A | T02 | Grounded controls work; safe reset preserves session state |
| T04 | P0 | Canvas, snapshot, undo/clear | Dev B | T01 | Valid PNG submission; no empty calls or cursor conflicts |
| T05 | P0 | AI type/stats/tags contract and server bounds | Dev B + Designer B | T04 | All five requested fields returned and validated; malformed data is recoverable |
| T06 | P0 | Coin IDs, route pickups, counter and tally | Dev A + Designer A | T03 | Each coin counts once; fall/retry does not reset or duplicate it |
| T07 | P0 | Background request and non-modal ready/error lifecycle | Dev B | T03–T06 | Move/collect while pending; late reply, respawn, cancel and restart handled correctly |
| T08 | P0 | E01 river crossing and original-art stat card | Both devs | T05, T07 | Real drawing enables an approved safe crossing after a coin detour; narrator guides the first drawing |
| T09 | P0 | Bounded crate pushing and designated climb route | Dev A | T03, T06 | Safe optional traversal, no gate bypass or permanent blockage |
| T10 | P0 | Finalize E01–E03 solution rules and implement dog/crow interactions | Designer B + Dev A | T08 | Confirmed river/dog/crow premises implemented; accepted alternatives, stat use, gates and retry rules documented |
| T11 | P0 | English script and ElevenLabs production | Designer B | T10; T17/T18 for later-stage lines | Narrator covers E01 tutorial; E04/E05 voice is based on approved designs, with matching subtitles |
| T12 | P0 | Dialogue, subtitles, Voice channel and skip/ducking | Dev B | T11 | Next/Skip, missing audio, mute, and simultaneous ready notification behave correctly |
| T13 | P0 | BGM and ten SFX event categories | Designer B + Dev A | T06–T09 | Comfortable loop, pickup, traversal and AI-ready feedback without sound spam |
| T14 | P0 | Implement E04 otter, E05 boss, ending and final assets | Designer A + Dev A | T09, T10, T17, T18 | Five-stage route and approved boss victory reach the ending; no old otter-bag or final-bridge substitution |
| T15 | P0 | Limits, manual mode and final browser playtests | Both devs; Designer B coordinates | T12–T14 | Section 15 results recorded; real and simulated slow/failing requests tested |
| T16 | P0 | Gameplay video, credits, submission and confirmation | Any teammate; yanwen fallback | T15 | Playable URL and gameplay video submitted before Sep 15 21:00 JST target; yanwen takes over if missing; hard deadline 23:59 JST |
| T17 | P0 | Decide E04 otter task and outcome | Team design discussion | Confirmed five-stage sequence | Objective, valid solutions, outcome and any later help explicitly approved; no assumed quest |
| T18 | P0 | Decide E05 boss strategy and ending | Team design discussion | Confirmed five-stage sequence; T17 only if linked | Minimum boss loop, accepted drawings/stat use, failure/retry, victory and ending explicitly approved |

## 15. Acceptance and playtesting

### Functional checks

| Case | Expected result |
|---|---|
| First visit and Start | Controls, narration and subtitles guide E01 river crossing; sound starts without login; otter is not introduced as the tutorial NPC |
| WASD / arrow keys, jump, sprint, fixed stage camera | Consistent movement; no diagonal speed boost or UI input leakage; cursor stays visible and camera stays fixed |
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
| Confirmed stage order | River -> large dog -> crows -> otter -> final boss; no extra old scenario or skipped stage |
| Approved solution routes | Every finalized route is tested; two per stage remains the design target, not evidence of implemented routes |
| E01 river crossing | Approved drawing enables safe bank-to-bank traversal and opens E02 |
| E02 large dog | Approved weapon/action visibly resolves the confrontation and opens E03 |
| E03 crows | Approved protection/repelling effect resolves the flock and opens E04; no stolen-sign objective |
| E04 otter | Matches the task/outcome the team eventually records; a placeholder does not pass |
| E05 boss | Approved strategy, retry and victory rules work; not marked done while design remains open |
| Unrelated recognized item | Contextual retry message, no resource penalty |
| Invalid/missing type or stat, unknown tag, NaN, infinite or oversized text | Agreed validation/normalization prevents broken UI or unbounded game effects |
| Range, item speed and remaining durability | Range uses world units, speed never changes player sprint, and only a committed successful use spends durability once |
| Uncertain recognition | Redraw or clearly labeled purpose selection is available |
| Timeout, offline, 429, or provider error | Waiting ends; retry/manual mode remains available |
| Cancel/restart followed by late response | Old data cannot replace current state or advance the game; ordinary walking does not invalidate a valid request |
| Rapid Submit or Use clicks | One pending request and one resolution; no duplicate effects |
| Revisit solved encounter | Progress stays solved; rewards/sequences do not repeat |
| E01 crossings and E05 ending transition | Crossing endpoints are safe; boss resolution reaches the approved ending without requiring an invented bridge or otter-help condition |
| Ending and restart | Narrated ending and coin tally; full restart resets world/items/draft/coins/request generation and story flags |
| Muted playthrough | All required information remains understandable; SOUND tags still work |
| Two BGM loops, sustained drawing, rapid clicks | No obvious seam, duplicate music, clipping from piled-up sounds, or SFX spam |
| Walk, stop, push against wall, open panel | Footsteps reflect actual movement and stop correctly |
| Music/SFX/Voice volumes and mute/unmute | Independent levels and chosen values respected; English subtitles remain available |
| Dialogue Next/Skip, missing voice, repeat trigger | No duplicate progression or stuck panel; subtitle remains accurate; one-shot clips do not spam |
| Voice plus coin/AI-ready cues | Dialogue remains intelligible; no overlapping spoken lines; music returns to its chosen volume |
| Hide tab, return, and restart | No duplicate music or unwanted unmuting; no stuck movement |
| Two target window sizes | Readable text, accessible controls, correct drawing coordinates |
| Final URL on teammate device | Movement, drawing, AI, audio, and all five stages through the ending work |
| Required submission package | Both playable URL and gameplay video are accessible and entered into the submission portal; confirmation is recorded |
| Internal deadline fallback | At 21:00 JST on Sep 15, yanwen confirms completion or takes over the remaining submission work before 23:59 JST |

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

The game is done when P0 passes or an explicit scope revision is recorded, all five approved stages and the ending are playable, credits and limitations are documented, and the required playable URL plus gameplay video have been submitted with confirmation. Unresolved E04/E05 design is not completed content.

## 16. Open decisions

Already settled: production has begun on September 12; five-stage order and the first three premises; English content; playable URL plus gameplay video; September 15 at 23:59 JST hard deadline; before-21:00 submission target; any teammate may submit with yanwen as fallback. Do not reopen these as missing information without a new team decision.

| Question | Current status / proposal | Decide by |
|---|---|---|
| E04 otter task and outcome | Meeting the otter is confirmed; what to do, accepted drawings, reward and later help are open | Proposed target: end of Day 1, before dependent implementation/assets |
| E05 boss and winning strategy | Final boss is confirmed; identity/twist, actions, phases, stat use, retry and ending are open | Proposed target: end of Day 1, before dependent implementation/assets |
| E01–E03 exact solution rules | Premises confirmed; raft/sword/shield-umbrella are reference examples, not a complete ruleset | Day 1 design/integration |
| Submission portal and video details | URL and gameplay video required; video duration, format/hosting and portal fields not supplied | Before recording/final submission |
| Judge browser/network and remaining asset/code rules | Web delivery planned; exact constraints and reuse/disclosure details still to verify | Early Day 1 |
| Camera feel and player appearance | Fixed views per stage; E01 overhead orthographic. Later framing follows designers; illustrated or low-detail character | During controller spike |
| Coin purpose | Count and ending reward proposed; optional spending undecided | Before economy/UI implementation |
| Climbing scope | Marked ladder/vine and small crates proposed; not arbitrary walls | Before traversal implementation |
| Final setting and ending presentation | Storybook trail; paper/story boss and narrator connection are visual-reference proposals | E05 design decision, before final art/voice |
| Narrator/otter voices and exact English script | Pre-generated ElevenLabs clips and subtitles; later-stage lines await design | Before voice generation |
| Audio sources | Instrumental BGM, SFX and scripted voices | Before final audio selection |
| Item stat budgets and action coverage | Five fields required; dog/boss action rules determine their approved use | E02/E05 rules and integration |
| AI provider/model, account owner, spending cap | Not selected | Before real integration/public access |
| Named implementation owners | Role split remains a proposal; submission fallback already assigned to yanwen | Team task assignment |

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

This file is the shared scope reference and may be updated by teammates as decisions evolve. Pull the latest version, preserve others' changes, and record which decisions are confirmed versus proposed. When E04/E05 are resolved, update their stage sections, dependent tasks, rules, voice coverage and acceptance checks together. New features need an owner, an acceptance condition, and a clear tradeoff within the September 12–15 production window.

| Version | Date | Change |
|---|---|---|
| 0.7 | 2026-09-12 | Confirmed issue #12: location-gated full-viewport transparent drawing, hidden normal HUD, and cropped white-background black-ink PNG handoff |
| 0.6 | 2026-09-12 | Fixed per-stage camera supersedes mouse orbit; E01 uses stag01 creek art and overhead orthographic framing; temporary otter trial removed |
| 0.5 | 2026-09-12 | Team decision supersedes first-person with third-person: captured mouse orbit, camera-relative movement, independent visual facing, placeholder hiker, camera collision, and retained drawing input locks (issue #1) |
| 0.4 | 2026-09-12 | Confirmed first-person + E sketchbook + bridge-first prototype; recorded implemented graybox and mock limitations; assigned Yanwen canvas/client work and Beichun AI/backend work |
| 0.3 | 2026-09-12 | Recorded confirmed production/submission dates and yanwen fallback; replaced old three-stage proposal with river/dog/crows/otter/boss; first three premises confirmed, E04/E05 design open; synchronized schedule, tasks, voice and acceptance |
| 0.2 | 2026-09-12 | Added voiced narration/dialogue, background AI with playable coin collection, jump/sprint/bounded push/climb and mouse controls, five required item fields, reuse research, and corresponding milestones/tests |
| 0.1 | 2026-09-12 | Initial English specification; confirmed free walking, English-only project content, and warm/playful audio; encounter stories and camera details remain proposals |

## September 12 playtest update: construction and traversal

Approved: show a construction cloth at the drawing location, briefly zoom in,
return to exploration and drop near-bank coins; zoom in again to reveal the ready
object. Collection and provider completion are independent. Keep fixed camera angles,
allow edge-follow panning, and gently assist bridge traversal while preserving stop
and reverse input. Remove obsolete interior map boundaries while preserving real
terrain/prop collision. See [implementation and verification](ENCOUNTER_FLOW.md).
