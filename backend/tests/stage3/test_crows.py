"""Stage 3 (Crows) classification contract; no live API calls."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_cases import StageCases


class CrowsTests(StageCases, unittest.TestCase):
    stage_number = 3
    stage = 'crows'
    encounter = 'E03'
    classes = ('BOW', 'MAGIC', 'UNKNOWN')
    rejected_classes = ('BOAT', 'BRIDGE', 'FOOD', 'GIFT', 'TOOL', 'TOY', 'WEAPON')
