import json
from pathlib import Path
import shutil
import sys
import subprocess
import time
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from game_bridge import run


class GameBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name).resolve()
        (self.folder / 'request').mkdir()
        shutil.copyfile(run.ROOT.parent / 'docs/assets/scene-drawing/bridge-input.png', self.folder / 'request/input.png')

    def status(self):
        return json.loads((self.folder / 'status.json').read_text())


    def test_live_delegates_and_filters_status_fields(self):
        def pipeline(argv, *, output_folder, on_event):
            self.assertEqual(argv, ['--skip-preview', '--image', str(self.folder / 'request/input.png'), '--game-stage', 'river'])
            self.assertEqual(output_folder, self.folder / 'response/artifacts')
            on_event({'stage': 'model', 'status': 'FAILED', 'error': 'POLL_TIMEOUT', 'signed_url': 'secret', 'texture_path': str(output_folder / 'texture.png')})
            return 1
        with patch.object(run.pipeline, 'main', side_effect=pipeline) as provider:
            self.assertEqual(run.execute(self.folder, 'live-test', 'E01', 'live'), 1)
            provider.assert_called_once()
        self.assertEqual(self.status()['error'], 'POLL_TIMEOUT')
        self.assertNotIn('texture_path', self.status())
        self.assertNotIn('signed_url', self.status())
        self.assertNotIn('secret', (self.folder / 'response/results.jsonl').read_text())

    def test_worker_listens_before_requests_and_reuses_process(self):
        worker = subprocess.Popen([sys.executable, str(Path(run.__file__)), '--serve', str(self.folder)])
        self.addCleanup(lambda: worker.poll() is None and worker.kill())
        def wait_for(predicate):
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if predicate():
                    return
                time.sleep(0.02)
            self.fail('Worker response timed out')
        wait_for(lambda: (self.folder / 'worker.json').exists())
        self.assertIsNone(worker.poll())
        for number, (stage, encounter) in enumerate((('river', 'E01'), ('dog', 'E02'))):
            job = self.folder / str(number)
            (job / "request").mkdir(parents=True)
            shutil.copyfile(self.folder / 'request/input.png', job / 'request/input.png')
            run.save_job(job / 'request/request.json', {'request_id': 'test-' + str(number),
                         'encounter_id': encounter, 'game_stage': stage, 'mode': 'fixture'})
            def status():
                return json.loads((job / 'status.json').read_text()) if (job / 'status.json').exists() else {}
            wait_for(lambda: 'item' in status())
            self.assertEqual(status()['status'], 'PENDING')
            wait_for(lambda: 'reference_path' in status())
            self.assertEqual(status()['status'], 'PENDING')
            self.assertTrue(Path(status()['reference_path']).exists())
            wait_for(lambda: status().get('status') == 'SUCCEEDED')
            self.assertIn('item', status())
            self.assertEqual(status()['item']['movable'], stage == 'dog')
            if stage == 'dog':
                self.assertEqual(status()['item']['name'], 'Dog Bone')
                fixture = run.ROOT.parent / 'docs/test-artifacts/stage2-2026-09-13'
                self.assertEqual(Path(status()['model_path']).read_bytes(), (fixture / 'model.glb').read_bytes())
                self.assertEqual(status()['item']['texture_key'], 'bone')
                self.assertEqual(status()['item']['color'], '#E8D9B7')
                self.assertEqual(Path(status()['reference_path']).read_bytes(), (fixture / 'reference.jpg').read_bytes())
            self.assertIn('reference_path', status())
            wait_for(lambda: status().get('pool_checked'))
            self.assertEqual(status()['pool_return_code'], 0)
            self.assertTrue((job / 'request/claimed.json').is_file())
            self.assertTrue((job / 'response/results.jsonl').is_file())
            self.assertLessEqual(status()['request_received_at'], status()['response_received_at'])
            self.assertIsNone(worker.poll())
            completed = status()
            run.save_job(job / 'request/request.json', {'request_id': 'test-' + str(number),
                         'encounter_id': encounter, 'game_stage': stage, 'mode': 'fixture'})
            wait_for(lambda: not (job / 'request/request.json').exists())
            self.assertEqual(status(), completed)
        (self.folder / 'shutdown').touch()
        self.assertEqual(worker.wait(timeout=5), 0)


    def test_mismatched_stage_is_rejected_before_paid_calls(self):
        with patch.object(run.pipeline, 'main') as provider:
            self.assertEqual(run.execute(self.folder, 'bad-stage', 'E01', 'live', 'dog'), 1)
            provider.assert_not_called()
        self.assertEqual(self.status()['error'], 'INVALID_REQUEST')

    def test_otter_options_and_reaction_cross_the_bridge(self):
        options = {"Shrug": "Raises both palms in uncertainty, as if unsure what to do."}
        def pipeline(argv, *, output_folder, on_event, animation_options):
            self.assertEqual(animation_options, options)
            self.assertEqual(argv[-1], "otter")
            on_event({"stage": "reference_image", "status": "PENDING", "reaction": "Shrug", "otter_happy": False, "otter_response": "I am still feeling blue."})
            on_event({"stage": "complete", "status": "SUCCEEDED"})
            return 0
        with patch.object(run.pipeline, "main", side_effect=pipeline):
            self.assertEqual(run.execute(self.folder, "otter-test", "E04", "live", "otter", animation_options=options), 0)
        self.assertEqual(self.status()["reaction"], "Shrug")
        self.assertIs(self.status()["otter_happy"], False)
        self.assertEqual(self.status()["otter_response"], "I am still feeling blue.")
