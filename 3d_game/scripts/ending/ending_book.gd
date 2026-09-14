extends Control

## A single, responsive storybook spread. Numbers come from the current session.
signal replay_requested
signal explore_requested

const INK := Color("294a43")
const GOLD := Color("b4955d")
const SIZE := Vector2(1000, 590)
var ending_title: Label
var ending_subtitle: Label
var conclusion: Label
var photo: TextureRect
var replay: Button
var explore: Button
var content: Control
var chapters_value: Label
var sketches_value: Label
var chapter_marks: Array[int] = []
var end_page: Control
var end_paper: TextureRect
var end_footer: ColorRect
var memories: Button
var memory_back: Button
var memory_replay: Button
var memory_explore: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	content = Control.new()
	content.size = SIZE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	content.draw.connect(_draw_book)
	_build_pages()
	_build_end_page()
	resized.connect(_fit)
	_fit()

func _fit() -> void:
	if content == null: return
	var factor := minf((size.x - 48.0) / SIZE.x, (size.y - 58.0) / SIZE.y)
	factor = maxf(0.1, factor)
	content.scale = Vector2.ONE * factor
	content.position = (size - SIZE * factor) * 0.5
	if end_paper != null:
		var scale_factor := minf(size.x / 1280.0, size.y / 800.0)
		var height := 355.0 * scale_factor
		end_paper.size = Vector2(size.x, height)
		end_paper.position = Vector2(0, size.y - height - 64 * scale_factor)
		end_footer.position = Vector2(0, size.y - 64 * scale_factor - 1)
		end_footer.size = Vector2(size.x, 64 * scale_factor + 1)
		var buttons := [memories, replay, explore]
		for i in buttons.size():
			buttons[i].position = Vector2(size.x * .5 + (i - 1) * 218 * scale_factor - 100 * scale_factor, height + 2 * scale_factor)
			buttons[i].size = Vector2(200, 50) * scale_factor
			buttons[i].add_theme_font_size_override("font_size", maxi(15, roundi(25 * scale_factor)))


func _build_end_page() -> void:
	memory_replay = replay
	memory_explore = explore
	end_page = Control.new()
	end_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(end_page)
	end_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_paper = TextureRect.new()
	end_paper.texture = preload("res://ui/title/ending_reference.svg")
	end_paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	end_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_footer = ColorRect.new()
	end_footer.color = Color("e8cca3")
	end_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_page.add_child(end_footer)
	end_page.add_child(end_paper)
	memories = _end_button("Your journey")
	replay = _end_button("Play again")
	explore = _end_button("Stay a while")
	replay.pressed.connect(func(): replay_requested.emit())
	explore.pressed.connect(func(): explore_requested.emit())
	memories.pressed.connect(func():
		end_page.hide()
		content.show()
		memory_back.grab_focus()
	)
	memory_back = _button("BackToEnd", "Back", Vector2(22, 14), Vector2(76, 30), false)
	memory_back.pressed.connect(show_end_page)
	visibility_changed.connect(func():
		if visible: show_end_page()
	)
	show_end_page()

func _end_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", preload("res://ui/title/cormorant.ttf"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var paint := StyleBoxTexture.new()
		paint.texture = preload("res://ui/title/play_paper.svg")
		paint.modulate_color = Color("ffc4a1") if state in ["hover", "focus"] else Color.WHITE
		button.add_theme_stylebox_override(state, paint)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	end_paper.add_child(button)
	return button

func show_end_page() -> void:
	content.hide()
	end_page.show()
	if is_visible_in_tree() and not replay.disabled: replay.grab_focus()

func set_actions_enabled(value: bool) -> void:
	for button in [replay, explore, memories, memory_replay, memory_explore, memory_back]:
		button.disabled = not value

