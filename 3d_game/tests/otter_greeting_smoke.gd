extends SceneTree
var failed := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String):
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-otter-" + label + ".png")
func run():
	var level = load("res://scenes/sunset_cove/sunset_cove.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	var otter = level.get_node("Otter")
	check(otter.grounded, "Otter starts grounded")
	var library: AnimationLibrary = otter.animator.get_animation_library("otter")
	check(library.get_animation_list().size() == 13, "One model has all 13 full animations")
	for i in 180:
		if not level.entering: break
		await frames(1)
	check(otter.phase == "waving" and otter.animator.current_animation == otter.WAVE, "Player arrival triggers a greeting wave")
	await capture("wave")
	level.player.set_physics_process(false)
	level.player.global_position = otter.global_position + Vector3(0, 0, 1.7)
	await frames(40)
	check(otter.phase == "idle" and otter.animator.current_animation == otter.IDLE, "Approaching interrupts the wave and returns to idle")
	var facing: Vector3 = otter.global_basis.z
	check(facing.dot(Vector3.BACK) > 0.98, "Otter turns to face the approaching player")
	await capture("idle")
	level.player.global_position = otter.global_position + Vector3(0, 0, 6)
	await frames(2)
	check(otter.phase == "waving", "Otter waves again when the player steps away")
	otter.animator.seek(otter.animator.current_animation_length - 0.01, true)
	await frames(4)
	check(otter.phase == "waving" and otter.animator.is_playing() and otter.animator.current_animation_position < 0.5, "Wave repeats at the end of the clip")
	level.player.global_position = otter.global_position + Vector3(0, 0, 12)
	await frames(2)
	check(otter.phase == "waving", "Otter keeps waving beyond the old greeting range")
	check(otter.animation_options.size() == 13, "All animation descriptions are saved as choices")
	otter.play_option("Idle_11")
	level._open_drawing()
	check(not level.drawing, "Drawing stays locked outside otter interaction range")
	level.player.global_position = otter.global_position + Vector3(0, 0.2, 1.7)
	await frames(2)
	level._open_drawing()
	check(level.drawing, "Player can draw after approaching the otter")
	await capture("drawing")
	level.generation.configure(1)
	var payloads: Array[Dictionary] = []
	level.request.request_prepared.connect(func(payload: Dictionary): payloads.append(payload))
	var center: Vector2 = level.camera.unproject_position(Vector3(0, 0.3, 5))
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([center - Vector2(20, 35), center + Vector2(20, 0)]))
	level._submit()
	check(payloads.size() == 1, "A nearby sketch produces exactly one request")
	if not payloads.is_empty():
		check(payloads[0].encounter_id == "E04" and payloads[0].game_stage == "otter", "Sketch has the Stage 4 routing labels")
		check(payloads[0].animation_options == otter.animation_options, "Request includes the saved animation choices")
		var folder: String = level.generation.job_dir.path_join("request")
		var envelope_path := folder.path_join("request.json")
		if not FileAccess.file_exists(envelope_path): envelope_path = folder.path_join("claimed.json")
		var envelope = JSON.parse_string(FileAccess.get_file_as_string(envelope_path))
		check(envelope is Dictionary and envelope.get("animation_options") == otter.animation_options, "Desktop mailbox preserves animation options")
		check(not level.drawing, "Submitting closes drawing and releases player controls")
		check(otter.phase == "waiting", "Otter looks confused during generation")
		level.request.cancel()
		check(otter.phase == "idle", "Cancel stops the confused animation")
		check(level.surface.has_drawing(), "Canceling preserves the sketch for retry")
	level.generation.configure(0)
	level.request.mock_mode = false
	check(level.request.submit(level.surface.snapshot_png(), "E04"), "Offline reaction test submits a sketch")
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	var item := {"name": "Bone", "description": "A bone to examine.", "movable": true, "texture_key": "bone", "color": "#E8D9B7"}
	var response := {"schema_version": 1, "request_id": level.request.active_id, "encounter_id": "E04", "game_stage": "otter", "stage": "reference_image", "status": "PENDING", "item": item, "reaction": "Shrug"}
	level.generation.consume_status(response)
	check(otter.phase == "waiting" and otter.animator.current_animation == "otter/Confused_Scratch", "Early interpretation keeps the confused look until rendering")
	otter.animator.seek(otter.animator.current_animation_length - 0.01, true)
	await frames(3)
	check(otter.phase == "waiting" and otter.animator.is_playing(), "Confused animation repeats while waiting")
	await capture("confused")
	var model_path: String = level.generation.job_dir.path_join("reaction-test.glb")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb"), model_path)
	response.merge({"stage": "complete", "status": "SUCCEEDED", "model_path": model_path}, true)
	level.generation.consume_status(response)
	await frames(4)
	check(is_instance_valid(level.offered) and otter.phase == "reacting" and otter.animator.current_animation == "otter/Shrug", "Rendered model triggers the returned reaction")
	check(not level.surface.has_drawing(), "Rendered model clears the original sketch")
	await capture("reaction")
	await frames(150)
	check(otter.phase == "idle", "Selected reaction returns to idle")
	var previous_id: String = level.request.active_id
	var previous_model = level.offered
	level._open_drawing()
	check(level.drawing and level.request.state == "IDLE" and not level.surface.has_drawing(), "Draw again opens a fresh canvas after success")
	level.surface.reference_size = level.surface.size
	center = level.camera.unproject_position(Vector3(0, 0.3, 6))
	level.surface.strokes.append(PackedVector2Array([center - Vector2(15, 30), center + Vector2(15, 0)]))
	level._submit()
	check(level.request.state == "PENDING" and level.request.active_id != previous_id, "Second drawing creates a fresh Stage 4 request")
	check(otter.phase == "waiting", "Second drawing starts confused waiting again")
	check(is_instance_valid(previous_model), "Previous object stays while the next drawing generates")
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	level.generation.partial_item = {}
	response.request_id = previous_id
	level.generation.consume_status(response)
	check(level.request.state == "PENDING", "Previous request cannot complete a new drawing")
	response.request_id = level.request.active_id
	response.reaction = "Big_Wave_Hello"
	level.generation.consume_status(response)
	await frames(4)
	check(level.request.state == "READY" and otter.animator.current_animation == "otter/Big_Wave_Hello", "Second drawing renders and plays its own reaction")
	check(not is_instance_valid(previous_model) and is_instance_valid(level.offered), "Second successful model replaces the previous one")

	var png := Image.create(512, 512, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	level.request.submit(png, "E04")
	level.request.fail_current("Offline test failure")
	check(otter.phase == "idle", "Generation failure stops the confused look")
	print("OTTER GREETING SMOKE: ", "FAIL" if failed else "PASS")
	level.queue_free()
	await frames(2)
	quit(1 if failed else 0)
