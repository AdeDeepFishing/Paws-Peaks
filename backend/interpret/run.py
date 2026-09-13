#!/usr/bin/env python3
"""One image -> OpenAI -> a validated Paws & Peaks item. Python 3.9+, no packages."""

import argparse
from copy import deepcopy
import json
import re
from pathlib import Path
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request
from uuid import uuid4

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from utils.common import AppError, MAX_IMAGE_BYTES, ROOT, image_input, load_config
from utils.common import provider_urlopen as urlopen
from utils.profiling import Profiler, measure, metric

from stage_config import STAGES, classes_for
from material_palette import KEYS as TEXTURE_KEYS, PROMPT as PALETTE_PROMPT

API_URL = "https://api.openai.com/v1/responses"
TYPES = list(classes_for("river"))
ITEM_PROPERTIES = {
    "name": {"type": "string", "minLength": 1, "maxLength": 40},
    "description": {"type": "string", "maxLength": 160},
    "type": {"type": "string", "enum": TYPES},
    "movable": {"type": "boolean"},
    "texture_key": {"type": "string", "enum": TEXTURE_KEYS},
    "color": {"type": "string", "pattern": "^#[0-9A-Fa-f]{6}$"},
}
SCHEMA = {
    "type": "object", "additionalProperties": False,
    "required": ["item"],
    "properties": {
        "item": {"type": "object", "additionalProperties": False,
                 "required": list(ITEM_PROPERTIES), "properties": ITEM_PROPERTIES},
    },
}
PROMPT = """Interpret the main object in this image for Paws & Peaks, a warm storybook game.
Accept rough sketches. Perform these two steps in order within this one response:
1. Identify the object from its visible strokes, silhouette, proportions, and parts.
Make a best-effort guess of a reasonably common object even when confidence is low.
Choose the most plausible common object suggested by the image. Do not let the game
stage or its allowed classes influence the object's identity.
2. Only after identifying the object, classify that object using the allowed classes.
Use UNKNOWN if the identified object does not fit any named class. Do not change its
identity to fit a class or solve the challenge.
Also decide whether the identified object is movable: true for portable or loose
objects such as food, toys, tools, or a freestanding chair; false for fixed structures
such as a bridge or building. Base this on the object itself, not the stage class.
Choose one texture_key from the material palette for the object's dominant material.
Use plain if none fits. Choose color as an opaque #RRGGBB hex tint, based on visible
sketch colors or a plausible natural color when the sketch is monochrome. Prefer
warm, muted storybook colors. The saved textures are neutral grayscale; material
and color are independent. Do not put color names or file paths in texture_key.
Always return an item; do not return an uncertainty status or a null item.
Write a short English name. In description, write one complete English sentence naming the object and its possible usefulness.
Aim for 80-120 characters and never exceed 160. Shorten the wording to finish the sentence; never cut off a word or phrase.
Describe a potential use, without claiming the player has already used it or solved the challenge.
"""


def schema_for(game_stage):
    schema = deepcopy(SCHEMA)
    schema["properties"]["item"]["properties"]["type"]["enum"] = list(classes_for(game_stage))
    return schema


def validate_interpretation(value, game_stage="river"):
    allowed_types = classes_for(game_stage)
    invalid = AppError("INVALID_MODEL_OUTPUT", "OpenAI returned an invalid item. Try again.")
    if not isinstance(value, dict) or set(value) != {"item"}:
        raise invalid
    item = value["item"]
    if not isinstance(item, dict) or set(item) != set(ITEM_PROPERTIES):
        raise invalid
    if not isinstance(item["name"], str) or not 1 <= len(item["name"].strip()) or len(item["name"]) > 40:
        raise invalid
    if not isinstance(item["description"], str) or len(item["description"]) > 160 or item["type"] not in allowed_types:
        raise invalid
    if type(item["movable"]) is not bool:
        raise invalid
    if not isinstance(item["texture_key"], str) or item["texture_key"] not in TEXTURE_KEYS:
        raise invalid
    if not isinstance(item["color"], str) or not re.fullmatch(r"#[0-9A-Fa-f]{6}", item["color"]):
        raise invalid
    return value


def parse_response(response, game_stage="river"):
    invalid = AppError("INVALID_MODEL_OUTPUT", "OpenAI returned incomplete or unreadable output. Try again.")
    if not isinstance(response, dict) or response.get("status") != "completed":
        raise invalid
    texts = []
    try:
        for output in response["output"]:
            if output.get("type") != "message":
                continue
            for content in output["content"]:
                if content.get("type") == "refusal":
                    raise AppError("INVALID_MODEL_OUTPUT", "OpenAI could not interpret this image. Try another image.")
                if content.get("type") == "output_text":
                    texts.append(content["text"])
        return validate_interpretation(json.loads("".join(texts)), game_stage)
    except (KeyError, TypeError, ValueError, AttributeError):
        raise invalid from None


