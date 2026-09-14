extends "res://tests/dog_presentation_smoke.gd"

func run():
	for sketch_size in [Vector2(100, 90), Vector2(430, 360), Vector2(580, 100), Vector2(110, 400)]:
		await fresh()
		await frames(120)
		level.request.draft_directory = "/private/tmp/paws-dog-framing-draft"
		level.presentation.duration_scale = 0.1
		level._open_drawing()
		var ground: Vector3 = level.player.global_position + Vector3(0, 0, -3)
		var query := PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 10, ground + Vector3.DOWN * 10, level.dog.GROUND_MASK)
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
		var screen: Vector2 = level.camera.unproject_position(hit.position)
		level.surface.reference_size = level.surface.size
		level.surface.strokes.append(PackedVector2Array([
			screen + Vector2(-sketch_size.x * 0.5, -sketch_size.y),
			screen + Vector2(sketch_size.x * 0.5, -sketch_size.y), screen]))
		level._submit()
		check(level.request.state == "PENDING", "Sketch reaches the actual submission flow")
		await wait_until(func(): return level.presentation.phase == "waiting")
		check(level.camera_follow_enabled and not level.presentation.focus_started, "Waiting preserves normal player follow")
		respond()
		await wait_until(func(): return level.presentation.phase == "revealing")
		var preview = level.generation_preview
		var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
		check(viewport.encloses(Rect2(preview.mist.position, preview.mist.size)), "Entire sketch and mist fit the close-up: " + str(sketch_size))
		check(preview.image.size.x <= preview.submitted_rect.size.x * 3.01, "Close-up keeps drawing enlargement within the intended threefold limit: " + str(sketch_size))
		for participant in [level.player.visual]:
			var points: Array[Vector3] = []
			preload("res://scripts/woodland/encounter_framing.gd").add_visual(points, participant)
			for point in points:
				check(not level.camera.is_position_behind(point) and viewport.grow(-24).has_point(level.camera.unproject_position(point)), "The protagonist remains fully framed")
		if "--visual" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/paws-dog-fit-%d.png" % int(sketch_size.x))

	# Allow the actual gravity/reveal sequence to finish before the dog approaches.
	level.presentation.duration_scale = 1.0
	await wait_until(func(): return level.dog.distracted)
	var landing: Vector3 = level.offered.global_position
	level.dog.paused = true
	# Drive the same AnimatableBody through the offering as a close fetch path.
	for i in 90:
		level.dog.global_position = landing + Vector3(lerpf(-4, 4, i / 89.0), 0, 0)
		await frames(1)
	check(level.offered.global_position.distance_to(landing) < 0.08, "The approaching dog cannot kick the revealed offering away")
	level.queue_free()
	await frames(3)
	print("DOG OFFERING FRAMING SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
