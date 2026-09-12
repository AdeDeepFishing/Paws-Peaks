extends Node3D

const DrawingSurface = preload("res://scripts/river/drawing_surface.gd")
const SPAWN := Vector3(-6.3, 1.5, -6.3)
const CROSSING := Vector3(-4.6, 1.3, -6.3)

@onready var player = $Player
@onready var request = $DrawingRequest
@onready var bridge: Node3D = $Bridge

var drawing_export_directory := "user://drawings"

var unlocked := false
var bridge_built := false
var completed := false
var collected: Dictionary = {}
var current_item: Dictionary = {}
var current_png := PackedByteArray()
var panel_mode := ""
var muted := false
var panel_tween: Tween

var hud: CanvasLayer
var title: Label
var objective: Label
var coins_label: Label
var status_label: Label
var book: Button
var controls: Label
var modal: Control
var panel: PanelContainer
var panel_title: Label
var panel_description: Label
var surface: Control
var book_preview: Control
var preview: TextureRect
var info: Label
var choices: OptionButton
var undo_button: Button
var clear_button: Button
var submit_button: Button
var use_button: Button
var redraw_button: Button
var previous_button: Button
var cancel_button: Button
var close_button: Button
var restart_button: Button
var audio: AudioStreamPlayer
var tones: Dictionary = {}

func _ready() -> void:
	_build_ui()
	audio = AudioStreamPlayer.new()
	add_child(audio)
	for cue in ["coin", "ready", "bridge", "submit"]:
		tones[cue] = _tone(cue)
	$DrawingArea.body_entered.connect(_on_drawing_area)
	request.state_changed.connect(_on_request_state)
	for coin in $Coins.get_children():
		coin.body_entered.connect(_on_coin.bind(coin))
	_update_hud()

func _process(delta: float) -> void:
	for coin in $Coins.get_children():
		if coin.visible:
			coin.get_node("Visual").rotate_y(delta * 1.4)
	if player.position.y < 0.35:
		player.respawn(SPAWN)
		status_label.text = "Back on dry land. Your drawing and coins are safe."
	if bridge_built and not completed and player.position.x > 5.8 and player.is_on_floor():
		_finish()
	if panel_mode == "result":
		use_button.disabled = not can_build_bridge()
		if not near_crossing() and _supports_bridge() and not bridge_built:
			info.text = _item_text() + "\n\nReturn to the drawing post on the near bank to use this idea."
		else:
			info.text = _item_text()
	if request.state == "PENDING":
		book.text = "SKETCHBOOK\nThinking...  /  E"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and unlocked and not completed:
			if modal.visible:
				_close_panel(true)
			else:
				_open_book()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE:
			if modal.visible and not completed:
				_close_panel(false)
			else:
				player.set_input_enabled(true)
			get_viewport().set_input_as_handled()

func _on_drawing_area(body: Node3D) -> void:
	if body != player or unlocked:
		return
	unlocked = true
	status_label.text = "The river is too wide to jump. Could you draw a way across?"
	_update_hud()

func _on_coin(body: Node3D, coin: Area3D) -> void:
	if body != player or collected.has(coin.name):
		return
	collected[coin.name] = true
	coin.hide()
	_play("coin")
	_update_hud()

func _open_book() -> void:
	if not player.is_on_floor():
		status_label.text = "Land on solid ground before opening your sketchbook."
		return
	if request.state == "PENDING":
		_show_panel("pending")
	elif request.state == "READY" and not bridge_built:
		_show_panel("result")
	else:
		_show_panel("draw")

func _show_panel(mode: String) -> void:
	panel_mode = mode
	player.set_input_enabled(false)
	modal.show()
	surface.visible = mode == "draw"
	preview.visible = mode != "draw"
	var image := Image.new()
	var bytes: PackedByteArray = request.snapshot if mode == "pending" else current_png
	if not bytes.is_empty() and image.load_png_from_buffer(bytes) == OK:
		image.convert(Image.FORMAT_RGBA8)
		preview.texture = ImageTexture.create_from_image(image)
	else:
		preview.texture = null
	choices.visible = mode == "draw" and request.mock_mode
	undo_button.visible = mode == "draw"
	clear_button.visible = mode == "draw"
	submit_button.visible = mode == "draw"
	use_button.visible = mode == "result"
	redraw_button.visible = mode == "result"
	previous_button.visible = mode == "draw" and not current_item.is_empty() and not bridge_built
	cancel_button.visible = mode == "pending"
	close_button.visible = mode != "complete"
	restart_button.visible = mode == "complete"
	submit_button.disabled = not surface.has_drawing()
	match mode:
		"draw":
			panel_title.text = "A little ink. A new possibility."
			panel_description.text = "Draw something long and sturdy to help you cross the river."
			info.text = "Your sketch will become a paper idea in the world.\n\n" + ("PROTOTYPE · NO AI\nChoose a simulated response below. This does not recognize your drawing." if request.mock_mode else "Submit your sketch for interpretation.")
			if request.state == "FAILED":
				info.text += "\n\n" + request.message
		"result":
			panel_title.text = "Your idea is ready."
			panel_description.text = "A drawing, a little imagination, and a way forward."
			info.text = _item_text()
			use_button.disabled = not can_build_bridge()
		"pending":
			panel_title.text = "Finding the idea in your drawing..."
			panel_description.text = "You can close this book and explore while you wait."
			info.text = "Your submitted sketch is safe.\n\nA small notification will appear when it is ready.\n\n" + ("PROTOTYPE · Simulated response" if request.mock_mode else "Waiting for the drawing service")
		"complete":
			panel_title.text = "You drew a way forward."
			panel_description.text = "Across the River · Complete"
			info.text = "A little ink carried you a long way.\n\nCoins collected: %d / %d\n\nThis is the end of the first-stage prototype. The next four encounters are still to come." % [collected.size(), $Coins.get_child_count()]
	if panel_tween:
		panel_tween.kill()
	panel.modulate.a = 0.0
	panel_tween = create_tween()
	panel_tween.tween_property(panel, "modulate:a", 1.0, 0.16)
	close_button.grab_focus() if mode != "complete" else restart_button.grab_focus()

