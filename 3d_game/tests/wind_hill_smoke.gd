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

func run():
	var woodland = load("res://scenes/woodland/woodland_path.tscn").instantiate()
	root.add_child(woodland)
	current_scene = woodland
	await frames(60)
	check(current_scene == woodland, "Woodland spawn does not trigger the exit")
	woodland.dog.solved = true
	woodland.player.respawn(Vector3(6.5, 3, -26.5))
	await frames(60)
	check(current_scene == woodland and woodland.player.is_on_floor(), "Player can stop before the lakeside exit")
	Input.action_press("move_up")
	for i in 60:
		if not is_instance_valid(woodland): break
		woodland.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	await frames(60)
	var level = current_scene
	check(level != null and level.name == "WindHill", "Walking into the lakeside birch path enters Stage 3")
	if level == null or level.name != "WindHill":
		quit(1)
		return
	check(not is_instance_valid(woodland) and root.get_children().filter(func(node): return node is Node3D).size() == 1, "Transition removes the old scene")
	check(level.player.is_on_floor(), "Player spawns on imported terrain")
	check(level.camera == root.get_camera_3d(), "Stage camera is current")
	check(is_equal_approx(level.camera.fov, 49.0), "Authored lens is preserved")
	var art = level.get_node("Stage03Art")
	var animator: AnimationPlayer = art.find_child("AnimationPlayer", true, false)
	check(animator != null and animator.is_playing(), "Strong wind animation plays")
	var foliage: MeshInstance3D = art.find_child("Wind_Foliage_0", true, false)
	check(foliage.mesh.get_blend_shape_count() > 0, "Wind morph targets survive import")
	animator.seek(0.0, true)
	var initial_weight := foliage.get_blend_shape_value(0)
	animator.seek(0.5, true)
	check(not is_equal_approx(initial_weight, foliage.get_blend_shape_value(0)), "Wind animation changes foliage shape")
	check(is_equal_approx(animator.current_animation_length, 16.0), "Full 16-second clip is retained")
	check(is_equal_approx(art.wind_strength, 0.8), "Wind is slightly below the delivered maximum")
	var adjusted := animator.get_animation(animator.current_animation)
	var original := animator.get_animation("Strong_Wind_16s")
	for track in original.get_track_count():
		if original.track_get_type(track) == Animation.TYPE_BLEND_SHAPE:
			for key in original.track_get_key_count(track):
				check(is_equal_approx(adjusted.track_get_key_value(track, key), original.track_get_key_value(track, key) * 0.8), "Wind deformations retain 80 percent amplitude")
	var count := 0
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is BaseMaterial3D:
				check(material.vertex_color_use_as_albedo, "Painted vertex colors are preserved")
				check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Painted lighting remains unlit")
				count += 1
	check(count >= 109, "All environment meshes are imported")
	check(art.find_child("Terrain_Ground", true, false).find_children("*", "CollisionShape3D", true, false).size() == 1, "Terrain has collision")
	check(foliage.find_children("*", "CollisionShape3D", true, false).is_empty(), "Foliage does not block walking")
	var feet: Vector2 = level.camera.unproject_position(level.player.position)
	var head: Vector2 = level.camera.unproject_position(level.player.position + Vector3.UP * 2.2)
	check(root.get_visible_rect().has_point(feet) and root.get_visible_rect().has_point(head), "Complete protagonist fits in frame")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-stage03.png")
	var before: Vector3 = level.player.position
	var angle: Vector3 = level.camera.rotation
	Input.action_press("move_right")
	for i in 60:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	check(level.player.position.x > before.x + 2.0, "Player walks along the path")
	check(level.player.is_on_floor(), "Walking remains grounded")
	check(level.camera.rotation.is_equal_approx(angle), "Movement preserves camera angle")
	Input.action_press("jump")
	level.player.window_focused = true
	await frames(5)
	Input.action_release("jump")
	check(level.player.position.y > before.y + 0.3, "Shared jump works")
	await frames(60)
	check(level.player.is_on_floor(), "Player lands after jumping")
	level.player.position.y = -10
	await frames(60)
	check(level.player.is_on_floor() and level.player.position.distance_to(level.spawn) < 3, "Fall recovery returns to spawn")
	level.find_child("BackButton", true, false).pressed.emit()
	await frames(30)
	check(current_scene.name == "WoodlandPath" and not is_instance_valid(level), "Back button returns to woodland")
	check(root.get_children().filter(func(node): return node is Node3D).size() == 1, "Return leaves one active scene")
	print("WIND HILL SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
