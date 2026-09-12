import contextlib
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import profile_api_responses as runner


class ResponseProfilingTests(unittest.TestCase):
    def test_both_calls_run_once_even_when_first_fails(self):
        responses = [subprocess.CompletedProcess([], 1, '{"error":{"code":"RATE_LIMITED"}}', ''),
                     subprocess.CompletedProcess([], 0, '{"task_id":"test-task","status":"PENDING"}', '')]
        output = io.StringIO()
        with patch.object(runner.subprocess, "run", side_effect=responses) as run:
            with contextlib.redirect_stdout(output):
                self.assertEqual(runner.main([]), 1)
        self.assertEqual(run.call_count, 2)
        records = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertEqual(records[1]["result"]["task_id"], "test-task")
        self.assertTrue(all(record["wall_ms"] >= 0 for record in records))

    def test_dry_run_forwarded_to_both_features(self):
        with patch.object(runner, "run_feature", return_value=True) as run:
            self.assertEqual(runner.main(["--dry-run", "--image-url", "https://example.com/image.png"]), 0)
        for call in run.call_args_list:
            self.assertIn("--dry-run", call.args[1])
            self.assertIn("https://example.com/image.png", call.args[1])

    def test_unexpected_stdout_is_not_disclosed(self):
        output = io.StringIO()
        response = subprocess.CompletedProcess([], 0, 'sensitive unexpected output', '')
        with patch.object(runner.subprocess, "run", return_value=response):
            with contextlib.redirect_stdout(output):
                self.assertFalse(runner.run_feature("sketch_to_narrative", []))
        self.assertNotIn('sensitive unexpected output', output.getvalue())


if __name__ == "__main__":
    unittest.main()
