extends Node3D

const DrawingSurface = preload("res://scripts/river/drawing_surface.gd")
const GeneratedModel = preload("res://scripts/river/generated_model.gd")
const SPAWN := Vector3(-6.3, 1.5, -6.3)

@onready var presentation = $EncounterPresentation

@onready var player = $Player
@onready var generation = $DesktopGeneration
var generated_visual: Node3D
var generation_modes: OptionButton
var map_button: Button

@onready var request = $DrawingRequest
@onready var bridge: Node3D = $Bridge

var unlocked := false
var bridge_built := false
var completed := false
var transitioning := false
@export var auto_advance := true
var current_item: Dictionary = {}
var current_png := PackedByteArray()
var panel_mode := ""
var muted := false

var hud: CanvasLayer
var title: Label
var objective: Label
var status_label: Label
var book: Button
var drawing_shine: Control
var controls: Label
var modal: Control
var surface: Control
var generation_preview: Control
var normal_hud: Control
var drawing_overlay: Control
var drawing_toolbar: PanelContainer
var drawing_hint: Label
var drawing_cancel: Button
var in_drawing_area := false
var choices: OptionButton
var undo_button: Button
var clear_button: Button
var submit_button: Button
var cancel_button: Button
var audio: AudioStreamPlayer
var tones: Dictionary = {}
var book_key := "E"
var hint_device := -1

func _ready() -> void:
	_build_ui()
	generation_preview = preload("res://scripts/river/generation_preview.gd").attach(self, request, generation, surface)
	Input.joy_connection_changed.connect(_update_controller_hints)
	_update_controller_hints()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	for cue in ["ready", "bridge", "submit"]:
		tones[cue] = _tone(cue)
	$DrawingArea.body_entered.connect(_on_drawing_area)
	$DrawingArea.body_exited.connect(_on_leaving_drawing_area)
	presentation.settled.connect(_update_hud)
	request.state_changed.connect(_on_request_state)
	generation.progress_changed.connect(func(message: String): status_label.text = message)
	_update_hud()

func _process(delta: float) -> void:
	presentation.follow_player(delta)
	_update_drawing_entry()
	map_button.disabled = not can_browse_map()
	if player.position.y < 0.35:
		player.respawn(SPAWN)
		status_label.text = "Back on dry land. Your drawing is safe."
	if bridge_built and not completed and not presentation.busy and player.position.x > 5.8 and player.is_on_floor():
		_finish()
	if completed and auto_advance and not transitioning and player.position.x >= 18.0 and player.position.z >= -8.5 and player.position.z <= -3.5 and player.is_on_floor():
		_enter_woodland()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sketchbook") and unlocked and not completed:
		if panel_mode != "":
			_close_panel(true)
		else:
			_open_book()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and request.state == "PENDING":
		request.cancel()
		status_label.text = "Stopped waiting. Your drawing is safe."
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and panel_mode != "" and not completed:
		_close_panel(false)
		get_viewport().set_input_as_handled()

func _on_drawing_area(body: Node3D) -> void:
	if body != player:
		return
	in_drawing_area = true
	if not unlocked:
		unlocked = true
		status_label.text = "Could you draw a way across?"
		status_label.set_meta("narrator_guidance", status_label.text)
	_update_drawing_entry()

func _on_leaving_drawing_area(body: Node3D) -> void:
	if body == player:
		in_drawing_area = false
		_update_drawing_entry()

func _update_drawing_entry() -> void:
	book.visible = true
	book.disabled = presentation.busy or not in_drawing_area or completed or bridge_built or request.state == "PENDING"
	drawing_shine.set_active(not book.disabled)
	book.text = "%s · %s" % [book_key, "Draw again" if request.state in ["FAILED", "READY"] else "Draw"]
	cancel_button.visible = not presentation.busy and request.state == "PENDING" and not completed

func _open_book() -> void:
	if presentation.busy or completed or bridge_built or request.state == "PENDING":
		return
	if not player.is_on_floor():
		status_label.text = "Land on solid ground before drawing."
		status_label.set_meta("narrator_guidance", status_label.text)
		return
	_show_panel("draw")

