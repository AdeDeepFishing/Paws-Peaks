#!/usr/bin/env python3
"""Send a stage sample through sketch-to-model; use --dry-run for no API calls."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sketch_to_model import run as pipeline


SAMPLES = {
    1: ('river', 'stage1/input.png'),
    2: ('dog', 'stage2/input.png'),
    3: ('crows', 'stage3/input.png'),
    4: ('otter', 'stage4/input.png'),
}


class BenchmarkLog:
    """Log client-observed adapter completion, without provider response contents."""
    def __init__(self, path, stage, run_id):
        self.path = path
        self.stage = stage
        self.run_id = run_id
        self.started = time.perf_counter()

    def record(self, event, **fields):
        record = {'event': event, 'timestamp_utc': datetime.now(timezone.utc).isoformat(),
                  'elapsed_ms': round((time.perf_counter() - self.started) * 1000, 3),
                  'game_stage': self.stage, 'run_id': self.run_id, **fields}
        line = json.dumps(record)
        print('BENCHMARK ' + line, file=sys.stderr, flush=True)
        try:
            with self.path.open('a', encoding='utf-8') as output:
                output.write(line + '\n')
        except OSError:
            print('Could not save benchmark event; see stderr.', file=sys.stderr, flush=True)

    def response(self, event):
        self.record('api_response' if event['status'] == 'SUCCEEDED' else 'api_failure',
                    operation=event['operation'], status=event['status'],
                    duration_ms=event['duration_ms'])


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    stages = parser.add_mutually_exclusive_group(required=True)
    for number, (stage, _) in SAMPLES.items():
        stages.add_argument(f'--stage{number}', dest='stage', action='store_const',
                            const=number, help=f'Submit the {stage} sample.')
    parser.add_argument('--dry-run', action='store_true',
                        help='Validate the image and configuration without paid API calls.')
    args = parser.parse_args(argv)
    stage, sample = SAMPLES[args.stage]
    image = Path(__file__).resolve().parent / sample
    request = ['--game-stage', stage, '--image', str(image)]
    if args.dry_run:
        request.append('--dry-run')
        return pipeline.main(request)
    run_id = uuid4().hex
    folder = pipeline.ROOT / 'output/sketch_to_model' / run_id
    folder.mkdir(parents=True)
    log = BenchmarkLog(folder / 'benchmark.jsonl', stage, run_id)
    log.record('run_started')
    code = 1
    try:
        code = pipeline.main(request, output_folder=folder, on_response=log.response)
        return code
    finally:
        log.record('run_finished', status='SUCCEEDED' if code == 0 else 'FAILED', exit_code=code)


if __name__ == '__main__':
    raise SystemExit(main())
