import base64
import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sketch_to_model import run
from common import AppError


class PipelineTests(unittest.TestCase):
    def test_reference_prompt_preserves_description_and_style(self):
        prompt = run.reference_prompt({"name": "Ladder", "description": "Two rails and rungs."}, "whole object")
        self.assertIn("Two rails and rungs.", prompt)
        self.assertTrue(prompt.startswith("whole object"))

    def run_mock_pipeline(self, description, edit_error=None, preview_error=False):
        with tempfile.TemporaryDirectory() as folder, contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(run, "ROOT", Path(folder)))
            stack.enter_context(patch.object(run, "load_config", return_value={}))
            original = run.DEFAULT_IMAGE.read_bytes()
            data_uri = "data:image/png;base64," + base64.b64encode(original).decode()
            stack.enter_context(patch.object(run, "image_input", side_effect=[data_uri, "edited-image"]))
            stack.enter_context(patch.object(run.Profiler, "finish"))
            interpretation = stack.enter_context(patch.object(run, 'interpret', return_value=description))
            def generate(source, prompt, config, output, model, size):
                self.assertEqual(self.events[-1]['item'], description['item'])
                self.assertEqual(source.read_bytes(), original)
                if edit_error:
                    raise edit_error
                return output / 'reference.jpg'
            reference = stack.enter_context(patch.object(run.openai_edit, 'generate', side_effect=generate))
            create = stack.enter_context(patch.object(run, "create_job"))
            stack.enter_context(patch.object(run, "refresh_job", return_value={"status": "SUCCEEDED"}))
            stack.enter_context(patch.object(run, "download_model", return_value="model.glb"))
            stack.enter_context(patch.object(run, "preview_result", return_value={"preview_error": "PREVIEW_RENDER_FAILED"} if preview_error else {"preview_path": "model.png"}))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            self.events = []
            code = run.main([], on_event=self.events.append)
            interpretation.assert_called_once_with(data_uri, {}, prompt=run.SKETCH_PROMPT, game_stage="river")
            saved = list(Path(folder).glob("output/sketch_to_model/*/input.png"))
            self.assertEqual(len(saved), 1)
            self.assertEqual(saved[0].read_bytes(), original)
            return code, reference, create

    def test_uncertain_stops_before_image_generation(self):
        code, reference, create = self.run_mock_pipeline({"status": "uncertain", "item": None})
        self.assertEqual(code, 1)
        reference.assert_not_called()
        create.assert_not_called()

    def test_edit_failure_never_submits_mesh(self):
        code, reference, create = self.run_mock_pipeline(
            {"status": "recognized", "item": {"name": "Ladder", "description": "Rails"}},
            AppError("OPENAI_IMAGE_ERROR", "failed"))
        self.assertEqual(code, 1)
        self.assertEqual(reference.call_count, 1)
        create.assert_not_called()

    def test_defaults_pass_edited_image_to_untextured_t2(self):
        code, reference, create = self.run_mock_pipeline(
            {"status": "recognized", "item": {"name": "Ladder", "description": "Rails"}})
        self.assertEqual(code, 0)
        self.assertEqual(reference.call_args.args[-1], "816x816")
        self.assertEqual(reference.call_args.args[-2], "gpt-image-2.5-flare")
        payload = create.call_args.args[0]
        self.assertEqual([event["stage"] for event in self.events], ["description", "reference_image", "model", "preview", "complete"])
        self.assertEqual(self.events[1]["item"]["name"], "Ladder")
        self.assertTrue(self.events[2]["reference_path"].endswith("reference.jpg"))
        self.assertEqual(self.events[-1]["model_path"], "model.glb")
        self.assertEqual(self.events[-1]["preview_path"], "model.png")
        self.assertEqual(payload["image_url"], "edited-image")
        self.assertNotIn("input_task_id", payload)
        self.assertEqual(payload["ai_model"], "meshy-t2")
        self.assertEqual(payload["target_polycount"], 1000)
        self.assertFalse(payload["should_texture"])

    def test_failed_task_stops_polling(self):
        with self.assertRaises(AppError):
            run.wait_for_task(lambda: {"status": "FAILED"})

    def test_preview_failure_preserves_successful_model(self):
        code, reference, create = self.run_mock_pipeline(
            {"status": "recognized", "item": {"name": "Ladder", "description": "Rails"}},
            preview_error=True)
        self.assertEqual(code, 0)
        self.assertEqual(create.call_count, 1)
        self.assertEqual(self.events[-1]['status'], 'SUCCEEDED')
        self.assertEqual(self.events[-1]['model_path'], 'model.glb')
        self.assertEqual(self.events[-1]['preview_error'], 'PREVIEW_RENDER_FAILED')
