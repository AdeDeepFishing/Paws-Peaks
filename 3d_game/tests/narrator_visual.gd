extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/narrator63-" + label + ".png")
func run() -> void:
	root.size = Vector2i(1152, 720)
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(3).timeout
	var narrator := root.get_node("Narrator")
	narrator.panel.open_dialogue()
	narrator.panel.present({"text": "I thought that if the last page stayed unturned, none of our little adventures could disappear. But perhaps a story can end and still be yours."})
	await capture("dialogue")
	narrator.panel.close_dialogue()
	narrator.state = {"stage": 5, "ending": "stay"}
	await root.get_node("Journey").finish_stay(current_scene)
	await capture("stay")
	quit()
