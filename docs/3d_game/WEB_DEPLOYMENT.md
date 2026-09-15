# Web deployment: Vercel game + Python API

## Architecture

GitHub `main` triggers Vercel's build command, `bash tools/web/build.sh`. The build
fetches Godot 4.7.2 and only the official single-threaded Web templates, imports
resources, exports `web-build/index.html`, and precompresses the pack and WASM.
Vercel publishes `web-build/` using `vercel.json`; the generated files are ignored
by Git. No provider keys enter the exported project.

The browser talks directly to a separate HTTPS Python service. Generation jobs
return immediately and run in a bounded background pool; the browser polls for
progress and downloads private assets with its session token. Narration, speech
recognition, and speech generation use the existing story service through the
same asynchronous adapter. Desktop file-mailbox behavior remains available.

A separate long-running backend is required: generation can outlast Vercel Hobby's
[300-second function limit](https://vercel.com/docs/functions/limitations).
The supplied Render Blueprint uses a Free web service without a disk. No cloud
service is created by these repository files alone. This is a small-playtest
configuration, not durable production storage. Render sleeps free services after
15 idle minutes; waking takes about a minute. Restart, redeploy, or sleep deletes
sessions, generated assets, and the file-based request counters. Reload the game
after a restart; do not assume daily limits survive it. Provider calls still cost
credits. See [Render Free limits](https://render.com/docs/free).

Before a demonstration, open the API's /health URL and wait for its ready response.
The client's initial session request allows 75 seconds and a later action can
retry a failed session connection; it does not automatically resubmit paid jobs.

## 1. Deploy the API on Render

1. Sign in to Render with GitHub and choose **New → Blueprint**.
2. Select `AdeDeepFishing/Paws-Peaks`, using the reviewed branch or `main` after
   merge. Render reads the root `render.yaml`.
3. Confirm the service plan is **Free**, with no disk or database. Use one
   service instance/process; storage is temporary, not a shared database.
4. Copy these values from your local `backend/.env` into the backend service:
   - `OPENAI_API_KEY`
   - `MESHY_API_KEY`
   - `ELEVENLABS_API_KEY`
   - `ELEVENLABS_NARRATOR_VOICE_ID`
   - `ELEVENLABS_OTTER_VOICE_ID`
   - `NARRATOR_MODEL`
5. The Blueprint supplies `OPENAI_MODEL`, `MESHY_MODEL`, `ELEVENLABS_MODEL`, and
   `ELEVENLABS_STT_MODEL`. Match them to the desktop configuration if different.
6. `ALLOWED_ORIGINS` must be exactly `https://the-tale-we-drew.vercel.app`.
   For an additional preview domain, append it separated by a comma. Do not use
   `*`. Origins contain no trailing slash or URL path.
7. Deploy. Verify `https://YOUR-SERVICE.onrender.com/health` returns
   `{"ready": true}`. This health check makes no provider calls.

The Docker image includes backend code and the shared material palette JSON.
`.dockerignore` excludes credentials, local environments, output jobs, and all
other game assets. A build-time server import checks startup dependencies. Data is stored temporarily under `/data/web`.

## 2. Connect the existing Vercel project

Keep the Git repository and `main` Production Branch already configured.

| Setting | Value |
| --- | --- |
| Application Preset | Other |
| Root Directory | `./` |
| Build Command | `bash tools/web/build.sh` |
| Output Directory | `web-build` |
| Install Command | None |
| Environment variable | `GAME_API_URL=https://YOUR-SERVICE.onrender.com` |

`vercel.json` defines build/output settings and compression headers. Remove stale
UI overrides if they disagree. Set `GAME_API_URL` for Production (and Preview if
using a preview backend/origin), then redeploy after the PR is merged. This value
is public; it is only the API origin. Provider keys belong to Render, not Vercel.
Existing provider environment variables in Vercel are unused by this build and
can be removed.

Use the production domain for public play. Vercel's Standard Protection excludes
production domains, while All Deployments requires authentication there too.
See [Deployment Protection](https://vercel.com/docs/deployment-protection).

## Runtime contract and limits

- `POST /api/session` creates a random bearer token with a 24-hour lifetime.
- `POST /api/generation` accepts stage identity, PNG base64, and an idempotent
  request ID. `GET /api/generation/{id}` reports progress and opaque asset IDs.
- `POST /api/story` accepts a bounded story operation and input ID.
  `GET /api/story/{id}` reports pending or the service response.
- `GET /api/assets/{id}` downloads assets belonging to that session only.
- All API requests use an allowed browser Origin; all except session creation
  also require `Authorization: Bearer <session-token>`.
- Provider URLs, keys, and local filesystem paths are not returned.
- Defaults: 100 sessions/day globally, 8/day per address, 10 generations/session,
  60 generations per rolling day globally, 400 story requests/session, 12 queued
  or active tasks. Generation and story each have two worker threads.
- Tune `MAX_SESSIONS_PER_DAY`, `MAX_GENERATIONS_PER_SESSION`,
  `MAX_GENERATIONS_PER_DAY`, and `MAX_STORY_REQUESTS_PER_SESSION` on the backend.
  Request-count limits are not a dollar-denominated provider budget.
- With persistent storage, restarted pending tasks report failure; the service does not automatically
  repeat paid jobs. Browser disconnects do not terminate accepted tasks.
- Expired session data is removed after 48 hours when another session is created.
- Reloading starts a new browser session. Tokens are held in memory, not embedded
  into URLs or persisted in exported files.

## Validation and current scope

The initial target is desktop Chrome with WebGL 2, using single-threaded
Compatibility rendering and desktop texture compression. Mobile browsers have
not been qualified. Browser microphone access requires HTTPS and user permission;
audio playback requires a user gesture. Web rendering may differ from desktop
Forward+ lighting.

The initial export was approximately 513 MiB PCK + 38 MiB WASM; gzip transfer is
approximately 419 MiB + 9 MiB. First load is still substantial. This workflow
builds in Vercel from Git rather than uploading the export with the Hobby CLI's
100 MB source-upload limit. See [Vercel limits](https://vercel.com/docs/limits).
Do not serve compressed outputs without their Content-Encoding headers.

Offline checks cover session isolation, idempotency, request limits, Origin/auth
handling, restart behavior, and script parsing. A real Chrome export check covers
map-to-river navigation with mocked story responses. This does not establish live
provider availability or production deployment success; verify those after the
backend URL and credentials have been configured.

### Verified on September 15

- Required backend suite: 78 offline tests passed (including localhost HTTP).
- Chrome rendered the actual compressed game export and entered Chapter I from
  the map; story responses were mocked to avoid charges.
- An isolated debug Web export exercised the real browser and Python adapters
  with fixture providers: PNG upload → progress → reference/model download →
  GLB import; authored story → MP3 download/decode; browser microphone capture →
  WAV upload → transcript. All three passed with no browser script errors.
- Web microphone playback explicitly uses streaming mode. Downloaded Web assets
  are written from returned bytes rather than relying on desktop download-file
  behavior. Exported BGM uses ResourceLoader to follow Godot's import remaps.
- The local Docker daemon was unavailable, so the image was not run locally.
  Hosted Render startup and live-provider verification remain operator steps.
