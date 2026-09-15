extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")

const Level = preload("res://scenes/wind_hill/wind_hill.tscn")
var failed := false
var visual := false

func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	if not value:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String):
	if not visual: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws34-" + label + ".png")
func wait_for(predicate: Callable, seconds: float) -> bool:
	for i in int(seconds * 60):
		if predicate.call(): return true
		await frames(1)
	return predicate.call()
func sketch(level):
	var ground: Vector3 = level.player.position + Vector3(2.0, 0, 0.2)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ground + Vector3.UP * 10, ground + Vector3.DOWN * 10, 2))
	check(not hit.is_empty(), "Drawing target is real terrain")
	if hit.is_empty(): return
	var point: Vector2 = level.camera.unproject_position(hit.position)
	level.surface.clear()
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([point + Vector2(-50,-80), point + Vector2(0,-110), point + Vector2(50,-80), point + Vector2(0,-80), point]))
	level.surface.changed.emit()
func fresh():
	var level = Level.instantiate()
	root.add_child(level)
	current_scene = level
	level.generation.configure(0)
	level.modes.select(1)
	level.request.draft_directory = "/private/tmp/paws34-test-drawings"
	level.request.mock_delay = 0.1
	level.presentation.duration_scale = 1.0 if visual else 0.01
	return level
func draw(level, outcome: int):
	level._open_drawing()
	check(level.drawing and not level.player.input_enabled and not level.bird.paused, "Drawing locks movement while the bird keeps flying")
	sketch(level)
	level.choices.select(outcome)
	level._submit()
	check(not level.drawing, "Accepted submission closes canvas")
