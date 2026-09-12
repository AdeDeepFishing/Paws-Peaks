import json
from pathlib import Path
import shutil
import sys
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
        shutil.copyfile(run.ROOT.parent / 'docs/assets/scene-drawing/bridge-input.png', self.folder / 'input.png')

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
        self.assertEqual(run.execute(self.folder, 'E01-test', 'E01', 'live'), 2)

    def test_failure_does_not_leak_exception(self):
        with patch.object(run, 'image_input', side_effect=ValueError('secret-token')):
            self.assertEqual(run.execute(self.folder, 'failure', 'E01', 'fixture'), 1)
        self.assertEqual(self.status()['status'], 'FAILED')
        self.assertNotIn('secret-token', (self.folder / 'status.json').read_text())

    def test_live_delegates_and_filters_status_fields(self):
        def pipeline(argv, *, output_folder, on_event):
            self.assertEqual(argv, ['--image', str(self.folder / 'input.png')])
            self.assertEqual(output_folder, self.folder / 'artifacts')
            on_event({'stage': 'model', 'status': 'FAILED', 'error': 'POLL_TIMEOUT', 'signed_url': 'secret'})
            return 1
        with patch.object(run.pipeline, 'main', side_effect=pipeline) as provider:
            self.assertEqual(run.execute(self.folder, 'live-test', 'E01', 'live'), 1)
            provider.assert_called_once()
        self.assertEqual(self.status()['error'], 'POLL_TIMEOUT')
        self.assertNotIn('signed_url', self.status())
