extends Node

## Beichun's integration boundary: connect request_prepared and deliver the JSON
## response to accept_response. Disable mock_mode before connecting a real backend.
signal request_prepared(payload: Dictionary)
signal state_changed(state: String)

@export var mock_mode := true
@export var mock_delay := 3.0
@export var timeout_seconds := 20.0

const TYPES := ["SWORD", "HAMMER", "SPEAR", "SHIELD", "BOW", "MAGIC", "TOOL", "FOOD", "ANIMAL", "UNKNOWN"]
const TAGS := ["LONG_REACH", "FLOATS", "STURDY", "PROTECTS", "FOOD", "SOUND", "OTHER"]
var state := "IDLE"
var active_id := ""
var encounter_id := ""
var snapshot := PackedByteArray()
var result: Dictionary = {}
var message := ""
var generation := 0
var deadline_ms := 0

func _process(_delta: float) -> void:
	if state == "PENDING" and Time.get_ticks_msec() >= deadline_ms:
		_fail("That took too long. Your drawing is safe. Try again.")

func submit(png: PackedByteArray, encounter: String, mock_outcome: int = 0) -> bool:
	if state == "PENDING" or png.is_empty() or png.size() > 1048576 or encounter != "E01":
		return false
	var image := Image.new()
	if image.load_png_from_buffer(png) != OK or image.get_size() != Vector2i(512, 512):
		return false
	generation += 1
	active_id = "E01-%d-%d" % [Time.get_ticks_usec(), generation]
	encounter_id = encounter
	snapshot = png.duplicate()
	result = {}
	message = ""
	deadline_ms = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	_set_state("PENDING")
	request_prepared.emit({
		"schema_version": 2, "request_id": active_id, "encounter_id": encounter_id,
		"locale": "en", "image_base64": Marshalls.raw_to_base64(snapshot)
	})
	if mock_mode:
		_deliver_mock(active_id, mock_outcome)
	return true

func _deliver_mock(request_id: String, outcome: int) -> void:
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
				"type": "TOOL", "attack_power": 0, "range": 8.0,
				"speed": 1.0, "durability": 3,
				"tags": ["LONG_REACH", "STURDY"] if outcome == 0 else ["OTHER"]
			}
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
	result = response["item"].duplicate(true)
	_set_state("READY")
	return true

static func valid_item(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["name", "description", "type"]:
		if not value.get(key) is String:
			return false
	if value["name"].is_empty() or value["name"].length() > 40 or value["description"].length() > 160 or value["type"] not in TYPES:
		return false
	var bounds := {"attack_power": Vector2(0, 100), "range": Vector2(0, 8), "speed": Vector2(0.5, 2), "durability": Vector2(1, 10)}
	for key in bounds:
		var number: Variant = value.get(key)
		if not (number is int or number is float):
			return false
		if not is_finite(float(number)) or number < bounds[key].x or number > bounds[key].y:
			return false
		if key in ["attack_power", "durability"] and float(number) != floor(float(number)):
			return false
	var tags: Variant = value.get("tags")
	if not tags is Array or tags.size() < 1 or tags.size() > 2:
		return false
	for tag in tags:
		if not tag is String or tag not in TAGS or tags.count(tag) != 1:
			return false
	return not ("OTHER" in tags and tags.size() != 1)

func cancel() -> void:
	generation += 1
	active_id = ""
	_set_state("IDLE")

func reset() -> void:
	cancel()
	snapshot = PackedByteArray()
	result = {}
	message = ""

func _fail(reason: String) -> void:
	message = reason
	_set_state("FAILED")

func _set_state(next: String) -> void:
	state = next
	state_changed.emit(state)
