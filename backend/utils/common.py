"""Shared local configuration and image input for the feature scripts."""

import base64
import os
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, build_opener, urlopen as standard_urlopen

ROOT = Path(__file__).resolve().parents[1]
MAX_IMAGE_BYTES = 1024 * 1024


class NoCredentialRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, new_url):
        # urllib otherwise copies Authorization to the redirected request, even across hosts.
        return None


def provider_urlopen(request, timeout):
    """Keep bearer credentials on the original endpoint; allow ordinary asset redirects."""
    if request.has_header("Authorization") or request.has_header("Xi-api-key"):
        return build_opener(NoCredentialRedirect()).open(request, timeout=timeout)
    return standard_urlopen(request, timeout=timeout)


class AppError(Exception):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code


def load_config(env_file, prefer_file=False):
    """Read literal KEY=value lines; never execute or shell-expand the file."""
    values = {}
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, separator, value = line.partition("=")
            if not separator or key.strip() not in ("OPENAI_API_KEY", "OPENAI_MODEL", "MESHY_API_KEY", "MESHY_MODEL", "NARRATOR_MODEL", "ELEVENLABS_API_KEY", "ELEVENLABS_NARRATOR_VOICE_ID", "ELEVENLABS_OTTER_VOICE_ID", "ELEVENLABS_MODEL", "ELEVENLABS_STT_MODEL"):
                raise AppError("CONFIG_ERROR", "Use only supported KEY=value settings in the env file; see backend/.env.example.")
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            values[key.strip()] = value
    return {
        key: (values.get(key, os.environ.get(key, default)) if prefer_file else os.environ.get(key, values.get(key, default))).strip()
        for key, default in (("OPENAI_API_KEY", ""), ("OPENAI_MODEL", "gpt-4.1-mini"),
                             ("MESHY_API_KEY", ""), ("MESHY_MODEL", "meshy-6"),
                             ("NARRATOR_MODEL", "gpt-5.6-terra"), ("ELEVENLABS_API_KEY", ""),
                             ("ELEVENLABS_NARRATOR_VOICE_ID", ""), ("ELEVENLABS_OTTER_VOICE_ID", ""),
                             ("ELEVENLABS_MODEL", "eleven_multilingual_v2"), ("ELEVENLABS_STT_MODEL", "scribe_v2"))
    }


def image_input(image_path=None, image_url=None):
    if image_url is not None:
        parsed = urlparse(image_url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise AppError("INVALID_INPUT", "Use a public HTTPS image URL without login credentials.")
        return image_url
    with Path(image_path).open("rb") as handle:
        data = handle.read(MAX_IMAGE_BYTES + 1)
    if not data or len(data) > MAX_IMAGE_BYTES:
        raise AppError("INVALID_INPUT", "Choose a nonempty PNG or JPEG at most 1 MiB.")
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        mime = "image/png"
    elif data.startswith(b"\xff\xd8\xff"):
        mime = "image/jpeg"
    else:
        raise AppError("INVALID_INPUT", "The image must be a PNG or JPEG file.")
    return "data:%s;base64,%s" % (mime, base64.b64encode(data).decode("ascii"))
