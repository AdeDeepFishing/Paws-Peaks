extends "res://tests/dog_presentation_smoke.gd"

func run():
	await fresh()
	start()
	respond()
	var body: RigidBody3D = level.offered
	check(not body.lock_rotation and not body.axis_lock_linear_x and not body.axis_lock_linear_z, "Offering can rotate and slide")
	var collider := body.get_child(1) as CollisionShape3D
	check(collider.shape is ConvexPolygonShape3D, "Offering collision follows the mesh hull")
	level.presentation.cancel()
	# Isolate the real offering on a flat floor, away from the dog and terrain.
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = level.dog.GROUND_MASK
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
	level.queue_free()
	await frames(3)
	print("OFFERING SETTLE SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
