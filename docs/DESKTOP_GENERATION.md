# Desktop drawing-to-model integration

Issue: [#15](https://github.com/AdeDeepFishing/Paws-Peaks/issues/15).

The drawing action now runs `backend/game_bridge/run.py` asynchronously. Live mode
calls Beichun's `sketch_to_model` pipeline: PNG → description → reference image → GLB.
Only a completed GLB and validated item result can place a generated object. Failure
never silently substitutes the mock bridge.

## Try it

Open the Godot project from this checkout. Python 3.9+ must be available as `python3`,
or at `backend/.venv/bin/python` (Windows: `.venv/Scripts/python.exe`). The scene's
DesktopGeneration node also accepts explicit backend and Python paths for packaged
local builds. A distributable Python runtime is not bundled.

The upper-right mode selector has three choices:

- **Sample model · No AI** (default): passes the submitted PNG to a real Python
  process and returns the checked-in ladder GLB from the September 12 sample run.
  Every drawing gets that same sample. No provider is called.
- **Mock bridge · No AI**: keeps the original bridge and failure fixtures for gameplay tests.
- **Live AI · Uses credits**: invokes the real pipeline using private `backend/.env`
  credentials. Follow [local setup](AI_LOCAL_SETUP.md) and
  [sketch-to-model setup](SKETCH_TO_MODEL_RUN_2026-09-12.md). Selecting this mode and submitting
  runs paid provider requests. The game never receives API keys.

At the riverbank, draw over the scene and submit. Generation progress appears in the
HUD while movement resumes. Successful output appears directly in the scene.
The mode cannot change while a request is pending.

## Lifecycle and files

Each request gets a unique ignored `backend/output/game_bridge/<id>/` directory with
an immutable transparent-background RGBA `input.png`, an exclusive `started.lock`, and atomic `status.json`.
Live artifacts and durable provider job IDs are stored under `artifacts/`.
The status envelope includes schema version 1, request ID, encounter ID, stage,
status, and finally item/model path. Only matching active requests are consumed.

Godot polls every 0.2 seconds and allows 25 minutes overall. Stop waiting, restart,
timeout, and exit terminate the local worker. They **do not cancel provider jobs**
already submitted. Inspect saved task IDs before manually retrying after an uncertain
failure; there is no automatic paid retry. Draft strokes remain available after errors.

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

- `python3 -m unittest discover -s backend/tests -v`: 44 offline tests.
- Godot `res://tests/desktop_generation_smoke.gd`: real fixture subprocess, GLB
  loading/normalization, automatic crossing, restart, cancellation, stale results,
  missing backend, and invalid model rejection.
- Godot `res://tests/river_smoke.gd`: existing drawing/gameplay regression coverage.

See [encounter presentation and movement](ENCOUNTER_FLOW.md) for construction
closeups, delayed coins, result reveals, and assisted crossing.