func _show_panel(mode: String) -> void:
	if mode == "draw" and (not near_crossing() or not player.is_on_floor() or bridge_built or request.state == "PENDING"):
		status_label.text = "Return to the left riverbank to draw."
		status_label.set_meta("narrator_guidance", status_label.text)
		return
	if mode != "draw": return
	panel_mode = mode
	player.set_drawing_active(true)
	player.set_input_enabled(false)
	modal.hide()
	drawing_overlay.show()
	normal_hud.hide()
	choices.visible = request.mock_mode
	submit_button.disabled = not surface.has_drawing()
	drawing_hint.text = "Draw over the scene. Submit when ready."
	if request.state == "FAILED":
		drawing_hint.text = request.message + " Try again."
	drawing_cancel.grab_focus()

func _close_panel(_resume: bool) -> void:
	surface.drawing = false
	drawing_overlay.hide()
	normal_hud.show()
	modal.hide()
	panel_mode = ""
	player.set_drawing_active(false)
	player.set_input_enabled(true)

func _submit() -> void:
	if panel_mode != "draw" or not near_crossing():
		return
	var png: PackedByteArray = surface.snapshot_png()
	if not request.submit(png, "E01", choices.selected):
		drawing_hint.text = "Draw something first, and finish or cancel any pending request."
		return
	var saved_path: String = request.saved_draft_path
	_close_panel(true)
	if saved_path.is_empty():
		status_label.text = "Drawing submitted, but the local PNG could not be saved."
	_play("submit")
	if request.state == "PENDING":
		var camera: Camera3D = $StageCamera
		var rect: Rect2 = surface.snapshot_screen_rect()
		var screen := Vector2(rect.get_center().x, rect.end.y)
		var anchor = Plane(Vector3.UP, bridge.global_position.y).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
		if anchor is Vector3: generation_preview.anchor_to_world(camera, anchor)
		presentation.begin(bridge.position)

func _on_request_state(state: String) -> void:
	match state:
		"PENDING":
			status_label.text = "Creating your idea... Explore while you wait."
		"READY":
			_finish_generation(request.active_id)
		"FAILED":
			presentation.cancel()
			status_label.text = request.message + " Return to the riverbank to retry."
		"IDLE":
			presentation.cancel()
	_update_hud()

func _finish_generation(id: String) -> void:
	if presentation.busy:
		await presentation.settled
	if request.active_id != id or request.state != "READY": return
	current_item = request.result.duplicate(true)
	current_png = request.snapshot.duplicate()
	if generation.mode != 0 or not request.model_path.is_empty():
		if not _place_generated_model():
			request.fail_current("The generated model could not be loaded. Your drawing is safe.")
			return
	if build_bridge():
		bridge.hide()
		presentation.reveal(bridge.position)
	else:
		if is_instance_valid(generated_visual):
			generated_visual.hide()
			presentation.reveal(generated_visual.position)
		else:
			presentation.cancel()
			generation_preview.model_presented()
		status_label.text = "That idea cannot support a crossing. Return to the riverbank and draw again."
		status_label.set_meta("narrator_guidance", status_label.text)
	_update_hud()

func assist_crossing(direction: Vector3) -> Vector3:
	if not bridge_built or presentation.busy: return direction
	var local: Vector3 = player.position - bridge.position
	if absf(local.x) > 6.5 or absf(local.z) > 1.35: return direction
	if direction.length_squared() < 0.001: return Vector3.ZERO
	# On this authored crossing, X is the travel axis. Both single-key and
	# diagonal input project onto it; letting go never moves the character.
	if absf(direction.x) < 0.2: return direction
	return Vector3(signf(direction.x) * direction.length(), 0, clampf(-local.z * 1.8, -0.65, 0.65))

func _place_generated_model() -> bool:
	var crossing := _supports_bridge()
	var visual: Node3D = GeneratedModel.load_visual(request.model_path, 10.4 if crossing else 1.8, crossing, request.result)
	if visual == null:
		return false
	_clear_generated_model()
	generated_visual = visual
	if crossing:
		bridge.add_child(visual)
		visual.position.y = 0.125
		var shape := $Bridge/Deck/CollisionShape3D.shape.duplicate() as BoxShape3D
		shape.size.z = clampf(GeneratedModel._bounds(visual).size.z, 1.2, 3.0)
		$Bridge/Deck/CollisionShape3D.shape = shape
		$Bridge/Deck/Visual.hide()
		for child in bridge.get_children():
			if child.name.begins_with("Plank"):
				child.hide()
	else:
		generated_visual = GeneratedModel.physics_body(visual, current_item.movable)
		add_child(generated_visual)
		generated_visual.position = Vector3(-4.8, 3.3 if current_item.movable else 1.3, -5.0)
	return true

