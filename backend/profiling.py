"""Optional elapsed-time profiling without recording credentials or image content."""

from contextlib import contextmanager
from contextvars import ContextVar
import json
import math
import sys
import time
from uuid import uuid4

from common import ROOT

PROFILE_DIR = ROOT / "output" / "profiles"
ACTIVE = ContextVar("ai_performance_profile", default=None)


class Profiler:
    def __init__(self, enabled, feature, operation, request_id=None):
        self.enabled = enabled
        self.run_id = uuid4().hex
        self.feature = feature
        self.operation = operation
        self.request_id = request_id
        self.task_id = None
        self.durations = {}
        self.counts = {}
        self.metrics = {}
        self.started = time.perf_counter()
        self.cpu_started = time.process_time()
        self.token = ACTIVE.set(self if enabled else None)

    def finish(self, outcome):
        elapsed = (time.perf_counter() - self.started) * 1000
        cpu = (time.process_time() - self.cpu_started) * 1000
        ACTIVE.reset(self.token)
        if not self.enabled:
            return None
        record = {
            "profile_version": 1, "run_id": self.run_id, "feature": self.feature,
            "operation": self.operation, "outcome": outcome,
            "request_id": self.request_id, "task_id": self.task_id,
            "command_wall_ms": round(elapsed, 3), "local_cpu_ms": round(cpu, 3),
            "timings_ms": {name: round(value, 3) for name, value in self.durations.items()},
            "stage_calls": self.counts, "metrics": self.metrics,
        }
        download_ms = self.durations.get("model_download", 0)
        if download_ms > 0 and "download_bytes" in self.metrics:
            record["metrics"]["download_mib_per_second"] = round(
                self.metrics["download_bytes"] / (1024 * 1024) / (download_ms / 1000), 3)
        # A profile write failure must never turn a completed paid job into an apparent failure.
        try:
            PROFILE_DIR.mkdir(parents=True, exist_ok=True)
            path = PROFILE_DIR / (self.run_id + ".json")
            with path.open("x", encoding="utf-8") as handle:
                json.dump(record, handle, indent=2, allow_nan=False)
                handle.write("\n")
            print("Profile saved: " + str(path), file=sys.stderr)
        except OSError:
            print("Could not save the profile file; performance data follows on stderr.", file=sys.stderr)
        print("PROFILE " + json.dumps(record, allow_nan=False), file=sys.stderr)
        return record


@contextmanager
def measure(name):
    profile = ACTIVE.get()
    if profile is None:
        yield
        return
    started = time.perf_counter()
    try:
        yield
    finally:
        profile.durations[name] = profile.durations.get(name, 0) + (time.perf_counter() - started) * 1000
        profile.counts[name] = profile.counts.get(name, 0) + 1


def metric(name, value):
    profile = ACTIVE.get()
    if profile is not None and type(value) in (int, float) and math.isfinite(value) and value >= 0:
        profile.metrics[name] = value


def identify(request_id, task_id=None):
    profile = ACTIVE.get()
    if profile is not None:
        profile.request_id = request_id
        profile.task_id = task_id


def provider_timings(task):
    """Derive Meshy durations only from positive, ordered timestamps on its own clock."""
    for label, start_key, end_key in (
        ("server_queue_ms", "created_at", "started_at"),
        ("server_processing_ms", "started_at", "finished_at"),
        ("server_total_ms", "created_at", "finished_at"),
    ):
        start, end = task.get(start_key), task.get(end_key)
        if (type(start) in (int, float) and type(end) in (int, float)
                and math.isfinite(start) and math.isfinite(end) and 0 < start <= end):
            metric(label, end - start)
