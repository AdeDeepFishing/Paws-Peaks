extends SceneTree

var failed := false

func _initialize():
	call_deferred("run")

func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame

func run():
	# Sample both terrain edges, the lakeside shoulder, and the main path.
	for x in [-59.0, 0.0, 6.5, 25.0, 59.0]:
		var level = load("res://scenes/woodland/woodland_path.tscn").instantiate()
		root.add_child(level)
		current_scene = level
		level.player.set_physics_process(false)
		level.player.position = Vector3(x, 3, -28.25)
		await frames(3)
		if current_scene != level:
			failed = true
			push_error("Unsolved dog must gate the entire exit")
			quit(1)
			return
		# The encounter smoke test exercises collection; this test isolates the exit.
		level.dog.solved = true
		level.player.position = Vector3(x, 3, -27.5)
		await frames(3)
		if current_scene != level:
			failed = true
			push_error("Exit triggered before the boundary at x=" + str(x))
		else:
			# Crossing while airborne must work too; X and Y do not gate progress.
			level.player.position.z = -28.25
			await frames(5)
			if current_scene == null or current_scene.name != "WindHill":
				failed = true
				push_error("Crossing the exit beside the path failed at x=" + str(x))
			elif root.get_children().filter(func(node): return node is Node3D).size() != 1:
				failed = true
				push_error("Exit left multiple active scenes")
		if current_scene:
			current_scene.queue_free()
			current_scene = null
		await frames(2)
	print("WOODLAND FULL-WIDTH EXIT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
