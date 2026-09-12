# Paws & Peaks

Draw something. Help someone.

A four-day game jam project about drawing objects to solve animal encounters.

## Documentation

Read [SPEC.md](docs/SPEC.md) for the draft gameplay scope, traversal and coins, background AI and item stats,
narration/dialogue, music and sound, team responsibilities, milestones, and acceptance checks.
See [reuse research](docs/REUSE_RESEARCH.md) for candidate Godot foundations, version pins, and license notes.
Open decisions are marked explicitly; this specification describes planned work, not implemented features.

Keep specifications, research, planning, and credits in `docs/`. This README stays at the repository
root as the project entry point; [AGENTS.md](AGENTS.md) stays here for coding-assistant conventions.

## Open and run

1. In Godot's Project Manager, click **Import** and select `3d_game/project.godot`.
2. Open the project and press **F5** (or click Run Project) to launch the **Across the River** prototype.
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
- `3d_game/scenes/river/river_crossing.tscn`: the first-stage prototype and startup scene.
- `3d_game/scripts/river/`: drawing UI, third-person controls, encounter logic, and the AI handoff boundary.
- `3d_game/scenes/river/river_player.tscn`: placeholder hiker and collision-aware follow camera.
- `3d_game/main.tscn`: the original Brackeys dungeon demo, retained as a reference.
- `3d_game/scenes/`, `3d_game/models/`, and `3d_game/addons/`: template scenes, assets, and controller.
- `docs/`: game specification and research.
- `.gitignore`: keeps generated files, local exports, and common secret files out of Git.
- `.gitattributes`: normalizes text line endings across team computers.

The first-stage prototype now includes third-person walking/jumping/sprinting, a river graybox,
eight collectible coins, a collapsible drawing panel, 512 × 512 PNG output, asynchronous mock
responses, an item card, a walkable bridge, fall recovery, and an ending/restart loop.
Simple synthesized feedback sounds are included; final art, music, voiced narration, real AI,
pushing/climbing, the remaining four stages, and Web deployment are still outstanding.

## Try the first stage

1. Click the game to capture the mouse. Move the mouse to orbit the placeholder hiker.
   **WASD** moves relative to the camera, **Space** jumps, **Shift** sprints.
   The hiker turns toward travel; orbiting while idle does not turn the hiker.
   The camera retracts around obstacles and returns when clear.
2. Approach the river post. Press **E** to expand the sketchbook; drawing pauses movement and camera input.
3. Draw with the left mouse button. Undo and Clear are available; closing preserves the draft.
4. Leave **Test: bridge** selected and submit. The **PROTOTYPE · NO AI** indicator is deliberate:
   the selected fixture determines the response, not the content of your sketch.
5. Explore or collect coins during the three-second simulated wait. Press **E** when the idea is ready.
6. Near the river post, choose **Use idea · Build bridge**, then walk across to finish.
7. **Esc** closes the book and releases the mouse. Click the world to resume mouse look.

The other test responses cover unsuitable objects, unclear drawings, and service failure.
The latest submitted drawing is saved to `user://drawings/E01-latest.png` (Godot's user-data directory),
not the repository. See [Day 1 handoff](docs/DAY1_HANDOFF.md) for Beichun's API boundary,
designer replacement points, tests, and current limitations.

## Team workflow

For the separate narrative and 3D API scripts, see [local AI setup](docs/AI_LOCAL_SETUP.md).
`backend/sketch_to_narrative/` uses OpenAI; `backend/image_text_to_3d/` uses Meshy to
generate untextured geometry from images. Both share `backend/.venv` and an ignored `backend/.env`.
These helpers are not yet connected to the game's drawing action.
See [backend development instructions](docs/BACKEND.md) for conventions, contracts, and credential handling.

Clone the GitHub repository to get your own local copy, then import `3d_game/project.godot` in Godot.
Pull before working, coordinate who edits each scene, and commit small changes.
Commit source assets and Godot scene files. Do not commit the generated `.godot/` folder or API keys.

## Next milestone

Connect the existing drawing request boundary to Beichun's real AI service, then replace graybox visuals.
The target is Web. The template still uses Forward Plus; Compatibility rendering adaptation,
export templates, an export preset, hosting, and browser verification remain to be done.
