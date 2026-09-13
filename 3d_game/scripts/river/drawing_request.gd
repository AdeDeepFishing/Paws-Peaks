extends Node

## Beichun's integration boundary: connect request_prepared and deliver the JSON
## response to accept_response. Disable mock_mode before connecting a real backend.
signal request_prepared(payload: Dictionary)
signal state_changed(state: String)
signal request_failed(request_id: String, error_code: String, message: String)

@export var mock_mode := true
@export var mock_delay := 3.0
@export var timeout_seconds := 20.0

const GAME_STAGES := {"E01": "river", "E02": "dog", "E03": "crows", "E04": "otter"}
const DraftStore = preload("res://scripts/river/draft_store.gd")
var draft_directory := "user://drawings"
var saved_draft_path := ""
var state := "IDLE"
var active_id := ""
var encounter_id := ""
var game_stage := ""
var snapshot := PackedByteArray()
var result: Dictionary = {}
var model_path := ""
var message := ""
var generation := 0
var deadline_ms := 0

func _process(_delta: float) -> void:
	if state == "PENDING" and Time.get_ticks_msec() >= deadline_ms:
		_fail("That took too long. Your drawing is safe. Try again.")

func submit(png: PackedByteArray, encounter: String, mock_outcome: int = 0) -> bool:
	if state == "PENDING" or png.is_empty() or png.size() > 1048576 or not GAME_STAGES.has(encounter):
		return false
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK or image.get_size() != Vector2i(512, 512):
		return false
	generation += 1
	active_id = "%s-%d-%d" % [encounter, Time.get_ticks_usec(), generation]
	encounter_id = encounter
	game_stage = GAME_STAGES[encounter]
	snapshot = png.duplicate()
	saved_draft_path = DraftStore.save_latest(snapshot, draft_directory)
	if saved_draft_path.is_empty(): push_warning("The latest draft could not be saved locally.")
	model_path = ""
	result = {}
	message = ""
	deadline_ms = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	_set_state("PENDING")
	request_prepared.emit({
		"schema_version": 2, "request_id": active_id, "encounter_id": encounter_id,
		"game_stage": game_stage, "locale": "en", "image_base64": Marshalls.raw_to_base64(snapshot)
	})
	if mock_mode:
		_deliver_mock(active_id, mock_outcome)
	return true

func _deliver_mock(request_id: String, outcome: int) -> void:
	if game_stage not in ["river", "dog", "crows"]:
		_fail("This stage does not have a mock response yet.")
		return
	await get_tree().create_timer(mock_delay).timeout
	var response := {"schema_version": 2, "request_id": request_id, "status": "recognized"}
	match outcome:
		2:
			response["status"] = "uncertain"
			response["item"] = null
		3:
			response["error"] = {"code": "SERVICE_UNAVAILABLE"}
		_:
			response["item"] = {
				"name": "Paper bridge" if outcome == 0 else "A little flower",
				"description": "A long, sturdy idea to carry you across." if outcome == 0 else "Lovely, but it cannot support a crossing.",
				"type": "BRIDGE" if outcome == 0 else "UNKNOWN"
			}
			if game_stage == "dog":
				response["item"] = {
					"name": "Drawn food" if outcome == 0 else ("Drawn toy" if outcome == 1 else "A little flower"),
					"description": "Your sketch can give the dog something to enjoy.",
					"type": "FOOD" if outcome == 0 else ("TOY" if outcome == 1 else "UNKNOWN")
				}
			if game_stage == "crows":
				response["item"] = {
					"name": "Umbrella" if outcome == 0 else ("Shield" if outcome == 1 else "A little flower"),
					"description": "A protective idea to keep the swooping bird at a distance.",
					"type": "DEFENCE" if outcome in [0, 1] else "UNKNOWN"
				}
	if response.get("item") is Dictionary:
		response.item["movable"] = response.item.type != "BRIDGE"
	accept_response(response)

func accept_response(response: Dictionary) -> bool:
	if state != "PENDING" or response.get("request_id") != active_id:
		return false
	if Time.get_ticks_msec() >= deadline_ms:
		_fail("That took too long. Your drawing is safe. Try again.")
		return false
	if response.get("schema_version") != 2:
		_fail("The response format was not valid. Try again.")
		return false
	if response.has("error"):
		_fail("The drawing service is unavailable. Try again.")
		return true
	if response.get("status") == "uncertain" and response.get("item") == null:
		_fail("We could not make out the idea. Add a few details and try again.")
		return true
	if response.get("status") != "recognized" or not valid_item(response.get("item")):
		_fail("The response format was not valid. Try again.")
		return false
	if not response.get("model_path", "") is String:
		_fail("The model response was not valid.")
		return false
	model_path = response.get("model_path", "")
	result = response["item"].duplicate(true)
	_set_state("READY")
	return true

## Classification membership is validated by the backend stage configuration.
static func valid_item(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4:
		return false
	if not value.get("movable") is bool:
		return false
	for key in ["name", "description", "type"]:
		if not value.get(key) is String:
			return false
	if value["name"].is_empty() or value["name"].length() > 40 or value["description"].length() > 160 or value["type"].strip_edges().is_empty() or value["type"].length() > 40:
		return false
	return true

func cancel() -> void:
	generation += 1
	active_id = ""
	_set_state("IDLE")

func reset() -> void:
	cancel()
	snapshot = PackedByteArray()
	model_path = ""
	result = {}
	message = ""

func fail_current(reason: String, code: String = "GENERATION_FAILED") -> void:
	if state in ["PENDING", "READY"]:
		_fail(reason, code)

func _fail(reason: String, code: String = "GENERATION_FAILED") -> void:
	var failed_id := active_id
	message = reason
	result = {}
	model_path = ""
	_set_state("FAILED")
	request_failed.emit(failed_id, code, reason)

func _set_state(next: String) -> void:
	state = next
	state_changed.emit(state)
