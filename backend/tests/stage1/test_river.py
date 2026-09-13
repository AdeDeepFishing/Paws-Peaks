"""Stage 1 (River) classification contract; no live API calls."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_cases import StageCases


class RiverTests(StageCases, unittest.TestCase):
    stage_number = 1
    stage = 'river'
    encounter = 'E01'
    classes = ('BRIDGE', 'BOAT', 'UNKNOWN')
