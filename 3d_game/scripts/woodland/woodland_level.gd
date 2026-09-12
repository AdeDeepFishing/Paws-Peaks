extends Node3D

@onready var player = $Player
@onready var camera: Camera3D = $StageCamera
var spawn := Vector3(0, 2, 5)
var reference: Transform3D
var status: Label

func _ready() -> void:
	var authored: Camera3D = $Stage02Art.find_child("Reference_composition_camera", true, false)
	if authored:
		camera.global_transform = authored.global_transform
		camera.projection = authored.projection
		camera.fov = authored.fov
		camera.keep_aspect = authored.keep_aspect
		authored.current = false
	camera.make_current()
	# The art camera frames scenery; pull back to include the playable hiker.
	camera.position += camera.basis.z * 6.0
	reference = camera.transform
	var marker: Node3D = $Stage02Art.find_child("Player_spawn", true, false)
	if marker: spawn = marker.global_position + Vector3.UP * 2
	player.respawn(spawn)
	_build_ui()

func _process(delta: float) -> void:
	if player.position.y < -4:
		player.respawn(spawn)
		status.text = "Back on the woodland path."
	# Preserve the designer's lens and orientation; track only ground movement.
	var offset: Vector3 = player.position - spawn
	offset.y = 0
	camera.position = camera.position.lerp(reference.origin + offset, 1.0 - exp(-delta * 4.0))

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(root)
	var card := PanelContainer.new()
	card.position = Vector2(28,28)
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(14)
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 14
	paper.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", paper)
	root.add_child(card)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	_label(stack, "PAWS & PEAKS  /  CHAPTER 02", 14)
	_label(stack, "Woodland Path", 28)
	_label(stack, "Explore the path · Scene preview", 16)
	status = _label(root, "WASD / Arrows  Move    SPACE  Jump    SHIFT  Sprint", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position += Vector2(28,-52)
	status.add_theme_color_override("font_color", Color("fff9ed"))
	status.add_theme_color_override("font_outline_color", Color("273d36"))
	status.add_theme_constant_override("outline_size", 4)
	var back := Button.new()
	back.text = "Back to river"
	back.add_theme_stylebox_override("normal", paper)
	back.add_theme_color_override("font_color", Color("273d36"))
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -180
	back.offset_right = -28
	back.offset_top = 28
	back.offset_bottom = 74
	root.add_child(back)
	back.pressed.connect(func():
		get_tree().current_scene = self
		get_tree().change_scene_to_file("res://scenes/river/river_crossing.tscn")
	)

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("273d36"))
	parent.add_child(label)
	return label
