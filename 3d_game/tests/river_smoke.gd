extends SceneTree

const Level = preload("res://scenes/river/river_crossing.tscn")
const Request = preload("res://scripts/river/drawing_request.gd")
var failures: Array[String] = []
var level

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func response(id: String, tags: Array = ["LONG_REACH", "STURDY"]) -> Dictionary:
	return {"schema_version": 2, "request_id": id, "status": "recognized", "item": {
		"name": "Paper bridge", "description": "A sturdy crossing.", "type": "TOOL",
		"attack_power": 0, "range": 8.0, "speed": 1.0, "durability": 3, "tags": tags
	}}

func screenshot(name: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args():
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-river-" + name + ".png")

func run() -> void:
	root.size = Vector2i(1152, 720)
	level = Level.instantiate()
	level.auto_advance = false
	level.get_node("EncounterPresentation").duration_scale = 0.01
	level.get_node("DesktopGeneration").mode = 0
	level.drawing_export_directory = "user://test-drawings/river-smoke"
	root.add_child(level)
	await frames(30)
	check(level.player.is_on_floor(), "Player spawns on the near bank")
	check(not level.unlocked, "Sketchbook starts hidden before approaching the river")
	await screenshot("world")
	await fixed_camera_checks()
	await controller_checks()
	level.player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	check(level.unlocked, "Entering the river area unlocks the sketchbook")
	check(absf(level.book.get_global_rect().end.x - 1124.0) < 1.0, "Sketchbook stays anchored to the lower-right margin")
	await screenshot("book")
	level._open_book()
	await frames(2)
	check(level.drawing_overlay.visible and not level.modal.visible and not level.player.input_enabled, "Scene drawing releases gameplay input without the old panel")
	check(not level.normal_hud.visible, "Drawing hides regular HUD")
	await overlay_checks()
	var locked_camera: Transform3D = level.get_node("StageCamera").global_transform
	var locked_motion := InputEventMouseMotion.new()
	locked_motion.relative = Vector2(200, 100)
	Input.parse_input_event(locked_motion)
	check(level.get_node("StageCamera").global_transform == locked_camera, "Drawing leaves the fixed camera unchanged")
	var before: Vector3 = level.player.position
	Input.action_press("move_up")
	Input.action_press("jump")
	Input.action_press("sprint")
	await frames(8)
	Input.action_release("move_up")
	Input.action_release("jump")
	Input.action_release("sprint")
	check(level.player.position.distance_to(before) < 0.1, "Movement and jumping are blocked while drawing")
	var canvas = level.surface
	var sample := Image.create(512, 512, false, Image.FORMAT_RGB8)
	sample.fill(Color.WHITE)
	var first_png := sample.save_png_to_buffer()
	var first_path: String = level._save_drawing(first_png)
	sample.fill(Color.BLACK)
	var second_png := sample.save_png_to_buffer()
	var second_path: String = level._save_drawing(second_png)
	check(not first_path.is_empty() and first_path != second_path, "Repeated exports have distinct filenames")
	check(FileAccess.get_file_as_bytes(first_path) == first_png, "Earlier drawing stays unchanged after another export")
	check(FileAccess.get_file_as_bytes(second_path) == second_png, "New drawing is saved with its own content")
	check(canvas.snapshot_png().is_empty(), "Empty canvas cannot be exported")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(80, 210)
	canvas._gui_input(click)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(420, 270)
	canvas._gui_input(motion)
	click.pressed = false
	canvas._input(click)
	check(not canvas.drawing, "Global mouse release ends the stroke")
	check(canvas.has_drawing(), "Mouse input produces a stroke")
	var png: PackedByteArray = canvas.snapshot_png()
	var bitmap := Image.new()
	check(bitmap.load_png_from_buffer(png) == OK, "Export is a valid PNG")
	check(bitmap.get_size() == Vector2i(512, 512), "Export stays 512 by 512")
	check(bitmap.get_pixel(256, 256).r < 0.5, "Cropped export contains the player's ink")
	check(bitmap.get_pixel(0, 0).a == 0.0, "Export has a transparent background")
	canvas.undo()
	check(not canvas.has_drawing(), "Undo removes the complete stroke")
	canvas.strokes.append(PackedVector2Array([Vector2(360, 280), Vector2(740, 420), Vector2(720, 470), Vector2(340, 330), Vector2(360, 280)]))
	canvas.strokes.append(PackedVector2Array([Vector2(390, 350), Vector2(370, 420)]))
	canvas.strokes.append(PackedVector2Array([Vector2(680, 450), Vector2(660, 520)]))
	canvas.queue_redraw()
	canvas.changed.emit()
	await frames(12)
	await screenshot("drawing")
	if "--visual" in OS.get_cmdline_user_args():
		var exported := Image.new()
		exported.load_png_from_buffer(canvas.snapshot_png())
		exported.save_png("/private/tmp/paws-scene-drawing-input.png")
	level.request.mock_mode = false
	var delivered: Array[Dictionary] = []
	level.request.request_prepared.connect(func(payload): delivered.append(payload))
	level._submit()
	check(level.request.state == "PENDING", "Submit starts a background request")
	check(level.presentation.busy and not level.player.input_enabled, "Submit begins construction closeup")
	await level.presentation.settled
	await frames(6)
	check(not level.modal.visible and not level.drawing_overlay.visible and level.normal_hud.visible and level.player.input_enabled, "Construction closeup restores exploration")
	check(delivered.size() == 1 and delivered[0].encounter_id == "E01", "Integration signal carries encounter context")
	check(Marshalls.base64_to_raw(delivered[0].image_base64) == level.request.snapshot, "Payload contains the exact immutable PNG")
	var saved: PackedByteArray = level.request.snapshot.duplicate()
	canvas.clear()
	check(level.request.snapshot == saved, "Editing the draft cannot mutate the submitted PNG")
	check(not level.request.submit(png, "E01"), "A second request cannot replace a pending request")
	var id: String = level.request.active_id
	check(not level.request.accept_response(response("old-request")), "Late responses for another request are ignored")
	level.player.position = level.get_node("Coins/Coin01").position - Vector3.UP * 0.6
	await frames(8)
	check(level.collected.size() == 1, "Coins can be collected while a request is pending")
	level.player.position.y = -3
	await frames(8)
	check(level.collected.size() == 1 and level.request.active_id == id, "Fall recovery preserves coins and request identity")
	var waiting_position: Vector3 = level.player.position
	level.request.accept_response(response(id))
	check(level.request.state == "READY" and not level.modal.visible and not level.drawing_overlay.visible, "Ready response does not reopen a canvas or result modal")
	check(level.bridge_built, "Supported result automatically creates the bridge while the player is away")
	check(not level.player.input_enabled and level.presentation.busy, "Result briefly locks input for its closeup")
	await level.presentation.settled
	check(level.player.position.distance_to(waiting_position) < 0.2 and level.player.input_enabled, "Result closeup restores control without teleporting")
	check(not level.get_node("Bridge").has_node("Sketch"), "Generated bridge does not display the drawing as a paper canvas")
	check(not level.request.accept_response(response(id)), "Duplicate completed response cannot create another bridge")
	check(not level.build_bridge() and level.current_item.durability == 2, "Automatic placement spends durability exactly once")
	await frames(3)
	check(not level.get_node("Bridge/Deck/CollisionShape3D").disabled, "The generated bridge has walkable collision")
	level._open_book()
	check(level.panel_mode == "", "No confirmation or preview is required after generation")
	level.player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	await screenshot("bridge")
	var yaw: float = level.get_node("StageCamera").rotation.y
	Input.action_press("move_right", cos(yaw))
	Input.action_press("move_down", sin(yaw))
	Input.action_press("sprint")
	await frames(150)
	Input.action_release("move_right")
	Input.action_release("move_down")
	Input.action_release("sprint")
	check(level.completed, "Walking across the physical bridge reaches the stage ending")
	await screenshot("complete")
	level.restart()
	check(not level.bridge_built and level.collected.is_empty() and not level.completed, "Restart clears the stage and coins")
	check(level.request.state == "IDLE" and not canvas.has_drawing(), "Restart clears request and draft")
	check(not level.request.accept_response(response(id)), "A pre-restart response cannot change the new session")
	level.request.submit(png, "E01")
	id = level.request.active_id
	var invalid := response(id)
	invalid.item.speed = "fast"
	check(not level.request.accept_response(invalid) and level.request.state == "FAILED", "Invalid JSON field types are rejected")
	level.request.submit(png, "E01")
	level.request.accept_response(response(level.request.active_id, ["OTHER"]))
	check(not level._supports_bridge(), "Unsuitable items do not solve the encounter")
	check(not Request.valid_item(response("x").item.merged({"tags": ["OTHER", "STURDY"]}, true)), "OTHER cannot be mixed with another tag")
	check(not Request.valid_item(response("x").item.merged({"range": INF}, true)), "Nonfinite stats are rejected")
	level.request.submit(png, "E01")
	level.request.deadline_ms = Time.get_ticks_msec() - 1
	await frames(2)
	check(level.request.state == "FAILED", "Requests have a finite timeout")
	level.request.mock_mode = true
	level.request.mock_delay = 0.01
	for outcome in range(4):
		level.request.submit(png, "E01", outcome)
		await create_timer(0.04).timeout
		check(level.request.state == ("READY" if outcome < 2 else "FAILED"), "Mock outcome %d completes correctly" % outcome)
	level.queue_free()
	await frames(2)
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("PASS: fixed camera, scene collision, movement, drawing PNG, request lifecycle, and automatic physical crossing")
		quit(0)
	else:
		print("FAIL: ", failures)
		quit(1)

func fixed_camera_checks() -> void:
	var player = level.player
	var camera: Camera3D = level.get_node("StageCamera")
	check(camera == root.get_camera_3d(), "Level camera is active")
	check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "First stage uses orthographic projection")
	var fixed_transform := camera.global_transform
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(300, 180)
	Input.parse_input_event(motion)
	await frames(3)
	check(camera.global_transform == fixed_transform, "Mouse motion cannot orbit the camera")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Exploration keeps the cursor visible")
	var art: Node3D = level.get_node("Stage01Art")
	var water: MeshInstance3D = art.find_child("Creek_flat_turquoise", true, false)
	check(water.get_active_material(0).vertex_color_use_as_albedo, "Imported creek retains its painted vertex colors")
	var animations := art.find_children("*", "AnimationPlayer", true, false)
	check(not animations.is_empty(), "Delivered water animation is imported")
	if not animations.is_empty():
		var animation: AnimationPlayer = animations[0]
		var before_time := animation.current_animation_position
		await frames(12)
		check(animation.is_playing() and animation.current_animation_position != before_time, "Water animation advances during gameplay")
	var start: Vector3 = player.position
	Input.action_press("move_left")
	await frames(10)
	Input.action_release("move_left")
	check(player.position.distance_to(start) > 0.3, "Movement works without clicking or capturing the mouse")
	check(camera.global_transform == fixed_transform, "Walking does not move the fixed camera")
	Input.action_press("move_left")
	Input.action_press("move_down")
	Input.action_press("sprint")
	await frames(3)
	check(Vector2(player.velocity.x, player.velocity.z).length() <= player.sprint_speed + 0.01, "Diagonal sprint has no speed boost")
	Input.action_release("move_left")
	Input.action_release("move_down")
	Input.action_release("sprint")
	player.respawn(level.SPAWN)
	await frames(15)
	check(player.is_on_floor(), "Imported meadow provides solid ground")
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	check(player.velocity.y > 0, "Jump works with the fixed camera")
	await frames(60)
	level.restart()
	await frames(15)

