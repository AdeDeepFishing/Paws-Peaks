# Paws & Peaks — Reusable Godot Projects

Research date: 2026-09-12. Target: Godot 4.7.2 Standard, GDScript, desktop Web browsers, a four-day jam with two beginner developers and two designers.

**Recommendation:** evaluate Kenney's 3D Platformer as the single movement/coin foundation; evaluate Dialogue Manager for authored dialogue; borrow small drawing and texture-capture patterns from the official demos. Keep GDQuest's third-person controller as an alternative, not a second controller to merge into the first.

This is source and documentation research. No candidate has been installed in Paws & Peaks, imported in its Godot editor, or tested in its hosted Web build. Upstream features are evidence for a compatibility trial, not delivered game features. Rankings reflect our integration needs, not repository popularity.

## 1. Shortlist

| Priority | Candidate | Useful coverage | Work that remains ours |
|---|---|---|---|
| First movement trial | [Kenney 3D Platformer](https://github.com/KenneyNL/Starter-Kit-3D-Platformer) | Character movement, jumping, camera rotation/zoom, coins, initial models and SFX | Sprint, mouse camera adaptation, crate pushing, ladder climbing, UI input modes, persistent session state |
| First dialogue trial | [Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager) | Dialogue authoring, branching, named cues, line tags, example presentation | Voice clip mapping, subtitles/voice synchronization, music ducking, nonblocking trail narration |
| Small drawing references | [Godot demo projects](https://github.com/godotengine/godot-demo-projects) | Drawable textures, viewport image capture, 2D content displayed in 3D | Stroke undo, clean PNG submission, canvas bounds, AI request lifecycle |
| Alternative movement trial | [GDQuest third-person controller](https://github.com/gdquest-demos/godot-4-3d-third-person-controller) | Camera-relative movement, jumping, mouse camera, coin handling | Remove shooter assumptions; add sprint, crate/ladder interactions; replace restricted art |

None of these is an existing implementation of our complete draw-to-solve game. The custom work is the encounter rules, bounded item statistics, asynchronous AI state, and the connection between player drawings and meaningful outcomes.

## 2. Kenney Starter Kit 3D Platformer

**Inspected revision:** `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`, main, commit dated 2026-03-12. [Pinned source](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/tree/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0).

The README describes a Godot 4.6 template with a double-jump character, collectible coins, falling platforms, rotating/zooming camera, and gamepad support. It identifies code as MIT and included sprites, models, and sound effects as CC0. Preserve the MIT notice when copying substantial code; separately retain source records for any additional assets we introduce. [README and licensing](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/README.md).

The inspected player script uses `CharacterBody3D`, rotates movement input with the view, normalizes long input vectors, applies gravity/jump behavior, and emits a coin-count signal. It also plays footsteps and jump/landing feedback. This is a small and understandable starting point for the requested exploration loop. **Its fall recovery reloads the entire current scene.** Replace that behavior with checkpoint repositioning so falling does not discard a drawing request, solved encounter, or collected-token history. [Player source](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/scripts/player.gd).

The camera script reads named camera axes and zoom axes; it does not establish mouse-motion orbit in the inspected file. Add the chosen mouse behavior explicitly, with camera input disabled over the drawing canvas. The inspected player/controller files do not implement sprinting, physics-crate pushing, or ladder climbing. These are bounded additions, not template features. [Camera source](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/scripts/view.gd).

**Web risk:** `project.godot` declares Godot 4.6 and Forward Plus. Trial it in Compatibility rendering before adopting the visual setup; do not assume the screenshots represent what the browser can render. [Project configuration](https://github.com/KenneyNL/Starter-Kit-3D-Platformer/blob/3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0/project.godot).

**Decision:** strongest first trial because the coin loop and playful movement are already together. Import only the necessary files and their dependencies after the trial; do not replace our whole repository with the template.

## 3. Nathan Hoad's Dialogue Manager

**Suggested trial pin:** release `v4.1.0`, commit `a719088aea342572f29b5559fd8726896c9519b2`, dated 2026-09-04. The release is labeled for Godot 4.7; main's README describes Dialogue Manager 4 as supporting Godot 4.6+. Use the pinned release documentation, not older v3 tutorials. [Release](https://github.com/nathanhoad/godot_dialogue_manager/releases/tag/v4.1.0), [README](https://github.com/nathanhoad/godot_dialogue_manager/blob/a719088aea342572f29b5559fd8726896c9519b2/README.md).

The addon supplies a branching dialogue editor/runtime under MIT. Use its GDScript path in our Standard project; the existence of optional C# wrappers is not a reason to use a .NET project. This is appropriate for designers writing English conversations and reviewing them separately from movement code. [License](https://github.com/nathanhoad/godot_dialogue_manager/blob/a719088aea342572f29b5559fd8726896c9519b2/LICENSE).

Its dialogue syntax supports speakers, responses, cues, and per-line tags with values. Our proposed adapter can map a tag such as `voice=otter_intro_01` to a local audio resource. This mapping is a project design recommendation, not a built-in ElevenLabs integration verified by this research. [Dialogue syntax](https://github.com/nathanhoad/godot_dialogue_manager/blob/a719088aea342572f29b5559fd8726896c9519b2/docs/Basic_Dialogue.md).

The author explicitly leaves final rendering and input handling to the game, with an example balloon that can be copied and customized. Start with that example. We still need skip/advance behavior, stopping the previous clip, captions, separate Voice volume, music ducking, and world narration that does not steal movement control. Generate authored voice lines ahead of time using the team's ElevenLabs account, then import the resulting files as assets. [Balloon integration](https://github.com/nathanhoad/godot_dialogue_manager/blob/a719088aea342572f29b5559fd8726896c9519b2/docs/Dialogue_Balloons.md).

**Decision:** worthwhile if one developer can connect one captioned voice line quickly. Avoid adding an elaborate cinematic or conversation framework. Authored dialogue resources must remain separate from AI-generated descriptive text; never evaluate AI output as dialogue commands.

## 4. Official Godot demos: drawing, capture, and original-art display

**Inspected master pin:** `a3b5c113112f77291d5f3d1360f33a882fdc52f7`, commit dated 2026-09-08. [Pinned source](https://github.com/godotengine/godot-demo-projects/tree/a3b5c113112f77291d5f3d1360f33a882fdc52f7). This is a development-branch revision, not a stable release.

**Version caution:** the repository says `master` follows Godot development, while other branches match stable versions. Queries for branches `4.7` and `4.6` returned no matching commit during this research. Inspect each selected demo's engine requirements and freeze a verified revision before copying. Do not download an unpinned moving master into the game. [Version policy](https://github.com/godotengine/godot-demo-projects#godot-versions).

The following three small examples belong to one candidate repository:

- **`2d/drawable_textures`:** interactive painting with a `DrawableTexture2D`, brush color/size, erasing, and the same texture displayed on mesh materials. Its inspected configuration declares 4.7 and Compatibility. It is a promising reference for preserving the player's drawing in the 3D scene. The inspected script does not supply stroke undo, PNG serialization, or AI submission. [Demo](https://github.com/godotengine/godot-demo-projects/tree/a3b5c113112f77291d5f3d1360f33a882fdc52f7/2d/drawable_textures), [painting source](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/2d/drawable_textures/main.gd), [configuration](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/2d/drawable_textures/project.godot).
- **`viewport/screen_capture`:** demonstrates retrieving a viewport texture as an image and displaying that image again. Adapt this pattern to a dedicated drawing viewport; capturing the entire game screen would include scenery and UI in the AI input. PNG encoding and upload remain additional work. [Capture source](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/viewport/screen_capture/screen_capture.gd).
- **`viewport/2d_in_3d`:** assigns a SubViewport texture to a 3D quad's material. This is a direct reference for a paper-like in-world representation of the player's artwork. We do not need the demo's Pong gameplay or camera motion. [Texture assignment source](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/viewport/2d_in_3d/2d_in_3d.gd).

The repository carries an MIT license. Retain applicable notices and inspect any per-asset licenses before copying demo media; prefer our own art where the media is irrelevant. [License](https://github.com/godotengine/godot-demo-projects/blob/a3b5c113112f77291d5f3d1360f33a882fdc52f7/LICENSE.md).

**Decision:** reuse patterns or a small isolated drawing component. Do not import the full demo collection. If the drawable-texture API is unsuitable in the actual 4.7.2 Web export, retain a simple stroke list rendered into a SubViewport and reuse only the capture/display patterns.

## 5. GDQuest 3D third-person controller

**Inspected revision:** `b3bd6e81084f568be8aa44a69a0c2b1e52e806b3`, main, commit dated 2026-08-15. [Pinned source](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/tree/b3bd6e81084f568be8aa44a69a0c2b1e52e806b3).

The current project identifies itself as RoboBlast, a third-person-shooter demo, and declares Godot 4.7 with Forward Plus. Its player has camera-relative motion, jump behavior, coin handling, and extensive dependencies on shooting, grenades, aiming UI, and animated character skin. It captures the mouse in `_ready()`, which needs adjustment for browser input rules and the drawing interface. [Configuration](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/blob/b3bd6e81084f568be8aa44a69a0c2b1e52e806b3/project.godot), [player source](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/blob/b3bd6e81084f568be8aa44a69a0c2b1e52e806b3/player/player.gd).

The camera controller explicitly handles captured mouse motion and uses a SpringArm3D reference. It is a useful reference for mouse-camera input, but its capture/release behavior still needs to fit our canvas and browser. [Camera source](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/blob/b3bd6e81084f568be8aa44a69a0c2b1e52e806b3/player/camera_controller.gd).

**Asset distinction:** source scripts, scenes, shaders, and Godot resources are MIT; image textures and 3D models are CC-BY-NC-SA 4.0. This is not an all-MIT asset pack. For our trial, use our own art or separately cleared assets rather than inheriting that art licensing constraint. [License](https://github.com/gdquest-demos/godot-4-3d-third-person-controller/blob/b3bd6e81084f568be8aa44a69a0c2b1e52e806b3/LICENSE).

**Decision:** keep as a code reference or alternate controller if Kenney's feel is unsuitable. It is a broader extraction task for beginners, and inspected movement code does not establish ready-made sprint, pushing, or climbing. Do not combine two complete player controllers.

## 6. Bounded compatibility trial and adoption gate

Proposed budget: 90 minutes for the first movement candidate, 45 minutes for dialogue/voice, and 45 minutes for drawing/capture. These are decision checkpoints, not implementation-time guarantees. Record the chosen revision, imported files, notices, required patches, and browser result before adoption.

Godot's Web documentation requires Compatibility rendering and describes browser restrictions on pointer capture, audio startup, and networking. Prefer a simple GDScript build with no native addon requirement; initialize sound and any mouse capture from an actual player gesture. Test the deployed build, not only the editor. [Official Web constraints](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

The trial passes only when:

1. The candidate opens in our exact Godot version without blocking parse/import errors, exports, and runs from a hosted HTTPS URL on a teammate's browser.
2. The player walks, jumps, and collects a coin; input still works after opening/closing a modal canvas. The selected camera does not paint and rotate simultaneously.
3. A deliberate fall returns to a safe point without resetting token totals, encounter state, or an in-flight request.
4. A drawing appears in a clean captured image and on a simple in-world card. Fast strokes, pointer release outside the canvas, undo, and resize have explicit results.
5. One authored voice line plays after Start, has a visible matching caption, can be skipped, and does not overlap the next line. Music and voice volume remain controllable.
6. A simulated delayed request lets the player keep exploring and collecting, then posts a nonmodal ready notice. Failure, late response, and return to a previous area cannot apply the wrong item.

Sprint, one constrained pushable crate, and one authored ladder should then be added to the chosen controller as separate small tasks. Reuse does not remove the need to verify their interaction with gates, respawn, drawing mode, and asynchronous AI.

If a candidate fails its time-box, record the specific blocker and choose the smaller reference or alternative. Never spend the four-day jam integrating overlapping frameworks before a single drawing can solve a single encounter.
