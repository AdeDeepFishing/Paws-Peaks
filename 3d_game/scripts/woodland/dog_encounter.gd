extends "res://scripts/woodland/woodland_level.gd"

const DrawingSurface = preload("res://scripts/river/drawing_surface.gd")
const GeneratedModel = preload("res://scripts/river/generated_model.gd")
const Presentation = preload("res://scripts/woodland/dog_presentation.gd")
const GUARD_Z := -4.8
const DRAW_RADIUS := 16.0
const COLLECTION_OFFSET := Vector3(-2.8, 0, -0.6)

@onready var dog = $Wolfdog
@onready var request = $DrawingRequest
@onready var generation = $DesktopGeneration
var overlay: Control
var surface: Control
var generation_preview: Control
var hint: Label
var submit_button: Button
var choices: OptionButton
var modes: OptionButton
var cancel_request: Button
var drawing := false
var item: Dictionary = {}
var offered: Node3D
var presentation: Node
var sketch_anchor := Vector3.ZERO
var sketch_request_id := ""

func _ready() -> void:
	super._ready()
	request.state_changed.connect(_on_request_state)
	generation.progress_changed.connect(func(message: String): status.text = message)
	dog.collected.connect(_on_collected)
	draw_button.pressed.connect(_open_drawing)
	draw_button.tooltip_text = "Draw food or a toy to lead the dog off the path."
	objective.text = "Draw a distraction for the dog."
	_build_drawing()
	presentation = Presentation.new()
	presentation.name = "DogPresentation"
	add_child(presentation)
	presentation.finished.connect(_react_to_offering)
	generation_preview = preload("res://scripts/river/generation_preview.gd").attach(self, request, generation, surface)
	status.text = "The dog guards this path. Try drawing food or a toy."

func _process(delta: float) -> void:
	super._process(delta)
	var near := near_dog()
	draw_button.disabled = dog.distracted or presentation.active or request.state == "PENDING" or not player.is_on_floor()
	draw_button.text = "Path is clear" if dog.solved else ("E · Offer drawing" if request.state == "READY" and not dog.distracted else "E · Draw")
	drawing_shine.set_active(not drawing and near and not draw_button.disabled)
	cancel_request.visible = request.state == "PENDING"
	modes.disabled = request.state == "PENDING" or dog.distracted or presentation.active

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sketchbook"):
		if drawing:
			_close_drawing()
		else:
			_open_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and drawing:
		_close_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and request.state == "PENDING":
		request.cancel()
		get_viewport().set_input_as_handled()

func can_exit() -> bool:
	return dog.solved

func constrain_player(body: CharacterBody3D) -> void:
	# The dog owns the entire forward boundary, including shoulders and jumps.
	# This final check also prevents a fast sprint outrunning its visual response.
	if not dog.solved and body.position.z < GUARD_Z:
		body.position.z = GUARD_Z
		body.velocity.z = maxf(body.velocity.z, 0.0)
		if request.state != "PENDING" and not dog.distracted:
			status.text = "The dog keeps blocking the way. Draw food or a toy to distract it."

func near_dog() -> bool:
	# Patrol must not move the interaction boundary away from a stationary player.
	return Vector2(player.position.x - dog.home.x, player.position.z - dog.home.z).length() <= DRAW_RADIUS

func _open_drawing() -> void:
	if dog.distracted or presentation.active or request.state == "PENDING" or not player.is_on_floor():
		return
	if request.state == "READY" and not item.is_empty():
		_offer_item()
		return
	drawing = true
	dog.paused = true
	player.set_drawing_active(true)
	player.set_input_enabled(false)
	hud_root.hide()
	overlay.show()
	choices.visible = request.mock_mode
	hint.text = "Draw food (like an apple) or a toy (like a bone)."
	submit_button.disabled = not surface.has_drawing()

func _close_drawing() -> void:
	drawing = false
	surface.drawing = false
	dog.paused = presentation.busy
	overlay.hide()
	hud_root.visible = not presentation.busy
	player.set_drawing_active(false)
	player.set_input_enabled(not presentation.busy)

