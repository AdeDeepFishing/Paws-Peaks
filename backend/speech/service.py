"""Character-routed ElevenLabs speech with private local caching and no music calls."""
import hashlib
import json
import re
from pathlib import Path
from urllib.request import Request
from utils.common import AppError, provider_urlopen

class Speech:
    def __init__(self, config, directory):
        self.config = config
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=True)

    def generate(self, text, speaker="narrator"):
        if speaker not in ("narrator", "otter") or not isinstance(text, str) or not 0 < len(text) <= 1200:
            raise AppError("INVALID_REQUEST", "Invalid speech request.")
        voice = self.config.get("ELEVENLABS_" + speaker.upper() + "_VOICE_ID", "")
        key = self.config.get("ELEVENLABS_API_KEY", "")
        if not key or not voice:
            raise AppError("VOICE_NOT_CONFIGURED", "Voice is not configured; subtitles remain available.")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,100}", voice):
            raise AppError("CONFIG_ERROR", "Invalid voice identifier.")
        body = {"text": text, "model_id": self.config["ELEVENLABS_MODEL"],
                "voice_settings": {"stability": 0.5, "similarity_boost": 0.75}}
        fingerprint = hashlib.sha256(json.dumps([voice, body], sort_keys=True).encode()).hexdigest()
        path = self.directory / (fingerprint + ".mp3")
        if path.exists(): return path
        request = Request("https://api.elevenlabs.io/v1/text-to-speech/" + voice + "?output_format=mp3_44100_128",
                          data=json.dumps(body).encode(), headers={"xi-api-key": key, "Content-Type": "application/json", "Accept": "audio/mpeg"})
        try:
            with provider_urlopen(request, timeout=35) as response:
                if "audio" not in response.headers.get("Content-Type", ""): raise ValueError()
                audio = response.read(8 * 1024 * 1024 + 1)
            if not 100 < len(audio) <= 8 * 1024 * 1024: raise ValueError()
            if not (audio.startswith(b"ID3") or audio[0] == 255): raise ValueError()
            temporary = path.with_suffix(".tmp")
            temporary.write_bytes(audio)
            temporary.replace(path)
            return path
        except Exception:
            raise AppError("VOICE_UNAVAILABLE", "Voice is unavailable; subtitles remain available.") from None
