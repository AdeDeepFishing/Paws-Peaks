extends "res://scripts/woodland/woodland_level.gd"

const DrawingSurface = preload("res://scripts/river/drawing_surface.gd")
const GeneratedModel = preload("res://scripts/river/generated_model.gd")
const Framing = preload("res://scripts/woodland/encounter_framing.gd")
const Presentation = preload("res://scripts/woodland/dog_presentation.gd")
const Sample = preload("res://scripts/wind_hill/defence_sample.gd")
const GUARD_X := 6.0
const GROUND_MASK := 2
const PROTECTION_WIDTH := 10.0
const PROTECTION_BASE_HEIGHT := 3.1

@onready var bird = $BirdGuard
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
var solved := false
var resolving := false
var item: Dictionary = {}
var offered: Node3D
var presentation: Node
var sketch_anchor := Vector3.ZERO
var sketch_request_id := ""
var protection_tween: Tween
var resolution_epoch := 0

func _ready() -> void:
	super._ready()
	request.state_changed.connect(_on_request_state)
	generation.progress_changed.connect(func(message: String): status.text = message)
	bird.cleared.connect(_on_cleared)
	bird.departure_started.connect(_release_protection)
	bird.swooping.connect(func():
		if not resolving and request.state != "PENDING":
			status.text = "Watch out! Draw something to protect yourself."
			status.set_meta("narrator_guidance", status.text)
	)
	draw_button.pressed.connect(_open_drawing)
	draw_button.tooltip_text = "Draw protection against the swooping bird."
	objective.text = "Draw protection from the bird."
	_build_drawing()
	presentation = Presentation.new()
	presentation.name = "BirdPresentation"
	presentation.focus_fov = 32.0
	presentation.track_subjects = false
	add_child(presentation)
	presentation.finished.connect(_finish_presentation)
	generation_preview = preload("res://scripts/river/generation_preview.gd").attach(self, request, generation, surface)
	status.text = "A giant bird is guarding the hill. An umbrella or a shield could help."
	status.set_meta("narrator_guidance", status.text)

func _process(delta: float) -> void:
	super._process(delta)
	draw_button.disabled = entering or solved or resolving or presentation.active or request.state == "PENDING" or not player.is_on_floor()
	draw_button.tooltip_text = "Path is clear" if solved else ("Protected" if resolving else ("E · Use protection" if request.state == "READY" and item.get("type") == "DEFENCE" else "E · Draw"))
	drawing_shine.set_active(not drawing and not draw_button.disabled)
	cancel_request.visible = request.state == "PENDING"
	modes.disabled = request.state == "PENDING" or resolving or solved or presentation.active

func presentation_camera_transform(anchor: Vector3) -> Transform3D:
	var back: Vector3 = global_basis * presentation.home.basis.z
	# Pulling back along the low authored lens can put the camera below the hill.
	back.y = maxf(back.y, 0.22)
	var basis := Transform3D(Basis.IDENTITY, back.normalized()).looking_at(Vector3.ZERO, Vector3.UP).basis
	var points: Array[Vector3] = []
	Framing.add_visual(points, player.visual)
	Framing.add_box(points, AABB(to_global(anchor), Vector3(0, 3, 0)))
	if is_instance_valid(offered): Framing.add_visual(points, offered)
	# The generation close-up belongs to the sketch and protagonist, not the flight path.
	Framing.add_sketch(points, generation_preview, basis)
	return global_transform.affine_inverse() * Framing.fit(camera, points, points, basis, generation_preview, presentation.focus_fov, 3.0, 0.83)

func can_exit() -> bool:
	return solved

func constrain_player(body: CharacterBody3D) -> void:
	if not solved and body.position.x > GUARD_X:
		body.position.x = GUARD_X
		body.velocity.x = minf(body.velocity.x, 0.0)
		if request.state != "PENDING" and not resolving:
			status.text = "The bird blocks the way. Draw something to protect yourself."
			status.set_meta("narrator_guidance", status.text)

func set_encounter_paused(value: bool) -> void:
	bird.paused = value

func _unhandled_input(event: InputEvent) -> void:
	if entering: return
	if event.is_action_pressed("sketchbook"):
		if drawing: _close_drawing()
		else: _open_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if drawing: _close_drawing()
		elif request.state == "PENDING": request.cancel()
		get_viewport().set_input_as_handled()

