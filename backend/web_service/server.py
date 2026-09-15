"""Bounded HTTP adapter for the existing generation and story services.

Run one process with persistent storage. Jobs survive client disconnects; interrupted
jobs fail on restart rather than silently repeating paid provider requests.
"""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from game_bridge.run import execute
from narrator_agent.service import Service
from utils.common import AppError, ROOT, load_config
from stage_config import STAGES

MAX_BODY = 1500000
ID = re.compile(r'^[A-Za-z0-9_-]{1,100}$')
OPS = {'new', 'event', 'respond', 'guide', 'read_drawing', 'presented', 'voice',
       'transcribe', 'confirm_stay', 'cancel_stay', 'leave', 'checkpoint', 'fork'}

def write(path, data):
    temp = path.with_suffix('.tmp')
    temp.write_text(json.dumps(data, allow_nan=False))
    temp.replace(path)

def require(ok, code='INVALID_REQUEST'):
    if not ok: raise AppError(code, 'The request could not be accepted.')

class Application:
    def __init__(self, directory, generation=execute, story_factory=Service):
        self.directory = Path(directory).resolve()
        self.directory.mkdir(parents=True, exist_ok=True)
        self.generation = generation
        self.story_factory = story_factory
        self.services = {}
        self.lock = threading.RLock()
        self.pool = ThreadPoolExecutor(max_workers=2)
        self.generation_pool = ThreadPoolExecutor(max_workers=2)
        self.capacity = threading.BoundedSemaphore(12)
        self.sessions_per_day = int(os.environ.get('MAX_SESSIONS_PER_DAY', '100'))
        self.jobs_per_day = int(os.environ.get('MAX_GENERATIONS_PER_DAY', '60'))
        self.session_jobs = int(os.environ.get('MAX_GENERATIONS_PER_SESSION', '10'))
        self.session_story = int(os.environ.get('MAX_STORY_REQUESTS_PER_SESSION', '400'))
        for path in self.directory.glob('*/tasks/*/result.json'):
            data = json.loads(path.read_text())
            if data.get('pending'):
                write(path, {'ok': False, 'error': 'SERVER_RESTARTED', 'message': 'The service restarted. Please try again.'})

    def session(self, address):
        with self.lock:
            for record_path in self.directory.glob('*/session.json'):
                record = json.loads(record_path.read_text())
                if time.time() - record['created'] > 172800:
                    self.services.pop(record_path.parent, None)
                    shutil.rmtree(record_path.parent)
            today = time.strftime('%Y-%m-%d', time.gmtime())
            records = [json.loads(p.read_text()) for p in self.directory.glob('*/session.json')]
            require(sum(r['day'] == today for r in records) < self.sessions_per_day, 'RATE_LIMITED')
            address_hash = hashlib.sha256(address.encode()).hexdigest()
            require(sum(r['day'] == today and r['address'] == address_hash for r in records) < 8, 'RATE_LIMITED')
            token = secrets.token_urlsafe(32)
            folder = self.directory / hashlib.sha256(token.encode()).hexdigest()
            folder.mkdir()
            write(folder / 'session.json', {'day': today, 'address': address_hash, 'created': time.time()})
            return {'token': token}

    def owner(self, token):
        require(isinstance(token, str) and 30 <= len(token) <= 100, 'UNAUTHORIZED')
        folder = self.directory / hashlib.sha256(token.encode()).hexdigest()
        require((folder / 'session.json').is_file(), 'UNAUTHORIZED')
        record = json.loads((folder / 'session.json').read_text())
        require(time.time() - record['created'] < 86400, 'UNAUTHORIZED')
        return folder

    def submit(self, token, kind, data):
        folder = self.owner(token)
        require(isinstance(data, dict) and kind in ('generation', 'story'))
        ident = data.get('request_id' if kind == 'generation' else 'input_id')
        require(isinstance(ident, str) and ID.fullmatch(ident))
        digest = hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest()
        task = folder / 'tasks' / (kind + '-' + ident)
        with self.lock:
            if task.exists():
                require((task / 'digest').read_text() == digest, 'CONFLICT')
                return {'id': ident}
            if kind == 'generation':
                stage = data.get('game_stage')
                require(stage in STAGES and data.get('encounter_id') == STAGES[stage]['encounter_id'])
                require(data.get('mode', 'live') == 'live')
                try: drawing = base64.b64decode(data.get('image_base64', ''), validate=True)
                except (ValueError, TypeError): raise AppError('INVALID_REQUEST', 'Invalid image.') from None
                require(drawing.startswith(b'\x89PNG\r\n\x1a\n') and len(drawing) <= 1048576)
                require(len(list((folder / 'tasks').glob('generation-*'))) < self.session_jobs, 'RATE_LIMITED')
                midnight = time.time() - 86400
                require(sum(p.stat().st_mtime > midnight for p in self.directory.glob('*/tasks/generation-*/digest')) < self.jobs_per_day, 'RATE_LIMITED')
            else:
                require(data.get('op') in OPS)
                require(len(list((folder / 'tasks').glob('story-*'))) < self.session_story, 'RATE_LIMITED')
            require(self.capacity.acquire(blocking=False), 'RATE_LIMITED')
            try:
                task.mkdir(parents=True)
                (task / 'digest').write_text(digest)
                write(task / 'result.json', {'pending': True})
                if kind == 'generation':
                    (task / 'request').mkdir()
                    (task / 'request/input.png').write_bytes(drawing)
                pool = self.generation_pool if kind == 'generation' else self.pool
                pool.submit(self.run, folder, task, kind, data)
            except Exception:
                self.capacity.release()
                raise
        return {'id': ident}

    def run(self, folder, task, kind, data):
        try:
            if kind == 'generation':
                self.generation(task, data['request_id'], data['encounter_id'], 'live', data['game_stage'], animation_options=data.get('animation_options'))
                result = json.loads((task / 'status.json').read_text())
                result = self.publish(folder, task, result)
            else:
                with self.lock:
                    if folder not in self.services:
                        self.services[folder] = self.story_factory(folder / 'stories', load_config(ROOT / '.env'))
                    service = self.services[folder]
                request = dict(data)
                request.pop('simulated', None)
                result = {'ok': True, **service.handle(request)}
                result = self.publish(folder, task, result)
            write(task / 'result.json', result)
        except AppError as error:
            write(task / 'result.json', {'ok': False, 'error': error.code, 'message': 'The service could not complete this request. Please try again.'})
        except Exception:
            write(task / 'result.json', {'ok': False, 'error': 'SERVICE_ERROR', 'message': 'The service could not complete this request. Please try again.'})
        finally:
            self.capacity.release()

    def publish(self, folder, task, data):
        result = dict(data)
        for key in list(result):
            if key.endswith('_path'):
                path = Path(str(result.pop(key))).resolve()
                if key not in ('reference_path', 'model_path', 'audio_path'): continue
                require(folder in path.parents and path.is_file())
                require(path.suffix.lower() in ('.png', '.jpg', '.jpeg', '.glb', '.mp3'))
                # Map an opaque asset ID; no local paths or provider URLs reach clients.
                asset = hashlib.sha256(str(path.relative_to(folder)).encode()).hexdigest() + path.suffix.lower()
                with self.lock:
                    assets = folder / 'assets'; assets.mkdir(exist_ok=True)
                    mapping = assets / (asset + '.json')
                    if not mapping.exists(): write(mapping, {'path': str(path.relative_to(folder))})
                result[key.replace('_path', '_asset')] = asset
        return result

    def status(self, token, kind, ident):
        folder = self.owner(token)
        require(kind in ('generation', 'story') and ID.fullmatch(ident))
        task = folder / 'tasks' / (kind + '-' + ident)
        require((task / 'result.json').is_file(), 'NOT_FOUND')
        result = json.loads((task / 'result.json').read_text())
        if kind == 'generation' and result.get('pending') and (task / 'status.json').exists():
            return self.publish(folder, task, json.loads((task / 'status.json').read_text()))
        return result

    def asset(self, token, ident):
        folder = self.owner(token)
        require(re.fullmatch(r'[a-f0-9]{64}\.(png|jpg|jpeg|glb|mp3)', ident))
        mapping = folder / 'assets' / (ident + '.json')
        require(mapping.is_file(), 'NOT_FOUND')
        path = (folder / json.loads(mapping.read_text())['path']).resolve()
        require(folder in path.parents and path.is_file(), 'NOT_FOUND')
        return path


