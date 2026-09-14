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

    def test_storykeeper_identifies_objects_without_deciding_boss_outcome(self):
        value = {"item": {**ITEM, "type": "UNKNOWN", "name": "Candle", "movable": True, "placement": "drop", "mass_kg": 0.4}}
        with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as transport:
            self.assertEqual(run.interpret('image', CONFIG, game_stage='storykeeper'), value)
        transport.assert_called_once()
        self.assertEqual(run.STAGES['storykeeper']['encounter_id'], 'E05')

    def test_crows_explains_defence_after_object_identification(self):
        value = {'item': {**ITEM, 'name': 'Umbrella', 'type': 'DEFENCE', 'movable': True}}
        with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as http:
            self.assertEqual(run.interpret('image', CONFIG, game_stage='crows'), value)
        prompt = json.loads(http.call_args.args[0].data)['input'][0]['content']
        context = prompt.split('Classification context for step 2 only:', 1)[1]
        self.assertIn('ordinary umbrella', context)
        self.assertIn('shield', context)
        self.assertIn('DEFENCE', context)
        self.assertIn("Do not change its", prompt)
        self.assertIn(run.PALETTE_PROMPT, prompt)
        http.assert_called_once()
        # This meaning is stage-specific; it must not steer river identification.
        with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response({'item': ITEM})).encode())) as river_http:
            run.interpret('image', CONFIG, game_stage='river')
        self.assertNotIn('ordinary umbrella', json.loads(river_http.call_args.args[0].data)['input'][0]['content'])
