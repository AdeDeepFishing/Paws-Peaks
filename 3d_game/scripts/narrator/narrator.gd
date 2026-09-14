extends Node

## One private story journal and transport across chapters. No provider keys enter Godot.
signal state_changed(state: Dictionary)
signal reply_ready(reply: Dictionary)
signal request_failed(message: String)

const StoryPanel = preload("res://scripts/narrator/story_panel.gd")
var state: Dictionary = {}
var panel: Control
var worker_dir := ""
var process_id := -1
var pending: Dictionary = {}
var queue: Array[Dictionary] = []
var active: Dictionary = {}
var poll := 0.0
var scene: Node
var chapter := 0
var epoch := 0
var event_serial := 0
var enabled := true
var auto_narration := true
var voice_enabled := true
var verbosity := "normal"
var next_comment := 0.0
var comment_due := false
var last_utterance := ""
var audio: AudioStreamPlayer
var last_error := ""
var caption_deadline := 0
var checkpoint := ""
var scripted_narration := false
var guidance_text := ""
var guidance_due := false
var reaction_due := false
var guidance_status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Automated test scenes never spend provider credits implicitly.
	enabled = not OS.get_cmdline_args().has("--script") and not OS.has_feature("web")
	panel = StoryPanel.new()
	panel.story = self
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	layer.add_child(panel)
	audio = AudioStreamPlayer.new()
	audio.volume_linear = get_node("/root/GameAudio").voice_volume
	add_child(audio)
	audio.finished.connect(panel.speech_finished)
	get_tree().scene_changed.connect(_scene_changed)
	get_node("/root/Journey").finished.connect(func(_stage): _scene_changed())
	_scene_changed.call_deferred()

func _scene_changed() -> void:
	var current := get_tree().current_scene
	if current == scene: return
	scripted_narration = false
	if is_instance_valid(guidance_status): guidance_status.show()
	guidance_status = null
	guidance_text = ""
	guidance_due = false
	reaction_due = false
	panel.cancel_boss_reveal()
	panel.last_status = ""
	panel.close_dialogue()
	epoch += 1
	audio.stop()
	panel.hide_caption()
	scene = current
	chapter = get_node("/root/Journey").stage_for_scene(scene.scene_file_path) if scene else 0
	comment_due = false
	if chapter == 0: return
	if enabled:
		_ensure_worker()
		if state.is_empty() and not _has_op("new"): _enqueue({"op": "new"})
		record("stage_entered", {})
	for drawing in scene.find_children("DrawingRequest", "", true, false):
		if not drawing.request_prepared.is_connected(_drawing_submitted): drawing.request_prepared.connect(_drawing_submitted)
	for generation in scene.find_children("DesktopGeneration", "", true, false):
		if not generation.interpretation_ready.is_connected(_interpreted): generation.interpretation_ready.connect(_interpreted)

func _drawing_submitted(payload: Dictionary) -> void:
	record("drawing_submitted", {"request_id": payload.request_id, "result": "Submitted; not yet created or used."})

func _interpreted(id: String, item: Dictionary) -> void:
	# The boss already receives the sketch; background generation must not stale its reply.
	if chapter == 5: return
	record("drawing_interpreted", {"request_id": id, "item": item, "result": "AI interpretation only; use has not been confirmed."})
	if enabled: _enqueue({"op": "read_drawing", "drawing_id": id})

func record(kind: String, payload: Dictionary) -> void:
	if not enabled or chapter == 0: return
	event_serial += 1
	if kind in ["npc_interaction_resolved", "encounter_completed", "object_use_resolved", "object_spawned"]: reaction_due = true
	_enqueue({"op": "event", "type": kind, "stage": chapter, "payload": payload})
	if kind in ["stage_entered", "npc_interaction_resolved", "encounter_completed", "object_use_resolved", "object_spawned"]:
		comment_due = true
		next_comment = Time.get_ticks_msec() / 1000.0 + 1.0

func _ensure_worker() -> void:
	if process_id > 0 and OS.is_process_running(process_id): return
	var backend: String = ProjectSettings.get_setting("generation/backend_directory", "")
	if backend.is_empty(): backend = ProjectSettings.globalize_path("res://").path_join("../backend").simplify_path()
	var python: String = ProjectSettings.get_setting("generation/python_executable", "")
	if python.is_empty():
		python = backend.path_join(".venv/Scripts/python.exe" if OS.has_feature("windows") else ".venv/bin/python")
		if not FileAccess.file_exists(python): python = "python3"
	worker_dir = backend.path_join("output/narrator_mailbox/" + Crypto.new().generate_random_bytes(8).hex_encode())
	DirAccess.make_dir_recursive_absolute(worker_dir)
	process_id = OS.create_process(python, PackedStringArray([backend.path_join("narrator_agent/run.py"), "--serve", worker_dir, "--parent-pid", str(OS.get_process_id())]))

