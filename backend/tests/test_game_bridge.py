from concurrent.futures import Future
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

    def test_fixture_returns_real_glb_without_provider(self):
        with patch.object(run.pipeline, 'main') as provider, patch.object(run.time, 'sleep'):
            self.assertEqual(run.execute(self.folder, 'E01-test', 'E01', 'fixture'), 0)
            provider.assert_not_called()
        status = self.status()
        self.assertEqual(status['request_id'], 'E01-test')
        self.assertEqual(status['encounter_id'], 'E01')
        self.assertEqual(status['status'], 'SUCCEEDED')
        self.assertEqual(Path(status['model_path']).read_bytes()[:4], b'glTF')
        self.assertEqual(status['item']['name'], 'Ladder')
        self.assertEqual(set(status['item']), {'name', 'description', 'type'})
        self.assertEqual(Path(status['input_path']).parent, self.folder / 'request')
        self.assertEqual(Path(status['model_path']).parent, self.folder / 'response')
        self.assertFalse((self.folder / 'results.jsonl').exists())
        self.assertLessEqual(status['request_received_at'], status['response_received_at'])
        self.assertEqual(Path(status['preview_path']).parent, Path(status['model_path']).parent)
        self.assertTrue(Path(status['preview_path']).read_bytes().startswith(b'\x89PNG'))
        self.assertEqual(run.execute(self.folder, 'E01-test', 'E01', 'live'), 2)

    def test_failure_does_not_leak_exception(self):
        with patch.object(run, 'image_input', side_effect=ValueError('secret-token')):
            self.assertEqual(run.execute(self.folder, 'failure', 'E01', 'fixture'), 1)
        self.assertEqual(self.status()['status'], 'FAILED')
        self.assertNotIn('secret-token', (self.folder / 'status.json').read_text())

    def test_live_delegates_and_filters_status_fields(self):
        def pipeline(argv, *, output_folder, on_event):
            self.assertEqual(argv, ['--image', str(self.folder / 'request/input.png'), '--game-stage', 'river'])
            self.assertEqual(output_folder, self.folder / 'response/artifacts')
            on_event({'stage': 'model', 'status': 'FAILED', 'error': 'POLL_TIMEOUT', 'signed_url': 'secret'})
            return 1
        with patch.object(run.pipeline, 'main', side_effect=pipeline) as provider:
            self.assertEqual(run.execute(self.folder, 'live-test', 'E01', 'live'), 1)
            provider.assert_called_once()
        self.assertEqual(self.status()['error'], 'POLL_TIMEOUT')
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
        for number in range(2):
            job = self.folder / str(number)
            (job / "request").mkdir(parents=True)
            shutil.copyfile(self.folder / 'request/input.png', job / 'request/input.png')
            run.save_job(job / 'request/request.json', {'request_id': 'test-' + str(number),
                         'encounter_id': 'E01', 'game_stage': 'river', 'mode': 'fixture'})
            def status():
                return json.loads((job / 'status.json').read_text()) if (job / 'status.json').exists() else {}
            wait_for(lambda: 'item' in status())
            self.assertEqual(status()['status'], 'PENDING')
            wait_for(lambda: 'reference_path' in status())
            self.assertEqual(status()['status'], 'PENDING')
            self.assertTrue(Path(status()['reference_path']).exists())
            wait_for(lambda: status().get('status') == 'SUCCEEDED')
            self.assertIn('item', status())
            self.assertIn('reference_path', status())
            wait_for(lambda: status().get('pool_checked'))
            self.assertEqual(status()['pool_return_code'], 0)
            self.assertTrue((job / 'request/claimed.json').is_file())
            self.assertTrue((job / 'response/results.jsonl').is_file())
            self.assertLessEqual(status()['request_received_at'], status()['response_received_at'])
            self.assertIsNone(worker.poll())
            completed = status()
            run.save_job(job / 'request/request.json', {'request_id': 'test-' + str(number),
                         'encounter_id': 'E01', 'game_stage': 'river', 'mode': 'fixture'})
            wait_for(lambda: not (job / 'request/request.json').exists())
            self.assertEqual(status(), completed)
        (self.folder / 'shutdown').touch()
        self.assertEqual(worker.wait(timeout=5), 0)

    def test_cancel_keeps_partial_results_and_skips_later_stage(self):
        def pipeline(argv, *, output_folder, on_event):
            on_event({'stage': 'reference_image', 'status': 'PENDING', 'item': {'name': 'Ladder'}})
            (self.folder / 'cancel').touch()
            on_event({'stage': 'model', 'status': 'PENDING'})
            self.fail('Canceled request advanced to model generation')
        with patch.object(run.pipeline, 'main', side_effect=pipeline):
            self.assertEqual(run.execute(self.folder, 'cancel', 'E01', 'live'), 1)
        self.assertEqual(self.status()['error'], 'CANCELED')
        self.assertEqual(self.status()['item']['name'], 'Ladder')

    def test_other_stages_do_not_use_river_fixture(self):
        for stage, encounter in [('dog', 'E02'), ('crows', 'E03'), ('otter', 'E04')]:
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as folder:
                job = Path(folder)
                (job / "request").mkdir()
                shutil.copyfile(self.folder / 'request/input.png', job / 'request/input.png')
                with patch.object(run.pipeline, 'main') as provider:
                    self.assertEqual(run.execute(job, 'stage-test', encounter, 'fixture', stage), 1)
                    provider.assert_not_called()
                status = json.loads((job / 'status.json').read_text())
                self.assertEqual(status['game_stage'], stage)
                self.assertEqual(status['error'], 'FIXTURE_NOT_AVAILABLE')

    def test_mismatched_stage_is_rejected_before_paid_calls(self):
        with patch.object(run.pipeline, 'main') as provider:
            self.assertEqual(run.execute(self.folder, 'bad-stage', 'E01', 'live', 'dog'), 1)
            provider.assert_not_called()
        self.assertEqual(self.status()['error'], 'INVALID_REQUEST')

    def test_dog_uses_shared_pipeline_with_its_stage_label(self):
        def pipeline(argv, *, output_folder, on_event):
            self.assertEqual(argv[-2:], ['--game-stage', 'dog'])
            on_event({'stage': 'complete', 'status': 'SUCCEEDED'})
            return 0
        with patch.object(run.pipeline, 'main', side_effect=pipeline) as provider:
            self.assertEqual(run.execute(self.folder, 'dog-test', 'E02', 'live', 'dog'), 0)
            provider.assert_called_once()
        self.assertEqual(self.status()['game_stage'], 'dog')

    def test_result_history_retains_image_paths_and_filters_private_fields(self):
        with patch.object(run.time, 'sleep'):
            self.assertEqual(run.execute(self.folder, 'history', 'E01', 'fixture'), 0)
        records = [json.loads(line) for line in (self.folder / 'response/results.jsonl').read_text().splitlines()]
        self.assertEqual([r['stage'] for r in records], ['starting', 'reference_image', 'model', 'preview', 'complete'])
        self.assertTrue(all(r['request_id'] == 'history' and 'updated_at' in r for r in records))
        self.assertEqual(records[-1], self.status())
        for key in ('input_path', 'reference_path', 'model_path', 'preview_path'):
            self.assertTrue(Path(records[-1][key]).is_file())

    def test_arrival_times_track_results_and_survive_pool_check(self):
        with patch.object(run.time, 'time', return_value=100.0) as clock:
            def pipeline(argv, *, output_folder, on_event):
                self.assertIsNone(self.status()['response_received_at'])
                clock.return_value = 110.0
                on_event({'stage': 'reference_image', 'status': 'PENDING', 'item': {'name': 'Bridge'}})
                self.assertEqual(self.status()['response_received_at'], 110.0)
                clock.return_value = 120.0
                on_event({'stage': 'complete', 'status': 'SUCCEEDED'})
                return 0
            with patch.object(run.pipeline, 'main', side_effect=pipeline):
                self.assertEqual(run.execute(self.folder, 'timing', 'E01', 'live', request_received_at=90.0), 0)
            identity = {key: self.status()[key] for key in
                        ('schema_version', 'request_id', 'encounter_id', 'game_stage', 'mode', 'request_received_at')}
            future = Future()
            future.set_result(0)
            clock.return_value = 130.0
            run.collect_results({future: (self.folder, identity)})
        self.assertEqual(self.status()['request_received_at'], 90.0)
        self.assertEqual(self.status()['response_received_at'], 120.0)
        self.assertEqual(self.status()['updated_at'], 130.0)

    def test_pool_exception_is_logged_without_private_exception_text(self):
        future = Future()
        future.set_exception(RuntimeError('private-provider-token'))
        identity = {'schema_version': 1, 'request_id': 'pool-error', 'encounter_id': 'E01',
                    'game_stage': 'river', 'mode': 'live'}
        pending = {future: (self.folder, identity)}
        run.collect_results(pending)
        self.assertFalse(pending)
        self.assertEqual(self.status()['error'], 'WORKER_JOB_FAILED')
        self.assertTrue(self.status()['pool_checked'])
        self.assertNotIn('private-provider-token', (self.folder / 'response/results.jsonl').read_text())

    def test_pool_success_without_final_status_is_failure(self):
        future = Future()
        future.set_result(0)
        identity = {'schema_version': 1, 'request_id': 'missing', 'encounter_id': 'E01',
                    'game_stage': 'river', 'mode': 'live'}
        run.write_status(self.folder, {**identity, 'stage': 'model', 'status': 'PENDING',
                                     'reference_path': str(self.folder / 'reference.jpg')})
        run.collect_results({future: (self.folder, identity)})
        self.assertEqual(self.status()['status'], 'FAILED')
        self.assertEqual(self.status()['error'], 'INVALID_FINAL_STATUS')
        self.assertIn('reference_path', self.status())
