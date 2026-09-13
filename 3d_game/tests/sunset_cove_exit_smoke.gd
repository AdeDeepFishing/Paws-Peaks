extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	JourneyTest.fast(self)
	# Lateral position and jumping must not turn the cave exit into a tiny target.
	for point in [Vector3(5.25, 0.5, -12), Vector3(5.25, 0.5, 0), Vector3(5.25, 0.5, 6), Vector3(5.25, 5, 12)]:
		var cove = load("res://scenes/sunset_cove/sunset_cove.tscn").instantiate()
		root.add_child(cove)
		current_scene = cove
		cove.player.set_physics_process(false)
		cove.player.position = point
		await frames(3)
		check(current_scene == cove, "Before the cave boundary stays in Stage 4")
		cove.player.position.x = 5.75
		await frames(8)
		await JourneyTest.complete(self)
		check(current_scene.name == "MoonlitForest", "Cave boundary covers depth and airborne approaches")
		check(not is_instance_valid(cove), "Cave exit replaces Stage 4")
		current_scene.queue_free()
		await frames(3)
	print("SUNSET COVE EXIT SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
