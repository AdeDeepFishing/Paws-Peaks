extends "res://tests/dog_presentation_smoke.gd"

func pointer(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames(2)
	event.pressed = false
	root.push_input(event, true)
	await frames(2)

func keypress(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames(3)

func run():
	root.get_node("Journey").duration_scale = .01
	for visit_menu in [false, true]:
		await fresh()
		level.request.draft_directory = "/private/tmp/dog-navigation-%d" % OS.get_process_id()
		level.presentation.duration_scale = .03
		level._open_drawing()
		await frames(3)
		check(level.drawing, "Drawing opens for the dog")
		if visit_menu:
			await pointer(root.get_node("GameAudio").menu_button)
			await pointer(root.get_node("GameAudio").menu_button)
		var front: Vector3 = level.player.global_position + Vector3(0, 0, -3)
		var query := PhysicsRayQueryParameters3D.create(front + Vector3.UP * 10, front + Vector3.DOWN * 10, level.dog.GROUND_MASK)
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(), "Sketch lands on ground")
		if hit.is_empty():
			quit(1)
			return
		var screen: Vector2 = level.camera.unproject_position(hit.position)
		level.surface.reference_size = level.surface.size
		level.surface.strokes.append(PackedVector2Array([screen + Vector2(-40,-100), screen + Vector2(40,-50)]))
		level.surface.changed.emit()
		await frames(3)
		await pointer(level.submit_button)
		check(current_scene == level and level.request.state == "PENDING", "Pointer Confirm submits without restarting")
		var draft: String = level.request.saved_draft_path
		if not draft.is_empty(): DirAccess.remove_absolute(draft)
		DirAccess.remove_absolute(level.request.draft_directory)
		respond()
		await wait_until(func(): return level.dog.solved, 20)
		check(current_scene == level and not root.get_node("Journey").busy, "Collecting the drawing stays in Chapter 2")
	var mix = root.get_node("GameAudio")
	await pointer(mix.menu_button)
	await pointer(mix.menu_button)
	# Space is both jump and UI accept. Stale toggle focus used to reopen the
	# menu, let movement arrows select Return to Title, and restart on Space.
	await keypress(KEY_SPACE)
	check(not mix.menu.visible, "Jump after closing the menu does not reopen it")
	for i in 3: await keypress(KEY_DOWN)
	await keypress(KEY_SPACE)
	await frames(90)
	check(current_scene == level and not root.get_node("Journey").busy, "Walking and jumping after closing menu never return to the opening map")
	# Keyboard activation of the menu CTA resumes the same collected encounter.
	await pointer(mix.menu_button)
	for i in 3: await keypress(KEY_DOWN)
	await keypress(KEY_SPACE)
	check(not mix.menu.visible and current_scene == level and level.dog.solved,
		"Keyboard Return to Game keeps the solved dog encounter")
	check(not root.get_node("Journey").busy, "Resume does not start a map transition")
	current_scene.queue_free()
	current_scene = null
	await frames(3)
	print("DOG SUBMISSION NAVIGATION: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
