extends Marker3D

@export_file("*.tscn") var destination: String
@export_enum("Forward (-Z)", "Right (+X)") var direction := 0
var transitioning := false
@onready var player: Node3D = get_parent().get_node("Player")

func _physics_process(_delta: float) -> void:
	if get_parent().has_method("can_exit") and not get_parent().can_exit():
		return
	# Each boundary covers all lateral positions and jump heights.
	var reached := player.global_position.z <= global_position.z
	if direction == 1:
		reached = player.global_position.x >= global_position.x
	if transitioning or not reached:
		return
	activate()

## Explicit encounter completion can use the same guarded transition as walking.
func activate() -> void:
	if get_parent().get("entering") == true: return
	if transitioning:
		return
	transitioning = true
	# Defer scene removal until the current physics iteration finishes.
	call_deferred("_change_scene")

func _change_scene() -> void:
	var tree := get_tree()
	tree.current_scene = get_parent()
	var error: Error = get_node("/root/Journey").travel_to(destination)
	if error != OK:
		transitioning = false
		push_error("Could not enter the next stage: " + error_string(error))
