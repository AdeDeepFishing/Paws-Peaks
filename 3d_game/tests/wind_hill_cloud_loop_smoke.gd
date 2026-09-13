extends SceneTree

var failed := false
var visual := "--visual" in OS.get_cmdline_user_args()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var art: Node3D
	if visual:
		var level = load("res://scenes/wind_hill/wind_hill.tscn").instantiate()
		root.add_child(level)
		current_scene = level
		art = level.get_node("Stage03Art")
		for i in 30:
			await physics_frame
			await process_frame
		level.set_process(false)
		level.player.set_physics_process(false)
	else:
		art = load("res://models/stage03/wind_hill.glb").instantiate()
		art.set_script(load("res://scripts/wind_hill/wind_hill_art.gd"))
		root.add_child(art)
		current_scene = art
	var animators := art.find_children("*", "AnimationPlayer", true, false)
	for player in animators:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clouds := art.find_children("Cloud_Layer_*", "MeshInstance3D", true, false)
	var previous: Array[Vector3] = []
	var shape_vertices: Array = []
	var bases: Array[Vector3] = []
	var prior_vertex: Array[Vector3] = []
	var last_step: Array[Vector3] = []
	var distance: Array[float] = []
	if clouds.size() != 11:
		failed = true
		push_error("The test requires all 11 delivered cloud layers")
	for player in animators:
		player.seek(0, true)
	for cloud in clouds:
		var targets: Array[Vector3] = []
		for shape in cloud.mesh.surface_get_blend_shape_arrays(0):
			targets.append(shape[Mesh.ARRAY_VERTEX][0])
		shape_vertices.append(targets)
		bases.append(cloud.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0])
		prior_vertex.append(deformed_vertex(cloud, targets, bases.back()))
		previous.append(cloud.position)
		last_step.append(Vector3.ZERO)
		distance.append(0.0)
	var worst := 0.0
	var worst_time := 0.0
	var sharpest_turn := 0.0
	var worst_shape_step := 0.0
	# Drive the real runtime animations through two slow cloud cycles at 60 FPS.
	for frame in range(1, 7682):
		for player in animators:
			player.advance(1.0 / 60.0)
		for i in clouds.size():
			var vertex := deformed_vertex(clouds[i], shape_vertices[i], bases[i])
			worst_shape_step = maxf(worst_shape_step, vertex.distance_to(prior_vertex[i]))
			prior_vertex[i] = vertex
			var displacement: Vector3 = clouds[i].position - previous[i]
			var step := displacement.length()
			distance[i] += step
			if frame > 1:
				sharpest_turn = maxf(sharpest_turn, displacement.distance_to(last_step[i]))
			last_step[i] = displacement
			if step > worst:
				worst = step
				worst_time = frame / 60.0
			previous[i] = clouds[i].position
	if worst > 0.1:
		failed = true
		push_error("Cloud teleports %.3f world units in one frame at %.3fs" % [worst, worst_time])
	if worst_shape_step > 0.1:
		failed = true
		push_error("Cloud geometry snaps %.6f units in one frame" % worst_shape_step)
	if sharpest_turn > 0.002:
		failed = true
		push_error("Cloud velocity changes abruptly: %.6f" % sharpest_turn)
	for travelled in distance:
		if travelled < 10.0:
			failed = true
			push_error("Clouds must keep drifting rather than freeze to hide the reset")
	print("CLOUD SHAPE: largest vertex step %.6f" % worst_shape_step)
	print("CLOUD TURN: largest per-frame velocity change %.6f" % sharpest_turn)
	print("CLOUD LOOP: ", "FAIL" if failed else "PASS", " | largest step %.6f at %.3fs" % [worst, worst_time])
	if visual:
		for time in [15.9667, 16.0333, 31.9667, 32.0333, 63.9667, 64.0333]:
			for player in animators:
				player.seek(0, true)
				player.advance(time)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/paws-stage03-cloud-%.3f.png" % time)
	quit(1 if failed else 0)

func deformed_vertex(cloud: MeshInstance3D, targets: Array, base: Vector3) -> Vector3:
	var vertex := base
	for shape in targets.size():
		var offset: Vector3 = targets[shape]
		if cloud.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
			offset -= base
		vertex += offset * cloud.get_blend_shape_value(shape)
	return cloud.transform * vertex
