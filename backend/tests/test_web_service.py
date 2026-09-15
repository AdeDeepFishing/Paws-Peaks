"""Offline checks for session isolation, bounded jobs, and asset transport."""
import base64
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from web_service.server import Application, AppError, write

class WebServiceTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.calls = 0
        def generation(folder, request_id, encounter, mode, stage, **kwargs):
            self.calls += 1
            (folder / 'model.glb').write_bytes(b'glTF')
            write(folder / 'status.json', {'schema_version': 1, 'request_id': request_id,
                  'encounter_id': encounter, 'game_stage': stage, 'status': 'SUCCEEDED',
                  'model_path': str(folder / 'model.glb')})
        self.app = Application(self.tmp.name, generation=generation)
        self.token = self.app.session('local')['token']
    def tearDown(self):
        self.app.pool.shutdown(wait=True)
        self.app.generation_pool.shutdown(wait=True)
        self.tmp.cleanup()
    def drawing(self, ident='example'):
        return {'request_id': ident, 'encounter_id': 'E01', 'game_stage': 'river',
                'image_base64': base64.b64encode(b'\x89PNG\r\n\x1a\nexample').decode()}
    def wait(self, token, kind, ident):
        for _ in range(100):
            result = self.app.status(token, kind, ident)
            if not result.get('pending'): return result
            time.sleep(.01)
        self.fail('Job did not finish')
    def test_generation_idempotence_and_private_assets(self):
        data = self.drawing()
        self.app.submit(self.token, 'generation', data)
        self.app.submit(self.token, 'generation', data)
        result = self.wait(self.token, 'generation', 'example')
        self.assertEqual(self.calls, 1)
        self.assertNotIn('model_path', result)
        asset = result['model_asset']
        self.assertEqual(self.app.asset(self.token, asset).read_bytes(), b'glTF')
        other = self.app.session('other')['token']
        with self.assertRaises(AppError): self.app.asset(other, asset)
        with self.assertRaises(AppError): self.app.status(other, 'generation', 'example')
        data['image_base64'] += 'AAAA'
        with self.assertRaises(AppError): self.app.submit(self.token, 'generation', data)
    def test_invalid_requests_make_no_provider_calls(self):
        for data in [self.drawing('../escape'), {**self.drawing(), 'encounter_id': 'E05'}, {**self.drawing(), 'image_base64': 'not an image'}]:
            with self.assertRaises(AppError): self.app.submit(self.token, 'generation', data)
        self.assertEqual(self.calls, 0)
    def test_generation_budget(self):
        self.app.session_jobs = 1
        self.app.submit(self.token, 'generation', self.drawing())
        with self.assertRaises(AppError): self.app.submit(self.token, 'generation', self.drawing('next'))
    def test_story_runs_are_session_scoped(self):
        self.app.submit(self.token, 'story', {'input_id': 'new', 'op': 'new'})
        first = self.wait(self.token, 'story', 'new')
        self.assertTrue(first['ok'])
        other = self.app.session('other')['token']
        self.app.submit(other, 'story', {'input_id': 'foreign', 'op': 'event', 'run_id': first['state']['run_id'], 'type': 'stage_entered', 'stage': 1})
        second = self.wait(other, 'story', 'foreign')
        self.assertFalse(second['ok'])
    def test_restart_does_not_repeat_pending_job(self):
        folder = self.app.owner(self.token) / 'tasks' / 'generation-interrupted'
        folder.mkdir(parents=True)
        write(folder / 'result.json', {'pending': True})
        second = Application(self.tmp.name)
        try:
            result = second.status(self.token, 'generation', 'interrupted')
            self.assertEqual(result['error'], 'SERVER_RESTARTED')
        finally:
            second.pool.shutdown()
            second.generation_pool.shutdown()
    def test_http_origin_and_authorization(self):
        from http.server import ThreadingHTTPServer
        from threading import Thread
        from urllib.request import Request, urlopen
        from urllib.error import HTTPError
        from web_service.server import handler
        server = ThreadingHTTPServer(('127.0.0.1', 0), handler(self.app, {'https://game.test'}))
        thread = Thread(target=server.serve_forever, daemon=True); thread.start()
        url = 'http://127.0.0.1:' + str(server.server_port)
        try:
            with self.assertRaises(HTTPError) as failure:
                urlopen(Request(url + '/api/session', b'{}', {'Origin': 'https://other.test'}))
            self.assertEqual(failure.exception.code, 403)
            response = urlopen(Request(url + '/api/session', b'{}', {'Origin': 'https://game.test'}))
            self.assertEqual(response.headers['Access-Control-Allow-Origin'], 'https://game.test')
            self.assertIn('token', json.load(response))
            with self.assertRaises(HTTPError) as failure:
                urlopen(Request(url + '/api/story/missing', headers={'Origin': 'https://game.test'}))
            self.assertEqual(failure.exception.code, 401)
        finally:
            server.shutdown(); server.server_close(); thread.join()