func _close_panel(_resume: bool) -> void:
	surface.drawing = false
	book_preview.strokes = surface.strokes.duplicate(true)
	book_preview.queue_redraw()
	modal.hide()
	panel_mode = ""
	player.set_input_enabled(true)

func _submit() -> void:
	var png: PackedByteArray = surface.snapshot_png()
	if not request.submit(png, "E01", choices.selected):
		info.text = "Draw something first, and finish or cancel any pending request."
		return
	var saved_path := _save_drawing(png)
	_close_panel(true)
	if saved_path.is_empty():
		status_label.text = "Drawing submitted, but the local PNG could not be saved."
	_play("submit")

func _save_drawing(png: PackedByteArray) -> String:
	if DirAccess.make_dir_recursive_absolute(drawing_export_directory) != OK:
		push_warning("Could not create the drawing export directory.")
		return ""
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var stem := "E01-%s-%s" % [timestamp, Crypto.new().generate_random_bytes(8).hex_encode()]
	var path := drawing_export_directory.path_join(stem + ".png")
	var suffix := 1
	while FileAccess.file_exists(path):
		path = drawing_export_directory.path_join("%s-%d.png" % [stem, suffix])
		suffix += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not open the drawing export file: " + path)
		return ""
	file.store_buffer(png)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		push_warning("Could not finish saving the drawing: " + path)
		return ""
	print("Drawing saved: " + ProjectSettings.globalize_path(path))
	return path

func _on_request_state(state: String) -> void:
	match state:
		"PENDING":
			status_label.text = "Finding the idea in your drawing... Explore while you wait."
		"READY":
			current_item = request.result.duplicate(true)
			current_png = request.snapshot.duplicate()
			status_label.text = "Your drawing is ready. Press E to take a look."
			_play("ready")
		"FAILED":
			status_label.text = request.message + "  E · Open sketchbook"
	if modal.visible and panel_mode == "pending" and state in ["READY", "FAILED"]:
		info.text = "Your result is ready. Close and reopen the book when you want to inspect it." if state == "READY" else request.message
		cancel_button.hide()
	_update_hud()

func near_crossing() -> bool:
	return Vector2(player.position.x - CROSSING.x, player.position.z - CROSSING.z).length() <= 3.0 and player.position.x < -2.5

func _supports_bridge() -> bool:
	var tags: Array = current_item.get("tags", [])
	return "LONG_REACH" in tags and "STURDY" in tags and current_item.get("durability", 0) > 0

func can_build_bridge() -> bool:
	return not bridge_built and _supports_bridge() and near_crossing() and player.is_on_floor()

func build_bridge() -> bool:
	if not can_build_bridge():
		return false
	bridge_built = true
	current_item["durability"] -= 1
	bridge.show()
	$Bridge/Deck/CollisionShape3D.set_deferred("disabled", false)
	var image := Image.new()
	if image.load_png_from_buffer(current_png) == OK:
		image.convert(Image.FORMAT_RGBA8)
		$Bridge/Sketch.texture = ImageTexture.create_from_image(image)
	status_label.text = "Your idea became a bridge. Walk across to the far bank!"
	_close_panel(true)
	_play("bridge")
	_update_hud()
	return true

func _item_text() -> String:
	if current_item.is_empty():
		return "No idea is ready yet."
	var item := current_item
	var result_text := "%s\n%s\n\nType: %s\nAttack power: %s\nRange: %s\nSpeed: %s\nDurability: %s\n\n" % [item.name, item.description, item.type, item.attack_power, item.range, item.speed, item.durability]
	result_text += "This can support a bridge. Use it at the river to make a way across." if _supports_bridge() else "This idea cannot support a crossing yet. Try something long and sturdy."
	return result_text

func _finish() -> void:
	completed = true
	_update_hud()
	_play("bridge")
	_show_panel("complete")

