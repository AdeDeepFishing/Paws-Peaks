extends "res://scripts/woodland/woodland_level.gd"

## Temporary exploration shortcut until the final boss encounter is integrated.
@export var preview_ending_enabled := true

func _ready() -> void:
	super._ready()
	objective.text = "Meet the Storykeeper in the clearing."

func can_exit() -> bool:
	return preview_ending_enabled

## Call after an implemented boss encounter resolves successfully.
func complete_boss_encounter() -> void:
	$EndingExit.activate()
