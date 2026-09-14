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
var previous_hud_visible := true
var previous_player_input := true
var previous_camera_follow := true
var reveal_text := ""
var reveal_time := 0.0
var reveal_duration := 0.0
var reveal_wait := 0.0
var speech_started := false
const Layout = preload("res://ui/storybook/layout.gd")
var caption_art: TextureRect
var player_caption: Control
var player_text: Label
var stop_button: Button
var last_status := ""
var current_speaker := "narrator"
var reveal_tween: Tween
var revealing_boss := false
var reveal_callback: Callable


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry = Layout.tool(self, "microphone", _talk)
	entry.toggle_mode = true
	Layout.corner(entry, -144, -48)
	entry.hide()
	caption = PanelContainer.new()
	caption.name = "SpeakerDialogue"
	add_child(caption)
	caption.add_to_group("drawing_input_blocker")
	caption.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_art = Layout.paper(caption, "narrator")
	caption_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A plain Control keeps labels inside the paper instead of growing its bounds.
	var stack := Control.new()
	caption.add_child(stack)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label = _label(stack, "Narrator", 14)
	speaker_label.hide()
	caption_text = Layout.RollingLabel.new()
	stack.add_child(caption_text)
	caption_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption_text.anchor_left = .27
	caption_text.anchor_right = .88
	caption_text.anchor_top = .35
	caption_text.anchor_bottom = .87
	thinking = Control.new()
	stack.add_child(thinking)
	thinking.position = Vector2(185, 112)
	for i in 3:
		var dot := _label(thinking, "●", 15)
		dot.position = Vector2(i*18,4)
		thinking_dots.append(dot)
	thinking.hide()
	confirmation = VBoxContainer.new()
	add_child(confirmation)
	confirmation.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	confirmation.position -= Vector2(180, 0)
	var question := _label(confirmation, "End this journey by staying here?", 17)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var choice := HBoxContainer.new()
	confirmation.add_child(choice)
	_button(choice, "End my journey here", story.confirm_stay)
	_button(choice, "Keep exploring", story.cancel_stay)
	confirmation.hide()
	caption.hide()
	_build_player_caption()
	_build_canvas()
	resized.connect(_layout)
	_layout()
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
	if story.chapter == 5 and story.scene.get("boss_revealed") == false: return
	opened = true

func _talk() -> void:
	if busy or not get_node("/root/Journey").microphone_unlocked: return
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
	if entry: entry.set_pressed_no_signal(false)
	if player_caption: player_caption.hide()
	if canvas_panel: canvas_panel.hide()
	_resume_world()
	set_busy(false)

func _resume_world() -> void:
	if is_instance_valid(paused_scene):
		var player = paused_scene.get("player")
		if player:
			player.set_drawing_active(false)
			player.set_input_enabled(previous_player_input)
		paused_scene.camera_follow_enabled = previous_camera_follow
		var hud = paused_scene.get("hud_root")
		if hud: hud.visible = previous_hud_visible
	paused_scene = null

func set_busy(value: bool) -> void:
	busy = value
	entry.disabled = value or not get_node("/root/Journey").microphone_unlocked
	thinking.visible = value
	if value:
		thinking_time = 0
		if opened:
			player_caption.show()
		else: caption.show()

func reset_story() -> void:
	close_dialogue()
	surface.clear()
	confirmation.hide()
	hide_caption()

func _show_line(speaker: String, text: String) -> void:
	if speaker == "You":
		player_text.text = text
		player_caption.show()
		return
	finish_reveal()
	if is_instance_valid(story.scene):
		var status = story.scene.get("status_label") if story.chapter == 1 else story.scene.get("status")
		if status is Label: last_status = status.text
	speaker_label.text = speaker
	current_speaker = "otter" if speaker == "Otter" else ("boss" if speaker == "Storykeeper" else "narrator")
	caption_art.texture = load("res://ui/storybook/dialogue_" + current_speaker + ".png")
	caption_text.anchor_left = .20 if current_speaker == "otter" else .27
	caption_text.anchor_top = .39 if current_speaker == "boss" else .35
	caption_text.text = text
	caption_text.show()
	caption.show()

