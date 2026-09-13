extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func snapshot(label: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/map53-" + label + ".png")

func run() -> void:
	root.size = Vector2i(1152, 720)
	var map = load("res://scenes/overworld/overworld.tscn").instantiate()
	map.autoplay = false
	root.add_child(map)
	current_scene = map
	await frames(40)
	for stage in [1, 3, 5]:
		map.configure(stage, stage)
		map._set_camera(map._full_transform())
		await snapshot("stage-%d-full" % stage)
	map.configure(2, 2)
	map.await_next_page(2, 1.0)
	await snapshot("browse-close")
	map.set_zoom(0.0)
	await create_timer(0.8).timeout
	await snapshot("browse-full")
	root.size = Vector2i(850, 720)
	await create_timer(0.5).timeout
	await snapshot("narrow")
	quit()
