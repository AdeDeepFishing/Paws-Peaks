extends Marker3D

@export_file("*.tscn") var destination: String
var transitioning := false
@onready var player: Node3D = get_parent().get_node("Player")

func _physics_process(_delta: float) -> void:
	# Forward travel is world -Z. The entire X axis shares this exit boundary,
	# including the shoulders and jumps; a narrow overlap box can be bypassed.
	if transitioning or player.global_position.z > global_position.z:
		return
	transitioning = true
	# Defer scene removal until the current physics iteration finishes.
	call_deferred("_change_scene")

func _change_scene() -> void:
	var tree := get_tree()
	tree.current_scene = get_parent()
	var error := tree.change_scene_to_file(destination)
	if error != OK:
		transitioning = false
		push_error("Could not enter the next stage: " + error_string(error))
