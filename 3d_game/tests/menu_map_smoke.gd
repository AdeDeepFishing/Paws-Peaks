extends SceneTree
const JourneyTest = preload("res://tests/journey_test_helpers.gd")
var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func frames(count := 3) -> void:
	for i in count:
		await physics_frame
		await process_frame
func click(control: Control) -> void:
	# Scene transition completion can precede the persistent HUD refresh.
	for i in 60:
		if control.is_visible_in_tree(): break
		await frames(1)
	check(control.is_visible_in_tree(), "Pointer input targets a visible control")
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames()
func run() -> void:
	create_timer(45).timeout.connect(func(): push_error("Menu map test timed out"); quit(1))
	var journey = root.get_node("Journey")
	var mix = root.get_node("GameAudio")
	JourneyTest.fast(self)
	change_scene_to_file(journey.STAGES[0])
	await scene_changed
	await frames(80)
	var river = current_scene
	var at: Vector3 = river.player.position
	river.current_item = {"name": "Saved bridge"}
	river.current_png = PackedByteArray([1, 2, 3])
	await click(mix.menu_button)
	check(mix.menu_close.is_visible_in_tree(), "Menu shows the supplied X")
	check(mix.menu.get_global_rect().encloses(mix.menu_close.get_global_rect()), "X stays inside the menu paper")
	check(mix.map_return.get_child(0).text == "Back to Map", "CTA names its destination")
	await click(mix.menu_close)
	check(not mix.menu.visible and current_scene == river and not journey.busy, "X resumes the existing chapter")
	check(river.player.position.distance_to(at) < .01, "X keeps the player in place")
	for keyboard in [false, true]:
		await click(mix.menu_button)
		check(mix.menu.visible, "Menu stays open immediately after returning from the map")
		check(not mix.map_return.disabled, "Map navigation is available during exploration")
		if keyboard:
			mix.map_return.grab_focus()
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.pressed = true
			root.push_input(key)
			key = key.duplicate()
			key.pressed = false
			root.push_input(key)
		else: await click(mix.map_return)
		for i in 600:
			if journey.phase == "start": break
			await frames(1)
		check(current_scene.name == "Overworld", "CTA opens the current chapter map")
		if current_scene.name != "Overworld": quit(1); return
		check(current_scene.review_stage == 1, "Map stays on the current chapter")
		check(current_scene.start_button.text == "Return", "Map offers return to the retained chapter")
		current_scene.start_button.pressed.emit()
		await JourneyTest.complete(self)
		check(current_scene == river and river.current_item.name == "Saved bridge" and river.current_png == PackedByteArray([1, 2, 3]), "Map return preserves scene and drawing state")
		check(river.player.position.distance_to(at) < .01, "Map return restores the player position")
	river.request.deadline_ms = Time.get_ticks_msec() + 60000
	river.request.state = "PENDING"
	await click(mix.menu_button)
	check(mix.map_return.disabled and not mix.menu_close.disabled, "Generation blocks map navigation but leaves X usable")
	await click(mix.menu_close)
	river.request.state = "IDLE"
	print("MENU MAP SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
