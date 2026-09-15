extends Node

const Model = preload("res://scripts/river/generated_model.gd")
@onready var request = $DrawingRequest
@onready var generation = $DesktopGeneration
@onready var level = get_parent()
var preview: Control
var anchor := Vector3.ZERO
var object: PhysicsBody3D

func setup() -> void:
	var panel = get_node("/root/Narrator").panel
	preview = preload("res://scripts/river/generation_preview.gd").attach(level, request, generation, panel.surface)
	request.state_changed.connect(_on_state)
	generation.progress_changed.connect(func(message: String): level.status.text = message)

func submit(png: PackedByteArray) -> bool:
	if request.state == "PENDING": return false
	# Keep generated objects beside the player, clear of the boss and exit.
	var found := false
	for offset in [Vector3(1.8, 0, 0), Vector3(-1.8, 0, 0), Vector3(0, 0, 1.8)]:
		var point: Vector3 = level.player.global_position + offset
		var excluded: Array[RID] = [level.player.get_rid(), level.get_node("Storykeeper").get_rid()]
		if is_instance_valid(object): excluded.append(object.get_rid())
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5, point + Vector3.DOWN * 10, 1, excluded)
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y >= 0.5:
			anchor = hit.position
			found = true
			break
	if not found:
		get_node("/root/Narrator").panel._show_line("Narrator", "Move onto the path before drawing an object.")
		return false
	if not request.submit(png, "E05"): return false
	preview.anchor_to_world(level.camera, anchor)
	return true

func _on_state(state: String) -> void:
	match state:
		"PENDING": level.status.text = "Creating your drawing while the Storykeeper considers it…"
		"FAILED": level.status.text = request.message + " Your sketch is safe; try again."
		"IDLE": level.status.text = "Stopped generating the object. Your sketch is safe."
		"READY":
			var visual := Model.load_visual(request.model_path, 1.8, false, request.result)
			if visual == null:
				request.fail_current("The generated object could not be loaded.")
				return
			if is_instance_valid(object): object.queue_free()
			object = Model.physics_body(visual, request.result, true)
			level.add_child(object)
			object.global_position = anchor + Vector3.UP * Model.placement_height(request.result)
			preview.model_presented()
			level.status.text = "Your drawing has appeared beside you."
