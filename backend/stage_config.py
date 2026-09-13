"""Backend-owned classification sets for the four game stages."""
from utils.common import AppError

STAGES = {
    'river': {'stage_number': 1, 'encounter_id': 'E01', 'classes': ('BRIDGE', 'BOAT', 'UNKNOWN')},
    'dog': {'stage_number': 2, 'encounter_id': 'E02', 'classes': ('FOOD', 'TOY', 'WEAPON', 'UNKNOWN')},
    'crows': {'stage_number': 3, 'encounter_id': 'E03', 'classes': ('BOW', 'MAGIC', 'DEFENCE', 'UNKNOWN')},
    'otter': {'stage_number': 4, 'encounter_id': 'E04', 'classes': ('GIFT', 'TOOL', 'UNKNOWN')},
}


def classes_for(game_stage):
    if game_stage not in STAGES:
        raise AppError('INVALID_REQUEST', 'Unknown game stage.')
    classes = STAGES[game_stage]['classes']
    if not classes:
        raise AppError('STAGE_NOT_CONFIGURED', 'Define classification classes for this stage in backend/stage_config.py.')
    if (not isinstance(classes, (tuple, list))
            or any(not isinstance(c, str) or not c.strip() or len(c) > 40 for c in classes)
            or len(set(classes)) != len(classes)):
        raise AppError('CONFIG_ERROR', 'Stage classes must be unique, nonempty strings of at most 40 characters.')
    return tuple(classes)