func _open_drawing() -> void:
	if get_node("/root/Narrator").panel.opened: return
	if entering: return
	if solved or resolving or presentation.active or request.state == "PENDING" or not player.is_on_floor(): return
	if request.state == "READY" and not item.is_empty() and not is_instance_valid(offered):
		_offer_item()
		return
	drawing = true
	bird.paused = false
	player.visual.set_avoidance(0.0)
	player.set_drawing_active(true)
	player.set_input_enabled(false)
	hud_root.hide()
	overlay.show()
	choices.visible = request.mock_mode
	hint.text = "Draw something to protect yourself."
	submit_button.disabled = not surface.has_drawing()

func _close_drawing() -> void:
	drawing = false
	surface.drawing = false
	bird.paused = presentation.busy
	overlay.hide()
	hud_root.visible = not presentation.busy
	player.set_drawing_active(false)
	player.set_input_enabled(not presentation.busy)

func _sketch_ground_anchor() -> Variant:
	var rect: Rect2 = surface.snapshot_screen_rect()
	if not rect.has_area(): return null
	var screen := Vector2(rect.get_center().x, rect.end.y)
	var origin := camera.project_ray_origin(screen)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(screen) * camera.far, GROUND_MASK, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y >= 0.5 and hit.position.distance_to(player.global_position) <= 10.0:
		return hit.position
	# Screen-space sketches may cover the sky; place those on nearby terrain.
	for offset in [Vector3(1.5, 0, 0), Vector3(-1.5, 0, 0), Vector3(0, 0, 1.5), Vector3.ZERO]:
		var point: Vector3 = player.global_position + offset
		var ground := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5, point + Vector3.DOWN * 10, GROUND_MASK, [player.get_rid()])
		hit = get_world_3d().direct_space_state.intersect_ray(ground)
		if not hit.is_empty() and hit.normal.y >= 0.5: return hit.position
	return null

func _submit() -> void:
	if not drawing or resolving: return
	var anchor = _sketch_ground_anchor()
	if not anchor is Vector3:
		_submission_error("No safe ground nearby. Close the drawing, move onto the path, and try again.")
		return
	if not request.submit(surface.snapshot_png(), "E03", choices.selected):
		_submission_error("Draw something first.")
		return
	if request.state == "PENDING":
		sketch_anchor = anchor
		sketch_request_id = request.active_id
		generation_preview.anchor_to_world(camera, sketch_anchor)
		presentation.begin(to_local(sketch_anchor))
	_close_drawing()

func _submission_error(message: String) -> void:
	hint.text = message
	var narrator := get_node("/root/Narrator")
	narrator.skip()
	narrator.panel._show_line("Narrator", message)

func _on_request_state(state: String) -> void:
	match state:
		"PENDING":
			if is_instance_valid(offered): offered.queue_free()
			offered = null
			item = {}
			status.text = "Giving your drawing shape..."
		"IDLE", "FAILED":
			_clear_presentation()
			status.text = request.message + " Your sketch is safe; try again." if state == "FAILED" else "Stopped waiting. Your sketch is safe."
		"READY":
			item = request.result.duplicate(true)
			if item.get("type") != "DEFENCE" and request.mock_mode:
				request.fail_current("Try something that could protect you from the bird.")
				return
			_offer_item()

func _clear_presentation() -> void:
	resolution_epoch += 1
	if protection_tween and protection_tween.is_valid(): protection_tween.kill()
	presentation.cancel()
	if is_instance_valid(offered): offered.queue_free()
	offered = null
	item = {}
	sketch_request_id = ""
	resolving = false
	player.visual.set_avoidance(0.0)

func _offer_item() -> void:
	if request.state != "READY" or resolving or solved or is_instance_valid(offered): return
	if sketch_request_id != request.active_id:
		request.fail_current("The drawing location was lost. Try another sketch.")
		return
	if request.mock_mode:
		offered = Sample.create(item.get("name") == "Shield")
	else:
		offered = GeneratedModel.load_visual(request.model_path, 3.0, false, item)
		if offered == null:
			request.fail_current("The generated protection could not be loaded.")
			return
	offered = GeneratedModel.physics_body(offered, item, true)
	if offered is RigidBody3D: offered.freeze = true
	offered.name = "DrawnProtection"
	offered.hide()
	add_child(offered)
	offered.global_position = sketch_anchor + Vector3.UP * GeneratedModel.placement_height(item)
	presentation.reveal(offered)

