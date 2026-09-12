"""Credential transport regression tests using in-memory HTTP handlers."""

from email.message import Message
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from urllib.request import HTTPSHandler, Request, build_opener
from urllib.response import addinfourl

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import common


class CredentialTests(unittest.TestCase):
    def test_authenticated_redirect_does_not_send_key_to_another_host(self):
        visited = []

        class RedirectingServer(HTTPSHandler):
            def https_open(self, request):
                visited.append(request.full_url)
                headers = Message()
                headers["Location"] = "https://unexpected.example/collect"
                response = addinfourl(io.BytesIO(b""), headers, request.full_url, 302)
                response.msg = "Found"
                return response

        def opener_with_fake_server(handler):
            return build_opener(handler, RedirectingServer())

        request = Request("https://api.openai.com/v1/responses",
                          headers={"Authorization": "Bearer fake-test-key"})
        with patch.object(common, "build_opener", side_effect=opener_with_fake_server):
            with self.assertRaises(HTTPError) as caught:
                common.provider_urlopen(request, timeout=15)
        self.assertEqual(caught.exception.code, 302)
        self.assertEqual(visited, ["https://api.openai.com/v1/responses"])

    def test_asset_requests_use_transport_without_authorization(self):
        request = Request("https://assets.meshy.ai/example/model.glb")
        with patch.object(common, "standard_urlopen", return_value=io.BytesIO(b"asset")) as transport, \
                patch.object(common, "build_opener") as authenticated:
            self.assertEqual(common.provider_urlopen(request, timeout=30).read(), b"asset")
            self.assertFalse(transport.call_args.args[0].has_header("Authorization"))
            authenticated.assert_not_called()


if __name__ == "__main__":
    unittest.main()