func _has_op(op: String) -> bool:
	if active.get("op") == op: return true
	for request in queue:
		if request.get("op") == op: return true
	return false

func _enqueue(request: Dictionary) -> void:
	request["input_id"] = Crypto.new().generate_random_bytes(12).hex_encode()
	request["epoch"] = epoch
	request["event_serial"] = event_serial
	queue.append(request)

func ask(text: String, drawing: PackedByteArray = PackedByteArray(), automatic := false) -> void:
	if not enabled:
		_fail("AI narration is unavailable in this preview.")
		return
	if not automatic and chapter not in [4, 5]: return
	if _has_op("respond"): return
	_ensure_worker()
	if not automatic: skip()
	var request := {"op": "respond", "text": text, "trigger": "event" if automatic else "dialogue"}
	if not drawing.is_empty():
		request["image_base64"] = Marshalls.raw_to_base64(drawing)
		if not scene.has_node("ObjectGeneration"):
			get_node("/root/Journey").sketches_shared += 1
	_enqueue(request)
	panel.set_busy(true)
	comment_due = false
	if automatic:
		guidance_due = false
		reaction_due = false

func confirm_stay() -> void:
	_enqueue({"op": "confirm_stay", "candidate": state.get("candidate")})

func cancel_stay() -> void:
	_enqueue({"op": "cancel_stay", "candidate": state.get("candidate")})

func crossed_exit() -> void:
	if state.get("ending") == "leave": return
	if state.get("exit_open", false) and not _has_op("leave"):
		_enqueue({"op": "leave", "crossed_exit": true})

func reset_journey() -> void:
	get_node("/root/Journey").microphone_unlocked = false
	epoch += 1
	queue.clear()
	state = {}
	checkpoint = ""
	panel.reset_story()
	skip()
	if enabled:
		_ensure_worker()
		_enqueue({"op": "new"})

func skip(keep_caption := false) -> void:
	audio.stop()
	last_utterance = ""
	if keep_caption: panel.finish_reveal()
	else: panel.hide_caption()

func set_voice(value: bool) -> void:
	voice_enabled = value
	if not value:
		audio.stop()
		panel.finish_reveal()

func _process(delta: float) -> void:
	var playable: bool = is_instance_valid(scene) and scene.is_inside_tree() and chapter > 0 and not get_node("/root/Journey").busy
	if playable:
		playable = scene.get("entering") != true and scene.process_mode != Node.PROCESS_MODE_DISABLED
	panel.entry.visible = playable and chapter in [4, 5] and get_node("/root/Journey").microphone_unlocked and not panel.canvas_panel.visible and state.get("ending") == null
	if playable: panel._update_tools()
	panel.entry.tooltip_text = "Approach the otter to talk." if chapter == 4 and panel.entry.disabled else "Speak with the character."
	if not enabled: return
	if playable and not panel.opened and not scripted_narration: _observe_guidance()
	if playable and panel.opened:
		var current_guidance := _current_guidance()
		if is_instance_valid(guidance_status) and not current_guidance.is_empty():
			guidance_status.hide()
	if caption_deadline > 0 and Time.get_ticks_msec() > caption_deadline and not audio.playing and not panel.opened and panel.reveal_text.is_empty():
		panel.hide_caption()
		caption_deadline = 0
	poll += delta
	if poll < 0.15: return
	poll = 0.0
	for id in pending.keys():
		var path: String = pending[id].path
		if not FileAccess.file_exists(path): continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() > 262144: continue
		var response = JSON.parse_string(file.get_as_text())
		var metadata: Dictionary = pending[id]
		pending.erase(id)
		if active.get("input_id") == id: active = {}
		if response is Dictionary: _consume(metadata, response)
	if not active.is_empty() and Time.get_ticks_msec() - int(active.get("started", 0)) > 95000:
		pending.erase(active.input_id)
		active = {}
		_fail("The Storykeeper is taking too long. Your words and drawing are safe; try again.")
	if active.is_empty() and not queue.is_empty(): _dispatch()
	if playable and not panel.opened and not panel.revealing_boss and not scripted_narration and auto_narration and (guidance_due or verbosity != "quiet") and queue.is_empty() and active.is_empty():
		var player = scene.get("player")
		var occupied: bool = player == null or not player.input_enabled or player.drawing_active
		if not occupied and (comment_due or guidance_due) and Time.get_ticks_msec() / 1000.0 >= next_comment:
			if guidance_due and (not reaction_due or verbosity == "quiet"):
				_enqueue({"op": "guide", "trigger": "event", "guidance": guidance_text})
				guidance_due = false
				reaction_due = false
				comment_due = false
			else:
				ask("", PackedByteArray(), true)

