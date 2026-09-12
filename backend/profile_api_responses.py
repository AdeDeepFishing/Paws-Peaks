#!/usr/bin/env python3
"""Call both AI features once and print their responses and elapsed times."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

from common import ROOT


def run_feature(feature, arguments):
    started = time.perf_counter()
    process = subprocess.run(
        [sys.executable, str(ROOT / feature / "run.py"), *arguments, "--profile"],
        capture_output=True, text=True,
    )
    elapsed = round((time.perf_counter() - started) * 1000, 3)
    # Existing feature CLIs sanitize diagnostics and keep detailed profiles on stderr.
    print(process.stderr, end="", file=sys.stderr)
    try:
        result = json.loads(process.stdout)
        if not isinstance(result, dict):
            raise ValueError("Expected an object")
    except ValueError:
        # Never print unexpected raw output, which could contain sensitive data.
        result = {"error": {"code": "INVALID_SCRIPT_OUTPUT"}}
    record = {"feature": feature, "wall_ms": elapsed,
              "exit_code": process.returncode, "result": result}
    print(json.dumps(record, ensure_ascii=False, allow_nan=False), flush=True)
    return process.returncode == 0 and "error" not in result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--image", type=Path, default=ROOT / "samples" / "banana.jpg")
    source.add_argument("--image-url")
    parser.add_argument("--dry-run", action="store_true", help="Validate inputs without API calls.")
    args = parser.parse_args(argv)
    image_args = (["--image-url", args.image_url] if args.image_url
                  else ["--image", str(args.image)])
    if args.dry_run:
        image_args.append("--dry-run")
    # Sequential calls make individual timing easy to compare. Neither call is retried.
    narrative_ok = run_feature("sketch_to_narrative", image_args)
    model_ok = run_feature("image_text_to_3d", ["create", *image_args])
    return 0 if narrative_ok and model_ok else 1


if __name__ == "__main__":
    sys.exit(main())
