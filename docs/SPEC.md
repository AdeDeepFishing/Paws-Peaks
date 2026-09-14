# Paws & Peaks — Game Jam Specification

> Version: 0.8 | Updated: 2026-09-13 | Status: Working draft
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
5. Keep trying inexpensive. Essential drawings stay free, and an exhausted item must never block the next attempt.
6. Combine open expression with finite mechanics. The player draws freely; the game executes a small set of implemented effects.
7. Let the player explore. Walking through the world and approaching problems are part of the experience.
8. Make music, sound effects, English narration, and dialogue part of the experience.
9. Keep AI processing non-blocking. Players can explore while a submitted drawing is being analyzed; E01 holds its construction camera as specified in #37.

### Audience and session

- First-time judges and casual players; no drawing or game expertise required.
- Target main-path playthrough: approximately 5–10 minutes; optional exploration may extend this. Check both with actual playtests.
- Primary target: desktop browser, keyboard and mouse or trackpad.
- No player account, personal API key, or installation required for the intended Web release.
- Mobile controls, pen pressure, and full keyboard-only drawing are outside the baseline unless competition rules require them. Controller traversal and panel navigation are an explicitly requested extension; drawing still uses a mouse or trackpad.
- All game text, repository documentation, code, comments, and textual asset content must be in English. Team conversation with the assistant may remain in Chinese.

## 2. Decisions and current status

September 13 contract update: AI items contain `name`, `description`, stage-specific
`type`, boolean `movable`, `texture_key`, and a `#RRGGBB` color tint. Interpretation identifies a likely common object
before classification and always returns an item when the call succeeds. Movable
objects fall under physics; fixed objects remain anchored. Numeric item stats and
capability tags are removed from the backend/game contract. This supersedes earlier stat/tag
planning references below; future encounter mechanics must be authored separately.
Stage 1 enables its fixed crossing for `BRIDGE` and no longer checks or spends
AI-generated durability.

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
| Coins and AI waiting | Updated September 13, #37 | Coins removed globally; E01 camera holds the construction view while processing |
| Coin spending | Removed, #37 | No coin economy or tally; essential drawings stay free |
| Language | Confirmed | English throughout the game and repository |
| Audio mood | Confirmed | Warm, comforting, and slightly playful |
| Background music and SFX | Confirmed | Required, with player volume controls |
| Narration and dialogue | Confirmed correction | English spoken narration and key NPC dialogue, with English subtitles |
| Voice production | Available option | User has an ElevenLabs subscription; proposed pre-generated audio, with exact voice/plan/credits still to verify |
| AI item fields | Required | `name`, `description`, stage-specific `type`, and boolean `movable`; no numeric stats or tags |
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
- The active Godot project is `3d_game/project.godot`, with `3d_game/scenes/overworld/overworld.tscn` as its startup scene. The map intro leads to `3d_game/scenes/river/river_crossing.tscn`. The Brackeys dungeon remains at `3d_game/main.tscn` as a reference.
- The first stage uses the supplied stag01 storybook creek, a placeholder hiker, camera-relative movement, a fixed overhead orthographic camera, walking/jumping/sprinting, transparent full-viewport drawing with transparent-background PNG export, a background request boundary with explicit mock responses, automatic encounter-object placement, a fixed bridge, fall recovery, and completion/restart. Desktop AI generation is connected through a persistent Python worker, with offline fixture and live modes; see [desktop integration](3d_game/DESKTOP_GENERATION.md). Visual output quality, final art/audio, push/climb, E04–E05 gameplay, and Web deployment remain incomplete. E02 implements the food/toy distraction encounter and E03 implements the giant bird protection encounter described below. GodotPhysics3D is enabled and the old Jolt extension is ignored; Forward Plus remains selected.
- Board linking, teammate permissions, export templates, API access, and hosting must be verified separately.
- Character integration update (2026-09-12): both playable scenes now use the supplied
  Moonlit Wanderer skinned model with idle, walk and run clips. Jumping retains a
  temporary held pose; see [HERO_INTEGRATION.md](3d_game/HERO_INTEGRATION.md). This replaces
  the placeholder hiker referenced in the earlier baseline above. Issue #22 adds a
  20% larger Stage 2 visual, quieter idle timing, running animation after three seconds
  of continuous walking (speed rises from 4.0 to 7.5 units/second), and a drawing-time thinking stand-in.

## 3. Release scope

### P0 — Required for the baseline submission

