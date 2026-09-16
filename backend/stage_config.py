"""Backend-owned stage classes and drawing interpretation hints."""
from utils.common import AppError

STAGES = {
    'river': {'stage_number': 1, 'encounter_id': 'E01', 'classes': ('BRIDGE', 'BOAT', 'UNKNOWN')},
    'dog': {'stage_number': 2, 'encounter_id': 'E02', 'classes': ('FOOD', 'TOY', 'WEAPON', 'UNKNOWN')},
    'crows': {
        'stage_number': 3, 'encounter_id': 'E03', 'classes': ('BOW', 'MAGIC', 'DEFENCE', 'UNKNOWN'),
        'classification_guidance': (
            'DEFENCE includes an ordinary umbrella, parasol, shield, helmet, or protective cover. '
            'BOW includes bows and crossbows; MAGIC fits magical creations such as a wind-summoning wand. '
            'Choose the class that matches your interpretation.'
        ),
    },
    'otter': {'stage_number': 4, 'encounter_id': 'E04', 'classes': ()},
    'storykeeper': {'stage_number': 5, 'encounter_id': 'E05', 'classes': ('UNKNOWN',)},
}


SCENARIO_HINTS = {
    'river': (
        'The player needs to cross a river. A bridge, stepping platform, or boat might help.'
    ),
    'dog': (
        'A large dog blocks the path and might want food or a toy. An oval with short strokes '
        'could suggest a bone, snack, or ball; playful inventions are welcome too.'
    ),
    'crows': (
        'A giant bird swoops toward the player. An umbrella or shield might offer cover, '
        'while a bow or magical creation might scare it from a distance. Protection is one '
        'approach among many. An arc with a string might be a bow; a star-tipped stick might be a wind-summoning wand.'
    ),
    'otter': (
        'A sad otter hopes for a thoughtful offering. It likes fish and shellfish, but '
        'toys and other thoughtful gifts can also cheer it up. Surprise it with a sensible connection.'
    ),
    'storykeeper': (
        'The Storykeeper fears the adventure ending. Comfort, a keepsake, or an imaginative '
        'way for stories to continue could help. Describe the idea; his mood and the ending '
        'are evaluated separately.'
    ),
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
