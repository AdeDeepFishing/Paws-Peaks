"""One low-quality OpenAI image edit, with bounded reads and sanitized errors."""

import base64
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request
from uuid import uuid4

from utils.common import AppError, image_input, provider_urlopen
from utils.profiling import measure, metric

DEFAULT_MODEL = "gpt-image-2.5-flare"
DEFAULT_SIZE = "816x816"


def edit_settings(prompt, model=DEFAULT_MODEL, size=DEFAULT_SIZE):
    if size not in ("816x816", "1024x1024"):
        raise AppError("INVALID_INPUT", "Choose 816x816 or 1024x1024 for the reference image.")
    return {"model": model, "prompt": prompt, "n": "1", "size": size,
            "quality": "low", "output_format": "png",
            "background": "transparent"}


def generate(image_path, prompt, config, folder, model=DEFAULT_MODEL, size=DEFAULT_SIZE):
    key = config["OPENAI_API_KEY"]
    if not key or not key.isascii() or any(c.isspace() for c in key):
        raise AppError("CONFIG_ERROR", "Configure a valid OPENAI_API_KEY.")
    # Reuse the bounded input validation before building multipart data.
    data_uri = image_input(image_path)
    mime = data_uri.split(";", 1)[0][5:]
    image = base64.b64decode(data_uri.split(",", 1)[1], validate=True)
    boundary = "paws" + uuid4().hex
    parts = []
    settings = edit_settings(prompt, model, size)
    for name, value in settings.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" %
                      (boundary, name, value)).encode())
    parts.append(("--%s\r\nContent-Disposition: form-data; name=\"image\"; filename=\"sketch\"\r\n"
                  "Content-Type: %s\r\n\r\n" % (boundary, mime)).encode() + image + b"\r\n")
    parts.append(("--%s--\r\n" % boundary).encode())
    request = Request("https://api.openai.com/v1/images/edits", data=b"".join(parts),
                      headers={"Authorization": "Bearer " + key,
                               "Content-Type": "multipart/form-data; boundary=" + boundary})
    (folder / "image_edit_settings.json").write_text(json.dumps(settings, indent=2) + "\n")
    metric("openai_edit_request_bytes", len(request.data))
    try:
        with measure("openai_image_edit"):
            with provider_urlopen(request, timeout=180) as response:
                raw = response.read(8 * 1024 * 1024 + 1)
        if len(raw) > 8 * 1024 * 1024:
            raise ValueError("Oversized response")
        result = json.loads(raw)
        if len(result["data"]) != 1:
            raise ValueError("Expected one image")
        content = base64.b64decode(result["data"][0]["b64_json"], validate=True)
        if not content.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError("Expected PNG")
        path = folder / "reference.png"
        path.write_bytes(content)
        # Ensure the result can enter the existing Meshy image-input path.
        image_input(path)
        metric("openai_edit_image_bytes", len(content))
        return path
    except HTTPError as error:
        raise AppError("OPENAI_IMAGE_ERROR", "OpenAI image edit returned HTTP %d. Check image-model access, permissions and credits." % error.code) from None
    except (URLError, TimeoutError, OSError):
        raise AppError("OPENAI_IMAGE_ERROR", "Image edit network/file operation failed; no automatic retry was made.") from None
    except (KeyError, TypeError, ValueError):
        raise AppError("INVALID_MODEL_OUTPUT", "OpenAI returned an invalid image response.") from None
