extends Node

## One persistent mix across scenes: authored BGM, local feedback, and speech ducking.
const TRACKS := ["opening", "chapters_1_3", "otter", "storykeeper", "ending"]
var players: Array[AudioStreamPlayer] = []
var effects: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var cues: Dictionary = {}
var selected := ""
var slot := 0
var music_volume := 0.5
var effects_volume := 0.5
var voice_volume := 0.5
var master_muted := false
var phase := ""
var scene: Node
var elapsed := 0.0
var step_timer := 0.0
var prior_grounded := true
var menu: PanelContainer
var controls: CanvasLayer
var menu_button: Button
var menu_blocker: Control
var menu_close: Button
var map_return: TextureButton
var menu_scene: Node
var menu_previous_mode := Node.PROCESS_MODE_INHERIT
var panel_previous_mode := Node.PROCESS_MODE_INHERIT
var mute_notice: CheckButton
var hidden_menu_layers: Dictionary = {}
var panel_previous_visible := true
var voice_was_paused := false


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
	for cue in ["page", "click", "submit", "ready", "jump", "step", "reveal"]: cues[cue] = _sound(cue)
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
		close_menu()
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
		controls.visible = not (journey != null and journey.busy) and scene.get("presentation_phase") != "book"
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

func set_voice_volume(value: float) -> void:
	voice_volume = clampf(value, 0.0, 1.0)
	var narrator = get_node_or_null("/root/Narrator")
	if narrator != null and is_instance_valid(narrator.audio):
		narrator.audio.volume_linear = voice_volume

func set_muted(value: bool) -> void:
	master_muted = value
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)

func _sound(cue: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.45 if cue == "reveal" else (0.65 if cue == "page" else (0.35 if cue == "ready" else 0.1))
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
		elif cue == "reveal": sample = sin(TAU * (90.0 - 45.0 * t) * float(i) / stream.mix_rate) * exp(-t * 7.0) * 0.45 + filtered * envelope * .12
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
	var root := Control.new()
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_blocker = Control.new()
	root.add_child(menu_blocker)
	menu_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_blocker.hide()
	menu_blocker.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed: close_menu()
	)
	menu_button = preload("res://ui/storybook/layout.gd").tool(root, "menu")
	menu_button.toggle_mode = true
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -144
	menu_button.offset_right = -48
	menu_button.offset_top = 40
	menu_button.offset_bottom = 136
	menu = PanelContainer.new()
	root.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.offset_left = -248
	menu.offset_right = 248
	menu.offset_top = -300
	menu.offset_bottom = 300
	menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var paper := StyleBoxTexture.new()
	paper.texture = load("res://ui/storybook/menu_paper.png")
	paper.content_margin_left = 62
	paper.content_margin_right = 62
	paper.content_margin_top = 100
	paper.content_margin_bottom = 76
	menu.add_theme_stylebox_override("panel", paper)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 10)
	menu.add_child(stack)
	var serif := preload("res://ui/title/cormorant_upright_bold.ttf")
	var source_knob: Texture2D = load("res://ui/storybook/slider_knob.png")
	var knob_image := source_knob.get_image()
	knob_image.resize(42, 42, Image.INTERPOLATE_LANCZOS)
	var knob := ImageTexture.create_from_image(knob_image)
	for label in ["Music", "Sound", "Voice"]:
		var title := Label.new()
		title.text = label
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_override("font", serif)
		title.add_theme_font_size_override("font_size", 30)
		title.add_theme_color_override("font_color", Color("383838"))
		stack.add_child(title)
		var slider := HSlider.new()
		slider.name = label + "Volume"
		slider.custom_minimum_size = Vector2(360, 38)
		slider.tooltip_text = label + " volume"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = voice_volume if label == "Voice" else (music_volume if label == "Music" else effects_volume)
		var track := StyleBoxTexture.new()
		track.texture = load("res://ui/storybook/slider_track.svg")
		track.content_margin_top = 8
		track.content_margin_bottom = 8
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", StyleBoxEmpty.new())
		slider.add_theme_stylebox_override("grabber_area_highlight", StyleBoxEmpty.new())
		for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(state, knob)
		slider.value_changed.connect(func(value):
			if label == "Music": music_volume = value
			elif label == "Sound": effects_volume = value
			else: set_voice_volume(value)
		)
		stack.add_child(slider)
	mute_notice = CheckButton.new()
	mute_notice.text = "Mute all"
	mute_notice.add_theme_color_override("font_color", Color("745d51"))
	mute_notice.toggled.connect(set_muted)
	stack.add_child(mute_notice)
	mute_notice.hide()
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	stack.add_child(spacer)
	var back := TextureButton.new()
	back.name = "BackToMap"
	map_return = back
	back.texture_normal = load("res://ui/storybook/return_normal.svg")
	back.texture_hover = load("res://ui/storybook/return_hover.svg")
	back.texture_focused = back.texture_hover
	back.texture_pressed = load("res://ui/storybook/return_pressed.svg")
	back.ignore_texture_size = true
	back.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	back.custom_minimum_size = Vector2(360, 76)
	back.tooltip_text = "Back to Map"
	back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	stack.add_child(back)
	var map_label := Label.new()
	map_label.text = "Back to Map"
	map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_label.add_theme_font_override("font", serif)
	map_label.add_theme_font_size_override("font_size", 30)
	map_label.add_theme_color_override("font_color", Color.WHITE)
	back.add_child(map_label)
	map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.pressed.connect(_back_to_map)
	_build_menu_close()
	menu.hide()
	menu_button.pressed.connect(func():
		if menu.visible: close_menu()
		else: open_menu()
	)


