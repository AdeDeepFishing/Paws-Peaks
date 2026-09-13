extends Node

signal progress_changed(message: String)
signal interpretation_ready(request_id: String, item: Dictionary)
signal reference_image_ready(request_id: String, path: String)

var partial_item: Dictionary = {}
var reference_path := ""

@export_enum("Mock bridge", "Offline model", "Live AI") var mode := 1

var request: Node
@onready var worker: Node = get_node("/root/GenerationWorker")
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
	finished = false
	partial_item = {}
	reference_path = ""
	last_stage = ""
	job_dir = ""
	poll_elapsed = 0.0
	request_id = payload.request_id
	if not worker.is_running():
		fail(worker.startup_error if not worker.startup_error.is_empty() else "The generation worker stopped. Restart the game.")
		return
	job_dir = worker.worker_dir.path_join(request_id)
	var request_dir := job_dir.path_join("request")
	if DirAccess.make_dir_recursive_absolute(request_dir) != OK:
		fail("Could not create a generation folder. Your drawing is safe.")
		return
	var file := FileAccess.open(request_dir.path_join("input.png"), FileAccess.WRITE)
	if file == null:
		fail("Could not save the generation input. Your drawing is safe.")
		return
	file.store_buffer(request.snapshot)
	file.close()
	var mailbox := FileAccess.open(request_dir.path_join("request.tmp"), FileAccess.WRITE)
	if mailbox == null:
		fail("Could not submit the generation request.")
		return
	mailbox.store_string(JSON.stringify({"request_id": request_id, "encounter_id": payload.encounter_id, "game_stage": payload.game_stage, "mode": "live" if mode == 2 else "fixture"}))
	mailbox.close()
	if DirAccess.rename_absolute(request_dir.path_join("request.tmp"), request_dir.path_join("request.json")) != OK:
		fail("Could not submit the generation request.")
		return
	progress_changed.emit("Starting generation..." if mode == 2 else "Loading the offline sample model...")

func _active(id: String) -> bool:
	return not finished and request.state == "PENDING" and request.active_id == id and request_id == id

func _read_status() -> void:
	var file := FileAccess.open(job_dir.path_join("status.json"), FileAccess.READ)
	if file != null and file.get_length() < 65536:
		var status = JSON.parse_string(file.get_as_text())
		if status is Dictionary:
			consume_status(status)

func _process(delta: float) -> void:
	if mode == 0 or not _active(request_id):
		return
	poll_elapsed += delta
	if poll_elapsed < 0.2:
		return
	poll_elapsed = 0.0
	_read_status()
	if _active(request_id) and not worker.is_running():
		# Read once more in case the final status arrived just before worker exit.
		_read_status()
		if _active(request_id):
			fail("Generation stopped before a model was ready. Your drawing is saved.")

func consume_status(status: Dictionary) -> void:
	if status.get("game_stage") != request.game_stage or status.get("schema_version") != 1 or status.get("encounter_id") != request.encounter_id or not _active(str(status.get("request_id", ""))):
		return
	# A terminal failure takes priority over retained partial item/image fields.
	if status.get("status") == "FAILED":
		var code := str(status.get("error", "GENERATION_FAILED"))
		var messages := {
			"STAGE_NOT_CONFIGURED": "Classification for this stage is not configured yet.",
			"FIXTURE_NOT_AVAILABLE": "This stage has no offline sample yet.",
			"INVALID_REQUEST": "The drawing request was not valid. Try another sketch.",
			"CONFIG_ERROR": "Generation is not configured. Check the local backend setup.",
			"INVALID_MODEL_OUTPUT": "The service returned an unusable result. Try another sketch.",
			"SERVICE_UNAVAILABLE": "The drawing service could not finish. Try another sketch.",
			"RATE_LIMITED": "The drawing service is busy. Try another sketch in a moment.",
			"OPENAI_IMAGE_ERROR": "The reference image could not be created. Try another sketch.",
			"POLL_TIMEOUT": "Generation timed out. You can submit another sketch; the previous job may still be running."
		}
		fail(messages.get(code, "Generation failed. Your drawing is saved. Try another sketch."), code)
		return
	var stage: String = str(status.get("stage", ""))
	if stage != last_stage:
		last_stage = stage
		var messages := {"starting": "Starting generation...", "description": "Understanding your drawing...", "reference_image": "Creating the reference image...", "model": "Building the 3D model...", "preview": "Rendering your model preview...", "complete": "Placing your model..."}
		progress_changed.emit(messages.get(stage, "Generating your object..."))
	if not _active(str(status.get("request_id", ""))):
		return
	# Cumulative snapshots retain early results even if polling skips a stage.
	if partial_item.is_empty() and status.has("item"):
		if not request.valid_item(status.item):
			fail("The interpretation response was not valid.")
			return
		partial_item = status.item.duplicate(true)
		interpretation_ready.emit(request_id, partial_item.duplicate(true))
	if not _active(str(status.get("request_id", ""))):
		return
	if reference_path.is_empty() and status.has("reference_path"):
		var path: String = str(status.reference_path).simplify_path()
		if not path.begins_with(job_dir + "/") or path.get_extension().to_lower() not in ["png", "jpg", "jpeg"] or not FileAccess.file_exists(path):
			fail("The reference image response was not valid.")
			return
		reference_path = path
		reference_image_ready.emit(request_id, reference_path)
	if not _active(str(status.get("request_id", ""))):
		return
	if status.get("status") == "SUCCEEDED":
		var model_path: String = str(status.get("model_path", "")).simplify_path()
		if not model_path.begins_with(job_dir + "/") or model_path.get_extension().to_lower() != "glb" or not FileAccess.file_exists(model_path):
			fail("The returned model file was not valid.")
			return
		finished = true
		request.accept_response({"schema_version": 2, "request_id": request_id, "status": "recognized", "item": status.get("item"), "model_path": model_path})

func fail(message: String, code: String = "GENERATION_FAILED") -> void:
	_cancel_job()
	request.fail_current(message, code)

func _on_state(state: String) -> void:
	if state in ["IDLE", "FAILED"]:
		_cancel_job()
		partial_item = {}
		reference_path = ""

func _cancel_job() -> void:
	if not finished and not job_dir.is_empty():
		var marker := FileAccess.open(job_dir.path_join("cancel"), FileAccess.WRITE)
		if marker != null:
			marker.close()
	finished = true

func _exit_tree() -> void:
	_cancel_job()
