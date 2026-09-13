"""Stage 4 (Otter) classification contract; no live API calls."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_cases import StageCases


class OtterTests(StageCases, unittest.TestCase):
    stage_number = 4
    stage = 'otter'
    encounter = 'E04'
    classes = ('GIFT', 'TOOL', 'UNKNOWN')
