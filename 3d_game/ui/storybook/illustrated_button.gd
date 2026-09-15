extends Button

## Painted states retain the normal Button input, focus and accessibility behavior.
var artwork: TextureRect
var textures: Array[Texture2D] = []
var kind := "pen"

func _init(art := "pen") -> void:
	kind = art
	clip_text = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(88, 88)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)

func _ready() -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var path: String = "res://ui/storybook/" + kind + "_" + state + ".png"
		if kind in ["cancel", "confirm"]: path = "res://ui/storybook/" + kind + ".png"
		textures.append(load(path))
	artwork = TextureRect.new()
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync()

# Painted hover artwork provides feedback without a floating text popup.
func _get_tooltip(_at_position: Vector2) -> String:
	return ""

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	if kind == "pen":
		var narrator = get_node_or_null("/root/Narrator")
		if not has_meta("closes_sketch") and narrator and (narrator.panel.opened or narrator.panel.revealing_boss): disabled = true
		var shine = get_node_or_null("DrawingShine")
		if shine: shine.visible = shine.active and not disabled
	text = ""
	icon = null
	var state := 3 if disabled else (2 if get_draw_mode() in [BaseButton.DRAW_PRESSED, BaseButton.DRAW_HOVER_PRESSED] else (1 if is_hovered() or has_focus() else 0))
	artwork.texture = textures[state]
	artwork.modulate = Color(1, 1, 1, 0.4) if disabled and kind in ["cancel", "confirm"] else Color.WHITE
