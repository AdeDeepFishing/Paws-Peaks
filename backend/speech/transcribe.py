"""Bounded microphone transcription; caller reviews text before sending dialogue."""
import io
import json
import wave
from uuid import uuid4
from urllib.request import Request
from utils.common import AppError, provider_urlopen


def transcribe(config, audio):
    try:
        if not 44 < len(audio) <= 700000: raise ValueError()
        with wave.open(io.BytesIO(audio), 'rb') as recording:
            if recording.getnchannels() != 1 or recording.getsampwidth() != 2 or recording.getframerate() != 16000: raise ValueError()
            if not 0.1 <= recording.getnframes() / 16000 <= 20.1: raise ValueError()
    except Exception:
        raise AppError('INVALID_AUDIO', 'Record up to 20 seconds, then try again.') from None
    key = config.get('ELEVENLABS_API_KEY')
    if not key: raise AppError('VOICE_NOT_CONFIGURED', 'Speech recognition is not configured. You can type instead.')
    boundary = 'talk-' + uuid4().hex
    body = ('--' + boundary + '\r\nContent-Disposition: form-data; name="model_id"\r\n\r\n' + config.get('ELEVENLABS_STT_MODEL', 'scribe_v2') + '\r\n--' + boundary + '\r\nContent-Disposition: form-data; name="file"; filename="speech.wav"\r\nContent-Type: audio/wav\r\n\r\n').encode() + audio + ('\r\n--' + boundary + '--\r\n').encode()
    request = Request('https://api.elevenlabs.io/v1/speech-to-text', data=body, headers={'xi-api-key': key, 'Content-Type': 'multipart/form-data; boundary=' + boundary})
    try:
        with provider_urlopen(request, timeout=35) as response:
            data = response.read(131073)
        if len(data) > 131072: raise ValueError()
        text = json.loads(data).get('text')
        if not isinstance(text, str) or not 0 < len(text.strip()) <= 2000: raise ValueError()
        return text.strip()
    except Exception:
        raise AppError('TRANSCRIPTION_UNAVAILABLE', 'Could not transcribe the recording. Check Speech to Text access, or type your message.') from None
