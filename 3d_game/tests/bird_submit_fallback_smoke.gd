extends SceneTree
var failed := false
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func run():
	change_scene_to_file("res://scenes/wind_hill/wind_hill.tscn")
	await scene_changed
	var level = current_scene
	level.generation.configure(0)
	level.request.mock_delay = 60
	await create_timer(4).timeout
	level._open_drawing()
	check(level.drawing, "Drawing opens after the entrance")
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([Vector2(600, 8), Vector2(640, 12), Vector2(680, 8)]))
	level.surface.changed.emit()
	level.submit_button.pressed.emit()
	check(level.request.state == "PENDING" and not level.drawing, "Sky sketch starts generation through the submit button")
	check(level.sketch_anchor.distance_to(level.player.global_position) < 5, "Fallback places the object near the player")
	level.request.cancel()
	level._open_drawing()
	level.player.set_physics_process(false)
	level.player.global_position = Vector3(1000, 100, 1000)
	level.submit_button.pressed.emit()
	check(level.drawing and level.request.state != "PENDING", "Missing terrain preserves the draft")
	check(root.get_node("Narrator").panel.caption_text.text.contains("No safe ground"), "Placement failure is immediately visible")
	print("BIRD SUBMIT FALLBACK: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
