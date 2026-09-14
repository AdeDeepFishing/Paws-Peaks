extends "res://scripts/woodland/woodland_level.gd"

const GeneratedModel = preload("res://scripts/river/generated_model.gd")
@export var drawing_distance := 2.5
@onready var otter = $Otter
@onready var request = $DrawingRequest
@onready var generation = $DesktopGeneration
var drawing := false
var overlay: Control
var surface: Control
var hint: Label
var submit_button: Button
var cancel_button: Button
var generation_preview: Control
var sketch_anchor := Vector3.ZERO
var offered: Node3D

func _ready() -> void:
	super._ready()
	request.animation_options = otter.animation_options.duplicate(true)
	request.state_changed.connect(_on_request_state)
	generation.progress_changed.connect(func(message: String): status.text = message)
	draw_button.pressed.connect(_open_drawing)
	draw_button.tooltip_text = "Approach the otter to show it a drawing."
	objective.text = "Meet the otter. Draw something to show it."
	_build_drawing()
	generation_preview = preload("res://scripts/river/generation_preview.gd").attach(self, request, generation, surface)

func near_otter() -> bool:
	return player.global_position.distance_to(otter.global_position) <= drawing_distance

func _process(delta: float) -> void:
	super._process(delta)
	draw_button.disabled = entering or not near_otter() or not player.is_on_floor() or request.state == "PENDING"
	draw_button.text = "E · Draw again" if is_instance_valid(offered) else "E · Draw"
	drawing_shine.set_active(not drawing and not draw_button.disabled)
	cancel_button.visible = request.state == "PENDING"
	if drawing and not near_otter(): _close_drawing()

func _unhandled_input(event: InputEvent) -> void:
	if entering: return
	if event.is_action_pressed("sketchbook"):
		if drawing: _close_drawing()
		else: _open_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if drawing: _close_drawing()
		elif request.state == "PENDING": request.cancel()
		else: return
		get_viewport().set_input_as_handled()

func _open_drawing() -> void:
	if entering: return
	if not near_otter() or not player.is_on_floor() or request.state == "PENDING": return
	if request.state == "READY":
		request.reset()
		surface.clear()
	drawing = true
	player.set_drawing_active(true)
	player.set_input_enabled(false)
	hud_root.hide()
	overlay.show()
	hint.text = "Draw something to show the otter."
	submit_button.disabled = not surface.has_drawing()

func _close_drawing() -> void:
	drawing = false
	surface.drawing = false
	overlay.hide()
	hud_root.show()
	player.set_drawing_active(false)
	player.set_input_enabled(true)

func _submit() -> void:
	if not drawing or not near_otter() or not surface.has_drawing(): return
	var rect: Rect2 = surface.snapshot_screen_rect()
	var point := Vector2(rect.get_center().x, rect.end.y)
	var origin := camera.project_ray_origin(point)
	var excluded: Array[RID] = [player.get_rid()]
	if is_instance_valid(offered): excluded.append(offered.get_rid())
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * camera.far, 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.5:
		hint.text = "Draw over the sand so your object has a place to land."
		return
	sketch_anchor = hit.position
	if not request.submit(surface.snapshot_png(), "E04"): return
	if request.state == "PENDING": generation_preview.anchor_to_world(camera, sketch_anchor)
	_close_drawing()

func _on_request_state(state: String) -> void:
	match state:
		"PENDING":
			otter.wait_for_drawing()
			status.text = "Preparing your drawing for the otter…"
		"FAILED":
			otter.stop_waiting()
			status.text = request.message + " Try another drawing."
		"IDLE":
			otter.stop_waiting()
			status.text = "Stopped waiting. Your sketch is safe."
		"READY":
			var visual := GeneratedModel.load_visual(request.model_path, 1.5, false, request.result)
			if visual == null:
				request.fail_current("The generated object could not be loaded.")
				return
			if is_instance_valid(offered): offered.queue_free()
			offered = GeneratedModel.physics_body(visual, request.result.movable)
			add_child(offered)
			offered.global_position = sketch_anchor + (Vector3.UP * 0.2 if request.result.movable else Vector3.ZERO)
			var rendered_id: String = request.active_id
			if not DisplayServer.get_name() == "headless":
				await RenderingServer.frame_post_draw
			if request.state != "READY" or request.active_id != rendered_id: return
			generation_preview.model_presented()
			otter.play_option(request.reaction)
			get_node("/root/Narrator").record("npc_interaction_resolved", {"result": "Showed a generated drawing to the otter; its reaction animation played. No gift transfer is implied.", "item": request.result, "reaction": request.reaction})
			status.text = "Your drawing is here. You can show the otter another."

func _build_drawing() -> void:
	cancel_button = Button.new()
	cancel_button.text = "Stop waiting"
	cancel_button.position = Vector2(28, 170)
	hud_root.add_child(cancel_button)
	cancel_button.pressed.connect(func(): request.cancel())
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.get_parent().add_child(overlay)
	surface = preload("res://scripts/river/drawing_surface.gd").new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(surface)
	var toolbar := PanelContainer.new()
	overlay.add_child(toolbar)
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	toolbar.offset_left = 20
	toolbar.offset_right = -20
	toolbar.offset_top = -120
	toolbar.offset_bottom = -20
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(14)
	paper.content_margin_left = 18
	paper.content_margin_top = 14
	toolbar.add_theme_stylebox_override("panel", paper)
	surface.excluded_control = toolbar
	var stack := VBoxContainer.new()
	toolbar.add_child(stack)
	hint = _label(stack, "Draw something to show the otter.", 18)
	var buttons := HBoxContainer.new()
	stack.add_child(buttons)
	for entry in [["Undo", surface.undo], ["Clear", surface.clear], ["Back · Esc", _close_drawing], ["Show drawing", _submit]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		buttons.add_child(button)
		submit_button = button
	surface.changed.connect(func(): submit_button.disabled = not surface.has_drawing())
	overlay.hide()
