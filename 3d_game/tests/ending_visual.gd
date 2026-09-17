extends SceneTree

var journey: Node
var shots := {}

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/map60-" + label + ".png")

func _process(_delta: float) -> bool:
	if journey == null or current_scene == null: return false
	if journey.phase == "page_to_ending":
		var progress: float = journey.page_material.get_shader_parameter("progress")
		if progress > 0.48 and not shots.has("last-turn"):
			shots["last-turn"] = true
			capture("last-turn")
	if journey.phase == "dawn" and not shots.has("arrival"):
		shots["arrival"] = true
		capture("arrival")
	return false

func run() -> void:
	root.size = Vector2i(1152, 720)
	journey = root.get_node("Journey")
	change_scene_to_file(journey.STAGES[4])
	await scene_changed
	await create_timer(1.0).timeout
	await capture("night")
	current_scene.complete_boss_encounter()
	await journey.finished
	await capture("victory")
	if "--preview" in OS.get_cmdline_user_args(): return
	root.size = Vector2i(850, 720)
	await create_timer(0.3).timeout
	await capture("victory-narrow")
	root.size = Vector2i(1152, 720)
	await create_timer(0.2).timeout
	var button: Button = current_scene.book.explore
	var point := button.get_global_rect().get_center()
	var click := InputEventMouseButton.new()
	click.position = point
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await create_timer(0.5).timeout
	assert(current_scene.presentation_phase == "explore", "Real mouse click restores exploration")
	await capture("dawn")
	var audio = root.get_node("GameAudio")
	audio.open_menu()
	audio.map_return.pressed.emit()
	await create_timer(1.0).timeout
	await capture("reopened")
	print("ENDING VISUAL: PASS (last page, dawn, victory, narrow layout, explore and reopen)")
	quit()
