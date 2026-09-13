# Generated examples

Recorded outputs from authorized sketch-to-model runs. Use the [backend guide](BACKEND.md)
for the public interface, setup, and benchmark methodology. Example artifacts are
preserved under `docs/test-artifacts/`; raw provider manifests and profiles stay local.

## Example index

| Stage | Input | Result | Observed total |
|---|---|---|---|
| [1 — River](#stage-1--river-september-13-2026) | Latest in-game bridge sketch | `BRIDGE`; GLB and preview generated | 18.529 s |
| [2 — Dog](#stage-2--dog) | Bone sketch | `FOOD`; GLB and preview generated | 16.024 s |
| [3 — Crows](#stage-3--crows) | Bow sketch | Not run; result pending | Pending |
| [4 — Otter](#stage-4--otter) | Gift sketch | Not run; result pending | Pending |

Stage 1 below is the latest completed live game response after simplifying the item
contract and updating the usefulness prompt. Stage 2 records the subsequent authorized
CLI test with the shorter, complete-sentence prompt. Stages 3 and 4 remain placeholders.

## Stage 1 — River, September 13, 2026

### Source and request

The game submitted a new drawing through the file-mailbox interface. This input is
**different from** `backend/tests/stage1/input.png`; it was not a `--stage1` CLI run.
The original drawing is [retained here](../test-artifacts/stage1-game-2026-09-13/input.png).

```json
{
  "request_id": "E01-36330253-1",
  "encounter_id": "E01",
  "game_stage": "river",
  "mode": "live"
}
```

### Actual response

The final status was `SUCCEEDED`, progress stage `complete`, with a verified pool
return code of 0. Its exact `item` response was:

```json
{
  "name": "Narrow Wooden Bridge",
  "description": "A narrow wooden bridge with railings along its length, spanning from the upper-left to lower-right edges. It could allow players to cross the river safely by le",
  "type": "BRIDGE"
}
```

**Review finding:** the description is exactly 160 characters and ends mid-word
at “by le”. The API response passed the current length validation, but the sentence
needs improvement. It is reproduced verbatim rather than silently corrected.

### Input and generated images

| Original game sketch | Edited reference | Local model preview |
|---|---|---|
| ![Original bridge sketch drawn in the game](../test-artifacts/stage1-game-2026-09-13/input.png) | ![Edited reference of a wooden bridge with a deck and railings](../test-artifacts/stage1-game-2026-09-13/reference.jpg) | ![Preview rendered from the generated bridge GLB](../test-artifacts/stage1-game-2026-09-13/model.png) |

[Download the generated GLB](../test-artifacts/stage1-game-2026-09-13/model.glb).
The edited reference adds a wooden deck and railings. The local clay preview shows
the generated mesh from the renderer's automatic camera; it does not reproduce
reference-image colors or establish gameplay collision. All four assets match the
saved game output byte for byte. Gameplay crossing was not verified for this example.

### Three API calls

All three generation calls completed successfully. The descriptions below distinguish
actual retained outputs from illustrative HTTP response shapes. Original HTTP bodies
were not retained for this game run. Completion times are **backend-observed UTC
progress timestamps**, not provider generation timestamps or isolated HTTP latency.

| Call | Provider operation | Returned content | Observed completion |
|---|---|---|---|
| 1. Interpret | OpenAI Responses | Structured text JSON; no image | 2026-09-13T07:05:19.948+00:00 |
| 2. Image edit | OpenAI Image Edits | One reference JPEG; no text response retained | 2026-09-13T07:05:29.646+00:00 |
| 3. Model generation | Meshy image-to-3D creation, then polling/download | Task receipt, then GLB; no image returned by this adapter | GLB available: 2026-09-13T07:05:34.871+00:00 |

#### Call 1 — Interpret

**Request:** `POST https://api.openai.com/v1/responses`, using the configured
`OPENAI_MODEL`. The request carries one sketch image, interpretation instructions,
River's classes (`BRIDGE`, `BOAT`, `UNKNOWN`), and a strict JSON schema containing
`status` and the three-field item. No second image is included.

**Input image:** [original game sketch](../test-artifacts/stage1-game-2026-09-13/input.png).
Prompt definitions are in [interpret/run.py](../../backend/interpret/run.py) and
[interpret/prompts.py](../../backend/interpret/prompts.py); the assembled prompt was
not saved with this run, so these links identify implementation sources rather
than an immutable copy of the exact historical HTTP request.

**Retained text response:** the adapter extracted and validated this JSON from
OpenAI's response. It is the exact saved `description.json` content, not the full
Responses API envelope:

```json
{
  "status": "recognized",
  "item": {
    "name": "Narrow Wooden Bridge",
    "description": "A narrow wooden bridge with railings along its length, spanning from the upper-left to lower-right edges. It could allow players to cross the river safely by le",
    "type": "BRIDGE"
  }
}
```

**Image response:** none. Interpretation returns text; its JSON description is
passed to Call 2. The description's truncated ending is retained as a review finding.
**Observed duration:** 2.196 s from interpretation-start to item-ready progress.

#### Call 2 — Image edit

**Request:** `POST https://api.openai.com/v1/images/edits`, multipart data containing
the original sketch and the [exact saved reference-image prompt](../test-artifacts/stage1-game-2026-09-13/reference_prompt.txt).
The prompt includes Call 1's returned name and description verbatim.

| Saved request setting | Value |
|---|---|
| Model | `gpt-image-2.5-flare` |
| Size | `816x816` |
| Quality | `low` |
| Image count | `1` |
| Output | `jpeg`, compression `70` |
| Background | `opaque` |

**Text response:** no descriptive text was retained. The adapter reads the single
`data[0].b64_json` image payload and saves its decoded JPEG bytes as `reference.jpg`;
it does not return a separate narrative or item JSON.

**Image response:**

![Actual JPEG returned by the image-edit call](../test-artifacts/stage1-game-2026-09-13/reference.jpg)

**Observed duration:** 9.698 s from item-ready to reference-image-ready progress.

#### Call 3 — Model generation

**Request:** `POST https://api.meshy.ai/openapi/v1/image-to-3d` with Call 2's
[reference JPEG](../test-artifacts/stage1-game-2026-09-13/reference.jpg) encoded as
`image_url`, plus these pipeline settings:

```json
{
  "ai_model": "meshy-t2",
  "model_type": "smart-topology",
  "target_polycount": 1000,
  "should_texture": false,
  "target_formats": ["glb"]
}
```

No text prompt is sent to Meshy. The image payload is omitted from this settings
excerpt; it is required in the real request.

**Creation response:** the adapter receives a JSON task receipt with a `result`
identifier. This is an illustrative shape with the real identifier omitted:

```json
{"result": "<task-id>"}
```

A task receipt is not a completed model. The backend subsequently polls the same
task and downloads its GLB after `SUCCEEDED`. The actual final game response reports
`status: SUCCEEDED`, `stage: complete`, and local `model_path`/`preview_path` values.
Provider manifests and signed download URLs remain in ignored local output.
The creation-response timestamp alone was not recorded in this game's progress log.

**Generated model:** [download the actual GLB](../test-artifacts/stage1-game-2026-09-13/model.glb).
**Image response:** none from the Meshy adapter. The image below is rendered locally
from the downloaded model by `utils/render.py`, after the model step finishes:

![Local preview of the Meshy-generated GLB](../test-artifacts/stage1-game-2026-09-13/model.png)

**Observed duration:** 5.225 s for submission, polling, and download combined;
then 1.396 s for the local preview. Preview completion was observed at
2026-09-13T07:05:36.267+00:00. The local preview is not a fourth API call.

### Observed performance

These intervals come from adjacent progress records in `response/results.jsonl`,
using the backend's timestamps. They include local work between notifications and
are not isolated provider processing measurements.

| Interval | Time |
|---|---|
| Interpretation: `description` → `reference_image` | 2.196 s |
| Image edit: `reference_image` → `model` | 9.698 s |
| Model submission, polling, download: `model` → `preview` | 5.225 s |
| Local preview: `preview` → `complete` | 1.396 s |
| **Request received → completed response** | **18.529 s** |

About 0.014 s precedes interpretation. The final pool check followed completion
by about 0.053 s and is excluded from the total. Image editing was the largest
interval. This is one observation, not an average or latency guarantee, and it
exceeds the 15-second target. It is not a controlled comparison with the previous
CLI run: the input and prompt changed, and the timing boundaries differ.

### Local provenance

Full local job: `backend/output/game_bridge/worker-de5384f82b10effb/E01-36330253-1/`.
It contains `request/`, `response/`, and sibling `status.json` with arrival timestamps.
This ignored directory may be absent on another checkout; the linked example assets
are preserved independently. No raw job/profile logs or signed URLs are copied here.

## Stage 2 — Dog

**Status: SUCCEEDED.** One authorized live CLI run on September 13, 2026 used
[`backend/tests/stage2/input.png`](../../backend/tests/stage2/input.png), the bone sketch.
The retained input matches the test image byte for byte. The command was:

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage2
```

This selects `game_stage: dog` and the allowed classes `FOOD`, `TOY`, `WEAPON`,
`UNKNOWN`. The CLI invokes sketch-to-model directly; this run has no game-mailbox
`request/` directory. Its local output folder is
`backend/output/sketch_to_model/2b756e72478646a3b46977fdaa7df4bc/`.

### Three API calls and actual responses

Completion timestamps below are client-observed UTC times from `benchmark.jsonl`.
There are three generation steps; model polling and asset download add HTTP requests.

**1. Interpret.** The request supplied the bone sketch as one `input_image`, the
shared sketch interpretation prompt, the dog-stage class list, and the strict item
schema. The saved response was:

```json
{
  "status": "recognized",
  "item": {
    "name": "Dog Bone",
    "description": "A dog bone that can be used to attract or reward the dog character in the game.",
    "type": "FOOD"
  }
}
```

The response arrived at **07:18:59.414695 UTC**, after **2.400 s** for the API wrapper.
This call returns text, with no image. The description is a complete sentence and
explains a potential use for the dog challenge; it is not cut off.

**2. Image edit.** The request supplied the original sketch and the
[exact saved edit prompt](../test-artifacts/stage2-2026-09-13/reference_prompt.txt),
which incorporates the interpreted name and description. Saved settings:
`gpt-image-2.5-flare`, one image, 816 × 816, low quality, JPEG, compression 70,
opaque background. The response arrived at **07:19:07.826484 UTC**, after
**8.408 s**. Its retained output is the reference image below. No text response
was retained by this adapter.

**3. Model generation.** The request supplied the edited reference image,
`meshy-t2`, `smart-topology` model type, target 1,000 faces, GLB format, and
textures disabled. No remeshing or topology parameter was sent. The name and
description are not sent to Meshy.
Submission returned a task receipt at **07:19:08.684362 UTC**, taking **0.857 s**.
The receipt has the illustrative shape `{"result": "<task-id>"}`; the actual
provider identifier and signed URLs are intentionally excluded from this document.
The final status poll completed at **07:19:12.594505 UTC** with successful model
completion; the GLB download finished at **07:19:12.788135 UTC**. The model step,
including submission, polling, download, validation, and writing, took **4.961 s**.
The output is the [generated GLB](../test-artifacts/stage2-2026-09-13/model.glb).
No narrative text or API-generated preview image is retained for this step.
The preview below was rendered locally from the GLB afterward.

### Input and generated images

| Original bone sketch | Edited reference | Local model preview |
|---|---|---|
| ![Bone sketch](../../backend/tests/stage2/input.png) | ![Edited bone reference](../test-artifacts/stage2-2026-09-13/reference.jpg) | ![Locally rendered bone mesh](../test-artifacts/stage2-2026-09-13/model.png) |

The reference and model preview both show a recognizable horizontal bone with
rounded double-lobed ends. The untextured preview shows faceted geometry. This
verifies the generated appearance, not dog-encounter gameplay or collision behavior.
All linked artifacts match the original run files byte for byte.

### Performance

| Measurement | Time |
|---|---|
| Interpretation stage | 2.402 s |
| Image-edit stage | 8.409 s |
| Model stage, including polling and download | 4.961 s |
| Local preview | 0.247 s |
| **Total stage runner** | **16.024 s** |

The run started at **07:18:57.012420 UTC** and finished at **07:19:13.035737 UTC**
with exit code 0. Stage durations include local work, so they differ slightly from
API-wrapper timings. Meshy reported **2.168 s processing** and **0.007 s queueing**;
these are included in the model stage. The three-second polling interval adds to
observed latency. Image editing was the largest contributor, about 52% of the total.
This single run exceeded the 15-second target by 1.024 s; it is not a latency average.

The ignored local run folder retains `benchmark.jsonl` and provider records.
Only generated images, the GLB, and the edit prompt are copied into documentation.
The input image is linked directly from the stage test folder to avoid duplication.

## Stage 3 — Crows

**Status: Not run.** Input: [bow sketch](../../backend/tests/stage3/input.png).

Planned command (uses provider credits; add `--dry-run` for offline validation):

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage3
```

| API call | Request details | Text response | Image/model output | Done timestamp and duration |
|---|---|---|---|---|
| 1. Interpret | Pending | Actual JSON pending | No image response expected | Pending |
| 2. Image edit | Prompt/settings pending | Record any retained text; none expected from this adapter | Reference image pending | Pending |
| 3. Model generation | Image/settings pending | Task receipt and final status pending; omit actual task ID | GLB and separately labeled local preview pending | Pending |

Total time, success/failure, run date/provenance, and visual/gameplay review: **Pending**.

## Stage 4 — Otter

**Status: Not run.** Input: [gift sketch](../../backend/tests/stage4/input.png).

Planned command (uses provider credits; add `--dry-run` for offline validation):

```sh
backend/.venv/bin/python backend/tests/stage_test.py --stage4
```

| API call | Request details | Text response | Image/model output | Done timestamp and duration |
|---|---|---|---|---|
| 1. Interpret | Pending | Actual JSON pending | No image response expected | Pending |
| 2. Image edit | Prompt/settings pending | Record any retained text; none expected from this adapter | Reference image pending | Pending |
| 3. Model generation | Image/settings pending | Task receipt and final status pending; omit actual task ID | GLB and separately labeled local preview pending | Pending |

Total time, success/failure, run date/provenance, and visual/gameplay review: **Pending**.

## Earlier benchmarks

An earlier Stage 1 CLI run completed in 17.885 seconds using the old prompt and
item contract. Its superseded artifact copies have been removed; the current
Stage 1 example above is the retained visual record. September 12 measurements
remain in the [historical benchmark appendix](BACKEND.md#historical-benchmarks).

## Adding an example

Replace each pending result only after an authorized test. Record the actual input,
request identity, per-call request details, actual text/image/model responses, completion
timestamps, settings, artifacts, timing boundaries, and verification
limits. Preserve response defects rather than editing the recorded output. Copy only
the latest approved generated assets into `docs/test-artifacts/`; link existing test
inputs directly and remove superseded example copies. Keep provider manifests, signed
URLs, credentials, and raw job/profile data in ignored local output.
