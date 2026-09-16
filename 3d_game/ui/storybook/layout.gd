extends RefCounted

const ArtButton = preload("res://ui/storybook/illustrated_button.gd")
const RollingLabel = preload("res://ui/storybook/rolling_label.gd")

static func tool(parent: Node, kind: String, action: Callable = Callable()) -> Button:
	var button := ArtButton.new(kind)
	parent.add_child(button)
	button.add_to_group("drawing_input_blocker")
	button.tooltip_text = {"pen": "Draw · E", "microphone": "Speak", "menu": "Menu", "cancel": "Cancel drawing · Esc", "confirm": "Submit drawing"}.get(kind, "")
	if action.is_valid(): button.pressed.connect(action)
	return button

static func corner(control: Control, top: float, bottom: float, width := 96.0) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	control.offset_left = -width - 48
	control.offset_right = -48
	control.offset_top = top
	control.offset_bottom = bottom

static func debug_control(control: Control, row: int) -> void:
	control.add_to_group("drawing_input_blocker")
	control.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	control.offset_left = -280
	control.offset_right = -40
	control.offset_top = 158 + row * 42
	control.offset_bottom = 194 + row * 42
	control.add_theme_font_size_override("font_size", 14)
	control.custom_minimum_size = Vector2.ZERO

static func paper(parent: Node, kind: String) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load("res://ui/storybook/dialogue_" + kind + ".png")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

static func toolbar(parent: Control, surface: Control, _cancel: Callable, submit: Callable) -> PanelContainer:
	var toolbar := PanelContainer.new()
	toolbar.name = "DrawingActions"
	parent.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toolbar.anchor_top = .86
	toolbar.anchor_bottom = .86
	toolbar.offset_left = -140
	toolbar.offset_right = 140
	toolbar.offset_top = -36
	toolbar.offset_bottom = 36
	toolbar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.name = "HBoxContainer"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 100)
	toolbar.add_child(row)
	var back := tool(row, "cancel", surface.clear)
	back.tooltip_text = "Clear drawing"
	back.name = "Cancel"
	back.custom_minimum_size = Vector2(72, 72)
	var send := tool(row, "confirm", submit)
	send.name = "Submit"
	send.custom_minimum_size = Vector2(72, 72)
	send.disabled = not surface.has_drawing()
	surface.changed.connect(func(): send.disabled = not surface.has_drawing())
	surface.excluded_control = toolbar
	return toolbar

static func drawing_tools(parent: Control, close_sketch: Callable) -> void:
	var pen := tool(parent, "pen", close_sketch)
	pen.name = "CloseSketch"
	pen.set_meta("closes_sketch", true)
	pen.disabled = false
	pen.tooltip_text = "Close sketch · E"
	corner(pen, -144, -48)
	var mic := tool(parent, "microphone")
	mic.name = "InactiveMicrophone"
	mic.disabled = true
	corner(mic, -144, -48)
	parent.visibility_changed.connect(func():
		var unlocked: bool = parent.get_node("/root/Journey").microphone_unlocked
		mic.visible = unlocked
		corner(pen, -256 if unlocked else -144, -160 if unlocked else -48)
	)
