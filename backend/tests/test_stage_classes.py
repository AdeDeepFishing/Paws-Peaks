"""Stage classification is chosen and validated entirely by the backend."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_config import STAGES
from interpret import run
from test_interpret import ITEM, CONFIG, provider_response
from utils.common import AppError


class StageClassTests(unittest.TestCase):
    def test_stage_class_is_used_in_prompt_schema_and_validation(self):
        value = {'item': {**ITEM, 'type': 'DOG_DISTRACTION'}}
        with patch.dict(STAGES, {'dog': {'encounter_id': 'E02', 'classes': ('DOG_DISTRACTION', 'UNKNOWN')}}):
            with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as http:
                self.assertEqual(run.interpret('image', CONFIG, game_stage='dog'), value)
            payload = json.loads(http.call_args.args[0].data)
            self.assertIn('DOG_DISTRACTION', payload['input'][0]['content'])
            enum = payload['text']['format']['schema']['properties']['item']['properties']['type']['enum']
            self.assertEqual(enum, ['DOG_DISTRACTION', 'UNKNOWN'])
            with self.assertRaises(AppError):
                run.validate_interpretation(value, 'river')
            with self.assertRaises(AppError):
                run.validate_interpretation({'item': ITEM}, 'dog')
            self.assertNotIn('DOG_DISTRACTION', run.schema_for('river')['properties']['item']['properties']['type']['enum'])
