# Stage 2: dog distraction (issue #38)

Updated: 2026-09-13.

The dog guards the woodland path until the protagonist draws food or a toy. This
replaces the static dog and unrestricted Stage 2 exit from issue #28.

## Playing the encounter

- Entry: `res://scenes/woodland/woodland_path.tscn`.
- Walk toward the dog: Idle changes to Idle Alert. Moving sideways makes it walk
  or run across the route to intercept you. Retreating makes it return home.
- Press E / the mapped sketchbook controller button, or click **Draw**. Draw on
  the transparent scene canvas; Undo, Clear and Back preserve the familiar river
  controls. Back retains the current draft. Drafting can start away from the dog;
  offering requires being within 16 horizontal world units of it.
- **AI drawing · Uses credits** uses the existing E02 / `dog` backend contract.
  Nothing is submitted until the player draws and explicitly offers it. The game
  passes the actual PNG to the persistent worker; FOOD and TOY are accepted.
- **Offline playtest · No AI** exposes explicit sample outcomes: Food, Toy,
  Unclear, Service failure, Unsuitable. It does not recognize the drawing or
  generate a mesh. It displays the actual sketch as the offered object.
- While the canvas is open, protagonist input and dog movement are paused.
  Submitting restores exploration; the forward route stays guarded while waiting.
  A result received far away waits for the player to return and press E.
- FOOD or TOY appears at the authored left roadside spot, alongside the original
  sketch. In AI mode the returned GLB is also displayed. The dog jumps once, runs
  over, slows to a walk, and collects it. One durability is spent on the accepted
  offering. The dog stays off the path with a heart and **Thank you!**.
- Unclear, unrelated, timeout, cancellation and invalid-model outcomes preserve
  the sketch and permit retry. Weapons are not a solution. Repeated submissions,
  duplicate offers and late canceled results cannot repeat the resolution.
- The player cannot cross world z=-4.8 until collection finishes, at any lateral
  position or height. The exit separately checks completion before transitioning
  at z=-28. Afterward, walking beside the path or jumping across the full-width
  exit works as before. Falling preserves encounter state; reloading the scene
  starts a fresh encounter, as with the existing preview navigation.

The drawing button is also visible during exploration in the river and shared
later-stage previews. It glows when the river or dog challenge is available.
Stages with no implemented drawing interaction keep it disabled. The HUD is
still hidden during drawing.

## Supplied model and animation

Source: the user's `Downloads/Scene2_warewolf` delivery. No Downloads runtime
references remain. Authorship/license details were not supplied separately.

`tools/pack_wolfdog.py` preserves the Idle delivery's mesh, skin and embedded
textures, adds animation accessors/buffer views from the other five files, and
maps tracks by exact node name. This avoids six duplicate meshes and texture
sets. The reproducible command is:

```sh
python3 tools/pack_wolfdog.py /path/to/Scene2_warewolf \
  3d_game/models/wolfdog/animated/wolfdog.glb
```

All six clips import on the same 32 animated tracks:
Idle (1.333 s), Idle Alert (1.600 s), Jump (2.200 s), Walk (1.000 s),
Run (0.467 s), Rest Pose (0.333 s). Rest Pose is retained for authoring, while
normal and collected states use Idle. Locomotion/idle clips loop; Jump plays once.
Transitions blend for 0.18 seconds. Horizontal hip translation is removed from
runtime copies, leaving vertical motion intact while the physics body owns travel.
The model faces +Z and uses scale 3.1 (approximately 4.81 units tall), close to the
previous large-dog size. The body retains unit scale and a simple box collider.
Walk speed is 2.6 units/second; run speed is 10, with a slower collection approach.
This is an authored encounter movement system, not general navigation AI.

Source SHA-256 checksums:

| File | SHA-256 |
|---|---|
| `Idel Alert.glb` | `e0dd0da9ba3072a19794e428c36bbd332d8d748bc0f34d6bd321bd84d90b5bdc` |
| `Idel.glb` | `463ea02f57bcbd3a96eacc67ac755f47a71a1f08373a8bc10ab1b79bac819237` |
| `Jump.glb` | `2c2281c629fddf5d4c27bd952eb3681d97091b9d6fb9fba553245a9ebf3d9562` |
| `RestPose.glb` | `2b7047758da5459c2fca6202b789aed096d132cd448c1e4e71e0387961e7f0f0` |
| `Run.glb` | `5ad1003ca3d98bf8cf46bff50e82b31c88f308a6866e6c07a8dce2ced49f225f` |
| `Walk.glb` | `a4443502b957cf7adce5d1886c79703296c7bec9b360c9f6b486bfc517ca58c8` |

Packed GLB SHA-256: `f4d97895072f235effabec3da31fb1e0e49ed2dc52d442ff6f78f2d85185e8d8`.
Keep the GLB, extracted PNG textures and import metadata together.

## Verification and limits

Godot 4.7.2, Apple M1, desktop Forward+:

- `dog_encounter_smoke.gd`: all six clips, idle/alert/interception, full-width
  airborne guard, drawing input lock, retained draft, empty and unsuitable
  submissions, uncertainty, failure, timeout, cancellation/stale results,
  distant completion, invalid model recovery, single-use offering, both food
  and toy routes, jump/run/walk, thank-you, collection-only unlock, real scene
  transition and fresh-scene reset.
- `woodland_exit_smoke.gd`: guarded and solved exits at x=-59, 0, 6.5, 25, 59.
- `woodland_smoke.gd`: terrain, collision, movement, framing, wind and shadows.
- `river_smoke.gd`: existing river/drawing/request/crossing regression and the
  now persistent drawing button.
- `wind_hill_smoke.gd`: solved-dog transition, Stage 3 movement and return.
- `desktop_generation_smoke.gd`: the existing offline Python worker, model loading,
  request routing, stale/canceled responses and river construction pass. The
  engine reported two ObjectDB instances at shutdown in this fixture test.
- Desktop renders inspected for idle, alert, interception, drawing, jump and collection.

Validation uses offline outcomes; no paid provider calls were made. The existing
E02 AI route is wired, but live apple/bone recognition and real generated-model
quality still require a live playtest. The existing desktop worker cannot run in
Web exports. Stage 3/4 drawing mechanics and final encounter audio remain separate
work. The complete game specification is not a claim of completed implementation.
