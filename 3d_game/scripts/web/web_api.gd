extends Node

## Browser transport: only an opaque session token and public API origin live here.
signal session_ready
var api_url := ""
var token := ""
var starting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FileAccess.file_exists("res://web_config.json"):
		var config = JSON.parse_string(FileAccess.get_file_as_string("res://web_config.json"))
		if config is Dictionary: api_url = str(config.get("api_url", "")).trim_suffix("/")

func session() -> bool:
	if starting:
		await session_ready
		return not token.is_empty()
	if not token.is_empty(): return true
	if not api_url.begins_with("https://"): return false
	starting = true
	var result := await send("/api/session", {}, false)
	token = str(result.get("token", ""))
	starting = false
	session_ready.emit()
	return not token.is_empty()

func send(path: String, data: Variant = null, authenticated := true) -> Dictionary:
	if authenticated and not await session():
		return {"ok": false, "error": "SERVICE_UNAVAILABLE", "message": "The online service is unavailable. Please try again later."}
	var http := HTTPRequest.new()
	# Free hosting can take about a minute to wake for the first session.
	http.timeout = 75.0 if path == "/api/session" else 35.0
	http.body_size_limit = 1500000
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json"])
	if authenticated: headers.append("Authorization: Bearer " + token)
	var error := http.request(api_url + path, headers, HTTPClient.METHOD_GET if data == null else HTTPClient.METHOD_POST, "" if data == null else JSON.stringify(data))
	if error != OK:
		http.queue_free()
		return {"ok": false, "error": "NETWORK_ERROR"}
	var reply: Array = await http.request_completed
	http.queue_free()
	if reply[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "NETWORK_ERROR"}
	var decoded = JSON.parse_string(reply[3].get_string_from_utf8())
	if not decoded is Dictionary: return {"ok": false, "error": "INVALID_RESPONSE"}
	if reply[1] < 200 or reply[1] >= 300:
		decoded["ok"] = false
	return decoded

func download(asset: String, destination: String) -> bool:
	if not await session() or asset.contains("/") or asset.contains("..") or asset.length() > 80: return false
	if FileAccess.file_exists(destination): return true
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var http := HTTPRequest.new()
	http.timeout = 120.0
	http.body_size_limit = 104857600
	add_child(http)
	var error := http.request(api_url + "/api/assets/" + asset, PackedStringArray(["Authorization: Bearer " + token]))
	if error != OK:
		http.queue_free()
		return false
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS or result[1] != 200:
		DirAccess.remove_absolute(destination + ".part")
		return false
	# Web HTTPRequest returns bytes without creating download_file on every browser.
	var file := FileAccess.open(destination + ".part", FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(result[3])
	var saved := file.get_error() == OK
	file.close()
	return saved and DirAccess.rename_absolute(destination + ".part", destination) == OK
