extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")

var failed := false

func _initialize():
	call_deferred("run")

func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame

func run():
	JourneyTest.fast(self)
	# A vertical screen boundary covers near/far ground positions and jump heights.
	for point in [Vector3(9.25, 0, -27), Vector3(9.25, 0, -0.5), Vector3(9.25, 5, 0), Vector3(9.25, 0, 13)]:
		var hill = load("res://scenes/wind_hill/wind_hill.tscn").instantiate()
		root.add_child(hill)
		current_scene = hill
		hill.player.set_physics_process(false)
		# Encounter completion is separately covered by bird_encounter_smoke.
		hill.solved = true
		hill.player.position = point
		await frames(3)
		if current_scene != hill:
			failed = true
			push_error("Stage 3 exits before reaching the rock boundary")
		else:
			hill.player.position.x = 9.75
			await frames(5)
			await JourneyTest.complete(self)
			if current_scene == null or current_scene.name != "SunsetCove":
				failed = true
				push_error("Full-depth exit did not trigger at " + str(point))
		if current_scene:
			current_scene.queue_free()
			current_scene = null
		await frames(2)
	print("WIND HILL VERTICAL EXIT: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
