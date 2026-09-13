extends SceneTree

const Level = preload("res://scenes/river/river_crossing.tscn")
const Model = preload("res://scripts/river/generated_model.gd")
var failed := false
var early_events: Array[String] = []

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
	var worker = root.get_node("GenerationWorker")
	check(worker.is_running(), "Worker starts before any submission")
	var worker_pid: int = worker.process_id
	level.generation.interpretation_ready.connect(func(_id: String, item: Dictionary):
		check(level.request.state == "PENDING" and item.has("name"), "Interpretation arrives before completion")
		early_events.append("item"))
	level.generation.reference_image_ready.connect(func(_id: String, path: String):
		check(level.request.state == "PENDING" and FileAccess.file_exists(path), "Reference arrives before completion")
		early_events.append("image"))
	var image := Image.new()
	level.surface.strokes.append(PackedVector2Array([Vector2(100, 100), Vector2(300, 200)]))
	image.load_png_from_buffer(level.surface.snapshot_png())
	check(image.get_pixel(0, 0).a == 0.0, "Transport input has transparent background")
	check(level.request.submit(image.save_png_to_buffer(), "E01"), "Submit starts a desktop request")
	var deadline := Time.get_ticks_msec() + 15000
	while level.request.state == "PENDING" and Time.get_ticks_msec() < deadline:
		await create_timer(0.1).timeout
	check(early_events == ["item", "image"], "Early results arrive exactly once in order")
	check(worker.process_id == worker_pid and worker.is_running(), "Worker survives completion")
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
	sent_image.load(level.generation.job_dir.path_join("request/input.png"))
	check(sent_image.get_pixel(0, 0).a == 0.0, "Python receives PNG with alpha preserved")
	level.player.respawn(Vector3(-4.8, 1.6, -6.0))
	for i in 30: await physics_frame
	Input.action_press("move_right")
	for i in 180:
		level.player.window_focused = true
		await physics_frame
	Input.action_release("move_right")
	check(level.completed, "Single-key crossing works with the actual generated GLB")
	var submitted = JSON.parse_string(FileAccess.get_file_as_string(level.generation.job_dir.path_join("request/claimed.json")))
	check(submitted.game_stage == "river", "Game sends the river stage label")
	var old_status = JSON.parse_string(FileAccess.get_file_as_string(level.generation.job_dir.path_join("status.json")))
	check(FileAccess.file_exists(level.generation.job_dir.path_join("response/results.jsonl")), "Response history lives in response folder")
	check(level.request.model_path.begins_with(level.generation.job_dir.path_join("response") + "/"), "Generated asset lives in response folder")
	check(old_status.request_received_at <= old_status.response_received_at, "Arrival timestamps are present and ordered")
	level.restart()
	check(not is_instance_valid(level.generated_visual), "Restart removes generated model")
	check(level.get_node("Bridge/Deck/CollisionShape3D").shape.size.z == 2.0, "Restart restores default collision width")
	check(level.request.submit(image.save_png_to_buffer(), "E01"), "Second submission starts")
	level.generation.consume_status(old_status)
	check(level.request.state == "PENDING", "Stale result is ignored")
	var wrong_stage: Dictionary = old_status.duplicate(true)
	wrong_stage.request_id = level.request.active_id
	wrong_stage.game_stage = "dog"
	level.generation.consume_status(wrong_stage)
	check(level.request.state == "PENDING", "Wrong-stage response is ignored")
	level.request.cancel()
	check(worker.process_id == worker_pid and worker.is_running(), "Cancel preserves listener")
	level.generation.consume_status(old_status)
	check(not level.bridge_built, "Canceled result cannot build a bridge")

	check(Model.load_visual("res://project.godot", 10.4, true) == null, "Invalid GLB is rejected")
	level.queue_free()
	await process_frame
	check(worker.process_id == worker_pid and worker.is_running(), "Listener survives scene removal")
	print("DESKTOP GENERATION SMOKE: " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
