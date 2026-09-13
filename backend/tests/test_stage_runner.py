"""Verify sample routing without sending provider requests."""
from contextlib import redirect_stderr
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import stage_test
from utils.common import image_input


class StageRunnerTests(unittest.TestCase):
    def test_each_stage_routes_its_image_and_propagates_result(self):
        for number, stage, filename in [
            (1, 'river', 'input.png'), (2, 'dog', 'input.png'),
            (3, 'crows', 'input.png'), (4, 'otter', 'input.png'),
        ]:
            image = Path(__file__).resolve().parent / f'stage{number}' / filename
            with self.subTest(stage=stage):
                self.assertTrue(image_input(image).startswith('data:image/'))
                for dry_run in (False, True):
                    args = [f'--stage{number}'] + (['--dry-run'] if dry_run else [])
                    expected = ['--game-stage', stage, '--image', str(image)]
                    if dry_run:
                        expected.append('--dry-run')
                    with tempfile.TemporaryDirectory() as folder, redirect_stderr(io.StringIO()), patch.object(stage_test.pipeline, 'ROOT', Path(folder)), patch.object(stage_test.pipeline, 'main', return_value=7) as pipeline:
                        self.assertEqual(stage_test.main(args), 7)
                        self.assertEqual(pipeline.call_args.args, (expected,))
                        pipeline.assert_called_once()
                        if dry_run:
                            self.assertEqual(pipeline.call_args.kwargs, {})
                        else:
                            output = pipeline.call_args.kwargs['output_folder']
                            records = [json.loads(line) for line in (output / 'benchmark.jsonl').read_text().splitlines()]
                            self.assertEqual([r['event'] for r in records], ['run_started', 'run_finished'])
                            self.assertEqual(records[-1]['exit_code'], 7)

    def test_response_log_has_timing_and_excludes_response_content(self):
        with tempfile.TemporaryDirectory() as folder, redirect_stderr(io.StringIO()):
            path = Path(folder) / 'benchmark.jsonl'
            with patch.object(stage_test.time, 'perf_counter', side_effect=[10, 10.25]):
                log = stage_test.BenchmarkLog(path, 'dog', 'test-run')
                log.response({'operation': 'openai_interpretation', 'status': 'SUCCEEDED',
                              'duration_ms': 200, 'response_body': 'private-response'})
            record = json.loads(path.read_text())
            self.assertEqual(record['elapsed_ms'], 250)
            self.assertEqual(record['duration_ms'], 200)
            self.assertEqual(record['event'], 'api_response')
            self.assertIn('+00:00', record['timestamp_utc'])
            self.assertNotIn('private-response', path.read_text())

    def test_log_write_failure_does_not_fail_completed_call(self):
        with redirect_stderr(io.StringIO()), patch.object(Path, 'open', side_effect=OSError):
            stage_test.BenchmarkLog(Path('unused'), 'dog', 'test-run').response(
                {'operation': 'meshy_submit', 'status': 'FAILED', 'duration_ms': 10})

    def test_requires_exactly_one_known_stage(self):
        for args in ([], ['--stage1', '--stage2'], ['--stage5']):
            with self.subTest(args=args), redirect_stderr(io.StringIO()):
                with patch.object(stage_test.pipeline, 'main') as pipeline:
                    with self.assertRaises(SystemExit) as error:
                        stage_test.main(args)
                    self.assertEqual(error.exception.code, 2)
                    pipeline.assert_not_called()
