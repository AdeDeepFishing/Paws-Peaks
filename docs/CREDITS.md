# Credits and source notes

This record distinguishes active components from retained source files. It is not
a complete production export manifest; outstanding verification is noted below.

## Repository findings

| Component | Evidence | Scope |
| --- | --- | --- |
| Godot | Active Godot project and Web export | Game engine; MIT and bundled engine third-party notices |
| Brackeys / ProtoController | Header in `3d_game/addons/proto_controller/proto_controller.gd` identifies Brackeys and CC0 | Starter controller and dungeon resources retained; the active hero uses separate gameplay scripts |
| Cormorant Upright | Two TTFs under `3d_game/ui/title/`, referenced by title and ending scripts | Active font; OFL notice under `docs/3d_game/assets/title/Cormorant-OFL.txt` |
| Three.js | `docs/3d_game/assets/overworld/THREE-LICENSE.txt`; overworld and stage integration notes | Scene authoring/source workflow; no standalone Three.js runtime found in the game |
| Legacy Godot Jolt extension | `3d_game/godot-jolt/.gdignore`, LICENSE.txt, THIRDPARTY.txt | Retained repository dependency, disabled; project uses GodotPhysics3D and Web extensions are disabled |
| Starter scenes/models | Dungeon scenes, barrels, buildings, chest and controller resources remain under `3d_game/` | Export uses all_resources and excludes main.tscn, not all its former dependencies; do not claim all unused starter resources are absent |

The local export cache contains a compiled ProtoController scene. This is additional
evidence that excluding the old main scene alone does not exclude every starter
resource. This review did not enumerate the live production PCK.

Existing source notices should remain with their components. The OFL and Three.js
notices currently sit outside the Godot project; a public credits/notices delivery
still needs to be checked before treating attribution as complete.

The team reports that environments, illustrations, characters, animations, and
music were generated using OpenAI GPT Astra under its direction. The repository
alone cannot verify the exact model used for every asset, subscription ownership,
or output rights. Describe that provenance as team-reported; do not infer it from
a GLB, PNG, or OGG file. Likewise, paid Meshy accounts and the ElevenLabs Scale
plan are team-provided details, not independently verified account facts.

No separately sourced dataset was identified in this focused review. This is not
a claim about datasets used internally by proprietary model providers.

## Suggested submission text (under 200 words)

Godot Engine powers the game (MIT, with its bundled third-party notices).
Brackeys' 3D Game in Godot and ProtoController provided the starter foundation
(CC0 1.0); starter resources remain in the repository. Cormorant Upright supplies
title typography (SIL OFL 1.1). Three.js informed source scene-generation workflows
(MIT); no Three.js runtime is used by the Godot game. The legacy Godot Jolt
extension remains in the repository with its MIT and third-party notices, but is
disabled in the game.

OpenAI APIs and ChatGPT support sketch interpretation, reference-image generation,
dialogue, and development/design assistance. The team reports using OpenAI GPT
Astra to create environments, illustrations, character models, animations, and
music under human creative direction and refinement. Meshy generates object
geometry through team paid accounts. ElevenLabs provides speech synthesis and
recognition; Voice Library selections are Elariel X – Epic Queen Ethereal and
Lulu Lolipop – High-Pitched and Bubbly. These proprietary services and outputs
remain subject to their applicable service, output, and Voice Library terms.
Vercel and Render host the frontend and backend. No separately sourced dataset
was identified in the repository review.

## Verified license sources

- [Godot MIT license](https://godotengine.org/license/)
- [Brackeys CC0 license](https://github.com/Brackeys/3d-game-in-godot/blob/main/LICENSE)
- [Cormorant OFL](https://github.com/CatharsisFonts/Cormorant/blob/master/OFL.txt)
- [Retained Three.js notice](3d_game/assets/overworld/THREE-LICENSE.txt)
- [Retained Godot Jolt license](../3d_game/godot-jolt/LICENSE.txt)
- [Retained Godot Jolt third-party notices](../3d_game/godot-jolt/THIRDPARTY.txt)

## Gameplay video

[Watch the gameplay demo](https://drive.google.com/file/d/1cWQvDYa-xe-_3DAUKSvzCvWzmE3zQyFU/view?usp=sharing)

The recording is hosted separately and is not included in the source repository.
