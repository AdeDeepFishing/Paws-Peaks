extends Control

var request: Node
var surface: Control
var active_id := ""
var submitted_rect := Rect2()
var submitted_viewport := Vector2.ONE
var world_camera: Camera3D
var world_anchor := Vector3.ZERO
var submitted_pixels_per_unit := 1.0
var image: TextureRect
var card: PanelContainer
var item_name: Label
var description: Label
var progress: Label

static func attach(parent: Node, drawing_request: Node, generation: Node, drawing_surface: Control) -> Control:
	var layer := CanvasLayer.new()
	layer.name = "GenerationPreviewLayer"
	layer.layer = 5
	parent.add_child(layer)
	var preview := preload("res://scripts/river/generation_preview.gd").new()
	layer.add_child(preview)
	preview.request = drawing_request
	preview.surface = drawing_surface
	drawing_request.request_prepared.connect(preview._begin)
	drawing_request.state_changed.connect(preview._on_state)
	generation.interpretation_ready.connect(preview._show_interpretation)
	generation.reference_image_ready.connect(preview._show_reference)
	return preview

func _ready() -> void:
	name = "GenerationPreview"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	image = TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(image)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("fff9edf5")
	paper.set_corner_radius_all(14)
	paper.content_margin_left = 20
	paper.content_margin_right = 20
	paper.content_margin_top = 14
	paper.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", paper)
	add_child(card)
	card.minimum_size_changed.connect(func(): _layout_card.call_deferred())
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)
	var heading := _label(stack, 12)
	heading.text = "YOUR DRAWING"
	heading.add_theme_color_override("font_color", Color("806544"))
	item_name = _label(stack, 24)
	description = _label(stack, 17)
	progress = _label(stack, 14)
	progress.add_theme_color_override("font_color", Color("806544"))
	resized.connect(_layout)
	_clear()

func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("273d36"))
	parent.add_child(label)
	return label

func _begin(payload: Dictionary) -> void:
	_clear()
	if request.state != "PENDING":
		return
	active_id = payload.request_id
	submitted_rect = surface.snapshot_screen_rect()
	submitted_viewport = get_viewport_rect().size
	var sketch := Image.new()
	if sketch.load_png_from_buffer(request.snapshot) == OK:
		image.texture = ImageTexture.create_from_image(sketch)
	image.modulate.a = 0.7
	show()
	_layout()

func _active(id: String) -> bool:
	return request.state == "PENDING" and request.active_id == id and active_id == id

func _show_interpretation(id: String, item: Dictionary) -> void:
	if not _active(id):
		return
	item_name.text = item.name
	description.text = item.description
	progress.text = "Giving your drawing shape…"
	card.show()
	_layout()

func _show_reference(id: String, path: String) -> void:
	if not _active(id):
		return
	var reference := Image.load_from_file(path)
	if reference == null or reference.is_empty():
		return
	image.texture = ImageTexture.create_from_image(reference)
	image.modulate.a = 0.9
	progress.text = "Bringing your object into the world…"
	_layout()

func anchor_to_world(camera: Camera3D, anchor: Vector3) -> void:
	world_camera = camera
	world_anchor = anchor
	submitted_pixels_per_unit = maxf(_pixels_per_unit(), 0.001)
	_layout()

func _pixels_per_unit() -> float:
	return world_camera.unproject_position(world_anchor).distance_to(
		world_camera.unproject_position(world_anchor + world_camera.global_basis.x))

func _process(_delta: float) -> void:
	if visible and is_instance_valid(world_camera):
		_layout_image()

func _layout_image() -> void:
	if is_instance_valid(world_camera):
		image.visible = not world_camera.is_position_behind(world_anchor)
		if not image.visible:
			return
		image.size = submitted_rect.size * _pixels_per_unit() / submitted_pixels_per_unit
		image.position = world_camera.unproject_position(world_anchor) - Vector2(image.size.x * 0.5, image.size.y)
	else:
		var viewport := get_viewport_rect().size
		var scale_factor := minf(viewport.x / submitted_viewport.x, viewport.y / submitted_viewport.y)
		image.position = submitted_rect.position * scale_factor + (viewport - submitted_viewport * scale_factor) * 0.5
		image.size = submitted_rect.size * scale_factor

func _layout() -> void:
	if not is_instance_valid(image):
		return
	var viewport := get_viewport_rect().size
	_layout_image()
	card.size.x = minf(420, maxf(160, viewport.x - 56))
	_layout_card.call_deferred()

func _layout_card() -> void:
	card.size.y = card.get_combined_minimum_size().y
	var viewport := get_viewport_rect().size
	card.position = Vector2(viewport.x - card.size.x - 28, maxf(155, viewport.y - 180 - card.size.y))

func model_presented() -> void:
	_clear()

func _on_state(state: String) -> void:
	if state == "READY":
		image.texture = null
		world_camera = null
		progress.text = "Your object is ready."
	elif state != "PENDING":
		_clear()

func _clear() -> void:
	active_id = ""
	world_camera = null
	image.show()
	image.texture = null
	item_name.text = ""
	description.text = ""
	progress.text = ""
	card.hide()
	hide()