func _build_menu_close() -> void:
	# Keep X outside the vertical stack so it does not shift the audio controls.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(overlay)
	menu_close = Button.new()
	menu_close.name = "CloseMenu"
	menu_close.tooltip_text = "Close menu"
	menu_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	menu_close.icon = preload("res://ui/storybook/menu_close.svg")
	menu_close.expand_icon = true
	menu_close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_close.custom_minimum_size = Vector2(55, 51)
	for state in ["normal", "hover", "pressed", "disabled"]:
		menu_close.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	menu_close.add_theme_color_override("icon_hover_color", Color("c17e52"))
	menu_close.add_theme_color_override("icon_pressed_color", Color("75432e"))
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color("b4955d")
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(5)
	menu_close.add_theme_stylebox_override("focus", focus)
	overlay.add_child(menu_close)
	overlay.resized.connect(func(): menu_close.position = Vector2(overlay.size.x - 61, -37))
	menu_close.position = Vector2(overlay.size.x - 61, -37)
	menu_close.pressed.connect(close_menu)

func _back_to_map() -> void:
	if map_return.disabled or not menu.visible: return
	play_cue("click")
	close_menu()
	var error: Error = get_node("/root/Journey").browse_map()
	if error != OK: open_menu()


func _exit_tree() -> void:
	for player in players + effects:
		player.stop()
		player.stream = null
	streams.clear()
	cues.clear()

func open_menu() -> void:
	if menu.visible or get_node("/root/Journey").busy: return
	var panel = get_node("/root/Narrator").panel
	if panel.mic.recording: panel.close_dialogue()
	panel_previous_visible = panel.visible
	panel.hide()
	var narrator = get_node("/root/Narrator")
	voice_was_paused = narrator.audio.stream_paused
	narrator.audio.stream_paused = true
	panel_previous_mode = panel.process_mode
	panel.process_mode = Node.PROCESS_MODE_DISABLED
	menu_scene = get_tree().current_scene
	map_return.disabled = not get_node("/root/Journey").can_browse_map()
	map_return.modulate.a = 0.45 if map_return.disabled else 1.0
	map_return.tooltip_text = "Finish the current action to open the map." if map_return.disabled else "Back to Map"
	if is_instance_valid(menu_scene):
		menu_previous_mode = menu_scene.process_mode
		menu_scene.process_mode = Node.PROCESS_MODE_DISABLED
		for layer in menu_scene.find_children("*", "CanvasLayer", true, false):
			hidden_menu_layers[layer] = layer.visible
			layer.hide()
	mute_notice.visible = master_muted
	mute_notice.set_pressed_no_signal(master_muted)
	menu.show()
	menu_blocker.show()
	menu_button.set_pressed_no_signal(true)
	menu.find_child("MusicVolume", true, false).grab_focus()

func close_menu() -> void:
	# The persistent toggle must not consume the next jump as UI accept.
	var focus := get_viewport().gui_get_focus_owner()
	if controls != null and is_instance_valid(focus) and controls.is_ancestor_of(focus):
		focus.release_focus()
	if menu and menu.visible:
		var narrator = get_node("/root/Narrator")
		narrator.panel.process_mode = panel_previous_mode
		narrator.panel.visible = panel_previous_visible
		narrator.audio.stream_paused = voice_was_paused
	for layer in hidden_menu_layers:
		if is_instance_valid(layer): layer.visible = hidden_menu_layers[layer]
	hidden_menu_layers.clear()
	if is_instance_valid(menu_scene): menu_scene.process_mode = menu_previous_mode
	menu_scene = null
	if menu: menu.hide()
	if menu_blocker: menu_blocker.hide()
	if menu_button: menu_button.set_pressed_no_signal(false)

func _unhandled_input(event: InputEvent) -> void:
	if menu and menu.visible and event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()
