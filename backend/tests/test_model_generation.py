"""Offline Meshy job lifecycle checks; no provider credentials or paid calls."""

import io
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model_generation import run as app

CONFIG = {"MESHY_API_KEY": "fake-meshy-key", "MESHY_MODEL": "meshy-6"}
ASSET_URL = "https://assets.meshy.ai/example/model.glb?Expires=123"


class ModelTests(unittest.TestCase):

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


if __name__ == "__main__":
    unittest.main()
