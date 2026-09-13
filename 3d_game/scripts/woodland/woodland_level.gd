extends Node3D

## Shared environment preview controller; encounter rules remain scene-specific work.
@export var art_path: NodePath = ^"Stage02Art"
@export var authored_camera_name := "Reference_composition_camera"
@export var chapter := "02"
@export var stage_title := "Woodland Path"
@export var fallback_spawn := Vector3(0, 2, 5)
@export var camera_pullback := 6.0
@export var return_scene := "res://scenes/river/river_crossing.tscn"
@export var return_label := "Back to river"

@onready var player = $Player
@onready var camera: Camera3D = $StageCamera
var spawn := Vector3(0, 2, 5)
var reference: Transform3D
var status: Label
var objective: Label
var hud_root: Control
var draw_button: Button
var drawing_shine: Control

func _ready() -> void:
	var art := get_node(art_path)
	var authored: Camera3D = art.find_child(authored_camera_name, true, false)
	if authored:
		camera.global_transform = authored.global_transform
		camera.projection = authored.projection
		camera.fov = authored.fov
		camera.keep_aspect = authored.keep_aspect
		camera.near = authored.near
		camera.far = authored.far
		authored.current = false
	camera.make_current()
	# The art camera frames scenery; pull back to include the playable hiker.
	camera.position += camera.basis.z * camera_pullback
	reference = camera.transform
	spawn = fallback_spawn
	var marker: Node3D = art.find_child("Player_spawn", true, false)
	if marker: spawn = marker.global_position + Vector3.UP * 2
	player.respawn(spawn)
	_build_ui()

func _process(delta: float) -> void:
	if player.position.y < -4:
		player.respawn(spawn)
		status.text = "Back on the path."
	# Preserve the designer's lens and orientation; track only ground movement.
	var offset: Vector3 = player.position - spawn
	offset.y = 0
	camera.position = camera.position.lerp(reference.origin + offset, 1.0 - exp(-delta * 4.0))

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	hud_root = root
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
	_label(stack, "PAWS & PEAKS  /  CHAPTER " + chapter, 14)
	_label(stack, stage_title, 28)
	objective = _label(stack, "Explore the path · Scene preview", 16)
	status = _label(root, "WASD / Arrows  Move    SPACE  Jump    SHIFT  Sprint", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position += Vector2(28,-52)
	status.add_theme_color_override("font_color", Color("fff9ed"))
	status.add_theme_color_override("font_outline_color", Color("273d36"))
	status.add_theme_constant_override("outline_size", 4)
	var navigation := VBoxContainer.new()
	navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	navigation.offset_left = -240
	navigation.offset_right = -28
	navigation.offset_top = 28
	navigation.add_theme_constant_override("separation", 10)
	root.add_child(navigation)
	_navigation_button(navigation, "BackButton", return_label, return_scene, paper)
	draw_button = Button.new()
	draw_button.text = "E · Draw"
	draw_button.icon = load("res://ui/pen.svg")
	draw_button.disabled = true
	draw_button.tooltip_text = "There is no drawing challenge in this preview yet."
	root.add_child(draw_button)
	draw_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	draw_button.offset_left = -240
	draw_button.offset_right = -28
	draw_button.offset_top = -108
	draw_button.offset_bottom = -52
	draw_button.add_theme_stylebox_override("normal", paper)
	draw_button.add_theme_font_size_override("font_size", 20)
	draw_button.add_theme_color_override("font_color", Color("273d36"))
	drawing_shine = preload("res://ui/drawing_shine.gd").attach(draw_button)

func _navigation_button(parent: Node, node_name: String, text: String, scene: String, paper: StyleBoxFlat) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_stylebox_override("normal", paper)
	button.add_theme_color_override("font_color", Color("273d36"))
	parent.add_child(button)
	button.pressed.connect(func():
		get_tree().current_scene = self
		get_tree().change_scene_to_file(scene)
	)

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("273d36"))
	parent.add_child(label)
	return label
