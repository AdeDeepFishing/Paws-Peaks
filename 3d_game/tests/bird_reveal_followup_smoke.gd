extends "res://tests/bird_encounter_smoke.gd"

func run():
	visual = "--visual" in OS.get_cmdline_user_args()
	var level = fresh()
	await frames(50)
	check(await wait_for(func(): return level.bird.phase == "circling", 8), "Bird reaches the encounter before drawing")
	level.request.mock_delay = 60
	draw(level, 0)
	check(await wait_for(func(): return level.presentation.phase == "waiting", 4), "Generation shot reaches its held position")
	var held: Transform3D = level.camera.transform
	var bird_start: Vector3 = level.bird.visual.position
	var player_start: Vector3 = level.player.position
	await frames(150)
	check(level.bird.visual.position.distance_to(bird_start) > 0.5, "Bird keeps moving during generation")
	check(level.camera.transform.is_equal_approx(held), "Generation camera does not follow the moving bird")
	check(level.generation_preview.image.size.x > level.generation_preview.submitted_rect.size.x * 1.1, "The held view visibly zooms in on the drawing")
	check(root.get_visible_rect().encloses(Rect2(level.generation_preview.mist.position, level.generation_preview.mist.size)), "Stronger cover remains bounded around the sketch")
	await capture("held-cover")
	level.request.mock_mode = false
	level.request.accept_response({"schema_version":2, "request_id":level.request.active_id, "status":"recognized", "item":{"name":"Umbrella", "description":"Protects the protagonist.", "type":"DEFENCE", "movable":true}, "model_path":ProjectSettings.globalize_path("res://../docs/test-artifacts/stage3-2026-09-13/model.glb")})
	check(await wait_for(func(): return is_instance_valid(level.offered) and level.offered.visible, 4), "Model reveal still completes")
	check(level.camera.transform.is_equal_approx(held), "Result hold uses the same stationary camera")
	check(not level.generation_preview.mist.active, "Cover disappears when the model is shown")
	check(await wait_for(func(): return level.bird.phase == "departing", 8), "Bird starts its exit after being blocked")
	var umbrella: Node3D = level.offered
	check(is_instance_valid(umbrella) and umbrella.get_parent() == level, "Departing umbrella detaches from the protagonist")
	if is_instance_valid(umbrella):
		var start: Vector3 = umbrella.global_position
		await frames(20)
		await capture("umbrella-departure")
		await frames(35)
		check(is_instance_valid(umbrella) and umbrella.global_position.distance_to(start) > 0.5, "Umbrella visibly drifts away before disappearing")
	check(level.player.position.distance_to(player_start) < 0.1, "Only the umbrella flies away; the protagonist stays grounded")
	check(await wait_for(func(): return level.solved, 5), "Departure unlocks the route")
	check(not is_instance_valid(level.offered), "No equipped umbrella remains after the bird leaves")
	await capture("after-departure")
	level.queue_free()
	await frames(3)
	print("BIRD REVEAL FOLLOW-UP SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
