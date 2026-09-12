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
import profiling
from image_text_to_3d import run as models
from sketch_to_narrative import run as narrative


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

    def test_provider_timestamps_only_use_valid_completed_intervals(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(profiling, "PROFILE_DIR", Path(directory)), redirect_stderr(io.StringIO()):
            for task, expected in [
                ({"created_at": 1000, "started_at": 1500, "finished_at": 4500},
                 {"server_queue_ms": 500, "server_processing_ms": 3000, "server_total_ms": 3500}),
                ({"created_at": 1000, "started_at": 1500, "finished_at": 0}, {"server_queue_ms": 500}),
                ({"created_at": 1000, "started_at": 0, "finished_at": 0}, {}),
                ({"created_at": 1000, "started_at": 500, "finished_at": 0}, {}),
                ({"created_at": True, "started_at": float("nan"), "finished_at": "4500"}, {}),
                ({}, {}),
            ]:
                with self.subTest(task=task):
                    profile = profiling.Profiler(True, "test", "status")
                    profiling.provider_timings(task)
                    report = profile.finish("test")
                    self.assertEqual(report["metrics"], expected)

    def test_disabled_profiling_does_not_write_or_print(self):
        with patch.object(profiling, "PROFILE_DIR") as directory, redirect_stderr(io.StringIO()) as stderr:
            profile = profiling.Profiler(False, "test", "test")
            with profiling.measure("request"):
                profiling.metric("bytes", 10)
            self.assertIsNone(profile.finish("test"))
            directory.mkdir.assert_not_called()
            self.assertEqual(stderr.getvalue(), "")

    def test_report_write_failure_does_not_fail_command(self):
        with patch.object(profiling, "PROFILE_DIR") as directory, redirect_stderr(io.StringIO()) as stderr:
            directory.mkdir.side_effect = OSError("local error")
            profile = profiling.Profiler(True, "test", "test")
            report = profile.finish("SUCCEEDED")
            self.assertEqual(report["outcome"], "SUCCEEDED")
            self.assertIn("PROFILE ", stderr.getvalue())

    def test_narrative_profile_preserves_stdout_and_excludes_credentials_and_image(self):
        body = json.dumps({"status": "completed", "output": [{"type": "message", "content": [
            {"type": "output_text", "text": '{"status":"uncertain","item":null}'}]}]}).encode()
        config = {"OPENAI_API_KEY": "fake-secret-key", "OPENAI_MODEL": "gpt-4.1-mini"}
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(profiling, "PROFILE_DIR", Path(directory)), \
                patch.object(narrative, "load_config", return_value=config), \
                patch.object(narrative, "urlopen", return_value=io.BytesIO(body)) as transport, \
                redirect_stdout(io.StringIO()) as stdout, redirect_stderr(io.StringIO()) as stderr:
            self.assertEqual(narrative.main(["--profile", "--request-id", "E01-test"]), 0)
            self.assertEqual(json.loads(stdout.getvalue()), {
                "schema_version": 2, "request_id": "E01-test", "status": "uncertain", "item": None})
            record = json.loads(next(Path(directory).glob("*.json")).read_text())
            self.assertEqual(record["outcome"], "uncertain")
            self.assertEqual(record["stage_calls"]["openai_request"], 1)
            self.assertEqual(record["metrics"]["response_body_bytes"], len(body))
            for forbidden in [config["OPENAI_API_KEY"], "data:image", "Bearer", "https://"]:
                self.assertNotIn(forbidden, json.dumps(record) + stderr.getvalue())
            transport.assert_called_once()

    def test_profiled_model_status_records_identity_and_provider_time(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job.json"
            path.write_text(json.dumps({"schema_version": 1, "feature": "image_text_to_3d", "provider": "meshy",
                                        "request_id": "E01-test", "task_id": "task-test", "status": "PENDING"}))
            task = {"id": "task-test", "status": "IN_PROGRESS", "created_at": 1000, "started_at": 2000, "finished_at": 0}
            with patch.object(profiling, "PROFILE_DIR", Path(directory) / "profiles"), \
                    patch.object(models, "load_config", return_value={"MESHY_API_KEY": "fake-key"}), \
                    patch.object(models, "urlopen", return_value=io.BytesIO(json.dumps(task).encode())) as transport, \
                    redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(models.main(["status", "--job", str(path), "--profile"]), 0)
                record = json.loads(next((Path(directory) / "profiles").glob("*.json")).read_text())
                self.assertEqual(record["task_id"], "task-test")
                self.assertEqual(record["request_id"], "E01-test")
                self.assertEqual(record["metrics"]["server_queue_ms"], 1000)
                self.assertNotIn("server_processing_ms", record["metrics"])
                self.assertEqual(record["stage_calls"]["meshy_status"], 1)
                self.assertEqual(transport.call_args.args[0].method, "GET")


if __name__ == "__main__":
    unittest.main()
