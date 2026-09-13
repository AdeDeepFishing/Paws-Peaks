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
	# Exercise the actual three call variants; navigation changes only the phase.
	for variant in ["stage", "map", "ending"]:
		journey.page.texture = ImageTexture.create_from_image(original)
		journey.page_material.set_shader_parameter("progress", 0.0)
		journey.page.show()
		journey._turn_page(variant == "map", 2.0, variant == "ending")
		for i in 600:
			await process_frame
			if float(journey.page_material.get_shader_parameter("progress")) >= 0.15: break
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		var bottom_right := frame.get_pixel(int(frame.get_width() * 0.97), int(frame.get_height() * 0.97))
		var bottom_left := frame.get_pixel(int(frame.get_width() * 0.03), int(frame.get_height() * 0.97))
		var top_right := frame.get_pixel(int(frame.get_width() * 0.97), int(frame.get_height() * 0.03))
		check(bottom_right.b > 0.8 and bottom_right.r < 0.2, variant + ": bottom-right corner reveals first")
		check(bottom_left.r > 0.8 and bottom_left.b < 0.2, variant + ": left edge never leads the page turn")
		check(top_right.r > 0.8 and top_right.b < 0.2, variant + ": lower corner lifts before the top edge")
		frame.save_png("/private/tmp/map53-corner-" + variant + ".png")
		for i in 600:
			await process_frame
			if not journey.page.visible: break
		check(not journey.page.visible, "Page turn finishes")
	print("PAGE CORNER SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
