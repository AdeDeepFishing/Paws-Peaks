extends SceneTree

var failed := false
var route_done := false

func _initialize() -> void: run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func animate_route(map: Node, from: int, to: int, timing: float) -> void:
	route_done = false
	await map.play_route(from, to, timing)
	route_done = true

func run() -> void:
	var map = load("res://scenes/overworld/overworld.tscn").instantiate()
	map.autoplay = false
	root.add_child(map)
	current_scene = map
	var original_camera: Transform3D = map.camera.transform
	animate_route(map, 0, 1, 1.0)
	await create_timer(2.35).timeout
	check(map.phase == "overview" and not map.hero.visible, "Opening holds the panoramic title before the hero enters")
	check(map.camera.transform.is_equal_approx(original_camera), "Camera holds for the first 2.5 seconds")
	check(not map.start_button.visible, "Opening has no clickable Play before its entrance")
	check(not map.title_lines[1].no_depth_test, "Mountains can occlude the title")
	await create_timer(.35).timeout
	check(map.phase == "zoom_in" and map.start_button.disabled, "Play enters with the paper but is disabled during zoom")
	check(map.chapter_card.progress > 0 and map.chapter_card.progress < 1, "Chapter paper enters progressively")
	for i in 600:
		if route_done: break
		await process_frame
	check(route_done and map.hero.visible, "Hero finishes the walk from below")
	check(map.hero.position.distance_to(map.RouteData.STAGES[0]) < .25, "Hero stops at the first marker")
	check(is_equal_approx(map.title_progress, 1), "Title finishes shrinking into the corner")
	for stage in range(1, 6):
		if stage > 1:
			map.configure(stage - 1, stage)
			await map.play_route(stage - 1, stage, .01)
		map.await_start(stage)
		check(not map.start_button.disabled and map.start_button.text == "Play", "Each chapter waits with an enabled Play")
		check(map.chapter_card.title.text == map.chapter_card.TITLES[stage - 1], "Each chapter uses its supplied title")
		check(map.chapter_card.paper.get_global_rect().encloses(map.start_button.get_global_rect()), "Play stays within the curved paper")
		check(map.find_children("*", "HSlider", true, false).is_empty(), "Map has no visible zoom slider")
		var zoom_key := InputEventKey.new()
		zoom_key.keycode = KEY_MINUS
		zoom_key.pressed = true
		root.push_input(zoom_key, true)
		check(map.zoom_target > 0, "Keyboard zoom works in every chapter, including Chapter I")
		var pinch := InputEventMagnifyGesture.new()
		pinch.factor = 2.0
		root.push_input(pinch, true)
		check(map.zoom_target == 0, "Pinching returns to the player without passing the close limit")
		map.start_button.pressed.emit()
		await process_frame
	map.queue_free()
	current_scene = null
	await process_frame
	var book = load("res://scripts/ending/ending_book.gd").new()
	root.add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var chapters: Array[int] = [1, 2, 3, 4, 5]
	book.set_memory(null, chapters, 7)
	check(book.end_page.visible and not book.content.visible, "Ending opens on the supplied The End art")
	book.memories.pressed.emit()
	check(book.content.visible and not book.end_page.visible, "Your journey opens the original recap")
	check(book.chapters_value.text == "5 / 5" and book.sketches_value.text == "7", "Recap retains the session totals")
	book.memory_back.pressed.emit()
	check(book.end_page.visible and not book.content.visible, "Back returns to The End without losing the recap")
	book.set_actions_enabled(false)
	check(book.replay.disabled and book.memory_replay.disabled and book.memories.disabled, "Both ending pages block actions during transitions")
	book.set_actions_enabled(true)
	var actions := []
	book.replay_requested.connect(func(): actions.append("replay"))
	book.explore_requested.connect(func(): actions.append("explore"))
	book.replay.pressed.emit()
	book.explore.pressed.emit()
	check(actions == ["replay", "explore"], "New ending actions retain the existing replay and exploration signals")
	book.queue_free()
	await process_frame
	print("TITLE UI SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