func _sketch_ground_anchor() -> Variant:
	var rect: Rect2 = surface.snapshot_screen_rect()
	if not rect.has_area():
		return null
	# The bottom center of the sketch is the object's contact point with the ground.
	var screen := Vector2(rect.get_center().x, rect.end.y)
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * camera.far, dog.GROUND_MASK, [player.get_rid(), dog.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5:
		return null
	return hit.position

func _submit() -> void:
	if not drawing or dog.distracted:
		return
	if not near_dog():
		hint.text = "Keep this sketch, then move closer to the dog to offer it."
		return
	var anchor = _sketch_ground_anchor()
	if not anchor is Vector3:
		hint.text = "Draw your object over the ground so it has a place to land."
		return
	if not request.submit(surface.snapshot_png(), "E02", choices.selected):
		hint.text = "Draw something first."
		return
	if request.state == "PENDING":
		sketch_anchor = anchor
		sketch_request_id = request.active_id
		generation_preview.anchor_to_world(camera, sketch_anchor)
		presentation.begin(_offering_position())
	_close_drawing()

func _on_request_state(state: String) -> void:
	match state:
		"PENDING":
			status.text = "Preparing your drawing. You can keep exploring."
		"IDLE":
			sketch_request_id = ""
			_clear_presentation()
		"FAILED":
			sketch_request_id = ""
			_clear_presentation()
			status.text = request.message + " Your sketch is safe; try again."
		"READY":
			item = request.result.duplicate(true)
			if item.get("type") not in ["FOOD", "TOY"]:
				request.fail_current("The dog wants food or a toy. That idea will not distract it.")
				return
			if near_dog() and player.is_on_floor():
				_offer_item()
			else:
				presentation.cancel()
				status.text = "Your drawing is ready. Return to the dog and press E to offer it."

func _clear_presentation() -> void:
	presentation.cancel()
	item = {}
	if is_instance_valid(offered):
		offered.queue_free()
	offered = null

func _offering_position() -> Vector3:
	return to_local(sketch_anchor)

func _offer_item() -> void:
	if request.state != "READY" or dog.distracted or is_instance_valid(offered) or item.get("type") not in ["FOOD", "TOY"]:
		return
	if not near_dog():
		status.text = "Return to the dog to offer your drawing."
		return
	if sketch_request_id != request.active_id:
		request.fail_current("The drawing location was lost. Try another sketch.")
		return
	var visual: Node3D
	if not request.model_path.is_empty():
		visual = GeneratedModel.load_visual(request.model_path, 1.5, false)
		if visual == null:
			request.fail_current("The generated object could not be loaded.")
			return
	if visual == null:
		visual = GeneratedModel.load_visual(ProjectSettings.globalize_path("res://../docs/test-artifacts/stage2-2026-09-13/model.glb"), 1.5, false)
		if visual == null:
			request.fail_current("The offline bone model could not be loaded.")
			return
	offered = GeneratedModel.physics_body(visual, item.movable)
	offered.name = "OfferedDrawing"
	if offered is RigidBody3D:
		offered.freeze = true
	offered.hide()
	add_child(offered)
	offered.global_position = sketch_anchor + (Vector3.UP * 2.0 if item.movable else Vector3.ZERO)
	presentation.reveal(offered)

func _react_to_offering() -> void:
	if request.state != "READY" or not is_instance_valid(offered) or dog.distracted: return
	# React to the final physical position after the covered reveal and drop.
	if dog.distract(offered.global_position + COLLECTION_OFFSET, offered.global_position):
		status.text = "You caught the dog's attention!"
		objective.text = "Watch the dog collect your drawing."

func _on_collected() -> void:
	objective.text = "The path is clear. Continue into the woods."
	status.text = "A new friend! Follow the path to the next chapter."
	var thanks := Label3D.new()
	thanks.name = "Thanks"
	thanks.text = "♥\nThank you!"
	thanks.modulate = Color("ffb4b4")
	thanks.font_size = 64
	thanks.outline_size = 10
	thanks.pixel_size = 0.009
	thanks.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	thanks.no_depth_test = true
	dog.add_child(thanks)
	thanks.top_level = true
	thanks.global_position = dog.global_position + Vector3.UP * 5.5

func _build_drawing() -> void:
	modes = OptionButton.new()
	modes.add_item("AI drawing · Uses credits", 2)
	modes.add_item("Sample bone · No AI", 1)
	modes.add_item("Mock outcomes · No AI", 0)
	modes.selected = 2 - generation.mode
	modes.position = Vector2(28, 150)
	hud_root.add_child(modes)
	modes.item_selected.connect(func(index: int): generation.configure(modes.get_item_id(index)))
	cancel_request = Button.new()
	cancel_request.text = "Stop waiting"
	cancel_request.position = Vector2(28, 195)
	hud_root.add_child(cancel_request)
	cancel_request.pressed.connect(func():
		request.cancel()
		status.text = "Stopped waiting. Your sketch is safe."
	)
	overlay = Control.new()
	overlay.name = "SceneDrawingOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.get_parent().add_child(overlay)
	surface = DrawingSurface.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(surface)
	var toolbar := PanelContainer.new()
	overlay.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left = 20
	toolbar.offset_right = -20
	toolbar.offset_top = -142
	toolbar.offset_bottom = -20
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(14)
	paper.content_margin_left = 18
	paper.content_margin_right = 18
	paper.content_margin_top = 14
	paper.content_margin_bottom = 14
	toolbar.add_theme_stylebox_override("panel", paper)
	surface.excluded_control = toolbar
	var stack := VBoxContainer.new()
	toolbar.add_child(stack)
	hint = _label(stack, "Draw food or a toy for the dog.", 18)
	choices = OptionButton.new()
	for choice in ["NO AI · Food", "NO AI · Toy", "NO AI · Unclear", "NO AI · Service failure", "NO AI · Unsuitable"]:
		choices.add_item(choice)
	stack.add_child(choices)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	stack.add_child(buttons)
	_button(buttons, "Undo", func(): surface.undo())
	_button(buttons, "Clear", func(): surface.clear())
	_button(buttons, "Back · Esc", _close_drawing)
	submit_button = _button(buttons, "Offer drawing", _submit)
	surface.changed.connect(func():
		submit_button.disabled = not surface.has_drawing()
		if surface.has_drawing():
			hint.text = "Draw food (like an apple) or a toy (like a bone)."
	)
	overlay.hide()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	button.pressed.connect(action)
	return button
