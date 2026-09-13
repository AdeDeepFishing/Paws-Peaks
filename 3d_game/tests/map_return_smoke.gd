extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")
var failed := false
var visual := "--visual" in OS.get_cmdline_user_args()

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	var journey := root.get_node("Journey")
	JourneyTest.fast(self)
	change_scene_to_file(journey.STAGES[0])
	await scene_changed
	await frames(50)
	var river := current_scene
	var position: Vector3 = river.player.position
	var worker := root.get_node("GenerationWorker")
	if visual:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/map53-back-button.png")
	# Preserve both encounter state and an in-memory drawing across repeated visits.
	river.current_item = {"name": "Saved bridge"}
	river.current_png = PackedByteArray([1, 2, 3])
	river.unlocked = true
	for visit in 2:
		river.map_button.pressed.emit()
		check(journey.browse_map() == ERR_BUSY, "Duplicate map opening is rejected")
		for i in 600:
			await frames(1)
			if journey.phase == "start": break
		check(current_scene.name == "Overworld" and is_instance_valid(river), "Map browsing retains the existing chapter")
		check(not river.visible and not river.hud.visible and river.process_mode == Node.PROCESS_MODE_DISABLED, "The retained chapter is hidden and paused")
		check(current_scene.start_button.text == "Return to chapter  →" and current_scene.zoom_controls.visible, "Map offers return and zoom even in Chapter 1")
		check(journey.page_material.get_shader_parameter("previous_page") == true, "Back to map turns to the previous page from the left")
		var map := current_scene
		map.zoom_slider.value = 1.0
		await frames(60)
		check(journey.phase == "start" and river.player.position == position, "Browsing waits without advancing or moving the player")
		if visual:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/map53-return-map.png")
		map.start_button.pressed.emit()
		await JourneyTest.complete(self)
		check(journey.page_material.get_shader_parameter("previous_page") == false, "Return to chapter restores the forward page direction")
		check(current_scene == river and not is_instance_valid(map), "Return restores the exact chapter and releases the map")
		check(river.current_item.name == "Saved bridge" and river.current_png == PackedByteArray([1, 2, 3]) and river.unlocked, "Drawing and encounter state survive")
		check(river.visible and river.hud.visible and river.player.position.distance_to(position) < 0.01, "Return restores HUD and player position")
		check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "No hidden map or chapter is leaked after return")
	river.request.state = "PENDING"
	check(journey.browse_map() == ERR_BUSY, "An active generation cannot be paused through map browsing")
	river.request.state = "IDLE"
	check(root.get_node("GenerationWorker") == worker and journey.visited_chapters == [1], "Browsing retains the worker and does not advance chapter counts")
	print("MAP RETURN SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
