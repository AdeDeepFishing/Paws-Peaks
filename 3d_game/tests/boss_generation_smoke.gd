extends SceneTree
var failed := false
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func run():
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	var generator = level.get_node("ObjectGeneration")
	generator.generation.configure(0)
	generator.request.mock_mode = false
	await create_timer(9).timeout
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
	print("BOSS GENERATION SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
