extends ColorRect

## A shared pearl-white challenge cue, drawn behind the button's readable ink.
const SHADER = preload("res://ui/drawing_shine.gdshader")
const STATES := ["normal", "hover", "pressed", "hover_pressed"]
var button: Button
var original_styles := {}
var original_colors := {}
var active := false

static func attach(target: Button) -> Control:
	var shine = load("res://ui/drawing_shine.gd").new()
	shine.button = target
	target.add_child(shine)
	return shine

func _ready() -> void:
	name = "DrawingShine"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = -18
	offset_top = -18
	offset_right = 18
	offset_bottom = 18
	var effect := ShaderMaterial.new()
	effect.shader = SHADER
	material = effect
	for state in STATES:
		original_styles[state] = button.get_theme_stylebox(state)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		original_colors[state] = button.get_theme_color(state)
	button.resized.connect(_resize)
	_resize()
	hide()

func _resize() -> void:
	material.set_shader_parameter("button_size", button.size)

func set_active(enabled: bool) -> void:
	if active == enabled:
		return
	active = enabled
	visible = enabled
	for state in STATES:
		if enabled:
			# Retain content margins so the label never moves when the cue appears.
			var empty := StyleBoxEmpty.new()
			for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				empty.set_content_margin(side, original_styles[state].get_content_margin(side))
			button.add_theme_stylebox_override(state, empty)
		else:
			button.add_theme_stylebox_override(state, original_styles[state])
	for state in original_colors:
		button.add_theme_color_override(state, Color("253c46") if enabled else original_colors[state])