func _dispatch() -> void:
	if process_id <= 0 or not OS.is_process_running(process_id):
		queue.clear()
		_fail("The story service is unavailable. You can keep exploring and try again later.")
		return
	var request: Dictionary = queue.pop_front()
	if request.op == "transcribe" and (not panel.opened or request.get("dialogue_epoch") != panel.dialogue_epoch): return
	if request.epoch != epoch and request.op not in ["new"]: return
	if request.has("drawing_id") and not _drawing_is_current(request.drawing_id): return
	if request.op == "voice" and (not voice_enabled or request.utterance_id != last_utterance): return
	if request.op != "new":
		if state.is_empty(): return
		request["run_id"] = state.run_id
		request["revision"] = state.revision
	if request.op == "respond":
		request["guidance"] = guidance_text if _current_guidance() == guidance_text else ""
	var directory := worker_dir.path_join(request.input_id)
	DirAccess.make_dir_recursive_absolute(directory)
	var file := FileAccess.open(directory.path_join("request.tmp"), FileAccess.WRITE)
	if file == null:
		_fail("Could not save the story request.")
		return
	file.store_string(JSON.stringify(request))
	file.close()
	DirAccess.rename_absolute(directory.path_join("request.tmp"), directory.path_join("request.json"))
	var metadata: Dictionary = request.duplicate(true)
	metadata.erase("image_base64")
	metadata.erase("audio_base64")
	metadata["path"] = directory.path_join("response.json")
	metadata["started"] = Time.get_ticks_msec()
	pending[request.input_id] = metadata
	if request.op != "voice": active = metadata

func _consume(request: Dictionary, response: Dictionary) -> void:
	if scripted_narration and request.op in ["respond", "guide", "read_drawing"] and not request.get("scripted", false): return
	if request.op == "transcribe":
		if not panel.opened or request.get("dialogue_epoch") != panel.dialogue_epoch: return
		if request.get("partial", false) and not panel.mic.recording: return
	if request.epoch != epoch and request.op != "new": return
	if request.op in ["respond", "guide"] and request.get("event_serial", event_serial) != event_serial:
		panel.set_busy(false)
		return
	if not response.get("ok", false):
		if request.op == "voice":
			pass # Continue with paced subtitles when voice is unavailable.
			panel.start_speech(0.0)
		elif request.op == "transcribe" and request.get("partial", false): return
		else: _fail(str(response.get("message", "The Storykeeper could not respond. Try again.")))
		return
	if request.has("drawing_id") and not _drawing_is_current(request.drawing_id): return
	if response.get("skipped", false): return
	if response.has("state"):
		if state.is_empty() or response.state.get("revision", -1) >= state.get("revision", -1):
			state = response.state
		panel.refresh_state()
		state_changed.emit(state)
	if response.has("checkpoint"): checkpoint = response.checkpoint
	if request.op in ["respond", "guide"]:
		panel.set_busy(false)
		last_utterance = request.input_id
		if request.get("trigger") == "event":
			var player = scene.get("player") if is_instance_valid(scene) else null
			if get_node("/root/Journey").busy or panel.opened or player == null or player.drawing_active or not player.input_enabled:
				return
		guidance_due = false
		panel.present(response.utterance, request.get("trigger") != "event")
		caption_deadline = Time.get_ticks_msec() + maxi(12000, str(response.utterance.text).length() * 65)
		reply_ready.emit(response)
		_enqueue({"op": "presented", "utterance_id": request.input_id})
		if voice_enabled: _enqueue({"op": "voice", "utterance_id": request.input_id})
	elif request.op == "read_drawing":
		# The item card already supplies the text; read it without another caption/model call.
		skip()
		last_utterance = request.input_id
		_enqueue({"op": "presented", "utterance_id": request.input_id})
		if voice_enabled: _enqueue({"op": "voice", "utterance_id": request.input_id, "drawing_id": request.drawing_id})
	elif request.op == "transcribe":
		var partial: bool = request.get("partial", false)
		if not partial: panel.set_busy(false)
		panel.receive_transcript(str(response.get("transcript", "")), partial)
	elif request.op == "voice" and voice_enabled and request.utterance_id == last_utterance and not get_node("/root/Journey").busy:
		var path := str(response.get("audio_path", "")).simplify_path()
		var allowed := worker_dir.get_base_dir().get_base_dir().path_join("narrator_agent/" + str(state.run_id)) + "/"
		if path.begins_with(allowed) and path.ends_with(".mp3"):
			var file := FileAccess.open(path, FileAccess.READ)
			if file and file.get_length() <= 8388608:
				var stream := AudioStreamMP3.new()
				stream.data = file.get_buffer(file.get_length())
				audio.stream = stream
				audio.play()
				if not request.has("drawing_id"): panel.start_speech(stream.get_length())
	elif request.op == "leave":
		if is_instance_valid(scene) and scene.has_method("complete_boss_encounter"): scene.complete_boss_encounter()

