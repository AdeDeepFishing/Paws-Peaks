extends Control

const INK := Color("294a43")
var story: Node
var entry: Button
var drawer: PanelContainer
var caption: PanelContainer
var caption_text: Label
var transcript: RichTextLabel
var input: TextEdit
var send: Button
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
var microphone_consent := false
var microphone_prompt: ConfirmationDialog

func _ready() -> void:
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
	drawer.offset_top = -405
	drawer.offset_bottom = -24
	drawer.add_theme_stylebox_override("panel", _paper())
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
	transcript.text = "Ask about the world, explain an idea, or share what this journey means to you."
	input = TextEdit.new()
	input.placeholder_text = "What would you like to say?"
	input.custom_minimum_size.y = 64
	input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	content.add_child(input)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("font_placeholder_color", Color("798777"))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("fffaf0")
	field.set_corner_radius_all(8)
	field.set_content_margin_all(10)
	input.add_theme_stylebox_override("normal", field)
	input.add_theme_stylebox_override("focus", field)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	_button(actions, "Draw an idea", _draw_idea)
	send = _button(actions, "Send", _send)
	record_button = _button(actions, "Record", _toggle_recording)
	record_button.icon = load("res://ui/microphone.svg")
	_button(actions, "Stop voice", story.skip)
	var voice := CheckButton.new()
	voice.text = "Voice"
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
		voice.add_theme_color_override(color_name, INK)
	voice.button_pressed = true
	voice.toggled.connect(story.set_voice)
	actions.add_child(voice)
	var frequency := OptionButton.new()
	for label in ["Guidance + reactions", "Guidance only"]: frequency.add_item(label)
	frequency.item_selected.connect(func(index): story.verbosity = ["normal", "quiet"][index])
	actions.add_child(frequency)
	frequency.add_theme_color_override("font_color", INK)
	frequency.add_theme_stylebox_override("normal", field)
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
	mic.recorded.connect(func(wav):
		record_button.text = "Record"
		story.transcribe(wav)
	)
	microphone_prompt = ConfirmationDialog.new()
	microphone_prompt.title = "Use your microphone?"
	microphone_prompt.dialog_text = "Record up to 20 seconds. The audio is sent to ElevenLabs to turn it into text. You can edit it before sending, or keep typing instead."
	microphone_prompt.ok_button_text = "Start recording"
	microphone_prompt.cancel_button_text = "Keep typing"
	microphone_prompt.confirmed.connect(func():
		microphone_consent = true
		if opened: _start_recording()
	)
	add_child(microphone_prompt)
	mic.failed.connect(func(message): record_button.text = "Record"; set_busy(false); show_error(message))

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
	input.grab_focus()

func close_dialogue() -> void:
	if not opened: return
	opened = false
	dialogue_epoch += 1
	if mic and mic.recording:
		mic.stop(false)
		set_busy(false)
	if record_button: record_button.text = "Record"
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

func _send() -> void:
	if busy or mic.recording or (input.text.strip_edges().is_empty() and not surface.has_drawing()): return
	if input.text.length() > 2000:
		show_error("Please keep this thought under 2,000 characters.")
		return
	transcript.text += "\n\nYou: " + input.text + (" [drawing]" if surface.has_drawing() else "")
	story.ask(input.text, surface.snapshot_png() if surface.has_drawing() else PackedByteArray())

func set_busy(value: bool) -> void:
	busy = value
	if send: send.disabled = value
	if voice_note: voice_note.text = "The Storykeeper is thinking…" if value else ""

func reset_story() -> void:
	close_dialogue()
	input.text = ""
	surface.clear()
	transcript.text = "Ask about the world, explain an idea, or share what this journey means to you."
	confirmation.hide()
	set_busy(false)

func present(utterance: Dictionary, clear_input := true) -> void:
	if clear_input:
		input.text = ""
		surface.clear()
	transcript.text += "\n\n" + ("Otter" if utterance.get("speaker") == "otter" else ("Storykeeper" if story.chapter == 5 else "Narrator")) + ": " + str(utterance.text)
	transcript.scroll_to_line(transcript.get_line_count() - 1)
	if not opened:
		caption_text.text = str(utterance.text)
		caption.show()

func hide_caption() -> void:
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
	var use := _button(actions, "Use drawing", _finish_drawing)
	use.disabled = true
	surface.changed.connect(func(): use.disabled = not surface.has_drawing())
	canvas_panel.hide()

func _finish_drawing() -> void:
	canvas_panel.hide()
	drawer.show()
	if surface.has_drawing(): voice_note.text = "Your drawing is ready. Add a thought, or send it as it is."
	input.grab_focus()

func _draw_idea() -> void:
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
	elif not microphone_consent:
		microphone_prompt.popup_centered(Vector2i(500, 180))
	else:
		_start_recording()

func _start_recording() -> void:
	story.skip()
	mic.start()
	send.disabled = true
	record_button.text = "Stop recording"
	voice_note.text = "Recording · up to 20 seconds. Review the text before sending."

func receive_transcript(text: String) -> void:
	input.text += (" " if not input.text.is_empty() else "") + text
	voice_note.text = "Check your words, then press Send when ready."
	input.grab_focus()