def interpret(image, config, prompt=PROMPT, game_stage="river"):
    """Make one synchronous provider call. Run off the game main thread later."""
    allowed_types = classes_for(game_stage)
    if "UNKNOWN" not in allowed_types:
        raise AppError("CONFIG_ERROR", "Stage classes must include UNKNOWN for unmatched objects.")
    prompt += ("\nClassification context for step 2 only: game stage " + game_stage
               + ". Allowed item classes: " + ", ".join(allowed_types)
               + ". Use UNKNOWN if no named class fits the object identified in step 1.")
    guidance = STAGES[game_stage].get("classification_guidance", "")
    if guidance:
        prompt += "\n" + guidance
    prompt += "\n" + PALETTE_PROMPT
    key = config["OPENAI_API_KEY"]
    if not key or key.lower().startswith(("your_", "paste_")):
        raise AppError("CONFIG_ERROR", "Fill OPENAI_API_KEY in backend/.env, then run again.")
    if not key.isascii() or any(character.isspace() for character in key):
        raise AppError("CONFIG_ERROR", "The API key must not contain whitespace or non-ASCII characters.")
    if not config["OPENAI_MODEL"]:
        raise AppError("CONFIG_ERROR", "Set OPENAI_MODEL in backend/.env.")
    payload = {
        "model": config["OPENAI_MODEL"], "store": False, "max_output_tokens": 800,
        "input": [
            {"role": "system", "content": prompt},
            {"role": "user", "content": [{"type": "input_image", "image_url": image, "detail": "auto"}]},
        ],
        "text": {"format": {"type": "json_schema", "name": "drawing_interpretation", "strict": True, "schema": schema_for(game_stage)}},
    }
    request = Request(API_URL, data=json.dumps(payload).encode("utf-8"), method="POST",
                      headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    metric("request_body_bytes", len(request.data))
    try:
        with measure("openai_request"):
            with urlopen(request, timeout=15) as response:
                data = response.read(1024 * 1024 + 1)
        metric("response_body_bytes", len(data))
        if len(data) > 1024 * 1024:
            raise AppError("INVALID_MODEL_OUTPUT", "The provider response was too large.")
        with measure("response_validation"):
            return parse_response(json.loads(data), game_stage)
    except HTTPError as error:
        # Never print the provider body, request headers, or the key.
        messages = {
            401: "OpenAI rejected authentication or key permissions. Check OPENAI_API_KEY and Responses access.",
            403: "OpenAI denied access. Check the API project and model permissions.",
            404: "The configured model was not found or is unavailable to this project.",
            429: "OpenAI rate or quota limit reached. Check API billing and limits.",
            400: "OpenAI rejected the request. Check the image and model's structured-output support.",
        }
        raise AppError("RATE_LIMITED" if error.code == 429 else "SERVICE_UNAVAILABLE",
                       messages.get(error.code, "OpenAI is unavailable. Try again later.")) from None
    except (URLError, TimeoutError, OSError):
        raise AppError("SERVICE_UNAVAILABLE", "Could not reach OpenAI or the request timed out. Check your connection.") from None
    except (ValueError, UnicodeError):
        raise AppError("INVALID_MODEL_OUTPUT", "OpenAI returned unreadable JSON.") from None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group()
    source.add_argument("--image", type=Path, help="Local PNG/JPEG; defaults to the downloaded sample.")
    source.add_argument("--image-url", help="Public HTTPS image URL for OpenAI to fetch.")
    parser.add_argument("--game-stage", choices=STAGES, default="river")
    parser.add_argument("--env-file", type=Path, default=ROOT / ".env")
    parser.add_argument("--request-id", default=None, help="Pass DrawingRequest.active_id when integrating Godot.")
    parser.add_argument("--dry-run", action="store_true", help="Check local input/config without sending anything to OpenAI.")
    parser.add_argument("--profile", action="store_true", help="Print performance to stderr and save a report under backend/output/profiles/.")
    args = parser.parse_args(argv)
    envelope = {"schema_version": 2, "request_id": args.request_id or STAGES[args.game_stage]["encounter_id"] + "-" + uuid4().hex}
    profiler = Profiler(args.profile, "interpret", "interpret", args.request_id)
    outcome = "UNEXPECTED_ERROR"
    try:
        classes_for(args.game_stage)
        with measure("config_load"):
            config = load_config(args.env_file)
        with measure("image_prepare"):
            image = image_input(args.image or ROOT / "samples" / "banana.jpg", args.image_url)
        if args.dry_run:
            print(json.dumps({"dry_run": True, "image_ready": True,
                              "api_key_configured": bool(config["OPENAI_API_KEY"]),
                              "model": config["OPENAI_MODEL"]}))
            outcome = "DRY_RUN"
            return 0
        result = interpret(image, config, game_stage=args.game_stage)
        print(json.dumps({**envelope, **result}, ensure_ascii=False, indent=2, allow_nan=False))
        outcome = "SUCCEEDED"
        return 0
    except AppError as error:
        code, message = error.code, str(error)
        outcome = code
    except (OSError, UnicodeError):
        code, message = "INVALID_INPUT", "Could not read the local image or env file. Check its path, encoding, and permissions."
        outcome = code
    except ValueError:
        code, message = "INVALID_INPUT", "The image URL is invalid. Use a public HTTPS image URL."
        outcome = code
    finally:
        profiler.finish(outcome)
    print(json.dumps({**envelope, "error": {"code": code}}))
    print(message, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
