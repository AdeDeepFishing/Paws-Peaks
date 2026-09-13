extends SceneTree

var failed := false
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failed = true
		push_error(message)
func frame():
	await physics_frame
	await process_frame
func projected_height(level) -> float:
	var feet: Vector3 = level.bird.visual.global_position
	return level.camera.unproject_position(feet).distance_to(level.camera.unproject_position(feet + Vector3.UP * 4.76))
func capture(level, label: String):
	if "--visual" not in OS.get_cmdline_user_args(): return
	level.bird.paused = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws34-arrival-" + label + ".png")
	level.bird.paused = false
func run():
	var level = load("res://scenes/wind_hill/wind_hill.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	await frame()
	# Sample the actual flight deterministically, independent of GUI focus/frame rate.
	level.bird.set_process(false)
	level.camera_follow_enabled = false
	level.player.set_physics_process(false)
	level.player.position = Vector3(0,0,-0.5)
	var first_height := projected_height(level)
	var point: Vector2 = level.camera.unproject_position(level.bird.visual.global_position)
	check(level.bird.phase == "arriving" and level.bird.visual.visible, "Entry starts in flight")
	check(point.x > root.get_visible_rect().size.x * 0.75 and point.y < root.get_visible_rect().size.y * 0.3, "Bird first appears in the upper-right distance")
	check(first_height < root.get_visible_rect().size.y * 0.10, "Distant giant starts small on screen")
	await capture(level, "far")
	var previous: Vector3 = level.bird.visual.position
	var last_height := first_height
	for i in 330:
		level.bird._process(1.0 / 60.0)
		var height := projected_height(level)
		check(height >= last_height - 0.15, "Perspective grows continuously during arrival")
		check(level.bird.visual.position.distance_to(previous) < 1.2, "Approach has no position pop")
		check(level.bird.visual.get_child(0).scale.is_equal_approx(Vector3.ONE * 2.8), "Bird retains its full physical scale")
		previous = level.bird.visual.position
		last_height = height
		if i == 165: await capture(level, "middle")
	await capture(level, "near")
	check(last_height > first_height * 3.0, "Near bird is at least three times its distant screen height")
	level.bird._process(1.0 / 60)
	check(level.bird.phase == "circling", "Arrival joins the guarding circuit")
	check(not level.can_exit(), "Arrival never unlocks the exit")
	print("BIRD ARRIVAL HEIGHTS: ", snappedf(first_height,0.1), " -> ", snappedf(last_height,0.1))
	print("BIRD ARRIVAL SMOKE: ", "FAIL" if failed else "PASS")
	level.queue_free()
	await frame()
	quit(1 if failed else 0)
