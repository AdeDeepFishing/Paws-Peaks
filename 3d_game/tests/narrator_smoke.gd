extends SceneTree

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
	var drawing = current_scene.find_child("DrawingRequest", true, false)
	check(drawing != null and drawing.request_prepared.is_connected(narrator._drawing_submitted), "Nested encounter drawings feed the shared journal")
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	await frames(120)
	check(not level.preview_ending_enabled and not level.can_exit(), "Boss gate is closed in real play")
	level.player.position.z = -13
	level.constrain_player(level.player)
	check(level.player.position.z > -12, "Walking around the boss cannot bypass its gate")
	level.player.position = Vector3(0, 1, -2)
	narrator.panel.open_dialogue()
	check(narrator.panel.opened and level.process_mode == Node.PROCESS_MODE_DISABLED, "Dialogue pauses the encounter")
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
	check(surface.has_drawing() and narrator.panel.drawer.visible, "Returning to dialogue preserves the drawing")
	narrator.panel.close_dialogue()
	check(level.process_mode != Node.PROCESS_MODE_DISABLED, "Closing dialogue restores the encounter")
	level._story_changed({"stage": 5, "exit_open": true, "ending": null})
	await frames(120)
	check(level.released and level.get_node("Storykeeper").position.x < -2.9, "Confirmed release moves the boss aside")
	level._story_changed({"stage": 5, "exit_open": false, "ending": null})
	check(level.released, "Later dialogue cannot reclose the exit")
	# Transport responses from an old scene must not change state or play speech.
	narrator.state = {"run_id": "test", "revision": 2}
	narrator._consume({"epoch": -1, "op": "respond"}, {"ok": true, "state": {"revision": 999}})
	check(narrator.state.revision == 2, "Old-scene responses are discarded")
	narrator.panel.input.text = "Old draft"
	narrator.reset_journey()
	check(narrator.panel.input.text.is_empty() and narrator.state.is_empty(), "Replay clears drafts and narrator history")
	level.status.text = "Follow the path to the right."
	level.status.set_meta("narrator_guidance", level.status.text)
	check(narrator._current_guidance() == level.status.text, "Narrator reads the authored chapter instruction")
	level.status.text = "Preparing your drawing…"
	check(narrator._current_guidance().is_empty(), "Technical status does not become spoken guidance")
	check(narrator.panel.caption.find_children("*", "Button", true, false).is_empty(), "Subtitle has no Skip button")
	check(narrator.panel.caption.get_theme_stylebox("panel").bg_color.a < 0.8, "Subtitle paper is translucent")
	level.show_stay_book(null)
	check(level.book.ending_title.text == "A Place to Stay", "Staying has a complete, distinct ending book")
	check(level.book.replay != null and level.book.explore != null, "Stay ending permits replay and viewing the world")
	print("NARRATOR SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
