extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")

const FOREST := "res://scenes/moonlit_forest/moonlit_forest.tscn"
var failed := false
var visual := "--visual" in OS.get_cmdline_user_args()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func clear_scene() -> void:
	current_scene.queue_free()
	await frames(3)

func forest() -> Node:
	var level = load(FOREST).instantiate()
	root.add_child(level)
	current_scene = level
	return level

func run() -> void:
	JourneyTest.fast(self)
	var worker := root.get_node("GenerationWorker")
	var level = forest()
	await frames(45)
	Input.action_press("move_up")
	for i in 360:
		if not is_instance_valid(level): break
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	await frames(60)
	check(current_scene.name == "DawnForest", "Walking deeper into Stage 5 reaches the ending without jumping")
	if current_scene.name != "DawnForest":
		print("STUCK AT: ", level.player.position)
		quit(1)
		return
	check(not is_instance_valid(level), "Entering the ending releases the night forest")
	var ending = current_scene
	var art := ending.get_node("DawnArt")
	check(art.find_children("*", "MeshInstance3D", true, false).size() == 451, "All delivered dawn meshes are present")
	check(art.find_children("Cloud_layer*", "MeshInstance3D", true, false).size() == 20, "Dawn retains the layered cloud sky")
	check(art.find_child("Painted_moon", true, false) == null and art.find_children("Firefly_*", "Node3D", true, false).is_empty(), "Dawn removes the moon and fireflies")
	check(art.find_child("Sunrise_key", true, false).shadow_enabled, "Sunrise casts terrain and character shadows")
	var sky: MeshInstance3D = art.find_child("Sky_dome", true, false)
	check(sky.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and sky.get_active_material(0) is ShaderMaterial, "Dawn uses painted sky sampling without sky shadows")
	var animator: AnimationPlayer = art.find_child("AnimationPlayer", true, false)
	check(animator.is_playing() and "Forest_dawn_wind_clouds" in animator.current_animation, "Dawn wind and clouds animate")
	check(animator.get_animation(animator.current_animation).loop_mode == Animation.LOOP_PINGPONG, "Dawn motion avoids a reset snap")
	check(ending.player.is_on_floor(), "Dawn player spawns on solid ground")
	check(is_equal_approx(ending.camera.fov, 52), "Dawn retains the designer's lens")
	check(ending.draw_button == null, "Ending has no inactive drawing prompt")
	if visual:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-ending.png")
	var before: Vector3 = ending.player.position
	Input.action_press("move_right")
	for i in 20:
		ending.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	check(ending.player.position.x > before.x + 0.5, "The dawn epilogue remains explorable")
	var floor_y: float = ending.player.position.y
	Input.action_press("jump")
	ending.player.window_focused = true
	await frames(5)
	Input.action_release("jump")
	check(ending.player.position.y > floor_y + 0.2, "Dawn supports jumping")
	await frames(60)
	check(ending.player.is_on_floor(), "Dawn jump lands safely")
	ending.player.position.y = -10
	await frames(60)
	check(ending.player.is_on_floor(), "Dawn fall recovery returns to the clearing")
	ending.find_child("BackButton", true, false).pressed.emit()
	await frames(60)
	check(current_scene.name == "MoonlitForest", "Back returns safely before the ending boundary")
	current_scene.complete_boss_encounter()
	current_scene.complete_boss_encounter()
	await frames(30)
	check(current_scene.name == "DawnForest", "Boss completion hook reaches the ending once")
	current_scene.find_child("RestartButton", true, false).pressed.emit()
	await frames(45)
	await JourneyTest.complete(self)
	check(current_scene.name == "RiverCrossing", "Play again opens the first stage through the map intro")
	check(not current_scene.completed and not current_scene.bridge_built and current_scene.current_item.is_empty(), "Play again starts with fresh encounter and item state")
	check(current_scene.current_png.is_empty() and current_scene.request.state != "PENDING", "Play again clears drawing and pending request state")
	check(root.get_node("GenerationWorker") == worker, "Navigation retains the persistent worker without submitting a request")
	await clear_scene()
	# The walk shortcut can be disabled independently of the future boss hook.
	level = forest()
	level.preview_ending_enabled = false
	level.player.set_physics_process(false)
	level.player.position = Vector3(0, 3, -13)
	await frames(5)
	check(current_scene == level, "Disabling the preview gate prevents walking past the boss")
	level.complete_boss_encounter()
	level.complete_boss_encounter()
	await frames(15)
	check(current_scene.name == "DawnForest", "Boss victory bypasses the disabled preview shortcut")
	check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Repeated completion leaves only one active world")
	await clear_scene()
	for x in [-18.0, 0.0, 18.0]:
		level = forest()
		level.player.set_physics_process(false)
		level.player.position = Vector3(x, 8, -11.75)
		await frames(3)
		check(current_scene == level, "Before the full-width boundary remains in Stage 5")
		level.player.position.z = -12.25
		await frames(12)
		check(current_scene.name == "DawnForest", "Ending boundary covers both sides and jumping")
		await clear_scene()
	print("ENDING SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
