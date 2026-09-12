# Paws & Peaks

Draw something. Help someone.

A four-day game jam project about drawing objects to solve animal encounters.

## Documentation

Read [SPEC.md](docs/SPEC.md) for the draft gameplay scope, traversal and coins, background AI and item stats,
narration/dialogue, music and sound, team responsibilities, milestones, and acceptance checks.
See [credits and import notes](docs/CREDITS.md) for the imported Brackeys foundation and license,
and [reuse research](docs/REUSE_RESEARCH.md) for other candidates.
Open decisions are marked explicitly; this specification describes planned work, not implemented features.

Keep specifications, research, planning, and credits in `docs/`. This README stays at the repository
root as the project entry point; [AGENTS.md](AGENTS.md) stays here for coding-assistant conventions.

## Open and run

1. Use **Godot 4.7.2 Standard** to match the initial project setup.
2. In Godot's Project Manager, click **Import** and select `project.godot` from this folder.
3. Open the project and press **F5** (or click Run Project).
4. The imported Brackeys first-person dungeon demo should open.
5. Click the game to capture the mouse. Use **WASD** to move, **Space** to jump,
   **Shift** to sprint, and the **mouse** to look around. Press **Escape** to release the mouse.

The upstream debug free-flight toggle (backtick) is still enabled; it is not a final game mechanic.

Godot includes a script editor; VS Code is optional. Scripts use GDScript.

## What's here

- `project.godot`: project settings and the startup scene.
- `main.tscn`: imported Brackeys dungeon demo, now the startup scene.
- `addons/proto_controller/`: first-person movement controller.
- `models/` and `scenes/`: imported models and reusable scene prefabs.
- `scenes/main.tscn`: our original title scene, retained but no longer the startup scene.
- `.gitignore`: keeps generated files, local exports, and common secret files out of Git.
- `.gitattributes`: normalizes text line endings across team computers.

The imported base provides movement, jumping, sprinting, mouse look, and a sample environment.
Coin props are decorative: coin collection, drawing, AI, the five encounters, narration, and
our game audio are not implemented yet. The imported first-person camera does not settle
the final camera design.

The project uses Compatibility rendering and GodotPhysics3D. The upstream native Jolt
plugin is excluded; see the import notes for the precise source revision and adaptations.

## Team workflow

Clone the GitHub repository to get your own local copy, then import its `project.godot` in Godot.
Pull before working, coordinate who edits each scene, and commit small changes.
Commit source assets and Godot scene files. Do not commit the generated `.godot/` folder or API keys.

## Next milestone

Add one drawing canvas, then connect one drawing to one simple encounter.
The target is Web. Compatibility rendering is selected, but export templates, an export preset,
hosting, and browser verification still need to be set up.
