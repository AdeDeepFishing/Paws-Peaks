# Backend development instructions

## Purpose and boundaries

The backend is a collection of local Python command-line features, not a hosted HTTP
server. Each command runs one operation and exits. Python 3.9+ is supported with only
the standard library; use the shared `backend/.venv` for development.

The Godot project lives in `3d_game/`. These helpers are not yet triggered by its drawing
UI. Keep gameplay state, item use, collision, progression, and stale-result handling
in Godot. A future desktop integration should run commands asynchronously, return results
on the main thread, and package or locate a Python runtime. A Web export cannot launch them.

## Feature ownership

| Path | Responsibility |
|---|---|
| `backend/sketch_to_narrative/run.py` | OpenAI image interpretation, prompt/schema, item validation |
| `backend/image_text_to_3d/run.py` | Meshy geometry jobs, status, durable task identity, GLB download |
| `backend/common.py` | Shared local settings, image input, authenticated HTTP transport |
| `backend/profiling.py` | Opt-in timing, numeric metrics, independent profile reports |
| `backend/tests/` | Offline behavior, error, credential-handling, and profiling tests |
| `backend/interpret_image.py` | Compatibility entry point for the original narrative command |
| `backend/samples/` | Shared sample inputs with source/license credits in documentation |

Add future features as separate folders with a `run.py` entry point. Keep feature prompts,
schemas, provider settings, and state machines within that feature. Extract shared helpers
only when more than one feature needs them. Add no dependencies without a concrete need;
if dependencies become necessary, add a reproducible dependency file and installation steps.

## Local setup and commands

See [local setup](AI_LOCAL_SETUP.md) for environment creation and credentials, and
[3D setup](AI_IMAGE_TEXT_TO_3D.md) for the full Meshy job lifecycle and measured sample run.
From the repository root:

```sh
source backend/.venv/bin/activate
python backend/sketch_to_narrative/run.py --dry-run --profile
python backend/image_text_to_3d/run.py create --dry-run --profile
python -m unittest discover -s backend/tests -v
```

Dry runs do not call providers. Removing `--dry-run` from a generation command makes a
paid request. `status` and `download` reuse a saved Meshy job; they must not submit a new
model. The current target is an untextured GLB with approximately 1,000 triangular faces.
Image-to-image preparation and text guidance for shape remain future work.

## Profile both API responses

From the repository root, run:

```sh
backend/.venv/bin/python backend/profile_api_responses.py --dry-run
backend/.venv/bin/python backend/profile_api_responses.py
```

The live command sends the banana sample to OpenAI and Meshy, once each, sequentially.
Use `--image path/to/sketch.png` or `--image-url https://...` for another input.
It prints one JSON line per feature containing the result, exit code, and elapsed
wall time (including Python startup). Detailed API timings go to stderr and ignored
`backend/output/profiles/` files. Keys are loaded from the existing local configuration.
Both features are attempted even if one fails; a failure produces a nonzero exit code.

Meshy's response is a task ID and saved job path, not a finished model. Its timing
measures submission only. Use the existing status/download commands to retrieve the
completed model. Each live run submits a new paid model job; there are no automatic retries.

## Compare Meshy polygon targets

```sh
backend/.venv/bin/python backend/benchmark_meshy_polygons.py --dry-run
backend/.venv/bin/python backend/benchmark_meshy_polygons.py
```

The live benchmark creates four paid jobs sequentially with the same image and model,
requesting 100, 200, 500, and 1,000 triangular faces. It polls every three seconds for
up to ten minutes per job, then downloads completed GLBs and counts their triangles.
Use `--image path/to/image.png` to replace the banana sample. Results, job manifests,
and models stay in ignored `backend/output/polygon_benchmarks/<run-id>/`.

Compare provider processing time separately from queue time, submission latency, and
the locally observed wait (which includes polling delay). The `server_timings_s`
summary values are seconds; their metric names match the original millisecond profiles.
One job per target is a quick comparison, not a statistical benchmark. Re-running
creates four new jobs; saved manifests can be checked using the existing status command.

Quick live comparison on 2026-09-12: banana sample, `meshy-6`, standard model,
remeshing enabled, no textures, triangle topology, GLB output. All four jobs succeeded.

