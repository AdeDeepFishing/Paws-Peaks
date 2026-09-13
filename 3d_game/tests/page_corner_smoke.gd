extends SceneTree

var failed := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Page corner validation requires the native renderer")
		quit(1)
		return
	root.size = Vector2i(1152, 720)
	root.disable_3d = true
	var background := ColorRect.new()
	background.color = Color.BLUE
	root.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var original := Image.create(16, 16, false, Image.FORMAT_RGB8)
	original.fill(Color.RED)
	var journey := root.get_node("Journey")
	# Back to map reverses the fold; every subsequent forward call resets it.
	for variant in ["back_to_map", "stage", "map", "ending"]:
		journey.page.texture = ImageTexture.create_from_image(original)
		journey.page_material.set_shader_parameter("progress", 0.0)
		journey.page.show()
		journey._turn_page(variant in ["map", "back_to_map"], 2.0, variant == "ending", variant == "back_to_map")
		# Hold a fixed fold position so rendering load cannot skip the sample.
		var turn: Tween = get_processed_tweens().back()
		turn.pause()
		journey.page_material.set_shader_parameter("progress", 0.15)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var bottom_right := frame.get_pixel(int(frame.get_width() * 0.97), int(frame.get_height() * 0.97))
		var bottom_left := frame.get_pixel(int(frame.get_width() * 0.03), int(frame.get_height() * 0.97))
		var top_right := frame.get_pixel(int(frame.get_width() * 0.97), int(frame.get_height() * 0.03))
		var revealed := bottom_left if variant == "back_to_map" else bottom_right
		var retained := bottom_right if variant == "back_to_map" else bottom_left
		check(revealed.b > 0.8 and revealed.r < 0.2, variant + ": the correct corner reveals first")
		check(retained.r > 0.8 and retained.b < 0.2, variant + ": the opposite corner stays on the outgoing page")
		check(top_right.r > 0.8 and top_right.b < 0.2, variant + ": lower corner lifts before the top edge")
		frame.save_png("/private/tmp/map53-corner-" + variant + ".png")
		turn.play()
		for i in 600:
			await process_frame
			if not journey.page.visible: break
		check(not journey.page.visible, "Page turn finishes")
	print("PAGE CORNER SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
