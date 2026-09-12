extends SceneTree

const Level = preload("res://scenes/river/river_crossing.tscn")
const Model = preload("res://scripts/river/generated_model.gd")
var failed := false

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level = Level.instantiate()
	level.auto_advance = false
	level.get_node("EncounterPresentation").duration_scale = 0.01
	root.add_child(level)
	await process_frame
	var image := Image.new()
	level.surface.strokes.append(PackedVector2Array([Vector2(100, 100), Vector2(300, 200)]))
	image.load_png_from_buffer(level.surface.snapshot_png())
	check(image.get_pixel(0, 0).a == 0.0, "Transport input has transparent background")
	check(level.request.submit(image.save_png_to_buffer(), "E01"), "Submit starts a desktop request")
	var deadline := Time.get_ticks_msec() + 15000
	while level.request.state == "PENDING" and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	check(level.request.state == "READY", "Fixture reaches READY: " + level.request.message)
	if level.presentation.busy:
		await level.presentation.settled
	check(level.bridge_built, "Returned model automatically enables crossing")
	check(is_instance_valid(level.generated_visual), "Actual GLB appears in scene")
	check(not level.get_node("Bridge/Deck/Visual").visible, "Placeholder is hidden")
	if is_instance_valid(level.generated_visual):
		check(absf(Model._bounds(level.generated_visual).size.x - 10.4) < 0.01, "Model fits authored crossing")
	check(FileAccess.file_exists(level.request.model_path), "Returned GLB file exists")
	if "--visual" in OS.get_cmdline_user_args():
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-generated-model.png")
	var sent_image := Image.new()
	sent_image.load(level.generation.job_dir.path_join("input.png"))
	check(sent_image.get_pixel(0, 0).a == 0.0, "Python receives PNG with alpha preserved")
	level.player.respawn(Vector3(-4.8, 1.6, -6.0))
	for i in 30: await physics_frame
	Input.action_press("move_right")
	for i in 180:
		level.player.window_focused = true
		await physics_frame
	Input.action_release("move_right")
	check(level.completed, "Single-key crossing works with the actual generated GLB")
	var old_status = JSON.parse_string(FileAccess.get_file_as_string(level.generation.job_dir.path_join("status.json")))
	level.restart()
	check(not is_instance_valid(level.generated_visual), "Restart removes generated model")
	check(level.get_node("Bridge/Deck/CollisionShape3D").shape.size.z == 2.0, "Restart restores default collision width")
	check(level.request.submit(image.save_png_to_buffer(), "E01"), "Second submission starts")
	level.generation.consume_status(old_status)
	check(level.request.state == "PENDING", "Stale result is ignored")
	level.request.cancel()
	check(level.generation.process_id == -1, "Cancel stops local worker")
	level.generation.consume_status(old_status)
	check(not level.bridge_built, "Canceled result cannot build a bridge")
	level.generation.backend_directory = "/does-not-exist"
	level.request.submit(image.save_png_to_buffer(), "E01")
	check(level.request.state == "FAILED", "Missing backend fails without a mock fallback")
	check(Model.load_visual("res://project.godot", 10.4, true) == null, "Invalid GLB is rejected")
	level.queue_free()
	await process_frame
	print("DESKTOP GENERATION SMOKE: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