func _clear_generated_model() -> void:
	if is_instance_valid(generated_visual):
		generated_visual.get_parent().remove_child(generated_visual)
		generated_visual.queue_free()
	generated_visual = null
	var deck := BoxShape3D.new()
	deck.size = Vector3(10.4, 0.25, 2.0)
	$Bridge/Deck/CollisionShape3D.shape = deck
	$Bridge/Deck/Visual.show()
	for child in bridge.get_children():
		if child.name.begins_with("Plank"):
			child.show()

func near_crossing() -> bool:
	return in_drawing_area

func _supports_bridge() -> bool:
	return current_item.get("type", "") == "BRIDGE" and not current_item.get("movable", false)

func can_build_bridge() -> bool:
	return not bridge_built and request.state == "READY" and request.encounter_id == "E01" and _supports_bridge()

func build_bridge() -> bool:
	if not can_build_bridge():
		return false
	bridge_built = true
	get_node("/root/Narrator").record("object_use_resolved", {"result": "Built a usable crossing; the player has not crossed yet.", "item": current_item})
	bridge.show()
	$Bridge/Deck/CollisionShape3D.set_deferred("disabled", false)
	status_label.text = "Your bridge is ready. Walk across to the far bank!"
	status_label.set_meta("narrator_guidance", status_label.text)
	_play("bridge")
	_update_hud()
	return true

func _finish() -> void:
	completed = true
	get_node("/root/Narrator").record("encounter_completed", {"result": "Crossed the river safely.", "item": current_item})
	_update_hud()
	_play("bridge")
	status_label.text = "Follow the path into the woodland."
	status_label.set_meta("narrator_guidance", status_label.text)
	player.set_input_enabled(true)

func _enter_woodland() -> void:
	transitioning = true
	get_tree().current_scene = self
	var error: Error = get_node("/root/Journey").travel_to("res://scenes/woodland/woodland_path.tscn")
	if error != OK:
		transitioning = false
		status_label.text = "The woodland could not be opened. Keep exploring and try again."

func restart() -> void:
	request.reset()
	$StageCamera.transform = presentation.overview
	$StageCamera.size = presentation.overview_size
	_clear_generated_model()
	surface.clear()
	current_item = {}
	current_png = PackedByteArray()
	unlocked = false
	in_drawing_area = false
	completed = false
	transitioning = false
	bridge_built = false
	bridge.hide()
	$Bridge/Deck/CollisionShape3D.set_deferred("disabled", true)
	player.respawn(SPAWN)
	status_label.text = "Follow the path to the river."
	status_label.set_meta("narrator_guidance", status_label.text)
	_close_panel(true)
	_update_hud()

func _update_hud() -> void:
	_update_drawing_entry()
	generation_modes.disabled = presentation.busy or request.state == "PENDING"
	objective.text = "Follow the path into the woodland." if completed else ("Walk across your bridge." if bridge_built else "Find a way across the river.")

func can_browse_map() -> bool:
	return not presentation.busy and request.state != "PENDING" and panel_mode.is_empty() and not transitioning

func _back_to_map() -> void:
	if not can_browse_map(): return
	var error: Error = get_node("/root/Journey").browse_map()
	if error != OK and error != ERR_BUSY:
		status_label.text = "The map could not be opened. Try again."

func _input(event: InputEvent) -> void:
	var device := hint_device
	if event is InputEventKey or event is InputEventMouseButton:
		device = -1
	elif event is InputEventMouseMotion and event.relative.length() > 2.0:
		device = -1
	elif event is InputEventJoypadButton and event.pressed:
		device = event.device
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.25:
		device = event.device
	if device != hint_device:
		hint_device = device
		_update_controller_hints()

