# Backend development instructions

## Current flow

**See [Sketch-to-model request contract](SKETCH_TO_MODEL_RUN_2026-09-12.md#current-multi-stage-request-contract) for the approved four-stage
class table, request labels, validation rules and result files.**

**Sketch → OpenAI interpretation → OpenAI image edit → Meshy T2 → GLB + local PNG preview.**

The backend consists of local Python 3.9+ command-line scripts using only the standard
library. Use the shared `backend/.venv` and ignored `backend/.env`.
A persistent Python listener starts with the desktop game and runs generation on
demand through `backend/game_bridge/run.py --serve`; it publishes the interpretation,
reference image and final model as cumulative progress. See [desktop integration](../3d_game/DESKTOP_GENERATION.md).
A Web export cannot launch Python.

## Setup and run

Follow [local setup](AI_LOCAL_SETUP.md) to create the environment and configure
`OPENAI_API_KEY` and `MESHY_API_KEY`. OpenAI credentials need access to Responses and
image editing. From the repository root:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --dry-run
backend/.venv/bin/python backend/sketch_to_model/run.py
```

The default source is `tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png`.
Use `--image path/to/sketch.png` for another input. Each live invocation makes one
OpenAI interpretation request, one OpenAI image edit, and one Meshy creation after
preceding stages succeed. Uncertain interpretation stops before either image or 3D
generation. There are no creation retries.

| Stage | Default settings |
|---|---|
| Interpretation | Configured `OPENAI_MODEL` (default/template: `gpt-4.1-mini`), strict item JSON schema |
| Reference image | `gpt-image-2.5-flare`, **816 × 816**, low quality, JPEG compression 70, one image, opaque background |
| 3D | `meshy-t2`, Smart Topology, target **1,000 faces**, GLB, **textures disabled** |

Options: `--style-prompt` replaces the reference-image instructions;
`--openai-image-model` overrides Flare; `--openai-image-size 1024x1024` compares the
larger image; `--target-faces` changes the T2 target (100–15,000).
`OPENAI_MODEL` configures interpretation in both this pipeline and the standalone
narrative CLI. The standalone adapter's `MESHY_MODEL` setting does not override the
pipeline's T2 model.

The image prompt preserves the sketch and description, asks for the whole object with
10% margins, and avoids decorative detail. These are model instructions, not enforced
visual guarantees. The accepted 816-pixel test changed triangular braces into ladder
rungs; intent and structural fidelity still need human review.

## Outputs and recovery

Outputs are saved under ignored `backend/output/sketch_to_model/<run-id>/`:
`input.png` (or `input.jpg` for JPEG sources), `description.json`, `reference_prompt.txt`, `image_edit_settings.json`, `reference.jpg`,
`model_job.json`, `model.glb`, and `model.png` (a 512 × 512 rendered model preview). The edited JPEG enters T2 as a data URI. Local
PNG/JPEG input and the generated JPEG must fit the existing 1 MiB image limit.

Stage results and local paths print as JSON lines on stdout. Diagnostics and profiles
go to stderr; profiles also save under `backend/output/profiles/`. Credentials and
signed URLs must not be printed. The Meshy manifest can contain a signed URL and must
stay local. Image-edit settings contain the submitted prompt and non-secret generation settings.
The bridge publishes item JSON immediately after interpretation and the local reference
path immediately after image editing. Each request retains timestamped cumulative
updates in `results.jsonl` and the latest atomic snapshot in `status.json`, including
local image/model paths. The listener checks completed thread-pool jobs against the
final status and records `pool_checked`/`pool_return_code`; crashes and missing final
results are logged as failures without retries.

Meshy status is polled every three seconds for up to ten minutes. OpenAI image editing
has a 180-second socket timeout, not a guaranteed completion deadline. Restarting
the pipeline creates new paid work. On failure, inspect existing outputs and recover
the Meshy task using the [status/download commands](AI_IMAGE_TEXT_TO_3D.md) instead of
blindly rerunning. `SUBMISSION_UNKNOWN` indicates an uncertain paid submission.

## Local model preview

After saving the GLB, the pipeline renders `model.png` beside it using the
standard-library CPU renderer in `backend/model_preview/render.py`. This is a
clay-shaded view of the actual static geometry, with automatic framing and a light
background; it does not reproduce textures or the game scene. No AI call, GPU,
window, or additional package is needed. Completion includes `preview_path`; a
preview failure includes `preview_error: PREVIEW_RENDER_FAILED` while preserving
the successful GLB. The game bridge applies the same step to offline fixtures.

Render an existing file without running generation:

```sh
backend/.venv/bin/python backend/model_preview/render.py path/to/model.glb
```

Local 512-pixel preview tests took 0.07–0.48 seconds; both outputs were visually
inspected. The renderer handles static
triangle meshes with node transforms and embedded position/index buffers. Skins,
morph targets, sparse accessors and required extensions are unsupported.

## Code ownership and cleanup

| Path | Responsibility |
|---|---|
| `backend/game_bridge/run.py` | Persistent request listener, cancellation, cumulative status |
| `backend/model_preview/render.py` | Local GLB-to-PNG preview, no provider calls |
| `backend/sketch_to_model/run.py` | Primary pipeline, prompts, polling, stage orchestration |
| `backend/sketch_to_model/openai_edit.py` | Bounded multipart image edit, low-quality settings, sanitized failures |
| `backend/sketch_to_narrative/run.py` | Reusable OpenAI interpretation and game-item validation; standalone narrative CLI |
| `backend/image_text_to_3d/run.py` | Meshy creation, durable task state, recovery, GLB validation/download |
| `backend/common.py` | Local configuration, image validation, credential-safe HTTP transport |
| `backend/profiling.py` | Shared timing and numeric performance reports |
| `backend/tests/` | Offline tests; no provider charges |

The unused Meshy image-to-image pipeline and its provider-selection switches have
been removed. The old `profile_api_responses.py` submission wrapper was also removed;
the primary pipeline profiles the full result. Keep each future feature in its own
folder and avoid new dependencies without a concrete need.

For historical benchmark results, see [Meshy benchmarks](AI_BENCHMARKS.md).
For exact prompts, artifacts, and the OpenAI comparison, see the
[run report](SKETCH_TO_MODEL_RUN_2026-09-12.md). Historical report commands describe
the code used at the time and can include switches removed during cleanup.

## Validation

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

The persistent-worker flow is verified with offline backend tests and the Godot
`desktop_generation_smoke.gd` test: startup, early results, reuse, cancellation and
scene removal. No paid calls are needed for these checks. See the historical
[run report](SKETCH_TO_MODEL_RUN_2026-09-12.md) for live generation measurements;
the 15-second total target remains unverified for the current prompts.

## Stage classification configuration

The exact classes and request contract are documented in
[Sketch-to-model stage classes](SKETCH_TO_MODEL_RUN_2026-09-12.md#approved-classes). Backend configuration lives in
`backend/stage_config.py`; the game supplies only stage/encounter identity. Tags and
numeric fields remain shared across stages. Both Python entry points accept
`--game-stage river|dog|crows|otter`, defaulting to river.

## Contracts and failure handling

- Game requests include `game_stage` (`river`, `dog`, `crows`, `otter`) and a matching
  encounter ID E01–E04. The worker selects classes from `backend/stage_config.py`. All stages share
  generation steps; stages with undefined classes fail before provider calls.
  See [stage routing](../3d_game/DESKTOP_GENERATION.md#game-stage-routing).

- Keep stdout machine-readable JSON. Send human diagnostics and optional profiling to stderr.
- Preserve the narrative version-2 envelope and original `request_id`; match the validator
  in `3d_game/scripts/river/drawing_request.gd`. Unsupported values must fail validation.
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