| Target faces | Actual triangles | Provider processing | Observed ready time | GLB bytes |
|---|---|---|---|---|
| 100 | 104 | 38.162 s | 43.988 s | 10,292 |
| 200 | 210 | 40.473 s | 47.450 s | 16,532 |
| 500 | 524 | 47.242 s | 54.376 s | 32,404 |
| 1,000 | 1,038 | 44.526 s | 46.684 s | 51,716 |

Queue times were 3–4 ms. A tenfold target increase took only 1.17 times as long to
process; the 1,000-face job was faster than the 500-face job. This sample does not
show proportional scaling, and variation between runs prevents attributing these
differences solely to polygon count. All downloaded GLBs passed header checks and
triangle counting; visual quality and Godot import were not tested in this comparison.
Meshy's [API documentation](https://docs.meshy.ai/en/api/image-to-3d) describes the
standard-model target as a remeshing/decimation target, which is consistent with
generation taking substantial time even at low output counts.

### Faster model comparison

Run a single 1,000-face Smart Topology job with:

```sh
backend/.venv/bin/python backend/benchmark_meshy_polygons.py --model meshy-t2 --targets 1000
```

The benchmark accepts `--model meshy-6`, `meshy-6-lite`, or `meshy-t2` and a unique
list of `--targets`. Each target creates one paid job. T2 uses `smart-topology`
and omits the ignored remeshing/topology options. This override affects only the
benchmark; the saved configuration and feature script defaults remain unchanged.

One T2 run on the same banana sample on 2026-09-12 succeeded in **2.030 seconds of
provider processing**, compared with **44.526 seconds** for the earlier Meshy-6
1,000-face run (approximately 22 times faster). Queue time was 6 ms; submission
took 0.924 seconds. Completion was observed at 4.827 seconds with three-second
polling, and the GLB was downloaded by 5.038 seconds. Output: 1,108 triangles,
20,704 bytes. The GLB header and triangle count were checked; visual quality and
Godot import remain unverified. This is a single-run comparison, not a guaranteed latency.

### T2 polygon sweep results

A subsequent four-job sweep on 2026-09-12 used the same banana image, T2 Smart
Topology, no textures, and GLB output. Each target was submitted once, sequentially.

| Target faces | Actual triangles | Provider processing | Observed ready time | GLB bytes |
|---|---|---|---|---|
| 100 | 108 | 1.896 s | 4.771 s | 2,672 |
| 200 | 218 | 1.901 s | 4.819 s | 4,652 |
| 500 | 552 | 2.620 s | 4.734 s | 10,668 |
| 1,000 | 1,076 | 2.841 s | 4.706 s | 20,128 |

All jobs succeeded and all GLBs downloaded and passed header/triangle checks.
Queue time was 3–5 ms. A tenfold polygon target increase took 1.50 times as long to
process in this sweep; timings did not scale proportionally. Compared with the earlier
Meshy-6 sweep, T2 processing was approximately 16–21 times faster. Each complete
command, including three-second polling and download, took 4.91–5.06 seconds.
These are single-run observations; visual quality and Godot import were not tested.

### T2 with a shared texture style

```sh
backend/.venv/bin/python backend/benchmark_meshy_polygons.py --model meshy-t2 --texture-prompt 'hand-drawing style'
```

`--texture-prompt` enables textures and accepts the art-style text to use for every
target in the run. Replace the quoted prompt to test a future shared game style.
Textures use 2K resolution with PBR maps disabled. Omit the option for geometry-only
benchmarks. The same four polygon targets are used by default; each creates one paid
textured generation. Reported provider processing includes both geometry and texture
work; it does not isolate the duration of the texture phase.

Live results on 2026-09-12, same banana image and exact prompt `hand-drawing style`:

| Target faces | Actual triangles | Textured processing | Earlier geometry-only processing | GLB bytes |
|---|---|---|---|---|
| 100 | 108 | 64.382 s | 1.896 s | 2,400,240 |
| 200 | 218 | 78.150 s | 1.901 s | 2,267,292 |
| 500 | 552 | 55.911 s | 2.620 s | 2,210,764 |
| 1,000 | 1,087 | 58.833 s | 2.841 s | 2,095,932 |

