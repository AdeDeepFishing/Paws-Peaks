"""Offline Meshy job lifecycle checks; no provider credentials or paid calls."""

from contextlib import redirect_stderr, redirect_stdout
import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model_generation import run as app

CONFIG = {"MESHY_API_KEY": "fake-meshy-key", "MESHY_MODEL": "meshy-6"}
ASSET_URL = "https://assets.meshy.ai/example/model.glb?Expires=123"


class ModelTests(unittest.TestCase):
    def test_payload_skips_texture_generation_and_requests_glb(self):
        payload = app.build_payload("https://example.com/banana.jpg", "meshy-6")
        self.assertFalse(payload["should_texture"])
        self.assertNotIn("texture_prompt", payload)
        self.assertNotIn("texture_image_url", payload)
        self.assertNotIn("enable_pbr", payload)
        self.assertEqual(payload["image_url"], "https://example.com/banana.jpg")
        self.assertEqual(payload["target_formats"], ["glb"])
        self.assertTrue(payload["should_remesh"])
        self.assertEqual(payload["target_polycount"], 1000)
        with self.assertRaises(app.AppError):
            app.build_payload("image", "")

    def test_create_preserves_identity_and_refuses_duplicate_job_path(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job.json"
            with patch.object(app, "urlopen", return_value=io.BytesIO(b'{"result":"task-123"}')) as transport:
                payload = app.build_payload("https://example.com/banana.jpg", "meshy-6")
                job = app.create_job(payload, CONFIG, path, "E01-original")
                self.assertEqual(job["task_id"], "task-123")
                self.assertEqual(job["feature"], "model_generation")
                self.assertEqual(json.loads(path.read_text())["request_id"], "E01-original")
                request = transport.call_args.args[0]
                self.assertEqual(request.method, "POST")
                self.assertEqual(request.full_url, app.API_URL)
                self.assertFalse(json.loads(request.data)["should_texture"])
                self.assertNotIn("texture_prompt", json.loads(request.data))
                with self.assertRaises(app.AppError):
                    app.create_job({}, CONFIG, path, "E01-new")
                transport.assert_called_once()

    def test_legacy_job_can_be_refreshed_without_resubmission(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'legacy.json'
            path.write_text(json.dumps({'schema_version': 1, 'feature': 'image_text_to_3d',
                                        'provider': 'meshy', 'request_id': 'original',
                                        'task_id': 'task-123', 'status': 'PENDING'}))
            with patch.object(app, 'api_request', return_value={'id': 'task-123', 'status': 'PENDING'}) as api:
                job = app.refresh_job(path, CONFIG)
            self.assertEqual(job['request_id'], 'original')
            api.assert_called_once_with(CONFIG, task_id='task-123')

    def test_uncertain_submission_is_preserved_and_not_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job.json"
            with patch.object(app, "urlopen", side_effect=TimeoutError()) as transport:
                with self.assertRaises(app.AppError):
                    app.create_job({}, CONFIG, path, "E01-original")
                self.assertEqual(json.loads(path.read_text())["status"], "SUBMISSION_UNKNOWN")
                transport.assert_called_once()

    def test_status_lifecycle_and_wrong_task_rejection(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "job.json"
            with patch.object(app, "api_request", return_value={"result": "task-123"}):
                app.create_job({}, CONFIG, path, "E01-original")
            for status in app.STATUSES:
                task = {"id": "task-123", "status": status, "progress": 50, "model_urls": {"glb": ASSET_URL}}
                with patch.object(app, "api_request", return_value=task) as transport:
                    job = app.refresh_job(path, CONFIG)
                    transport.assert_called_once_with(CONFIG, task_id="task-123")
                    self.assertEqual(job["status"], status)
                    self.assertEqual(job["request_id"], "E01-original")
                    self.assertEqual("glb_url" in job, status == "SUCCEEDED")
            with patch.object(app, "api_request", return_value={"id": "wrong", "status": "SUCCEEDED"}):
                with self.assertRaises(app.AppError):
                    app.refresh_job(path, CONFIG)

    def test_download_header_bounds_and_no_authorization_header(self):
        chunk = b'{"asset":{"version":"2.0"}} '
        chunk += b" " * (-len(chunk) % 4)
        glb = struct.pack("<4sII", b"glTF", 2, 20 + len(chunk)) + struct.pack("<I4s", len(chunk), b"JSON") + chunk
        job = {"status": "SUCCEEDED", "glb_url": ASSET_URL}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "model.glb"
            with patch.object(app, "urlopen", return_value=io.BytesIO(glb)) as transport:
                self.assertEqual(app.download_model(job, path), str(path.resolve()))
                self.assertEqual(path.read_bytes(), glb)
                self.assertFalse(transport.call_args.args[0].has_header("Authorization"))
            with patch.object(app, "urlopen") as transport:
                with self.assertRaises(app.AppError):
                    app.download_model(job, path)
                transport.assert_not_called()
            path.unlink()
            for data in [b"<html>error</html>", glb[:-1]]:
                with patch.object(app, "urlopen", return_value=io.BytesIO(data)):
                    with self.assertRaises(app.AppError):
                        app.download_model(job, path)
                    self.assertFalse(path.exists())
            with patch.object(app, "MAX_MODEL_BYTES", 12), patch.object(app, "urlopen", return_value=io.BytesIO(glb)):
                with self.assertRaises(app.AppError):
                    app.download_model(job, path)

    def test_not_ready_and_untrusted_asset_urls(self):
        with patch.object(app, "urlopen") as transport:
            with self.assertRaises(app.AppError):
                app.download_model({"status": "PENDING"}, Path("unused.glb"))
            for url in ["http://assets.meshy.ai/a.glb", "https://example.com/a.glb", "https://user:pass@assets.meshy.ai/a.glb", None]:
                with self.assertRaises(app.AppError):
                    app.validate_asset_url(url)
            transport.assert_not_called()

    def test_dry_run_and_missing_key_do_not_call_provider(self):
        config = {**CONFIG, "MESHY_API_KEY": ""}
        for suffix, expected in [(["--dry-run"], 0), ([], 1)]:
            with patch.object(app, "load_config", return_value=config), patch.object(app, "urlopen") as transport, \
                    redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(app.main(["create"] + suffix), expected)
                transport.assert_not_called()

    def test_errors_do_not_expose_key_or_provider_body(self):
        error = HTTPError(app.API_URL, 401, CONFIG["MESHY_API_KEY"], {}, io.BytesIO(b"secret provider body"))
        with patch.object(app, "urlopen", side_effect=error):
            with self.assertRaises(app.AppError) as caught:
                app.api_request(CONFIG, task_id="task-123")
            self.assertNotIn(CONFIG["MESHY_API_KEY"], str(caught.exception))
            self.assertNotIn("secret provider body", str(caught.exception))

    def test_status_output_omits_signed_url(self):
        output = io.StringIO()
        job = {"status": "SUCCEEDED", "task_id": "test-task", "glb_url": "https://assets.meshy.ai/model.glb?private-token"}
        with patch.object(app, "load_config", return_value=CONFIG), \
                patch.object(app, "refresh_job", return_value=job), redirect_stdout(output):
            self.assertEqual(app.main(["status", "--job", "unused.json"]), 0)
        self.assertNotIn("private-token", output.getvalue())
        self.assertEqual(json.loads(output.getvalue())["task_id"], "test-task")


if __name__ == "__main__":
    unittest.main()
