# Image to an untextured 3D model

Entry point: `backend/image_text_to_3d/run.py`. Uses the shared `backend/.venv`,
`backend/.env`, and `backend/samples/banana.jpg`. No additional Python packages are required.

The current adapter generates **geometry from the image, with texturing disabled**
(`should_texture: false`). No texture prompt, texture reference, or PBR generation is
requested. The CLI has no `--text` argument. The feature folder retains its planned
`image_text_to_3d` name, but text guidance for shape is not implemented. That would need
a reference-image editing stage or a provider that supports both inputs for geometry.

## Credentials

Add a separately obtained Meshy API key to the existing ignored `backend/.env`:

```dotenv
MESHY_API_KEY=your_meshy_key_here
MESHY_MODEL=meshy-6
```

The OpenAI key remains in the same file and continues to serve the narrative feature.
OpenAI credits cannot pay for this Meshy request. A live banana-image test succeeded on
September 12, 2026; the measured results are recorded below. Sketch quality and Godot
loading/rendering remain unverified.

## Run the sample

Activate the virtual environment from the repository root:

```sh
source backend/.venv/bin/activate
```

First check the local inputs without a network call or a key:

```sh
python backend/image_text_to_3d/run.py create --dry-run
```

Submit a job once (this uses Meshy API credits):

```sh
python backend/image_text_to_3d/run.py create \
  --image backend/samples/banana.jpg \
  --request-id E01-banana-model \
  --job backend/output/image_text_to_3d/banana-job.json
```

You can substitute `--image-url 'https://...'` for `--image`. No text is required.
The default requests an untextured GLB, triangle topology, and remeshing
toward 1,000 faces. This is a target, not an enforced game asset budget.

The command returns immediately after submission. It saves the provider task ID and
your request ID in the job file. When `--job` is omitted, it creates a unique manifest
under `backend/output/image_text_to_3d/` and prints its path. Existing job files cannot
be reused for creation; this prevents accidental duplicate submissions using that path.

Check the same job later:

```sh
python backend/image_text_to_3d/run.py status \
  --job backend/output/image_text_to_3d/banana-job.json
```

Statuses are `PENDING`, `IN_PROGRESS`, `SUCCEEDED`, `FAILED`, or `CANCELED`.
Each invocation checks once; a future game caller can poll every few seconds while
the player explores. Checking status never creates a new generation job.

When it succeeds, download the model:

```sh
python backend/image_text_to_3d/run.py download \
  --job backend/output/image_text_to_3d/banana-job.json \
  --output backend/output/image_text_to_3d/banana.glb
```

Download refreshes the task to obtain its current signed GLB URL, then downloads without
forwarding the API key. It accepts the documented `assets.meshy.ai` HTTPS host, limits
the response to 64 MiB, and checks the GLB version/header/declared length. It preserves
existing output files. These checks are not full glTF validation, a mesh quality check,
or a Godot import test. Asset links can expire; keep the downloaded file.

## Errors and recovery

- JSON is printed to stdout; local diagnostic messages go to stderr. Keys and raw
  provider errors are never printed. Job files and GLBs are under the ignored output folder.
- Exit code 0 means submission/status/download succeeded; a `PENDING` result still has
  no usable model. Failed/canceled tasks and command errors exit with code 1.
- Creation is never automatically retried. A timeout can happen after Meshy accepted
  a paid job. An interrupted or failed submission may leave `SUBMITTING` or
  `SUBMISSION_UNKNOWN` in the manifest. Check the provider dashboard before starting
  another job. If a task was created, recover its ID into the manifest's `task_id` and
  use `status`; otherwise use a different manifest path for a deliberate new attempt.
- Job files hold task identity, status, and signed asset URLs, not API keys or image bytes.
- Each provider request/download has a 30-second socket timeout. There is no generation
  timeout or cancel-provider action in this initial adapter. Closing the script does not
  cancel a job already submitted to Meshy.

## Game integration boundary

Keep the narrative item and model job separate. Use `--request-id` to associate a job
with a submitted drawing, and retain that identity through status/download. The model
manifest uses its own feature schema version 1; it is not a `DrawingRequest` version-2
item response and must not be passed to `DrawingRequest.accept_response()`.

Godot should check that the originating item/session is still current before loading
the GLB. Model failure must leave the narrative item usable. The generated visual needs
runtime loading, scale/orientation adjustment, and a predefined spawn anchor. Collision
and encounter rules stay authored. None of this game-side model integration is implemented.

## Verification and provider reference

### Live sample test — September 12, 2026

One Meshy `meshy-6` job was submitted using the downloaded banana photograph, a target
of 1,000 triangular faces, and textures disabled. The same job was polled and downloaded;
no additional generation jobs were created.

| Measurement | Result |
|---|---|
| Submission API round trip | 939.273 ms |
| Provider queue | 3 ms |
| Provider processing | 38,493 ms |
| Provider total (creation to finish) | 38,496 ms |
| GLB download | 233.775 ms |
| Download command including status refresh | 866.578 ms |
| File size | 52,960 bytes |
| Actual mesh | 1 mesh, 1 primitive, 1,048 triangles |
| Images / textures / materials | 0 / 0 / 0 |

These are one-run observations, not average latency or a guarantee. The triangle count
was inspected from the GLB primitive/accessor metadata and exceeds the requested target
by 48 faces. GLB header/chunk structure passed local checks; no Godot import, visual
quality, collision, or runtime performance check was performed.

Local artifacts (ignored by Git):

- `backend/output/image_text_to_3d/banana-test.glb`
- `backend/output/image_text_to_3d/banana-test-job.json`
- `backend/output/image_text_to_3d/banana-test-inspection.json`
- Submission profile: `backend/output/profiles/c33a6bdccc9340aca9789fa479cd3282.json`
- Download profile: `backend/output/profiles/50b615b198e0444fabdef2036cc50b45.json`

The 23 offline tests also passed after adding profiling.

### Profiling and offline checks

For performance measurements, add `--profile` after `create`, `status`, or `download`.
Reports include API round-trip time, provider queue/processing time when timestamps are
available, and GLB transfer size/time. See [profiling details](AI_LOCAL_SETUP.md#performance-profiling).
The generation target remains 1,000 faces with textures disabled.

```sh
backend/.venv/bin/python -m unittest discover -s backend/tests -v
```

Offline tests cover creation, duplicate prevention, uncertain submission, status changes,
request identity, download headers/size, credential handling, and failure paths.

Provider fields, task states, and limits were checked against the official
[Meshy image-to-3D API documentation](https://docs.meshy.ai/en/api/image-to-3d).
See [local AI setup](AI_LOCAL_SETUP.md) for the shared environment and narrative feature.
