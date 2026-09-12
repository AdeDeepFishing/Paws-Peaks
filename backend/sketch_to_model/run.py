#!/usr/bin/env python3
"""Hand-drawn equipment -> description -> reference image -> untextured T2 GLB."""

import argparse
import json
from pathlib import Path
import sys
import time
from uuid import uuid4

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from common import ROOT, AppError, image_input, load_config
from sketch_to_narrative.run import interpret, PROMPT
from image_text_to_3d.run import create_job, refresh_job, download_model, save_job
from profiling import Profiler, measure
from sketch_to_model import openai_edit

SKETCH_PROMPT = PROMPT + """
This is a hand-drawn tool or piece of equipment intended for a game, not a photograph.
Infer the most likely object from its strokes. Equipment may include a bridge or ladder.
Describe its visible silhouette, proportions and structural parts to guide reconstruction.
Describe the complete object, not a cropped fragment. If the sketch touches the image
edge, describe its likely complete form without inventing unrelated parts. Include
"whole object, all parts visible" in the description to guide the next image stage.
Do not invent an object if the sketch is too ambiguous: return uncertain instead.
"""
STYLE_PROMPT = ("Turn this rough sketch into a clear, three-dimensional reference of the "
                "object described below. Preserve its silhouette and proportions. "
                "Hand-drawing style, isolated object, plain background, no text. "
                "Show one complete object in a single view, not a collage. "
                "Fit the entire object inside the frame with at least 10% empty margin on every side. "
                "All endpoints, rails, handles and other parts must be fully visible. "
                "No cropping, cut-off parts, close-up framing or objects touching the image edges. "
                "Zoom out as needed; preserve the complete object's proportions.")
DEFAULT_IMAGE = ROOT.parent / "tests/fixtures/sketches/E01-2026-09-12T15-55-03-58aa7d14598ccf2b.png"


def reference_prompt(item, style):
    return (style + "\nObject description: " + item["name"] + ". " + item["description"]
            + "\nUse simple solid forms with minimal shading. No fine surface detail, "
            "decorative textures, scenery, labels or extra objects. Prioritize readable geometry.")


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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, default=DEFAULT_IMAGE)
    parser.add_argument("--style-prompt", default=STYLE_PROMPT)
    parser.add_argument("--openai-image-model", default=openai_edit.DEFAULT_MODEL)
    parser.add_argument("--openai-image-size", choices=("816x816", "1024x1024"), default=openai_edit.DEFAULT_SIZE)
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
                              "reference_provider": "openai",
                              "openai_image_size": args.openai_image_size,
                              "image_model": args.openai_image_model,
                              "mesh_model": "meshy-t2", "should_texture": False}))
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
        prompt = reference_prompt(description["item"], args.style_prompt)
        (folder / "reference_prompt.txt").write_text(prompt)
        with measure("reference_image_stage"):
            reference = openai_edit.generate(args.image, prompt, config, folder,
                                            args.openai_image_model, args.openai_image_size)
            mesh_input = {"image_url": image_input(reference)}
        print(json.dumps({"stage": "reference_image", "path": str(reference)}), flush=True)
        with measure("model_stage"):
            mesh_payload = {**mesh_input, "ai_model": "meshy-t2",
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