func _finish_presentation() -> void:
	if request.state != "READY" or not is_instance_valid(offered): return
	if item.get("type") == "DEFENCE":
		_raise_protection()
	else:
		objective.text = "Try something that could protect you from the bird."
		status.text = "Your object is ready, but it cannot block the bird. Try another drawing."
		status.set_meta("narrator_guidance", status.text)

func _raise_protection() -> void:
	if request.state != "READY" or not is_instance_valid(offered) or resolving or solved: return
	resolving = true
	var token := resolution_epoch
	player.set_input_enabled(false)
	player.visual.set_avoidance(0.0)
	bird.paused = true
	if offered is PhysicsBody3D:
		var body := offered
		offered = body.get_child(0)
		offered.reparent(self)
		body.queue_free()
	# Equipped protection follows the protagonist; it is not a loose ground obstacle.
	offered.reparent(player)
	var bounds := GeneratedModel._bounds(offered)
	var factor := PROTECTION_WIDTH / maxf(maxf(bounds.size.x, bounds.size.z), 0.1)
	var top := PROTECTION_BASE_HEIGHT + bounds.end.y * factor
	protection_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	protection_tween.tween_property(offered, "position", Vector3(0, PROTECTION_BASE_HEIGHT, 0), 1.0)
	protection_tween.tween_property(offered, "scale", Vector3.ONE * factor, 1.0)
	await protection_tween.finished
	if token != resolution_epoch: return
	bird.paused = false
	bird.protect(top + 0.3)
	objective.text = "Your protection blocks the bird."
	status.text = "Safe underneath! The bird is flying away."
	status.set_meta("narrator_guidance", status.text)

func _release_protection() -> void:
	if not resolving or not is_instance_valid(offered): return
	var model := offered
	var token := resolution_epoch
	# The wind takes only the drawing. Detach before animating any transform.
	model.reparent(self)
	protection_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	protection_tween.tween_property(model, "position", model.position + Vector3(16, 10, -12), 2.6)
	protection_tween.tween_property(model, "rotation", model.rotation + Vector3(0.2, 0.5, -0.5), 2.6)
	protection_tween.tween_property(model, "scale", model.scale * 0.3, 2.6)
	for mesh in model.get_children():
		if mesh is MeshInstance3D:
			protection_tween.tween_property(mesh, "transparency", 1.0, 0.65).set_delay(1.95)
	protection_tween.finished.connect(func():
		if token != resolution_epoch or not is_instance_valid(model): return
		model.queue_free()
		if offered == model: offered = null
	)

func _on_cleared() -> void:
	if not resolving: return
	solved = true
	player.visual.play_action("celebrate")
	get_node("/root/Narrator").record("encounter_completed", {"result": "The drawing protected the player and the bird cleared the path.", "item": request.result})
	resolving = false
	player.set_input_enabled(true)
	objective.text = "The sky is clear. Continue to Sunset Cove."
	status.text = "Your drawing kept you safe. Follow the path to the right."
	status.set_meta("narrator_guidance", status.text)

func _build_drawing() -> void:
	modes = OptionButton.new()
	modes.add_item("AI drawing · Uses credits", 2)
	modes.add_item("Mock outcomes · No AI", 0)
	modes.selected = 0 if generation.mode == 2 else 1
	preload("res://ui/storybook/layout.gd").debug_control(modes, 0)
	hud_root.add_child(modes)
	modes.hide()
	modes.item_selected.connect(func(index: int): generation.configure(modes.get_item_id(index)))
	cancel_request = Button.new()
	cancel_request.text = "Stop waiting"
	preload("res://ui/storybook/layout.gd").debug_control(cancel_request, 2)
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
	hint = _label(overlay, "Draw your idea over the scene.", 18)
	hint.hide()
	choices = OptionButton.new()
	for choice in ["NO AI · Umbrella", "NO AI · Shield", "NO AI · Unclear", "NO AI · Service failure", "NO AI · Unsuitable"]:
		choices.add_item(choice)
	overlay.add_child(choices)
	preload("res://ui/storybook/layout.gd").debug_control(choices, 0)
	var actions := preload("res://ui/storybook/layout.gd").toolbar(overlay, surface, _close_drawing, _submit)
	submit_button = actions.get_node("HBoxContainer/Submit")
	preload("res://ui/storybook/layout.gd").drawing_tools(overlay)
	surface.changed.connect(func():
		if surface.has_drawing(): hint.text = "Draw your idea over the scene."
	)
	overlay.hide()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 18)
	parent.add_child(button)
	button.pressed.connect(action)
	return button
