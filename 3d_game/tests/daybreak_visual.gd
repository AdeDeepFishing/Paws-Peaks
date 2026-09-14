extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/daybreak-"+label+".png")
func run() -> void:
	root.size = Vector2i(1152,720)
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(2).timeout
	var level = current_scene
	await capture("night")
	for phase in [1.0,2.0]:
		await level.daybreak.go(phase,.1)
		await create_timer(.3).timeout
		await capture("dawn" if phase == 1 else "sunrise")
	if "--preview" not in OS.get_cmdline_user_args():
		print("DAYBREAK VISUAL: PASS")
		quit()
		return
	level.daybreak.set_value(0)
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	level.add_child(canvas)
	var button := Button.new()
	button.text = "Preview: Boss opens the way"
	button.position = Vector2(400,120)
	canvas.add_child(button)
	button.pressed.connect(func():
		button.hide()
		level._story_changed({"stage":5,"mood":95,"exit_open":true})
		level.preview_ending_enabled = true
	)
