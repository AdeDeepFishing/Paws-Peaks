extends SceneTree
var failed := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(n):
	for i in n:
		await physics_frame
		await process_frame
func run():
	var river = load("res://scenes/river/river_crossing.tscn").instantiate()
	root.add_child(river)
	current_scene = river
	await frames(20)
	river.bridge_built = true
	river.bridge.show()
	river.get_node("Bridge/Deck/CollisionShape3D").disabled = false
	river.player.respawn(Vector3(-4.8,1.6,-6.3))
	await frames(30)
	Input.action_press("move_right")
	for i in 200:
		river.player.window_focused = true
		await frames(1)
		if river.completed: break
	Input.action_release("move_right")
	check(river.completed, "Walking across reaches far bank")
	check(not river.modal.visible and river.panel_mode == "" and river.player.input_enabled, "Far bank has no completion modal or input lock")
	await frames(10)
	check(current_scene == river, "Stopping on far bank keeps the current scene")
	# Continue along the authored path (world +X, screen down-right).
	var yaw: float = river.get_node("StageCamera").rotation.y
	Input.action_press("move_right", cos(yaw))
	Input.action_press("move_down", sin(yaw))
	for i in 70:
		river.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	check(current_scene == river and river.player.position.x > 9, "The old early exit no longer changes scenes")
	check(river.player.input_enabled, "Player can keep exploring the far-bank path")
	Input.action_press("move_right", cos(yaw))
	Input.action_press("move_down", sin(yaw))
	for i in 300:
		if not is_instance_valid(river) or current_scene != river: break
		river.player.window_focused = true
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("move_down")
	await frames(30)
	check(current_scene != null and current_scene.name == "WoodlandPath", "Continuing forward automatically enters Stage 2")
	check(root.get_child_count() == 1, "Transition removes the previous scene")
	print("WALK-THROUGH TRANSITION: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
