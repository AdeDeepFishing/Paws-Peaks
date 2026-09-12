extends Node

signal progress_changed(message: String)

@export_enum("Mock bridge", "Offline model", "Live AI") var mode := 1
@export var backend_directory := ""
@export var python_executable := ""

var request: Node
var process_id := -1
var job_dir := ""
var request_id := ""
var poll_elapsed := 0.0
var last_stage := ""
var finished := false

func _ready() -> void:
	request = get_parent().get_node("DrawingRequest")
	request.request_prepared.connect(_start)
	request.state_changed.connect(_on_state)
	configure(mode)

func configure(next_mode: int) -> void:
	if request.state == "PENDING":
		return
	mode = clampi(next_mode, 0, 2)
	request.mock_mode = mode == 0
	request.timeout_seconds = 20.0 if mode == 0 else 1500.0

func _start(payload: Dictionary) -> void:
	if mode == 0:
		return
	_stop_process()
	finished = false
	last_stage = ""
	request_id = payload.request_id
	if OS.has_feature("web"):
		fail("Desktop generation is unavailable in a browser build.")
		return
	var backend := backend_directory
	if backend.is_empty():
		backend = ProjectSettings.globalize_path("res://").path_join("../backend").simplify_path()
	var runner := backend.path_join("game_bridge/run.py")
	if not FileAccess.file_exists(runner):
		fail("The local generation backend was not found. Check the desktop setup.")
		return
	var python := python_executable
	if python.is_empty():
		python = backend.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
		if not FileAccess.file_exists(python):
			python = "python3"
	job_dir = backend.path_join("output/game_bridge").path_join(request_id + "-" + Crypto.new().generate_random_bytes(4).hex_encode())
	if DirAccess.make_dir_recursive_absolute(job_dir) != OK:
		fail("Could not create a generation folder. Your drawing is safe.")
		return
	var file := FileAccess.open(job_dir.path_join("input.png"), FileAccess.WRITE)
	if file == null:
		fail("Could not save the generation input. Your drawing is safe.")
		return
	file.store_buffer(request.snapshot)
	file.close()
	process_id = OS.create_process(python, PackedStringArray([
		runner, "--job-dir", job_dir, "--request-id", request_id,
		"--encounter-id", payload.encounter_id, "--mode", "live" if mode == 2 else "fixture"
	]))
	if process_id <= 0:
		fail("Could not start Python. Check the desktop generation setup.")
		return
	progress_changed.emit("Starting generation..." if mode == 2 else "Loading the offline sample model...")

func _process(delta: float) -> void:
	if process_id <= 0:
		return
	if finished:
		if not OS.is_process_running(process_id):
			process_id = -1
		return
	if request.state != "PENDING" or request.active_id != request_id:
		_stop_process()
		return
	poll_elapsed += delta
	if poll_elapsed < 0.2:
		return
	poll_elapsed = 0.0
	var path := job_dir.path_join("status.json")
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() < 65536:
			var status = JSON.parse_string(file.get_as_text())
			if status is Dictionary:
				consume_status(status)
	# The final file may have appeared while checking process liveness. Recheck
	# next frame before reporting exit without a result.
	if not finished and not OS.is_process_running(process_id):
		if FileAccess.file_exists(path):
			var value = JSON.parse_string(FileAccess.get_file_as_string(path))
			if value is Dictionary:
				consume_status(value)
		if not finished and request.state == "PENDING":
			fail("Generation stopped before a model was ready. Your drawing is saved.")

func consume_status(status: Dictionary) -> void:
	if finished or request.state != "PENDING" or status.get("request_id") != request.active_id or status.get("request_id") != request_id or status.get("encounter_id") != request.encounter_id or status.get("schema_version") != 1:
		return
	var stage: String = str(status.get("stage", ""))
	if stage != last_stage:
		last_stage = stage
		var messages := {"starting": "Starting generation...", "description": "Understanding your drawing...", "reference_image": "Creating the reference image...", "model": "Building the 3D model...", "complete": "Placing your model..."}
		progress_changed.emit(messages.get(stage, "Generating your object..."))
	if status.get("status") == "FAILED":
		var messages := {"UNCERTAIN_SKETCH": "We could not recognize the drawing. Add detail and try again.", "CONFIG_ERROR": "Generation is not configured. Check the local backend setup.", "POLL_TIMEOUT": "Generation timed out; its provider job may still be running. Check it before submitting again."}
		fail(messages.get(str(status.get("error", "")), "Generation failed. Your drawing and any submitted job IDs are saved."))
	elif status.get("status") == "SUCCEEDED":
		var model_path: String = str(status.get("model_path", "")).simplify_path()
		if not model_path.begins_with(job_dir + "/") or model_path.get_extension().to_lower() != "glb" or not FileAccess.file_exists(model_path):
			fail("The returned model file was not valid.")
			return
		finished = true
		request.accept_response({"schema_version": 2, "request_id": request_id, "status": "recognized", "item": status.get("item"), "model_path": model_path})

func fail(message: String) -> void:
	_stop_process()
	request.fail_current(message)

func _on_state(state: String) -> void:
	if state in ["IDLE", "FAILED"]:
		_stop_process()

func _stop_process() -> void:
	if process_id > 0 and OS.is_process_running(process_id):
		OS.kill(process_id)
	process_id = -1

func _exit_tree() -> void:
	_stop_process()
