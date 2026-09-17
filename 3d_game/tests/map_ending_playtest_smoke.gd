extends SceneTree

var failed := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-" + label + "-fixed.png")

func run() -> void:
	root.size = Vector2i(1152, 720)
	root.get_node("Narrator").enabled = false
	var journey = root.get_node("Journey")
	journey.duration_scale = 0.01
	var map = load(journey.MAP).instantiate()
	map.autoplay = false
	root.add_child(map)
	current_scene = map
	map.configure(2, 3)
	map.await_start(3)
	map._zoom_by(1.0)
	await create_timer(0.8).timeout
	check(not map.chapter_card.is_visible_in_tree(), "Full map hides the chapter paper and text")
	check(map.start_button.disabled, "Hidden Play cannot be activated by keyboard")
	await capture("map-overview")
	map._zoom_by(-1.0)
	await create_timer(0.8).timeout
	check(map.chapter_card.is_visible_in_tree() and not map.start_button.disabled, "Close zoom restores the chapter and Play")
	await capture("map-close")
	change_scene_to_file(journey.ENDING)
	await scene_changed
	var ending = current_scene
	await ending.get_node("DawnArt").wait_until_prepared()
	await create_timer(0.5).timeout
	check(ending.presentation_phase == "book", "Ending opens its book")
	ending.book.explore.pressed.emit()
	await create_timer(0.5).timeout
	check(ending.presentation_phase == "explore" and ending.player.input_enabled, "Stay a while enables exploration")
	check(ending.player.is_visible_in_tree(), "Stay a while restores a visible hero")
	check(ending.player.visual.is_visible_in_tree(), "The hero model is visible after placement")
	check(ending.player.is_on_floor(), "Epilogue hero is grounded")
	var start: Vector3 = ending.player.position
	ending.player.window_focused = true
	Input.action_press("move_right")
	await create_timer(0.2).timeout
	Input.action_release("move_right")
	check(ending.player.position.distance_to(start) > 0.1, "The visible epilogue hero can move")
	for button in ending.exploration.find_children("*", "Button", true, false):
		check(not button.is_visible_in_tree(), "Exploration has no legacy navigation buttons")
	await capture("ending")
	var audio = root.get_node("GameAudio")
	audio.open_menu()
	check(not audio.map_return.disabled and audio.map_return.get_node("DestinationLabel").text == "The last page", "Epilogue menu offers the ending recap")
	await capture("ending-menu")
	audio.map_return.pressed.emit()
	await create_timer(0.9).timeout
	check(ending.presentation_phase == "book" and not audio.menu.visible, "Menu reopens the ending book")
	ending.book.explore.pressed.emit()
	await create_timer(0.5).timeout
	check(ending.player.is_visible_in_tree() and ending.player.input_enabled, "Repeated Stay a while preserves the hero")
	print("MAP ENDING PLAYTEST: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
