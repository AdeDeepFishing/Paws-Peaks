"""Interpretation instructions used by the sketch-to-model pipeline."""
from interpret.run import PROMPT

SKETCH_PROMPT = PROMPT + """
The image-edit step also sees the original sketch and handles reconstruction.
Focus the description on the imagined object and its usefulness rather than drawing coordinates.
"""
