import base64
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sketch_to_model import openai_edit
from common import AppError


class ImageEditTests(unittest.TestCase):
    def test_small_size_preserves_low_quality(self):
        settings = openai_edit.edit_settings("whole object", size="816x816")
        self.assertEqual(settings["size"], "816x816")
        self.assertEqual(settings["quality"], "low")
        with self.assertRaises(AppError):
            openai_edit.edit_settings("whole object", size="512x512")

    def test_edit_sends_original_and_low_quality_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source = folder / "input.png"
            source.write_bytes(b"\x89PNG\r\n\x1a\noriginal")
            jpeg = b"\xff\xd8\xfftest-jpeg"
            response = io.BytesIO(json.dumps({"data": [{"b64_json": base64.b64encode(jpeg).decode()}]}).encode())
            with patch.object(openai_edit, "provider_urlopen", return_value=response) as call:
                result = openai_edit.generate(source, "preserve shape", {"OPENAI_API_KEY": "test-key"}, folder)
            request = call.call_args.args[0]
            self.assertIn(source.read_bytes(), request.data)
            self.assertIn(b'\r\n\r\nlow\r\n', request.data)
            self.assertIn(b'816x816', request.data)
            self.assertNotIn(b'test-key', request.data)
            self.assertEqual(result.read_bytes(), jpeg)

    def test_http_error_is_sanitized_without_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source = folder / "input.png"
            source.write_bytes(b"\x89PNG\r\n\x1a\noriginal")
            error = HTTPError('https://api.openai.com/v1/images/edits', 403, 'sensitive', {}, io.BytesIO(b'sensitive'))
            with patch.object(openai_edit, "provider_urlopen", side_effect=error) as call:
                with self.assertRaises(AppError) as caught:
                    openai_edit.generate(source, 'prompt', {"OPENAI_API_KEY": "test-key"}, folder)
            self.assertNotIn('sensitive', str(caught.exception))
            self.assertIn('403', str(caught.exception))
            self.assertEqual(call.call_count, 1)
