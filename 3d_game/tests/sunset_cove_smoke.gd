extends SceneTree

var failed := false

func _initialize():
	call_deferred("run")

func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)

func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame

func world_count() -> int:
	return root.get_children().filter(func(node): return node is Node3D).size()

func run():
	var hill = load("res://scenes/wind_hill/wind_hill.tscn").instantiate()
	root.add_child(hill)
	current_scene = hill
	await frames(60)
	check(hill.player.is_on_floor(), "Wind Hill starts grounded")
	Input.action_press("move_right")
	for i in 60:
		hill.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	check(current_scene == hill, "Stopping before the rock keeps Stage 3 active")
	check(hill.player.position.x > 2.0 and hill.player.is_on_floor(), "Horizontal travel works along the path")
	if "--visual" in OS.get_cmdline_user_args():
		hill.player.respawn(Vector3(8.5, 2, -0.5))
		await frames(60)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-stage03-exit.png")
	Input.action_press("move_right")
	for i in 240:
		if not is_instance_valid(hill): break
		hill.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	await frames(60)
	var level = current_scene
	check(level != null and level.name == "SunsetCove", "Walking right reaches Stage 4 without jumping onto the rock")
	if level == null or level.name != "SunsetCove":
		quit(1)
		return
	check(not is_instance_valid(hill) and world_count() == 1, "Transition replaces only the active world")
	check(root.has_node("GenerationWorker"), "Persistent generation worker survives the transition")
	check(level.player.is_on_floor(), "Stage 4 spawn is on the beach")
	print("COVE SPAWN: ", level.player.position, " CAMERA: ", level.camera.position)
	check(is_equal_approx(level.camera.fov, 53.0), "Delivered lens is retained")
	check(level.camera == root.get_camera_3d(), "Stage 4 camera is current")
	var art = level.get_node("Stage04Art")
	var animator: AnimationPlayer = art.find_child("AnimationPlayer", true, false)
	check(animator != null and animator.is_playing(), "Delivered breeze and water loop is playing")
	check(is_equal_approx(animator.current_animation_length, 16.0), "Full 16-second animation is retained")
	var leaves: Node3D = art.find_child("Tree_Leaf_Spray", true, false)
	animator.seek(0.0, true)
	var before_leaves := leaves.transform
	animator.seek(2.0, true)
	check(not leaves.transform.is_equal_approx(before_leaves), "Foliage transforms actually animate")
	var sky: MeshInstance3D = art.find_child("Painted_Sky_Dome", true, false)
	check(sky.get_active_material(0) is ShaderMaterial, "Sky uses the mirrored-repeat paint shader")
	if sky.get_active_material(0) is ShaderMaterial:
		check(sky.get_active_material(0).get_shader_parameter("mirror_axes") == Vector2(1, 0), "Sky repeats horizontally and clamps vertically")
	var count := 0
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				check(material.vertex_color_use_as_albedo, "Painted vertex colors are preserved")
				count += 1
			elif material is ShaderMaterial:
				check(material.get_shader_parameter("paint") != null, "Mirrored paint retains its original texture")
				count += 1
	check(count >= 1305, "Complete delivered environment is present")
	for name in ["Calm_River_Surface", "Continuous_Ground_Underlay", "Painted_Leaves"]:
		check(art.find_child(name, true, false).find_children("*", "CollisionShape3D", true, false).is_empty(), "Water, foliage and background do not block traversal: " + name)
	var feet: Vector2 = level.camera.unproject_position(level.player.position)
	var head: Vector2 = level.camera.unproject_position(level.player.position + Vector3.UP * 2.6)
	check(root.get_visible_rect().has_point(feet) and root.get_visible_rect().has_point(head), "Full-size protagonist fits the camera")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-stage04.png")
	var before: Vector3 = level.player.position
	var camera_angle: Vector3 = level.camera.rotation
	Input.action_press("move_right")
	for i in 45:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	check(level.player.position.x > before.x + 1.0, "Player walks along the beach")
	check(level.player.is_on_floor(), "Beach movement stays grounded")
	check(level.camera.rotation.is_equal_approx(camera_angle), "Movement keeps the camera angle fixed")
	var ground_y: float = level.player.position.y
	Input.action_press("jump")
	level.player.window_focused = true
	await frames(5)
	Input.action_release("jump")
	check(level.player.position.y > ground_y + 0.2, "Shared jump works in Stage 4")
	await frames(60)
	check(level.player.is_on_floor(), "Player lands after jumping")
	level.player.position.y = -10
	await frames(60)
	check(level.player.is_on_floor(), "Fall recovery returns to the beach")
	level.find_child("BackButton", true, false).pressed.emit()
	await frames(30)
	check(current_scene.name == "WindHill" and not is_instance_valid(level), "Back returns to Stage 3")
	check(world_count() == 1, "Return keeps one active world")
	print("SUNSET COVE SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
