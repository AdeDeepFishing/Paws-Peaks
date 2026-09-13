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
from utils.common import AppError


class PipelineTests(unittest.TestCase):
    def run_mock_pipeline(self, description, edit_error=None, preview_error=False, interpretation_error=None, game_stage="river", animation_options=None):
        with tempfile.TemporaryDirectory() as folder, contextlib.ExitStack() as stack:
            stack.enter_context(patch.object(run, "ROOT", Path(folder)))
            stack.enter_context(patch.object(run, "load_config", return_value={}))
            original = run.DEFAULT_IMAGE.read_bytes()
            data_uri = "data:image/png;base64," + base64.b64encode(original).decode()
            stack.enter_context(patch.object(run, "image_input", side_effect=[data_uri, "edited-image"]))
            stack.enter_context(patch.object(run.Profiler, "finish"))
            interpretation = stack.enter_context(patch.object(
                run.interpret, 'interpret', return_value=description, side_effect=interpretation_error))
            def generate(source, prompt, config, output, model, size):
                self.assertEqual(self.events[-1]['item'], description['item'])
                self.assertEqual(source.read_bytes(), original)
                if edit_error:
                    raise edit_error
                return output / 'reference.png'
            reference = stack.enter_context(patch.object(run.image_edit, 'generate', side_effect=generate))
            create = stack.enter_context(patch.object(run.model_generation, "create_job"))
            stack.enter_context(patch.object(run.model_generation, "refresh_job", return_value={"status": "SUCCEEDED"}))
            stack.enter_context(patch.object(run.model_generation, "download_model", return_value="model.glb"))
            stack.enter_context(patch.object(run, "preview_result", return_value={"preview_error": "PREVIEW_RENDER_FAILED"} if preview_error else {"preview_path": "model.png"}))
            stack.enter_context(contextlib.redirect_stdout(io.StringIO()))
            stack.enter_context(contextlib.redirect_stderr(io.StringIO()))
            self.events = []
            self.responses = []
            output_folder = Path(folder) / 'output/sketch_to_model/test-run'
            output_folder.mkdir(parents=True)
            (output_folder / 'benchmark.jsonl').write_text('')
            code = run.main(["--game-stage", game_stage], output_folder=output_folder, on_event=self.events.append, on_response=self.responses.append, animation_options=animation_options)
            interpretation.assert_called_once_with(data_uri, {}, prompt=run.SKETCH_PROMPT, game_stage=game_stage, **({"animation_options": animation_options} if game_stage == "otter" else {}))
            saved = list(Path(folder).glob("output/sketch_to_model/*/input.png"))
            self.assertEqual(len(saved), 1)
            self.assertEqual(saved[0].read_bytes(), original)
            return code, reference, create

    def test_interpretation_failure_stops_before_generation(self):
        for error_code in ('INVALID_MODEL_OUTPUT', 'SERVICE_UNAVAILABLE'):
            with self.subTest(error=error_code):
                code, reference, create = self.run_mock_pipeline(
                    None, interpretation_error=AppError(error_code, 'failed'))
                self.assertEqual(code, 1)
                reference.assert_not_called()
                create.assert_not_called()
                self.assertEqual(self.events[-1]['error'], error_code)

    def test_edit_failure_never_submits_mesh(self):
        code, reference, create = self.run_mock_pipeline(
            {"item": {"name": "Ladder", "description": "Rails", "texture_key": "wood", "color": "#B88755"}},
            AppError("OPENAI_IMAGE_ERROR", "failed"))
        self.assertEqual(code, 1)
        self.assertEqual(reference.call_count, 1)
        create.assert_not_called()
        self.assertEqual(self.responses[-1]['operation'], 'openai_image_edit')
        self.assertEqual(self.responses[-1]['status'], 'FAILED')

    def test_unknown_item_flows_through_image_edit_and_untextured_t2(self):
        item = {"name": "Chair", "description": "A chair could provide a place to rest.", "type": "UNKNOWN", "movable": True, "texture_key": "wood", "color": "#D9C6A0"}
        code, reference, create = self.run_mock_pipeline({"item": item})
        self.assertEqual(code, 0)
        reference.assert_called_once()
        create.assert_called_once()
        self.assertEqual(self.events[1]['item'], item)
        self.assertEqual(self.events[-1]['item'], item)
        prompt = reference.call_args.args[1]
        self.assertTrue(prompt.startswith(run.STYLE_PROMPT))
        self.assertIn(item['name'], prompt)
        self.assertIn(item['description'], prompt)
        self.assertIn("Material: " + item['texture_key'], prompt)
        self.assertIn("Use " + item['color'] + " as the dominant base color", prompt)
        self.assertNotIn('UNKNOWN', prompt)
        self.assertEqual([r['operation'] for r in self.responses], [
            'openai_interpretation', 'openai_image_edit', 'meshy_submit', 'meshy_status', 'model_download'])
        self.assertTrue(all(r['status'] == 'SUCCEEDED' and r['duration_ms'] >= 0 for r in self.responses))
        self.assertEqual(reference.call_args.args[-1], "816x816")
        self.assertEqual(reference.call_args.args[-2], "gpt-image-2.5-flare")
        payload = create.call_args.args[0]
        self.assertEqual([event["stage"] for event in self.events], ["description", "reference_image", "model", "preview", "complete"])
        self.assertTrue(self.events[2]["reference_path"].endswith("reference.png"))
        self.assertEqual(self.events[-1]["model_path"], "model.glb")
        self.assertEqual(self.events[-1]["preview_path"], "model.png")
        self.assertEqual(payload["image_url"], "edited-image")
        self.assertNotIn("input_task_id", payload)
        self.assertEqual(payload["ai_model"], "meshy-t2")
        self.assertEqual(payload["target_polycount"], 500)
        self.assertFalse(payload["should_texture"])

        self.assertEqual(payload["target_formats"], ["glb"])
        for key in ("texture_prompt", "texture_resolution", "enable_pbr", "texture_image_url"):
            self.assertNotIn(key, payload)

    def test_otter_reaction_survives_generation(self):
        description = {"item": {"name": "Flower", "description": "A flower to enjoy.", "movable": True, "texture_key": "fabric", "color": "#CC8877"}, "reaction": "Cheer_with_Both_Hands"}
        code, _, _ = self.run_mock_pipeline(description, game_stage="otter", animation_options={"Cheer_with_Both_Hands": "Raises both hands overhead in celebration."})
        self.assertEqual(code, 0)
        self.assertEqual(self.events[1]["reaction"], description["reaction"])
        self.assertEqual(self.events[-1]["reaction"], description["reaction"])
