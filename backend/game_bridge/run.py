"""Persistent file-mailbox worker and atomic status adapter for the desktop game."""
import argparse
from concurrent.futures import ThreadPoolExecutor
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
from utils.common import ROOT, AppError, image_input
from model_generation.run import save_job
from sketch_to_model import run as pipeline
from utils.render import preview_result
from stage_config import STAGES, classes_for
from interpret.run import validate_interpretation


def write_status(job_dir, status):
    """Append a timestamped result history and publish the latest snapshot atomically."""
    record = {**status, "updated_at": time.time()}
    response_dir = job_dir / "response"
    response_dir.mkdir(exist_ok=True)
    with (response_dir / "results.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps(record, allow_nan=False) + "\n")
    save_job(job_dir / "status.json", record)


def collect_results(pending):
    """Check completed pool jobs against their persisted status; never resubmit work."""
    for future, (job_dir, identity) in list(pending.items()):
        if not future.done():
            continue
        del pending[future]
        error = None
        try:
            code = future.result()
            if code == 2:  # A duplicate lock belongs to the original job.
                continue
        except Exception:
            code, error = 1, "WORKER_JOB_FAILED"
        status = dict(identity)
        try:
            path = job_dir / "status.json"
            if path.stat().st_size > 65536:
                raise ValueError("Oversized status")
            saved = json.loads(path.read_text())
            if not isinstance(saved, dict) or any(saved.get(k) != v for k, v in identity.items()):
                raise ValueError("Mismatched status")
            status.update(saved)
        except (OSError, ValueError):
            error = error or "MISSING_FINAL_STATUS"
        expected = "SUCCEEDED" if code == 0 else "FAILED"
        if error or status.get("status") != expected:
            status.update(stage="error", status="FAILED", error=error or "INVALID_FINAL_STATUS")
            status["response_received_at"] = time.time()
        status.update(pool_checked=True, pool_return_code=code)
        write_status(job_dir, status)


def generate(job_dir, mode, emit, game_stage):
    response_dir = job_dir / "response"
    if mode == "fixture":
        stage_number = STAGES[game_stage]["stage_number"]
        if stage_number == 1:
            fixture = ROOT.parent / "docs/test-artifacts/sketch-to-model-2026-09-12"
            sample = json.loads((fixture / "description.json").read_text())
            # Project the retained sample onto the current fixed-crossing contract.
            sample["item"] = {key: sample["item"][key] for key in ("name", "description", "type")}
            sample["item"].update(type="BRIDGE", movable=False)
            reference_name = "reference.png"
        elif stage_number == 2:
            fixture = ROOT.parent / "docs/test-artifacts/stage2-2026-09-13"
            # Authored fixture metadata for the retained generated bone assets.
            sample = {"item": {"name": "Dog Bone",
                               "description": "A dog bone that could attract or reward the dog.",
                               "type": "FOOD", "movable": True}}
            reference_name = "reference.jpg"
        else:
            raise AppError("FIXTURE_NOT_AVAILABLE", "No offline sample exists for this stage.")
        item = validate_interpretation({"item": sample["item"]}, game_stage)["item"]
        emit({"stage": "reference_image", "status": "PENDING", "item": item})
        time.sleep(0.4)
        reference = response_dir / reference_name
        shutil.copyfile(fixture / reference_name, reference)
        emit({"stage": "model", "status": "PENDING", "reference_path": str(reference)})
        time.sleep(0.4)
        target = response_dir / "model.glb"
        shutil.copyfile(fixture / "model.glb", target)
        emit({"stage": "preview", "status": "PENDING", "model_path": str(target)})
        preview = preview_result(target)
        emit({"stage": "complete", "status": "SUCCEEDED", "item": item, "model_path": str(target), **preview})
        return 0
    # Provider keys are read only by Python. No keys or signed URLs enter Godot.
    with open(os.devnull, "w") as sink, contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        code = pipeline.main(["--image", str(job_dir / "request/input.png"), "--game-stage", game_stage],
                             output_folder=response_dir / "artifacts", on_event=emit)
    return code



def execute(job_dir, request_id, encounter_id, mode, game_stage="river", *, request_received_at=None):
    job_dir = Path(job_dir).resolve()
    # The caller creates a unique job directory and its immutable request/input.png.
    try:
        # Exclusive creation also prevents concurrent duplicate submissions.
        with (job_dir / "started.lock").open("x"):
            pass
    except FileExistsError:
        return 2  # Never silently start the same paid job twice.
    progress = {"schema_version": 1, "request_id": request_id,
                "encounter_id": encounter_id, "game_stage": game_stage, "mode": mode,
                "input_path": str(job_dir / "request/input.png"),
                "request_received_at": time.time() if request_received_at is None else request_received_at,
                "response_received_at": None}

    def emit(event):
        if (job_dir / "cancel").exists() and event.get("status") != "FAILED":
            raise AppError("CANCELED", "Local request canceled.")
        # Only the explicitly allowed fields enter the game's status channel.
        allowed = {key: event[key] for key in ("stage", "status", "item", "reference_path", "model_path", "preview_path", "preview_error", "error") if key in event}
        progress.update(allowed)
        if event.get("status") in ("SUCCEEDED", "FAILED") or any(
                key in allowed for key in ("item", "reference_path", "model_path", "preview_path", "preview_error")):
            progress["response_received_at"] = time.time()
        write_status(job_dir, progress)

    try:
        emit({"stage": "starting", "status": "PENDING"})
        image_input(job_dir / "request/input.png")
        expected_encounter = STAGES.get(game_stage, {}).get("encounter_id")
        if game_stage not in STAGES or encounter_id != expected_encounter or mode not in ("fixture", "live"):
            raise AppError("INVALID_REQUEST", "Invalid stage, encounter or mode.")
        classes_for(game_stage)
        code = generate(job_dir, mode, emit, game_stage)
        if code and progress.get("status") != "FAILED":
            emit({"stage": "error", "status": "FAILED", "error": "PIPELINE_FAILED"})
        return code
    except AppError as error:
        emit({"stage": "error", "status": "FAILED", "error": error.code})
        return 1
    except Exception:
        # Never forward raw exceptions, paths from providers, or credentials to UI.
        emit({"stage": "error", "status": "FAILED", "error": "LOCAL_OR_RESPONSE_ERROR"})
        return 1


def serve(worker_dir):
    """Consume atomically published request.json mailboxes continuously; run generation serially without retries.

    A private directory belongs to one game session. Completed request files are
    claimed before execution; restarting a worker never replays claimed work.
    """
    worker_dir = Path(worker_dir).resolve()
    worker_dir.mkdir(parents=True, exist_ok=True)
    save_job(worker_dir / "worker.json", {"status": "READY", "pid": os.getpid()})
    pending = {}
    with ThreadPoolExecutor(max_workers=1) as executor:
        while not (worker_dir / "shutdown").exists():
            for request_path in sorted(worker_dir.glob("*/request/request.json")):
                claimed = request_path.with_name("claimed.json")
                job_dir = request_path.parent.parent
                request_received_at = time.time()
                try:
                    request_path.replace(claimed)
                    if claimed.stat().st_size > 4096:
                        raise ValueError("Oversized request")
                    value = json.loads(claimed.read_text())
                    request_id = value["request_id"]
                    if (not isinstance(request_id, str)
                            or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", request_id)
                            or not isinstance(value.get("game_stage"), str)
                            or value.get("mode") not in ("fixture", "live")):
                        raise ValueError("Invalid request")
                    if (job_dir / "started.lock").exists() or any(
                            pending_job == job_dir for pending_job, _ in pending.values()):
                        continue  # A duplicate must not replace the original response with receipt status.
                    identity = {"schema_version": 1, "request_received_at": request_received_at, **{k: value.get(k) for k in
                                ("request_id", "encounter_id", "game_stage", "mode")}}
                    # Publish receipt before queueing, even while another request is running.
                    write_status(job_dir, {**identity, "stage": "starting", "status": "PENDING",
                                           "input_path": str(job_dir / "request/input.png"),
                                           "response_received_at": None})
                    future = executor.submit(execute, job_dir, request_id, value.get("encounter_id"),
                                             value["mode"], value["game_stage"], request_received_at=request_received_at)
                    pending[future] = (job_dir, identity)
                except (OSError, ValueError, KeyError, TypeError):
                    write_status(job_dir, {
                        "schema_version": 1, "status": "FAILED", "error": "INVALID_REQUEST",
                        "request_received_at": request_received_at, "response_received_at": time.time()})
            collect_results(pending)
            time.sleep(0.05)
    collect_results(pending)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serve", type=Path, required=True,
                        help="Listen for requests in a private game-session directory")
    return serve(parser.parse_args(argv).serve)


if __name__ == "__main__":
    sys.exit(main())
