"""Interpretation instructions used by the sketch-to-model pipeline."""
from interpret.run import PROMPT

SKETCH_PROMPT = PROMPT + """
This is a hand-drawn object intended for a game, not a photograph.
Infer the most likely reasonably common object from its strokes.
Use its visible silhouette, proportions and structural parts to identify the object.
Keep the description focused on what it is and how it might help with the challenge.
Do not spend the description's character budget listing endpoint positions, reconstruction
instructions, or fixed phrases such as "whole object, all parts visible".
The image-edit step receives the original sketch and handles visual reconstruction.
If the sketch touches the image edge, infer its likely complete form without inventing unrelated parts.
If the sketch is ambiguous, choose the most plausible reasonably common object suggested by its strokes.
"""
