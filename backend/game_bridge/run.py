"""Private, atomic status-file adapter for the desktop Godot game."""
import argparse
import contextlib
import json
import os
from pathlib import Path
import re
import shutil
import sys
import time

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import ROOT, image_input
from image_text_to_3d.run import save_job
from sketch_to_model import run as pipeline


def execute(job_dir, request_id, encounter_id, mode):
    job_dir = Path(job_dir).resolve()
    # The caller creates a unique job directory and its immutable input.png.
    status_path = job_dir / "status.json"
    try:
        # Exclusive creation also prevents concurrent duplicate submissions.
        with (job_dir / "started.lock").open("x"):
            pass
    except FileExistsError:
        return 2  # Never silently start the same paid job twice.
    envelope = {"schema_version": 1, "request_id": request_id,
                "encounter_id": encounter_id, "mode": mode}

    def emit(event):
        # Only the explicitly allowed fields enter the game's status channel.
        allowed = {key: event[key] for key in ("stage", "status", "item", "model_path", "error") if key in event}
        save_job(status_path, {**envelope, **allowed})

    try:
        emit({"stage": "starting", "status": "PENDING"})
        image_input(job_dir / "input.png")
        if mode == "fixture":
            fixture = ROOT.parent / "docs/test-artifacts/sketch-to-model-2026-09-12"
            emit({"stage": "reference_image", "status": "PENDING"})
            time.sleep(0.4)
            item = json.loads((fixture / "description.json").read_text())["item"]
            emit({"stage": "model", "status": "PENDING"})
            time.sleep(0.4)
            target = job_dir / "model.glb"
            shutil.copyfile(fixture / "model.glb", target)
            emit({"stage": "complete", "status": "SUCCEEDED", "item": item, "model_path": str(target)})
            return 0
        # Provider keys are read only by Python. No keys or signed URLs enter Godot.
        with open(os.devnull, "w") as sink, contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
            code = pipeline.main(["--image", str(job_dir / "input.png")],
                                 output_folder=job_dir / "artifacts", on_event=emit)
        if code and json.loads(status_path.read_text()).get("status") != "FAILED":
            emit({"stage": "error", "status": "FAILED", "error": "PIPELINE_FAILED"})
        return code
    except Exception:
        # Never forward raw exceptions, paths from providers, or credentials to UI.
        emit({"stage": "error", "status": "FAILED", "error": "LOCAL_OR_RESPONSE_ERROR"})
        return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--job-dir", type=Path, required=True)
    parser.add_argument("--request-id", required=True)
    parser.add_argument("--encounter-id", choices=["E01"], required=True)
    parser.add_argument("--mode", choices=["fixture", "live"], required=True)
    args = parser.parse_args(argv)
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", args.request_id):
        parser.error("Invalid request ID")
    return execute(args.job_dir, args.request_id, args.encounter_id, args.mode)


if __name__ == "__main__":
    sys.exit(main())
