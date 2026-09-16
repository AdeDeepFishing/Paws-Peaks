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
var generation_preview: Control
var sketch_anchor := Vector3.ZERO
var offered: Node3D
var microphone_gift: Node2D
var gift_pending := false
var greeted_player := false

func _ready() -> void:
	super._ready()
	request.animation_options = otter.animation_options.duplicate(true)
	request.state_changed.connect(_on_request_state)
	generation.progress_changed.connect(func(message: String): status.text = message)
	draw_button.pressed.connect(_open_drawing)
	draw_button.tooltip_text = "Approach the otter to meet it."
	objective.text = "Meet the otter on the beach."
	status.text = "There is an otter waving on the beach. Go say hello."
	status.set_meta("narrator_guidance", status.text)
	_build_drawing()
	generation_preview = preload("res://scripts/river/generation_preview.gd").attach(self, request, generation, surface)

func near_otter() -> bool:
	return player.global_position.distance_to(otter.global_position) <= drawing_distance

func _process(delta: float) -> void:
	super._process(delta)
	if not entering and not otter.mood_revealed and otter.phase == "idle":
		otter.mood_revealed = true
		objective.text = "The otter feels heartbroken. Offer something to cheer it up."
		status.text = "The otter looks unhappy. Draw an offering to cheer it up."
		status.set_meta("narrator_guidance", status.text)
	if not entering and otter.mood_revealed and not greeted_player and near_otter() and player.velocity.length() < 0.1 and not drawing:
		greeted_player = true
		player.visual.play_action("greet")
	draw_button.disabled = entering or gift_pending or not near_otter() or not player.is_on_floor() or request.state == "PENDING"
	draw_button.tooltip_text = "E · Draw again" if is_instance_valid(offered) else "E · Draw"
	drawing_shine.set_active(not drawing and not draw_button.disabled)
	if drawing and not near_otter(): _close_drawing()

func _unhandled_input(event: InputEvent) -> void:
	if entering: return
	if event.is_action_pressed("sketchbook"):
		if drawing: _close_drawing()
		else: _open_drawing()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if drawing: _close_drawing()
		else: return
		get_viewport().set_input_as_handled()

func _open_drawing() -> void:
	if get_node("/root/Narrator").panel.opened: return
	if entering or gift_pending: return
	if not near_otter() or not player.is_on_floor() or request.state == "PENDING": return
	if request.state == "READY":
		request.reset()
		surface.clear()
	drawing = true
	player.set_drawing_active(true)
	player.set_input_enabled(false)
	hud_root.hide()
	overlay.show()
	hint.text = "Draw an offering to cheer up the otter."
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
		# Drawing is screen-space: sky/water ink can still become an offering on nearby sand.
		for offset in [Vector3(1.2, 0, 0), Vector3(-1.2, 0, 0), Vector3(0, 0, 1.2), Vector3.ZERO]:
			var target: Vector3 = otter.global_position + offset
			var ground := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 8, target + Vector3.DOWN * 8, 1, excluded)
			hit = get_world_3d().direct_space_state.intersect_ray(ground)
			if not hit.is_empty() and hit.normal.y >= 0.5: break
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
			otter.wait_for_drawing(sketch_anchor)
			status.text = "(Preparing your drawing for the otter…)"
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
			offered = GeneratedModel.physics_body(visual, request.result, true)
			add_child(offered)
			offered.global_position = sketch_anchor + Vector3.UP * GeneratedModel.placement_height(request.result)
			var rendered_id: String = request.active_id
			if not DisplayServer.get_name() == "headless":
				await RenderingServer.frame_post_draw
			if request.state != "READY" or request.active_id != rendered_id: return
			generation_preview.model_presented()
			otter.play_option(request.reaction)
			otter.accept_offering(request.otter_happy)
			if request.otter_happy: player.visual.play_action("celebrate")
			objective.text = "You cheered up the otter!" if otter.happy else "Try another offering to cheer up the otter."
			get_node("/root/Narrator").record("npc_interaction_resolved", {"result": "Presented a generated offering to the otter; its reaction animation played.", "item": request.result, "reaction": request.reaction, "otter_happy": request.otter_happy, "otter_response": request.otter_response})
			status.text = "Otter: " + request.otter_response
			status.set_meta("narrator_guidance", status.text)
			if request.otter_happy: _give_microphone()

func _give_microphone() -> void:
	var journey := get_node("/root/Journey")
	if journey.microphone_unlocked or gift_pending: return
	gift_pending = true
	var narrator := get_node("/root/Narrator")
	status.text = "Your offering cheered up the otter. It has a surprise gift for you!"
	status.set_meta("narrator_guidance", status.text)
	narrator.begin_scripted_line(status.text)
	while not narrator.panel.reveal_text.is_empty():
		await get_tree().process_frame
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	microphone_gift = preload("res://scripts/sunset_cove/microphone_gift.gd").new()
	microphone_gift.otter = otter
	layer.add_child(microphone_gift)
	await microphone_gift.conjured
	status.text = "The otter gave you a microphone. looks like the otter want to talk to you! use the mic to speak"
	status.set_meta("narrator_guidance", status.text)
	narrator.begin_scripted_line(status.text)
	# Keep the mist until speech (or paced subtitle fallback) actually starts.
	while narrator.panel.reveal_time <= 0.0 and not narrator.audio.playing and not narrator.panel.reveal_text.is_empty():
		await get_tree().process_frame
	microphone_gift.reveal()
	await microphone_gift.received
	journey.grant_microphone()
	gift_pending = false
	narrator.record("npc_interaction_resolved", {"result": "The happy otter conjured a microphone gift. The player received it and can now speak."})
	narrator.end_scripted_narration()
	layer.queue_free()

func _build_drawing() -> void:
	var modes := OptionButton.new()
	modes.add_item("Saved otter request · No AI", 1)
	modes.add_item("Live AI · Uses credits", 2)
	modes.selected = 1 if generation.mode == 2 else 0
	preload("res://ui/storybook/layout.gd").debug_control(modes, 0)
	hud_root.add_child(modes)
	modes.hide()
	modes.item_selected.connect(func(index: int): generation.configure(modes.get_item_id(index)))
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.get_parent().add_child(overlay)
	surface = preload("res://scripts/river/drawing_surface.gd").new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(surface)
	hint = _label(overlay, "Draw an offering to cheer up the otter.", 18)
	hint.hide()
	var actions := preload("res://ui/storybook/layout.gd").toolbar(overlay, surface, _close_drawing, _submit)
	submit_button = actions.get_node("HBoxContainer/Submit")
	preload("res://ui/storybook/layout.gd").drawing_tools(overlay, _close_drawing)
	overlay.hide()