func _label_at(text: String, at: Vector2, bounds: Vector2, font_size: int, serif: bool = false, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = bounds
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if serif:
		label.add_theme_font_override("font", preload("res://ui/title/cormorant.ttf"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func _build_pages() -> void:
	_label_at("T H E   T A L E   W E   D R A W", Vector2(62, 45), Vector2(400, 22), 13)
	photo = TextureRect.new()
	photo.position = Vector2(62, 92)
	photo.size = Vector2(400, 330)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ending/keepsake.gdshader")
	photo.material = material
	content.add_child(photo)
	ending_title = _label_at("A New Dawn", Vector2(62, 440), Vector2(400, 46), 31, true)
	ending_subtitle = _label_at("Every little drawing left a little light.", Vector2(62, 489), Vector2(400, 26), 15)
	_label_at("THE JOURNEY, REMEMBERED", Vector2(62, 554), Vector2(400, 22), 10, false, Color("857b65"))
	_label_at("T H E   L A S T   P A G E", Vector2(532, 45), Vector2(410, 22), 12, false, Color("857b65"))
	_label_at("Journey\ncomplete.", Vector2(532, 177), Vector2(410, 116), 46, true)
	conclusion = _label_at("A few small drawings.\nA world of possibilities.", Vector2(548, 307), Vector2(378, 52), 17)
	chapters_value = _label_at("0 / 5", Vector2(567, 382), Vector2(150, 32), 25, true)
	sketches_value = _label_at("0", Vector2(757, 382), Vector2(150, 32), 25, true)
	_label_at("CHAPTERS VISITED", Vector2(567, 417), Vector2(150, 22), 10, false, Color("857b65"))
	_label_at("SKETCHES SHARED", Vector2(757, 417), Vector2(150, 22), 10, false, Color("857b65"))
	replay = _button("RestartButton", "Begin a new journey  →", Vector2(568, 463), Vector2(338, 47), true)
	replay.pressed.connect(func(): replay_requested.emit())
	explore = _button("ExploreButton", "Stay in the dawn", Vector2(568, 517), Vector2(338, 32), false)
	explore.pressed.connect(func(): explore_requested.emit())
	_label_at("WITH LOVE, FOUR OTTERS", Vector2(532, 555), Vector2(410, 20), 10, false, Color("857b65"))

func _button(node_name: String, text: String, at: Vector2, bounds: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.position = at
	button.size = bounds
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17 if primary else 14)
	var style := StyleBoxFlat.new()
	style.bg_color = INK if primary else Color(0, 0, 0, 0)
	style.set_corner_radius_all(8)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color("3d6256") if primary else Color(0.5, 0.45, 0.3, 0.1)
	button.add_theme_stylebox_override("hover", hover)
	var press := style.duplicate()
	press.bg_color = Color("203a35") if primary else Color(0.5, 0.45, 0.3, 0.16)
	button.add_theme_stylebox_override("pressed", press)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = GOLD
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(8)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color("fff3d9") if primary else INK)
	content.add_child(button)
	return button

func set_memory(texture: Texture2D, chapters: Array[int], sketches: int) -> void:
	photo.texture = texture
	chapter_marks = chapters.duplicate()
	chapters_value.text = "%d / 5" % chapters.size()
	sketches_value.text = str(sketches)
	content.queue_redraw()

func _draw_book() -> void:
	# A cloth cover, stacked page edges and a shaded gutter give the spread depth.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color("233f39")
	shadow.set_corner_radius_all(14)
	shadow.shadow_color = Color(0.02, 0.04, 0.06, 0.44)
	shadow.shadow_size = 30
	shadow.shadow_offset = Vector2(0, 18)
	content.draw_style_box(shadow, Rect2(Vector2(-10, 1), SIZE + Vector2(20, 14)))
	for i in range(4, 0, -1):
		var edge := StyleBoxFlat.new()
		edge.bg_color = Color("d7c6a6") if i % 2 == 0 else Color("ebe0c9")
		edge.set_corner_radius_all(8)
		content.draw_style_box(edge, Rect2(Vector2(0, i * 2), SIZE))
	var page := StyleBoxFlat.new()
	page.bg_color = Color("f4ecd9")
	page.set_corner_radius_all(8)
	content.draw_style_box(page, Rect2(Vector2.ZERO, SIZE))
	content.draw_rect(Rect2(16, 18, 968, 551), Color("d8c9aa"), false, 1.0)
	for i in 35:
		var alpha := pow(1.0 - float(i) / 35.0, 2) * 0.13
		content.draw_line(Vector2(500 - i, 7), Vector2(500 - i, 583), Color(0.26, 0.23, 0.17, alpha))
		content.draw_line(Vector2(500 + i, 7), Vector2(500 + i, 583), Color(0.26, 0.23, 0.17, alpha * 0.7))
	content.draw_line(Vector2(500, 8), Vector2(500, 582), Color("cabc9e"), 1.0)
	content.draw_rect(Rect2(57, 87, 410, 340), GOLD, false, 1.0)
	# Small route stamps reflect the chapters actually visited in this run.
	content.draw_line(Vector2(164, 535), Vector2(360, 535), Color("cbbb99"), 1.0)
	for i in 5:
		var point := Vector2(164 + i * 49, 535)
		content.draw_circle(point, 5.0, GOLD if i + 1 in chapter_marks else Color("dfd3bb"))
		if i + 1 in chapter_marks: content.draw_circle(point, 2.0, Color("f8f0dd"))
	# A quiet victory seal, with a hand-drawn sprig on each side.
	var center := Vector2(737, 126)
	content.draw_arc(center, 37, 0, TAU, 80, Color("d7c39b"), 1.0, true)
	_star(center, 24, 7, GOLD)
	for side in [-1, 1]:
		var points := PackedVector2Array()
		for i in 14:
			var angle := -0.8 + float(i) / 13.0 * 1.6
			points.append(center + Vector2(side * (46 + cos(angle) * 9), sin(angle) * 38))
		content.draw_polyline(points, GOLD, 1.4, true)
		for i in 5:
			var p := center + Vector2(side * 53, -26 + i * 13)
			content.draw_colored_polygon(PackedVector2Array([p, p + Vector2(side * 12, -10), p + Vector2(side * 8, 1), p + Vector2(0, 5)]), Color("acb492"))
	content.draw_line(Vector2(574, 369), Vector2(900, 369), Color("d8c9aa"), 1.0)
	content.draw_line(Vector2(737, 387), Vector2(737, 432), Color("d8c9aa"), 1.0)
	# The bookmark is attached to the book, not a floating UI decoration.
	content.draw_colored_polygon(PackedVector2Array([Vector2(940, 0), Vector2(961, 0), Vector2(961, 64), Vector2(950, 56), Vector2(940, 64)]), Color("9b725a"))

func _star(center: Vector2, outer: float, inner: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := i * TAU / 8.0 - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * (outer if i % 2 == 0 else inner))
	content.draw_colored_polygon(points, color)

func set_stay_ending() -> void:
	ending_title.text = "A Place to Stay"
	ending_subtitle.text = "You chose a place in this story."
	conclusion.text = "An ending freely chosen.\nA world to remember."
	explore.text = "Look around"
	memory_explore.text = "Look around this memory"
