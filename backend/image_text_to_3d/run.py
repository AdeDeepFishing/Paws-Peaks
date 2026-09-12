#!/usr/bin/env python3
"""Meshy image-to-3D jobs: generate an untextured mesh from an image."""

import argparse
import json
import os
from pathlib import Path
import struct
import sys
import tempfile
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlparse
from urllib.request import Request
from uuid import uuid4

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import AppError, ROOT, image_input, load_config
from common import provider_urlopen as urlopen
from profiling import Profiler, identify, measure, metric, provider_timings

API_URL = "https://api.meshy.ai/openapi/v1/image-to-3d"
MAX_MODEL_BYTES = 64 * 1024 * 1024
STATUSES = ("PENDING", "IN_PROGRESS", "SUCCEEDED", "FAILED", "CANCELED")


def require_key(config):
    key = config["MESHY_API_KEY"]
    if not key or not key.isascii() or any(c.isspace() for c in key):
        raise AppError("CONFIG_ERROR", "Fill MESHY_API_KEY in backend/.env with your Meshy API key.")
    return key


def api_request(config, task_id=None, payload=None):
    url = API_URL if task_id is None else API_URL + "/" + quote(task_id, safe="")
    request = Request(url, method="POST" if payload is not None else "GET",
                      data=json.dumps(payload).encode() if payload is not None else None,
                      headers={"Authorization": "Bearer " + require_key(config), "Content-Type": "application/json"})
    metric("request_body_bytes", len(request.data or b""))
    try:
        with measure("meshy_submit" if payload is not None else "meshy_status"):
            with urlopen(request, timeout=30) as response:
                data = response.read(1024 * 1024 + 1)
        metric("response_body_bytes", len(data))
        if len(data) > 1024 * 1024:
            raise ValueError()
        value = json.loads(data)
        if not isinstance(value, dict):
            raise ValueError()
        return value
    except HTTPError as error:
        messages = {
            400: "Meshy rejected the input or model settings.",
            401: "Meshy rejected authentication. Check MESHY_API_KEY.",
            402: "Meshy requires additional API credits.",
            403: "Meshy denied access. Check your API permissions and plan.",
            404: "The Meshy task or endpoint was not found.",
            429: "Meshy rate or quota limit reached. Try checking the task later.",
        }
        raise AppError("SERVICE_UNAVAILABLE", messages.get(error.code, "Meshy is unavailable. Try again later.")) from None
    except (URLError, TimeoutError, OSError):
        raise AppError("SERVICE_UNAVAILABLE", "Could not reach Meshy. A submitted job may still be running; do not blindly resubmit.") from None
    except (ValueError, UnicodeError):
        raise AppError("INVALID_MODEL_OUTPUT", "Meshy returned an unreadable response.") from None


def build_payload(image, model):
    if not model:
        raise AppError("CONFIG_ERROR", "Set MESHY_MODEL in backend/.env.")
    return {"image_url": image, "ai_model": model,
            "model_type": "standard", "should_texture": False,
            "should_remesh": True, "topology": "triangle", "target_polycount": 1000,
            "target_formats": ["glb"]}


