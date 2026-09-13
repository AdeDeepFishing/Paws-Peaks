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
