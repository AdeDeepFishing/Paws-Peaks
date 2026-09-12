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
2. Open the project and press **F5** (or click Run Project) to launch its sample scene.
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
- `3d_game/main.tscn`: the sample startup scene.
- `3d_game/scenes/`, `3d_game/models/`, and `3d_game/addons/`: template scenes, assets, and controller.
- `docs/`: game specification and research.
- `.gitignore`: keeps generated files, local exports, and common secret files out of Git.
- `.gitattributes`: normalizes text line endings across team computers.

The supplied template includes first-person movement. Our drawing, AI, collectible-token
loop, and five encounters remain planned work.

## Team workflow

Clone the GitHub repository to get your own local copy, then import `3d_game/project.godot` in Godot.
Pull before working, coordinate who edits each scene, and commit small changes.
Commit source assets and Godot scene files. Do not commit the generated `.godot/` folder or API keys.

## Next milestone

Add one drawing canvas, then connect one drawing to one simple encounter.
The target is Web. The template still uses Forward Plus; Compatibility rendering adaptation,
export templates, an export preset, hosting, and browser verification remain to be done.