func present(utterance: Dictionary, clear_input := true) -> void:
	if clear_input: surface.clear()
	set_busy(false)
	_show_line("Otter" if utterance.get("speaker") == "otter" else ("Storykeeper" if story.chapter == 5 and is_instance_valid(story.scene) and story.scene.get("boss_revealed") == true else "Narrator"),str(utterance.text))
	reveal_text = str(utterance.text)
	reveal_time = 0
	reveal_wait = 0
	reveal_duration = maxf(2.0,reveal_text.split(" ",false).size()/2.5)
	speech_started = false
	caption_text.text = ""

func start_speech(duration: float) -> void:
	if reveal_text.is_empty(): return
	speech_started = true
	if duration > 0: reveal_duration = duration

func finish_reveal() -> void:
	if not reveal_text.is_empty() and caption_text: caption_text.text = reveal_text
	reveal_text = ""
	if caption_text:
		caption_text.visible_characters = -1

func speech_finished() -> void:
	finish_reveal()
	if revealing_boss: return
	if not mic.recording and not busy:
		close_dialogue()
		if not confirmation.visible: caption.hide()

func _process(delta: float) -> void:
	_update_tools()
	if not revealing_boss and not get_node("/root/Journey").busy: _relay_status()
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
	caption_text.text = " ".join(words.slice(0,count))
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
	Layout.toolbar(canvas_panel, surface, _finish_drawing, _share_drawing)
	Layout.drawing_tools(canvas_panel)
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
	if busy or mic.recording or canvas_panel.visible or revealing_boss or story.chapter != 5: return
	open_dialogue()
	if not opened: return
	story.skip(true)
	paused_scene = story.scene
	previous_player_input = paused_scene.player.input_enabled
	previous_camera_follow = paused_scene.camera_follow_enabled
	paused_scene.player.set_input_enabled(false)
	paused_scene.player.set_drawing_active(true)
	paused_scene.camera_follow_enabled = false
	var hud = paused_scene.get("hud_root")
	if hud:
		previous_hud_visible = hud.visible
		hud.hide()
	canvas_panel.show()

func _unhandled_input(event: InputEvent) -> void:
	if opened and event.is_action_pressed("ui_cancel"):
		close_dialogue()
		story.skip()
		get_viewport().set_input_as_handled()

func _start_recording() -> void:
	if not get_node("/root/Journey").microphone_unlocked: return
	story.skip(true)
	dialogue_epoch += 1
	_show_line("You","Listening…")
	mic.start()
	entry.set_pressed_no_signal(true)

func receive_transcript(text: String, partial := false) -> void:
	text = text.strip_edges()
	if text.is_empty():
		if not partial: show_error("No speech heard. Tap the microphone and try again.")
		return
	_show_line("You",text)
	if not partial: story.ask(text)

func _build_player_caption() -> void:
	player_caption = Control.new()
	player_caption.name = "PlayerSpeech"
	add_child(player_caption)
	player_caption.add_to_group("drawing_input_blocker")
	player_caption.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper := Layout.paper(player_caption, "player")
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_text = Layout.RollingLabel.new()
	player_caption.add_child(player_text)
	player_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player_text.anchor_left = .05
	player_text.anchor_right = .80
	player_text.anchor_top = .12
	player_text.anchor_bottom = .92
	player_text.add_theme_font_size_override("font_size", 18)
	stop_button = _button(player_caption, "■", func():
		if mic.recording: mic.stop(true)
		else: close_dialogue()
	)
	stop_button.add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var disc := StyleBoxFlat.new()
		disc.bg_color = Color("d3b07c66")
		disc.set_corner_radius_all(26)
		stop_button.add_theme_stylebox_override(state, disc)
	stop_button.tooltip_text = "Stop recording"
	stop_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	stop_button.offset_left = -78
	stop_button.offset_right = -26
	stop_button.offset_top = -26
	stop_button.offset_bottom = 26
	player_caption.hide()

