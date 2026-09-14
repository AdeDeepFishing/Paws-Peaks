extends SceneTree
class CaptureStub extends Node:
	var recording := false
	func start() -> void: recording = true
	func stop(_submit := true) -> void: recording = false

var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	var narrator := root.get_node("Narrator")
	check(not narrator.enabled, "Scripted tests do not start paid narration")
	change_scene_to_file(root.get_node("Journey").STAGES[1])
	await scene_changed
	await frames(2)
	check(not narrator.panel.entry.visible, "Talk is hidden in Chapter 2")
	var drawing = current_scene.find_child("DrawingRequest", true, false)
	check(drawing != null and drawing.request_prepared.is_connected(narrator._drawing_submitted), "Nested encounter drawings feed the shared journal")
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	await create_timer(5).timeout
	root.get_node("Journey").grant_microphone()
	await frames(3)
	check(narrator.panel.entry.visible, "Chapter 5 exposes Talk")
	check(level.mood_bar.value == 37, "Boss starts at 37 percent")
	level._update_mood(19)
	check(level.mood_bar.get_theme_stylebox("fill").bg_color == Color("df7064"), "Below 20 mood is red")
	level._update_mood(80)
	check(level.mood_bar.get_theme_stylebox("fill").bg_color == Color("edc66d"), "80 remains in the middle band")
	level._update_mood(81)
	check(level.mood_bar.get_theme_stylebox("fill").bg_color == Color("8fca98"), "Above 80 mood is green")
	level._update_mood(37)
	check(not level.preview_ending_enabled and not level.can_exit(), "Boss gate is closed in real play")
	level.player.position.z = -13
	level.constrain_player(level.player)
	check(level.player.position.z > -12, "Walking around the boss cannot bypass its gate")
	level.player.position = Vector3(0, 1, -2)
	var real_mic = narrator.panel.mic
	var fake_mic := CaptureStub.new()
	narrator.panel.mic = fake_mic
	root.get_node("Journey").microphone_unlocked = false
	narrator.panel.entry.pressed.emit()
	check(not fake_mic.recording, "Speaking is locked before receiving the microphone")
	root.get_node("Journey").microphone_unlocked = true
	narrator.panel.entry.pressed.emit()
	check(fake_mic.recording and narrator.panel.opened, "One microphone click starts recording directly")
	narrator.panel.close_dialogue()
	narrator.panel.mic = real_mic
	fake_mic.free()
	narrator.panel.open_dialogue()
	check(narrator.panel.opened and level.process_mode != Node.PROCESS_MODE_DISABLED, "Conversation leaves the scene running")
	narrator.panel._draw_idea()
	await frames(2)
	check(narrator.panel.surface.size.is_equal_approx(root.get_visible_rect().size), "Boss drawing covers the scene")
	check(not narrator.panel.canvas_panel is PanelContainer, "No paper panel covers the boss drawing surface")
	var surface = narrator.panel.surface
	check(not surface._can_draw(surface.excluded_control.get_global_rect().get_center()), "Drawing toolbar does not create strokes")
	surface.reference_size = surface.size
	surface.strokes.append(PackedVector2Array([Vector2(200, 200), Vector2(240, 240)]))
	check(not surface.snapshot_png().is_empty(), "Scene drawing still produces the submitted image")
	narrator.panel._finish_drawing()
	check(surface.has_drawing() and not narrator.panel.canvas_panel.visible, "Returning to dialogue preserves the drawing")
	narrator.panel.close_dialogue()
	check(level.process_mode != Node.PROCESS_MODE_DISABLED, "Closing dialogue restores the encounter")
	level._story_changed({"stage": 5, "exit_open": true, "ending": null})
	await frames(120)
	check(level.released and is_equal_approx(level.get_node("Storykeeper").position.x, 0.0) and absf(level.get_node("Storykeeper").rotation.y - PI/2) < .01, "Confirmed release rotates the boss in place")
	level._story_changed({"stage": 5, "exit_open": false, "ending": null})
	check(level.released, "Later dialogue cannot reclose the exit")
	# Transport responses from an old scene must not change state or play speech.
	narrator.state = {"run_id": "test", "revision": 2}
	narrator._consume({"epoch": -1, "op": "respond"}, {"ok": true, "state": {"revision": 999}})
	check(narrator.state.revision == 2, "Old-scene responses are discarded")
	narrator.panel.caption_text.text = "Old draft"
	narrator.reset_journey()
	check(not narrator.panel.caption.visible and narrator.state.is_empty(), "Replay clears recognized speech and narrator history")
	level.status.text = "Follow the path to the right."
	level.status.set_meta("narrator_guidance", level.status.text)
	check(narrator._current_guidance() == level.status.text, "Narrator reads the authored chapter instruction")
	level.status.text = "Preparing your drawing…"
	check(narrator._current_guidance().is_empty(), "Technical status does not become spoken guidance")
	check(narrator.panel.caption.find_children("*", "Button", true, false).all(func(b): return not "Skip" in b.text), "Subtitle has no Skip button")
	check(narrator.panel.caption_art.texture != null, "Subtitle uses supplied paper")
	level.show_stay_book(null)
	check(level.book.ending_title.text == "A Place to Stay", "Staying has a complete, distinct ending book")
	check(level.book.replay != null and level.book.explore != null, "Stay ending permits replay and viewing the world")
	# Inspect queued transport without starting a worker or making provider calls.
	narrator.queue.clear()
	narrator.guidance_text = "A microphone! Tap Talk to speak."
	narrator.scripted_narration = true
	level.status.text = "Tap Talk to speak with the otter."
	level.status.set_meta("narrator_guidance", level.status.text)
	narrator.enabled = true
	narrator.end_scripted_narration()
	narrator.enabled = false
	check(narrator.queue.size() == 1 and narrator.queue[0].op == "event" and narrator.queue[0].type == "guidance_changed" and narrator.queue[0].payload.text == level.status.text, "Gift completion records the new guidance before a spoken reply")
	check(not narrator.guidance_due and not narrator.comment_due, "Recording final gift guidance does not repeat narration")
	narrator.queue.clear()
	print("NARRATOR SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
