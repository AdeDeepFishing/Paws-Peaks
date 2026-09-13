extends SceneTree

const Level = preload("res://scenes/woodland/woodland_path.tscn")
var failed := false
var seen_states: Array[String] = []

func _initialize():
	call_deferred("run")

func check(value: bool, message: String):
	if not value:
		failed = true
		push_error(message)

func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame

func capture(label: String):
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws38-" + label + ".png")

func draw(level, outcome: int):
	level._open_drawing()
	check(level.drawing and not level.player.input_enabled, "Drawing locks player movement")
	check(not level.hud_root.visible, "Only the canvas toolbar remains while drawing")
	level.surface.strokes.append(PackedVector2Array([Vector2(200, 100), Vector2(250, 180), Vector2(300, 100)]))
	level.surface.changed.emit()
	check(not level.submit_button.disabled, "Adding ink enables the offer button")
	level.choices.selected = outcome
	level._submit()
	check(not level.drawing and level.player.input_enabled, "Submit restores exploration")
	await frames(12)

func run():
	var level = Level.instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	level.modes.select(1)
	level.request.mock_delay = 0.05
	level.dog.state_changed.connect(func(state: String): seen_states.append(state))
	await frames(60)
	check(level.dog.state == "idle", "Dog idles before the player approaches")
	for clip in ["idle", "alert", "walk", "run", "jump", "rest"]:
		check(level.dog.animator.has_animation("encounter/" + clip), "Delivered clip imported: " + clip)
	check(not level.can_exit(), "Unsolved encounter keeps exit closed")
	await capture("idle")
	level.player.respawn(Vector3(0, 0.1, 0))
	await frames(8)
	check(level.dog.state == "alert", "Approach triggers idle alert")
	await capture("alert")
	level.player.respawn(Vector3(8, 0.1, 0))
	await frames(55)
	check(level.dog.position.x > 2, "Dog moves sideways to intercept the player")
	check(level.dog.state in ["block_run", "block_walk", "alert"], "Interception plays movement clips")
	await capture("blocking")
	for x in [-59.0, 0.0, 59.0]:
		level.player.position = Vector3(x, 5, -30)
		await frames(2)
		check(current_scene == level and level.player.position.z >= level.GUARD_Z - 0.001, "Cannot bypass the dog at any X or jump height")
	level.player.respawn(Vector3(0, 0.1, 0))
	await frames(90)
	level._open_drawing()
	level._submit()
	check(level.drawing and level.request.state == "IDLE", "Empty sketch cannot submit")
	level.surface.strokes.append(PackedVector2Array([Vector2(100, 100), Vector2(150, 150)]))
	level.surface.changed.emit()
	var draft: PackedByteArray = level.surface.snapshot_png()
	await capture("canvas")
	level._close_drawing()
	level._open_drawing()
	check(level.surface.snapshot_png() == draft, "Closing the canvas preserves the draft")
	level._close_drawing()
	for outcome in [2, 3, 4]:
		await draw(level, outcome)
		check(level.request.state == "FAILED" and not level.can_exit(), "Unclear, failure, and unrelated drawings allow retry without opening the exit")
		check(level.surface.has_drawing(), "Failed request preserves the sketch")
	level._open_drawing()
	level.request.mock_delay = 0.15
	level.choices.selected = 0
	level._submit()
	var old_id: String = level.request.active_id
	level.request.cancel()
	await frames(20)
	check(level.request.state == "IDLE" and not level.dog.distracted, "Canceled result cannot distract the dog")
	check(not level.request.accept_response({"request_id": old_id}), "Stale response is rejected")
	level._open_drawing()
	level._submit()
	level.request.deadline_ms = Time.get_ticks_msec() - 1
	await frames(12)
	check(level.request.state == "FAILED" and not level.can_exit(), "Timeout keeps the path closed and permits retry")
	# A ready result belongs to this encounter even after the player walks away.
	level._open_drawing()
	level._submit()
	level.player.respawn(Vector3(0, 0.2, 24))
	await frames(20)
	check(level.request.state == "READY" and not level.dog.distracted, "Result waits for the player to return before offering")
	level._offer_item()
	check(not level.dog.distracted, "Distant use is rejected")
	level.player.respawn(Vector3(0, 0.1, 0))
	await frames(30)
	# Exercise the same model-loader boundary as a desktop response without a paid call.
	level.request.model_path = "res://project.godot"
	level._offer_item()
	check(level.request.state == "FAILED" and not level.dog.distracted, "Invalid model preserves retry and cannot clear the dog")
	level.request.mock_delay = 0.05
	seen_states.clear()
	await draw(level, 0)
	check(level.request.state == "READY" and level.dog.state == "jump", "Food triggers one excited jump")
	check(not level.can_exit(), "Jump alone does not unlock the path")
	check(level.item.size() == 3 and level.item.type == "FOOD", "Offering accepts the three-field item contract")
	var offered: Node3D = level.offered
	level._offer_item()
	check(level.offered == offered and level.item.size() == 3, "Repeated offer cannot replay or duplicate the object")
	await capture("jump")
	for i in 600:
		await frames(1)
		if level.can_exit(): break
	check("fetch_run" in seen_states and "fetch_walk" in seen_states, "Dog runs to the offering and slows down to collect it")
	check(level.can_exit() and level.dog.position.x < -4, "Collection leaves the dog off the main path and opens the exit")
	check(level.dog.has_node("Thanks"), "Collection displays a heart and thank-you")
	await capture("collected")
	level.player.respawn(Vector3(0, 0.1, 0))
	await frames(12)
	level.player.position.z = -6
	await frames(3)
	check(level.player.position.z < level.GUARD_Z, "Solved encounter permits passage")
	level.player.position = Vector3(59, 5, -30)
	await frames(8)
	check(current_scene != null and current_scene.name == "WindHill", "Solved exit still supports full-width airborne crossing")
	current_scene.queue_free()
	await frames(3)
	# A fresh stage resets the dog and supports the independent toy route.
	level = Level.instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	level.request.mock_delay = 0.05
	await frames(60)
	check(not level.can_exit() and level.offered == null, "Fresh stage resets encounter progress")
	level.player.respawn(Vector3(0, 0.1, 0))
	await frames(35)
	await draw(level, 1)
	check(level.item.type == "TOY" and level.dog.distracted, "Toy is a second accepted route")
	for i in 600:
		await frames(1)
		if level.can_exit(): break
	check(level.can_exit(), "Toy collection also opens the path")
	level.queue_free()
	await frames(3)
	print("DOG ENCOUNTER SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