| ID | Feature | Minimum definition of done |
|---|---|---|
| F01 | Start and ending | Start button, concise controls, clear ending, credits, and restart |
| F02 | Traversal | Walk, jump, sprint, fixed stage camera, one bounded pushable-crate interaction, and a designated climb route |
| F03 | Proximity interaction | Approach an encounter, see a prompt, and interact with one clear target |
| F04 | Drawing canvas | One pen, undo last stroke, clear, submit, and back |
| F05 | Real AI interpretation | Analyze actual drawings and return validated name, description, and stage-specific type |
| F06 | Original-art object | Original sketch, interpretation, a readable item description, and visible use feedback |
| F07 | Five stages | River crossing, large dog, crows, otter, final boss in that order; finalize and implement the solution rules for all five before submission |
| F08 | Otter encounter | A complete fourth-stage interaction after the team defines the task and outcome; no assumed tutorial role or mandatory boss assistance |
| F09 | Recovery | Invalid objects, uncertainty, timeout, network failure, and repeated input cannot soft-lock play |
| F10 | Audio and voice | Looping BGM, essential SFX, narrated story beats, key NPC dialogue, subtitles, global mute, and Music/SFX/Voice volume |
| F11 | Web delivery | Hosted build supports movement, drawing, requests, sound, and a complete playthrough |
| F12 | Readability | Legible text, clear interaction prompts, and visual/text equivalents for necessary audio information |
| F13 | Submission package | Required playable URL and gameplay video, plus instructions, credits/notices, known limitations, and recorded submission confirmation |
| F14 | Retired: coins (#37) | No coin pickups, counters, spending, or ending tally in the active game |
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
- Mandatory paid drawing attempts, a full shop/trading system, and a crafting economy. Coin pickups, spending and tallies are removed by #37.
- Multiplayer, accounts, leaderboards, cloud saves, and mandatory persistent progress.
- Free-form NPC chat, player voice input, runtime music generation, and mandatory runtime speech synthesis of every generated item. Pre-generated narration and key NPC dialogue are included.
- Pet progression, a general companion navigation system, or dynamically simulated bridges and water.

## 4. Exploration, traversal, camera, and coins

**Free exploration and recoverable AI processing remain baseline requirements. Coins are removed globally by #37.** The requested traversal abilities are included as small, testable implementations rather than an unrestricted parkour system.

### World layout

- One compact 3D route with five ordered stage zones: river, large dog, crows, otter, and final boss. Previously opened areas remain accessible; the exact ending location is still a story decision.
- Keep routes and waiting areas traversable without collectible-coin detours.
- Each processing area offers a short loop: a low jump ledge or a reusable traversal toy. Players can start exploring immediately after submission.
- Place at least one small pushable crate and one marked climb route in the game. These are optional traversal detours, so controller problems cannot block the main drawing path.
- Keep the main route readable through landmarks, NPC placement, and visible gates; do not require a minimap.
- Keep main-route travel short, initially about 10–20 seconds between encounters. Optional detours should be nearby, not lengthy distractions from the result.
- Route gates must remain effective against sprint-jumps and crate-assisted jumps. Validate maximum reach when setting their geometry.
- Use static authored scenery and simple collision. No generated terrain, physical bridge simulation, or mandatory precision platforming.

### Controls — confirmed first-stage prototype and later proposals

| Action | Input | Behavior |
|---|---|---|
| Move | WASD or arrow keys | Camera-relative ground movement; character turns toward travel. After three continuous grounded seconds, automatically run at 7.5 units/second instead of walking at 4.0; stopping resets this |
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
- Falling or becoming stuck returns the player to a safe checkpoint, preserving solved encounters and the active AI request. Do not reload the entire scene or restart the network call.
- The otter can appear at scripted locations; a companion navigation system is not required.

### Coins removed (#37)

The September 13 direction removes coins from all active stages. Do not spawn
pickups, show a counter or ending tally, play coin pickup sounds, or use a coin
economy to gate drawing. The earlier coin/reward proposals are superseded.
The existing collectible implementation was in E01; later active stages have no
coin pickups. Original dungeon reference assets are separate from this gameplay.

## 5. Player flow and asynchronous state

```text
Start -> Narration -> Explore -> Approach stage target -> Observe / dialogue -> Draw
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
| EXPLORING | Walk, jump, sprint, push, climb, and inspect scenery |
| DIALOGUE / OBSERVING | Read/listen to encounter dialogue; open drawing or return |
| DRAWING | Edit a draft; movement and camera input are suspended |
| ITEM_VIEW | Read artwork, interpretation, and classification; close, redraw, or use if near the correct target |
| RESOLVING | Watch a short authored result; player movement is temporarily suspended |
| ENDING | Read/listen to conclusion, view credits, or restart |

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
- Solved encounters persist throughout the session. Full restart resets progress, items, drafts, pending context, and one-shot dialogue flags.
- Keep an upper bound on waiting even while the player is occupied. Re-evaluate deadlines when the browser regains focus; hidden-tab suspension must not leave a request pending indefinitely.
- No required persistent save in this release. Refresh may restart the session; record that limitation in the README.

## 6. Five-stage progression and design status

**Meeting update, September 12:** retain the five-stage sequence shown in the team's Concept 01 image. The river, large dog, and crows are confirmed stage premises. The otter belongs in Stage 4, and the final boss belongs in Stage 5, but their detailed tasks and solutions remain open.

The image's Japanese writing is reference material only. All shipped titles, narration, dialogue, UI, and repository text remain English. Sketches in the reference suggest example objects; they do not by themselves settle every allowed solution, stat threshold, or combat rule.

### Stage overview

| ID | Working English title | Confirmed content | Still to decide |
|---|---|---|---|
| E01 | Across the River | The player needs to reach the far bank of a river too wide to cross unaided; draw something useful | Supported crossing objects, alternative routes, trigger and reach/size rules |
| E02 | The Large Dog | Draw food or a toy to distract the dog and clear its guarded path (#38) | Live recognition playtesting and final audio |
| E03 | The Crows | A flock descends and blocks or harasses the player; draw an object to deal with them | How shielding/repelling works, accepted alternatives, duration and success condition |
| E04 | Meeting the Otter | The player meets an otter in the fourth stage | What it needs, how the player helps or interacts, and any later help/reward |
| E05 | Final Boss | The fifth stage is the final boss encounter | Final identity/presentation, phases or actions, winning strategy, failure/retry rules, and ending |

E01–E05 now have these meanings in scene configuration, prompt context, fixtures, scripts, and voice manifests. The former otter-bag tutorial, stolen-sign crow scenario, and final broken crossing are superseded; do not implement them as additional levels.

### E01 — Across the River

- **Confirmed September 13, #37:** move the bridgehead stone and its painted overlay
  away from the crossing while retaining collision at the new position. Bring the
  normal view approximately 18% closer and double the Stage 1 character visual.
- **Generation camera:** slowly focus the construction site over two seconds; hold
  that view throughout processing; reveal the finished object for two seconds,
  then ease back to normal over one second. Fast results wait for the opening
  move. Cancellation/failure restores the normal view. Exploration and cancellation
  remain available after the initial camera move, while camera following pauses.
- **Coins:** removed globally, including pickups, HUD counters and release effects.
  See [current implementation and validation](3d_game/ENCOUNTER_FLOW.md).

- **Confirmed classification (September 13):** backend classes are BRIDGE, BOAT, UNKNOWN. This changes recognition categories; it does not implement the deferred boat/raft traversal route.

- **Confirmed premise:** the player wants to reach the other bank, but the river is too wide to cross unaided.
- **Reference example:** the concept shows a raft-like drawing. Preserve the experience of drawing an aid and then using it to cross.
- **Implementation proposal:** use E01 for the first drawing tutorial, guided by the narrator and short English UI prompts. The otter does not appear as the tutorial guide.
- **Confirmed Day 1 implementation:** a fixed, walkable bridge using a long and sturdy idea. The prototype accepts class BRIDGE and commits placement once. Dimensions and collision are authored; no AI stats or tags are required. The raft route is deferred; additional supported solutions remain design work.
- Use authored crossing positions and a safe endpoint instead of simulating water or arbitrary bridge construction. Prevent normal jumps or crate-assisted jumps from bypassing the intended crossing.
- While analysis runs, the player may explore and collect in a safe near-bank pocket. Returning a ready result must not start the crossing automatically.
- **Completion:** using an accepted object gets the player safely to the far bank and opens E02.
- **Acceptance:** the player learns draw -> submit -> explore while waiting -> inspect -> use; approved crossing routes work; failures preserve the draft and permit retry.

### E02 — The Large Dog

- **Confirmed September 13, issue #38:** this is a drawing-driven distraction encounter.
  It supersedes the earlier sword/confrontation proposal. On arrival the dog walks
  a continuous oval across the path, plays Idle Alert when the protagonist approaches,
  and walks or runs across the path
  to intercept attempts to pass. There is no damage or combat requirement.
  Retreating resumes patrol; drawing pauses both movement and the walking clip.
  Collection stops patrol and leaves the dog idle beside the offering.
- Backend classes remain FOOD, TOY, WEAPON, UNKNOWN. FOOD (for example an apple) and
  TOY (for example a toy bone) are the supported solutions.
  WEAPON and UNKNOWN give a contextual retry; they never open the route.
- Submission surrounds the sketch with shared pearl-white particles and local blur.
  The camera slowly focuses on the generation location and holds until generation finishes. Reveal only
  the 3D object, hold for two seconds, then restore the normal camera. The original
  sketch stays in the canvas, not as an overlay beside the finished model.
  Only after zoom-out does the dog show a heart, jump once, run toward it, slow to a
  walk and collect it. It then displays “Thank you!” while remaining off the path.
- The forward boundary is blocked at every lateral position and jump height until
  collection finishes. The E03 exit also checks encounter completion independently.
  Once cleared, the full-width z=-28 exit works as before.
- One accepted offering starts the distraction once. Dog travel speed and the offering
  position are authored; no numeric item stats are required or consumed.
- Drawing pauses protagonist input and dog pursuit. Processing restores exploration
  after the initial camera movement;
  it cannot unlock passage. Failed, unclear and canceled results preserve the draft
  for retry, and stale/duplicate results cannot replay the resolution.
- The drawing button stays visible during exploration and glows near an available
  challenge. The normal HUD is hidden while drawing. E02 allows drafting away from
  the dog, but submission/offer requires returning within interaction range.
- **Completion:** the dog collects FOOD or TOY, leaves the main path clear, and unlocks E03.
- **Verification status:** desktop/offline integration and recovery are covered in
  [the implementation note](3d_game/DOG_ENCOUNTER.md). This does not assert paid live
  recognition accuracy or Web backend availability.

### E03 — The Giant Bird (#34)

- **Confirmed September 13:** one very large bird guards Wind Hill. This supersedes
  the earlier multiple-crow premise. The supplied Moonwing flies in from the distant
  upper-right sky over 5.5 seconds. Keep its giant world scale fixed; the depth of
  its approach makes it appear small far away and large near the protagonist.
- The bird flies near the protagonist, who automatically ducks and leans away.
  No damage or timing challenge is introduced by this encounter.
- Draw a protective object such as an umbrella or shield. DEFENCE is the supported
  route for this implementation; BOW, MAGIC and UNKNOWN produce a contextual retry.
  The backend identity remains E03 / crows, with its existing class vocabulary.
- Surround the sketch with particles and local blur, focus the generation location,
  reveal the 3D model, hold two seconds,
  then restore the normal camera. The original sketch overlay disappears when the
  model is presented. Raise the protection, show the bird retreat and fly away,
  then unlock the path to Sunset Cove. Protection stays with the protagonist and
  grows to a ten-unit width when raised, matching the giant bird's scale.
- Block the rightward route at every depth and jump height until departure completes.
  Drawing pauses the encounter; cancellation/errors preserve the latest draft and
  restore controls. Late or duplicate replies never unlock the route.
- See [Bird encounter](3d_game/BIRD_ENCOUNTER.md) for implementation, supplied assets,
  offline test coverage and live/Web verification limits.

### E04 — Meeting the Otter — DETAILS OPEN

- **Implemented greeting (September 14):** the otter idles by the water, faces the player, loops its wave while the player is more than 2.5 units away, and returns to idle on approach. One model shares all 13 imported animation clips and saved selection descriptions. Within 2.5 units, the player can submit a sketch labeled E04 / otter, carrying the animation options. The first AI call selects a reaction; the otter looks confused until the model appears, then plays that reaction. Stage resolution remains open.

- **Updated September 14:** Stage 4 identifies the object without classification and selects one reaction from the otter animation descriptions. The otter task, gameplay effects and success rules remain open.

- **Confirmed:** the fourth stage features meeting the otter. It follows the crow encounter.
- **Reference tone:** a small otter appears lonely or interested in company. The illustration suggests gifts or play, including fish, flowers, or friendship motifs.
- **Not yet decided:** the actual need/task, accepted drawings, success condition, dialogue, reward, and whether the otter provides later assistance.
- These illustrated possibilities are discussion inputs, not a finalized feeding quest, fetch quest, friendship meter, or combat companion.
- Reserve a stage scene, interaction point, and transition to E05. A development stub may keep integration moving but does not count as a completed submission stage.
- **Decision required before final implementation:** write the player's objective, supported solution routes, visible outcome, and any persisted otter state. Add a later-help dependency only if the team explicitly adopts it.

### E05 — Final Boss — DETAILS OPEN

- **Confirmed:** the fifth stage is a final boss encounter, followed by the ending.
- **Confirmed visual (September 14, #36):** use the supplied Storykeeper GLB as a giant figure of pages, with its authored hand-lift and body-sway loop.
- **Reference concept only:** the illustration labels the boss as the story itself, with a possible connection to the narrator. That identity/twist is not confirmed by the visual integration. Personality/agent work is reserved for #63.
- **Not yet decided:** the boss's final identity, behavior, attacks or phases, what the player draws, the winning strategy, role of item statistics, failure/retry behavior, and the ending.
- Do not prescribe a sword-only fight, a health-bar system, a fixed phase count, an otter-assisted victory, or a specific ending without team agreement.
- Reserve a boss scene and ending transition for integration. A placeholder is not a finished boss.
- Preserve safe background processing, original-art use feedback, and valid retry paths regardless of the eventual boss design.
- **Decision required before final implementation:** define one minimum complete boss loop and its ending, then document any alternative solutions. Update affected state flags, class-based rules, voice lines, and tests together.

### Classification and solution rules

The backend returns `name`, `description`, `type`, and `movable`; capability tags and numeric
stats are not required. Stage-specific classes are defined in
[the backend contract](backend/BACKEND.md#approved-classes). River accepts `BRIDGE`
for its authored crossing; Dog accepts `FOOD` or `TOY` for distraction. Remaining-stage effects and success conditions remain
separate gameplay design decisions; classification alone does not implement them.

The design target remains multiple reasonable solutions. Record accepted/rejected
examples, authored actions, and feedback for each finalized route. Test varied
sketches before locking rules, including rough, unrelated, and text-bearing inputs.

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
- E01 now presents the resulting object directly at its encounter location; original drawings remain saved as input data, not attached paper props. Other stages’ item presentation remains to be designed.
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

- AI: analyze the drawing and return a name, short description, and stage-specific object type.
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
    "type": "BRIDGE"
  }
}
```

- Proposed limits: name up to 40 characters, description up to 160 characters, displayed as plain text.
- Tags contain one or two unique allowed values. Unsupported values invalidate the response.
- For an unclear image, return the same version/request fields with `status: "uncertain"` and `item: null`.
- A recognizable object outside the selected stage’s classes may return `recognized` with `type: UNKNOWN`.
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

### Required item fields and gameplay use

Recognized items contain exactly `name`, `description`, stage-specific `type`, boolean `movable`,
`texture_key` from the shared material palette, and an opaque `color` hex tint.
Validate their string types, lengths, and classification membership against the
[backend contract](backend/BACKEND.md#item-validation). Unknown but recognizable
objects use `UNKNOWN`; ambiguous drawings receive a best-effort common-object guess.
No numeric statistics or tags are generated, validated, displayed, or consumed.
Game rules use the class and authored encounter behavior. Manual mode must return
the same six-field item with clear manual provenance.

### Waiting, cancellation, and fallback

- Initial experience target: normal interpretation within 8 seconds. Measure it; it is not a provider guarantee. The game must already be playable during this interval.
- Initial client timeout: 15 seconds, then show a non-modal failure notification with retry/manual options. Movement and collection remain available before and after timeout.
- No infinite automatic retries. A retry is a deliberate click; repeated failure makes fallback prominent.
- Disable repeated submission while waiting, not player movement. Ignore canceled/obsolete replies while preserving valid replies received after ordinary exploration.
- Client cancellation does not guarantee the provider stopped processing or charging.
- Manual mode allows players to select a supported purpose and uses the same encounter rules. Label it “Manual mode” or equivalent; never imply AI recognized the image.
- Fallback must allow completion, but it cannot count as proof that the real AI integration works. Do not artificially extend processing to match a traversal route or a voice clip.

### Credentials, spending, and images

- Keep provider keys in server-side environment variables, never in Git, Godot resources, or browser bundles.
- Set upload limits, server-side request limits, and a spending ceiling before sharing a public URL. The account owner must choose the actual quota and budget.
- Do not treat an embedded client token, CORS, or a freely recreated client ID as sufficient abuse prevention.
- Keep only the latest optional draft export across encounters (`user://drawings/latest.png`),
  replacing it after a valid submission and removing old timestamped test exports.
  Pending requests keep independent snapshots so another draft cannot alter their input.
  Send only the image and necessary context.
- Verify the provider's separate retention policy before making any privacy promise.
- Briefly disclose near the first submission that the drawing is sent to an AI service. No personal information is required.

## 9. Art, interface, and asset delivery

### Visual direction

- A warm storybook route with a broad river, a large dog, one giant bird, an otter area, and a final boss space. Mountain/ruin scenery is a visual direction; the final setting and ending view remain open.
- Gentle, playful stakes; no realistic violence required.
- Use simple 3D scenery with illustrated characters or props where helpful. Keep the camera and asset pipeline achievable for beginners.
- Paper framing or soft shadows can integrate rough player artwork into the scene.
- A readable walking character is required. Two-dimensional illustration frames on a 3D body are acceptable; complex rigging is not required.
- Establish character scale, ground contact point, facing convention, and idle/run/jump/climb appearance before final assets. Reuse suitable controller animations and allow simple pose changes to keep production bounded.

### Required interface

- Title: game name, Start, controls preview, sound control, and Credits.
- World: proximity prompt, current objective, non-modal AI pending/ready/error status, and sound control.
- Encounter panel: problem, Draw, current item if available, and Back.
- Canvas: drawing area, Undo, Clear, Submit, and Back/Cancel.
- Item card: sketch, name, interpretation, five required item fields, Use, and Draw again.
- Feedback: outcome and the next available action.
- Ending: narrated completion, Restart, and Credits.
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
- Reuse one suitable CharacterBody3D-based controller/starter after a compatibility spike. Validate movement, camera, and respawn in a graybox; do not combine several complete controller frameworks.
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
| AIClient / RequestManager | Background lifecycle, originating encounter, timeout, errors, item contract validation, ready notification | Movement locks or scene progression |
| EncounterController | Tag rules, result sequence, route unlocking | Generated code execution |
| ItemCard | Original artwork, text, Use and Redraw actions | Credentials |
| AudioManager | Music, SFX, Voice, mixing, volume, mute | Gameplay success |
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
  backend/          # Backend setup, pipeline contracts, and historical measurements
  3d_game/          # Game integration, drawing, stages, and reuse research
    REUSE_RESEARCH.md
  CREDITS.md        # Planned asset attribution and team credits
```

Decide the server code location after selecting the hosting approach. Fixed responses may unblock early integration, but must be marked as test mode and replaced with a real call in the Day 1 vertical slice.

### Web acceptance environment

- Verify the actual HTTPS deployment, not only F5 inside Godot.
- Open it on another team member's device to expose local-path or developer-session dependencies.
- Initial primary acceptance browser: desktop Chrome. Perform a basic Safari smoke check and record differences.
- If the competition mandates a browser or embedded player, test that exact environment as well.
- Verify movement/jump/sprint, fixed camera, push/climb, focus changes, canvas coordinates, route gates, and recovery while a real request is pending.
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
| Designer A | Art direction, player/NPC assets, compact level and waiting-area layout | One readable zone with an optional nearby activity pocket |
| Designer B | Encounter rules, English script, ElevenLabs voice production, music/SFX, playtests | Solution matrix, short script manifest, and audio samples |

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
| Day 1 — Sat, Sep 12 | Reuse/Web spike; controls; drawing and real JSON; E01 river prototype; refine E02/E03 rules; discuss E04/E05 | Hosted E01 drawing-to-crossing loop works with exploration during processing; E02/E03 have concrete next tasks; unresolved E04/E05 choices have named discussion owners |
| Day 2 — Sun, Sep 13 | Complete E01–E03 interactions, safe async handling, traversal, dialogue controls; build E04/E05 from approved rules | First three stages are playable in order; E04/E05 rules are recorded and integrated or explicitly flagged as incomplete, not silently replaced by old scenarios |
| Day 3 — Mon, Sep 14 | Complete all five stages and ending; integrate art/voice; test full route; prepare gameplay recording | Beginning-to-ending five-stage build works; final content, narrated beats and principal blockers are addressed |
| Day 4 — Tue, Sep 15 | Feature freeze; browser regression; final video; license/credits check; submit and verify | Both required deliverables are submitted before 21:00 JST if possible; yanwen takes over any missing submission at 21:00; hard cutoff 23:59 JST |

### Decision gates

- Production may start now. Verify remaining portal, video-format/duration, browser/network, external-code and asset-use details without treating the known deadline or permission to begin as unanswered questions.
- Time-box the initial reuse/controller spike to about 2–3 hours; simplify integration if it fails rather than combining multiple frameworks.
- Proposed design target: settle the minimum E04 task/outcome and E05 boss loop by the end of Day 1, or at the next explicit team decision slot. This is a scheduling recommendation, not a claim that those designs are already approved.
- Until E04/E05 are decided, implement shared interfaces or clearly marked development stubs only. Do not finalize dependent art, voice, or combat rules from an assumed solution.
- End of Day 2: escalate any missing E04/E05 design or core-loop blocker so all five stages can be finished before final-day testing and recording.
- Before the internal submission target, verify the playable URL and video are accessible to judges, record the submission confirmation, and communicate who completed it.

### Cut order and limits

Reduce extra voices, second music, ambience, elaborate scenery, additional traversal detours, and optional effects before removing a confirmed stage.

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
| T05 | P0 | AI item contract and validation | Dev B + Designer B | T04 | Name, description, and stage-specific type returned and validated; malformed data is recoverable |
| T06 | Retired (#37) | Coin pickups, counter and tally removed | Dev A | None | Active scenes contain no coin pickups or counter |
| T07 | P0 | Background request and non-modal ready/error lifecycle | Dev B | T03–T06 | Move while pending; late reply, respawn, cancel and restart handled correctly |
| T08 | P0 | E01 river crossing and original-art item presentation | Both devs | T05, T07 | Real drawing enables an approved safe crossing after the generation presentation; narrator guides the first drawing |
| T09 | P0 | Bounded crate pushing and designated climb route | Dev A | T03, T06 | Safe optional traversal, no gate bypass or permanent blockage |
| T10 | P0 | Finalize E01–E03 solution rules and implement dog/crow interactions | Designer B + Dev A | T08 | Confirmed river/dog/crow premises implemented; accepted alternatives, authored actions, gates and retry rules documented |
| T11 | P0 | English script and ElevenLabs production | Designer B | T10; T17/T18 for later-stage lines | Narrator covers E01 tutorial; E04/E05 voice is based on approved designs, with matching subtitles |
| T12 | P0 | Dialogue, subtitles, Voice channel and skip/ducking | Dev B | T11 | Next/Skip, missing audio, mute, and simultaneous ready notification behave correctly |
| T13 | P0 | BGM and ten SFX event categories | Designer B + Dev A | T06–T09 | Comfortable loop, pickup, traversal and AI-ready feedback without sound spam |
| T14 | P0 | Implement E04 otter, E05 boss, ending and final assets | Designer A + Dev A | T09, T10, T17, T18 | Five-stage route and approved boss victory reach the ending; no old otter-bag or final-bridge substitution |
| T15 | P0 | Limits, manual mode and final browser playtests | Both devs; Designer B coordinates | T12–T14 | Section 15 results recorded; real and simulated slow/failing requests tested |
| T16 | P0 | Gameplay video, credits, submission and confirmation | Any teammate; yanwen fallback | T15 | Playable URL and gameplay video submitted before Sep 15 21:00 JST target; yanwen takes over if missing; hard deadline 23:59 JST |
| T17 | P0 | Decide E04 otter task and outcome | Team design discussion | Confirmed five-stage sequence | Objective, valid solutions, outcome and any later help explicitly approved; no assumed quest |
| T18 | P0 | Decide E05 boss strategy and ending | Team design discussion | Confirmed five-stage sequence; T17 only if linked | Minimum boss loop, accepted drawings and authored actions, failure/retry, victory and ending explicitly approved |
| T19 | Unprioritized | Two-image interpretation: sketch plus optional scene/reference context | Unassigned | T05; define second-image role | [Backend acceptance criteria](backend/BACKEND.md#backlog); one-image requests remain compatible; no implementation yet |

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
| First real drawing | Original artwork plus validated name, description, and stage-specific type become an item |
| Submit and continue playing | Canvas closes; walk/jump/sprint work while the request stays pending |
| AI returns during jumping, climbing, or dialogue | Non-modal notification persists; no camera theft, teleport, or speech interruption |
| Leave origin area and revisit solved ground while pending | Result stays bound to the original encounter and can be inspected later |
| Fall/respawn while pending | Request, solved states and narration flags remain valid |
| E01 generation timing | Camera stays in construction view until completion; finished object holds two seconds, then normal framing returns |
| Empty drawing | No network call; useful feedback |
| Release pointer outside canvas | Stroke ends correctly; other controls remain usable |
| Undo, clear, and reopen canvas | Draft behavior matches Section 7; progress is unchanged |
| Confirmed stage order | River -> large dog -> crows -> otter -> final boss; no extra old scenario or skipped stage |
| Approved solution routes | Every finalized route is tested; two per stage remains the design target, not evidence of implemented routes |
| E01 river crossing | Approved drawing enables safe bank-to-bank traversal and opens E02 |
| E02 large dog | FOOD/TOY visibly distracts the dog; collection opens E03; bypasses and unrelated drawings remain blocked |
| E03 giant bird | Enlarged DEFENCE protection blocks one giant bird; its departure opens E04; failed or unrelated drawings preserve the gate |
| E04 otter | Matches the task/outcome the team eventually records; a placeholder does not pass |
| E05 boss | Approved strategy, retry and victory rules work; not marked done while design remains open |
| Unrelated recognized item | Contextual retry message, no resource penalty |
| Invalid/missing type or stat, unknown tag, NaN, infinite or oversized text | Agreed validation/normalization prevents broken UI or unbounded game effects |
| Class-based crossing | BRIDGE enables the authored crossing exactly once; UNKNOWN and BOAT do not; no AI stats or tags are required |
| Uncertain recognition | Redraw or clearly labeled purpose selection is available |
| Timeout, offline, 429, or provider error | Waiting ends; retry/manual mode remains available |
| Cancel/restart followed by late response | Old data cannot replace current state or advance the game; ordinary walking does not invalidate a valid request |
| Rapid Submit or Use clicks | One pending request and one resolution; no duplicate effects |
| Revisit solved encounter | Progress stays solved; rewards/sequences do not repeat |
| E01 crossings and E05 ending transition | Crossing endpoints are safe; boss resolution reaches the approved ending without requiring an invented bridge or otter-help condition |
| Ending and restart | Narrated ending; full restart resets world/items/draft/request generation and story flags |
| Muted playthrough | All required information remains understandable; SOUND tags still work |
| Two BGM loops, sustained drawing, rapid clicks | No obvious seam, duplicate music, clipping from piled-up sounds, or SFX spam |
| Walk, stop, push against wall, open panel | Footsteps reflect actual movement and stop correctly |
| Music/SFX/Voice volumes and mute/unmute | Independent levels and chosen values respected; English subtitles remain available |
| Dialogue Next/Skip, missing voice, repeat trigger | No duplicate progression or stuck panel; subtitle remains accurate; one-shot clips do not spam |
| Voice plus AI-ready cues | Dialogue remains intelligible; no overlapping spoken lines; music returns to its chosen volume |
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
- Is traversal enjoyable during a deliberately slow test response? Do players notice readiness and know how to return to their encounter?
- Does the held construction view remain understandable during a long request, and can the player recover from failure without coaching?
- Are narration/dialogue understandable and skippable? Are music, footsteps and pencil sounds comfortable, and are Voice/mute controls easy to find?
- Does the main path roughly fit 5–10 minutes, with optional exploration extending it naturally?

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
| Remaining E01 alternatives | E02 food/toy distraction is confirmed in #38; E03 protection is implemented in #34; E01 alternatives remain open | Design/integration |
| Submission portal and video details | URL and gameplay video required; video duration, format/hosting and portal fields not supplied | Before recording/final submission |
| Judge browser/network and remaining asset/code rules | Web delivery planned; exact constraints and reuse/disclosure details still to verify | Early Day 1 |
| Camera feel and player appearance | Fixed views per stage; E01 overhead orthographic. Later framing follows designers; illustrated or low-detail character | During controller spike |
| Coin purpose | Removed globally by #37 | Settled September 13 |
| Climbing scope | Marked ladder/vine and small crates proposed; not arbitrary walls | Before traversal implementation |
| Final setting and ending presentation | Storybook trail; paper/story boss and narrator connection are visual-reference proposals | E05 design decision, before final art/voice |
| Narrator/otter voices and exact English script | Pre-generated ElevenLabs clips and subtitles; later-stage lines await design | Before voice generation |
| Audio sources | Instrumental BGM, SFX and scripted voices | Before final audio selection |
| Item classes and action coverage | Three-field item contract confirmed; E02 accepts FOOD/TOY; boss actions remain open | E05 rules and integration |
| AI provider/model, account owner, spending cap | Not selected | Before real integration/public access |
| Named implementation owners | Role split remains a proposal; submission fallback already assigned to yanwen | Team task assignment |

## 17. Reuse strategy and researched candidates

See [REUSE_RESEARCH.md](3d_game/REUSE_RESEARCH.md) for source links, version pins, license distinctions, maintenance evidence, and missing features. These are researched candidates, not dependencies already installed or tested in our game.

- Initial movement/coin candidate: [Kenney 3D Platformer Starter Kit](https://github.com/KenneyNL/Starter-Kit-3D-Platformer). Reuse its narrow movement/collection foundation after the Web spike, not the entire game unchanged.
- Controller alternative: [GDQuest Godot 4 third-person controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller). Inspect code separately from assets; asset permissions differ from the code license.
- Dialogue candidate: [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager). Evaluate for authored conversations; line-based voice playback/subtitles still need integration.
- Drawing and texture references: [Godot official demos](https://github.com/godotengine/godot-demo-projects). Copy only a relevant example after verifying its engine/API version and license.

### Adoption gate

1. Choose a specific commit/release; retain the code license and check bundled art/audio separately.
2. Test in an isolated copy using our exact Godot version and Compatibility renderer.
3. Verify Web export, mouse/UI switching, jump/sprint, pickup persistence, and checkpoint respawn.
4. Keep request state outside reloadable scenes. Replace any starter's whole-scene reload on falling.
5. Add bounded push/climb only where missing; do not assume the chosen starter includes them.
6. Verify drawing snapshot/undo and prerecorded voice needs separately. A platformer base does not supply sketch interpretation.
7. Record adopted upstream pins, local changes, licenses and required notices. Import no whole repository solely because it appears mature or popular.

## 18. References and changes

- [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html): rendering, export, browser networking, and audio constraints. Recheck against the team's installed version during implementation.
- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): starting point for script-controlled movement and collision.
- [Godot InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html): named input actions.
- [ElevenLabs Text to Speech](https://elevenlabs.io/docs/overview/capabilities/text-to-speech): voice-generation capability; exact account access remains unverified.
- [ElevenLabs audio downloads](https://help.elevenlabs.io/hc/en-us/articles/14129286847505-How-do-I-download-generated-files-from-Text-to-Speech): exporting generated clips for an asset workflow.
- [Reuse research](3d_game/REUSE_RESEARCH.md): verified candidate evidence and adaptation limits.
- [Repository](https://github.com/AdeDeepFishing/Paws-Peaks)
- [Four Otters - Dev Board](https://github.com/users/AdeDeepFishing/projects/1/views/1)

This file is the shared scope reference and may be updated by teammates as decisions evolve. Pull the latest version, preserve others' changes, and record which decisions are confirmed versus proposed. When E04/E05 are resolved, update their stage sections, dependent tasks, rules, voice coverage and acceptance checks together. New features need an owner, an acceptance condition, and a clear tradeoff within the September 12–15 production window.

| Version | Date | Change |
|---|---|---|
| 0.8 | 2026-09-13 | Confirmed #37 river framing, stone relocation, generation hold and global coin removal; #38 dog distraction and iridescent drawing prompt |
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
terrain/prop collision. See [implementation and verification](3d_game/ENCOUNTER_FLOW.md).

## September 12 asset update: Stage 2 woodland

The supplied woodland environment is now available as a playable scene preview
with its reference camera, wind/shadow animation and player movement. Stage 1
now transitions into it when the player keeps walking along the far bank,
without a completion modal. This original environment integration did not settle
E02 encounter rules; the September 13 issue #38 update below supersedes that status. See
[Stage 02 integration](3d_game/STAGE02_INTEGRATION.md).

## September 12 asset update: Stage 3 Wind Hill

The supplied Wind Hill environment is available as a playable Stage 3 preview,
reached automatically by walking into the lakeside white birch area in Stage 2,
at the location selected by the user. It includes restored painted
textures, the reference camera, shared protagonist, terrain collision and the
16-second wind animation. The user requested wind slightly below maximum; the
preview uses 80% of the delivered deformation amplitude. E03 crow interaction,
solution rules and progression to E04 remain open. See
[Stage 03 integration](3d_game/STAGE03_INTEGRATION.md).

September 13 playtest correction: the Stage 2 exit is a full-width boundary at
world z=-28. Reaching it at any X position, including beside the path or during
a jump, enters Stage 3. It no longer requires overlap with a narrow path area.

## September 13 asset update: Stage 4 Sunset Cove (#31)

The supplied Sunset Cove is available as a playable environment preview. Stage 3
progresses horizontally to the right: reaching the large rock's near edge at
world x>=9.5 enters Stage 4, with no restriction on Z position or jump height.
This follows the user's requested vertical screen boundary and requires no jump
onto the rock. Stage 4 includes the delivered terrain, camera, shared protagonist,
painted materials and exported animation, with native water and sky motion and
live planar water reflections.
E04 otter gameplay remains open. See
[Stage 04 integration](3d_game/STAGE04_INTEGRATION.md) for checks and visual limits.

## September 13 asset update: Stage 5 Moonlit Forest (#32)

The designer's Moonlit Forest V5 replaces V4 as the playable environment preview,
including revised ancient trees, nine midground trees, watercolor hills and
woodland, a new night sky and 20 cloud layers/wisps.
Walking right to Stage 4's cave approach at world x>=5.5 enters Stage 5 across
all depth positions and jump heights. The forest retains the delivered painted
assets, camera, cloud/canopy/firefly animation and lights, with native foliage
wind, night lighting, terrain collision, the shared protagonist and return
navigation. This completes scene integration only; E05 final boss gameplay (#36)
remains open. The ending presentation is connected as described in the #52 update below.
See [Stage 05 integration](3d_game/STAGE05_INTEGRATION.md).

## September 13: Stage 2 dog interaction (#38)

The approved E02 distraction rules above replace the earlier environment-only dog
status and unrestricted Stage 2 exit. Six supplied animations are integrated into
one model. The drawing button remains visible in the river and shared later-stage
previews, with a glow when an implemented challenge is available. Preview stages
without an implemented encounter keep the button inactive. See
[Dog encounter implementation](3d_game/DOG_ENCOUNTER.md).

## September 13: Stage 1 update (#37)

The E01 rules above supersede the earlier construction/coin sequence: the far-bank
stone is moved, the normal camera is closer, the hero visual is doubled, the camera
holds until generation finishes plus a two-second result display, and coins are
removed across active gameplay. Historical September 12 coin notes are retained
only as change history. See [the current encounter flow](3d_game/ENCOUNTER_FLOW.md).


## September 13: Dawn ending presentation (#52)

The user approved the supplied dawn forest as the ending environment, reached
after Stage 5 boss victory. While the boss is absent, walking deeper into the
Stage 5 clearing (world z<=-12, across all X positions and heights) is an approved
temporary shortcut, following the Stage 2-to-3 boundary pattern.

The implemented ending replaces the night forest with the delivered morning
scene, keeps exploration available, and displays a thank-you card, Four Otters
team credit, return-to-forest and fresh river restart controls. A dedicated
boss-completion hook can trigger this scene with the walking shortcut disabled.
This supersedes earlier open-setting references for the visual ending only.
The final boss loop, victory call site, ending narration/dialogue, full asset
credits screen and Web validation remain unfinished. See
[Ending integration](3d_game/ENDING_INTEGRATION.md).

## September 13: shared sketch generation particles

The global playtest revision replaces all construction tent geometry with pearl-white
particles and soft local blur around the submitted sketch. River, Dog and Bird use
the shared generation preview. Keep their focus, completed-model hold, zoom-out and
reaction sequence; clear the atmosphere when the model appears or a request ends
unsuccessfully. See [Generation presentation](3d_game/GENERATION_PRESENTATION.md).

## September 13 playtest follow-up: group framing (#58, #59)

Stage 2 and Stage 3 generation shots must include the protagonist, animal and
drawn/generated object together. Use a gentle group close-up with space for the
sketch mist. Stage 2 offerings settle on terrain and cannot be knocked away by
the dog or protagonist. Stage 3's single bird is reduced 30% from its previous
fourfold scale, continues flying while the canvas is open, and pitches downward
toward the protagonist during its swoop. Successful generated models must appear
even when unsuitable for protection; show why a different drawing is needed,
retain the latest draft, and keep the route locked until DEFENCE succeeds.

For Stage 3 classification, ordinary umbrellas and shields count as DEFENCE after
the model identifies the object. This clarification must not steer the identity
toward a solution. The successful-model display and the level's solve check remain
separate, so an unsuitable classification never silently discards a generated GLB.

## September 13 late playtest revision: fixed generation close-up (#59)

Increase the shared sketch cover opacity across all implemented drawing stages.
For Stage 3, zoom closer to the sketch and protagonist, then hold the camera fixed
through processing and the completed-model pause; bird movement must not move the
camera. This supersedes the earlier Stage 3 group-tracking requirement above.
Retain Stage 2 group framing. When the bird departs, detach the protection from the
protagonist and animate it tilting, drifting away, shrinking and fading out. Remove
it after departure; the protagonist must remain grounded. This supersedes the
earlier persistent equipped-protection behavior.

The subsequent marked screenshot defines the Stage 3 composition more precisely:
frame the central sketch/cover area as the close-up, moving the shot center upward
from the ground. Include the sketch bounds when choosing both center and distance;
small and large drawings should remain prominent without clipping the cover.


## September 13: Overworld and page turns (#53)

The September 14 ticket update restores **Next page** confirmation before
Chapters 2–5, superseding the temporary automatic-entry playtest revision.
Start with the full daylight map, zoom to the protagonist at Chapter 1, then
hold that closeup with one prominent **Start the journey** CTA. Do not enter the river until
the player confirms. Clicking Start turns into the first scene, after which the
protagonist drops onto the path through the existing spawn physics.

Each forward exit in Chapters 1–4 turns back to the map at the completed
chapter's closeup. Pull back while the protagonist walks along the painted
route, then zoom to the next chapter and show **Next page →**. Hold until the
player confirms. While waiting, allow smooth bounded zoom between the current
chapter closeup and full-map view. Keep the opening **Start the journey** CTA.
Existing encounter gates still decide when the player can leave.

Forward progression lifts the bottom-right corner toward the upper-left at
one fixed physical angle, following the user’s paper reference. This includes
chapter-completion map journeys and the ending. The later **Back to map**
button revision below is previous-page navigation and uses the left corner.

Blend daylight into sunset during the Chapter 2-to-3 map journey, and sunset
into night during Chapter 4-to-5. Keep all other map legs in their current time.
The dawn ending's **Begin a new journey** returns to the daylight map and Start CTA
before creating a fresh river. Individual scene previews remain available. This adds presentation
to the current exits; otter and final-boss gameplay remain separate work.
See [Overworld integration](3d_game/OVERWORLD_INTEGRATION.md) for assets, controls,
implementation and verification.


## September 14: The last page and victory recap (#60)

Replace the abrupt Chapter 5-to-ending cut with a slower final page curl. Fade
out the chapter HUD before turning; keep the revealed dawn restrained, then
raise its light smoothly. Reduce dawn exposure, key/local light and bloom rather
than using a white flash. Keep the existing preview exit and future boss-victory
hook; this presentation does not implement or simulate boss combat.

After dawn settles, show an open storybook victory spread: a keepsake of the
forest, “Journey complete.”, the actual chapters visited and sketches submitted
this session, and the Four Otters credit. Do not invent score, stars earned,
completed encounters or visited chapters. “Sketches shared” counts valid accepted
submissions, including retries; it does not imply provider success.

**Begin a new journey** resets the recap and returns to the opening map/Start
flow. **Stay in the dawn** dismisses the book and restores movement; **The last
page** reopens it. Retain **Back to forest** while exploring. See
[Ending integration](3d_game/ENDING_INTEGRATION.md) for implementation and checks.


## September 14: Return to the map from Chapter 1

Add **Back to map** below the River's Sound button. This is a current-chapter
map visit, not a restart or an unlocked next chapter. Retain the current scene,
player position, drawing and encounter state while browsing. Allow bounded map
zoom and show **Return to chapter →** to resume. **Back to map** turns from
the bottom-left toward the upper-right, as returning to the previous page.
**Return to chapter** turns forward from the bottom-right again. Disable this action while a drawing panel, generation,
model presentation or chapter-exit transition is active.


## September 14 asset update: giant Storykeeper (#36)

The supplied `boss-Storykeeper-HandLift-Sway-Loop-v01.glb` is the accepted
Stage 5 boss visual. Place it centrally in Moonlit Forest at a giant scale so
the protagonist feels small in front of it. Preserve the source hand-lift and
body-sway animation, materials and manuscript texture. The integrated visual
is approximately 11 world units tall, with a solid body and terrain grounding.

This update covers the model only. The user explicitly deferred the separate
boss personality/agent requirements (#63); no dialogue, combat, drawing rules
or victory condition is inferred from that file. The existing temporary route
around the boss to the dawn ending remains available until encounter gameplay
is implemented. See [Boss integration](3d_game/BOSS_INTEGRATION.md).
## September 14: Stage entrances

Stages 2–5 now begin with an automatic walk to the existing starting position.
The player starts four world units behind that position along the approach path
(Stage 3 approaches from the left). Normal walking animation and terrain collision
remain active. The camera holds its authored starting framing during the entrance;
movement, sprint, jump, and drawing controls unlock on grounded arrival. The HUD
appears at that point. Stage 1 keeps its existing start flow.

`3d_game/tests/stage_entrance_smoke.gd` checks all four arrivals with movement,
sprint, and jump held throughout the entrance, plus drawing lockout and the final
position. Use `-- --visual` for approach and arrival screenshots.


## September 14: The Storykeeper and spoken narration (#63, #66)

This update resolves the earlier open E05 identity and ending decisions. The warm,
talkative narrator becomes the physical Storykeeper in Chapter 5 and fears ending
the adventure. Free dialogue and drawing ideas can convince him to open the exit;
leaving completes only when the player crosses it. A voluntary stay ending requires
explicit intent plus a neutral confirmation; temporary rest is never terminal.
The referee and performer are separate model calls, with game-owned state guards.

The desktop MVP adds persistent evidence journals, bounded cross-chapter memory,
English subtitles and ElevenLabs speech, plus a local authoring bench with narrator
checkpoints and branches. Stage 1–4 encounter rules remain authoritative. Current
memory coverage is recorded chapter/drawing/use/NPC events, not every movement.
Music remains the teammate's work. A separate otter voice slot is reserved for later.
Full world-save restoration, Web hosting and new skeletal animation delivery are
not implemented by this update. See [Narrator integration](3d_game/NARRATOR_AGENT.md)
and [backend setup and validation](backend/BACKEND.md#narrator-and-speech).


## September 14: Talk scope and boss mood

Player dialogue is available only in Chapter 4 (otter) and Chapter 5 (Storykeeper),
through a microphone Talk CTA beside Draw. Typing and microphone-to-text are both
supported; the player reviews a transcript and presses Send. Earlier chapters keep
passive narration. The boss now starts at 37% mood. Model-evaluated dialogue/drawings
can increase or decrease it; below 20 is red, 20–80 yellow, above 80 green, and 95
opens the way. Game code enforces the threshold and idempotency. This supersedes
previous score-free boss resolution assumptions; resting and voluntary stay-ending
confirmation still do not automatically complete a leave ending.


## September 14: Delivered BGM and feedback (#19, #69)

Five team-delivered tracks cover opening, Chapters 1–3, Chapter 4, Chapter 5 and
the endings, with persistent playback, looping, crossfades and speech ducking.
Shared procedural feedback covers buttons, page turns, drawing submission/results,
boss release, jumping and footsteps. Music/Effects levels and master mute are
available in the Audio panel. See [Audio integration](3d_game/AUDIO.md).
