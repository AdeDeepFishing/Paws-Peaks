# Local AI features

This is a desktop development helper: one Python process sends an image to OpenAI,
prints a validated item response, and exits. No HTTP server, package installation,
or GPU is required. Python 3.9 or later is required; all imports use the standard library.

Implemented: local PNG/JPEG or public HTTPS image input, local credentials, an OpenAI
Responses API call with Structured Outputs, and the game's version-2 output contract.
The separate Meshy adapter supports image -> an untextured 3D generation job and GLB
download; see [3D setup](AI_IMAGE_TEXT_TO_3D.md). Godot still uses its mock responses.
Player-action invocation, application packaging, and hosted browser integration are not implemented.

## Feature layout

```text
backend/
  .env                        # Ignored local credentials shared by features
  .env.example                # Tracked blank configuration template
  .venv/                      # Ignored shared Python environment
  common.py                   # Local configuration and PNG/JPEG input helpers
  profiling.py                # Optional command/stage timing and JSON reports
  sketch_to_narrative/
    run.py                    # OpenAI: image -> narrative and game item JSON
  image_text_to_3d/
    run.py                    # Meshy: image -> untextured mesh job/status/GLB
  samples/banana.jpg          # Shared development input
  tests/                      # Offline tests for both features
  output/                     # Ignored job manifests and generated models
  interpret_image.py          # Compatibility shortcut for the original command
```

The old `python backend/interpret_image.py` command still works. Prefer the feature
entry points below for new integrations. Use a separate folder for each future feature;
share only common input/configuration helpers, not feature-specific prompts or responses.

## Setup and first run

From the repository root, create and activate the environment:

```sh
python3 -m venv backend/.venv
source backend/.venv/bin/activate
```

The initial setup already created `.venv` and a blank `backend/.env` on Beichun's machine.
On a fresh clone, copy `backend/.env.example` to `backend/.env` if `.env` does not exist.
Open `.env` in your editor and fill in:

```dotenv
OPENAI_API_KEY=your_actual_key_here
OPENAI_MODEL=gpt-4.1-mini
```

Keep values on single lines; optional surrounding quotes are accepted. Full-line `#`
comments are supported; inline comments and shell expansion are not. Environment variables
take precedence over `.env`. The file is resolved relative to the script, so it works from
any working directory. `.env` and `.venv/` are ignored by Git. Never place the key in
command-line arguments, tracked files, or a game export.

Run a local check without an API request, then make one real request:

```sh
python backend/sketch_to_narrative/run.py --dry-run
python backend/sketch_to_narrative/run.py
```

Without activation, use `backend/.venv/bin/python backend/sketch_to_narrative/run.py`.
The real run sends `backend/samples/banana.jpg` as a Base64 data URL and makes one
billable API call using your account. It prints JSON with an English name, a short
descriptive/narrative sentence, type, attack power, range, speed, durability, and tags.
The sample's actual interpretation is model-generated, not a fixture.

Use your own image or let OpenAI fetch a public image link:

```sh
python backend/sketch_to_narrative/run.py --image /absolute/path/to/drawing.png
python backend/sketch_to_narrative/run.py --image-url 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Banana-Single.jpg/960px-Banana-Single.jpg'
```

Local files are limited to 1 MiB and checked for PNG/JPEG signatures. This helper does
not fully decode images or enforce the game's 512 × 512 drawing size; OpenAI performs
image decoding. URL mode passes the link to OpenAI, which must be able to access it
without authentication. Localhost links will not work. The local file avoids that
external image-host dependency on subsequent runs.

Save a result if useful:

```sh
mkdir -p backend/output
python backend/sketch_to_narrative/run.py > backend/output/item.json
```

Successful recognition and uncertainty both exit with code 0. Errors exit with code 1,
print a versioned JSON error envelope to stdout, and a human-readable message to stderr.
Check the exit code before treating a saved file as a successful result. Raw provider
errors and credentials are not printed. There are no automatic retries. The network
socket timeout is 15 seconds, not a guaranteed end-to-end deadline.

If access fails, check the key, API billing/quota, and model access. `gpt-4.1-mini` is
a configurable initial choice supporting image input and Structured Outputs; this is
not a claim of lowest latency. A live request successfully recognized the sample banana
with the configured account before the folder reorganization; subsequent refactoring is
verified with offline tests rather than additional paid calls.

## Later: invoke from a player action

The script can be called as a subprocess with a submitted image path and the game's
existing request identity:

```sh
backend/.venv/bin/python backend/sketch_to_narrative/run.py \
  --image /absolute/path/to/submitted.png \
  --request-id E01-original-request-id
```

Use the actual `DrawingRequest.active_id`; the CLI generates a new ID only for standalone
testing. It prints the same `schema_version: 2`, `request_id`, `status`, and `item` shape
accepted by `DrawingRequest.accept_response()`. Error responses preserve that identity too.

When integrating, run the subprocess asynchronously, collect its stdout JSON, and deliver
the result on Godot's main thread. Keep the current deadline and stale-result checks;
do not block the game loop while Python waits for OpenAI. Preserve the submitted image
until the process has read it. A desktop release would need an available or bundled
Python runtime and local configuration; a Godot Web export cannot launch this process.

## Performance profiling

Add `--profile` to any feature command, including `--dry-run`:

```sh
python backend/sketch_to_narrative/run.py --profile
python backend/image_text_to_3d/run.py create --profile
python backend/image_text_to_3d/run.py status --job backend/output/image_text_to_3d/banana-job.json --profile
python backend/image_text_to_3d/run.py download --job backend/output/image_text_to_3d/banana-job.json --output backend/output/image_text_to_3d/banana.glb --profile
```

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

## Offline verification

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

Tests replace HTTP with fixtures: they check image handling, request construction,
the output contract, numeric/tag validation, malformed/refused/incomplete responses,
credential redaction, and errors. They do not verify live model quality or API access.

## Sample image credit

- File: `backend/samples/banana.jpg` (960 × 846 JPEG thumbnail).
- Work: [Banana-Single.jpg](https://commons.wikimedia.org/wiki/File:Banana-Single.jpg).
- Author: Evan-Amos.
- License: [Creative Commons Attribution-ShareAlike 3.0 Unported](https://creativecommons.org/licenses/by-sa/3.0/).
- Source: [Wikimedia thumbnail](https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Banana-Single.jpg/960px-Banana-Single.jpg).
- Downloaded September 12, 2026. No local modifications; Wikimedia supplied the resized thumbnail.
- This sample is a development input, not game art or a test of sketch-recognition quality.

## API references

- [OpenAI image inputs](https://developers.openai.com/api/docs/guides/images-vision).
- [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
- [GPT-4.1 mini capabilities](https://developers.openai.com/api/docs/models/gpt-4.1-mini).

`store: false` is used; it is not a promise of zero provider retention. This script
generates text and item data. The separate [3D feature](AI_IMAGE_TEXT_TO_3D.md) uses Meshy
and its own credentials. It currently generates geometry from an image with texturing
disabled; text guidance for shape is not implemented.
