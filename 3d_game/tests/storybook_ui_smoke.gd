extends SceneTree

## Offline interaction and layout coverage for #72; --visual also saves real frames.
var failures: Array[String] = []
var visual := false
class CaptureStub extends Node:
	var recording := false
	func start() -> void: recording = true
	func stop(_submit := true) -> void: recording = false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func frames(count := 3) -> void:
	for i in count: await process_frame
func capture(label: String) -> void:
	if not visual: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/ui72-" + label + ".png")
func click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = control.get_global_rect().get_center()
	event.pressed = true
	root.push_input(event, true)
	await frames()
	event.pressed = false
	root.push_input(event, true)
	await frames()

func run() -> void:
	visual = OS.get_cmdline_user_args().has("--visual")
	root.size = Vector2i(1440, 900)
	var journey = root.get_node("Journey")
	var narrator = root.get_node("Narrator")
	var mix = root.get_node("GameAudio")
	narrator.voice_enabled = false
	check(not narrator.enabled, "No paid narration in smoke tests")
	change_scene_to_file(journey.STAGES[0])
	await scene_changed
	await create_timer(1).timeout
	var river = current_scene
	check(not river.title.is_visible_in_tree() and not river.controls.visible, "Chapter title and controls are removed")
	check(river.generation_modes.position.y >= 150 and river.map_button.position.y >= 190, "Testing controls sit below the menu")
	check(not narrator.panel.entry.visible, "Microphone is hidden before the gift")
	narrator.panel._show_line("Narrator", "The river hums a little tune. Somewhere beyond the water, another page is waiting.")
	await frames()
	await capture("river")
	var player_position: Vector3 = river.player.position
	var chapters = journey.visited_chapters.duplicate()
	var current_item = river.current_item.duplicate(true)
	await click(mix.menu_button)
	await frames()
	check(not river.book.is_visible_in_tree() and not river.generation_modes.is_visible_in_tree() and not river.map_button.is_visible_in_tree(), "Menu hides all chapter controls")
	check(not narrator.panel.is_visible_in_tree(), "Menu hides NPC and player dialogue")
	check(mix.menu_button.is_visible_in_tree(), "Menu button remains visible")
	check(mix.menu.visible and river.process_mode == Node.PROCESS_MODE_DISABLED, "Menu blocks world input")
	var sliders = mix.menu.find_children("*", "HSlider", true, false)
	check(sliders.size() == 3, "Menu contains Music, Sound and Voice")
	for slider in sliders: check(is_equal_approx(slider.value, .5), "Audio sliders start centered")
	check(is_equal_approx(narrator.audio.volume_linear, .5), "Actual speech volume matches its default slider")
	await capture("menu")
	mix.menu.find_child("VoiceVolume", true, false).value = .3
	check(is_equal_approx(narrator.audio.volume_linear, .3), "Voice slider controls narration")
	await click(mix.menu_close)
	check(current_scene == river and not journey.busy, "Menu X resumes the same chapter instead of starting over")
	if not is_instance_valid(river):
		quit(1)
		return
	check(river.player.position.distance_to(player_position) < .01 and river.current_item == current_item,
		"Menu X preserves player position and item")
	check(journey.visited_chapters == chapters, "Menu X preserves journey progress")
	check(river.generation_modes.is_visible_in_tree() and narrator.panel.visible, "Closing menu restores previous HUD")
	check(river.process_mode == Node.PROCESS_MODE_INHERIT, "Closing menu restores input mode")
	change_scene_to_file(journey.STAGES[3])
	await scene_changed
	await create_timer(3).timeout
	var otter = current_scene
	check(not narrator.panel.entry.visible, "Chapter 4 arrival does not grant microphone")
	journey.grant_microphone()
	await frames()
	check(narrator.panel.entry.visible, "Gift hook reveals microphone")
	check(otter.draw_button.position.y < narrator.panel.entry.position.y, "Pen is above microphone")
	otter.player.position = otter.otter.position + Vector3(0, 0, 1)
	await create_timer(.5).timeout
	otter._open_drawing()
	await frames()
	check(otter.drawing and otter.surface.is_visible_in_tree(), "Otter drawing opens")
	narrator.panel._show_line("Otter", "A little imagination goes a long way. I wonder what you will make.")
	var surface = otter.surface
	surface.reference_size = surface.size
	surface.strokes.append(PackedVector2Array([Vector2(460, 460), Vector2(590, 350), Vector2(760, 460), Vector2(460, 460)]))
	surface.changed.emit()
	surface.queue_redraw()
	await frames()
	check(not otter.submit_button.disabled, "Ink enables the confirm button")
	check(not surface._can_draw(surface.excluded_control.get_global_rect().get_center()), "Drawing actions exclude ink")
	check(not surface._can_draw(narrator.panel.caption.get_global_rect().get_center()), "Speaker paper excludes drawing strokes")
	check(not surface._can_draw(mix.menu_button.get_global_rect().get_center()), "Menu excludes drawing strokes")
	check(surface.snapshot_png().size() > 0, "New controls preserve PNG export")
	await capture("drawing")
	mix.open_menu()
	await frames()
	check(not otter.overlay.is_visible_in_tree(), "Menu hides the drawing and toolbar")
	await click(mix.menu_close)
	check(otter.drawing and not otter.player.input_enabled, "Menu preserves drawing lock")
	otter._close_drawing()
	change_scene_to_file(journey.STAGES[4])
	await scene_changed
	for i in 600:
		if narrator.panel.revealing_boss: break
		await physics_frame
		await process_frame
	check(narrator.panel.revealing_boss, "Boss reveal starts after the entrance")
	await create_timer(1.92).timeout
	check(narrator.panel.caption.position.distance_to((narrator.panel.size - narrator.panel.caption.size) * .5) < 2, "Reveal dialogue reaches screen center")
	await capture("reveal-center")
	await create_timer(3).timeout
	var boss = current_scene
	check(boss.boss_revealed and boss.get_node("Storykeeper/Character").visible, "Boss reveal finishes")
	check(narrator.panel.caption.position.distance_to(Vector2(24,24)) < 1, "Dialogue returns to the corner")
	narrator.panel._show_line("Storykeeper", "I have carried every page of this journey. Do you really have to go already?")
	await frames()
	await capture("boss")
	var original_mic = narrator.panel.mic
	var fake := CaptureStub.new()
	narrator.panel.mic = fake
	narrator.panel._talk()
	check(fake.recording and narrator.panel.player_caption.visible, "Microphone opens the player speech paper")
	narrator.panel.receive_transcript("One two three four five six seven eight nine ten. ".repeat(10) + "This is the newest sentence.", true)
	await frames()
	check(narrator.panel.player_text.lines_skipped > 0 and narrator.panel.player_text.max_lines_visible in [2, 3], "Long player speech retains the latest two or three lines")
	check(boss.draw_button.disabled, "Recording disables drawing")
	await capture("speech")
	narrator.panel.close_dialogue()
	narrator.panel.mic = original_mic
	fake.free()
	narrator.panel._show_line("Storykeeper", "A very long story with many words. ".repeat(20) + "The newest ending.")
	await frames()
	check(narrator.panel.caption_text.lines_skipped > 0, "Long NPC speech scrolls to newest lines")
	root.size = Vector2i(1152, 720)
	await frames(8)
	check(narrator.panel.caption.get_global_rect().end.x < mix.menu_button.get_global_rect().position.x, "Dialogue and menu do not overlap at 1152 pixels")
	await capture("compact")
	change_scene_to_file(journey.STAGES[1])
	await scene_changed
	await frames()
	check(not narrator.panel.revealing_boss and not narrator.panel.player_caption.visible, "Scene change cancels presentation and speech")
	print("STORYBOOK UI SMOKE: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	quit(0 if failures.is_empty() else 1)
