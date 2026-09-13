extends SceneTree

var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var level = load("res://scenes/river/river_crossing.tscn").instantiate()
	level.get_node("DesktopGeneration").mode = 0
	root.add_child(level)
	current_scene = level
	await process_frame
	check(level.book.text == "E · Draw", "Keyboard entry shows only E")
	check(not "Square" in level.controls.text and not "D-pad" in level.controls.text, "Keyboard hints omit controller labels")
	var joy := InputEventJoypadMotion.new()
	joy.device = 0
	joy.axis = JOY_AXIS_LEFT_X
	joy.axis_value = 0.1
	root.push_input(joy)
	check(level.book_key == "E", "Idle stick drift cannot switch hints")
	joy.axis_value = 0.5
	root.push_input(joy)
	check(level.hint_device == 0 and level.book_key == "West button", "Real controller input switches to its layout")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	root.push_input(mouse)
	check(level.book_key == "E", "Mouse input restores keyboard hints")
	level.hint_device = 0
	level._update_controller_hints(0, false)
	check(level.book.text == "E · Draw", "Disconnect restores keyboard hints")
	check(level.controller_labels("Xbox Wireless Controller").draw == "X", "Xbox uses X")
	check(level.controller_labels("DualSense Wireless Controller").draw == "□", "PlayStation uses a square glyph")
	check(level.controller_labels("Nintendo Switch Pro Controller").draw == "Y", "Switch uses Y")
	current_scene.queue_free()
	await process_frame
	print("INPUT HINTS SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
