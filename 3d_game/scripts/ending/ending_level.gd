extends "res://scripts/woodland/woodland_level.gd"

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "EndingHUD"
	add_child(hud)
	hud_root = Control.new()
	hud.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(14)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 18
	paper.content_margin_bottom = 18
	var card := PanelContainer.new()
	card.position = Vector2(28, 28)
	card.add_theme_stylebox_override("panel", paper)
	hud_root.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	_label(stack, "PAWS & PEAKS  /  THE END", 14)
	_label(stack, stage_title, 32)
	objective = _label(stack, "Thank you for playing Paws & Peaks.", 16)
	_label(stack, "Made by Four Otters", 14)
	var navigation := VBoxContainer.new()
	hud_root.add_child(navigation)
	navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	navigation.offset_left = -240
	navigation.offset_right = -28
	navigation.offset_top = 28
	navigation.add_theme_constant_override("separation", 10)
	_navigation_button(navigation, "RestartButton", "Play again", "res://scenes/river/river_crossing.tscn", paper)
	_navigation_button(navigation, "BackButton", return_label, return_scene, paper)
	status = _label(hud_root, "Stay a while. A new day is beginning.", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position += Vector2(28, -52)
	status.add_theme_color_override("font_color", Color("fff9ed"))
	status.add_theme_color_override("font_outline_color", Color("273d36"))
	status.add_theme_constant_override("outline_size", 4)
