extends Label

## Wrap first, then show the latest three rendered lines, including long words.
var previous_text := ""
var previous_size := Vector2.ZERO

func _init() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	max_lines_visible = 3
	clip_text = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color", Color("383c3b"))
	add_theme_font_size_override("font_size", 20)

func _process(_delta: float) -> void:
	if text != previous_text or size != previous_size:
		previous_text = text
		previous_size = size
		max_lines_visible = clampi(floori(size.y / maxf(1, get_line_height() + get_theme_constant("line_spacing"))), 1, 3)
		lines_skipped = maxi(0, get_line_count() - max_lines_visible)
