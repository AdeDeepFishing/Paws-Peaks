#!/usr/bin/env python3
"""Interpret -> image edit -> model generation, with reusable game materials selected during interpretation."""

import argparse
import base64
import json
from pathlib import Path
import sys
import time
from uuid import uuid4

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from utils.common import ROOT, AppError, image_input, load_config
from interpret import run as interpret
from interpret.prompts import SKETCH_PROMPT
from image_edit import run as image_edit
from image_edit.prompts import STYLE_PROMPT, reference_prompt
from model_generation import run as model_generation
from utils.profiling import Profiler, measure
from utils.render import preview_result
from stage_config import STAGES, classes_for

DEFAULT_IMAGE = ROOT.parent / "tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png"


def wait_for_task(fetch):
    deadline = time.monotonic() + 600
    while time.monotonic() < deadline:
        task = fetch()
        if task["status"] == "SUCCEEDED":
            return task
        if task["status"] in ("FAILED", "CANCELED"):
            raise AppError("GENERATION_FAILED", "Provider generation failed; check the saved task ID.")
        time.sleep(0.1)
    raise AppError("POLL_TIMEOUT", "Task may still be running; check the saved task ID instead of resubmitting.")


def main(argv=None, *, output_folder=None, on_event=None, on_response=None):
    def api_call(operation, call):
        started = time.perf_counter()
        status = "FAILED"
        try:
            result = call()
            status = "SUCCEEDED"
            return result
        finally:
            if on_response is not None:
                on_response({"operation": operation, "status": status,
                             "duration_ms": round((time.perf_counter() - started) * 1000, 3)})

    def emit(event):
        if on_event is not None:
            on_event(event)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game-stage", choices=STAGES, default="river")
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE)
    parser.add_argument("--style-prompt", default=STYLE_PROMPT)
    parser.add_argument("--openai-image-model", default=image_edit.DEFAULT_MODEL)
    parser.add_argument("--openai-image-size", choices=("816x816", "1024x1024"), default=image_edit.DEFAULT_SIZE)
    parser.add_argument("--target-faces", type=int, default=500,
                        help="T2 geometry target (default: 500 for lightweight game objects).")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    if not 100 <= args.target_faces <= 15000:
        parser.error("T2 target faces must be between 100 and 15000.")
    folder = Path(output_folder) if output_folder is not None else ROOT / "output/sketch_to_model" / uuid4().hex
    profile = Profiler(True, "sketch_to_model", "pipeline")
    outcome = "ERROR"
    try:
        classes_for(args.game_stage)
        config = load_config(ROOT / ".env")
        image = image_input(args.image)
        if args.dry_run:
            print(json.dumps({"dry_run": True, "image_ready": True, "target_faces": args.target_faces,
                              "reference_provider": "openai",
                              "openai_model": config.get("OPENAI_MODEL", "gpt-4.1-mini"),
                              "openai_image_size": args.openai_image_size,
                              "image_model": args.openai_image_model,
                              "mesh_model": "meshy-t2", "should_texture": False}))
            outcome = "DRY_RUN"
            return 0
        folder.mkdir(parents=True, exist_ok=True)
        # Keep the exact validated bytes used by interpretation beside its outputs.
        suffix = ".png" if image.startswith("data:image/png;") else ".jpg"
        source = folder / ("input" + suffix)
        source.write_bytes(base64.b64decode(image.split(",", 1)[1], validate=True))
        print("Output folder: " + str(folder), file=sys.stderr, flush=True)
        # 1. Interpret: one OpenAI request returns structured item JSON.
        emit({"stage": "description", "status": "PENDING"})
        with measure("description_stage"):
            description = api_call("openai_interpretation", lambda: interpret.interpret(
                image, config, prompt=SKETCH_PROMPT, game_stage=args.game_stage))
        model_generation.save_job(folder / "description.json", description)
        print(json.dumps({"stage": "description", "result": description}), flush=True)
        # 2. Image edit: one reference image using the selected material and color.
        emit({"stage": "reference_image", "status": "PENDING", "item": description["item"]})
        prompt = reference_prompt(description["item"], args.style_prompt)
        (folder / "reference_prompt.txt").write_text(prompt)
        with measure("reference_image_stage"):
            reference = api_call("openai_image_edit", lambda: image_edit.generate(
                source, prompt, config, folder, args.openai_image_model, args.openai_image_size))
            mesh_input = {"image_url": image_input(reference)}
        print(json.dumps({"stage": "reference_image", "path": str(reference)}), flush=True)
        # 3. Model generation: one Meshy creation request returns a task ID.
        emit({"stage": "model", "status": "PENDING", "reference_path": str(reference)})
        with measure("model_stage"):
            mesh_payload = {**mesh_input, "ai_model": "meshy-t2",
                            "model_type": "smart-topology", "target_polycount": args.target_faces,
                            "should_texture": False, "target_formats": ["glb"]}
            job_path = folder / "model_job.json"
            api_call("meshy_submit", lambda: model_generation.create_job(mesh_payload, config, job_path, folder.name))
            # Poll and download the existing task; never submit another creation.
            job = wait_for_task(lambda: api_call("meshy_status", lambda: model_generation.refresh_job(job_path, config)))
            model_path = api_call("model_download", lambda: model_generation.download_model(job, folder / "model.glb"))
        print(json.dumps({"stage": "model", "status": "SUCCEEDED", "path": model_path}), flush=True)
        emit({"stage": "preview", "status": "PENDING", "model_path": str(model_path)})
        with measure("preview_stage"):
            preview = preview_result(model_path)
        print(json.dumps({"stage": "preview", **preview}), flush=True)
        emit({"stage": "complete", "status": "SUCCEEDED", "item": description["item"], "model_path": str(model_path), **preview})
        outcome = "SUCCEEDED"
        return 0
    except AppError as error:
        emit({"stage": "error", "status": "FAILED", "error": error.code})
        print(json.dumps({"error": error.code, "output_folder": str(folder)}))
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, KeyError, TypeError):
        emit({"stage": "error", "status": "FAILED", "error": "LOCAL_OR_RESPONSE_ERROR"})
        print(json.dumps({"error": "LOCAL_OR_RESPONSE_ERROR", "output_folder": str(folder)}))
        return 1
    finally:
        profile.finish(outcome)


if __name__ == "__main__":
    sys.exit(main())