static func controller_labels(device_name: String) -> Dictionary:
	var label := device_name.to_lower()
	if "nintendo" in label or "switch" in label:
		return {"draw": "Y", "jump": "B", "sprint": "R", "close": "A"}
	if "playstation" in label or "dualshock" in label or "dualsense" in label or "ps4" in label or "ps5" in label:
		return {"draw": "□", "jump": "×", "sprint": "R1", "close": "○"}
	if "xbox" in label or "xinput" in label:
		return {"draw": "X", "jump": "A", "sprint": "RB", "close": "B"}
	return {"draw": "West button", "jump": "South button", "sprint": "Right shoulder", "close": "East button"}

func _update_controller_hints(device: int = -1, connected: bool = false) -> void:
	if device >= 0 and device == hint_device and not connected:
		hint_device = -1
	if hint_device < 0:
		book_key = "E"
		controls.text = "WASD / Arrows  Move    SPACE  Jump    SHIFT  Sprint\nE  Draw    Esc  Close"
		drawing_cancel.text = "Cancel · Esc"
	else:
		var keys := controller_labels(Input.get_joy_name(hint_device))
		book_key = keys.draw
		controls.text = "Stick / D-pad  Move    %s  Jump    %s  Sprint\n%s  Draw    %s  Close" % [keys.jump, keys.sprint, book_key, keys.close]
		drawing_cancel.text = "Cancel · " + keys.close
	_update_hud()

func _build_ui() -> void:
	hud = CanvasLayer.new()
	hud.name = "RiverHUD"
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("273d36"))
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("fff9ed") if style_name != "hover" else Color("e8dfc8")
		if style_name == "pressed":
			style.bg_color = Color("d6c8a6")
		style.set_corner_radius_all(10)
		style.content_margin_left = 16
		style.content_margin_right = 16
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if style_name == "focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(2)
			style.border_color = Color("b97d42")
		for type in ["Button", "OptionButton"]:
			theme.set_stylebox(style_name, type, style)
	for type in ["Button", "OptionButton"]:
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			theme.set_color(color_name, type, Color("273d36"))
		theme.set_color("font_disabled_color", type, Color("9b9c90"))
	root.theme = theme
	var ui_root := root
	normal_hud = Control.new()
	normal_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	normal_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(normal_hud)
	root = normal_hud
	var title_card := PanelContainer.new()
	title_card.position = Vector2(28, 26)
	title_card.custom_minimum_size = Vector2(430, 112)
	title_card.add_theme_stylebox_override("panel", _paper_style())
	root.add_child(title_card)
	var title_stack := VBoxContainer.new()
	title_card.add_child(title_stack)
	_label(title_stack, "PAWS & PEAKS   /   CHAPTER 01", 14)
	title = _label(title_stack, "Across the River", 30)
	objective = _label(title_stack, "Find a way across the river.", 17)
	generation_modes = OptionButton.new()
	root.add_child(generation_modes)
	for label in ["Mock bridge · No AI", "Sample model · No AI", "Live AI · Uses credits"]:
		generation_modes.add_item(label)
	generation_modes.select(generation.mode)
	generation_modes.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	generation_modes.offset_left = -275
	generation_modes.offset_right = -28
	generation_modes.offset_top = 28
	generation_modes.offset_bottom = 58
	generation_modes.item_selected.connect(func(index: int):
		generation.configure(index)
		submit_button.text = "Generate · Uses credits" if index == 2 else "Submit drawing"
		status_label.text = "Live generation selected." if index == 2 else "Offline preview selected."
	)
	var sound_button := _button(root, "Sound: off" if get_node("/root/GameAudio").master_muted else "Sound: on", func():
		muted = not get_node("/root/GameAudio").master_muted
		get_node("/root/GameAudio").set_muted(muted)
	)
	sound_button.focus_mode = Control.FOCUS_NONE
	sound_button.pressed.connect(func(): sound_button.text = "Sound: off" if muted else "Sound: on")
	sound_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sound_button.offset_left = -180
	sound_button.offset_right = -28
	sound_button.offset_top = 86
	sound_button.offset_bottom = 130
	map_button = _button(root, "Back to map", _back_to_map)
	map_button.name = "BackToMap"
	map_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	map_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	map_button.offset_left = -180
	map_button.offset_right = -28
	map_button.offset_top = 144
	map_button.offset_bottom = 188
	status_label = _label(root, "Follow the path to the river.", 19)
	status_label.set_meta("narrator_guidance", status_label.text)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position += Vector2(28, -154)
	status_label.size = Vector2(690, 64)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("fff9ed"))
	status_label.add_theme_color_override("font_shadow_color", Color("273d36"))
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	controls = _label(root, "WASD / Arrows  Move    SPACE  Jump    SHIFT  Sprint\nFixed overhead view    E  Draw    ESC  Close panel", 14)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position += Vector2(28, -78)
	controls.add_theme_color_override("font_color", Color("fff9ed"))
	controls.add_theme_color_override("font_outline_color", Color("273d36"))
	controls.add_theme_constant_override("outline_size", 4)
	book = _button(root, "E · Draw", _open_book)
	book.focus_mode = Control.FOCUS_NONE
	book.icon = load("res://ui/pen.svg")
	book.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	book.offset_left = -310
	book.offset_right = -28
	book.offset_top = -92
	book.offset_bottom = -28
	book.add_theme_font_size_override("font_size", 20)
	drawing_shine = preload("res://ui/drawing_shine.gd").attach(book)
	cancel_button = _button(root, "Stop waiting", func():
		request.cancel()
		status_label.text = "Stopped waiting. Your drawing is saved." + (" The provider job may still be running." if generation.mode == 2 else "")
		_update_hud()
	)
	cancel_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	cancel_button.offset_left = -240
	cancel_button.offset_right = -28
	cancel_button.offset_top = -150
	cancel_button.offset_bottom = -102
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(modal)
	modal.hide()
	_build_drawing_overlay(ui_root)

