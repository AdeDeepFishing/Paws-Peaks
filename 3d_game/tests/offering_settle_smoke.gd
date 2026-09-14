extends "res://tests/dog_presentation_smoke.gd"

func run():
	await fresh()
	start()
	respond(true, 3.5)
	var body: RigidBody3D = level.offered
	check(not body.lock_rotation and not body.axis_lock_linear_x and not body.axis_lock_linear_z, "Offering can rotate and slide")
	var collider := body.get_child(1) as CollisionShape3D
	check(collider.shape is ConvexPolygonShape3D, "Offering collision follows the mesh hull")
	level.presentation.cancel()
	# Isolate the real offering on a flat floor, away from the dog and terrain.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1 | level.dog.GROUND_MASK
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	level.add_child(floor_body)
	floor_body.global_position = Vector3(0, 99.5, 0)
	body.global_position = Vector3(0, 103, 0)
	body.rotation.z = 0.6
	var initial_basis := body.basis
	body.show()
	body.freeze = false
	body.contact_monitor = true
	body.max_contacts_reported = 4
	await wait_until(func(): return body.get_contact_count() > 0)
	check(not body.freeze, "Ground contact does not freeze the falling offering")
	await wait_until(func(): return body.sleeping, 15.0)
	check(not body.basis.is_equal_approx(initial_basis), "Offering tips into a resting orientation")
	var lowest := INF
	for point in collider.shape.points:
		lowest = minf(lowest, (body.global_transform * point).y)
	check(absf(lowest - 100.0) < 0.08, "Resting mesh touches the floor without floating or sinking")
	check(body.linear_velocity.length() < 0.05 and body.angular_velocity.length() < 0.05, "Offering comes to rest naturally")
	# The actual player must hit the settled bone rather than pass through it.
	level.player.set_physics_process(false)
	var center: Vector3 = body.global_transform * level.GeneratedModel._bounds(body.get_child(0)).get_center()
	level.player.global_position = center + Vector3.UP * 3
	var collision = level.player.move_and_collide(Vector3.DOWN * 3)
	check(collision != null and collision.get_collider() == body, "Player collides with the offering")
	check(is_equal_approx(body.mass, 3.5), "AI response mass reaches the physics body")
	# Fixed and floating modes stay anchored, even for portable items.
	for mode in ["fixed", "float"]:
		var item: Dictionary = level.request.result.duplicate(true)
		item.placement = mode
		var visual = level.GeneratedModel.load_visual(level.request.model_path, 1.5, false, item)
		var placed = level.GeneratedModel.physics_body(visual, item, true)
		level.add_child(placed)
		var height: float = 110 + level.GeneratedModel.placement_height(item)
		placed.global_position = Vector3(5, height, 0)
		await frames(3)
		check(placed is StaticBody3D and is_equal_approx(placed.global_position.y, height), mode + " remains at its placement height")
		placed.queue_free()
	level.queue_free()
	await frames(3)
	print("OFFERING SETTLE SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
