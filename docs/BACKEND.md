# Backend development instructions

## Current flow

**Sketch → OpenAI description → OpenAI image edit → Meshy T2 → untextured GLB.**

The backend consists of local Python 3.9+ command-line scripts using only the standard
library. Use the shared `backend/.venv` and ignored `backend/.env`. The scripts are
not connected to the Godot drawing action yet. A future desktop integration must run
blocking work away from the game main thread; a Web export cannot launch Python.

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
OpenAI interpretation, one OpenAI edit, and one Meshy creation if preceding stages
succeed. Uncertain interpretation stops before image editing. There are no creation retries.

| Stage | Default settings |
|---|---|
| Description | Configured `OPENAI_MODEL` (template: `gpt-4.1-mini`), equipment interpretation and whole-object constraints |
| Reference image | `gpt-image-2.5-flare`, **816 × 816**, low quality, JPEG compression 70, one image, opaque background |
| 3D | `meshy-t2`, Smart Topology, target **1,000 faces**, GLB, **textures disabled** |

Options: `--style-prompt` replaces the reference-image instructions;
`--openai-image-model` overrides Flare; `--openai-image-size 1024x1024` compares the
larger image; `--target-faces` changes the T2 target (100–15,000).
The standalone adapter's `MESHY_MODEL` setting does not override the pipeline's T2 model.

The image prompt preserves the sketch and description, asks for the whole object with
10% margins, and avoids decorative detail. These are model instructions, not enforced
visual guarantees. The accepted 816-pixel test changed triangular braces into ladder
rungs; intent and structural fidelity still need human review.

## Outputs and recovery

Outputs are saved under ignored `backend/output/sketch_to_model/<run-id>/`:
`description.json`, `reference_prompt.txt`, `image_edit_settings.json`, `reference.jpg`,
`model_job.json`, and `model.glb`. The edited JPEG enters T2 as a data URI. Local
PNG/JPEG input and the generated JPEG must fit the existing 1 MiB image limit.

Stage results and local paths print as JSON lines on stdout. Diagnostics and profiles
go to stderr; profiles also save under `backend/output/profiles/`. Credentials and
signed URLs must not be printed. The Meshy manifest can contain a signed URL and must
stay local. Image-edit settings contain the prompt and non-secret generation settings.

Meshy status is polled every three seconds for up to ten minutes. OpenAI image edits
have a 180-second socket timeout, not a guaranteed completion deadline. Restarting
the pipeline creates new paid work. On failure, inspect existing outputs and recover
the Meshy task using the [status/download commands](AI_IMAGE_TEXT_TO_3D.md) instead of
blindly rerunning. `SUBMISSION_UNKNOWN` indicates an uncertain paid submission.

## Code ownership and cleanup

| Path | Responsibility |
|---|---|
| `backend/sketch_to_model/run.py` | Primary pipeline, prompts, polling, stage orchestration |
| `backend/sketch_to_model/openai_edit.py` | Bounded multipart image edit, low-quality settings, sanitized failures |
| `backend/sketch_to_narrative/run.py` | Reusable OpenAI interpretation and game-item validation; standalone narrative CLI |
| `backend/image_text_to_3d/run.py` | Meshy creation, durable task state, recovery, GLB validation/download |
| `backend/common.py` | Local configuration, image validation, credential-safe HTTP transport |
| `backend/profiling.py` | Shared timing and numeric performance reports |
| `backend/benchmark_meshy_polygons.py` | Optional polygon/model/texture experiments |
| `backend/interpret_image.py` | Small compatibility shim for the original narrative CLI |
| `backend/tests/` | Offline tests; no provider charges |

The unused Meshy image-to-image pipeline and its provider-selection switches have
been removed. The old `profile_api_responses.py` submission wrapper was also removed;
the primary pipeline profiles the full result. Keep each future feature in its own
folder and avoid new dependencies without a concrete need.

For benchmark commands and prior results, see [Meshy benchmarks](AI_BENCHMARKS.md).
For exact prompts, artifacts, and the OpenAI comparison, see the
[run report](SKETCH_TO_MODEL_RUN_2026-09-12.md). Historical report commands describe
the code used at the time and can include switches removed during cleanup.

## Validation

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

Latest accepted live setup: **19.700 seconds** total (description 2.240 s, reference
12.444 s, T2 plus download 5.013 s); 891 output triangles, no textures. Reference
visually inspected; GLB structurally checked, not visually inspected or imported into
Godot. The 15-second goal remains unmet. Cleanup was validated offline; no additional
live calls were made. **41 offline tests passed**, including edited-image handoff,
uncertain/failure handling, request settings and signed-URL omission.
Historical test counts in the report include since-removed
experimental branches; current tests cover the retained flow.

## Contracts and failure handling

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
