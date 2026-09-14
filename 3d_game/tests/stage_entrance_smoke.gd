extends SceneTree
var failed := false
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func run():
	for stage in ["woodland/woodland_path", "wind_hill/wind_hill", "sunset_cove/sunset_cove", "moonlit_forest/moonlit_forest"]:
		var level = load("res://scenes/" + stage + ".tscn").instantiate()
		root.add_child(level)
		current_scene = level
		check(level.entering and not level.player.input_enabled, stage + ": controls locked on entry")
		check(not level.player.visible, stage + ": elevated setup spawn is hidden")
		level.player.entrance_finished.connect(func():
			Input.action_release("move_right")
			Input.action_release("jump")
			Input.action_release("sprint")
		, CONNECT_ONE_SHOT)
		Input.action_press("move_right")
		Input.action_press("jump")
		Input.action_press("sprint")
		for i in 480:
			await physics_frame
			await process_frame
			if i == 15:
				if "--visual" in OS.get_cmdline_user_args():
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("/private/tmp/entrance-walk-" + level.chapter + ".png")
				check(level.player.walking_in and level.player.visible, stage + ": grounded scripted walk is visible")
				if level.has_method("_open_drawing"):
					level._open_drawing()
					check(not level.drawing, stage + ": drawing blocked during entrance")
			if not level.entering: break
		Input.action_release("move_right")
		Input.action_release("jump")
		Input.action_release("sprint")
		check(not level.entering and level.player.input_enabled, stage + ": control returned on arrival")
		var offset: Vector3 = level.player.position - level.spawn
		offset.y = 0
		check(offset.length() < 0.1 and level.player.is_on_floor(), stage + ": reached grounded starting position")
		if "--visual" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/entrance-" + level.chapter + ".png")
		level.queue_free()
		await process_frame
	print("STAGE ENTRANCE SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
