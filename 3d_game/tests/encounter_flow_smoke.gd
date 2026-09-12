extends SceneTree
const Level = preload("res://scenes/river/river_crossing.tscn")
var failures: Array[String] = []
var level
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures.append(message)
		push_error(message)
func frames(n: int):
	for i in n:
		if is_instance_valid(level): level.player.window_focused = true
		await physics_frame
		await process_frame
func visible_coins() -> int:
	var count := 0
	for coin in level.get_node("Coins").get_children():
		if coin.visible: count += 1
	return count
func ready_response() -> Dictionary:
	return {"schema_version":2,"request_id":level.request.active_id,"status":"recognized","item":{"name":"Bridge","description":"A crossing.","type":"TOOL","attack_power":0,"range":6,"speed":1,"durability":8,"tags":["LONG_REACH","STURDY"]}}
func prepare_draw():
	level.player.respawn(Vector3(-4.6,1.5,-6.3))
	await frames(30)
	level._open_book()
	level.surface.strokes.append(PackedVector2Array([Vector2(380,340), Vector2(700,440)]))
func capture(name: String):
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-" + name + ".png")
func run():
	level = Level.instantiate()
	level.get_node("DesktopGeneration").mode = 0
	level.drawing_export_directory = "user://test-drawings/encounter-flow"
	root.add_child(level)
	await frames(30)
	level.request.mock_mode = false
	check(visible_coins() == 0, "No coins before drawing")
	await prepare_draw()
	var home: Transform3D = level.get_node("StageCamera").transform
	level._submit()
	check(level.presentation.busy and not level.player.input_enabled, "Submission starts locked construction closeup")
	check(visible_coins() == 0, "Coins stay hidden during construction closeup")
	await create_timer(0.65).timeout
	check(level.get_node("StageCamera").size < 15, "Camera zooms into construction")
	check(is_instance_valid(level.presentation.cover), "Construction tarp exists")
	await capture("construction-closeup")
	level.request.accept_response(ready_response())
	check(not level.bridge_built, "Fast result waits for construction intro")
	await create_timer(1.25).timeout
	check(visible_coins() == 8 and level.presentation.coins_released, "Coins drop only after intro returns")
	while level.presentation.busy: await level.presentation.settled
	check(level.bridge_built and level.player.input_enabled, "Result reveal restores controls")
	check(level.get_node("StageCamera").transform.is_equal_approx(home), "Camera returns to its original framing")
	check(not is_instance_valid(level.presentation.cover), "Finished result removes construction tarp")
	for coin in level.get_node("Coins").get_children():
		check(coin.position.x < -6, "Reward coin is on accessible near bank")
		var query := PhysicsShapeQueryParameters3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		query.shape = capsule
		query.transform.origin = coin.position + Vector3.UP * 0.28
		query.exclude = [level.player.get_rid()]
		var overlaps: Array = level.get_world_3d().direct_space_state.intersect_shape(query)
		check(overlaps.is_empty(), "Coin " + str(coin.name) + " has standing room")
	await capture("construction-complete")
	level.player.respawn(Vector3(-4.8,1.6,-5.85))
	await frames(30)
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	var stopped: Vector3 = level.player.position
	await frames(15)
	check(absf(level.player.position.x - stopped.x) < 0.1, "Releasing input stops bridge travel")
	check(absf(level.player.position.z + 6.3) < 0.2, "Bridge assist centers a single-key crossing")
	Input.action_press("move_left")
	await frames(20)
	Input.action_release("move_left")
	check(level.player.position.x < stopped.x - 0.5, "Reverse input walks back along bridge")
	Input.action_press("move_right")
	await frames(180)
	Input.action_release("move_right")
	check(level.completed, "Single right key reaches opposite bank")
	level.restart()
	check(visible_coins() == 0, "Restart hides reward coins")
	await prepare_draw()
	level._submit()
	await frames(5)
	level.request.cancel()
	await create_timer(2.0).timeout
	check(not level.presentation.busy and level.player.input_enabled and not is_instance_valid(level.presentation.cover), "Cancel during intro restores camera and input")
	check(visible_coins() == 0, "Canceled intro cannot release coins later")
	await prepare_draw()
	level._submit()
	level.request.fail_current("Offline failure")
	check(not level.presentation.busy and level.player.input_enabled, "Failure during intro restores controls")
	level.restart()
	# This meadow route used to stop at z=1.33 against the obsolete Boundary2.
	level.player.respawn(Vector3(-9,2,0))
	await frames(30)
	var yaw: float = level.get_node("StageCamera").rotation.y
	var axes := Basis(Vector3.UP,-yaw) * Vector3(0,0,1)
	Input.action_press("move_left",-axes.x)
	Input.action_press("move_down",axes.z)
	await frames(80)
	Input.action_release("move_left")
	Input.action_release("move_down")
	check(level.player.position.z > 3, "Open meadow no longer has the old invisible wall")
	level.queue_free()
	await frames(2)
	print("ENCOUNTER FLOW: " + ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)
