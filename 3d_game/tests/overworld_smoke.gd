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
	await JourneyTest.complete(self)
	check(current_scene.name == "RiverCrossing" and journey.current_stage == 1, "F5 map intro enters the river automatically")
	check(not current_scene.completed and not current_scene.bridge_built, "The intro does not solve the river")
	for stage in range(2, 6):
		var previous := current_scene
		check(journey.travel_to(journey.STAGES[stage - 1]) == OK, "Next chapter is accepted")
		check(journey.travel_to(journey.STAGES[stage - 1]) == ERR_BUSY, "Duplicate transitions are rejected")
		if not await until_phase("browse"):
			quit(1)
			return
		var map := current_scene
		check(not is_instance_valid(previous), "Returning to the map frees the previous stage")
		check(map.name == "Overworld" and map.phase == "browse", "Each transition stops on the map")
		check(map.next_button.visible and not map.next_button.disabled, "Next page is available")
		check(map.materials.size() == 36, "One geometry uses all 36 shared palette materials")
		check(map.stars.size() == 90, "Night sky retains the supplied star layout")
		var expected := Vector3(0, 0, 1) if stage == 5 else (Vector3(0, 1, 0) if stage >= 3 else Vector3(1, 0, 0))
		check(map.palette_weights.is_equal_approx(expected), "Only E02→E03 and E04→E05 change the map time")
		check(map.hero.position.distance_to(map.RouteData.STAGES[stage - 1]) < 0.25, "The traveler reaches the authored stage point")
		check(map.hero.state == "idle", "The traveler stops walking on arrival")
		check(map.art.find_children("*", "AnimationPlayer", true, false).filter(func(player): return player.is_playing()).size() == 3, "Wind, water and clouds animate together")
		var close: Transform3D = map.camera.transform
		var wheel := InputEventMouseButton.new()
		wheel.position = Vector2(20, 200)
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel)
		await frames(1)
		check(map.zoom_target < 1.0, "Mouse-wheel input reaches map inspection")
		map.set_zoom(-20)
		await frames(45)
		check(map.zoom_target == 0.0 and map.camera.position.distance_to(close.origin) > 20, "Inspection zoom clamps at the full map")
		check(current_scene == map and journey.busy, "Waiting and zooming never advance the chapter")
		map.set_zoom(20)
		await frames(45)
		check(map.zoom_target == 1.0 and map.camera.position.distance_to(close.origin) < 0.1, "Inspection zoom clamps at the player")
		# Keyboard confirmation uses the focused Next page button.
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.pressed = true
		root.push_input(key)
		key = key.duplicate()
		key.pressed = false
		root.push_input(key)
		map.next_button.pressed.emit()
		await JourneyTest.complete(self)
		check(current_scene.scene_file_path == journey.STAGES[stage - 1], "Next page enters exactly the requested chapter")
		check(current_scene.process_mode == Node.PROCESS_MODE_INHERIT, "Gameplay resumes after the page turn")
		check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Only one world remains active")
		check(not journey.page.visible and journey.page.texture == null and not journey.input_blocker.visible, "Transition snapshots and input blockers are released")
	check(root.get_node("GenerationWorker") == worker, "All five chapters retain the same AI worker without submitting jobs")
	# Restart after night is a fresh automatic day intro, with no retained browse UI.
	journey.start_intro()
	await JourneyTest.complete(self)
	check(current_scene.name == "RiverCrossing" and journey.current_stage == 1, "Restart returns to the first chapter")
	check(not current_scene.completed and not current_scene.bridge_built, "Restart clears encounter progress")
	current_scene.queue_free()
	current_scene = null
	await frames(6)
	print("OVERWORLD FLOW SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
