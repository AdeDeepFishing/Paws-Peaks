# Paws & Peaks

Draw something. Help someone.

A four-day game jam project about drawing objects to solve animal encounters.

## Documentation

See [Sketch-to-model stage classes](docs/backend/BACKEND.md#current-multi-stage-request-contract) for the **River, Dog, Crows and Otter
classification sets**, request format, and result logs.

Read [SPEC.md](docs/SPEC.md) for the draft gameplay scope, traversal, background AI and item classification,
narration/dialogue, music and sound, team responsibilities, milestones, and acceptance checks.
See [reuse research](docs/3d_game/REUSE_RESEARCH.md) for candidate Godot foundations, version pins, and license notes.
Open decisions are marked explicitly; this specification describes planned work, not implemented features.

Keep specifications, research, planning, and credits in `docs/`. This README stays at the repository
root as the project entry point; [AGENTS.md](AGENTS.md) stays here for coding-assistant conventions.

## Open and run

1. In Godot's Project Manager, click **Import** and select `3d_game/project.godot`.
2. Open the project and press **F5** (or click Run Project) to launch the **world map intro**, which pauses at the hero for **Start the journey** before entering **Across the River**.
3. The repository root is for documentation and Git; the Godot project lives in `3d_game/`.

Use **Godot 4.7.2 Standard**. The project uses built-in **GodotPhysics3D**; the bundled
Godot 4.3-only Jolt extension is disabled by `3d_game/godot-jolt/.gdignore`.
Headless import and startup checks passed, and a desktop game launch reported no Jolt errors.

After pulling this fix, close and reopen the Godot project and let the asset scan finish.
If the old extension error persists, close Godot, remove only the generated
`3d_game/.godot/` cache, then reopen `3d_game/project.godot` to rebuild it.

Godot includes a script editor; VS Code is optional. Scripts use GDScript.

## What's here

- `3d_game/project.godot`: the active Godot project settings.
- `3d_game/scenes/overworld/overworld.tscn`: the opening map and chapter transitions.
- `3d_game/scenes/river/river_crossing.tscn`: the first-stage prototype.
- `3d_game/scripts/river/`: drawing UI, third-person controls, encounter logic, and the AI handoff boundary.
- `3d_game/scenes/river/river_player.tscn`: shared animated protagonist and capsule collision.
- `3d_game/main.tscn`: the original Brackeys dungeon demo, retained as a reference.
- `3d_game/scenes/`, `3d_game/models/`, and `3d_game/addons/`: template scenes, assets, and controller.
- `docs/`: game specification and research.
- `.gitignore`: keeps generated files, local exports, and common secret files out of Git.
- `.gitattributes`: normalizes text line endings across team computers.

The first-stage prototype now includes third-person walking/jumping/sprinting, the stag01 storybook creek and a fixed overhead camera,
a transparent scene drawing overlay, 512 × 512 PNG output, asynchronous desktop generation,
automatic placement of returned GLB models, fall recovery, and an ending/restart loop.
Simple synthesized feedback sounds are included; final art, music, voiced narration, live API playtesting,
pushing/climbing, later encounter mechanics, and Web deployment are still outstanding.
Stage 2 includes the [dog distraction encounter](docs/3d_game/DOG_ENCOUNTER.md).
Issue #37 removes coin pickups/counters from active gameplay, clears the far-bank
bridgehead, doubles the Stage 1 character visual, and brings its normal camera about 18% closer.

## World map and chapter turns

The opening shows the daylight map and zooms to the protagonist. Click **Start the journey**
(or use Enter/controller confirm) to turn into the first chapter; the character
then drops onto the path. The opening waits as long as you need.

After each forward exit in Chapters 1–4, the page turns back to the map, the
protagonist walks to the next chapter, and the camera zooms in. **Next page →**
waits for your confirmation. Before entering, use the scroll wheel, trackpad
pinch, slider or **You / Map** controls to browse between the chapter closeup
and full map. Every page lifts from the bottom-right toward the upper-left,
including returns to the map and the ending. The map changes to sunset before Chapter 3 and night before
Chapter 5. **Begin a new journey** returns to the daylight map and **Start the journey**. See
[Overworld integration](docs/3d_game/OVERWORLD_INTEGRATION.md) for source assets
and verification.

## Try the first stage

1. Use **WASD or arrow keys** to move relative to the fixed overhead camera, **Space** to jump,
   and **Shift** to sprint. The mouse stays visible and does not rotate the camera.
2. Follow the pink path to the river. When the pen prompt appears, press **E** or click it to draw over the scene; movement pauses and the regular HUD hides.
3. Draw with the left mouse button. Undo and Clear are available; closing preserves the draft.
4. Leave **Sample model · No AI** selected to test the Python-to-GLB workflow without keys.
   Every sketch gets the same sample ladder. Select **Live AI · Uses credits** for actual generation after backend setup.
5. The camera slowly moves into the construction view over two seconds and stays there
   until generation finishes. The finished object remains in closeup for two seconds,
   then the camera returns to normal. After the opening camera move, you can still
   walk and use **Stop waiting**. No coins spawn.
6. When the bridge appears, walk across to finish. Near the bridge, input gently follows its axis;
   release to stop or reverse to walk back. No Use confirmation is required.
7. **Esc** cancels drawing or a pending request. The drawing entry stays visible during
   exploration and shines near an available challenge. **Stop waiting** also restores
   the normal camera without losing your draft.

Controllers: **left stick or D-pad** to move, **A/Cross** to jump, hold **RB/R1** to sprint,
**X/Square** to toggle drawing, and **B/Circle** to close it. In panels, use the
**D-pad** to navigate and **A/Cross** to activate buttons. Drawing still requires a mouse
or trackpad. For **Nintendo Switch Pro**, use **B** to jump/confirm, **R** to sprint,
**Y** for drawing, and **A** to close. Hints adapt when a Switch controller connects.
Stick movement is analog with a 0.2 deadzone; the camera remains fixed.

In **Mock bridge · No AI** mode, the other test responses cover unsuitable objects, unclear drawings, and service failure.
Each submitted drawing is saved to a unique `user://drawings/E01-<timestamp>-<id>.png` (Godot's user-data directory),
not the repository. See [desktop integration](docs/3d_game/DESKTOP_GENERATION.md) for the request boundary,
generation modes, tests, and current limitations.

See [Scene drawing and PNG handoff](docs/3d_game/SCENE_DRAWING.md) for issue #12, controls and a sample PNG.

See [Stage 01 integration](docs/3d_game/STAGE01_INTEGRATION.md) for camera settings, asset details, and import fixes.

## API keys for local AI features

The default offline mode runs without API keys. To use live generation or the local
backend scripts, create your private configuration from the repository root:

```sh
# Create the file only if it does not already exist; preserve existing keys.
if [ ! -e backend/.env ]; then
  cp backend/.env.example backend/.env
fi
chmod 600 backend/.env
```

Open `backend/.env` in your editor and fill in only the keys for the features you use:

| Setting | Used by |
|---|---|
| `OPENAI_API_KEY` | Sketch interpretation and reference-image editing |
| `MESHY_API_KEY` | Image → untextured 3D model |

Leave the model settings at their template defaults to start. The scripts load
`backend/.env` automatically; environment variables with the same names take precedence.
See [local AI setup](docs/backend/BACKEND.md#setup-and-run) for Python setup and run commands.

**Keep keys private.** `backend/.env` is ignored by Git; commit only the blank
`backend/.env.example` template. Never put keys in source code, screenshots, logs,
or game exports. Each developer should configure their own local file. To verify
the ignore rule without displaying any credentials, run:

```sh
git check-ignore backend/.env
```

The expected output is `backend/.env`.

## Generate a model from a sketch

With Python and both API keys configured, run:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --image path/to/sketch.png
```

Omit `--image` to use the saved sample sketch; add `--dry-run` to validate inputs
without API calls. The flow uses separate OpenAI interpretation and low-quality 816 × 816 image-edit
requests producing an object reference, then untextured Meshy T2 (~500 faces) and
a local clay PNG preview. Interpretation also selects a reusable material key and
color; Godot applies and tints the bundled texture with triplanar mapping. See the
[16-material palette](docs/3d_game/MATERIAL_PALETTE.md). Outputs and timings are saved locally.
See the [three API steps and data flow](docs/backend/BACKEND.md#current-flow) for
request inputs, outputs, and how interpretation becomes available while generation continues.
See the [test report](docs/backend/BACKEND.md#historical-benchmarks) for results and limitations.
The retained September 12 run took 19.70 seconds; this is a historical measurement,
not a current latency guarantee. The generated shape still needs review.

## Team workflow

For the separate narrative and 3D API scripts, see [local AI setup](docs/backend/BACKEND.md#setup-and-run).
`backend/interpret/` interprets sketches with OpenAI, `backend/image_edit/`
creates reference images with OpenAI, and `backend/model_generation/` creates
untextured geometry with Meshy. `backend/sketch_to_model/` runs these three steps
in order. All share `backend/.venv` and an ignored `backend/.env`.
The desktop drawing action connects through `backend/game_bridge/` to the sketch-to-model pipeline.
See [desktop generation](docs/3d_game/DESKTOP_GENERATION.md) for modes, setup, cancellation, and limitations.
See [backend development instructions](docs/backend/BACKEND.md) for conventions, contracts, and credential handling.

Clone the GitHub repository to get your own local copy, then import `3d_game/project.godot` in Godot.
Pull before working, coordinate who edits each scene, and commit small changes.
Commit source assets and Godot scene files. Do not commit the generated `.godot/` folder or API keys.

## Next milestone

Connect the existing drawing request boundary to Beichun's real AI service, then review the imported scene with the designers.
The target is Web. The template still uses Forward Plus; Compatibility rendering adaptation,
export templates, an export preset, hosting, and browser verification remain to be done.

See [construction flow and movement](docs/3d_game/ENCOUNTER_FLOW.md) for the latest camera,
reward timing, and map-boundary changes.

## Preview the woodland scene

After crossing the river, keep walking along the far-bank path to its lower-right
edge to return to the map, then choose **Next page** to enter the woodland. You can also run
`3d_game/scenes/woodland/woodland_path.tscn` directly in Godot. Stage 2 includes the imported environment, fixed-angle camera, walking/jumping,
and the dog distraction encounter. UNKNOWN objects render without unlocking the path.
See [Stage 02 integration](docs/3d_game/STAGE02_INTEGRATION.md) for source ownership and checks.

All four scene previews use the delivered Moonlit Wanderer protagonist, with idle, walking and
running animations. See [hero integration](docs/3d_game/HERO_INTEGRATION.md) for assets,
animation handling and the temporary jump pose.

## Preview Wind Hill

In Stage 2, follow the lakeside path to the white birch trees to return to the
map, then choose **Next page** for Wind Hill, or run
`3d_game/scenes/wind_hill/wind_hill.tscn` directly. Stage 3 includes the supplied
painted environment, restored textures, terrain collision, the shared protagonist
and a 16-second wind animation at 80% of the delivered maximum strength.
**Back to woodland** returns to Stage 2. Crow encounter gameplay remains unimplemented.
See [Stage 03 integration](docs/3d_game/STAGE03_INTEGRATION.md) for asset repair and checks.

## Preview Sunset Cove

In Stage 3, walk right toward the large rock beside the tree. Reaching its near
edge starts the map journey toward Stage 4; choose **Next page** when ready.
The exit also works while walking beside the path or jumping; climbing onto the rock is unnecessary. You can also run
`3d_game/scenes/sunset_cove/sunset_cove.tscn` directly. Sunset Cove includes the
painted beach and cave, collision, the shared protagonist, wind and water motion,
and live water reflections of the sunset, scenery and character.
**Back to Wind Hill** returns to Stage 3. Otter encounter gameplay remains open.
See [Stage 04 integration](docs/3d_game/STAGE04_INTEGRATION.md) for verification and
differences from the source HTML renderer.

## Preview Moonlit Forest

In Stage 4, walk right toward the cave. Reaching the cave approach enters Stage 5
even from the surrounding grass, without jumping onto a rock. You can also run
`3d_game/scenes/moonlit_forest/moonlit_forest.tscn` directly. The scene includes
the designer's V5 painted night forest, terrain collision, shared protagonist, wind, moving
clouds and fireflies. **Back to Sunset Cove** returns to Stage 4.
Final boss gameplay remains separate. See
[Stage 05 integration](docs/3d_game/STAGE05_INTEGRATION.md) for assets and checks.


## Preview the dawn ending

Continue deeper into Stage 5's clearing to enter **A New Dawn**. The temporary
exit covers the full width of the forest, including jumping. The ending uses
the supplied dawn forest. A slower final page turn leads into a soft sunrise,
then a storybook victory spread with a keepsake of the scene and actual session
counts. **Stay in the dawn** restores exploration; **The last page** reopens the
book. **Begin a new journey** clears the recap and returns to the daylight map
and Start CTA before a fresh river. **Back to forest** remains available while
exploring the dawn.
Direct entry: `3d_game/scenes/ending/dawn_forest.tscn`.

Boss victory is the intended final trigger; the boss is not implemented yet.
See [Ending integration](docs/3d_game/ENDING_INTEGRATION.md) for the preview
switch, future victory hook, asset provenance and verification.
