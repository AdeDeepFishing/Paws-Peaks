extends SceneTree
var failed := false
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func capture(label: String):
	if "--visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/paws-otter-" + label + ".png")
func run():
	var level = load("res://scenes/sunset_cove/sunset_cove.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(3)
	var otter = level.get_node("Otter")
	var journey = root.get_node("Journey")
	var narrator = root.get_node("Narrator")
	narrator._scene_changed()
	check(not journey.microphone_unlocked, "Speaking starts locked")
	check(not otter.happy and not otter.heart.happy, "Otter begins with a broken heart")
	check(otter.grounded, "Otter starts grounded")
	var library: AnimationLibrary = otter.animator.get_animation_library("otter")
	check(library.get_animation_list().size() == 13, "One model has all 13 full animations")
	for i in 180:
		if not level.entering: break
		await frames(1)
	check(otter.phase == "waving" and otter.animator.current_animation == otter.WAVE, "Farther-back player arrival triggers a greeting wave")
	check(not otter.heart.visible and not otter.mood_revealed, "Waving hides the broken heart before meeting the otter")
	check(not level.status.text.contains("unhappy") and not level.objective.text.contains("heartbroken"), "Arrival guidance only introduces the otter")
	await capture("wave")
	level.player.set_physics_process(false)
	level.player.global_position = otter.global_position + Vector3(0, 0, 1.7)
	await frames(40)
	check(otter.phase == "idle" and otter.animator.current_animation == otter.IDLE, "Approaching interrupts the wave and returns to idle")
	var facing: Vector3 = otter.global_basis.z
	check(facing.dot(Vector3.BACK) > 0.98, "Otter turns to face the approaching player")
	check(narrator.panel.entry.disabled, "Talk stays disabled near the sad otter")
	check(not narrator.panel.microphone_shine.active, "Microphone does not glow before the gift")
	narrator.panel._talk()
	check(not narrator.panel.mic.recording, "Locked Talk cannot start recording")
	check(otter.heart.visible and otter.mood_revealed, "Approaching reveals the broken heart")
	check(level.status.text.contains("unhappy") and level.status.get_meta("narrator_guidance") == level.status.text, "Approach queues the unhappy-otter narration")
	await capture("idle")
	level.player.global_position = otter.global_position + Vector3(0, 0, 6)
	await frames(2)
	check(otter.phase == "waving", "Otter waves again when the player steps away")
	otter.animator.seek(otter.animator.current_animation_length - 0.01, true)
	await frames(4)
	check(otter.phase == "waving" and otter.animator.is_playing() and otter.animator.current_animation_position < 0.5, "Wave repeats at the end of the clip")
	level.player.global_position = otter.global_position + Vector3(0, 0, 12)
	await frames(2)
	check(otter.phase == "waving", "Otter keeps waving beyond the old greeting range")
	check(not otter.heart.visible, "Broken heart hides again while waving")
	check(otter.animation_options.size() == 8, "Eight reaction descriptions are saved as AI choices")
	var reaction_clip: Animation = library.get_animation("Shrug")
	var original_length := reaction_clip.length
	reaction_clip.length = 20.0
	check(otter.play_option("Shrug"), "Long reaction starts")
	otter._physics_process(9.9)
	check(otter.phase == "reacting", "Long reaction continues before ten seconds")
	otter._physics_process(0.11)
	check(otter.phase == "idle" and otter.animator.current_animation == otter.IDLE, "Long reaction returns to idle at ten seconds")
	reaction_clip.length = 0.5
	otter.play_option("Shrug")
	otter.animator.seek(0.49, true)
	await frames(4)
	check(otter.phase == "reacting" and otter.animator.is_playing() and otter.animator.current_animation_position < 0.4, "Short reaction loops after its clip ends")
	otter.elapsed = 9.9
	otter._physics_process(0.11)
	check(otter.phase == "idle" and otter.animator.current_animation == otter.IDLE, "Looping reaction returns to idle at ten seconds")
	reaction_clip.length = original_length
	level._open_drawing()
	check(not level.drawing, "Drawing stays locked outside otter interaction range")
	level.player.global_position = otter.global_position + Vector3(0, 0.2, 1.7)
	await frames(2)
	level._open_drawing()
	check(level.drawing, "Player can draw after approaching the otter")
	await frames(2)
	check(not otter.heart.visible, "Broken heart hides while the drawing canvas is open")
	level._close_drawing()
	await frames(2)
	check(otter.heart.visible, "Closing drawing restores the broken heart")
	level._open_drawing()
	await capture("drawing")
	level.generation.configure(1)
	var payloads: Array[Dictionary] = []
	level.request.request_prepared.connect(func(payload: Dictionary): payloads.append(payload))
	var center: Vector2 = level.camera.unproject_position(Vector3(0, 0.3, 5))
	level.surface.reference_size = level.surface.size
	level.surface.strokes.append(PackedVector2Array([center - Vector2(20, 35), center + Vector2(20, 0)]))
	level._submit()
	check(payloads.size() == 1, "A nearby sketch produces exactly one request")
	if not payloads.is_empty():
		check(payloads[0].encounter_id == "E04" and payloads[0].game_stage == "otter", "Sketch has the Stage 4 routing labels")
		check(payloads[0].animation_options == otter.animation_options, "Request includes the saved animation choices")
		var folder: String = level.generation.job_dir.path_join("request")
		var envelope_path := folder.path_join("request.json")
		if not FileAccess.file_exists(envelope_path): envelope_path = folder.path_join("claimed.json")
		var envelope = JSON.parse_string(FileAccess.get_file_as_string(envelope_path))
		check(envelope is Dictionary and envelope.get("animation_options") == otter.animation_options, "Desktop mailbox preserves animation options")
		check(not level.drawing, "Submitting closes drawing and releases player controls")
		check(otter.phase == "waiting", "Otter looks confused during generation")
		level.request.cancel()
		check(otter.phase == "idle", "Cancel stops the confused animation")
		check(level.surface.has_drawing(), "Canceling preserves the sketch for retry")
	var saved_player_position: Vector3 = level.player.global_position
	otter.wait_for_drawing(otter.global_position + Vector3.RIGHT * 3)
	level.player.global_position = otter.global_position + Vector3.LEFT * 3
	otter._physics_process(1.0)
	check(otter.global_basis.z.dot(Vector3.RIGHT) > 0.98, "Waiting faces the sketch even when the player moves opposite it")
	otter.stop_waiting()
	otter._physics_process(1.0)
	check(otter.global_basis.z.dot(Vector3.LEFT) > 0.98, "Canceling restores player-facing")
	level.player.global_position = saved_player_position
	level.generation.configure(0)
	level.request.mock_mode = false
	check(level.request.submit(level.surface.snapshot_png(), "E04"), "Offline reaction test submits a sketch")
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	var item := {"name": "Bone", "description": "A bone to examine.", "movable": true, "texture_key": "bone", "color": "#E8D9B7"}
	var response := {"otter_happy": false, "otter_response": "Thank you, but I am still feeling blue.", "schema_version": 1, "request_id": level.request.active_id, "encounter_id": "E04", "game_stage": "otter", "stage": "reference_image", "status": "PENDING", "item": item, "reaction": "Shrug"}
	level.generation.consume_status(response)
	check(not otter.happy, "Early interpretation cannot change happiness before an offering appears")
	check(otter.waiting_target == level.sketch_anchor, "Generation faces the submitted object placement center")
	check(otter.phase == "waiting" and otter.animator.current_animation == "otter/Confused_Scratch", "Early interpretation keeps the confused look until rendering")
	otter.animator.seek(otter.animator.current_animation_length - 0.01, true)
	await frames(3)
	check(otter.phase == "waiting" and otter.animator.is_playing(), "Confused animation repeats while waiting")
	check(not otter.heart.visible, "Broken heart stays hidden while generation is pending")
	await capture("confused")
	var model_path: String = level.generation.job_dir.path_join("reaction-test.glb")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb"), model_path)
	response.merge({"stage": "complete", "status": "SUCCEEDED", "model_path": model_path}, true)
	level.generation.consume_status(response)
	await frames(4)
	check(is_instance_valid(level.offered) and otter.phase == "reacting" and otter.animator.current_animation == "otter/Shrug", "Rendered model triggers the returned reaction")
	check(not otter.happy and not otter.heart.happy, "Negative AI decision leaves the heart broken")
	check(not level.gift_pending and not journey.microphone_unlocked, "Negative offering does not give a microphone")
	check(level.status.text.contains(response.otter_response), "Otter explains its response to the offering")
	check(not level.surface.has_drawing(), "Rendered model clears the original sketch")
	await capture("reaction")
	otter.elapsed = 9.9
	otter._physics_process(0.11)
	check(otter.phase == "idle", "Selected reaction returns to idle after ten seconds")
	var previous_id: String = level.request.active_id
	var previous_model = level.offered
	level._open_drawing()
	check(level.drawing and level.request.state == "IDLE" and not level.surface.has_drawing(), "Draw again opens a fresh canvas after success")
	level.surface.reference_size = level.surface.size
	center = level.camera.unproject_position(Vector3(0, 0.3, 6))
	level.surface.strokes.append(PackedVector2Array([center - Vector2(15, 30), center + Vector2(15, 0)]))
	level._submit()
	check(level.request.state == "PENDING" and level.request.active_id != previous_id, "Second drawing creates a fresh Stage 4 request")
	check(otter.phase == "waiting", "Second drawing starts confused waiting again")
	check(is_instance_valid(previous_model), "Previous object stays while the next drawing generates")
	level.generation.request_id = level.request.active_id
	level.generation.finished = false
	level.generation.partial_item = {}
	response.request_id = previous_id
	level.generation.consume_status(response)
	check(level.request.state == "PENDING", "Previous request cannot complete a new drawing")
	response.request_id = level.request.active_id
	response.reaction = "Cheer_with_Both_Hands"
	response.otter_happy = true
	response.otter_response = "Your gift cheers me up!"
	level.generation.consume_status(response)
	await frames(4)
	check(level.request.state == "READY" and otter.animator.current_animation == "otter/Cheer_with_Both_Hands", "Second drawing renders and plays its own reaction")
	check(otter.happy and otter.heart.happy, "Affirmative AI response restores the whole heart after placement")
	check(level.gift_pending and not journey.microphone_unlocked, "Happy offering starts the gift sequence without unlocking Talk")
	check(not is_instance_valid(level.microphone_gift) and narrator.panel.reveal_text.contains("surprise"), "Outcome and surprise narration precede the gift")
	for i in 1200:
		if is_instance_valid(level.microphone_gift): break
		await frames(1)
	check(is_instance_valid(level.microphone_gift), "Gift appears after the outcome narration finishes")
	await create_timer(0.4).timeout
	check(not level.microphone_gift.revealed and level.microphone_gift.mist.active, "Gift starts under the shared generation blur")
	await capture("microphone-conjuring")
	for i in 600:
		if level.microphone_gift.revealed: break
		await frames(1)
	check(level.microphone_gift.revealed and not level.microphone_gift.mist.active, "Microphone becomes clear after conjuring")
	check(narrator.panel.reveal_text.contains("gave you a microphone") and narrator.panel.reveal_text.contains("looks like the otter want to talk") and narrator.panel.entry.disabled, "Usage narration starts during the clear microphone hold")
	await capture("microphone-gift")
	await create_timer(2.5).timeout
	check(is_instance_valid(level.microphone_gift) and not journey.microphone_unlocked, "Clear microphone stays visible for the full three-second hold")
	await create_timer(0.6).timeout
	check(journey.microphone_unlocked and not level.gift_pending and not is_instance_valid(level.microphone_gift), "After three seconds the gift disappears and speaking unlocks")
	check(not narrator.panel.entry.disabled, "Nearby player can now use Talk")
	check(narrator.panel.microphone_shine.active, "Available microphone uses the pen shine after the gift")
	check(narrator.panel.reveal_text.ends_with("looks like the otter want to talk to you! use the mic to speak"), "Combined gift narration ends with the requested speaking invitation")
	check(narrator.panel.reveal_time >= 3.0, "Gift removal does not restart or split the combined narration")
	level._give_microphone()
	check(not level.gift_pending, "The microphone gift is granted only once per journey")
	await capture("happy-heart")
	check(not is_instance_valid(previous_model) and is_instance_valid(level.offered), "Second successful model replaces the previous one")

	var png := Image.create(512, 512, false, Image.FORMAT_RGBA8).save_png_to_buffer()
	level.request.submit(png, "E04")
	level.request.fail_current("Offline test failure")
	check(otter.phase == "idle", "Generation failure stops the confused look")
	print("OTTER GREETING SMOKE: ", "FAIL" if failed else "PASS")
	level.queue_free()
	await frames(2)
	quit(1 if failed else 0)
