#!/usr/bin/env python3
"""Desktop mailbox and optional local-only authoring bench for the same service."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from utils.common import AppError, ROOT, load_config
from narrator_agent.service import Service

MAX_REQUEST = 1500000

def safe_handle(service, data):
    try:
        if data.get("op") in ("respond", "voice"):
            service.config = load_config(ROOT / ".env", prefer_file=True)
        return {"ok": True, **service.handle(data)}
    except AppError as error: return {"ok": False, "error": error.code, "message": str(error)}
    except Exception: return {"ok": False, "error": "SERVICE_ERROR", "message": "The story service could not complete this request."}

def atomic(path, data):
    temp = path.with_suffix(".tmp")
    temp.write_text(json.dumps(data))
    temp.replace(path)

def process_file(service, path):
    result_path = path.with_name("response.json")
    try:
        if path.stat().st_size > MAX_REQUEST: raise ValueError()
        request = json.loads(path.read_text())
        result = safe_handle(service, request)
    except Exception:
        result = {"ok": False, "error": "INVALID_REQUEST", "message": "Invalid story request."}
    atomic(result_path, result)

def mailbox(service, directory, parent_pid=0):
    directory.mkdir(parents=True, exist_ok=True)
    atomic(directory / "ready.json", {"ready": True})
    with ThreadPoolExecutor(max_workers=3) as pool:
        running = set()
        while not (directory / "stop").exists():
            if parent_pid:
                try: os.kill(parent_pid, 0)
                except OSError: break
            running = {job for job in running if not job.done()}
            for path in sorted(directory.glob("*/request.json")):
                if len(running) >= 3: break
                claimed = path.with_name("claimed.json")
                try: path.rename(claimed)
                except FileNotFoundError: continue
                running.add(pool.submit(process_file, service, claimed))
            time.sleep(0.05)

def bench(service, port):
    token = secrets.token_urlsafe(24)
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args): pass
        def reply(self, code, data, content_type="application/json"):
            self.send_response(code)
            self.send_header("Content-Type", content_type)
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(data if isinstance(data, bytes) else json.dumps(data).encode())
        def do_GET(self):
            if self.path != "/": return self.reply(404, {})
            self.reply(200, Path(__file__).with_name("bench.html").read_bytes(), "text/html; charset=utf-8")
        def do_POST(self):
            if self.headers.get("Authorization") != "Bearer " + token: return self.reply(403, {})
            size = int(self.headers.get("Content-Length", 0))
            if not 0 < size <= MAX_REQUEST: return self.reply(413, {})
            try: data = json.loads(self.rfile.read(size))
            except Exception: return self.reply(400, {})
            if data.get("op") == "new": data["simulated"] = True
            result = safe_handle(service, data)
            if data.get("op") == "voice" and result.get("ok"):
                import base64
                result["audio_base64"] = base64.b64encode(Path(result.pop("audio_path")).read_bytes()).decode()
            self.reply(200, result)
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    print("Storykeeper bench: http://127.0.0.1:%d/#%s" % (server.server_port, token), flush=True)
    server.serve_forever()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--serve", type=Path)
    parser.add_argument("--parent-pid", type=int, default=0)
    parser.add_argument("--bench", action="store_true")
    parser.add_argument("--port", type=int, default=8766)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.dry_run:
        print(json.dumps({"ready": True, "provider_calls": 0, "features": ["journal", "referee", "narrator", "speech"]}))
        return
    config = load_config(ROOT / ".env", prefer_file=True)
    service = Service(ROOT / "output/narrator_agent", config)
    if args.serve: mailbox(service, args.serve.resolve(), args.parent_pid)
    elif args.bench: bench(service, args.port)
    else: parser.error("Choose --serve, --bench or --dry-run")

if __name__ == "__main__":
    try: main()
    except AppError as error:
        print(json.dumps({"ok": False, "error": error.code}), flush=True)
        sys.exit(1)
