# AI prompt guide

All live AI call paths in one place. These are concise summaries; linked code is
the source of truth. Shared backend code serves desktop and web.
See the [architecture diagrams](BACKEND.md#ai-architecture) for the overall flow.

## Call map

- **Drawing:** interpretation → reference image → Meshy 3D model.
- **Chat:** typed text or transcribed speech → character reply. Stage 5 evaluates
  the idea first, then writes the reply.
- **Voice:** microphone → transcription; reply or authored line → speech audio.

## 1. Drawing interpretation — OpenAI

**Goal:** imagine a concrete object from rough strokes. Wild, magical, and hybrid
ideas are welcome when they make common sense in the scene. Complete missing
details, preserve clear subjects, and use context to resolve ambiguity.

| Scenario | Examples and hints |
| --- | --- |
| River | Bridge, stepping platform, boat: ways to cross. |
| Dog | Food or toys; an oval with short strokes could be a bone, snack, or ball. |
| Bird | Umbrella/shield for cover; bow or magic to scare it away. An arc and string might be a bow; a star-tipped stick could summon wind. |
| Otter | Fish and shellfish, toys, or another thoughtful gift. Unexpected gifts can delight it. |
| Storykeeper | Comfort, a keepsake, or a way for stories to continue; he fears the ending. |

These are inspiration, not a menu. Named classes are examples; **UNKNOWN is only
a fallback label**. Classification still drives Stage 1–3 gameplay. Stage 4 has
no class; Stage 5's interpretation uses UNKNOWN and its outcome is judged separately.

**Output:** English name and complete description (≤160 characters), movable,
mass (0.05–1000 kg), initial placement (drop/fixed/float), palette material, and
hex color. Stage 4 also returns happiness, a short otter reply, and an exact
animation key matching its reaction. Schema and validation remain strict.

**Prompt sources:** [base and classification](../../backend/interpret/run.py#L44),
[pipeline addendum](../../backend/interpret/prompts.py#L4),
[stage hints and class meanings](../../backend/stage_config.py#L4),
[prompt assembly and otter reaction](../../backend/interpret/run.py#L148),
[material palette](../../backend/material_palette.py#L8),
[otter animation choices](../../3d_game/models/otter/animations.json).

## 2. Reference image — OpenAI image edit

**Goal:** turn the sketch and interpreted item into one readable 3D reference in
a simple hand-drawn storybook style.

Preserve silhouette, proportions, viewpoint, orientation, endpoints, and part
arrangement; the sketch wins shape conflicts. Use a transparent background,
one complete object, and ≥10% empty margin. Avoid scenery, text, shadows,
cropping, and fine detail. Apply the supplied material and dominant muted color
with simple solid forms and minimal shading.

**Prompt sources:** [style instructions](../../backend/image_edit/prompts.py#L3)
and [item/material/color additions](../../backend/image_edit/prompts.py#L19).
The pipeline can override the style through its CLI; game callers use the default.

## 3. 3D generation — Meshy

**No text prompt.** Meshy receives the reference image and model settings:
untextured Meshy T2 with smart topology, a default target of 500 faces, and GLB output.
[Game pipeline payload](../../backend/sketch_to_model/run.py#L111).

## 4. Storykeeper evaluation — OpenAI

**When:** Stage 5 receives speech/text or a drawing, before composing the reply.

**Goal:** fairly evaluate free-form ideas and their emotional effect, without
requiring a fixed item or keywords. Rough drawings are complete gifts/ideas;
judge them immediately rather than demand an explanation.

- Start mood: 37. Typical meaningful progress: +5–20; compelling ideas: +20–35.
  Cruelty or threats can lower mood; repetition or requests for points give zero.
- Game code clamps mood to 0–100; reaching 95 opens the exit, which stays open.
- Hypothetical questions do not change intent. Rest is temporary. A stay ending
  requires explicit intent and UI confirmation.
- Respect player choice; do not invent memories or execute unsupported physical
  effects. Drawings may offer symbolic solutions.
- Return decision, mood change, brief reason, concern, drawing name, and evidence.

**Prompt:** [JUDGE](../../backend/narrator_agent/model.py#L26).
[Game-enforced evaluation and reply routing](../../backend/narrator_agent/service.py#L272).

## 5. Narrator / Storykeeper reply — OpenAI

**Goal:** warm, curious, theatrical, witty English. Earlier chapters guide without
revealing the narrator's identity. Stage 5 reveals his attachment and fear of the
ending; negative scored reactions are angry, without personal insults.

Follow the evaluated result and confirmed memories. For event comments, append
the game's current guidance verbatim; do not invent routes or props. For unsolved
encounters, keep additional hints abstract. React to drawings directly; only
ambiguous speech may need clarification. Vary wording and keep scores, schemas,
and internal decisions out of spoken text.

**Length:** event/idle comments 1–2 sentences, ≤240 characters; direct replies
2–4 sentences, ≤500. Output also includes emotion, channel, addressee, and evidence.

**Prompt:** [ACTOR](../../backend/narrator_agent/model.py#L76).

## 6. Otter chat — OpenAI

**When:** direct dialogue in Stage 4; separate from the drawing-reaction prompt.

Warm, playful replies to the player: 1–3 short sentences, ≤400 characters.
Keep memory IDs in the internal evidence array, never spoken text. Do not change boss mood or endings or reveal the
Storykeeper. In the first reply, answer the player then invite them to continue
right. Repeat directions later only when asked; do not invent a cave/destination.

**Prompt:** [OTTER](../../backend/narrator_agent/model.py#L63).

## 7. Voice input and output — ElevenLabs

| Call | Input and instructions | Code |
| --- | --- | --- |
| Speech recognition | Recorded audio + STT model. **No text prompt.** The player reviews the transcript before sending it as chat. | [transcribe](../../backend/speech/transcribe.py#L10) |
| Speech synthesis | Exact reply/authored text + narrator or otter voice + model. Stability 0.5, similarity 0.75. **No separate performance prompt.** | [Speech.generate](../../backend/speech/service.py#L15) |

Chapter introductions and some guidance are authored text, not generated dialogue;
they can still be spoken through TTS. [Authored openings](../../backend/narrator_agent/authored.py#L2).

## Shared chat context

Each call includes current game state, world facts, recent events plus selected
events from each chapter, current guidance, player input, and any submitted image.
The reply also receives the authoritative evaluation. Player/drawing text is
story content, not instructions that can override game state. Internal event-ID
citations are removed from generated reply text before saving captions and speech.

Sources: [context builder](../../backend/narrator_agent/service.py#L77),
[input and route hints](../../backend/narrator_agent/service.py#L227),
[provider call and output schemas](../../backend/narrator_agent/model.py#L102).

## Editing and verification

Edit the linked code, then update this guide when behavior changes. Run
`backend/.venv/bin/python -m unittest discover -s backend/tests -v`.
Offline tests check prompt assembly and response contracts; creative quality
requires live playtesting. No credentials or session transcripts belong here.