func restart() -> void:
	request.reset()
	surface.clear()
	current_item = {}
	current_png = PackedByteArray()
	collected.clear()
	unlocked = false
	completed = false
	bridge_built = false
	bridge.hide()
	$Bridge/Deck/CollisionShape3D.set_deferred("disabled", true)
	for coin in $Coins.get_children():
		coin.show()
	player.respawn(SPAWN)
	status_label.text = "Follow the pink path to the river."
	_close_panel(true)
	_update_hud()

func _update_hud() -> void:
	coins_label.text = "COINS  %02d / %02d" % [collected.size(), $Coins.get_child_count()]
	book.visible = unlocked and not completed and not bridge_built
	book.text = "SKETCHBOOK\nE · " + ("View your idea" if request.state == "READY" else "Open & draw")
	objective.text = "Walk across your bridge." if bridge_built else "Find a way across the river."

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
	coins_label = _label(root, "", 18)
	coins_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	coins_label.offset_left = -240
	coins_label.offset_right = -28
	coins_label.offset_top = 36
	coins_label.offset_bottom = 64
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mock_label := _label(root, "PROTOTYPE · NO AI" if request.mock_mode else "LIVE INTERPRETATION", 14)
	mock_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mock_label.offset_left = -240
	mock_label.offset_right = -28
	mock_label.offset_top = 70
	mock_label.offset_bottom = 94
	mock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [coins_label, mock_label]:
		label.add_theme_color_override("font_color", Color("fff9ed"))
		label.add_theme_color_override("font_outline_color", Color("273d36"))
		label.add_theme_constant_override("outline_size", 4)
	var sound_button := _button(root, "Sound: on", func():
		muted = not muted
	)
	sound_button.pressed.connect(func(): sound_button.text = "Sound: off" if muted else "Sound: on")
	sound_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sound_button.offset_left = -180
	sound_button.offset_right = -28
	sound_button.offset_top = 102
	sound_button.offset_bottom = 146
	status_label = _label(root, "Follow the pink path to the river.", 19)
	status_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status_label.position += Vector2(28, -132)
	status_label.size = Vector2(690, 64)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("fff9ed"))
	status_label.add_theme_color_override("font_shadow_color", Color("273d36"))
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 2)
	controls = _label(root, "WASD / Arrows  Move    SPACE  Jump    SHIFT  Sprint\nFixed overhead view    E  Sketchbook    ESC  Close panel", 14)
	controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	controls.position += Vector2(28, -56)
	controls.add_theme_color_override("font_color", Color("fff9ed"))
	controls.add_theme_color_override("font_outline_color", Color("273d36"))
	controls.add_theme_constant_override("outline_size", 4)
	book = _button(root, "SKETCHBOOK\nE · Open & draw", _open_book)
	book.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	book.offset_left = -328
	book.offset_right = -28
	book.offset_top = -140
	book.offset_bottom = -28
	book.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	book.add_theme_font_size_override("font_size", 20)
	book_preview = DrawingSurface.new()
	book_preview.position = Vector2(16, 18)
	book_preview.size = Vector2(76, 76)
	book_preview.modulate = Color("e4e7d5")
	book.add_child(book_preview)
	book_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.07, 0.13, 0.13, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -324
	panel.offset_bottom = 324
	panel.add_theme_stylebox_override("panel", _paper_style())
	modal.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	panel_title = _label(content, "", 27)
	panel_description = _label(content, "", 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	content.add_child(row)
	var square := Control.new()
	square.custom_minimum_size = Vector2(512, 512)
	row.add_child(square)
	surface = DrawingSurface.new()
	surface.name = "DrawingSurface"
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	square.add_child(surface)
	surface.changed.connect(func(): submit_button.disabled = not surface.has_drawing())
	preview = TextureRect.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	square.add_child(preview)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 340
	side.add_theme_constant_override("separation", 8)
	row.add_child(side)
	var info_scroll := ScrollContainer.new()
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(info_scroll)
	info = _label(info_scroll, "", 16)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices = OptionButton.new()
	for choice in ["Test: bridge", "Test: unsuitable idea", "Test: unclear drawing", "Test: service failure"]:
		choices.add_item(choice)
	side.add_child(choices)
	var tools_row := HBoxContainer.new()
	side.add_child(tools_row)
	undo_button = _button(tools_row, "Undo", func(): surface.undo())
	clear_button = _button(tools_row, "Clear", func(): surface.clear())
	submit_button = _button(side, "Submit drawing", _submit)
	use_button = _button(side, "Use idea · Build bridge", func(): build_bridge())
	redraw_button = _button(side, "Draw again", func(): _show_panel("draw"))
	previous_button = _button(side, "View previous idea", func(): _show_panel("result"))
	cancel_button = _button(side, "Cancel request", func():
		request.cancel()
		status_label.text = "Request canceled. Your drawing is still in the book."
		_show_panel("draw")
	)
	close_button = _button(side, "Close · E / Esc", func(): _close_panel(true))
	restart_button = _button(side, "Play again", restart)
	modal.hide()

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
	var notes: Array = {"coin": [784.0, 1046.5], "ready": [523.25, 659.25, 784.0], "bridge": [392.0, 523.25, 659.25, 784.0], "submit": [440.0, 523.25]}[cue]
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
