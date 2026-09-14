extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")
var failed := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(n):
	for i in n:
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/ui72-transition-" + label + ".png")

func run():
	JourneyTest.fast(self)
	var journey = root.get_node("Journey")
	change_scene_to_file(journey.MAP)
	await scene_changed
	await frames(2)
	await JourneyTest.complete(self)
	check(current_scene.scene_file_path == journey.STAGES[0], "Opening Start enters the river")
	var river = current_scene
	await frames(20)
	river.generation.configure(0)
	river.request.mock_delay = 0.01
	river.request.draft_directory = "/private/tmp/paws-transition-%d" % OS.get_process_id()
	river.presentation.duration_scale = 0.01
	river.player.respawn(Vector3(-4.8,1.6,-6.3))
	await frames(30)
	river._open_book()
	check(river.panel_mode == "draw", "Riverbank drawing opens")
	var mix = root.get_node("GameAudio")
	mix.open_menu()
	await frames(2)
	mix.close_menu()
	await frames(3)
	check(river.panel_mode == "draw" and not river.player.input_enabled, "Closing the menu restores drawing")
	river.surface.reference_size = river.surface.size
	river.surface.strokes.append(PackedVector2Array([Vector2(400, 300), Vector2(650, 330)]))
	river.surface.changed.emit()
	river._submit()
	check(river.request.state == "PENDING", "Confirm submits the bridge drawing")
	for i in 600:
		await frames(1)
		if river.bridge_built and not river.presentation.busy: break
	check(river.bridge_built and river.bridge.visible, "Offline drawing creates the usable bridge")
	var saved_draft: String = river.request.saved_draft_path
	if not saved_draft.is_empty(): DirAccess.remove_absolute(saved_draft)
	DirAccess.remove_absolute(river.request.draft_directory)
	Input.action_press("move_right")
	for i in 200:
		river.player.window_focused = true
		await frames(1)
		if river.completed: break
	Input.action_release("move_right")
	check(river.completed, "Walking across reaches far bank")
	check(not river.modal.visible and river.panel_mode == "" and river.player.input_enabled, "Far bank has no completion modal or input lock")
	await frames(10)
	check(current_scene == river, "Stopping on far bank keeps the current scene")
	# Continue along the authored path (world +X, screen down-right).
	var yaw: float = river.get_node("StageCamera").rotation.y
	Input.action_press("move_right", cos(yaw))
	Input.action_press("move_down", sin(yaw))
	for i in 70:
		river.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(current_scene == river and river.player.position.x > 9, "The old early exit no longer changes scenes")
	check(river.player.input_enabled, "Player can keep exploring the far-bank path")
	Input.action_press("move_right", cos(yaw))
	Input.action_press("move_down", sin(yaw))
	for i in 300:
		if not is_instance_valid(river) or current_scene != river: break
		river.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	for i in 1800:
		await frames(1)
		if journey.phase == "start" or not journey.busy: break
	check(journey.phase == "start" and journey.target_stage == 2, "River exit keeps Chapter 2 as its destination")
	if current_scene != null and current_scene.scene_file_path == journey.MAP:
		check(current_scene.start_button.text == "Next page  →", "River exit never offers a new journey")
		check(current_scene.review_stage == 2 and "CHAPTER 02" in current_scene.caption.text, "Map presents Chapter 2")
		check(current_scene.hero.position.distance_to(current_scene.RouteData.STAGES[1]) < 0.25, "Map traveler reaches Chapter 2")
	await capture("chapter-two-map")
	await JourneyTest.complete(self)
	await frames(10)
	await capture("woodland")
	check(current_scene != null and current_scene.name == "WoodlandPath", "Continuing forward automatically enters Stage 2")
	check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Transition removes the previous scene")
	print("WALK-THROUGH TRANSITION: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
