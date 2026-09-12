import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sketch_to_model import run
from common import AppError


class PipelineTests(unittest.TestCase):
    def test_image_model_override_preserves_input_and_minimal_options(self):
        payload = run.reference_payload("original", {"name": "Tool", "description": "Rails"}, "style", "nano-banana-2")
        self.assertEqual(payload["ai_model"], "nano-banana-2")
        self.assertEqual(payload["reference_image_urls"], ["original"])
        self.assertFalse(payload["remove_background"])
        self.assertFalse(payload["generate_multi_view"])

    def test_reference_provider_timings_separate_queue_and_processing(self):
        self.assertEqual(run.reference_timings({"created_at": 1000, "started_at": 2000, "finished_at": 5000}),
                         {"queue_ms": 1000, "processing_ms": 3000})
        self.assertEqual(run.reference_timings({"created_at": 2000, "started_at": 1000}), {})

    def test_reference_combines_original_image_description_and_style(self):
        payload = run.reference_payload("original-data", {"name": "Ladder", "description": "Two rails and rungs."}, "style")
        self.assertEqual(payload["reference_image_urls"], ["original-data"])
        self.assertIn("Two rails and rungs.", payload["prompt"])
        self.assertTrue(payload["prompt"].startswith("style"))

    def test_uncertain_stops_before_meshy(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(run, "ROOT", Path(folder)))
            stack.enter_context(patch.object(run, "load_config", return_value={}))
            stack.enter_context(patch.object(run, "image_input", return_value="image"))
            stack.enter_context(patch.object(run, "interpret", return_value={"status": "uncertain", "item": None}))
            stack.enter_context(patch.object(run.Profiler, "finish"))
            generate = stack.enter_context(patch.object(run, "generate_reference"))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            self.assertEqual(run.main([]), 1)
            generate.assert_not_called()

    def test_submission_failure_persists_unknown_without_retry(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "job.json"
            with patch.object(run, "api_request", side_effect=AppError("SERVICE_UNAVAILABLE", "failed")) as call:
                with self.assertRaises(AppError):
                    run.generate_reference({}, {}, path)
            self.assertEqual(call.call_count, 1)
            self.assertEqual(json.loads(path.read_text())["status"], "SUBMISSION_UNKNOWN")

    def test_failed_task_stops_polling(self):
        with self.assertRaises(AppError):
            run.wait_for_task(lambda: {"status": "FAILED"})

    def test_success_passes_reference_task_to_untextured_t2(self):
        with tempfile.TemporaryDirectory() as folder, contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(run, "ROOT", Path(folder)))
            stack.enter_context(patch.object(run, "load_config", return_value={}))
            stack.enter_context(patch.object(run, "image_input", return_value="original"))
            stack.enter_context(patch.object(run, "interpret", return_value={
                "status": "recognized", "item": {"name": "Ladder", "description": "Rails and rungs."}}))
            stack.enter_context(patch.object(run.Profiler, "finish"))
            reference = stack.enter_context(patch.object(run, "generate_reference", return_value=("image-task", Path(folder)/"ref.png")))
            create = stack.enter_context(patch.object(run, "create_job"))
            stack.enter_context(patch.object(run, "refresh_job", return_value={"status": "SUCCEEDED"}))
            stack.enter_context(patch.object(run, "download_model", return_value="model.glb"))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            self.assertEqual(run.main([]), 0)
            self.assertEqual(reference.call_args.args[0]["reference_image_urls"], ["original"])
            payload = create.call_args.args[0]
            self.assertEqual(payload["input_task_id"], "image-task")
            self.assertEqual(payload["ai_model"], "meshy-t2")
            self.assertFalse(payload["should_texture"])
