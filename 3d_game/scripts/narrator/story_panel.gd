extends Control

const INK := Color("294a43")
var story: Node
var entry: Button
var drawer: PanelContainer
var caption: PanelContainer
var caption_text: Label
var transcript: RichTextLabel
var thinking: Control
var thinking_dots: Array[Label] = []
var thinking_time := 0.0
var heard: Label
var draw_idea: Button
var reveal_text := ""
var reveal_prefix := 0
var reveal_time := 0.0
var reveal_duration := 0.0
var reveal_wait := 0.0
var speech_started := false
var surface: Control
var canvas_panel: Control
var voice_note: Label
var confirmation: VBoxContainer
var opened := false
var paused_scene: Node
var previous_mode := Node.PROCESS_MODE_INHERIT
var previous_hud_visible := true
var busy := false
var heading_title: Label
var mic: Node
var record_button: Button
var partner := "Storykeeper"
var dialogue_epoch := 0
const MICROPHONE_PREFERENCES := "user://microphone_preferences.cfg"
var microphone_prompt_seen := false
var microphone_prompt: ConfirmationDialog

func _ready() -> void:
	var preferences := ConfigFile.new()
	if preferences.load(MICROPHONE_PREFERENCES) == OK:
		microphone_prompt_seen = bool(preferences.get_value("microphone", "prompt_seen", false))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry = _button(self, "Talk", open_dialogue)
	entry.icon = load("res://ui/microphone.svg")
	entry.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	entry.offset_left = -240
	entry.offset_right = -28
	entry.offset_top = -174
	entry.offset_bottom = -118
	entry.hide()
	caption = PanelContainer.new()
	add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 200
	caption.offset_right = -255
	caption.offset_top = -115
	caption.offset_bottom = -20
	var subtitle_style := _paper()
	subtitle_style.bg_color = Color(0.06, 0.13, 0.12, 0.68)
	subtitle_style.shadow_size = 0
	subtitle_style.set_content_margin_all(16)
	caption.add_theme_stylebox_override("panel", subtitle_style)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	caption.add_child(stack)
	caption_text = _label(stack, "", 18)
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_text.add_theme_color_override("font_color", Color("fff9ed"))
	caption_text.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.04, 0.8))
	caption_text.add_theme_constant_override("outline_size", 2)
	caption_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.hide()
	drawer = PanelContainer.new()
	add_child(drawer)
	drawer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	drawer.offset_left = -390
	drawer.offset_right = 390
	drawer.offset_top = -370
	drawer.offset_bottom = -24
	var glass := _paper()
	glass.bg_color.a = 0.76
	drawer.add_theme_stylebox_override("panel", glass)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	drawer.add_child(content)
	var heading := HBoxContainer.new()
	content.add_child(heading)
	heading_title = _label(heading, "A word between pages", 27)
	heading_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(heading, "Close · Esc", close_dialogue)
	_label(content, "AI storyteller · Your choices remain yours.", 13)
	transcript = RichTextLabel.new()
	transcript.bbcode_enabled = false
	transcript.custom_minimum_size.y = 100
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.add_theme_color_override("default_color", INK)
	transcript.add_theme_font_size_override("normal_font_size", 19)
	content.add_child(transcript)
	transcript.text = ""
	heard = _label(content, "Tap the microphone and speak. Pause when you are done.", 17)
	heard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	content.add_child(actions)
	draw_idea = _button(actions, "Draw an idea", _draw_idea)
	record_button = _button(actions, "Speak", _toggle_recording)
	record_button.icon = load("res://ui/microphone.svg")
	thinking = Control.new()
	thinking.custom_minimum_size = Vector2(70, 24)
	content.add_child(thinking)
	for i in 3:
		var dot := _label(thinking, "●", 15)
		dot.position = Vector2(i * 18, 4)
		thinking_dots.append(dot)
	thinking.hide()
	voice_note = _label(content, "", 13)
	confirmation = VBoxContainer.new()
	content.add_child(confirmation)
	var question := _label(confirmation, "End this journey by staying here? Taking a break does not end your story.", 17)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var choice := HBoxContainer.new()
	confirmation.add_child(choice)
	_button(choice, "End my journey here", story.confirm_stay)
	_button(choice, "Keep exploring", story.cancel_stay)
	confirmation.hide()
	drawer.hide()
	_build_canvas()
	mic = preload("res://scripts/narrator/microphone.gd").new()
	add_child(mic)
	mic.partial_recorded.connect(func(wav): story.transcribe(wav, true))
	mic.recorded.connect(func(wav):
		record_button.text = "Speak"
		story.transcribe(wav)
	)
	microphone_prompt = ConfirmationDialog.new()
	microphone_prompt.title = "Use your microphone?"
	microphone_prompt.dialog_text = "Speak for up to 20 seconds. Pause when you are done."
	microphone_prompt.ok_button_text = "Start recording"
	microphone_prompt.cancel_button_text = "Not now"
	microphone_prompt.confirmed.connect(func():
		if opened: _start_recording()
	)
	add_child(microphone_prompt)
	mic.failed.connect(func(message): record_button.text = "Speak"; set_busy(false); show_error(message))

