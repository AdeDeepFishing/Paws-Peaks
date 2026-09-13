"""Shared game-material keys supplied to interpretation."""
import json
from pathlib import Path

PALETTE_PATH = Path(__file__).resolve().parents[1] / "3d_game/assets/materials/palette.json"
PALETTE = json.loads(PALETTE_PATH.read_text())
KEYS = list(PALETTE)
PROMPT = "Material palette: " + "; ".join(key + " = " + value["description"] for key, value in PALETTE.items())
