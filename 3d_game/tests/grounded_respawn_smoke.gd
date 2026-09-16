extends SceneTree

var failed := false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player = load("res://scenes/river/river_player.tscn").instantiate()
	player.position = Vector3(0, 8, 0)
	stage.add_child(player)
	player.set_input_enabled(false)
	await frames(5)
	check(player.placement_pending and not player.visual.visible, "Missing terrain never shows a midair player")
	check(is_equal_approx(player.position.y, 8.0), "Gravity waits for terrain registration")
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	collider.shape = shape
	ground.add_child(collider)
	ground.position.y = 2.5
	stage.add_child(ground)
	await frames(5)
	check(not player.placement_pending and player.visual.visible and player.is_on_floor(), "Player appears grounded when terrain becomes available")
	check(absf(player.position.y - 3.0) < 0.05, "Spawn follows terrain height")
	player.respawn(Vector3(2, 12, 0))
	check(not player.visual.visible, "Elevated respawn is hidden until placed")
	await frames(3)
	check(player.is_on_floor() and absf(player.position.y - 3.0) < 0.05, "Respawn lands immediately on the surface")
	check(absf(player.position.x - 2.0) < 0.01, "Respawn preserves horizontal placement")
	# Ground placement only applies at spawn; ordinary jumping still uses gravity.
	player.velocity.y = 4.5
	await frames(5)
	check(player.position.y > 3.1 and not player.placement_pending, "Normal airborne movement is preserved")
	stage.queue_free()
	await process_frame
	print("GROUNDED RESPAWN: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