def save_job(path, job):
    """Replace a manifest atomically so an interrupted write preserves the old job ID."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(job, handle, indent=2, allow_nan=False)
            handle.write("\n")
        os.replace(temporary, path)
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


def create_job(payload, config, path, request_id):
    require_key(config)
    path.parent.mkdir(parents=True, exist_ok=True)
    job = {"schema_version": 1, "feature": "image_text_to_3d", "provider": "meshy",
           "request_id": request_id, "task_id": None, "status": "SUBMITTING"}
    try:
        with path.open("x", encoding="utf-8") as handle:
            json.dump(job, handle)
    except FileExistsError:
        raise AppError("INVALID_INPUT", "That job file already exists. Use status/download or a different job path.") from None
    # One creation call, with no retries. Preserve an uncertain submission for manual recovery.
    try:
        task_id = api_request(config, payload=payload).get("result")
        if not valid_task_id(task_id):
            raise AppError("INVALID_MODEL_OUTPUT", "Meshy did not return a usable task ID.")
    except AppError:
        job["status"] = "SUBMISSION_UNKNOWN"
        save_job(path, job)
        raise
    job.update(task_id=task_id, status="PENDING")
    identify(request_id, task_id)
    try:
        save_job(path, job)
    except OSError:
        # Task ID is not a credential. Preserve the only handle to an already-paid job.
        print("Created Meshy task ID: " + task_id, file=sys.stderr)
        raise
    return job


def valid_task_id(value):
    return isinstance(value, str) and 1 <= len(value) <= 256 and value not in (".", "..") and not any(ord(c) < 32 for c in value)


def refresh_job(path, config):
    job = json.loads(path.read_text(encoding="utf-8"))
    if (not isinstance(job, dict) or job.get("schema_version") != 1 or
            job.get("feature") != "image_text_to_3d" or job.get("provider") != "meshy" or
            not isinstance(job.get("request_id"), str) or not valid_task_id(job.get("task_id"))):
        raise AppError("INVALID_INPUT", "The job file has no valid Meshy task. Check the Meshy dashboard if submission was interrupted.")
    identify(job["request_id"], job["task_id"])
    task = api_request(config, task_id=job["task_id"])
    if task.get("id") != job["task_id"] or task.get("status") not in STATUSES:
        raise AppError("INVALID_MODEL_OUTPUT", "Meshy returned an unexpected task or status.")
    provider_timings(task)
    job["status"] = task["status"]
    progress = task.get("progress")
    if type(progress) in (int, float) and 0 <= progress <= 100:
        job["progress"] = progress
    job.pop("glb_url", None)
    if task["status"] == "SUCCEEDED":
        urls = task.get("model_urls")
        glb_url = urls.get("glb") if isinstance(urls, dict) else None
        validate_asset_url(glb_url)
        job["glb_url"] = glb_url
    save_job(path, job)
    return job


def validate_asset_url(url):
    if not isinstance(url, str):
        raise AppError("INVALID_MODEL_OUTPUT", "Meshy did not return a GLB download URL.")
    try:
        parsed = urlparse(url)
        valid = (parsed.scheme == "https" and parsed.hostname == "assets.meshy.ai"
                 and not parsed.username and not parsed.password and parsed.port in (None, 443))
    except ValueError:
        valid = False
    if not valid:
        raise AppError("INVALID_MODEL_OUTPUT", "Unexpected model download host; expected HTTPS assets.meshy.ai.")


def download_model(job, path):
    if job["status"] != "SUCCEEDED":
        raise AppError("MODEL_NOT_READY", "The model is not ready. Check its status again later.")
    validate_asset_url(job.get("glb_url"))
    if path.exists():
        raise AppError("INVALID_INPUT", "The output file already exists. Choose a new --output path.")
    try:
        # The signed asset link authenticates itself. Never forward the API key to a download host.
        with measure("model_download"):
            with urlopen(Request(job["glb_url"]), timeout=30) as response:
                data = response.read(MAX_MODEL_BYTES + 1)
    except (HTTPError, URLError, TimeoutError, OSError):
        raise AppError("SERVICE_UNAVAILABLE", "Model download failed. Retry download to refresh the asset link.") from None
    metric("download_bytes", len(data))
    with measure("model_validation"):
        if len(data) < 12 or len(data) > MAX_MODEL_BYTES:
            raise AppError("INVALID_MODEL_OUTPUT", "The GLB is empty, truncated, or larger than 64 MiB.")
        magic, version, size = struct.unpack("<4sII", data[:12])
        if magic != b"glTF" or version != 2 or size != len(data):
            raise AppError("INVALID_MODEL_OUTPUT", "The downloaded file has an invalid GLB header.")
    path.parent.mkdir(parents=True, exist_ok=True)
    # Exclusive creation preserves any file another process created during the download.
    try:
        with measure("model_write"):
            with path.open("xb") as handle:
                try:
                    handle.write(data)
                except OSError:
                    path.unlink(missing_ok=True)
                    raise
    except FileExistsError:
        raise AppError("INVALID_INPUT", "The output file already exists. Choose a new --output path.") from None
    return str(path.resolve())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("create", help="Submit one paid job and save its ID; does not wait for generation.")
    source = create.add_mutually_exclusive_group()
    source.add_argument("--image", type=Path, default=ROOT / "samples" / "banana.jpg")
    source.add_argument("--image-url")
    create.add_argument("--request-id", default="model-" + uuid4().hex)
    create.add_argument("--job", type=Path, help="New local manifest path. Defaults to backend/output/image_text_to_3d/<unique-id>.json.")
    create.add_argument("--dry-run", action="store_true")
    status = commands.add_parser("status", help="Retrieve an existing job once; never creates a new model.")
    status.add_argument("--job", type=Path, required=True)
    download = commands.add_parser("download", help="Refresh an existing job and download its completed GLB.")
    download.add_argument("--job", type=Path, required=True)
    download.add_argument("--output", type=Path, required=True)
    for command in (create, status, download):
        command.add_argument("--profile", action="store_true", help="Print performance to stderr and save a report under backend/output/profiles/.")
    args = parser.parse_args(argv)
    path = args.job or ROOT / "output" / "image_text_to_3d" / (uuid4().hex + ".json")
    profiler = Profiler(args.profile, "image_text_to_3d", args.command, getattr(args, "request_id", None))
    outcome = "UNEXPECTED_ERROR"
    try:
        with measure("config_load"):
            config = load_config(args.env_file)
        if args.command == "create":
            with measure("image_prepare"):
                payload = build_payload(image_input(args.image, args.image_url), config["MESHY_MODEL"])
            metric("target_faces", payload["target_polycount"])
            if args.dry_run:
                print(json.dumps({"dry_run": True, "feature": "image_text_to_3d", "provider": "meshy",
                                  "model": config["MESHY_MODEL"], "api_key_configured": bool(config["MESHY_API_KEY"]),
                                  "image_ready": True, "should_texture": False, "target_format": "glb"}))
                outcome = "DRY_RUN"
                return 0
            job = create_job(payload, config, path, args.request_id)
        else:
            job = refresh_job(path, config)
            if args.command == "download":
                job["model_path"] = download_model(job, args.output)
                save_job(path, job)
        print(json.dumps({**job, "job_file": str(path.resolve())}, indent=2, allow_nan=False))
        outcome = job["status"]
        return 1 if job["status"] in ("FAILED", "CANCELED") else 0
    except AppError as error:
        code, message = error.code, str(error)
        outcome = code
    except (OSError, ValueError, UnicodeError):
        code, message = "LOCAL_FILE_ERROR", "Could not read or write the image, configuration, job manifest, or output file."
        outcome = code
    finally:
        profiler.finish(outcome)
    print(json.dumps({"feature": "image_text_to_3d", "job_file": str(path.resolve()), "error": {"code": code}}))
    print(message, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