func _build_drawing_overlay(root: Control) -> void:
	drawing_overlay = Control.new()
	drawing_overlay.name = "SceneDrawingOverlay"
	drawing_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(drawing_overlay)
	surface = DrawingSurface.new()
	surface.name = "DrawingSurface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_default_cursor_shape = Control.CURSOR_CROSS
	drawing_overlay.add_child(surface)
	drawing_toolbar = PanelContainer.new()
	drawing_toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	drawing_toolbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	drawing_toolbar.offset_left = 20
	drawing_toolbar.offset_right = -20
	drawing_toolbar.offset_top = -150
	drawing_toolbar.offset_bottom = -20
	drawing_toolbar.add_theme_stylebox_override("panel", _paper_style())
	drawing_overlay.add_child(drawing_toolbar)
	surface.excluded_control = drawing_toolbar
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	drawing_toolbar.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	drawing_hint = _label(heading, "Draw over the scene. Submit when ready.", 16)
	drawing_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawing_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices = OptionButton.new()
	for choice in ["NO AI · Test bridge", "NO AI · Unsuitable", "NO AI · Unclear", "NO AI · Service failure"]:
		choices.add_item(choice)
	heading.add_child(choices)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	stack.add_child(buttons)
	undo_button = _button(buttons, "Undo", func(): surface.undo())
	clear_button = _button(buttons, "Clear", func(): surface.clear())
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	drawing_cancel = _button(buttons, "Cancel · Esc", func(): _close_panel(true))
	submit_button = _button(buttons, "Submit drawing", _submit)
	surface.changed.connect(func():
		submit_button.disabled = not surface.has_drawing()
		undo_button.disabled = not surface.has_drawing()
		clear_button.disabled = not surface.has_drawing()
		if surface.has_drawing():
			drawing_hint.text = "Draw over the scene. Submit when ready."
	)
	drawing_overlay.hide()

func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f3ebda")
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func _play(cue: String) -> void:
	if cue in ["submit", "ready"]: return # Shared drawing feedback is handled by GameAudio.
	if muted or not is_instance_valid(audio):
		return
	audio.stream = tones[cue]
	audio.play()

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	tones.clear()

func _tone(cue: String) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var notes: Array = {"ready": [523.25, 659.25, 784.0], "bridge": [392.0, 523.25, 659.25, 784.0], "submit": [440.0, 523.25]}[cue]
	var samples := PackedByteArray()
	var note_samples := 2646
	samples.resize(note_samples * notes.size() * 2)
	for n in notes.size():
		for i in note_samples:
			var envelope := sin(PI * float(i) / note_samples) * 0.12
			var value := int(sin(TAU * notes[n] * i / stream.mix_rate) * envelope * 32767)
			samples.encode_s16((n * note_samples + i) * 2, value)
	stream.data = samples
	return stream