func _paper() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f3ebda")
	style.set_corner_radius_all(18)
	style.set_content_margin_all(20)
	style.shadow_color = Color(0.03, 0.09, 0.08, 0.3)
	style.shadow_size = 14
	return style

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", INK)
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 38
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("e5ddc9")
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", style)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func open_dialogue() -> void:
	if opened or not is_instance_valid(story.scene) or story.chapter not in [4, 5]: return
	if story.chapter == 4 and story.scene.has_method("near_otter") and not story.scene.near_otter(): return
	var player = story.scene.get("player")
	if player == null or not player.input_enabled or player.walking_in: return
	partner = "Otter" if story.chapter == 4 else "Storykeeper"
	draw_idea.visible = story.chapter == 5
	heading_title.text = "A word with the " + partner
	story.skip()
	paused_scene = story.scene
	previous_mode = paused_scene.process_mode
	paused_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = paused_scene.get("hud_root")
	if hud:
		previous_hud_visible = hud.visible
		hud.hide()
	opened = true
	entry.hide()
	drawer.show()
	refresh_state()
	record_button.grab_focus()

func close_dialogue() -> void:
	if not opened: return
	opened = false
	dialogue_epoch += 1
	if mic and mic.recording:
		mic.stop(false)
		set_busy(false)
	if record_button: record_button.text = "Speak"
	if microphone_prompt: microphone_prompt.hide()
	drawer.hide()
	canvas_panel.hide()
	if is_instance_valid(paused_scene):
		paused_scene.process_mode = previous_mode
		var hud = paused_scene.get("hud_root")
		if hud: hud.visible = previous_hud_visible
		var player = paused_scene.get("player")
		if player: player.set_input_enabled(player.input_enabled)
	paused_scene = null

func set_busy(value: bool) -> void:
	busy = value
	if record_button: record_button.disabled = value
	if draw_idea: draw_idea.disabled = value
	if thinking: thinking.visible = value
	if value: thinking_time = 0.0
	if voice_note: voice_note.text = ""

func reset_story() -> void:
	close_dialogue()
	heard.text = "Tap the microphone and speak."
	surface.clear()
	transcript.text = ""
	confirmation.hide()
	set_busy(false)

func present(utterance: Dictionary, clear_input := true) -> void:
	finish_reveal()
	if clear_input: surface.clear()
	var speaker := "Otter" if utterance.get("speaker") == "otter" else ("Storykeeper" if story.chapter == 5 else "Narrator")
	transcript.text += "\n\n" + speaker + ": "
	reveal_prefix = transcript.text.length()
	reveal_text = str(utterance.text)
	transcript.text += reveal_text
	transcript.visible_characters = reveal_prefix
	reveal_time = 0.0
	reveal_wait = 0.0
	reveal_duration = maxf(2.0, reveal_text.split(" ", false).size() / 2.5)
	speech_started = false
	caption_text.text = reveal_text
	caption_text.visible_characters = 0
	if not opened: caption.show()

func start_speech(duration: float) -> void:
	if reveal_text.is_empty(): return
	speech_started = true
	if duration > 0: reveal_duration = duration

func finish_reveal() -> void:
	reveal_text = ""
	if transcript: transcript.visible_characters = -1
	if caption_text: caption_text.visible_characters = -1

