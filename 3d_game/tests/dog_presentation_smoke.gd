extends SceneTree

var failed := false
var level

func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String):
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws38-reveal-" + label + ".png")
func start():
	level._open_drawing()
	check(level.drawing, "Canvas opens before construction")
	level.surface.strokes.append(PackedVector2Array([Vector2(100,100), Vector2(140,150), Vector2(190,100)]))
	level._submit()
	check(level.request.state == "PENDING" and level.presentation.phase == "focusing", "Submission starts the construction focus")
func respond(valid_model := true):
	var path := ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb") if valid_model else "res://project.godot"
	level.request.accept_response({"schema_version": 2, "request_id": level.request.active_id, "status": "recognized", "item": {"name": "Dog Bone", "description": "A local model fixture.", "type": "FOOD"}, "model_path": path})
func wait_until(condition: Callable, seconds := 10.0):
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await frames(1)
	check(condition.call(), "Timed sequence reaches expected phase")
func fresh():
	if is_instance_valid(level):
		level.queue_free()
		await frames(3)
	level = load("res://scenes/woodland/woodland_path.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	level.request.draft_directory = "user://test-drawings/dog_presentation_smoke"
	level.request.mock_delay = 60.0
	await frames(40)

func run():
	await fresh()
	var home_fov: float = level.camera.fov
	start()
	check(is_instance_valid(level.presentation.cover) and not level.player.input_enabled, "Cover appears while camera moves")
	await create_timer(0.5).timeout
	check(level.presentation.phase == "focusing" and level.camera.fov < home_fov and level.camera.fov > 32, "Camera zooms gradually")
	await wait_until(func(): return level.presentation.phase == "waiting")
	check(level.player.input_enabled and level.cancel_request.visible, "Exploration and cancellation are available while generating")
	var focus: Transform3D = level.camera.transform
	level.player.respawn(Vector3(1, 0.2, 3))
	await frames(35)
	check(level.camera.transform.is_equal_approx(focus), "Moving the player does not pull the camera off the cover")
	await capture("cover")
	respond()
	check(is_instance_valid(level.offered) and not level.offered.visible and not level.dog.distracted, "Model remains hidden during uncovering and dog waits")
	await wait_until(func(): return level.offered.visible)
	check(level.offered.find_children("*", "Sprite3D", true, false).is_empty(), "Completed model has no floating original drawing")
	check(not is_instance_valid(level.presentation.cover), "Reveal removes the cloth")
	check(not level.dog.has_node("ReactionHeart"), "Dog does not react before zoom-out")
	await capture("model")
	await create_timer(1.5).timeout
	check(level.presentation.phase == "revealing" and is_equal_approx(level.camera.fov, 32) and not level.dog.distracted, "Visible result holds for two seconds before zoom-out")
	await wait_until(func(): return level.dog.distracted)
	check(not level.presentation.active and is_equal_approx(level.camera.fov, home_fov), "Dog reaction starts only after camera restoration")
	check(level.dog.state == "jump" and level.dog.has_node("ReactionHeart"), "Reaction includes a heart and an excited jump")
	await capture("reaction")
	await wait_until(func(): return level.can_exit())
	check(level.dog.has_node("Thanks"), "Collection still gives thanks and opens the route")
	await capture("collected")

	await fresh()
	level.presentation.duration_scale = 0.05
	start()
	respond()
	check(level.presentation.phase == "focusing" and not level.offered.visible, "Fast completion waits for initial camera focus")
	level.request.cancel()
	await create_timer(0.4).timeout
	check(not level.presentation.active and level.offered == null and not level.dog.distracted, "Cancellation invalidates an already queued reveal")
	check(level.player.input_enabled and level.camera_follow_enabled and not is_instance_valid(level.presentation.cover), "Cancel restores controls, follow and cover")
	start()
	await wait_until(func(): return level.presentation.phase == "waiting")
	level.request.deadline_ms = Time.get_ticks_msec() - 1
	await frames(3)
	check(level.request.state == "FAILED" and not level.presentation.active and level.player.input_enabled, "Timeout releases held construction view")
	start()
	respond(false)
	await frames(3)
	check(level.request.state == "FAILED" and level.offered == null and not level.presentation.active, "Invalid GLB removes cover without dog reaction")
	start()
	respond()
	await wait_until(func(): return is_instance_valid(level.offered) and level.offered.visible)
	level.request.cancel()
	await create_timer(0.4).timeout
	check(not level.dog.distracted and level.offered == null, "Cancel during the result hold cannot trigger a late reaction")
	start()
	respond()
	level.queue_free()
	await frames(30)
	level = null
	print("DOG PRESENTATION SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
