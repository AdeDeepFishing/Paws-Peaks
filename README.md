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

1. Use **Godot 4.7.2 Standard** to match the initial project setup.
2. In Godot's Project Manager, click **Import** and select `project.godot` from this folder.
3. Open the project and press **F5** (or click Run Project).
4. You should see the Paws & Peaks title and "Our first Godot scene is running."

Godot includes a script editor; VS Code is optional. Future scripts will use GDScript.

## What's here

- `project.godot`: project settings and the startup scene.
- `scenes/main.tscn`: a minimal, editable title scene.
- `.gitignore`: keeps generated files, local exports, and common secret files out of Git.
- `.gitattributes`: normalizes text line endings across team computers.

This starter has no gameplay or AI integration yet.

## Team workflow

Clone the GitHub repository to get your own local copy, then import its `project.godot` in Godot.
Pull before working, coordinate who edits each scene, and commit small changes.
Commit source assets and Godot scene files. Do not commit the generated `.godot/` folder or API keys.

## Next milestone

Add one drawing canvas, then connect one drawing to one simple encounter.
The target is Web. Compatibility rendering is selected, but export templates, an export preset,
hosting, and browser verification still need to be set up.
