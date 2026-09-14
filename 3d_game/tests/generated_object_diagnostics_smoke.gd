extends SceneTree

const Diagnostics = preload("res://scripts/river/generated_object_diagnostics.gd")
const GeneratedModel = preload("res://scripts/river/generated_model.gd")
var failed := false

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var visual := GeneratedModel.load_visual(ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb"), 1.5, false)
	check(visual != null, "Saved offline model loads")
	if visual == null:
		quit(1)
		return
	var holder := Node3D.new()
	root.add_child(holder)
	holder.position = Vector3(1, 2, 3)
	holder.add_child(visual)
	await process_frame
	await process_frame
	if not OS.get_cmdline_user_args().has(Diagnostics.FLAG):
		check(Diagnostics.log_path.is_empty(), "Normal launches do not create diagnostics logs")
	else:
		await create_timer(1.1).timeout
		holder.position = Vector3(4, -6, 8)
		await create_timer(1.1).timeout
		visual.queue_free()
		await process_frame
		await process_frame
		var rows: Array = []
		for line in FileAccess.get_file_as_string(Diagnostics.log_path).split("\n", false):
			rows.append(JSON.parse_string(line))
		check(rows.size() >= 4, "Spawn, periodic samples and removal are logged")
		if rows.size() >= 4:
			check(rows[0].event == "spawn" and Vector3(rows[0].world_position[0], rows[0].world_position[1], rows[0].world_position[2]).is_equal_approx(Vector3(1, 2, 3)), "Spawn includes inherited world position")
			check(rows[1].elapsed_ms - rows[0].elapsed_ms >= 900, "Samples follow the one-second cadence")
			check(Vector3(rows[-2].world_position[0], rows[-2].world_position[1], rows[-2].world_position[2]).is_equal_approx(Vector3(4, -6, 8)), "Movement below the terrain is captured")
			check(rows[-1].event == "removed", "Freeing a model stops tracking and records removal")
	holder.queue_free()
	await process_frame
	print("GENERATED OBJECT DIAGNOSTICS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
