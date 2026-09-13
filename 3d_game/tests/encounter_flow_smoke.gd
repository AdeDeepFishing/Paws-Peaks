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
func ready_response() -> Dictionary:
	return {"schema_version":2,"request_id":level.request.active_id,"status":"recognized","item":{"name":"Bridge","description":"A crossing.","type":"BRIDGE","movable":false, "texture_key": "plain", "color": "#D9C6A0"}}
func prepare_draw():
	# Let the physics overlap cache observe leaving the area after a restart.
	level.player.respawn(level.SPAWN)
	await frames(3)
	level.player.respawn(Vector3(-4.6,1.5,-6.3))
	await frames(30)
	level._open_book()
	check(level.panel_mode == "draw", "Recovery scenario actually reopens drawing")
	level.surface.strokes.append(PackedVector2Array([Vector2(380,340), Vector2(700,440)]))
func capture(name: String):
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-" + name + ".png")
func run():
	level = Level.instantiate()
	level.auto_advance = false
	level.get_node("DesktopGeneration").mode = 0
	level.get_node("DrawingRequest").draft_directory = "user://test-drawings/encounter-flow"
	root.add_child(level)
	await frames(30)
	level.request.mock_mode = false
	check(not level.has_node("Coins"), "No coin pickups remain in the stage")
	check(is_equal_approx(level.get_node("StageCamera").size, 18.6), "Normal camera is about 18 percent closer")
	check(level.player.visual.scale.is_equal_approx(Vector3.ONE * 2.0), "Character visual is twice its previous size")
	check_bridgehead()
	await prepare_draw()
	var home: Transform3D = level.get_node("StageCamera").transform
	level._submit()
	check(level.presentation.busy and not level.player.input_enabled, "Submission starts locked construction closeup")
	await create_timer(0.65).timeout
	check(level.get_node("StageCamera").size < 18.6 and level.get_node("StageCamera").size > 12.1, "Camera slowly zooms in rather than snapping")
	check(level.generation_preview.mist.active, "Sketch mist is active")
	await capture("construction-closeup")
	await create_timer(1.6).timeout
	check(not level.presentation.busy and level.presentation.holding, "Camera remains focused while waiting for generation")
	check(level.player.input_enabled and level.cancel_button.visible, "Waiting preserves exploration and cancellation")
	var closeup: Transform3D = level.get_node("StageCamera").transform
	level.player.position.x -= 2.0
	await create_timer(1.0).timeout
	check(level.get_node("StageCamera").transform.is_equal_approx(closeup), "Waiting camera does not follow player movement or return early")
	check(is_equal_approx(level.get_node("StageCamera").size, 12.0), "Waiting retains the construction zoom")
	await capture("construction-waiting")
	level.request.accept_response(ready_response())
	await create_timer(0.6).timeout
	check(level.bridge.visible and not level.generation_preview.mist.active, "Result replaces sketch mist")
	await create_timer(1.0).timeout
	check(level.presentation.busy and is_equal_approx(level.get_node("StageCamera").size, 12.0), "Finished result stays visible for at least two seconds before zooming out")
	while level.presentation.busy: await level.presentation.settled
	check(level.bridge_built and level.player.input_enabled and not level.presentation.holding, "Result reveal restores controls and releases the held camera")
	check(level.get_node("StageCamera").transform.is_equal_approx(home), "Camera returns to its original framing")
	check(is_equal_approx(level.get_node("StageCamera").size, 18.6), "Camera returns to the new normal zoom")
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
	check(not level.has_node("Coins"), "Restart cannot restore removed coins")
	# A fast response must wait for the slow opening shot, then reveal once.
	await prepare_draw()
	level._submit()
	level.request.accept_response(ready_response())
	check(not level.bridge_built, "Fast result waits for construction intro")
	while level.presentation.busy: await level.presentation.settled
	check(level.bridge_built and not level.presentation.holding, "Fast result completes without a camera deadlock")
	level.restart()
	await prepare_draw()
	level._submit()
	await frames(5)
	level.request.cancel()
	await create_timer(2.0).timeout
	check(not level.presentation.busy and level.player.input_enabled and not level.generation_preview.mist.active, "Cancel during intro restores camera and input")
	check(not level.presentation.holding, "Canceled intro cannot re-enter the held camera")
	await prepare_draw()
	level._submit()
	while level.presentation.busy: await level.presentation.settled
	level.request.cancel()
	check(not level.presentation.holding and is_equal_approx(level.get_node("StageCamera").size, 18.6), "Cancel during a long wait restores normal zoom")
	level.restart()
	await prepare_draw()
	level._submit()
	level.request.fail_current("Offline failure")
	check(not level.presentation.busy and level.player.input_enabled, "Failure during intro restores controls")
	level.restart()
	level.presentation.duration_scale = 0.05
	await prepare_draw()
	level._submit()
	while level.presentation.busy: await level.presentation.settled
	level.request.deadline_ms = Time.get_ticks_msec() - 1
	await frames(3)
	check(level.request.state == "FAILED" and not level.presentation.holding and is_equal_approx(level.get_node("StageCamera").size, 18.6), "Timeout during held view restores the normal camera")
	level.restart()
	await prepare_draw()
	level._submit()
	while level.presentation.busy: await level.presentation.settled
	var unsuitable := ready_response()
	unsuitable.item.type = "UNKNOWN"
	level.request.accept_response(unsuitable)
	check(not level.bridge_built and not level.presentation.holding, "Unsuitable mock result releases the held camera for retry")
	level.restart()
	await prepare_draw()
	level._submit()
	while level.presentation.busy: await level.presentation.settled
	level.request.accept_response(ready_response())
	for frame in 10:
		if level.bridge.visible: break
		await frames(1)
	check(level.presentation.busy and level.bridge.visible, "Restart case reaches the finished-object hold")
	level.restart()
	await create_timer(0.3).timeout
	check(not level.bridge_built and not level.presentation.holding and not level.presentation.busy and is_equal_approx(level.get_node("StageCamera").size, 18.6), "Old reveal timer cannot alter a restarted stage")
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

func check_bridgehead():
	var rock: MeshInstance3D = level.get_node("Stage01Art").find_child("Lavender_boulder_06", true, false)
	var paint: MeshInstance3D = level.get_node("Stage01Art").find_child("Lavender_boulder_06_dry_brush", true, false)
	var bounds := rock.global_transform * rock.get_aabb()
	check(bounds.position.x > 8.0 and bounds.end.z < -9.0, "Blocking stone is relocated away from the bridge and exit path")
	check(rock.global_position.is_equal_approx(paint.global_position), "Rock and its hand-painted overlay move together")
	var hit := KinematicCollision3D.new()
	var approach: Transform3D = level.player.global_transform
	approach.origin = Vector3(2.5, 1.85, -6.3)
	check(not level.player.test_move(approach, Vector3(5, 0, 0), hit), "Bridgehead has no remaining rock collision")
	check(not rock.find_children("*", "CollisionShape3D", true, false).is_empty(), "Relocated rock retains solid collision")
