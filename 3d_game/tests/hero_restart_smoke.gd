extends SceneTree

var failed := false

func _initialize(): call_deferred("run")

func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame

func poses(hero: Node3D) -> Array:
	var skeleton: Skeleton3D = hero.character.find_child("Skeleton3D", true, false)
	var result := []
	for i in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose_rotation(i))
	return result

func check_pose(actual: Array, expected: Array, message: String):
	var largest := 0.0
	for i in actual.size():
		largest = maxf(largest, actual[i].angle_to(expected[i]))
	if largest > 0.01:
		failed = true
		push_error(message + " (largest bone difference: %0.3f radians)" % largest)

func run():
	var hero = load("res://scripts/river/hero_visual.gd").new()
	var reference = load("res://scripts/river/hero_visual.gd").new()
	root.add_child(hero)
	root.add_child(reference)
	await frames(5)
	# One character has run; the reference has only been standing.
	hero.set_motion(true, true, true)
	await frames(40)
	hero.set_motion(false, false, true)
	await frames(120)
	check_pose(poses(hero), poses(reference), "Stopping must fully discard the prior running pose")
	hero.set_motion(true, false, true)
	reference.set_motion(true, false, true)
	await frames(2)
	check_pose(poses(hero), poses(reference), "Restarting must look like fresh walking, without a leftover run blend")
	await frames(15)
	check_pose(poses(hero), poses(reference), "Walking remains synchronized after the transition")
	hero.queue_free()
	reference.queue_free()
	await frames(2)
	print("HERO RESTART: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
