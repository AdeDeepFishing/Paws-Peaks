extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/sunset_cove/sunset_cove.tscn")
	await scene_changed
	var level = current_scene
	for i in 120: await physics_frame
	for connection in level.request.request_prepared.get_connections():
		if connection.callable.get_object() == level.generation:
			level.request.request_prepared.disconnect(connection.callable)
	level.request.mock_mode = false
	level.entering = false
	level.player.walking_in = false
	level.player.global_position = level.otter.global_position + Vector3(1, 0.05, 0)
	level.offered = StaticBody3D.new()
	level.add_child(level.offered)
	level.request.state = "READY"
	level._open_drawing()
	# Force the actual drawing state if the controlled placement has not landed yet.
	level.drawing = true
	level.overlay.show()
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([Vector2(100, 20), Vector2(180, 30)]))
	level.surface.changed.emit()
	level.submit_button.pressed.emit()
	var passed: bool = level.request.state == "PENDING"
	print("OTTER REPEAT SUBMIT: ", "PASS" if passed else "FAIL", " · state=", level.request.state, " · hint=", level.hint.text)
	quit(0 if passed else 1)
