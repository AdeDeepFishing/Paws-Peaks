# Credits and Import Notes

## Brackeys 3D Game in Godot

- Source: [Brackeys/3d-game-in-godot](https://github.com/Brackeys/3d-game-in-godot).
- Imported revision: `ee810266e0d71e993a63a15fa14b1ea6cb91d80e`.
- [Pinned project files](https://github.com/Brackeys/3d-game-in-godot/tree/ee810266e0d71e993a63a15fa14b1ea6cb91d80e/3d_game).
- Imported on September 12, 2026, at the user's request.
- License: CC0 1.0 Universal; the upstream README states that everything is free to use, including commercially. The original license text is preserved in [BRACKEYS_CC0.txt](licenses/BRACKEYS_CC0.txt).
- Includes the upstream ProtoController, sample environment, models, textures, and prefab scenes. ProtoController also identifies itself as CC0 in its script header.

## Integration

The contents of upstream `3d_game/` were copied into this repository's Godot project root. Existing repository history, documentation, Git configuration, and the original `scenes/main.tscn` title scene were retained. The upstream `.git` history and generated `.godot` cache are not included.

Adaptations:

- Project name changed to **Paws & Peaks**; the demo at `main.tscn` is the startup scene.
- Godot feature version updated from 4.3 to 4.7 to match our installed engine.
- Forward Plus replaced with Compatibility rendering for our intended Web target.
- Native `godot-jolt/` plugin excluded; physics changed from `JoltPhysics3D` to `GodotPhysics3D`.
- SSAO and glow disabled in the sample environment for the Compatibility baseline.
- Godot regenerated asset import metadata and script UIDs on first import. Source file permissions and four whitespace-only script lines were normalized.

The imported controller is first-person and includes a debug free-flight toggle. It is a starting point, not a completed implementation of our game specification. Coin stacks are decorative props, not collectible tokens. Final camera behavior, drawing/UI input switching, encounter logic, AI, audio, pushing, climbing, and Web deployment still require development.

## Verification

Godot 4.7.2 completed headless editor import and a 120-frame main-scene startup run with exit code 0 and no reported errors or warnings. `git diff --cached --check` passed.

Headless checks do not establish visual quality, interactive controls, or browser compatibility; these need a desktop playtest and a hosted Web build.
