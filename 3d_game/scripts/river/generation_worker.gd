extends Node

## One worker for the whole game, started before the main scene.
var process_id := -1
var worker_dir := ""
var startup_error := ""
var web: Node

func _ready() -> void:
	if OS.has_feature("web"):
		web = preload("res://scripts/web/web_api.gd").new()
		add_child(web)
		return
	var backend: String = ProjectSettings.get_setting("generation/backend_directory", "")
	if backend.is_empty():
		backend = ProjectSettings.globalize_path("res://").path_join("../backend").simplify_path()
	var runner := backend.path_join("game_bridge/run.py")
	if not FileAccess.file_exists(runner):
		startup_error = "The local generation backend was not found. Check the desktop setup."
		return
	var python: String = ProjectSettings.get_setting("generation/python_executable", "")
	if python.is_empty():
		python = backend.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
		if not FileAccess.file_exists(python):
			python = "python3"
	worker_dir = backend.path_join("output/game_bridge").path_join("worker-" + Crypto.new().generate_random_bytes(8).hex_encode())
	if DirAccess.make_dir_recursive_absolute(worker_dir) != OK:
		startup_error = "Could not create the generation worker folder."
		return
	process_id = OS.create_process(python, PackedStringArray([runner, "--serve", worker_dir]))
	if process_id <= 0:
		startup_error = "Could not start Python. Check the desktop generation setup."

func is_running() -> bool:
	return process_id > 0 and OS.is_process_running(process_id)

func _exit_tree() -> void:
	if is_running():
		OS.kill(process_id)
	process_id = -1