func run():
	JourneyTest.fast(self)
	visual = "--visual" in OS.get_cmdline_user_args()
	var level = fresh()
	check(await wait_for(func(): return not level.entering, 8), "Entrance finishes before interaction")
	await capture("entry")
	check(not level.can_exit(), "Entry remains gated")
	check(level.bird.get_child_count() == 1 and level.bird.visual.visible, "Exactly one giant bird guards the hill")
	check(is_equal_approx(level.bird.visual.get_child(0).scale.x, 2.8), "Bird is 30 percent smaller than the previous giant")
	check(level.bird.animators.size() == 1, "One bird uses the delivered flapping clip")
	check(await wait_for(func(): return level.bird.phase == "swooping", 9.0), "Bird arrives, circles, then swoops")
	await frames(65)
	check(level.player.visual.action == "knockdown", "Bird contact starts the delivered knockdown without health damage")
	await capture("dodge")
	level._open_drawing()
	var stopped: Vector3 = level.bird.visual.position
	await frames(12)
	check(level.bird.visual.position.distance_to(stopped) > 0.01, "Drawing keeps bird flight active")
	check(level.bird.animators[0].speed_scale == 1, "Drawing keeps flap animation active")
	level._close_drawing()
	# The physical guard covers the whole level, independent of height and depth.
	var home: Vector3 = level.player.position
	for point in [Vector3(15,0,-27), Vector3(15,8,0), Vector3(15,0,13)]:
		level.player.position = point
		level.constrain_player(level.player)
		check(level.player.position.x == level.GUARD_X, "No shoulder/jump bypass")
	level.player.respawn(home + Vector3.UP)
	await frames(50)
	for outcome in [2,3,4]:
		draw(level, outcome)
		check(await wait_for(func(): return level.request.state == "FAILED", 3), "Unclear/service/unsuitable results fail safely")
		check(not level.can_exit() and level.player.input_enabled and not level.presentation.active, "Failure restores control without unlocking")
		check(level.surface.has_drawing(), "Retry retains the latest sketch")
	# Cancel during the initial camera focus and reject late replies.
	level.request.mock_delay = 10
	draw(level, 0)
	var old_id: String = level.request.active_id
	level.request.cancel()
	check(not level.presentation.active and level.player.input_enabled, "Cancel restores camera and controls")
	check(not level.request.accept_response({"request_id":old_id}), "Canceled replies are ignored")
	level.request.mock_delay = 4.0 if visual else 0.1
	draw(level, 0)
	check(not level.can_exit(), "Pending protection does not unlock")
	if visual:
		check(await wait_for(func(): return level.presentation.phase == "waiting", 4), "Cover camera settles while generation is pending")
		await capture("cover")
	check(await wait_for(func(): return level.presentation.phase == "revealing" or level.resolving, 5), "Cover reveals after focus")
	if visual:
		await frames(32)
		await capture("model")
	check(await wait_for(func(): return level.bird.phase == "blocked", 8), "Bird reacts only after reveal and zoom out")
	check(not level.can_exit() and level.offered.get_parent() == level.player, "Protection is equipped while exit stays closed")
	check(not level.generation_preview.visible, "Original sketch disappears after model reveal")
	var protection_bounds: AABB = level.GeneratedModel._bounds(level.offered)
	check(is_equal_approx(maxf(protection_bounds.size.x, protection_bounds.size.z) * level.offered.scale.x, 10.0), "Equipped protection grows to the giant bird wingspan")
	check(level.bird.protection_top > 3.1 + protection_bounds.end.y * level.offered.scale.y, "Bird stays above the enlarged canopy")
	if visual:
		await wait_for(func(): return level.bird.phase == "blocked" and level.bird.elapsed >= 0.8, 2)
		level.bird.paused = true
		await capture("protect")
		level.bird.paused = false
	var grounded_y: float = level.player.position.y
	check(await wait_for(func(): return level.bird.phase == "departing", 7), "Blocked bird departs")
	check(is_instance_valid(level.offered) and level.offered.get_parent() == level, "Protection detaches from the player on departure")
	check(await wait_for(func(): return level.solved, 5), "Bird flies away and clears the route")
	check(absf(level.player.position.y - grounded_y) < 0.1 and not is_instance_valid(level.offered), "Protection leaves without lifting the player or remaining equipped")
	check(level.player.input_enabled and not level.bird.visible, "Success restores movement and removes the bird")
	await capture("clear")
	level.player.position.y = -10
	await frames(60)
	check(level.solved and level.player.is_on_floor(), "Fall recovery retains completion")
	level.player.position = Vector3(10, 5, -20)
	await frames(8)
	await JourneyTest.complete(self)
	check(current_scene != null and current_scene.name == "SunsetCove", "Cleared full-width boundary enters Stage 4")
	current_scene.queue_free()
	current_scene = null
	await frames(3)
	# The second supported drawing takes the same complete route.
	level = fresh()
	check(await wait_for(func(): return not level.entering, 8), "Retry scene finishes its entrance")
	draw(level, 1)
	check(await wait_for(func(): return level.solved, 12), "Shield also protects and clears the bird")
	level.queue_free()
	current_scene = null
	await frames(3)
	# Exercise the live model branch with an existing committed umbrella; no worker calls.
	level = fresh()
	check(await wait_for(func(): return not level.entering, 8), "Saved-model scene finishes its entrance")
	check_submission_fallback(level)
	level.request.mock_delay = 30.0
	for kind in ["BOW", "MAGIC"]:
		draw(level, 0)
		level.request.accept_response({"schema_version":2, "request_id":level.request.active_id, "status":"recognized", "item":{"name":"Unsupported idea", "description":"Use protection instead.", "type":kind, "movable":true, "texture_key":"fabric", "color":"#D6B886"}})
		check(level.request.state == "FAILED" and not level.can_exit(), "Unsupported class gives a retry: " + kind)
	# Missing model is recoverable and never substitutes a mock in live mode.
	draw(level, 0)
	check(level.generation.mode == 0, "Saved-model test never starts the backend")
	level.request.mock_mode = false
	level.request.accept_response({"schema_version":2, "request_id":level.request.active_id, "status":"recognized", "item":{"name":"Umbrella", "description":"Protects from the bird.", "type":"DEFENCE", "movable":true, "texture_key":"fabric", "color":"#D6B886"}, "model_path":"/private/tmp/paws34-missing-model.glb"})
	check(level.request.state == "FAILED" and not level.can_exit(), "Missing generated model fails safely")
	level.request.mock_mode = true
	draw(level, 0)
	level.request.mock_mode = false
	var response := {"schema_version":2, "request_id":level.request.active_id, "status":"recognized", "item":{"name":"Umbrella", "description":"Protects from the bird.", "type":"DEFENCE", "movable":true, "texture_key":"fabric", "color":"#D6B886"}, "model_path":ProjectSettings.globalize_path("res://../docs/test-artifacts/stage3-2026-09-13/model.glb")}
	level.request.accept_response(response)
	check(not level.request.accept_response(response), "Duplicate completion cannot restart protection")
	if visual:
		check(await wait_for(func(): return level.bird.phase == "blocked", 8), "Generated umbrella is raised before the bird reacts")
		level.bird.paused = true
		await capture("generated-protect")
		level.bird.paused = false
	check(await wait_for(func(): return level.solved, 12), "Existing generated umbrella loads, equips and clears the bird")
	await capture("generated-umbrella")
	level.queue_free()
	current_scene = null
	await frames(3)
	print("BIRD ENCOUNTER SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func check_submission_fallback(level):
	level._open_drawing()
	check(level.drawing, "Drawing opens after the entrance")
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([Vector2(600, 8), Vector2(640, 12), Vector2(680, 8)]))
	level.surface.changed.emit()
	level.submit_button.pressed.emit()
	check(level.request.state == "PENDING" and not level.drawing, "Sky sketch starts generation through the submit button")
	check(level.sketch_anchor.distance_to(level.player.global_position) < 5, "Fallback places the object near the player")
	level.request.cancel()
	var home: Vector3 = level.player.global_position
	level._open_drawing()
	level.player.set_physics_process(false)
	level.player.global_position = Vector3(1000, 100, 1000)
	level.submit_button.pressed.emit()
	check(level.drawing and level.request.state != "PENDING", "Missing terrain preserves the draft")
	check(root.get_node("Narrator").panel.caption_text.text.contains("No safe ground"), "Placement failure is immediately visible")
	level.player.global_position = home
	level.player.set_physics_process(true)
	level._close_drawing()
