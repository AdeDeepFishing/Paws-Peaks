#!/usr/bin/env python3
"""Hand-drawn equipment -> description -> reference image -> untextured T2 GLB."""

import argparse
import json
from pathlib import Path
import sys
import time
from urllib.request import Request
from uuid import uuid4

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import ROOT, AppError, image_input, load_config, provider_urlopen
from sketch_to_narrative.run import interpret, PROMPT
from image_text_to_3d.run import (api_request, create_job, refresh_job, download_model,
                                save_job, valid_task_id, validate_asset_url)
from profiling import Profiler, measure, metric

SKETCH_PROMPT = PROMPT + """
This is a hand-drawn tool or piece of equipment intended for a game, not a photograph.
Infer the most likely object from its strokes. Equipment may include a bridge or ladder.
Describe its visible silhouette, proportions and structural parts to guide reconstruction.
Do not invent an object if the sketch is too ambiguous: return uncertain instead.
"""
STYLE_PROMPT = ("Turn this rough sketch into a clear, three-dimensional reference of the "
                "object described below. Preserve its silhouette and proportions. "
                "Hand-drawing style, isolated object, plain background, no text. "
                "Show one complete object in a single view, not a collage.")
DEFAULT_IMAGE = ROOT.parent / "tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png"


def reference_payload(image, item, style, model="nano-banana"):
    return {"ai_model": model, "reference_image_urls": [image],
            "prompt": style + "\nObject description: " + item["name"] + ". " + item["description"],
            "generate_multi_view": False, "aspect_ratio": "1:1", "remove_background": False}


def reference_timings(task):
    result = {}
    for name, start_key, end_key in (
        ("queue_ms", "created_at", "started_at"),
        ("processing_ms", "started_at", "finished_at"),
    ):
        start, end = task.get(start_key), task.get(end_key)
        if type(start) in (int, float) and type(end) in (int, float) and 0 < start <= end:
            result[name] = end - start
            metric("reference_" + name, end - start)
    return result


def wait_for_task(fetch):
    deadline = time.monotonic() + 600
    while time.monotonic() < deadline:
        task = fetch()
        if task["status"] == "SUCCEEDED":
            return task
        if task["status"] in ("FAILED", "CANCELED"):
            raise AppError("GENERATION_FAILED", "Provider generation failed; check the saved task ID.")
        time.sleep(3)
    raise AppError("POLL_TIMEOUT", "Task may still be running; check the saved task ID instead of resubmitting.")


def generate_reference(payload, config, path):
    job = {"endpoint": "image-to-image", "status": "SUBMITTING", "task_id": None,
           "ai_model": payload.get("ai_model")}
    save_job(path, job)
    try:
        task_id = api_request(config, payload=payload, endpoint="image-to-image").get("result")
        if not valid_task_id(task_id):
            raise AppError("INVALID_MODEL_OUTPUT", "Image generation returned no usable task ID.")
    except AppError:
        job["status"] = "SUBMISSION_UNKNOWN"
        save_job(path, job)
        raise
    job.update(task_id=task_id, status="PENDING")
    save_job(path, job)

    def fetch():
        task = api_request(config, task_id=task_id, endpoint="image-to-image")
        if task.get("id") != task_id or task.get("status") not in ("PENDING", "IN_PROGRESS", "SUCCEEDED", "FAILED", "CANCELED"):
            raise AppError("INVALID_MODEL_OUTPUT", "Unexpected image task response.")
        job["status"] = task["status"]
        save_job(path, job)
        return task

    task = wait_for_task(fetch)
    job["provider_timings"] = reference_timings(task)
    save_job(path, job)
    urls = task.get("image_urls")
    if not isinstance(urls, list) or len(urls) != 1:
        raise AppError("INVALID_MODEL_OUTPUT", "Expected exactly one reference image.")
    validate_asset_url(urls[0])
    # Save a local preview; signed URL remains private and is never printed.
    with provider_urlopen(Request(urls[0]), timeout=30) as response:
        data = response.read(20 * 1024 * 1024 + 1)
    if len(data) > 20 * 1024 * 1024 or not data.startswith((b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff")):
        raise AppError("INVALID_MODEL_OUTPUT", "Invalid reference image download.")
    image_path = path.parent / ("reference.png" if data.startswith(b"\x89PNG") else "reference.jpg")
    image_path.write_bytes(data)
    return task_id, image_path


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE)
    parser.add_argument("--style-prompt", default=STYLE_PROMPT)
    parser.add_argument("--image-model", default="nano-banana",
                        choices=("nano-banana", "nano-banana-2", "nano-banana-pro", "gpt-image-2"),
                        help="Meshy reference-image model. Speed differences require live measurement.")
    parser.add_argument("--target-faces", type=int, default=1000)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if not 100 <= args.target_faces <= 15000:
        parser.error("T2 target faces must be between 100 and 15000.")
    folder = ROOT / "output/sketch_to_model" / uuid4().hex
    profile = Profiler(True, "sketch_to_model", "pipeline")
    outcome = "ERROR"
    try:
        config = load_config(ROOT / ".env")
        image = image_input(args.image)
        if args.dry_run:
            print(json.dumps({"dry_run": True, "image_ready": True, "target_faces": args.target_faces,
                              "image_model": args.image_model, "mesh_model": "meshy-t2", "should_texture": False}))
            outcome = "DRY_RUN"
            return 0
        folder.mkdir(parents=True)
        print("Output folder: " + str(folder), file=sys.stderr, flush=True)
        with measure("description_stage"):
            description = interpret(image, config, prompt=SKETCH_PROMPT)
        save_job(folder / "description.json", description)
        if description["status"] != "recognized":
            raise AppError("UNCERTAIN_SKETCH", "Sketch was ambiguous; no Meshy jobs submitted.")
        print(json.dumps({"stage": "description", "result": description}), flush=True)
        payload = reference_payload(image, description["item"], args.style_prompt, args.image_model)
        (folder / "reference_prompt.txt").write_text(payload["prompt"])
        with measure("reference_image_stage"):
            image_task, reference = generate_reference(payload, config, folder / "image_job.json")
        print(json.dumps({"stage": "reference_image", "path": str(reference)}), flush=True)
        with measure("model_stage"):
            mesh_payload = {"input_task_id": image_task, "ai_model": "meshy-t2",
                            "model_type": "smart-topology", "target_polycount": args.target_faces,
                            "should_texture": False, "target_formats": ["glb"]}
            job_path = folder / "model_job.json"
            create_job(mesh_payload, config, job_path, folder.name)
            job = wait_for_task(lambda: refresh_job(job_path, config))
            model_path = download_model(job, folder / "model.glb")
        print(json.dumps({"stage": "model", "status": "SUCCEEDED", "path": model_path}), flush=True)
        outcome = "SUCCEEDED"
        return 0
    except AppError as error:
        print(json.dumps({"error": error.code, "output_folder": str(folder)}))
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        print(json.dumps({"error": "LOCAL_OR_RESPONSE_ERROR", "output_folder": str(folder)}))
        return 1
    finally:
        profile.finish(outcome)


if __name__ == "__main__":
    sys.exit(main())
