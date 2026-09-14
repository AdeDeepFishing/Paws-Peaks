extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/narrator63-" + label + ".png")
func run() -> void:
	root.size = Vector2i(1152, 720)
	change_scene_to_file(root.get_node("Journey").STAGES[2])
	await scene_changed
	await create_timer(3).timeout
	var guide := root.get_node("Narrator")
	guide.voice_enabled = false
	guide.panel.present({"text": "Your umbrella kept you safe. Follow the path to the right."}, false)
	current_scene.status.hide()
	await create_timer(.7).timeout
	await capture("guidance")
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(3).timeout
	var narrator := root.get_node("Narrator")
	await capture("boss-mood")
	narrator.panel.open_dialogue()
	narrator.panel.present({"text": "I thought that if the last page stayed unturned, none of our little adventures could disappear. But perhaps a story can end and still be yours."})
	await create_timer(2.0).timeout
	await capture("dialogue")
	narrator.panel._draw_idea()
	await process_frame
	var surface = narrator.panel.surface
	surface.reference_size = surface.size
	surface.strokes.append(PackedVector2Array([Vector2(230, 380), Vector2(280, 290), Vector2(370, 240), Vector2(460, 290), Vector2(510, 380), Vector2(230, 380)]))
	surface.strokes.append(PackedVector2Array([Vector2(370, 240), Vector2(370, 485), Vector2(340, 500), Vector2(325, 475)]))
	surface.changed.emit()
	surface.queue_redraw()
	await capture("drawing")
	narrator.panel._finish_drawing()
	narrator.panel.close_dialogue()
	narrator.state = {"stage": 5, "ending": "stay"}
	await root.get_node("Journey").finish_stay(current_scene)
	await capture("stay")
	quit()
