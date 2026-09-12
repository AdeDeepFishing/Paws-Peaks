"""Stage classification is chosen and validated entirely by the backend."""
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_config import STAGES, classes_for
from sketch_to_narrative import run
from test_sketch_to_narrative import ITEM, CONFIG, provider_response
from common import AppError


class StageClassTests(unittest.TestCase):
    def test_stage_class_is_used_in_prompt_schema_and_validation(self):
        value = {'status': 'recognized', 'item': {**ITEM, 'type': 'DOG_DISTRACTION'}}
        with patch.dict(STAGES, {'dog': {'encounter_id': 'E02', 'classes': ('DOG_DISTRACTION',)}}):
            with patch.object(run, 'urlopen', return_value=io.BytesIO(json.dumps(provider_response(value)).encode())) as http:
                self.assertEqual(run.interpret('image', CONFIG, game_stage='dog'), value)
            payload = json.loads(http.call_args.args[0].data)
            self.assertIn('DOG_DISTRACTION', payload['input'][0]['content'])
            enum = payload['text']['format']['schema']['properties']['item']['anyOf'][0]['properties']['type']['enum']
            self.assertEqual(enum, ['DOG_DISTRACTION'])
            with self.assertRaises(AppError):
                run.validate_interpretation(value, 'river')
            with self.assertRaises(AppError):
                run.validate_interpretation({'status': 'recognized', 'item': ITEM}, 'dog')
            self.assertNotIn('DOG_DISTRACTION', run.schema_for('river')['properties']['item']['anyOf'][0]['properties']['type']['enum'])

    def test_unconfigured_stage_fails_without_network(self):
        with patch.dict(STAGES, {'otter': {'encounter_id': 'E04', 'classes': None}}), patch.object(run, 'urlopen') as http:
            with self.assertRaises(AppError) as error:
                run.interpret('image', CONFIG, game_stage='otter')
            self.assertEqual(error.exception.code, 'STAGE_NOT_CONFIGURED')
            http.assert_not_called()

    def test_invalid_class_configuration(self):
        for classes in [('TOOL', 'TOOL'), ('',), 'TOOL']:
            with self.subTest(classes=classes), patch.dict(STAGES, {'dog': {'encounter_id': 'E02', 'classes': classes}}):
                with self.assertRaises(AppError):
                    classes_for('dog')

    def test_all_confirmed_sets_and_cross_stage_rejection(self):
        expected = {
            'river': ('BRIDGE', 'BOAT', 'UNKNOWN'),
            'dog': ('FOOD', 'TOY', 'WEAPON', 'UNKNOWN'),
            'crows': ('BOW', 'MAGIC', 'UNKNOWN'),
            'otter': ('GIFT', 'TOOL', 'UNKNOWN'),
        }
        all_classes = set().union(*expected.values())
        for stage, classes in expected.items():
            with self.subTest(stage=stage):
                self.assertEqual(classes_for(stage), classes)
                enum = run.schema_for(stage)['properties']['item']['anyOf'][0]['properties']['type']['enum']
                self.assertEqual(enum, list(classes))
            for kind in all_classes:
                value = {'status': 'recognized', 'item': {**ITEM, 'type': kind}}
                with self.subTest(stage=stage, kind=kind):
                    if kind in classes:
                        self.assertEqual(run.validate_interpretation(value, stage), value)
                    else:
                        with self.assertRaises(AppError):
                            run.validate_interpretation(value, stage)
