extends Control

const INK := Color("294a43")
var story: Node
var entry: Button
var caption: PanelContainer
var caption_text: Label
var speaker_label: Label
var thinking: Control
var thinking_dots: Array[Label] = []
var thinking_time := 0.0
var surface: Control
var canvas_panel: Control
var confirmation: VBoxContainer
var opened := false
var busy := false
var dialogue_epoch := 0
var mic: Node
var paused_scene: Node
var previous_mode := Node.PROCESS_MODE_INHERIT
var previous_hud_visible := true
var reveal_text := ""
var reveal_time := 0.0
var reveal_duration := 0.0
var reveal_wait := 0.0
var speech_started := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry = _button(self, "Talk", _talk)
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
	caption.offset_left = 28
	caption.offset_right = -255
	caption.offset_top = -150
	caption.offset_bottom = -24
	var style := _paper()
	style.bg_color.a = .76
	style.shadow_size = 0
	style.set_content_margin_all(16)
	caption.add_theme_stylebox_override("panel", style)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	caption.add_child(stack)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label = _label(stack, "Narrator", 14)
	caption_text = _label(stack, "", 18)
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thinking = Control.new()
	thinking.custom_minimum_size = Vector2(70,24)
	stack.add_child(thinking)
	for i in 3:
		var dot := _label(thinking, "●", 15)
		dot.position = Vector2(i*18,4)
		thinking_dots.append(dot)
	thinking.hide()
	confirmation = VBoxContainer.new()
	stack.add_child(confirmation)
	var question := _label(confirmation, "End this journey by staying here?", 17)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var choice := HBoxContainer.new()
	confirmation.add_child(choice)
	_button(choice, "End my journey here", story.confirm_stay)
	_button(choice, "Keep exploring", story.cancel_stay)
	confirmation.hide()
	caption.hide()
	_build_canvas()
	mic = preload("res://scripts/narrator/microphone.gd").new()
	add_child(mic)
	mic.partial_recorded.connect(func(wav): story.transcribe(wav,true))
	mic.recorded.connect(func(wav): entry.text = "Talk"; story.transcribe(wav))
	mic.failed.connect(func(message): entry.text = "Talk"; set_busy(false); show_error(message))

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
	if opened or not is_instance_valid(story.scene) or story.chapter not in [4,5]: return
	if story.chapter == 4 and story.scene.has_method("near_otter") and not story.scene.near_otter(): return
	var player = story.scene.get("player")
	if player == null or not player.input_enabled or player.walking_in: return
	opened = true

func _talk() -> void:
	if busy: return
	if mic.recording:
		mic.stop(true)
		return
	open_dialogue()
	if not opened: return
	_start_recording()

func close_dialogue() -> void:
	opened = false
	dialogue_epoch += 1
	if mic and mic.recording: mic.stop(false)
	if entry: entry.text = "Talk"
	if canvas_panel: canvas_panel.hide()
	_resume_world()
	set_busy(false)

func _resume_world() -> void:
	if is_instance_valid(paused_scene):
		paused_scene.process_mode = previous_mode
		var hud = paused_scene.get("hud_root")
		if hud: hud.visible = previous_hud_visible
	paused_scene = null

func set_busy(value: bool) -> void:
	busy = value
	entry.disabled = value
	thinking.visible = value
	if value:
		thinking_time = 0
		caption.show()

func reset_story() -> void:
	close_dialogue()
	surface.clear()
	confirmation.hide()
	hide_caption()

func _show_line(speaker: String, text: String) -> void:
	finish_reveal()
	speaker_label.text = speaker
	caption_text.text = text
	caption_text.show()
	caption.show()

func present(utterance: Dictionary, clear_input := true) -> void:
	if clear_input: surface.clear()
	set_busy(false)
	_show_line("Otter" if utterance.get("speaker") == "otter" else ("Storykeeper" if story.chapter == 5 else "Narrator"),str(utterance.text))
	reveal_text = str(utterance.text)
	reveal_time = 0
	reveal_wait = 0
	reveal_duration = maxf(2.0,reveal_text.split(" ",false).size()/2.5)
	speech_started = false
	caption_text.visible_characters = 0

func start_speech(duration: float) -> void:
	if reveal_text.is_empty(): return
	speech_started = true
	if duration > 0: reveal_duration = duration

func finish_reveal() -> void:
	reveal_text = ""
	if caption_text: caption_text.visible_characters = -1

func speech_finished() -> void:
	finish_reveal()
	if not mic.recording and not busy:
		close_dialogue()
		if not confirmation.visible: caption.hide()

func _process(delta: float) -> void:
	if busy:
		thinking_time += delta
		for i in thinking_dots.size():
			thinking_dots[i].position.y = 4-5*maxf(0,sin(thinking_time*6-i*.8))
	if reveal_text.is_empty(): return
	reveal_wait += delta
	if speech_started and story.audio.playing:
		reveal_time = maxf(reveal_time,story.audio.get_playback_position())
	elif not story.voice_enabled or reveal_wait > 8 or speech_started:
		reveal_time += delta
	else: return
	var words := reveal_text.split(" ",false)
	var count := mini(words.size(),(int(reveal_time/reveal_duration*words.size())/3+1)*3)
	caption_text.visible_characters = " ".join(words.slice(0,count)).length()
	if reveal_time >= reveal_duration and not story.audio.playing: speech_finished()

func hide_caption() -> void:
	finish_reveal()
	caption.hide()

func show_error(message: String) -> void:
	_show_line("",message)
	close_dialogue()

func refresh_state() -> void:
	confirmation.visible = story.state.get("candidate") != null
	if confirmation.visible: caption.show()
	if story.state.get("ending") != null:
		close_dialogue()
		hide_caption()

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
	_resume_world()
	opened = false

func _share_drawing() -> void:
	if busy or mic.recording or not surface.has_drawing(): return
	_finish_drawing()
	opened = true
	_show_line("You","Shared a drawing.")
	story.ask("",surface.snapshot_png())

func _draw_idea() -> void:
	if busy or mic.recording or story.chapter != 5: return
	open_dialogue()
	if not opened: return
	story.skip()
	paused_scene = story.scene
	previous_mode = paused_scene.process_mode
	paused_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var hud = paused_scene.get("hud_root")
	if hud:
		previous_hud_visible = hud.visible
		hud.hide()
	canvas_panel.show()
	caption.hide()

func _unhandled_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		story.skip()
		get_viewport().set_input_as_handled()

func _start_recording() -> void:
	story.skip()
	dialogue_epoch += 1
	_show_line("You","Listening…")
	mic.start()
	entry.text = "Stop recording"

func receive_transcript(text: String, partial := false) -> void:
	text = text.strip_edges()
	if text.is_empty():
		if not partial: show_error("No speech heard. Tap the microphone and try again.")
		return
	_show_line("You",text)
	if not partial: story.ask(text)
