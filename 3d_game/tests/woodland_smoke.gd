extends SceneTree
var failed := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func run():
	var level = load("res://scenes/woodland/woodland_path.tscn").instantiate()
	root.add_child(level)
	await frames(60)
	print("Spawn ",level.player.position," camera ",level.camera.position," rotation ",level.camera.rotation," fov ",level.camera.fov)
	check(level.player.is_on_floor(), "Player stands on imported terrain")
	var dog := level.get_node_or_null("Wolfdog") as StaticBody3D
	check(dog != null, "Wolfdog stands in the second-stage path")
	if dog:
		var approach: Transform3D = level.player.global_transform
		approach.origin = Vector3(0, 0.2, 1)
		var collision := KinematicCollision3D.new()
		check(level.player.test_move(approach, Vector3(0, 0, -10), collision), "Approaching the dog meets a solid body")
		check(collision.get_collider() == dog, "The dog blocks movement through its body")
	check(level.camera == root.get_camera_3d(), "Stage uses its authored camera")
	var animator: AnimationPlayer = level.get_node("Stage02Art").find_child("AnimationPlayer",true,false)
	check(animator != null and animator.is_playing(), "Wind and painted shadow animation is playing")
	var shadows: Array = level.get_node("Stage02Art").find_children("Baked_moving_ground_shadow_*", "MeshInstance3D", true, false)
	check(shadows.size() == 96, "All baked shadow frames are present")
	for time in [0.0, 0.3, 1.5, 4.0, 7.9]:
		animator.seek(time, true)
		var active := 0
		for shadow in shadows:
			if shadow.scale.length() > 0.5: active += 1
		check(active == 1, "Exactly one painted shadow frame at " + str(time))
	var feet: Vector2 = level.camera.unproject_position(level.player.position)
	var head: Vector2 = level.camera.unproject_position(level.player.position + Vector3.UP * 1.8)
	check(root.get_visible_rect().has_point(feet) and root.get_visible_rect().has_point(head), "Complete player fits in the gameplay framing")
	var material_count := 0
	for mesh in level.get_node("Stage02Art").find_children("*","MeshInstance3D",true,false):
		for i in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(i)
			if material is BaseMaterial3D:
				check(material.vertex_color_use_as_albedo, "Authored vertex colors are preserved")
				material_count += 1
	check(material_count > 300, "Imported scene is populated")
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-stage02.png")
	var before: Vector3 = level.player.position
	var angle: Vector3 = level.camera.rotation
	Input.action_press("move_up")
	for i in 60:
		level.player.window_focused = true
		await physics_frame
	Input.action_release("move_up")
	check(level.player.position.distance_to(before) > 2, "Player walks along woodland path")
	check(level.camera.rotation.is_equal_approx(angle), "Walking preserves designer camera angle")
	check(level.player.is_on_floor(), "Player remains grounded after walking")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200,100)
	Input.parse_input_event(motion)
	await frames(2)
	check(level.camera.rotation.is_equal_approx(angle), "Mouse cannot orbit camera")
	level.player.position.y = -10
	await frames(40)
	check(level.player.is_on_floor(), "Fall recovery returns to ground")
	level.queue_free()
	await frames(2)
	print("WOODLAND SMOKE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
