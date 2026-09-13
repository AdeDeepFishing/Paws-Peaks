"""Offline tests: no API key, network access, or paid calls required."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from urllib.error import HTTPError, URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from interpret import run as app


ITEM = {
    "name": "A little bridge", "description": "A sturdy little bridge with a long adventure ahead.",
    "type": "BRIDGE", "movable": False, "texture_key": "plain", "color": "#D9C6A0",
}
CONFIG = {"OPENAI_API_KEY": "fake-key-for-offline-test", "OPENAI_MODEL": "gpt-4.1-mini"}


def provider_response(value):
    return {"status": "completed", "output": [
        {"type": "message", "content": [{"type": "output_text", "text": json.dumps(value)}]},
    ]}


class InterpretTests(unittest.TestCase):


    def test_invalid_item_fields(self):
        mutations = [
            ("texture_key", "../wood"), ("texture_key", "unknown_material"), ("color", "brown"), ("color", "#12345G"), ("color", "#12345678"), ("movable", "true"), ("movable", 1), ("type", "SWORD"), ("type", None), ("name", " "), ("name", "x" * 41),
            ("description", "x" * 161), ("description", None),
        ]
        for field, value in mutations:
            item = deepcopy(ITEM)
            item[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(app.AppError):
                app.validate_interpretation({"item": item})
        for value in [
            {"item": None}, {"item": {}}, {"status": "recognized", "item": ITEM},
            {"item": {key: value for key, value in ITEM.items() if key != "movable"}},
        ]:
            with self.assertRaises(app.AppError):
                app.validate_interpretation(value)


    def test_one_api_call_and_game_envelope(self):
        body = json.dumps(provider_response({"item": ITEM})).encode()
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.object(app, "urlopen", return_value=io.BytesIO(body)) as transport, \
                patch.object(app, "load_config", return_value=CONFIG), \
                redirect_stdout(stdout), redirect_stderr(stderr):
            self.assertEqual(app.main(["--request-id", "E01-player-submission"]), 0)
        result = json.loads(stdout.getvalue())
        self.assertEqual(result["request_id"], "E01-player-submission")
        self.assertEqual(result["schema_version"], 2)
        self.assertEqual(result["item"], ITEM)
        self.assertNotIn("status", result)
        self.assertNotIn(CONFIG["OPENAI_API_KEY"], stdout.getvalue() + stderr.getvalue())
        transport.assert_called_once()
        request = transport.call_args.args[0]
        self.assertEqual(request.full_url, app.API_URL)
        payload = json.loads(request.data)
        self.assertFalse(payload["store"])
        props = payload["text"]["format"]["schema"]["properties"]["item"]["properties"]
        self.assertEqual(props["texture_key"]["enum"], app.TEXTURE_KEYS)
        self.assertEqual(len(app.TEXTURE_KEYS), 16)
        for key in app.TEXTURE_KEYS:
            self.assertIn(key, payload["input"][0]["content"])
            self.assertTrue((app.ROOT.parent / "3d_game/assets/materials" / (key + ".png")).is_file())
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


if __name__ == "__main__":
    unittest.main()