func _layout() -> void:
	var width := clampf(size.x * .49, 340, 660)
	if not revealing_boss:
		caption.position = Vector2(24, 24)
	caption.size = Vector2(width, width * .35)
	player_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	player_caption.offset_left = -minf(size.x - 220, 700)
	player_caption.offset_right = -190
	player_caption.offset_top = -144
	player_caption.offset_bottom = -48

func _update_tools() -> void:
	if not is_instance_valid(story.scene) or not story.scene.is_inside_tree(): return
	var player = story.scene.get("player")
	var locked: bool = player != null and (player.drawing_active or not player.input_enabled)
	var draw = story.scene.get("book") if story.chapter == 1 else story.scene.get("draw_button")
	if draw is Button:
		var unlocked: bool = get_node("/root/Journey").microphone_unlocked
		Layout.corner(draw, -256 if unlocked else -144, -160 if unlocked else -48)
		if opened or revealing_boss: draw.disabled = true
	entry.disabled = not get_node("/root/Journey").microphone_unlocked or busy or locked or revealing_boss or (story.chapter == 5 and story.scene.get("boss_revealed") == false) or (story.chapter == 4 and story.scene.has_method("near_otter") and not story.scene.near_otter())
	entry.set_pressed_no_signal(mic.recording)
	stop_button.disabled = busy
	stop_button.tooltip_text = "Stop recording" if mic.recording else "Close speech"

func _relay_status() -> void:
	if not is_instance_valid(story.scene) or not story.scene.is_inside_tree() or story.chapter == 0: return
	var label = story.scene.get("status_label") if story.chapter == 1 else story.scene.get("status")
	if not label is Label: return
	label.hide()
	var value: String = label.text
	var drawing_hint = story.scene.get("drawing_hint") if story.chapter == 1 else story.scene.get("hint")
	var player = story.scene.get("player")
	if player and player.drawing_active and drawing_hint is Label: value = drawing_hint.text
	if value == last_status or value.is_empty(): return
	if story.scene.get("entering") == true or get_node("/root/Journey").busy: return
	if not reveal_text.is_empty() or busy or opened: return
	last_status = value
	# Live narration speaks authored guidance; local errors remain readable offline.
	if story.enabled and label.get_meta("narrator_guidance", "") == value: return
	_show_line("Narrator", value)
	last_status = value

func animate_boss_reveal(reveal: Callable) -> void:
	if revealing_boss: return
	revealing_boss = true
	reveal_callback = reveal
	if reveal_text.is_empty():
		_show_line("Narrator", "There is one last thing I haven't told you…")
		reveal_text = caption_text.text
		reveal_time = 0
		reveal_duration = 3.2
		reveal_wait = 0
		speech_started = true
		caption_text.text = ""
	var home := Vector2(24, 24)
	var center := (size - caption.size) * .5
	reveal_tween = create_tween()
	reveal_tween.tween_interval(1.2)
	reveal_tween.tween_property(caption, "position", center, .65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	reveal_tween.tween_interval(.18)
	reveal_tween.tween_callback(func():
		if reveal_callback.is_valid(): reveal_callback.call()
		caption.pivot_offset = caption.size * .5
	)
	reveal_tween.tween_property(caption, "scale", Vector2.ONE * 1.08, .08)
	reveal_tween.tween_property(caption, "scale", Vector2.ONE, .2)
	reveal_tween.tween_property(caption, "position", home, .36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reveal_tween.tween_callback(func():
		revealing_boss = false
		current_speaker = "boss"
		caption_art.texture = load("res://ui/storybook/dialogue_boss.png")
		caption_text.anchor_top = .39
		speaker_label.text = "Storykeeper"
	)

func cancel_boss_reveal() -> void:
	if reveal_tween: reveal_tween.kill()
	revealing_boss = false
	reveal_callback = Callable()
	caption.scale = Vector2.ONE
	_layout()
