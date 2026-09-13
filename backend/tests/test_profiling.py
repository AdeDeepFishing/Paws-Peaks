"""Profiling accuracy, isolation, error handling, and CLI output compatibility."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils import profiling


class ProfilingTests(unittest.TestCase):
    def test_monotonic_durations_and_failed_stage_are_recorded(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(profiling, "PROFILE_DIR", Path(directory)), \
                patch.object(profiling.time, "perf_counter", side_effect=[10, 11, 13, 14]), \
                patch.object(profiling.time, "process_time", side_effect=[1, 1.05]), \
                redirect_stderr(io.StringIO()), redirect_stdout(io.StringIO()) as stdout:
            profile = profiling.Profiler(True, "test", "test", "request-1")
            with self.assertRaises(TimeoutError), profiling.measure("request"):
                raise TimeoutError()
            report = profile.finish("SERVICE_UNAVAILABLE")
            self.assertEqual(report["command_wall_ms"], 4000)
            self.assertEqual(report["local_cpu_ms"], 50)
            self.assertEqual(report["timings_ms"]["request"], 2000)
            self.assertEqual(report["stage_calls"]["request"], 1)
            saved = json.loads(next(Path(directory).glob("*.json")).read_text())
            self.assertEqual(saved, report)
            self.assertEqual(stdout.getvalue(), "")
            self.assertIsNone(profiling.ACTIVE.get())


if __name__ == "__main__":
    unittest.main()
