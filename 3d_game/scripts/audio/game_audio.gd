extends Node

## One persistent mix across scenes: authored BGM, local feedback, and speech ducking.
const TRACKS := ["opening", "chapters_1_3", "otter", "storykeeper", "ending"]
var players: Array[AudioStreamPlayer] = []
var effects: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var cues: Dictionary = {}
var selected := ""
var slot := 0
var music_volume := 0.6
var effects_volume := 0.6
var master_muted := false
var phase := ""
var scene: Node
var elapsed := 0.0
var step_timer := 0.0
var prior_grounded := true
var menu: PanelContainer
var controls: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		add_child(player)
		player.volume_db = -80
		players.append(player)
	for i in 4:
		var effect := AudioStreamPlayer.new()
		add_child(effect)
		effects.append(effect)
	for cue in ["page", "click", "submit", "ready", "jump", "step"]: cues[cue] = _sound(cue)
	get_tree().node_added.connect(func(node):
		if node is Button: _bind_button.call_deferred(node)
	)
	_build_controls.call_deferred()

func _bind_button(button: Button) -> void:
	if is_instance_valid(button): button.pressed.connect(func(): play_cue("click"))

func track_for(path: String, stayed := false) -> String:
	if stayed or "/ending/" in path: return "ending"
	if "/moonlit_forest/" in path: return "storykeeper"
	if "/sunset_cove/" in path: return "otter"
	if "/river/" in path or "/woodland/" in path or "/wind_hill/" in path: return "chapters_1_3"
	# Keep the current chapter's music while viewing the map; initial map uses opening.
	return selected if not selected.is_empty() and selected != "ending" else "opening"

func _select(track: String) -> void:
	if selected == track: return
	selected = track
	if not streams.has(track):
		var stream := AudioStreamOggVorbis.load_from_file("res://audio/bgm/" + track + ".ogg")
		if stream == null: return
		stream.loop = true
		streams[track] = stream
	slot = 1 - slot
	players[slot].stream = streams[track]
	players[slot].volume_db = -80
	players[slot].play()

func _process(delta: float) -> void:
	var narrator = get_node_or_null("/root/Narrator")
	var recording: bool = narrator != null and narrator.panel.mic != null and narrator.panel.mic.recording
	var speaking: bool = narrator != null and narrator.audio.playing
	var target := music_volume * (0.18 if recording else (0.35 if speaking else 1.0)) * 0.35
	for i in players.size():
		var desired := target if i == slot and not master_muted else 0.0
		players[i].volume_linear = move_toward(players[i].volume_linear, desired, delta * 0.22)
		if i != slot and players[i].volume_linear < 0.0002: players[i].stop()
	elapsed += delta
	if elapsed < 0.15: return
	elapsed = 0.0
	var current := get_tree().current_scene
	if current == null: return
	if scene != current:
		scene = current
		prior_grounded = true
		for request in scene.find_children("DrawingRequest", "", true, false):
			if not request.has_meta("audio_connected"):
				request.set_meta("audio_connected", true)
				request.request_prepared.connect(func(_payload): play_cue("submit"))
				request.state_changed.connect(func(state):
					if state == "READY": play_cue("ready")
				)
	var journey = get_node_or_null("/root/Journey")
	if controls:
		controls.visible = not (journey != null and journey.busy) and not (narrator != null and narrator.panel.opened) and scene.get("drawing") != true and scene.get("presentation_phase") != "book"
	var intro: bool = journey != null and journey.visited_chapters.is_empty() and journey.from_stage == 0 and journey.target_stage == 1 and "/overworld/" in scene.scene_file_path
	_select("opening" if intro else track_for(scene.scene_file_path, scene.get("stay_presented") == true))
	if journey != null and phase != journey.phase:
		phase = journey.phase
		if phase.begins_with("page_to_"): play_cue("page")
	var player = scene.get("player")
	if player != null and scene.process_mode != Node.PROCESS_MODE_DISABLED and player.input_enabled:
		if prior_grounded and not player.is_on_floor() and player.velocity.y > 2: play_cue("jump")
		prior_grounded = player.is_on_floor()
		if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
			step_timer += 0.15
			if step_timer > 0.4:
				step_timer = 0
				play_cue("step")

func play_cue(cue: String) -> void:
	if master_muted or effects_volume <= 0 or not cues.has(cue): return
	var narrator = get_node_or_null("/root/Narrator")
	if narrator != null and narrator.panel.mic != null and narrator.panel.mic.recording: return
	for effect in effects:
		if effect.playing: continue
		effect.stream = cues[cue]
		effect.volume_linear = effects_volume * (0.2 if cue == "step" else 0.55)
		effect.play()
		return

func set_muted(value: bool) -> void:
	master_muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)

func _sound(cue: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.65 if cue == "page" else (0.35 if cue == "ready" else 0.1)
	var count := int(duration * stream.mix_rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 19
	var filtered := 0.0
	for i in count:
		var t := float(i) / count
		var envelope := pow(sin(PI * t), 1.4)
		var noise := random.randf_range(-1, 1)
		filtered = lerpf(filtered, noise, 0.25)
		var sample: float
		if cue == "page": sample = filtered * envelope * (0.25 + 0.3 * pow(sin(t * PI * 5), 2))
		elif cue == "step": sample = filtered * envelope * 0.3
		else:
			var frequency: float = {"click": 440.0, "submit": 660.0, "ready": 880.0, "jump": 330.0}.get(cue, 440.0)
			sample = sin(TAU * frequency * float(i) / stream.mix_rate) * envelope * 0.16
		data.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
	stream.data = data
	return stream

func _build_controls() -> void:
	var layer := CanvasLayer.new()
	controls = layer
	layer.layer = 60
	add_child(layer)
	var button := Button.new()
	button.text = "Audio"
	button.position = Vector2(20, 220)
	layer.add_child(button)
	menu = PanelContainer.new()
	menu.position = Vector2(20, 262)
	layer.add_child(menu)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(10)
	paper.set_content_margin_all(12)
	menu.add_theme_stylebox_override("panel", paper)
	button.add_theme_stylebox_override("normal", paper)
	button.add_theme_color_override("font_color", Color("294a43"))
	var stack := VBoxContainer.new()
	menu.add_child(stack)
	for label in ["Music", "Effects"]:
		var title := Label.new()
		title.text = label
		title.add_theme_color_override("font_color", Color("294a43"))
		stack.add_child(title)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(190, 32)
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = 0.6
		slider.value_changed.connect(func(value):
			if label == "Music": music_volume = value
			else: effects_volume = value
		)
		stack.add_child(slider)
	var mute := CheckButton.new()
	mute.text = "Mute all"
	mute.add_theme_color_override("font_color", Color("294a43"))
	mute.toggled.connect(set_muted)
	stack.add_child(mute)
	menu.hide()
	button.pressed.connect(func(): menu.visible = not menu.visible)


func _exit_tree() -> void:
	for player in players + effects:
		player.stop()
		player.stream = null
	streams.clear()
	cues.clear()
