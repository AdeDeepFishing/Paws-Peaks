"""Generate export-only settings; never read or embed provider credentials."""
import json
import os
import re
from pathlib import Path
from urllib.parse import urlparse

root = Path(__file__).resolve().parents[2]
api = os.environ.get('GAME_API_URL', '').rstrip('/')
parsed = urlparse(api)
if api and (parsed.scheme != 'https' or not parsed.netloc or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment):
    raise SystemExit('GAME_API_URL must be an HTTPS API origin')
(root / '3d_game/web_config.json').write_text(json.dumps({'api_url': api}))
templates = Path(os.environ.get('TALE_WEB_TEMPLATES', '/tmp/tale-godot-4.7.2/templates')).resolve()
preset = (root / '3d_game/export_presets.cfg').read_text()
for kind in ['debug', 'release']:
    preset = re.sub(r'custom_template/' + kind + r'=.*', lambda _: f'custom_template/{kind}={json.dumps(str(templates / ("web_nothreads_" + kind + ".zip")))}', preset)
(root / '3d_game/export_presets.cfg').write_text(preset)
