extends SceneTree

var failed := false
func _initialize(): call_deferred("run")
func frame():
	await physics_frame
	await process_frame
func run():
	var level = load("res://scenes/wind_hill/wind_hill.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	for i in 60: await frame()
	level.request.state = "READY"
	level.offered = level.GeneratedModel.load_visual(ProjectSettings.globalize_path("res://../docs/test-artifacts/stage3-2026-09-13/model.glb"), 3.0, false)
	level.add_child(level.offered)
	level.offered.position = level.player.position + Vector3(2,0,0)
	var origin: Vector3 = level.player.position
	level._raise_protection()
	var maximum_lift := 0.0
	for i in 420:
		await frame()
		maximum_lift = maxf(maximum_lift, level.player.position.y - origin.y)
		if level.player.position.y > origin.y + 0.08 or (level.resolving and level.player.visual.position.y > 0.08):
			failed = true
	if not level.solved: failed = true
	print("PROTECTION PLAYER MAX LIFT: ", snappedf(maximum_lift, 0.001))
	print("BIRD GROUNDING SMOKE: ", "FAIL" if failed else "PASS")
	level.queue_free()
	await frame()
	quit(1 if failed else 0)
