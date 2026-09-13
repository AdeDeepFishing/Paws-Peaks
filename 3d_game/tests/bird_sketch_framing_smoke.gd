extends "res://tests/bird_encounter_smoke.gd"

func run():
	visual = "--visual" in OS.get_cmdline_user_args()
	for sketch_size in [Vector2(100, 110), Vector2(430, 360), Vector2(580, 100), Vector2(110, 400)]:
		var level = fresh()
		await frames(50)
		level.presentation.duration_scale = 0.1
		level.request.mock_delay = 60
		level._open_drawing()
		var ground: Vector3 = level.player.position + Vector3(2, 0, 0.2)
		var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 10, ground + Vector3.DOWN * 10, 2))
		check(not hit.is_empty(), "Sketch has a ground contact")
		var point: Vector2 = level.camera.unproject_position(hit.position)
		# Use a canopy and handle with their padded square bottom on real terrain.
		var side := maxf(sketch_size.x, sketch_size.y)
		var center := point - Vector2(0, side * 0.56 + 5)
		level.surface.clear()
		level.surface.reference_size = level.surface.size
		level.surface.strokes.append(PackedVector2Array([
			center + Vector2(-sketch_size.x * 0.5, -sketch_size.y * 0.1),
			center + Vector2(0, -sketch_size.y * 0.5),
			center + Vector2(sketch_size.x * 0.5, -sketch_size.y * 0.1),
			center + Vector2(0, -sketch_size.y * 0.1),
			center + Vector2(0, sketch_size.y * 0.5)]))
		level._submit()
		check(level.request.state == "PENDING", "Sketch submits: " + str(sketch_size))
		check(await wait_for(func(): return level.presentation.phase == "waiting", 3), "Creation framing settles")
		await frames(3)
		var preview = level.generation_preview
		var viewport := root.get_visible_rect()
		var image_rect := Rect2(preview.image.position, preview.image.size)
		check(viewport.encloses(Rect2(preview.mist.position, preview.mist.size)), "Sketch and cover stay visible: " + str(sketch_size))
		check(image_rect.size.y > viewport.size.y * 0.39, "Creation gets a substantial close-up: " + str(sketch_size))
		check(absf(image_rect.get_center().y - viewport.get_center().y) < viewport.size.y * 0.12, "Camera centers the drawing rather than the ground")
		var held: Transform3D = level.camera.transform
		await frames(100)
		check(level.camera.transform.is_equal_approx(held), "Bird movement leaves the shot fixed")
		print("SKETCH FRAME ", sketch_size, " size=", image_rect.size / viewport.size, " center=", image_rect.get_center() / viewport.size)
		await capture("sketch-framing-%d" % int(sketch_size.x))
		level.request.cancel()
		level.queue_free()
		await frames(3)
	print("BIRD SKETCH FRAMING SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
