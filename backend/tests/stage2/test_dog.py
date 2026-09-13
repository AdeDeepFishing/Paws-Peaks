"""Stage 2 (Dog) classification contract; no live API calls."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from stage_cases import StageCases


class DogTests(StageCases, unittest.TestCase):
    stage_number = 2
    stage = 'dog'
    encounter = 'E02'
    classes = ('FOOD', 'TOY', 'WEAPON', 'UNKNOWN')
