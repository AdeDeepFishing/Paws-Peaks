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
from image_edit import run as image_edit
from utils.common import AppError


class ImageEditTests(unittest.TestCase):

    def test_edit_sends_original_and_low_quality_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source = folder / "input.png"
            source.write_bytes(b"\x89PNG\r\n\x1a\noriginal")
            png = b"\x89PNG\r\n\x1a\ntest-png"
            response = io.BytesIO(json.dumps({"data": [{"b64_json": base64.b64encode(png).decode()}]}).encode())
            with patch.object(image_edit, "provider_urlopen", return_value=response) as call:
                result = image_edit.generate(source, "preserve shape", {"OPENAI_API_KEY": "test-key"}, folder)
            request = call.call_args.args[0]
            self.assertIn(source.read_bytes(), request.data)
            self.assertIn(b'\r\n\r\nlow\r\n', request.data)
            self.assertIn(b'816x816', request.data)
            self.assertIn(b'\r\n\r\ntransparent\r\n', request.data)
            self.assertIn(b'\r\n\r\npng\r\n', request.data)
            self.assertNotIn(b'output_compression', request.data)
            self.assertEqual(result.name, 'reference.png')
            self.assertNotIn(b'test-key', request.data)
            self.assertEqual(result.read_bytes(), png)

    def test_http_error_is_sanitized_without_retry(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            source = folder / "input.png"
            source.write_bytes(b"\x89PNG\r\n\x1a\noriginal")
            error = HTTPError('https://api.openai.com/v1/images/edits', 403, 'sensitive', {}, io.BytesIO(b'sensitive'))
            with patch.object(image_edit, "provider_urlopen", side_effect=error) as call:
                with self.assertRaises(AppError) as caught:
                    image_edit.generate(source, 'prompt', {"OPENAI_API_KEY": "test-key"}, folder)
            self.assertNotIn('sensitive', str(caught.exception))
            self.assertIn('403', str(caught.exception))
            self.assertEqual(call.call_count, 1)
