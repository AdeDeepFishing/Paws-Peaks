extends SceneTree

var failed := false
var narrator
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-public-" + label + ".png")
func run() -> void:
	narrator = root.get_node("Narrator")
	narrator.enabled = false
	# Inspect configured scenes without running unrelated encounters or providers.
	for path in root.get_node("Journey").STAGES:
		var scene = load(path).instantiate()
		var generation = scene.get_node("ObjectGeneration/DesktopGeneration") if scene.has_node("ObjectGeneration") else scene.get_node("DesktopGeneration")
		check(generation.mode == 2, "Live AI defaults in " + path)
		scene.free()
	change_scene_to_file("res://scenes/river/river_crossing.tscn")
	await scene_changed
	await frames(45)
	var river = current_scene
	check(not river.generation_modes.is_visible_in_tree() and not river.map_button.is_visible_in_tree(), "River has no mode selector or duplicate map button")
	check(not river.request.mock_mode and river.generation.mode == 2, "River adapter keeps live mode after ready")
	narrator.panel._show_line("Narrator", "Little curiosity. Let us see where yours takes us. Follow the path to the river.")
	await frames(2)
	var camera := root.get_camera_3d()
	var head: Vector2 = camera.unproject_position(river.player.global_position + Vector3.UP * 3.6)
	check(head.y > narrator.panel.caption.get_global_rect().end.y + 4, "River starting hero clears the top-left narration banner")
	await capture("river")
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	for i in 600:
		await frames(1)
		if level.boss_revealed and level.player.input_enabled and not narrator.panel.revealing_boss: break
	check(level.boss_revealed and level.mood_layer.visible and level.mood_bar.is_visible_in_tree(), "Boss reveal shows mood")
	check(level.player.is_on_floor() and level.get_node("Storykeeper").grounded, "Entrance and boss wait for prepared terrain")
	var navigation = level.find_child("BackButton", true, false)
	check(navigation != null and not navigation.is_visible_in_tree(), "Later chapter duplicate navigation is hidden")
	level._story_changed({"stage":5, "mood":72})
	check(level.mood_bar.value == 72 and level.mood_label.text.contains("72%"), "Mood tracks narrator state")
	await capture("boss-mood")
	var panel = narrator.panel
	var gift = load("res://scripts/sunset_cove/microphone_gift.gd").new()
	check(gift.ICON.resource_path == panel.entry.textures[0].resource_path, "Otter gift and speech button share the painted microphone")
	gift.free()
	var generator = level.get_node("ObjectGeneration")
	generator.generation.configure(0)
	generator.request.mock_mode = false
	generator.request.draft_directory = "/private/tmp/paws-public-drafts"
	panel._show_line("You", "An earlier spoken sentence.")
	panel._draw_idea()
	panel.surface.reference_size = panel.surface.size
	panel.surface.strokes.append(PackedVector2Array([Vector2(400,300), Vector2(500,400)]))
	panel.surface.changed.emit()
	panel._share_drawing()
	panel.set_busy(true)
	await frames(2)
	check(generator.request.state == "PENDING", "Drawing still submits without the removed button")
	check(not panel.player_caption.visible and panel.player_text.text.is_empty(), "Drawings never appear as player speech, including stale transcripts")
	check(level.find_children("*", "Button", true, false).filter(func(button): return button.text == "Stop generating object").is_empty(), "No stop-generation button exists")
	await capture("drawing")
	generator.request.cancel()
	panel.close_dialogue()
	panel._show_line("You", "I would like to pass.")
	check(panel.player_caption.visible and panel.player_text.text == "I would like to pass.", "Actual speech remains visible")
	print("PUBLIC PLAYTEST: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
