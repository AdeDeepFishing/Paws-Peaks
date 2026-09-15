extends Control

## Shared chapter paper, with live Cormorant Upright text and a real keyboard CTA.
const FONT = preload("res://ui/title/cormorant_upright_semibold.ttf")
const BOLD = preload("res://ui/title/cormorant_upright_bold.ttf")
const TITLES := ["The Other Side", "A Growling Welcome", "Trouble Overhead", "A Friend by the Water", "Just One More Page"]
const NUMERALS := ["I", "II", "III", "IV", "V"]
var paper: TextureRect
var chapter: Label
var title: Label
var play: Button
var progress := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper = TextureRect.new()
	paper.texture = preload("res://ui/title/chapter_paper.svg")
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)
	chapter = label(30)
	chapter.add_theme_font_override("font", BOLD)
	title = label(56)
	play = Button.new()
	play.name = "Play"
	play.text = "Play"
	play.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	play.add_theme_font_override("font", BOLD)
	play.add_theme_font_size_override("font_size", 40)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var paint := StyleBoxTexture.new()
		paint.texture = preload("res://ui/title/play_paper.svg")
		paint.modulate_color = Color("ffc4a1") if state in ["hover", "focus"] else (Color("bba293") if state == "pressed" else Color.WHITE)
		play.add_theme_stylebox_override(state, paint)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		play.add_theme_color_override(state, Color.WHITE)
	paper.add_child(play)
	resized.connect(_layout)
	_layout()

func label(font_size: int) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", Color("3b3c38"))
	paper.add_child(node)
	return node

func configure(stage: int, resume := false) -> void:
	chapter.text = "Chapter " + NUMERALS[stage - 1]
	title.text = TITLES[stage - 1]
	play.text = "Return" if resume else "Play"

func set_progress(value: float) -> void:
	progress = value
	if paper != null:
		paper.position.y = size.y - paper.size.y * progress

func _layout() -> void:
	if paper == null: return
	var factor := minf(size.x / 1280.0, size.y / 800.0)
	var height := 341.0 * factor
	paper.position = Vector2(0, size.y - height * progress)
	paper.size = Vector2(size.x, height)
	chapter.position = Vector2(0, height * .19)
	chapter.size = Vector2(size.x, 40 * factor)
	title.position = Vector2(0, height * .32)
	title.size = Vector2(size.x, 74 * factor)
	chapter.add_theme_font_size_override("font_size", maxi(16, roundi(30 * factor)))
	title.add_theme_font_size_override("font_size", maxi(24, roundi(56 * factor)))
	play.size = Vector2(202, 92) * factor
	play.position = Vector2((size.x - play.size.x) * .5, height * .63)
	play.add_theme_font_size_override("font_size", maxi(20, roundi(40 * factor)))
