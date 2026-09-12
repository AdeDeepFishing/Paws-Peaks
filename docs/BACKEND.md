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