def handler(app, origins):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass  # Never log tokens, bodies, or asset paths.
        def reply(self, code, data):
            body = json.dumps(data).encode()
            self.send_response(code); self.headers_out('application/json', len(body))
            self.end_headers(); self.wfile.write(body)
        def headers_out(self, mime, length):
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(length))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            if self.headers.get('Origin') in origins:
                self.send_header('Access-Control-Allow-Origin', self.headers['Origin'])
                self.send_header('Vary', 'Origin')
        def do_OPTIONS(self):
            if self.headers.get('Origin') not in origins: return self.reply(403, {})
            self.send_response(204)
            self.headers_out('text/plain', 0)
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
            self.end_headers()
        def do_GET(self): self.dispatch(False)
        def do_POST(self): self.dispatch(True)
        def dispatch(self, post):
            try:
                self.connection.settimeout(30)
                if self.path == '/health' and not post: return self.reply(200, {'ready': True})
                require(self.headers.get('Origin') in origins, 'FORBIDDEN')
                if post:
                    size = int(self.headers.get('Content-Length', '0'))
                    require(0 < size <= MAX_BODY)
                    data = json.loads(self.rfile.read(size))
                if self.path == '/api/session' and post:
                    # Render provides the client IP; keep no raw address on disk.
                    address = self.headers.get('X-Forwarded-For', self.client_address[0]).split(',')[-1].strip()
                    return self.reply(201, app.session(address))
                token = self.headers.get('Authorization', '').removeprefix('Bearer ')
                pieces = self.path.strip('/').split('/')
                require(len(pieces) in (2, 3) and pieces[0] == 'api', 'NOT_FOUND')
                kind = pieces[1]
                if post and len(pieces) == 2:
                    return self.reply(202, app.submit(token, kind, data))
                require(not post and len(pieces) == 3, 'NOT_FOUND')
                if kind == 'assets':
                    path = app.asset(token, pieces[2])
                    require(path.stat().st_size <= 100 * 1024 * 1024)
                    self.send_response(200); self.headers_out('application/octet-stream', path.stat().st_size)
                    self.end_headers()
                    with path.open('rb') as source:
                        while chunk := source.read(65536): self.wfile.write(chunk)
                    return
                return self.reply(200, app.status(token, kind, pieces[2]))
            except AppError as error:
                code = {'UNAUTHORIZED': 401, 'FORBIDDEN': 403, 'NOT_FOUND': 404, 'CONFLICT': 409, 'RATE_LIMITED': 429}.get(error.code, 400)
                self.reply(code, {'ok': False, 'error': error.code, 'message': 'The service could not accept this request.'})
            except (ValueError, TypeError, KeyError): self.reply(400, {'ok': False, 'error': 'INVALID_REQUEST'})
            except (BrokenPipeError, ConnectionResetError, TimeoutError): pass
            except Exception: self.reply(500, {'ok': False, 'error': 'SERVICE_ERROR'})
    return Handler

if __name__ == '__main__':
    origins = set(filter(None, os.environ.get('ALLOWED_ORIGINS', '').split(',')))
    if not origins: raise SystemExit('Set ALLOWED_ORIGINS to the exact HTTPS game origin.')
    application = Application(os.environ.get('WEB_DATA_DIR', str(ROOT / 'output/web')))
    server = ThreadingHTTPServer(('0.0.0.0', int(os.environ.get('PORT', '8080'))), handler(application, origins))
    server.serve_forever()