All four jobs succeeded. Each GLB passed header/triangle checks and contains an embedded
image texture referenced by a base-color material. Queue times were 3–4 ms. Textured
processing took about 56–78 seconds versus 2–3 seconds for geometry alone, with no
proportional scaling by polygon count in this sample. These are single runs, not
isolated texture-phase measurements. Art-style fidelity and Godot import remain unverified.

## Sketch → description → reference image → model

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --dry-run
backend/.venv/bin/python backend/sketch_to_model/run.py
```

The default input is `tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png`.
Use `--image path/to/sketch.png` to choose another sketch, `--target-faces 1000` for
the mesh target, or `--style-prompt '...'` to replace the reference-image instructions.

1. OpenAI uses the configured model to identify hand-drawn equipment and return its
   name, description, and existing validated item fields. Uncertain recognition stops
   the flow before Meshy submission.
2. Meshy's image-to-image endpoint uses `nano-banana`, the original sketch, the OpenAI
   name/description, and a prompt requesting a clear 3D reference while preserving
   silhouette/proportions in hand-drawing style on a plain background.
3. The completed image task ID is passed to T2 Smart Topology, targeting 1,000 faces
   by default, GLB output, and **textures disabled**.

Each live run makes one OpenAI interpretation and up to two paid Meshy creations.
There are no creation retries. Both Meshy stages poll every three seconds for up to
ten minutes; a timeout does not cancel the remote task. A fresh invocation creates a
new run, not a resume. After failure, inspect the saved task IDs before rerunning;
use the Meshy dashboard for the image task and existing status/download CLI for the
model task. `SUBMISSION_UNKNOWN` means creation may have succeeded without a response.

Outputs stay in ignored `backend/output/sketch_to_model/<run-id>/`: `description.json`,
`reference_prompt.txt`, `image_job.json`, `reference.png` (or `.jpg`), `model_job.json`,
and `model.glb`. JSON stage results and local paths print to stdout; sanitized errors
and stage timings go to stderr and the usual profile folder. Keys and signed URLs
are never printed. This is a local script; Godot integration remains pending.

One live test on 2026-09-12 completed successfully using the default saved sketch.
OpenAI identified it as a "Ladder"; this is the model's interpretation, not verified
ground truth. The reference image retained the triangular bracing and added shaded
rounded rails. Measured stage wall times: description 3.049 s, reference image
134.446 s, T2 model and download 5.609 s; total 143.108 s. These include HTTP and
polling overhead. T2 reported 2.930 s of provider processing. The resulting GLB was
18,580 bytes with 934 triangles, zero textures and zero embedded images. The reference
image was visually inspected; the GLB passed structural/triangle checks but was not
visually inspected or imported into Godot. No second live run was made.

For latency investigation, `--image-model nano-banana-2` selects another Meshy image
model; `nano-banana-pro` and `gpt-image-2` are also accepted. The default remains
`nano-banana`, which Meshy describes as suited to fast drafts. No alternative has
been benchmarked in this pipeline. A dry run can validate selection without charges:

```sh
backend/.venv/bin/python backend/sketch_to_model/run.py --image-model nano-banana-2 --dry-run
```

Image jobs now retain separate provider queue and processing milliseconds in the
manifest and profile (`reference_queue_ms`, `reference_processing_ms`). The first
run did not retain these image-provider timestamps, so its 134-second stage cannot
be attributed specifically to queueing or computation. Single-view generation and
background-removal-off are explicit. Meshy's image-to-image API currently documents
no resolution or fast-mode control. Model selection is preparation for measurement,
not a verified speed improvement. Any live rerun needs user authorization.

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
  profiles, or generated models. `backend/output/` is ignored. Exporting Godot must not
  bundle shared API credentials.
- Before staging, inspect `git status` and the diff. Stage explicit source/documentation
  paths instead of the entire working tree. Check `git check-ignore` for local credentials,
  environment, and output paths. Scan staged blobs for actual configured key values and
  recognizable key patterns, reporting filenames only if anything is found.
- Run tests and `git diff --cached --check` before committing. Inspect the staged file list
  and verify `.env.example` key fields are blank. Preserve unrelated user changes/stashes.

## Verification status

OpenAI successfully recognized the banana sample. One Meshy sample job also completed:
38.49 seconds of provider processing, 1,048 output triangles, and no textures. These are
single-run observations. The game smoke tests passed after rebasing onto `main`, but
the game continues to use mock AI and the generated GLB has not been imported into Godot.
