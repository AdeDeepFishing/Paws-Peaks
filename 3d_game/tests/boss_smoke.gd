extends SceneTree

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
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	level.preview_ending_enabled = false
	for i in 600:
		await frames(1)
		if not level.entering and level.boss_revealed and level.player.input_enabled: break
	check(not level.entering and level.boss_revealed, "Stage 5 entrance and reveal complete")
	check_generation(level)
	var boss = level.get_node("Storykeeper")
	check(boss.grounded, "The Storykeeper settles on the forest terrain")
	check(boss.get_node("Character").scale.is_equal_approx(Vector3.ONE*1.6), "Boss retains giant scale")
	check(not boss.anger_clip.is_empty(), "Supplied page cycle is available")
	boss.express("angry")
	check(boss.animator.is_playing(), "Anger starts the delivered page cycle")
	check(is_equal_approx(boss.animator.current_animation_length,6.2), "Full delivered cycle is retained")
	boss._idle()
	Input.action_press("move_up")
	for i in 180:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < -2.0, "The player can approach the giant boss")
	check(level.player.position.z > boss.position.z + .5, "The player cannot walk through the boss body")
	check(level.player.is_on_floor(), "Approaching the boss keeps the player grounded")
	var start_position: Vector3 = boss.position
	level.released = true
	boss.make_way()
	await frames(130)
	check(is_equal_approx(boss.position.x, start_position.x - 1.5) and is_equal_approx(boss.position.z, start_position.z), "Release shifts the boss left by 1.5 units")
	check(absf(boss.rotation.y-PI/2)<.01, "Release turns the boss ninety degrees")
	level.preview_ending_enabled = false
	level.player.position = Vector3(1.2,level.player.position.y,0)
	Input.action_press("move_up")
	for i in 170:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < -8, "Player can pass beside the rotated narrow collider")
	print("BOSS APPROACH: ", level.player.position, " BOSS: ", boss.position)
	print("BOSS SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func check_generation(level) -> void:
	var generator = level.get_node("ObjectGeneration")
	generator.generation.configure(0)
	generator.request.mock_mode = false
	var panel = root.get_node("Narrator").panel
	panel._draw_idea()
	panel.surface.reference_size = panel.surface.size
	panel.surface.strokes.append(PackedVector2Array([Vector2(500,300),Vector2(600,400)]))
	panel.surface.changed.emit()
	panel._share_drawing()
	check(generator.request.state == "PENDING" and generator.request.encounter_id == "E05", "Sharing starts Stage 5 object generation")
	check(not panel.canvas_panel.visible and panel.surface.has_drawing(), "Submitted sketch is retained after closing the canvas")
	var response := {"schema_version":2, "request_id":generator.request.active_id, "status":"recognized", "item":{"name":"Bone", "description":"A sample object.", "type":"UNKNOWN", "movable":true, "mass_kg":2.5, "placement":"float", "texture_key":"bone", "color":"#E8D9B7"}, "model_path":ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb")}
	check(generator.request.accept_response(response), "Stage 5 accepts the generated result")
	check(is_instance_valid(generator.object) and generator.object is StaticBody3D, "Generated floating object appears with collision")
	check(is_equal_approx(generator.object.global_position.y, generator.anchor.y + 1.5), "AI placement controls the reveal height")
	check(not generator.preview.mist.active and not level.released, "Model reveal finishes without unlocking the boss")
	var narrator = root.get_node("Narrator")
	var serial: int = narrator.event_serial
	var queued: int = narrator.queue.size()
	narrator._interpreted(generator.request.active_id, generator.request.result)
	check(narrator.event_serial == serial and narrator.queue.size() == queued, "Generation interpretation does not invalidate the boss dialogue")
	panel._draw_idea()
	panel.surface.strokes.append(PackedVector2Array([Vector2(500,300),Vector2(550,350)]))
	panel.surface.changed.emit()
	check(generator.submit(panel.surface.snapshot_png()), "Another drawing can be generated")
	var stale := response.duplicate(true)
	stale.request_id = generator.request.active_id
	generator.request.cancel()
	check(not generator.request.accept_response(stale), "Canceled results cannot replace the object")
	panel._finish_drawing()
