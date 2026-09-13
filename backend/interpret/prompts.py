"""Interpretation instructions used by the sketch-to-model pipeline."""
from interpret.run import PROMPT

SKETCH_PROMPT = PROMPT + """
This is a hand-drawn tool or piece of equipment intended for a game, not a photograph.
Infer the most likely object from its strokes. Equipment may include a bridge or ladder.
Use its visible silhouette, proportions and structural parts to identify the object.
Keep the description focused on what it is and how it might help with the challenge.
Do not spend the description's character budget listing endpoint positions, reconstruction
instructions, or fixed phrases such as "whole object, all parts visible".
The image-edit step receives the original sketch and handles visual reconstruction.
If the sketch touches the image edge, infer its likely complete form without inventing unrelated parts.
Do not invent an object if the sketch is too ambiguous: return uncertain instead.
"""
