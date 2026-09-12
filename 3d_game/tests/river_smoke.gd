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
	level.drawing_export_directory = "user://test-drawings/river-smoke"
	root.add_child(level)
	await frames(30)
	check(level.player.is_on_floor(), "Player spawns on the near bank")
	check(not level.unlocked, "Sketchbook starts hidden before approaching the river")
	await screenshot("world")
	await fixed_camera_checks()
	level.player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	check(level.unlocked, "Entering the river area unlocks the sketchbook")
	check(absf(level.book.get_global_rect().end.x - 1124.0) < 1.0, "Sketchbook stays anchored to the lower-right margin")
	await screenshot("book")
	level._open_book()
	await frames(2)
	check(level.modal.visible and not level.player.input_enabled, "Opening the book releases gameplay input")
	var locked_camera: Transform3D = level.get_node("StageCamera").global_transform
	var locked_motion := InputEventMouseMotion.new()
	locked_motion.relative = Vector2(200, 100)
	Input.parse_input_event(locked_motion)
	check(level.get_node("StageCamera").global_transform == locked_camera, "Drawing leaves the fixed camera unchanged")
	var before: Vector3 = level.player.position
	Input.action_press("move_up")
	Input.action_press("jump")
	await frames(8)
	Input.action_release("move_up")
	Input.action_release("jump")
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
	check(bitmap.get_pixel(80, 210).r < 0.5, "Export contains the player's ink")
	check(bitmap.get_pixel(0, 0).r > 0.9, "Export has a light background")
	canvas.undo()
	check(not canvas.has_drawing(), "Undo removes the complete stroke")
	canvas.strokes.append(PackedVector2Array([Vector2(90, 210), Vector2(410, 210), Vector2(410, 260), Vector2(90, 260), Vector2(90, 210)]))
	canvas.strokes.append(PackedVector2Array([Vector2(120, 260), Vector2(120, 340)]))
	canvas.strokes.append(PackedVector2Array([Vector2(380, 260), Vector2(380, 340)]))
	canvas.queue_redraw()
	canvas.changed.emit()
	await frames(12)
	await screenshot("drawing")
	level.request.mock_mode = false
	var delivered: Array[Dictionary] = []
	level.request.request_prepared.connect(func(payload): delivered.append(payload))
	level._submit()
	check(level.request.state == "PENDING", "Submit starts a background request")
	check(not level.modal.visible and level.player.input_enabled, "Submit restores exploration")
	check(delivered.size() == 1 and delivered[0].encounter_id == "E01", "Integration signal carries encounter context")
	check(Marshalls.base64_to_raw(delivered[0].image_base64) == level.request.snapshot, "Payload contains the exact immutable PNG")
	var saved: PackedByteArray = level.request.snapshot.duplicate()
	canvas.clear()
	check(level.request.snapshot == saved, "Editing the draft cannot mutate the submitted PNG")
	check(not level.request.submit(png, "E01"), "A second request cannot replace a pending request")
	var id: String = level.request.active_id
	check(not level.request.accept_response(response("old-request")), "Late responses for another request are ignored")
	level.player.position = Vector3(-8, 1.5, -4)
	await frames(8)
	check(level.collected.size() == 1, "Coins can be collected while a request is pending")
	level.player.position.y = -3
	await frames(8)
	check(level.collected.size() == 1 and level.request.active_id == id, "Fall recovery preserves coins and request identity")
	level.request.accept_response(response(id))
	check(level.request.state == "READY" and not level.modal.visible, "Ready response does not open a modal")
	check(not level.build_bridge(), "A bridge cannot be applied away from its encounter")
	level.player.respawn(Vector3(-4.6, 1.5, -6.3))
	await frames(30)
	level._open_book()
	await frames(12)
	await screenshot("result")
	check(level.build_bridge(), "Supported idea builds the bridge at the river")
	check(not level.build_bridge() and level.current_item.durability == 2, "Use is idempotent and spends durability once")
	await frames(3)
	check(not level.get_node("Bridge/Deck/CollisionShape3D").disabled, "The generated bridge has walkable collision")
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
		print("PASS: fixed camera, scene collision, movement, drawing PNG, request lifecycle, and physical crossing")
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