func _fail(message: String) -> void:
	if scripted_narration:
		panel.start_speech(0.0)
		return
	last_error = message
	panel.set_busy(false)
	panel.show_error(message)
	request_failed.emit(message)

func _exit_tree() -> void:
	if process_id > 0 and OS.is_process_running(process_id): OS.kill(process_id)


func _current_guidance() -> String:
	if not is_instance_valid(scene) or chapter == 0: return ""
	var label = scene.get("status_label") if chapter == 1 else scene.get("status")
	if not label is Label: return ""
	guidance_status = label
	var text := str(label.get_meta("narrator_guidance", ""))
	return text if text == label.text else ""

func _observe_guidance() -> void:
	var latest := _current_guidance()
	if is_instance_valid(guidance_status):
		# Keep errors and loading status visible; avoid two copies of spoken guidance.
		guidance_status.hide()
	if latest == guidance_text: return
	guidance_text = latest
	guidance_due = not latest.is_empty()
	# Every change invalidates an in-flight line, including a cleared instruction.
	record("guidance_changed", {"text": latest})
	if guidance_due:
		comment_due = true
		next_comment = Time.get_ticks_msec() / 1000.0 + 0.6


func transcribe(wav: PackedByteArray, partial := false) -> void:
	if chapter not in [4, 5] or not enabled or not get_node("/root/Journey").microphone_unlocked: return
	if partial and _has_op("transcribe"): return
	_ensure_worker()
	if not partial:
		queue = queue.filter(func(request): return request.get("op") != "transcribe")
	_enqueue({"op": "transcribe", "partial": partial, "dialogue_epoch": panel.dialogue_epoch, "audio_base64": Marshalls.raw_to_base64(wav)})
	if not partial:
		panel.set_busy(true)



func _drawing_is_current(id: String) -> bool:
	if not is_instance_valid(scene): return false
	for drawing in scene.find_children("DrawingRequest", "", true, false):
		if drawing.active_id == id and drawing.state in ["PENDING", "READY"]: return true
	return false


func begin_scripted_line(text: String) -> void:
	scripted_narration = true
	skip()
	panel.set_busy(false)
	queue = queue.filter(func(request): return request.get("op") not in ["respond", "guide", "read_drawing", "voice"])
	guidance_text = text
	_current_guidance()
	if is_instance_valid(guidance_status): guidance_status.hide()
	record("guidance_changed", {"text": text})
	comment_due = false
	guidance_due = false
	reaction_due = false
	panel.present({"text": text, "speaker": "narrator"}, false)
	if enabled:
		_ensure_worker()
		_enqueue({"op": "guide", "trigger": "event", "guidance": text, "scripted": true})
	else:
		panel.start_speech(0.0)

func end_scripted_narration() -> void:
	scripted_narration = false
	var latest := _current_guidance()
	if latest != guidance_text:
		guidance_text = latest
		# Queue the new guidance before a player reply can reference it.
		record("guidance_changed", {"text": latest})
	comment_due = false
	guidance_due = false
	reaction_due = false
	if is_instance_valid(guidance_status): guidance_status.visible = not panel.caption.visible