func pointer(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)
	await frames(1)

func pointer_move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await frames(1)

func overlay_checks() -> void:
	var canvas = level.surface
	var animations: Array[Node] = level.get_node("Stage01Art").find_children("*", "AnimationPlayer", true, false)
	var water_time: float = animations[0].current_animation_position
	var player_position: Vector3 = level.player.position
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_UP
	arrow.pressed = true
	Input.parse_input_event(arrow)
	await frames(6)
	arrow.pressed = false
	Input.parse_input_event(arrow)
	check(level.player.position.distance_to(player_position) < 0.1, "Arrow keys cannot move the player during drawing")
	check(animations[0].current_animation_position != water_time, "Water keeps playing while drawing")
	check(canvas.size.is_equal_approx(root.get_visible_rect().size), "Transparent canvas covers the entire viewport")
	level._submit()
	check(level.request.state == "IDLE", "Empty overlay does not submit")
	await pointer(Vector2(200, 180), true)
	await pointer_move(Vector2(600, 180))
	await pointer_move(Vector2(600, 380))
	await pointer_move(Vector2(200, 380))
	await pointer_move(Vector2(200, 180))
	await pointer(Vector2(200, 180), false)
	check(canvas.strokes.size() == 1, "Viewport pointer input draws a complete stroke")
	var png: PackedByteArray = canvas.snapshot_png()
	var bitmap := Image.new()
	bitmap.load_png_from_buffer(png)
	var bounds := Rect2i(512, 512, 0, 0)
	var minimum := Vector2i(512, 512)
	var maximum := Vector2i.ZERO
	var black_and_transparent := true
	for y in 512:
		for x in 512:
			var color := bitmap.get_pixel(x, y)
			black_and_transparent = black_and_transparent and (color == Color.TRANSPARENT or color == Color.BLACK)
			if color == Color.BLACK:
				minimum = minimum.min(Vector2i(x, y))
				maximum = maximum.max(Vector2i(x, y))
	bounds = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
	check(black_and_transparent, "Export contains opaque black ink and transparent background only")
	check(absf(float(bounds.size.x) / bounds.size.y - 2.0) < 0.08, "Wide drawing is cropped without changing its proportions")
	check(minimum.x > 0 and minimum.y > 0 and maximum.x < 511 and maximum.y < 511, "Cropped PNG keeps transparent padding around the ink")
	var original_scale_size := root.content_scale_size
	root.content_scale_size = Vector2i(960, 800)
	root.size = Vector2i(960, 800)
	await frames(4)
	check(canvas.size.is_equal_approx(root.get_visible_rect().size), "Overlay follows a second window size")
	check(canvas.size.is_equal_approx(Vector2(960, 800)), "Resize exercises a different canvas aspect ratio")
	check(level.drawing_toolbar.get_global_rect().end.y <= canvas.size.y, "Toolbar fits within the resized viewport")
	check(canvas.snapshot_png() == png, "Window resize preserves the exact export")
	var horizontal: Vector2 = canvas._to_screen(Vector2(600, 180)) - canvas._to_screen(Vector2(200, 180))
	var vertical: Vector2 = canvas._to_screen(Vector2(200, 380)) - canvas._to_screen(Vector2(200, 180))
	check(is_equal_approx(horizontal.length() / vertical.length(), 2.0), "Resized on-screen ink keeps its proportions")
	await screenshot("drawing-resized")
	await pointer(Vector2(920, 30), true)
	await pointer(Vector2(920, 30), false)
	check(canvas._to_screen(canvas.strokes[-1][0]).distance_to(Vector2(920, 30)) < 0.1, "New strokes align with the pointer after resize")
	canvas.undo()
	root.content_scale_size = original_scale_size
	root.size = Vector2i(1152, 720)
	await frames(4)
	var saved: Array = canvas.strokes.duplicate(true)
	var cancel_center: Vector2 = level.drawing_cancel.get_global_rect().get_center()
	await pointer(cancel_center, true)
	await pointer(cancel_center, false)
	check(level.panel_mode == "" and canvas.strokes == saved, "Toolbar Cancel exits without drawing or discarding the draft")
	level.player.respawn(level.SPAWN)
	await frames(30)
	check(level.book.visible and level.book.disabled and not level.near_crossing(), "Leaving the river keeps the drawing entry visible but inactive")
	level._open_book()
	check(not level.drawing_overlay.visible, "Revisiting a discovered stage cannot open drawing outside its area")
	level.player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	level._open_book()
	await frames(3)
	check(canvas.strokes == saved, "Returning to the encounter restores its draft")
	await pointer(Vector2(20, 20), true)
	check(canvas.drawing, "A stroke can begin near the viewport edge")
	canvas._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not canvas.drawing, "Losing focus ends the stroke")
	await pointer(Vector2(20, 20), false)
	canvas.undo()
	var clear_center: Vector2 = level.clear_button.get_global_rect().get_center()
	await pointer(clear_center, true)
	await pointer(clear_center, false)
	check(not canvas.has_drawing(), "Toolbar Clear does not leave an accidental stroke")
	await pointer(Vector2(200, 300), true)
	await pointer_move(level.drawing_toolbar.get_global_rect().get_center())
	check(not canvas.drawing, "Moving a held stroke onto the toolbar ends it")
	await pointer(Vector2(200, 300), false)
	canvas.clear()

