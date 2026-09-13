extends SceneTree

var failed := false
var level
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func run():
	for stage in ["river/river_crossing", "woodland/woodland_path", "wind_hill/wind_hill"]:
		level = load("res://scenes/" + stage + ".tscn").instantiate()
		level.get_node("DesktopGeneration").mode = 0
		level.get_node("DrawingRequest").draft_directory = "/private/tmp/paws57-mist-drafts"
		root.add_child(level)
		current_scene = level
		level.request.mock_delay = 60
		await frames(45)
		if stage.begins_with("river"):
			level.player.respawn(Vector3(-4.6,1.5,-6.3))
			await frames(30)
			level._open_book()
			level.surface.reference_size = level.surface.size
			level.surface.strokes.append(PackedVector2Array([Vector2(450,300),Vector2(570,280),Vector2(690,360)]))
		else:
			level._open_drawing()
			var point: Vector3 = level.player.position + (Vector3(0,0,-3) if stage.begins_with("woodland") else Vector3(2,0,0))
			var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP*10, point + Vector3.DOWN*10, 2))
			check(not hit.is_empty(), "Sketch has terrain: " + stage)
			var screen: Vector2 = level.camera.unproject_position(hit.position)
			level.surface.reference_size = level.surface.size
			level.surface.strokes.append(PackedVector2Array([screen + Vector2(-70,-100),screen + Vector2(0,-150),screen + Vector2(70,-100),screen]))
		level._submit()
		check(level.request.state == "PENDING", "Real scene submission starts: " + stage)
		await create_timer(2.5).timeout
		var preview = level.generation_preview
		check(preview.mist.active and preview.mist.visible and preview.mist.particles.emitting, "Shared particles run: " + stage)
		check(preview.mist.get_global_rect().intersects(root.get_visible_rect()), "Mist remains inside the camera view: " + stage)
		check(preview.mist.size.x > preview.image.size.x, "Mist surrounds rather than replaces the sketch")
		check(level.find_children("ConstructionCover", "", true, false).is_empty(), "No tent remains: " + stage)
		check(is_instance_valid(preview.world_camera), "Mist stays anchored during camera movement: " + stage)
		if "--visual" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/paws57-mist-" + stage.get_slice("/",0) + ".png")
		# Ready alone does not end the atmosphere before the model is visible.
		preview._on_state("READY")
		check(preview.mist.active, "Mist survives until the model is presented")
		preview.model_presented()
		check(not preview.mist.active and not preview.visible, "Model reveal clears mist and sketch together")
		level.request.cancel()
		check(level.player.input_enabled and not preview.mist.active, "Cancel restores normal presentation")
		level.queue_free()
		current_scene = null
		await frames(4)
	print("GENERATION MIST SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
