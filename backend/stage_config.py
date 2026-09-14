"""Backend-owned classification sets for the game stages."""
from utils.common import AppError

STAGES = {
    'river': {'stage_number': 1, 'encounter_id': 'E01', 'classes': ('BRIDGE', 'BOAT', 'UNKNOWN')},
    'dog': {'stage_number': 2, 'encounter_id': 'E02', 'classes': ('FOOD', 'TOY', 'WEAPON', 'UNKNOWN')},
    'crows': {
        'stage_number': 3, 'encounter_id': 'E03', 'classes': ('BOW', 'MAGIC', 'DEFENCE', 'UNKNOWN'),
        'classification_guidance': (
            'DEFENCE includes an identified ordinary umbrella, parasol, shield, helmet, or other protective cover; '
            'protection from weather or animals counts, not only combat armor. '
            'Classify an ordinary umbrella or shield as DEFENCE, not UNKNOWN merely because it is not a weapon. '
            'BOW means a bow or crossbow. MAGIC requires an identified magical object, such as a wand; '
            'do not invent magical properties for an ordinary object. '
            'These class meanings apply only after identifying the actual object from the sketch.'
        ),
    },
    'otter': {'stage_number': 4, 'encounter_id': 'E04', 'classes': ()},
    'storykeeper': {'stage_number': 5, 'encounter_id': 'E05', 'classes': ('UNKNOWN',)},
}


def classes_for(game_stage):
    if game_stage not in STAGES:
        raise AppError('INVALID_REQUEST', 'Unknown game stage.')
    classes = STAGES[game_stage]['classes']
    if game_stage == "otter":
        return ()  # Stage 4 identifies an object and selects an animation, without classification.
    if not classes:
        raise AppError('STAGE_NOT_CONFIGURED', 'Define classification classes for this stage in backend/stage_config.py.')
    if (not isinstance(classes, (tuple, list))
            or any(not isinstance(c, str) or not c.strip() or len(c) > 40 for c in classes)
            or len(set(classes)) != len(classes)):
        raise AppError('CONFIG_ERROR', 'Stage classes must be unique, nonempty strings of at most 40 characters.')
    return tuple(classes)
