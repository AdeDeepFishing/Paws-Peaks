#!/usr/bin/env python3
"""Benchmark Meshy on one image; each requested target creates one paid job."""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import time
from uuid import uuid4

from common import AppError, ROOT, image_input, load_config
from image_text_to_3d.run import build_payload, create_job, refresh_job, download_model
from profiling import Profiler


def triangle_count(path):
    data = path.read_bytes()
    length, kind = struct.unpack_from("<I4s", data, 12)
    if kind != b"JSON":
        raise ValueError("Missing GLB JSON chunk")
    document = json.loads(data[20:20 + length])
    total = 0
    for mesh in document["meshes"]:
        for primitive in mesh["primitives"]:
            if primitive.get("mode", 4) != 4:
                raise ValueError("Expected triangle primitives")
            accessor = primitive.get("indices", primitive["attributes"]["POSITION"])
            count = document["accessors"][accessor]["count"]
            if count % 3:
                raise ValueError("Invalid triangle element count")
            total += count // 3
    return total


def benchmark_payload(image, model, texture_prompt=None):
    payload = build_payload(image, model)
    if model == "meshy-t2":
        payload["model_type"] = "smart-topology"
        payload.pop("should_remesh")
        payload.pop("topology")
    if texture_prompt is not None:
        if not texture_prompt.strip() or len(texture_prompt) > 800:
            raise ValueError("Texture prompt must contain 1–800 characters.")
        payload.update(should_texture=True, texture_prompt=texture_prompt,
                       texture_resolution="2k", enable_pbr=False)
    return payload


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--image", type=Path, default=ROOT / "samples/banana.jpg")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--model", choices=("meshy-6", "meshy-6-lite", "meshy-t2"))
    parser.add_argument("--targets", type=int, nargs="+", default=[100, 200, 500, 1000])
    parser.add_argument("--texture-prompt", help="Enable 2K textures with this art-style prompt; omit for geometry only.")
    args = parser.parse_args()
    config = load_config(ROOT / ".env")
    image = image_input(args.image)
    model = args.model or config["MESHY_MODEL"]
    maximum = 15000 if model == "meshy-t2" else 300000
    if len(set(args.targets)) != len(args.targets) or any(not 100 <= n <= maximum for n in args.targets):
        parser.error("Targets must be unique integers between 100 and %d." % maximum)
    try:
        settings = benchmark_payload(image, model, args.texture_prompt)
    except ValueError as error:
        parser.error(str(error))
    if args.dry_run:
        print(json.dumps({"dry_run": True, "targets": args.targets,
                          "model": model, "model_type": settings["model_type"],
                          "should_texture": settings["should_texture"], "image_ready": True}))
        return 0
    folder = ROOT / "output/polygon_benchmarks" / uuid4().hex
    folder.mkdir(parents=True)
    report = {"image_sha256": hashlib.sha256(args.image.read_bytes()).hexdigest(),
              "settings": {k: v for k, v in settings.items() if k != "image_url"},
              "method": "Sequential jobs, one per target, 3-second polling", "results": []}
    for target in args.targets:
        profile = Profiler(True, "image_text_to_3d", "polygon_benchmark")
        row = {"target_faces": target}
        started = time.perf_counter()
        path = folder / (str(target) + ".json")
        print("Starting target %d" % target, flush=True)
        try:
            job = create_job({**settings, "target_polycount": target}, config, path,
                             "benchmark-%d-%s" % (target, folder.name))
            row["submission_s"] = round(time.perf_counter() - started, 3)
            row["task_id"] = job["task_id"]
            deadline = started + 600
            while time.perf_counter() < deadline:
                job = refresh_job(path, config)
                if job["status"] in ("SUCCEEDED", "FAILED", "CANCELED"):
                    break
                time.sleep(3)
            else:
                raise AppError("POLL_TIMEOUT", "Check the saved job later; do not resubmit.")
            row["status"] = job["status"]
            row["observed_ready_s"] = round(time.perf_counter() - started, 3)
            if job["status"] == "SUCCEEDED":
                model = folder / (str(target) + ".glb")
                download_started = time.perf_counter()
                download_model(job, model)
                row["download_s"] = round(time.perf_counter() - download_started, 3)
                row["actual_triangles"] = triangle_count(model)
                row["model_bytes"] = model.stat().st_size
        except AppError as error:
            row["status"] = error.code
        except (OSError, ValueError, KeyError, struct.error):
            row["status"] = "LOCAL_OR_MODEL_ERROR"
        finally:
            record = profile.finish(row.get("status", "INTERRUPTED"))
            row["server_timings_s"] = {key: round(value / 1000, 3)
                for key, value in record["metrics"].items() if key.startswith("server_")}
            report["results"].append(row)
            (folder / "summary.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(row), flush=True)
    print("Summary saved: " + str(folder / "summary.json"), flush=True)
    return 0 if all(row["status"] == "SUCCEEDED" for row in report["results"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
