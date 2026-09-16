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
        context = prompt.split('Scenario context:', 1)[1]
        self.assertIn('ordinary umbrella', context)
        self.assertIn('shield', context)
        self.assertIn('DEFENCE', context)
        self.assertIn("Preserve a clear subject", prompt)
        self.assertIn(run.PALETTE_PROMPT, prompt)
        http.assert_called_once()
        # Bird examples must not leak into the river scenario.
        with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response({'item': ITEM})).encode())) as river_http:
            run.interpret('image', CONFIG, game_stage='river')
        self.assertNotIn('ordinary umbrella', json.loads(river_http.call_args.args[0].data)['input'][0]['content'])


    def test_contextual_examples_exclude_fallback_but_keep_required_classes(self):
        for stage, kind, hint in [('river', 'BRIDGE', 'cross a river'),
                                  ('dog', 'FOOD', 'food or a toy'),
                                  ('crows', 'BOW', 'scare it from a distance'),
                                  ('storykeeper', 'UNKNOWN', 'fears the adventure ending')]:
            value = {'item': {**ITEM, 'type': kind}}
            with self.subTest(stage=stage), patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as http:
                run.interpret('image', CONFIG, game_stage=stage)
                payload = json.loads(http.call_args.args[0].data)
                prompt = payload['input'][0]['content']
                self.assertIn(hint, prompt)
                self.assertNotIn("Do not let the game", prompt)
                examples = [line for line in prompt.splitlines() if line.startswith('Example idea families')]
                self.assertEqual(len(examples), 0 if stage == 'storykeeper' else 1)
                if examples:
                    self.assertNotIn('UNKNOWN', examples[0])
                self.assertIn('UNKNOWN', payload['text']['format']['schema']['properties']['item']['properties']['type']['enum'])
                http.assert_called_once()

    def test_pipeline_prompt_keeps_contextual_guessing_and_otter_preferences(self):
        from interpret.prompts import SKETCH_PROMPT
        value = {'item': {key: item for key, item in ITEM.items() if key != 'type'},
                 'reaction': 'Cheer_with_Both_Hands', 'otter_happy': True,
                 'otter_response': 'A thoughtful gift!'}
        with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as http:
            run.interpret('image', CONFIG, prompt=SKETCH_PROMPT, game_stage='otter')
        payload = json.loads(http.call_args.args[0].data)
        prompt = payload['input'][0]['content']
        self.assertIn('fish and shellfish', prompt)
        self.assertIn('toys and other thoughtful gifts', prompt)
        self.assertIn('scenario as a hint', prompt)
        self.assertIn('wild, whimsical, magical, or hybrid objects', prompt)
        self.assertNotIn('reasonably common object', prompt)
        self.assertNotIn('Example idea families', prompt)
        self.assertNotIn('item.type', prompt)
        self.assertNotIn('type', payload['text']['format']['schema']['properties']['item']['properties'])
        self.assertIn('reaction', payload['text']['format']['schema']['required'])
