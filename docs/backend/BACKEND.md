# Backend guide

The single backend reference for implementation, setup, stage contracts, testing,
benchmarking, and backlog. Game-side integration stays in
[Desktop Generation](../3d_game/DESKTOP_GENERATION.md); shared scope stays in [SPEC.md](../SPEC.md).

- [Public sketch-to-model interface](#sketch-to-model-interface)
- [Three-call flow](#three-call-flow), [current API steps](#current-flow), and [folder layout](#feature-layout)
- [Setup and run](#setup-and-run)
- [Stage classes and request contract](#current-multi-stage-request-contract)
- [Internal implementation and recovery](#internal-implementation)
- [Outputs](#outputs-and-recovery) and [local preview](#local-model-preview)
- [Tests and stage samples](#validation)
- [Benchmarking](#performance-profiling)
- [Development requirements](#contracts-and-failure-handling)
- [Samples and credits](#samples-and-credits)
- [Backlog](#backlog)
- [Generated examples](GENERATED_EXAMPLES.md)
- [Historical benchmarks](#historical-benchmarks)

## Sketch-to-model interface

**Sketch-to-model is the only public generation interface.** The game submits one
sketch and its stage identity, then receives item data and generated assets.
`interpret/`, `image_edit/`, and `model_generation/` are internal steps; callers do
not invoke them separately or supply provider prompts, keys, or class lists.

### Transport and lifecycle

The current desktop transport is a local file mailbox, not an HTTP endpoint.
Godot's `GenerationWorker` autoload starts the Python bridge once at game startup;
`game_bridge/run.py` is the transport adapter for sketch-to-model, not another
public generation service. Startup makes no provider calls.

1. Create a unique request directory inside the running worker's directory.
2. Save the drawing bytes as `request/input.png` before publishing the request.
3. Write `request/request.tmp`, close it, and atomically rename it to `request/request.json`.
4. Read `status.json` for the latest response; the game polls every 0.2 seconds.
   `response/results.jsonl` retains the timestamped response history.
5. Stop waiting when `status` becomes `SUCCEEDED` or `FAILED`. Ignore responses
   whose request, encounter, or game-stage identity no longer matches the session.

The worker claims `request/request.json` as `request/claimed.json` and prevents duplicate execution
with `started.lock`. To cancel local waiting, create a `cancel` marker in the job
directory. Cancellation is reported as `FAILED` with `error: CANCELED` at a progress
boundary; it does not guarantee cancellation of an already-submitted provider job.
A browser-hosted HTTP interface has not been implemented.

### Example request

Stage 1 (River), live generation:

```text
<worker-directory>/E01-example/
  request/
    input.png
    request.json
  response/
    results.jsonl
    artifacts/       # Live model, reference image, and retained pipeline files
  status.json        # Latest status and arrival timestamps
```

`request/request.json`:

```json
{
  "request_id": "E01-example",
  "encounter_id": "E01",
  "game_stage": "river",
  "mode": "live"
}
```

| Input | Contract |
|---|---|
| `request_id` | Unique string for this submission; 1–100 ASCII letters, digits, underscores, or hyphens |
| `encounter_id` | `E01`–`E04`, matching the selected game stage |
| `game_stage` | `river`, `dog`, `crows`, or `otter`; see [stage mapping](#approved-classes) |
| `mode` | `live` runs the three paid generation steps; `fixture` returns saved sample assets without provider calls, available for River and Dog |
| `request/input.png` | One drawing in the request directory, supplied separately from JSON; game-generated PNG, at most 1 MiB |

`stage_number` is backend configuration, not a request field. The request contains
no image URL, Base64 field, provider credentials, or second image. Two-image support
is [backlogged](#backlog).

### Example response

An illustrative completed `status.json` for the request above follows. Paths and
time are example values, not a recorded live run. Real paths are absolute local
paths within the originating job directory; live generated assets are under its
`response/artifacts/` subdirectory. Fixture assets are directly under `response/`.

```json
{
  "schema_version": 1,
  "request_id": "E01-example",
  "encounter_id": "E01",
  "game_stage": "river",
  "mode": "live",
  "input_path": "/example/worker/E01-example/request/input.png",
  "stage": "complete",
  "status": "SUCCEEDED",
  "item": {
    "name": "A little bridge",
    "description": "A sturdy little bridge ready to span the creek.",
    "type": "BRIDGE",
    "movable": false,
    "texture_key": "wood",
    "color": "#B88755"
  },
  "reference_path": "/example/worker/E01-example/response/artifacts/reference.png",
  "model_path": "/example/worker/E01-example/response/artifacts/model.glb",
  "preview_path": "/example/worker/E01-example/response/artifacts/model.png",
  "request_received_at": 1789257600.0,
  "response_received_at": 1789257620.0,
  "updated_at": 1789257620.0,
  "pool_checked": true,
  "pool_return_code": 0
}
```

| Response field | Meaning |
|---|---|
| `schema_version` | `1` for the game-facing sketch-to-model status |
| Identity fields | Echo the originating `request_id`, `encounter_id`, `game_stage`, and `mode` |
| `stage` | Progress: `starting`, `description`, `reference_image`, `model`, `preview`, `complete`, or `error` |
| `status` | `PENDING`, `SUCCEEDED`, or `FAILED` |
| `item` | Validated interpretation; appears before model completion; [field bounds](#item-validation) |
| Asset paths | `reference_path`, `model_path`, and `preview_path` appear as assets become available |
| `request_received_at` | Unix seconds when the backend observes the published request, before queueing; retained through completion |
| `response_received_at` | Unix seconds when the latest result or terminal failure reaches the bridge; `null` until a result arrives; pool verification preserves it |
| `updated_at` | Unix timestamp in seconds, updated for each published response |
| `error` | Sanitized error code on failure; no raw provider response |
| `preview_error` | Optional `PREVIEW_RENDER_FAILED`; the GLB can still succeed without `preview_path` |
| `pool_checked`, `pool_return_code` | Added after the listener checks the completed job; may be absent on the first terminal response |

Receipt is published immediately, even when another job is running. Arrival timestamps
use the backend clock, not provider generation clocks; benchmark durations use a
monotonic clock. Each new item/asset or terminal result updates `response_received_at`,
and its previous value remains in `response/results.jsonl`. The request, response,
and status paths stay within one unique job directory.

Progress snapshots are cumulative: a `PENDING` response can already contain `item`
or `reference_path`. The frontend may display these early, but should wait for
`SUCCEEDED` before treating the model as ready. Preview failure preserves model
success. No credentials or signed provider URLs enter this response.

Example failure before any item or generated asset becomes available:

```json
{
  "schema_version": 1,
  "request_id": "E01-example",
  "encounter_id": "E01",
  "game_stage": "river",
  "mode": "live",
  "input_path": "/example/worker/E01-example/request/input.png",
  "stage": "error",
  "status": "FAILED",
  "error": "SERVICE_UNAVAILABLE",
  "request_received_at": 1789257600.0,
  "response_received_at": 1789257601.0,
  "updated_at": 1789257601.0
}
```

Common failures include `INVALID_REQUEST`, `STAGE_NOT_CONFIGURED`,
`FIXTURE_NOT_AVAILABLE`, `SERVICE_UNAVAILABLE`, `RATE_LIMITED`, `OPENAI_IMAGE_ERROR`,
`INVALID_MODEL_OUTPUT`, `GENERATION_FAILED`, `CONFIG_ERROR`, `POLL_TIMEOUT`, and
`CANCELED`. Failed snapshots may retain earlier successful fields.

`status: FAILED` with `error` and the originating `request_id` is the backend's
terminal failure signal. The desktop adapter handles it before partial results,
clears the failed result, and transitions `DrawingRequest` to `FAILED`. It emits
`request_failed(request_id, error_code, message)` so game callers can react explicitly.
The current encounter UI displays the message and allows drawing again; the saved
sketch is retained. A new submission gets a fresh request ID, and late responses
from the failed request are ignored. Do not resubmit automatically: remote generation
may still exist after a timeout.

### Local command-line entry point

For manual callers, use the same sketch-to-model operation:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --image backend/tests/stage1/input.png --game-stage river --dry-run
```

Remove `--dry-run` to generate with providers. The direct CLI prints pipeline
JSON events to stdout and diagnostics/profiles to stderr; it does not emit the
mailbox's version-1 envelope or accept `request.json`. Game callers use the mailbox
contract above. The [stage runner](#validation) selects bundled samples and adds
benchmark logs to this same operation.

## Three-call flow

Interpretation makes a best-effort guess of a reasonably common object, then
classifies it in the same AI call. The response contains only `item`.
The prompt requests this reasoning order; offline tests verify the contract and
routing, not the model's actual reasoning or recognition quality.

Repeated code-formatted names below denote the same data passed between calls:
`SKETCH` is the original PNG/JPEG, `ITEM` is the interpretation result's `item`,
`REFERENCE_IMAGE` is the generated object-reference PNG, and `MODEL_TASK_ID`
identifies the Meshy job.

| AI call | Input | Output |
|---|---|---|
| **1. Interpret** | `SKETCH` + interpretation prompt + game stage's allowed classes | `{ "item": ITEM }`, where `ITEM` contains `name`, `description`, `type`, `movable`, `texture_key`, and `color`; no `status` field |
| **2. Image edit** | `SKETCH` + `ITEM.name` + `ITEM.description` + `ITEM.texture_key` + `ITEM.color` + style instructions + image settings | `REFERENCE_IMAGE`: one 816 × 816 object-reference PNG, prompted to use `ITEM.color` as its dominant base color |
| **3. 3D generation** | `REFERENCE_IMAGE` + Meshy T2 settings: target 500 faces, no textures, GLB format | `MODEL_TASK_ID`: task ID used to retrieve the model |

Within the single interpretation call, first identify a reasonably common object
from the sketch, making a best-effort guess even when confidence is low. The allowed
classes must not influence that identity. Then classify the identified object using
the game stage's allowed classes; use `UNKNOWN` if none fits. Ambiguity alone does
not stop generation. Also classify mobility from the identified object: portable
or loose objects use `movable: true`; fixed structures use `movable: false`.
API failures and invalid responses remain errors.

After the three AI calls, status polling takes `MODEL_TASK_ID` and returns task
status/progress plus `MODEL_GLB_URL` on success. Downloading `MODEL_GLB_URL` returns
the GLB bytes saved as `model.glb`. Polling and downloading are additional HTTP
requests, not additional AI generation calls.

## Current flow

The three calls run sequentially. See [item validation](#item-validation) for the
implemented schema.

| Call | Endpoint | Provider encoding |
|---|---|---|
| Interpret | `POST https://api.openai.com/v1/responses` | Sketch as an `input_image` data URI; strict `drawing_interpretation` JSON schema; `store: false`, `max_output_tokens: 800`, `detail: auto` |
| Image edit | `POST https://api.openai.com/v1/images/edits` | Original sketch in multipart field `image`; response PNG in `data[0].b64_json` |
| 3D generation | `POST https://api.meshy.ai/openapi/v1/image-to-3d` | Reference PNG data URI in `image_url`; response task ID in `result` |

The interpreted item is available before image editing starts. The bridge publishes
cumulative item, reference-image, model, and preview updates; see the
[public interface](#sketch-to-model-interface). The River and Dog encounters display
the early interpretation and reference image through their shared
[generation overlay](../3d_game/DESKTOP_GENERATION.md#lifecycle-and-files).
The final model preview is rendered locally.

For model/image defaults and overrides, see [Setup and run](#setup-and-run).
For polling, artifacts, and retry behavior, see [Outputs and recovery](#outputs-and-recovery).
Prompt locations and adapter responsibilities are listed under
[Code ownership](#code-ownership-and-cleanup).

The backend uses local Python 3.9+ scripts and the shared `backend/.venv` and ignored
`backend/.env`. The desktop game starts the persistent listener with
`backend/game_bridge/run.py --serve`; a Web export cannot launch Python. See
[desktop integration](../3d_game/DESKTOP_GENERATION.md).

## Feature layout

```text
backend/
  .env                        # Ignored local credentials shared by features
  .env.example                # Tracked blank configuration template
  .venv/                      # Ignored shared Python environment
  stage_config.py             # Backend-owned class sets for all four game stages
  game_bridge/run.py          # Persistent request listener and result logs
  utils/
    render.py                 # Local GLB-to-PNG renderer
    common.py                 # Local configuration and PNG/JPEG input helpers
    profiling.py              # Optional command/stage timing and JSON reports
  sketch_to_model/
    run.py                    # Primary sketch -> description -> reference -> T2 flow
  interpret/                  # API step 1
    run.py                    # OpenAI: image -> narrative and game item JSON
    prompts.py                # Pipeline interpretation instructions
  image_edit/                 # API step 2
    run.py                    # OpenAI: sketch + prompt -> reference image
    prompts.py                # Style and reference-image prompt
  model_generation/           # API step 3
    run.py                    # Meshy: image -> untextured mesh job/status/GLB
  samples/banana.jpg          # Shared development input
  tests/                      # Offline tests for the pipeline and adapters
  output/                     # Ignored job manifests and generated models
```

## Setup and run

Run all commands below from the repository root. Python 3.9+ and its standard
library are sufficient. Create the shared environment if needed:

```sh
python3 -m venv backend/.venv
if [ ! -e backend/.env ]; then
  cp backend/.env.example backend/.env
fi
chmod 600 backend/.env
```

Open the ignored `backend/.env` in your editor and fill in the keys. Keep tracked
credential examples blank:

```dotenv
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4.1-mini
MESHY_API_KEY=
MESHY_MODEL=meshy-6
```

The two providers use separate accounts/credits. OpenAI credentials need access
to Responses and image editing. Environment variables override `.env`; values
are literal single lines with optional surrounding quotes. Full-line comments
are supported; inline comments and shell expansion are not. Paths to local
configuration resolve from the backend directory.

Validate offline first. The second command below makes paid requests:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --dry-run
backend/.venv/bin/python backend/sketch_to_model/run.py
```

The default source is `tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png`.
Use `--image path/to/sketch.png` for another input. Each live invocation makes one
OpenAI interpretation request, one OpenAI image edit, and one Meshy creation after
preceding stages succeed. Ambiguity is handled by a best-effort object guess;
invalid responses and provider errors stop the pipeline. There are no creation retries.

| Stage | Default settings |
|---|---|
| Interpretation | Configured `OPENAI_MODEL` (default/template: `gpt-4.1-mini`), strict item JSON schema |
| Reference image | `gpt-image-2.5-flare`, **816 × 816**, low quality, transparent PNG |
| 3D | `meshy-t2`, Smart Topology, target **500 faces**, GLB, **textures disabled** |

Options: `--style-prompt` replaces the reference-image instructions;
`--openai-image-model` overrides Flare; `--openai-image-size 1024x1024` compares the
larger reference image.
`--target-faces` changes the T2 target (100–15,000; default 500).
The lower face target favors lightweight geometry. The single textured comparison
was faster at 500 faces, but does not isolate the face-count effect. Use
`--target-faces 1000` to reproduce the earlier geometry setting.
Texture experiments and their measured performance are retained in
[Generated examples](GENERATED_EXAMPLES.md).

`OPENAI_MODEL` configures interpretation in both this pipeline and the standalone
narrative CLI. The standalone adapter's `MESHY_MODEL` setting does not override the
pipeline's T2 model.

The image prompt preserves the sketch and description, asks for the whole object with
10% margins, and avoids decorative detail. These are model instructions, not enforced
visual guarantees. The accepted 816-pixel test changed triangular braces into ladder
rungs; intent and structural fidelity still need human review.

### Reusable material palette

Interpretation selects `texture_key` from the 16 keys in
`3d_game/assets/materials/palette.json` and returns an opaque `color` in `#RRGGBB`
format. That same catalog supplies the prompt descriptions, schema enum and game
material properties. Invalid keys and malformed colors fail validation.

Image edit uses the same material key and color to guide the reference's dominant
base color. Godot tints the bundled tile and applies it across the untextured mesh
with local triplanar mapping. No extra image call is needed.

See [Material palette](../3d_game/MATERIAL_PALETTE.md) for rendering, asset sizes,
keys, preparation, provenance and verification limits.

## Current multi-stage request contract

**The backend selects the classification classes from the game stage. All four stages
share the same generation pipeline. The game never supplies a class list.**

### Approved classes

These sets were confirmed on September 13, 2026. Class labels are case-sensitive.
Each configuration entry also defines `stage_number` (1–4); the bridge uses this
number to select the River or Dog fixture. Requests still send the named
`game_stage`, which the backend resolves through this configuration.
The executable source of truth is [`backend/stage_config.py`](../../backend/stage_config.py).

| Stage number | `game_stage` | `encounter_id` | Allowed `item.type` values |
|---|---|---|---|
| 1 — River | `river` | `E01` | **`BRIDGE`, `BOAT`, `UNKNOWN`** |
| 2 — Large Dog | `dog` | `E02` | **`FOOD`, `TOY`, `WEAPON`, `UNKNOWN`** |
| 3 — Crows | `crows` | `E03` | **`BOW`, `MAGIC`, `DEFENCE`, `UNKNOWN`** |
| 4 — Otter | `otter` | `E04` | **`GIFT`, `TOOL`, `UNKNOWN`** |

These are separate allowed sets, not one combined enum. For example, `FOOD` is valid
for Dog but invalid for Crows; `BOW` is valid for Crows but invalid for Dog. The AI
must classify within the selected stage's categories. It must not borrow a category
from another stage. The fifth-stage boss in the broader game specification has no
backend classification configuration yet.

`UNKNOWN` means the identified or guessed object fits none of the stage's named
categories. It has the usual item fields and continues through generation. Every
stage must include this fallback. Low confidence alone does not stop generation.

### Request and routing

Use the [public sketch-to-model request](#example-request). `game_stage` names the
game challenge; response `stage` describes pipeline progress. Their meanings are
different. `game_stage` and `encounter_id` must match the table above.

The persistent Python listener validates the request and queues its job. The selected
class set is passed through to OpenAI interpretation and checked in three places:

1. The prompt lists the classes allowed for this game stage.
2. The strict JSON schema sets `item.type.enum` to exactly that class set.
3. Backend response validation rejects any type outside the selected set.

Godot validates request/stage identity, field types, string lengths and file paths.
It does not maintain a second classification enum. Changing backend class sets does
not require adding the same class names to Godot.

### Shared generation and results

The interpretation result contains only `name`, `description`, `type`, `movable`, `texture_key`, and `color` across
all stages. Numeric stats and capability tags are not part of the item contract.

As each result becomes available, the worker appends a cumulative record to
`response/results.jsonl` and atomically updates `status.json`. Results include local paths:

| Field | File |
|---|---|
| `input_path` | Original sketch |
| `reference_path` | Generated reference image |
| `model_path` | Downloaded GLB |
| `preview_path` | Locally rendered PNG |

Every update retains request identity, `game_stage`, progress `stage`, status and an
`updated_at` timestamp. The listener checks finished thread-pool jobs against the
status file and records `pool_checked` and `pool_return_code`. Provider credentials,
signed download URLs and raw provider errors are excluded from these game-facing logs.

Godot polls every 0.2 seconds. Item and reference-image signals can arrive before
completion. `SUCCEEDED` is published after the GLB and preview step; preview failure
still delivers the GLB with `preview_error`. See [desktop integration](../3d_game/DESKTOP_GENERATION.md)
for worker lifetime, cancellation and scene integration.

### Classification is not challenge completion

Being a valid class does not guarantee that an object solves the challenge. Gameplay
rules are evaluated separately in Godot. River currently accepts `type: BRIDGE`
with `movable: false`
for its fixed crossing, with placement committed once per encounter. Recognizing `BOAT` does not
implement boat movement. Stage 2 renders FOOD, TOY and UNKNOWN, but only FOOD and
TOY distract the dog and unlock the path. UNKNOWN permits another sketch; submitting
replaces the previous object. Later-stage success rules remain design work.

Stage 3 adds backend-owned meanings for its classification step: an identified
ordinary umbrella, parasol, shield, helmet or protective cover belongs to DEFENCE,
including protection from weather or animals. The model still identifies the
actual sketch first; stage context must not change that identity to solve the level.
This addresses the September 13 #59 playtest, where generated umbrellas were
classified UNKNOWN. Offline request tests verify the guidance is sent only for
Stage 3; new live classification accuracy has not been measured.

### Changing a class set

Edit only the stage's `classes` tuple in `backend/stage_config.py`, update this table
and the relevant specification section, then run:

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

Restart the game to reload the persistent worker's configuration. Test generation
without providers using River fixture mode. For a local configuration/input check:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --game-stage crows --dry-run
```

A missing class set fails with `STAGE_NOT_CONFIGURED` before provider calls. An invalid
stage/encounter pair fails with `INVALID_REQUEST`; an unavailable offline fixture
fails with `FIXTURE_NOT_AVAILABLE`. No paid generation is automatically retried.

### Item validation

Interpretation returns exactly `{ "item": { ... } }`, without `status` or a null
item. Items require exactly these fields; additional properties are rejected:

| Field | Validation |
|---|---|
| `name` | Nonempty string, at most 40 characters |
| `description` | String, at most 160 characters |
| `type` | One class allowed by the selected stage |
| `movable` | Boolean: `true` for loose/portable objects, `false` for fixed structures |
| `texture_key` | One key from the shared 16-material palette |
| `color` | Opaque hex tint matching `^#[0-9A-Fa-f]{6}$` |

`attack_power`, `range`, `speed`, `durability`, and `tags` are removed from the
schema and are no longer requested from OpenAI. The game validates the same
six-field object. Saved historical results may contain the old fields; the
fixture adapter projects its retained sample onto the current contract.

The standalone interpretation CLI adds `schema_version: 2` and `request_id` to the
item-only result. The desktop adapter separately supplies `status: recognized` to
the existing Godot drawing-request interface; worker progress statuses such as
`PENDING` and `SUCCEEDED` remain unchanged. The Meshy task manifest uses version 1. Neither is interchangeable with the
worker's cumulative progress records. Preserve the originating request identity.

## Internal implementation

The three provider adapters are implementation details of sketch-to-model. Their
Python functions and maintenance CLIs are not separate game-facing interfaces.

| Step | Internal function | Responsibility |
|---|---|---|
| Interpret | `interpret.run.interpret()` | One OpenAI Responses request, followed by item validation |
| Image edit | `image_edit.run.generate()` | One OpenAI multipart image-edit request, followed by PNG validation |
| Model generation | `model_generation.run.create_job()` | One Meshy submission with durable task identity |

Interpretation has a 15-second socket timeout; image editing has 180 seconds;
Meshy requests/downloads have 30 seconds. These are socket limits, not guaranteed
end-to-end deadlines. The shared input helper validates PNG/JPEG signatures and
size rather than fully decoding images. Interpretation uses `store: false`, which
is not a promise of zero provider retention.

### Model generation and recovery

The pipeline polls the submitted task and downloads its model. New manifests use
`model_generation`; existing `image_to_3d` and `image_text_to_3d` manifests remain
readable. Maintenance tooling may inspect an existing manifest using its original
path; do not create another task merely to check status or download an output.

`SUBMITTING` or `SUBMISSION_UNKNOWN` can mean the provider accepted work before
the connection failed. Check the provider dashboard and recover its task identity
before deliberately submitting again. Stopping local work does not cancel the
provider job. Model-job manifests are internal files and are not public responses.

Downloads use HTTPS `assets.meshy.ai` without forwarding provider credentials,
enforce a 64 MiB limit, validate the GLB header/version/declared length, and preserve
existing output files. These checks do not establish full glTF validity or quality.

## Outputs and recovery

Game mailbox jobs keep inputs under `request/`, response history and fixture assets
under `response/`, and live pipeline files under `response/artifacts/`. `status.json`,
`started.lock`, and the optional `cancel` marker remain at the job root. The pipeline
continues to retain its validated input copy alongside its generated artifacts.

The standalone pipeline and stage runner retain their own output layout below;
they do not submit through the game mailbox.

Outputs are saved under ignored `backend/output/sketch_to_model/<run-id>/`:
`input.png` (or `input.jpg` for JPEG sources), `description.json`, `reference_prompt.txt`, `image_edit_settings.json`, `reference.png`,
`model_job.json`, `model.glb`, and `model.png` (a 512 × 512 rendered model preview). The edited PNG enters T2 as a data URI. Local
PNG/JPEG input and the generated transparent PNG must fit the existing 1 MiB image limit.

Stage results and local paths print as JSON lines on stdout. Diagnostics and profiles
go to stderr; profiles also save under `backend/output/profiles/`. Credentials and
signed URLs must not be printed. The Meshy manifest can contain a signed URL and must
stay local. Image-edit settings contain the submitted prompt and non-secret generation settings.
The bridge publishes item JSON immediately after interpretation and the local reference
path immediately after image editing. Each request retains timestamped cumulative
updates in `response/results.jsonl` and the latest atomic snapshot in `status.json`, including
local image/model paths. The listener checks completed thread-pool jobs against the
final status and records `pool_checked`/`pool_return_code`; crashes and missing final
results are logged as failures without retries.

Meshy status polling calls `GET /openapi/v1/image-to-3d/{task_id}` immediately after
submission, then sleeps 0.1 seconds after each unfinished response. Request starts
are separated by the preceding request's duration plus 0.1 seconds. The loop has a
600-second deadline; an in-flight request can run past it. A successful response
provides the download URL in `model_urls.glb`; `FAILED` or `CANCELED` stops the loop.
OpenAI image editing
has a 180-second socket timeout, not a guaranteed completion deadline. Restarting
the pipeline creates new paid work. On failure, inspect existing outputs and recover
the Meshy task using the [internal recovery tooling](#model-generation-and-recovery) instead of
blindly rerunning. `SUBMISSION_UNKNOWN` indicates an uncertain paid submission.

## Local model preview

After saving the GLB, the pipeline renders `model.png` beside it using the
standard-library CPU renderer in `backend/utils/render.py`. This is a
clay-shaded view of the actual static geometry, with automatic framing and a light
background; it does not reproduce textures or the game scene. No AI call, GPU,
window, or additional package is needed. Completion includes `preview_path`; a
preview failure includes `preview_error: PREVIEW_RENDER_FAILED` while preserving
the successful GLB. The game bridge applies the same step to offline fixtures.

Render an existing file without running generation:

```sh
backend/.venv/bin/python backend/utils/render.py path/to/model.glb
```

Local 512-pixel preview tests took 0.07–0.48 seconds; both outputs were visually
inspected. The renderer handles static
triangle meshes with node transforms and embedded position/index buffers. Skins,
morph targets, sparse accessors and required extensions are unsupported.

## Validation

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

The offline suite contains 20 focused tests covering the interpretation contract,
image editing, model jobs/downloads, game handoff, failure propagation, credential
transport, sample routing, profiling, and preview rendering. Per-stage duplicate
checks and peripheral edge-case tests have been removed. Stage sample images remain
under `backend/tests/stage1/` through `stage4/` for the manual runner below.

Run only the pipeline checks during focused flow work:

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -p test_sketch_to_model.py -v
```

Each stage folder contains an input image for the manual pipeline runner:
Stage 1 reuses Yanwen's saved river sketch
(`tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png`),
Stages 2 and 4 contain synthetic line drawings of a bone and a wrapped gift.
Stage 3 uses an AI-generated black-line umbrella sketch. Recorded model results
are in [generated examples](GENERATED_EXAMPLES.md); sample images alone do not
establish gameplay outcomes.

Validate a sample offline:

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage1 --dry-run
```

Submit that image through the existing sketch-to-model pipeline (paid OpenAI and
Meshy calls, requiring local credentials):

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage1
```

Replace `--stage1` with `--stage2`, `--stage3`, or `--stage4`; exactly one stage is
required. Image paths resolve relative to the script, including when run outside
the repository. The pipeline builds provider requests using the selected image
and backend stage classes, retaining the original image and results under ignored
`backend/output/sketch_to_model/<run-id>/`. This manual runner is excluded from
unittest discovery; automated routing tests mock its pipeline calls.

Latest palette verification: the 20-test offline backend suite and desktop-generation
smoke passed. Godot reported two ObjectDB instances at desktop-test shutdown.
Saved Stage 2 material replays and the UNKNOWN flower render/retry check passed.
The broader dog smoke has patrol and sketch-placement failures; it is not a passing
check for this branch. Live color matching remains unmeasured. Historical provider
timings and their limitations are recorded in [Generated examples](GENERATED_EXAMPLES.md).

## Performance profiling

The sketch-to-model pipeline profiles automatically. Use its stage runner for
an offline check or a benchmarked live submission:

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage1 --dry-run
backend/.venv/bin/python backend/tests/stage_test.py --stage1
```

The second command uses provider credits. No separate calls to the internal API
steps are needed.

Each profiled invocation prints a `PROFILE` JSON record to stderr and saves the same
record under `backend/output/profiles/<unique-run-id>.json`. Stdout retains its normal
result/error JSON, so Godot and output redirection continue to work. Profiles contain
request/task IDs and numeric measurements, never keys, images, prompts, or asset URLs.
A profile-file write failure does not fail a successful generation or download.

Reports include:

- `command_wall_ms`: elapsed time after argument parsing through completion/error handling,
  excluding interpreter startup/imports and profile-output overhead.
- `local_cpu_ms`: CPU time used by this local Python process, excluding remote computation.
- `timings_ms` and `stage_calls`: local configuration/image preparation, API round trips,
  response validation, and model download/header validation/file writing as applicable.
  Timings use a monotonic clock and still record stages that fail or time out.
- `request_body_bytes` and `response_body_bytes`: JSON payload sizes excluding HTTP headers;
  Base64 inflation is included. URL mode does not measure the provider's image fetch.
- `download_bytes` and `download_mib_per_second`: GLB transfer size and effective throughput,
  including connection setup and server wait, available after a download response is read.
- `server_queue_ms`, `server_processing_ms`, `server_total_ms`: Meshy task durations derived
  from its positive, ordered `created_at`, `started_at`, and `finished_at` timestamps.
  Missing, zero, or invalid intervals are omitted rather than presented as zero time.

API round-trip time includes network setup, upload, provider waiting/processing, and response
download; it is not an isolated inference benchmark. Meshy server processing can include
remeshing. Its creation request returns before model generation completes. To measure the
completed task, profile `status` or `download` after it finishes. Durations use only the
provider's clock; manual delays between CLI commands do not inflate server timings.

Profiling makes no additional API calls or automatic retries. A profiled `create` still
creates one paid job; a profiled `--dry-run` makes no network requests. Dry-run timings
are setup measurements, not live API performance. GPU/RAM usage, actual mesh face counts,
and Godot import/render performance are not measured by this helper.

### Stage benchmark logs

Live stage runs immediately print `BENCHMARK` JSON records to stderr and append
those records to `benchmark.jsonl` beside the run's input and outputs. Records
include UTC timestamps, elapsed milliseconds since run start, operation duration,
stage identity, and run ID. Each OpenAI interpretation/image-edit response, Meshy
submission/status poll, and model download is logged as its adapter returns.
Failed calls are labeled `api_failure`, and `run_finished` records total time and
exit status. No response bodies, credentials, or signed URLs enter this log.
These are client-observed completion times, including adapter validation/local
writes, not exact provider generation timestamps. Meshy polling intervals count
toward total run time; each poll has its own duration. Existing profiles retain
aggregate timings and provider-reported Meshy timing where available. Dry runs
make no API calls and produce no benchmark response records.

### Stage 1 live benchmark — September 13, 2026

The [previous Stage 1 CLI benchmark](GENERATED_EXAMPLES.md#previous-stage-1-cli-benchmark)
took 17.885 s. The [latest in-game example](GENERATED_EXAMPLES.md#stage-1--river-september-13-2026)
used the updated prompt and three-field item contract, completing in 18.529 s.
Its description is cut off at 160 characters. See the examples for original inputs,
outputs, timing boundaries, and review findings; the two runs are not a controlled comparison.

For the game mailbox change, six alternating batches of 100 status writes on the
local output filesystem measured a median of 0.307 ms/update before and
0.313 ms/update after adding response-folder history and arrival timestamps.
This small local sample shows negligible added write overhead; it does not measure
other devices or full gameplay performance. One additional receipt update is
written per request so queued requests are visible immediately.

## Code ownership and cleanup

| Path | Responsibility |
|---|---|
| `backend/game_bridge/run.py` | Persistent request listener, cancellation, cumulative status |
| `backend/utils/render.py` | Local GLB-to-PNG preview, no provider calls |
| `backend/sketch_to_model/run.py` | Three-step orchestration, polling, progress, and response timing |
| `backend/image_edit/run.py` | Bounded multipart image edit, low-quality settings, sanitized failures |
| `backend/interpret/run.py` | Reusable OpenAI interpretation and game-item validation; standalone narrative CLI |
| `backend/model_generation/run.py` | Meshy creation, durable task state, recovery, GLB validation/download |
| `backend/utils/common.py` | Local configuration, image validation, credential-safe HTTP transport |
| `backend/utils/profiling.py` | Shared timing and numeric performance reports |
| `backend/tests/` | Offline tests; no provider charges |

The unused Meshy image-to-image pipeline and its provider-selection switches have
been removed. The old `profile_api_responses.py` submission wrapper was also removed;
the primary pipeline profiles the full result. Keep each future feature in its own
folder. Shared helpers belong in `backend/utils/`; stage classification remains
in `backend/stage_config.py`. Avoid new dependencies without a concrete need.

## Contracts and failure handling

- Game requests include `game_stage` (`river`, `dog`, `crows`, `otter`) and a matching
  encounter ID E01–E04. The worker selects classes from `backend/stage_config.py`. All stages share
  generation steps; stages with undefined classes fail before provider calls.
  See [stage routing](../3d_game/DESKTOP_GENERATION.md#game-stage-routing).

- Keep stdout machine-readable JSON. Send human diagnostics and optional profiling to stderr.
- Preserve request identity and the desktop adapter's version-2 game envelope;
  match the validator in `3d_game/scripts/river/drawing_request.gd`. The provider's
  item-only response is separate from this game envelope. Unsupported values must fail validation.
- Keep the model-job version-1 manifest separate from the narrative response. Persist the
  provider task ID immediately and retain request identity through status/download.
- Never automatically retry paid task creation. Network failure can leave the provider
  running a job whose creation response was lost. Preserve `SUBMISSION_UNKNOWN` for recovery.
- Retain bounded network reads and timeouts. A socket timeout is not a complete operation deadline.
- Validate GLB headers and sizes before writing. These checks do not establish visual
  quality, exact face count, Godot compatibility, or safe gameplay collision.
- Use monotonic timing for local intervals and provider timestamps for provider intervals.
  Omit unavailable timing data. Profiling failures must not invalidate a completed paid job.

## Request input retention

Always keep a byte-for-byte copy of the original input image inside the same
ignored backend request/output folder as its responses and generated assets. This
also applies to manual, single-stage API tests. Use `input.png` or `input.jpg`
according to the actual input format. The model pipeline snapshots the validated
input before provider calls and uses that copy for reference-image generation.

## Credentials and publication

- Keep real keys only in ignored `backend/.env` or environment variables. Keep `.env`
  owner-readable/writable (`chmod 600 backend/.env` on macOS/Linux).
- Keep only blank key fields in `.env.example`. Do not paste keys into commands, tests,
  examples, commit messages, issue reports, or chat. Use clearly fake values in tests.
- Do not dump configuration, request headers, or raw provider errors. Authenticated
  provider requests must not forward credentials through redirects. Asset downloads
  must not include a provider Authorization header.
- Never commit `.venv/`, `__pycache__/`, local output, task manifests, signed asset URLs,
  profiles, or generated models by default. User-approved sample image/model copies
  may live under `docs/test-artifacts/`; never include task manifests or signed URLs.
  Routine `backend/output/` files stay ignored. Exporting Godot must not
  bundle shared API credentials.
- Before staging, inspect `git status` and the diff. Stage explicit source/documentation
  paths instead of the entire working tree. Check `git check-ignore` for local credentials,
  environment, and output paths. Scan staged blobs for actual configured key values and
  recognizable key patterns, reporting filenames only if anything is found.
- Run tests and `git diff --cached --check` before committing. Inspect the staged file list
  and verify `.env.example` key fields are blank. Preserve unrelated user changes/stashes.

## Samples and credits

These PNGs were drawn by Yanwen in the running game and exported through Submit drawing.
They are copied without image edits into `tests/fixtures/sketches/`, outside the Godot project.
Each image is 512 by 512 pixels and contains only the drawing canvas.

### Saved sketches

- [`E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png`](../../tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png)
- [`E01-2026-09-12T15-55-28-65602f8be67ceb40.png`](../../tests/fixtures/sketches/E01-2026-09-12T15-55-28-65602f8be67ceb40.png)
- [`E01-2026-09-12T15-56-31-36b8a3cc39e1e976.png`](../../tests/fixtures/sketches/E01-2026-09-12T15-56-31-36b8a3cc39e1e976.png)
- [`E01-preserved-20260912-155046.png`](../../tests/fixtures/sketches/E01-preserved-20260912-155046.png)

The preserved sample came from the legacy latest-only export. Identical copies are included only once.
Expected object labels have not been confirmed by the artist. Do not treat the filename or the
mock response selected in the game as a ground-truth AI label. Send the PNG content to the
interpretation API; do not include evaluation hints in the prompt.

New game submissions are saved locally under `user://drawings/`. This folder is a manually
collected snapshot, not an automatic upload destination. Automated smoke-test images are excluded.


### Banana sample credit

- File: `backend/samples/banana.jpg` (960 × 846 JPEG thumbnail).
- Work: [Banana-Single.jpg](https://commons.wikimedia.org/wiki/File:Banana-Single.jpg).
- Author: Evan-Amos.
- License: [Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/).
- Source: [Wikimedia thumbnail](https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Banana-Single.jpg/960px-Banana-Single.jpg).
- Downloaded September 12, 2026. No local modifications; Wikimedia supplied the resized thumbnail.
- This sample is a development input, not game art or a test of sketch-recognition quality.

## Backlog

These are planned tasks, not implemented features or GitHub issues created by this
refactor. The shared game backlog is in [SPEC.md](../SPEC.md#14-backlog-ready-for-tickets).

| Item | Status | Acceptance |
|---|---|---|
| T19: two-image interpretation | To Do | Accept a sketch and optional scene/reference image; label their roles in one OpenAI request; validate and retain both originals; preserve one-image behavior and item schema; cover routing/failure cases offline; benchmark latency and review quality within an authorized live-test scope |

The second image is for interpretation context. Its use by the later image-edit
step is a separate design decision. The current backend accepts one image only.
The OpenAI API supports multiple image inputs; see [official image-input documentation](https://developers.openai.com/api/docs/guides/images-vision).

Remaining integration work includes hosted Web execution/desktop packaging,
later-stage gameplay rules, and validating the 15-second end-to-end latency target
with the current prompts. See the shared specification for game-wide open work.

## Historical benchmarks

The following September 12, 2026 reports preserve original measurements, prompts,
artifact links, and limitations, including item fields removed from the current
contract. They are single-run observations, not current
commands, implementation status, or latency guarantees. Some reports used removed
Meshy image-edit experiments. Use the current sections above for setup and APIs.

The retained reports and artifacts are in [Generated examples](GENERATED_EXAMPLES.md#september-12-benchmarks).

## Provider references

- [OpenAI image inputs](https://developers.openai.com/api/docs/guides/images-vision).
- [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
- [Meshy image-to-3D](https://docs.meshy.ai/en/api/image-to-3d).
