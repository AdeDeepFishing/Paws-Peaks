extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")
var failed := false
var journey: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func until_phase(expected: String) -> bool:
	for i in 1800:
		await frames(1)
		if journey.phase == expected: return true
	check(false, "Timed out waiting for " + expected)
	return false

func run() -> void:
	journey = root.get_node("Journey")
	JourneyTest.fast(self)
	var worker := root.get_node("GenerationWorker")
	change_scene_to_file(journey.MAP)
	await scene_changed
	if not await until_phase("start"):
		quit(1)
		return
	var opening := current_scene
	check(opening.start_button.visible and not opening.start_button.disabled, "The opening offers Play at the hero closeup")
	check(opening.hero.position.distance_to(opening.RouteData.STAGES[0]) < 0.25, "Opening focuses on the hero at Chapter 1")
	var close: Transform3D = opening.camera.transform
	await frames(90)
	check(current_scene == opening and journey.phase == "start", "Waiting never enters the river without Play")
	check(opening.camera.transform.is_equal_approx(close), "The opening holds the hero closeup")
	# Confirm using the focused CTA, then simulate a duplicate button event.
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	key = key.duplicate()
	key.pressed = false
	root.push_input(key)
	await frames(1)
	check(journey.phase != "start", "Keyboard confirmation activates Play")
	if is_instance_valid(opening): opening.start_button.pressed.emit()
	await JourneyTest.complete(self)
	check(current_scene.name == "RiverCrossing" and journey.current_stage == 1, "Play enters the first chapter once")
	check(not current_scene.completed and not current_scene.bridge_built, "Play does not solve the river")
	for stage in range(2, 6):
		var previous := current_scene
		check(journey.travel_to(journey.STAGES[stage - 1]) == OK, "Next chapter is accepted")
		check(journey.travel_to(journey.STAGES[stage - 1]) == ERR_BUSY, "Duplicate transitions are rejected")
		for i in 1800:
			await frames(1)
			if not journey.busy or journey.phase == "start": break
			if current_scene != null and current_scene.name == "Overworld":
				check(not current_scene.start_button.visible or current_scene.start_button.disabled, "The CTA cannot activate during the route animation")
		# Inspect the settled arrival: accelerated timing may finish the brief
		# arrival phase between physics/process samples.
		var map := current_scene
		check(map.materials.size() == 36, "All palette materials are present")
		check(map.stars.size() == 90, "Night sky retains the supplied star layout")
		var expected := Vector3(0, 0, 1) if stage == 5 else (Vector3(0, 1, 0) if stage >= 3 else Vector3(1, 0, 0))
		check(map.palette_weights.is_equal_approx(expected), "Day changes only before Chapter 3 and Chapter 5")
		check(map.hero.position.distance_to(map.RouteData.STAGES[stage - 1]) < 0.25, "Traveler reaches the authored chapter point")
		check(map.hero.state == "idle", "Traveler stops at the destination")
		check(map.art.find_children("*", "AnimationPlayer", true, false).filter(func(player): return player.is_playing()).size() == 3, "Wind, water and clouds animate together")
		check(journey.phase == "start", "Every later arrival waits for confirmation")
		var waiting := current_scene
		check(waiting.start_button.text == "Play" and waiting.start_button.visible, "Later maps offer the Play CTA")
		check(not journey.input_blocker.visible, "Map browsing is available while waiting")
		await frames(90)
		check(current_scene == waiting and journey.phase == "start", "Waiting never enters the next chapter automatically")
		var zoom := InputEventMouseButton.new()
		zoom.position = Vector2(400, 180)
		zoom.button_index = MOUSE_BUTTON_WHEEL_DOWN
		zoom.pressed = true
		zoom.factor = 20
		root.push_input(zoom, true)
		await frames(60)
		check(waiting.zoom_target == 1.0 and waiting.zoom_amount <= 1.0, "Zoom out is bounded at the full map")
		check(waiting.camera.position.distance_to(waiting._full_transform().origin) < 0.05, "Zoom out shows the full map")
		zoom.button_index = MOUSE_BUTTON_WHEEL_UP
		root.push_input(zoom, true)
		await frames(60)
		check(waiting.zoom_target == 0.0 and waiting.zoom_amount >= 0.0, "Zoom in is bounded at the player")
		check(waiting.camera.position.distance_to(waiting._close_transform(stage).origin) < 0.05, "Zoom in returns to the current chapter")
		waiting.start_button.pressed.emit()
		waiting.start_button.pressed.emit()
		await JourneyTest.complete(self)
		check(not journey.busy and current_scene.scene_file_path == journey.STAGES[stage - 1], "A single confirmation enters the chosen chapter")
		check(not is_instance_valid(previous), "The previous stage is released")
		check(current_scene.process_mode == Node.PROCESS_MODE_INHERIT, "Gameplay resumes after the page turn")
		check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Only one world remains active")
		check(not journey.page.visible and journey.page.texture == null and not journey.input_blocker.visible, "Transition snapshots and input blockers are released")
	check(root.get_node("GenerationWorker") == worker, "All five chapters retain the same AI worker without submitting jobs")
	check(journey.visited_chapters == [1, 2, 3, 4, 5], "Journal records actual chapter visits once")
	# Restart after night returns to the daylight Start screen.
	journey.start_intro()
	if not await until_phase("start"):
		quit(1)
		return
	check(current_scene.palette_weights == Vector3(1, 0, 0), "Restart resets the map to day")
	check(journey.visited_chapters.is_empty() and journey.sketches_shared == 0, "A new journey clears the session journal before Start")
	await frames(30)
	check(journey.phase == "start", "Restart also waits for Start")
	await JourneyTest.complete(self)
	check(current_scene.name == "RiverCrossing" and journey.current_stage == 1, "Restart returns to the first chapter")
	check(not current_scene.completed and not current_scene.bridge_built, "Restart clears encounter progress")
	current_scene.queue_free()
	current_scene = null
	await frames(6)
	print("OVERWORLD FLOW SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
