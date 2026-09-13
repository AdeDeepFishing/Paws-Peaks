extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")

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

func screenshot(path: String) -> void:
	if visual:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)

func run() -> void:
	JourneyTest.fast(self)
	var cove = load("res://scenes/sunset_cove/sunset_cove.tscn").instantiate()
	root.add_child(cove)
	current_scene = cove
	await frames(45)
	check(cove.player.is_on_floor(), "Stage 4 begins on the beach")
	# Approach the screenshot's cave area using actual walking, without a jump.
	Input.action_press("move_right")
	for i in 65:
		cove.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	check(current_scene == cove, "Stopping before the cave approach stays in Stage 4")
	check(cove.player.position.x > 4.0, "The cave approach is reachable on foot")
	await frames(20)
	await screenshot("/private/tmp/paws-stage04-cave-exit.png")
	Input.action_press("move_right")
	for i in 120:
		if not is_instance_valid(cove): break
		cove.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	await frames(60)
	await JourneyTest.complete(self)
	# The map presentation finishes before the chapter arrival drop lands.
	await frames(45)
	var level = current_scene
	check(level != null and level.name == "MoonlitForest", "Walking beside the cave enters Stage 5")
	if level == null or level.name != "MoonlitForest":
		quit(1)
		return
	check(not is_instance_valid(cove), "Stage 4 and its reflection viewport are released")
	check(root.has_node("GenerationWorker"), "Generation worker persists across the transition")
	check(level.player.is_on_floor(), "Stage 5 spawn is grounded")
	check(level.camera == root.get_camera_3d() and is_equal_approx(level.camera.fov, 52.0), "Stage 5 uses its delivered camera lens")
	var art := level.get_node("Stage05Art")
	check(art.find_children("*", "MeshInstance3D", true, false).size() == 514, "All V5 meshes replace the previous environment")
	check(art.find_children("Cloud_layer*", "MeshInstance3D", true, false).size() == 20, "All 12 cloud layers and 8 wisps are present")
	check(art.find_children("Midground_painted_trunk*", "MeshInstance3D", true, false).size() == 9, "All nine V5 midground trees are present")
	var sky: MeshInstance3D = art.find_child("Sky_dome", true, false)
	check(sky.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "The mirrored sky does not cast a shadow over the playable forest")
	var sky_paint: ShaderMaterial = sky.get_active_material(0)
	check(sky_paint.get_shader_parameter("paint") != null, "V5 painted sky retains its texture")
	check(sky_paint.get_shader_parameter("paint_scale").is_equal_approx(Vector2(5, 2.6)), "V5 mirrored sky tiling is preserved")
	var trunk: MeshInstance3D = art.find_child("Flowing_painted_trunk", true, false)
	var bark_paint: ShaderMaterial = trunk.get_active_material(0)
	check(bark_paint.get_shader_parameter("paint_scale").is_equal_approx(Vector2(1, 2.35)), "V5 mirrored bark tiling is preserved")
	check(art.find_children("Firefly_*", "Node3D", true, false).size() == 62, "All 62 fireflies are retained")
	var animator: AnimationPlayer = art.find_child("AnimationPlayer", true, false)
	check(animator != null and animator.is_playing(), "Forest animation is playing")
	check(animator.get_animation(animator.current_animation).loop_mode == Animation.LOOP_PINGPONG, "Non-seamless source motion reverses instead of snapping on repeat")
	var foliage: MeshInstance3D = art.find_child("Low_painted_grass_0", true, false)
	var paint: ShaderMaterial = foliage.get_active_material(0)
	check(paint != null and paint.get_shader_parameter("paint") != null, "Native foliage wind retains the delivered brush atlas")
	check(is_equal_approx(paint.get_shader_parameter("wind_strength"), 1.0), "Grass retains its authored wind amplitude")
	check(paint.get_shader_parameter("paint_scale").is_equal_approx(Vector2(0.242, 0.241)), "Brush atlas coordinates survive shader conversion")
	var cloud: Node3D = art.find_child("Cloud_layer_5", true, false)
	var fly: Node3D = art.find_child("Firefly_0", true, false)
	animator.seek(0.0, true)
	var cloud_before := cloud.position
	var fly_before := fly.position
	animator.seek(5.0, true)
	check(not cloud.position.is_equal_approx(cloud_before), "Clouds move across the moon")
	check(not fly.position.is_equal_approx(fly_before), "Fireflies follow their delivered flight paths")
	animator.seek(11.99, true)
	var before_repeat := cloud.position
	animator.advance(0.02)
	check(cloud.position.distance_to(before_repeat) < 0.1, "Cloud playback crosses the repeat boundary without teleporting")
	animator.seek(5.0, true)
	for label in ["Continuous_organic_forest_terrain", "Flowing_painted_trunk", "Painted_rounded_rock", "Midground_painted_trunk_0"]:
		check(not art.find_child(label, true, false).find_children("*", "CollisionShape3D", true, false).is_empty(), "Solid scenery has collision: " + label)
	for label in ["Cloud_layer_5", "Low_painted_grass_0", "Painted_moon"]:
		check(art.find_child(label, true, false).find_children("*", "CollisionShape3D", true, false).is_empty(), "Decorative scenery does not block movement: " + label)
	print("FOREST SPAWN: ", level.player.position, " CAMERA: ", level.camera.position)
	await screenshot("/private/tmp/paws-stage05.png")
	var before: Vector3 = level.player.position
	Input.action_press("move_up")
	for i in 45:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < before.z - 2.0 and level.player.is_on_floor(), "Player walks through the forest clearing")
	var ground_y: float = level.player.position.y
	Input.action_press("jump")
	level.player.window_focused = true
	await frames(5)
	Input.action_release("jump")
	check(level.player.position.y > ground_y + 0.2, "Player can jump in Stage 5")
	await frames(60)
	check(level.player.is_on_floor(), "Player lands on the terrain")
	level.player.position.y = -10
	await frames(60)
	check(level.player.is_on_floor(), "Fall recovery returns to the forest spawn")
	level.find_child("BackButton", true, false).pressed.emit()
	await frames(30)
	check(current_scene.name == "SunsetCove" and not is_instance_valid(level), "Back returns to Stage 4")
	await frames(10)
	check(current_scene.name == "SunsetCove", "Return spawn does not immediately re-enter Stage 5")
	check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Only one level is active")
	print("MOONLIT FOREST SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