func _process(delta: float) -> void:
	if busy:
		thinking_time += delta
		for i in thinking_dots.size():
			thinking_dots[i].position.y = 4.0 - 5.0 * maxf(0, sin(thinking_time * 6.0 - i * .8))
	if reveal_text.is_empty(): return
	reveal_wait += delta
	if speech_started and story.audio.playing:
		reveal_time = maxf(reveal_time, story.audio.get_playback_position())
	elif not story.voice_enabled or reveal_wait > 8.0 or speech_started:
		reveal_time += delta
	else: return
	var words := reveal_text.split(" ", false)
	var count := mini(words.size(), (int(reveal_time / reveal_duration * words.size()) / 3 + 1) * 3)
	var visible_text := " ".join(words.slice(0, count))
	transcript.visible_characters = reveal_prefix + visible_text.length()
	caption_text.visible_characters = visible_text.length()
	transcript.scroll_to_line(transcript.get_line_count() - 1)
	if reveal_time >= reveal_duration: finish_reveal()

func hide_caption() -> void:
	finish_reveal()
	if caption: caption.hide()

func show_error(message: String) -> void:
	voice_note.text = message
	if not opened:
		caption_text.text = message
		caption.show()

func refresh_state() -> void:
	confirmation.visible = story.state.get("candidate") != null
	if story.state.get("ending") != null: close_dialogue()

func _build_canvas() -> void:
	canvas_panel = Control.new()
	canvas_panel.name = "SceneDrawingOverlay"
	add_child(canvas_panel)
	canvas_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface = preload("res://scripts/river/drawing_surface.gd").new()
	canvas_panel.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := PanelContainer.new()
	canvas_panel.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left = 20
	toolbar.offset_right = -20
	toolbar.offset_top = -126
	toolbar.offset_bottom = -20
	toolbar.add_theme_stylebox_override("panel", _paper())
	surface.excluded_control = toolbar
	var stack := VBoxContainer.new()
	toolbar.add_child(stack)
	_label(stack, "Draw your idea here, in the world.", 20)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	_button(actions, "Undo", surface.undo)
	_button(actions, "Clear", surface.clear)
	_button(actions, "Back · Esc", _finish_drawing)
	var use := _button(actions, "Share drawing", _share_drawing)
	use.disabled = true
	surface.changed.connect(func(): use.disabled = not surface.has_drawing())
	canvas_panel.hide()

func _finish_drawing() -> void:
	canvas_panel.hide()
	drawer.show()
	voice_note.text = ""
	record_button.grab_focus()

func _share_drawing() -> void:
	if busy or mic.recording or not surface.has_drawing(): return
	_finish_drawing()
	finish_reveal()
	heard.text = ""
	transcript.text += "\n\nYou shared a drawing."
	story.ask("", surface.snapshot_png())

func _draw_idea() -> void:
	if busy or mic.recording: return
	story.skip()
	if story.chapter != 5:
		voice_note.text = "Use this chapter's Draw button for physical objects. You can describe ideas here."
		return
	canvas_panel.show()
	drawer.hide()

func _unhandled_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		if canvas_panel.visible: _finish_drawing()
		else: close_dialogue()
		get_viewport().set_input_as_handled()


func _toggle_recording() -> void:
	if busy: return
	if mic.recording:
		mic.stop(true)
	elif not microphone_prompt_seen:
		microphone_prompt_seen = true
		var preferences := ConfigFile.new()
		preferences.set_value("microphone", "prompt_seen", true)
		preferences.save(MICROPHONE_PREFERENCES)
		microphone_prompt.popup_centered(Vector2i(500, 180))
	else:
		_start_recording()

func _start_recording() -> void:
	story.skip()
	mic.start()
	dialogue_epoch += 1
	heard.text = "Listening…"
	draw_idea.disabled = true
	record_button.text = "Stop recording"
	voice_note.text = "Listening · pause to finish, or tap Stop recording."

func receive_transcript(text: String, partial := false) -> void:
	text = text.strip_edges()
	if text.is_empty():
		if not partial: show_error("No speech heard. Tap Speak and try again.")
		return
	heard.text = "You: " + text
	if partial: return
	heard.text = ""
	finish_reveal()
	transcript.text += "\n\nYou: " + text
	story.ask(text)
