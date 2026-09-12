"""Offline tests: no API key, network access, or paid calls required."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from sketch_to_narrative import run as app


ITEM = {
    "name": "A little bridge", "description": "A sturdy little bridge with a long adventure ahead.",
    "type": "TOOL", "attack_power": 0, "range": 8.0, "speed": 1.0,
    "durability": 3, "tags": ["LONG_REACH", "STURDY"],
}
CONFIG = {"OPENAI_API_KEY": "fake-key-for-offline-test", "OPENAI_MODEL": "gpt-4.1-mini"}


def provider_response(value):
    return {"status": "completed", "output": [
        {"type": "message", "content": [{"type": "output_text", "text": json.dumps(value)}]},
    ]}


class InterpretTests(unittest.TestCase):
    def test_sample_and_url_inputs(self):
        image = app.image_input(app.ROOT / "samples" / "banana.jpg")
        self.assertTrue(image.startswith("data:image/jpeg;base64,/9j/"))
        url = "https://example.com/drawing.png"
        self.assertEqual(app.image_input(image_url=url), url)
        for url in ["http://example.com/a.png", "file:///tmp/a.png", "https://user:pass@example.com/a.png"]:
            with self.subTest(url=url), self.assertRaises(app.AppError):
                app.image_input(image_url=url)

    def test_empty_wrong_format_and_oversized_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "image.png"
            for data in [b"", b"not an image", b"x" * (app.MAX_IMAGE_BYTES + 1)]:
                path.write_bytes(data)
                with self.subTest(size=len(data)), self.assertRaises(app.AppError):
                    app.image_input(path)

    def test_env_is_literal_and_environment_takes_precedence(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / ".env"
            path.write_text('# Local settings\nOPENAI_API_KEY="$(do-not-execute)"\nOPENAI_MODEL=gpt-4.1-mini\n')
            with patch.dict(os.environ, {}, clear=True):
                self.assertEqual(app.load_config(path)["OPENAI_API_KEY"], "$(do-not-execute)")
            with patch.dict(os.environ, {"OPENAI_API_KEY": "environment-key"}, clear=True):
                self.assertEqual(app.load_config(path)["OPENAI_API_KEY"], "environment-key")

    def test_recognized_and_uncertain(self):
        for value in [{"status": "recognized", "item": ITEM}, {"status": "uncertain", "item": None}]:
            self.assertEqual(app.parse_response(provider_response(value)), value)

    def test_invalid_item_fields(self):
        mutations = [
            ("attack_power", True), ("attack_power", 101), ("durability", 1.5),
            ("range", float("nan")), ("speed", float("inf")), ("range", "8"),
            ("type", "BRIDGE"), ("name", " "), ("name", "x" * 41),
            ("description", "x" * 161), ("tags", []), ("tags", ["EXECUTE"]),
            ("tags", ["OTHER", "STURDY"]), ("tags", ["STURDY", "STURDY"]),
            ("tags", [{}]),
        ]
        for field, value in mutations:
            item = deepcopy(ITEM)
            item[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(app.AppError):
                app.validate_interpretation({"status": "recognized", "item": item})
        for value in [
            {"status": "recognized", "item": None}, {"status": "uncertain", "item": ITEM},
            {"status": "recognized", "item": {}}, {"status": "complete", "item": ITEM},
        ]:
            with self.assertRaises(app.AppError):
                app.validate_interpretation(value)

    def test_refusal_incomplete_and_malformed_response(self):
        for response in [
            {"status": "incomplete", "output": []},
            {"status": "completed", "output": []},
            {"status": "completed", "output": [None]},
            {"status": "completed", "output": [{"type": "message", "content": [{"type": "refusal"}]}]},
            {"status": "completed", "output": [{"type": "message", "content": [{"type": "output_text", "text": "oops"}]}]},
        ]:
            with self.subTest(response=response), self.assertRaises(app.AppError):
                app.parse_response(response)

    def test_one_api_call_and_game_envelope(self):
        body = json.dumps(provider_response({"status": "recognized", "item": ITEM})).encode()
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(app, "urlopen", return_value=io.BytesIO(body)) as transport, \
                patch.object(app, "load_config", return_value=CONFIG), \
                redirect_stdout(stdout), redirect_stderr(stderr):
            self.assertEqual(app.main(["--request-id", "E01-player-submission"]), 0)
        result = json.loads(stdout.getvalue())
        self.assertEqual(result["request_id"], "E01-player-submission")
        self.assertEqual(result["schema_version"], 2)
        self.assertEqual(result["item"], ITEM)
        self.assertNotIn(CONFIG["OPENAI_API_KEY"], stdout.getvalue() + stderr.getvalue())
        transport.assert_called_once()
        request = transport.call_args.args[0]
        self.assertEqual(request.full_url, app.API_URL)
        payload = json.loads(request.data)
        self.assertFalse(payload["store"])
        self.assertTrue(payload["text"]["format"]["strict"])
        self.assertTrue(payload["input"][1]["content"][0]["image_url"].startswith("data:image/jpeg;base64,"))
        self.assertEqual(transport.call_args.kwargs["timeout"], 15)

    def test_provider_errors_are_sanitized_without_retry(self):
        for error in [
            HTTPError(app.API_URL, 401, CONFIG["OPENAI_API_KEY"], {}, None),
            HTTPError(app.API_URL, 429, "quota", {}, None),
            URLError(CONFIG["OPENAI_API_KEY"]), TimeoutError("timeout"),
        ]:
            stdout, stderr = io.StringIO(), io.StringIO()
            with self.subTest(error=type(error).__name__), \
                    patch.object(app, "urlopen", side_effect=error) as transport, \
                    patch.object(app, "load_config", return_value=CONFIG), \
                    redirect_stdout(stdout), redirect_stderr(stderr):
                self.assertEqual(app.main([]), 1)
                self.assertIn("error", json.loads(stdout.getvalue()))
                self.assertNotIn(CONFIG["OPENAI_API_KEY"], stdout.getvalue() + stderr.getvalue())
                transport.assert_called_once()

    def test_dry_run_and_missing_key_never_call_provider(self):
        for args, expected_code in [(["--dry-run"], 0), ([], 1)]:
            with patch.object(app, "load_config", return_value={**CONFIG, "OPENAI_API_KEY": ""}), \
                    patch.object(app, "urlopen") as transport, \
                    redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                self.assertEqual(app.main(args), expected_code)
                transport.assert_not_called()


if __name__ == "__main__":
    unittest.main()
