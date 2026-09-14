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
	level.show_stay_book(null)
	check(level.book.ending_title.text == "A Place to Stay", "Staying has a complete, distinct ending book")
	check(level.book.replay != null and level.book.explore != null, "Stay ending permits replay and viewing the world")
	print("NARRATOR SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
