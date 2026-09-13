extends SceneTree

func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/boss36-" + label + ".png")
func run() -> void:
	root.size = Vector2i(1152, 720)
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(1.5).timeout
	await capture("arrival")
	var boss := current_scene.get_node("Storykeeper")
	print("BOSS VISUAL: position=", boss.position, " grounded=", boss.grounded, " animation=", boss.animator.current_animation)
	if "--preview" in OS.get_cmdline_user_args(): return
	current_scene.player.position = Vector3(0, 1, -2.7)
	await create_timer(1.0).timeout
	await capture("close")
	quit()
