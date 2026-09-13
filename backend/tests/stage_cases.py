"""Shared offline assertions used by each stage's explicit test cases."""
import io
import json
from pathlib import Path
import sys
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from interpret import run
from stage_config import STAGES, classes_for
from test_interpret import CONFIG, ITEM, provider_response


class StageCases:
    def test_encounter_and_schema(self):
        self.assertEqual(STAGES[self.stage]['stage_number'], self.stage_number)
        self.assertEqual(STAGES[self.stage]['encounter_id'], self.encounter)
        self.assertEqual(classes_for(self.stage), self.classes)
        enum = run.schema_for(self.stage)['properties']['item']['anyOf'][0]['properties']['type']['enum']
        self.assertEqual(enum, list(self.classes))

    def test_recognized_classes_through_mocked_provider(self):
        for kind in self.classes:
            with self.subTest(kind=kind):
                value = {'status': 'recognized', 'item': {**ITEM, 'type': kind}}
                response = io.BytesIO(json.dumps(provider_response(value)).encode())
                with patch.object(run, 'urlopen', return_value=response) as http:
                    self.assertEqual(run.interpret('image', CONFIG, game_stage=self.stage), value)
                http.assert_called_once()
                payload = json.loads(http.call_args.args[0].data)
                enum = payload['text']['format']['schema']['properties']['item']['anyOf'][0]['properties']['type']['enum']
                self.assertEqual(enum, list(self.classes))

    def test_uncertain_drawing(self):
        value = {'status': 'uncertain', 'item': None}
        response = io.BytesIO(json.dumps(provider_response(value)).encode())
        with patch.object(run, 'urlopen', return_value=response):
            self.assertEqual(run.interpret('image', CONFIG, game_stage=self.stage), value)
