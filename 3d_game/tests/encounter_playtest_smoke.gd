extends "res://tests/bird_encounter_smoke.gd"

func actor_in_frame(level, point: Vector3, label: String):
	var camera: Camera3D = level.camera
	check(not camera.is_position_behind(point) and root.get_visible_rect().grow(-24).has_point(camera.unproject_position(point)), label + " remains in the presentation frame")

func run():
	visual = "--visual" in OS.get_cmdline_user_args()
	var level = fresh()
	await frames(50)
	check(is_equal_approx(level.bird.visual.get_child(0).scale.x, 2.8), "Bird is 30 percent smaller")
	level._open_drawing()
	var initial: Vector3 = level.bird.visual.position
	await frames(40)
	check(initial.distance_to(level.bird.visual.position) > 0.5 and level.bird.animators[0].speed_scale > 0, "Drawing keeps flight and flapping active")
	await capture("drawing-flight")
	level._close_drawing()
	level.bird.set_process(false)
	level.bird.visual.position = level.player.position + Vector3(5, 9, 0)
	level.bird._enter("circling")
	level.bird.elapsed = 2.99
	level.bird._process(0.02)
	var from: Vector3 = level.bird.visual.position
	for i in 32: level.bird._process(1.0 / 60.0)
	check(level.bird.visual.position.y < from.y - 0.2, "Swoop descends toward the protagonist")
	check(level.bird.visual.basis.z.normalized().y < -0.1, "Bird faces downward along its dive")
	level.bird.set_process(true)
	level.request.mock_delay = 60
	level._open_drawing()
	sketch(level)
	level._submit()
	check(await wait_for(func(): return level.presentation.phase == "waiting", 4), "Sketch framing settles")
	actor_in_frame(level, level.player.global_position, "Protagonist feet")
	actor_in_frame(level, level.player.global_position + Vector3.UP * 3.3, "Protagonist head")
	actor_in_frame(level, level.sketch_anchor, "Object landing")
	var sight := PhysicsRayQueryParameters3D.create(level.camera.global_position, level.player.global_position + Vector3.UP * 1.5, level.GROUND_MASK)
	check(level.get_world_3d().direct_space_state.intersect_ray(sight).is_empty(), "The terrain does not hide the protagonist during sketch framing")
	await capture("group-focus")
	# Feed an ordinary backend completion through the actual desktop adapter.
	# A successful but unsuitable item must still display its returned GLB.
	level.request.mock_mode = false
	var source_path := ProjectSettings.globalize_path("res://../docs/test-artifacts/stage3-2026-09-13/model.glb").simplify_path()
	if not OS.get_environment("PAWS_REPLAY_MODEL").is_empty(): source_path = OS.get_environment("PAWS_REPLAY_MODEL")
	var mailbox := "/private/tmp/paws59-status-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(mailbox)
	var path := mailbox.path_join("model.glb")
	check(DirAccess.copy_absolute(source_path, path) == OK, "Local replay uses an isolated test mailbox")
	level.generation.job_dir = mailbox
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	if not visual:
		level.player.velocity.y = 4.0
		await frames(3)
	level.generation.consume_status({"schema_version":1, "request_id":level.request.active_id, "encounter_id":"E03", "game_stage":"crows", "status":"SUCCEEDED", "stage":"complete", "item":{"name":"Unusual object", "description":"An object that does not provide protection.", "type":"UNKNOWN", "movable":true}, "model_path":path})
	if not visual:
		check(await wait_for(func(): return level.player.is_on_floor(), 3), "Airborne completion waits for a safe landing")
		level._open_drawing()
	check(await wait_for(func(): return is_instance_valid(level.offered) and level.offered.visible, 4), "Successful non-defence generation displays its 3D model: " + level.request.message)
	check(await wait_for(func(): return not level.presentation.active, 4), "Unsuitable result restores camera")
	await capture("unsuitable-model")
	check(not level.can_exit() and not level.resolving, "Showing an unsuitable object never solves the encounter")
	check(not level.generation_preview.visible, "The completed model replaces the sketch")
	level._open_drawing()
	check(level.drawing, "The player can retry after seeing an unsuitable model")
	sketch(level)
	level._submit()
	check(level.offered == null, "A new submission replaces the previous preview instead of accumulating models")
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	level.generation.consume_status({"schema_version":1, "request_id":level.request.active_id, "encounter_id":"E03", "game_stage":"crows", "status":"SUCCEEDED", "stage":"complete", "item":{"name":"Umbrella", "description":"Protective canopy.", "type":"DEFENCE", "movable":true}, "model_path":path})
	check(await wait_for(func(): return is_instance_valid(level.offered) and level.offered.visible, 4), "Supported completion displays its generated model")
	await frames(20)
	await capture("supported-model")
	check(await wait_for(func(): return level.bird.phase == "blocked", 8), "Supported protection still triggers the bird reaction")
	await capture("group-protection")
	check(await wait_for(func(): return level.solved, 7), "A supported retry clears the encounter")
	level.queue_free()
	await frames(3)
	DirAccess.remove_absolute(path)
	if FileAccess.file_exists(mailbox.path_join("cancel")): DirAccess.remove_absolute(mailbox.path_join("cancel"))
	DirAccess.remove_absolute(mailbox)
	print("ENCOUNTER PLAYTEST SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
