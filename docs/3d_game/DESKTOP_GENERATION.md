# Desktop drawing-to-model integration

Issue: [#15](https://github.com/AdeDeepFishing/Paws-Peaks/issues/15).

At game startup, the `GenerationWorker` autoload launches one persistent Python
listener (`backend/game_bridge/run.py --serve <private-worker-directory>`), before
the main scene loads. It stays alive across submissions, restarts and scene changes,
including while Mock mode is selected. Startup makes no provider calls. Live mode
calls the `sketch_to_model` pipeline: PNG → OpenAI interpretation → OpenAI image edit
→ Meshy GLB → local preview.
Only a completed GLB and validated item result can place a generated object. Failure
never silently substitutes the mock bridge.

## Try it

Open the Godot project from this checkout. Python 3.9+ must be available as `python3`,
or at `backend/.venv/bin/python` (Windows: `.venv/Scripts/python.exe`). The project settings `generation/backend_directory` and
`generation/python_executable` accept explicit paths for packaged local builds. A distributable Python runtime is not bundled.

The upper-right mode selector has three choices:

- **Sample model · No AI** (default): passes the submitted PNG to the persistent Python
  worker and returns the checked-in ladder GLB from the September 12 sample run.
  Every drawing gets that same sample. No provider is called.
- **Mock bridge · No AI**: keeps the original bridge and failure fixtures for gameplay tests.
- **Live AI · Uses credits**: invokes the real pipeline using private `backend/.env`
  credentials. Follow [local setup](../backend/AI_LOCAL_SETUP.md) and
  [sketch-to-model setup](../backend/SKETCH_TO_MODEL_RUN_2026-09-12.md). Selecting this mode and submitting
  runs paid provider requests. The game never receives API keys.

At the riverbank, draw over the scene and submit. Generation progress appears in the
HUD while movement resumes. Successful output appears directly in the scene.
The mode cannot change while a request is pending.

## Lifecycle and files

Each game session owns an ignored `backend/output/game_bridge/worker-<id>/`
directory. Python writes `worker.json` when listening. Godot submits work by saving
`<request-id>/input.png`, then atomically renaming `request.tmp` to `request.json`.
Python claims that file as `claimed.json`, preventing replay, and dispatches it to
one generation thread. The listener remains responsive while generation runs;
requests execute serially. No automatic paid retries occur.

Each request keeps its exclusive `started.lock`, append-only `results.jsonl` history,
and cumulative atomic `status.json` snapshot. Every recorded update has an `updated_at`
Unix timestamp and includes the request/stage identity. Image bytes stay in files;
`input_path`, `reference_path`, and `preview_path` point to the original sketch,
generated reference, and rendered model image. `model_path` points to the GLB.

The listener polls completed thread-pool futures and checks their return codes against
`status.json`. It logs `pool_checked: true` and `pool_return_code` once verified. A
crashed job or missing/inconsistent terminal status becomes a logged failure, without
retrying provider work. Completed jobs are also checked during graceful shutdown.
Godot continues polling the latest snapshot; it does not have to parse the history.
The status envelope includes schema version 1, request ID, encounter ID, mode, stage,
and status. Completed stages add fields retained through later stages and errors:

| Available after | Field | Godot signal on DesktopGeneration |
|---|---|---|
| Interpretation | `item` (validated name, description, stats, tags) | `interpretation_ready(request_id, item)` |
| Reference image | `reference_path` (local image file) | `reference_image_ready(request_id, path)` |
| Model and preview | `model_path` (local GLB), `preview_path` (sibling `model.png`) | DrawingRequest changes to `READY` |

Godot polls every 0.2 seconds, validates request identity and emits each early-result
signal once per request. `partial_item` and `reference_path` also expose the latest
intermediate values. These signals let game code use the first two results while
DrawingRequest remains `PENDING`; they do not place the final object or complete the
encounter. The existing gameplay presentation still waits for the GLB. Cumulative
fields ensure a fast stage cannot disappear between polls. The offline fixture
publishes the same stages using its checked-in description, image and model.
After the GLB is saved, a local `preview` stage renders a 512 × 512 PNG of its
geometry before completion. A failed preview reports `preview_error` while
retaining successful model delivery. See [local rendering](../backend/BACKEND.md#local-model-preview).

Stop waiting, restart, timeout or scene removal writes a per-request `cancel` marker;
the listener stays alive. Cancellation is cooperative at stage boundaries: an
in-flight provider operation can finish before cancellation takes effect, delaying
the next queued generation. Already-submitted provider jobs are not canceled.
Inspect saved task IDs before retrying uncertain submissions. Game exit terminates
the worker. A missing or crashed worker fails submissions explicitly; restart the
game after correcting setup. Startup never replays work from previous sessions.

Live artifacts and durable provider job IDs stay under each job's `artifacts/`.
Only local allowed fields enter the game status; API keys and signed URLs remain
private. The overall game waiting deadline remains 25 minutes.

## Game stage routing

See [Sketch-to-model stage classes](../backend/SKETCH_TO_MODEL_RUN_2026-09-12.md#current-multi-stage-request-contract) for the full classification contract.

Every game request includes a `game_stage` label alongside its `encounter_id`:

| Game stage | Encounter | Allowed classes |
|---|---|---|
| `river` | `E01` | BRIDGE, BOAT, UNKNOWN |
| `dog` | `E02` | FOOD, TOY, WEAPON, UNKNOWN |
| `crows` | `E03` | BOW, MAGIC, UNKNOWN |
| `otter` | `E04` | GIFT, TOOL, UNKNOWN |

For example, the river scene writes:

```json
{"request_id": "E01-example", "encounter_id": "E01", "game_stage": "river", "mode": "live"}
```

`DrawingRequest.submit(png, encounter_id)` derives the stage label from its encounter
mapping. `DesktopGeneration` forwards it unchanged. The backend's `stage_config.py` registry
selects the classification set and rejects mismatched labels before provider calls. All job
updates echo `game_stage`; Godot ignores responses for a different game stage.
The existing `stage` field describes pipeline progress (`description`, `model`, etc.).

This extends request routing to four stages, not gameplay implementation. The existing
river scene still submits E01; later scenes must wire their own encounters. All configured stages share the generation steps, with stage-specific classes.
Only river has an offline fixture.
The fifth-stage boss in the broader spec remains outside this four-stage API change.

## Placement limits

The loader accepts self-contained static GLBs up to 32 MiB and copies mesh nodes only.
For items tagged LONG_REACH and STURDY, it aligns the longest dimension across the
river, places the dominant horizontal surface at deck height, scales uniformly to
the authored 10.4-unit crossing, and uses the existing
walkable deck collider. This collider is a gameplay approximation, not a collision
mesh derived from the model; gaps between ladder rungs remain walkable. Unsupported
items appear on the riverbank and do not unlock the crossing. Skinned models and
external asset URIs are rejected. Final placement/orientation rules remain designer work.

This is a **desktop checkout integration**. A Web build needs a hosted service;
it cannot launch Python. Earlier live drawing generation succeeded locally; the PR #17 integration is
verified offline.

## Verification

- `python3 -m unittest discover -s backend/tests -v`: 53 offline tests, including persistent worker reuse and early results.
- Godot `res://tests/desktop_generation_smoke.gd`: real fixture subprocess, GLB
  loading/normalization, automatic crossing, restart, cancellation, stale results,
  startup before submission, listener survival after scene removal, and invalid model rejection.
- Godot `res://tests/river_smoke.gd`: existing drawing/gameplay regression coverage.

See [encounter presentation and movement](ENCOUNTER_FLOW.md) for construction
closeups, delayed coins, result reveals, and assisted crossing.