func joy_axis(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func joy_button(button: int, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)

func controller_checks() -> void:
	var player = level.player
	joy_axis(JOY_AXIS_LEFT_X, 0.1)
	await frames(3)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Stick drift inside deadzone produces no movement")
	joy_axis(JOY_AXIS_LEFT_X, 0.6)
	await frames(3)
	var partial_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(partial_speed > 0.1 and partial_speed < player.base_speed, "Partial stick tilt produces analog walking")
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	joy_axis(JOY_AXIS_LEFT_Y, 1.0)
	joy_button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(3)
	var full_speed := Vector2(player.velocity.x, player.velocity.z).length()
	check(absf(full_speed - player.sprint_speed) < 0.01, "Controller diagonal sprint reaches but does not exceed sprint speed")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	joy_axis(JOY_AXIS_LEFT_Y, 0.0)
	joy_button(JOY_BUTTON_RIGHT_SHOULDER, false)
	player.respawn(level.SPAWN)
	await frames(30)
	joy_button(JOY_BUTTON_DPAD_LEFT, true)
	await frames(3)
	check(Vector2(player.velocity.x, player.velocity.z).length() > 0.1, "D-pad moves the player")
	joy_button(JOY_BUTTON_DPAD_LEFT, false)
	joy_button(JOY_BUTTON_A, true)
	await frames(2)
	check(player.velocity.y > 0, "Controller south button jumps")
	joy_button(JOY_BUTTON_A, false)
	player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	joy_button(JOY_BUTTON_X, true)
	await frames(2)
	joy_button(JOY_BUTTON_X, false)
	check(level.drawing_overlay.visible and not player.input_enabled, "Controller west button opens the sketchbook and locks movement")
	joy_axis(JOY_AXIS_LEFT_X, 1.0)
	await frames(3)
	check(Vector2(player.velocity.x, player.velocity.z).length() < 0.01, "Stick cannot move player while sketchbook is open")
	joy_axis(JOY_AXIS_LEFT_X, 0.0)
	joy_button(JOY_BUTTON_B, true)
	await frames(2)
	joy_button(JOY_BUTTON_B, false)
	check(not level.drawing_overlay.visible and player.input_enabled, "Controller east button closes the sketchbook")
	joy_button(JOY_BUTTON_X, true)
	await frames(2)
	joy_button(JOY_BUTTON_X, false)
	check(root.gui_get_focus_owner() == level.drawing_cancel, "Opening a panel focuses its close button")
	joy_button(JOY_BUTTON_DPAD_UP, true)
	await frames(2)
	joy_button(JOY_BUTTON_DPAD_UP, false)
	check(root.gui_get_focus_owner() != level.drawing_cancel, "D-pad navigates panel buttons")
	level.drawing_cancel.grab_focus()
	joy_button(JOY_BUTTON_A, true)
	await frames(2)
	joy_button(JOY_BUTTON_A, false)
	await frames(2)
	check(not level.drawing_overlay.visible, "Controller accept activates the focused menu button")
	check(player.is_on_floor(), "Accepting a menu button does not also jump")
	level.restart()
	await frames(15)
