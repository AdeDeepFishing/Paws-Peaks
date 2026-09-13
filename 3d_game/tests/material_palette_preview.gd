extends SceneTree

# Replay an already generated Stage 2 result; this script never submits paid work.
func _initialize(): call_deferred("run")

func run():
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		push_error("Provide a saved Stage 2 result folder, texture key and #RRGGBB color")
		quit(1)
		return
	var folder: String = args[0].simplify_path()
	var summary_path := folder.path_join("result.json")
	if not FileAccess.file_exists(summary_path): summary_path = folder.path_join("description.json")
	var summary = JSON.parse_string(FileAccess.get_file_as_string(summary_path))
	summary.item["texture_key"] = args[1]
	summary.item["color"] = args[2]
	root.size = Vector2i(1280, 800)
	var level = load("res://scenes/woodland/woodland_path.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	level.request.mock_mode = false
	level.request.draft_directory = "user://test-drawings/material-texture"
	for i in 60: await physics_frame
	level._open_drawing()
	var front: Vector3 = level.player.global_position + Vector3(0, 0, -3)
	var query := PhysicsRayQueryParameters3D.create(front + Vector3.UP * 10, front + Vector3.DOWN * 10, level.dog.GROUND_MASK)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("No ground for the Stage 2 preview")
		quit(1)
		return
	var source := Image.load_from_file(folder.path_join("input.png"))
	source.resize(512, 512)
	if not level.request.submit(source.save_png_to_buffer(), "E02"):
		quit(1)
		return
	level.sketch_anchor = hit.position
	level.sketch_request_id = level.request.active_id
	level.generation_preview.anchor_to_world(level.camera, hit.position)
	level.presentation.begin(level._offering_position())
	level._close_drawing()
	# Step aside after submitting so the protagonist does not obscure the test object.
	level.player.position.x -= 4.0
	level.generation.job_dir = folder
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	level.generation.consume_status({"schema_version": 1, "request_id": level.request.active_id,
		"encounter_id": "E02", "game_stage": "dog", "stage": "complete", "status": "SUCCEEDED",
		"item": summary.item, "model_path": folder.path_join("model.glb"),
		"reference_path": folder.path_join("reference.png")})
	var deadline := Time.get_ticks_msec() + 10000
	while (not is_instance_valid(level.offered) or not level.offered.visible) and Time.get_ticks_msec() < deadline:
		await process_frame
	if not is_instance_valid(level.offered) or not level.offered.visible:
		push_error("Saved model failed to render: " + level.request.message)
		quit(1)
		return
	var visual = level.offered.get_child(0)
	var material = visual.get_child(0).material_override
	if not material is StandardMaterial3D or not material.uv1_triplanar or material.albedo_texture == null:
		push_error("Material did not reach the offered model")
		quit(1)
		return
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var preview_dir := ProjectSettings.globalize_path("res://../backend/output/material-palette")
	DirAccess.make_dir_recursive_absolute(preview_dir)
	root.get_texture().get_image().save_png(preview_dir.path_join("in-game-" + args[1] + ".png"))
	print("STAGE 2 PALETTE RENDER: PASS")
	await create_timer(4.0).timeout
	if summary.item.type == "UNKNOWN":
		while level.presentation.active: await process_frame
		if level.dog.distracted or level.can_exit():
			push_error("UNKNOWN object must not advance the encounter")
			quit(1)
			return
		level._open_drawing()
		if not level.drawing or not is_instance_valid(level.offered):
			push_error("UNKNOWN object must allow another sketch")
			quit(1)
			return
		print("UNKNOWN RENDER AND RETRY: PASS")
	quit()
