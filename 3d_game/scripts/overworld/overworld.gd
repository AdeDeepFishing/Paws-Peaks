extends Node3D

signal next_page

const RouteData = preload("res://scripts/overworld/route_data.gd")
const HeroVisual = preload("res://scripts/river/hero_visual.gd")
const FULL_POSITION := Vector3(0, 40.487478, 44.482349)
const FULL_TARGET := Vector3(0, 5.7, 0)
const TITLES := ["Across the River", "Woodland Path", "Wind Hill", "Sunset Cove", "Moonlit Forest"]

@export var autoplay := true
@onready var art: Node3D = $Art
@onready var camera: Camera3D = $Camera
var hero: Node3D
var caption: Label
var materials: Array[ShaderMaterial] = []
var route := Curve3D.new()
var stage_offsets: Array[float] = []
var palette_weights := Vector3(1, 0, 0)
var phase := "overview"
var traveler_offset := 0.0
var motion_time := 0.0
var stars: Array[Node] = []
var browse_panel: PanelContainer
var next_button: Button
var zoom_slider: HSlider
var inspection_stage := 1
var zoom_amount := 1.0
var zoom_target := 1.0

func _ready() -> void:
	_build_route()
	_build_hero()
	_build_caption()
	_build_browse_controls()
	_prepare_art()
	configure(0, 1)
	var journey := get_node("/root/Journey")
	if autoplay and not journey.busy:
		journey.start_intro.call_deferred()

func _build_route() -> void:
	route.bake_interval = 0.08
	for point in RouteData.ROUTE:
		route.add_point(point + Vector3.UP * 0.025)
	for stage in RouteData.STAGES:
		stage_offsets.append(route.get_closest_offset(stage))

func _build_hero() -> void:
	hero = HeroVisual.new()
	hero.name = "Traveler"
	hero.scale = Vector3.ONE * 1.45
	add_child(hero)
	# The imported map is unlit. A small dedicated light makes the shared hero
	# readable while leaving all supplied painted colors unchanged.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -25, 0)
	sun.light_energy = 0.7
	add_child(sun)

func _build_caption() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	caption = Label.new()
	hud.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_top = -76
	caption.offset_bottom = -28
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 23)
	caption.add_theme_color_override("font_color", Color("fff4da"))
	caption.add_theme_color_override("font_outline_color", Color("283b43"))
	caption.add_theme_constant_override("outline_size", 5)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_browse_controls() -> void:
	browse_panel = PanelContainer.new()
	caption.get_parent().add_child(browse_panel)
	browse_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	browse_panel.offset_left = 24
	browse_panel.offset_right = -24
	browse_panel.offset_top = -88
	browse_panel.offset_bottom = -24
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color("f3ebda")
	paper.set_corner_radius_all(16)
	paper.content_margin_left = 18
	paper.content_margin_right = 18
	paper.content_margin_top = 10
	paper.content_margin_bottom = 10
	browse_panel.add_theme_stylebox_override("panel", paper)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	browse_panel.add_child(row)
	var overview := Button.new()
	overview.text = "Full map"
	row.add_child(overview)
	overview.pressed.connect(func(): set_zoom(0.0))
	zoom_slider = HSlider.new()
	zoom_slider.min_value = 0.0
	zoom_slider.max_value = 1.0
	zoom_slider.step = 0.01
	zoom_slider.value = 1.0
	zoom_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_slider.custom_minimum_size.x = 80
	zoom_slider.tooltip_text = "Zoom · Mouse wheel / trackpad / − and +"
	row.add_child(zoom_slider)
	zoom_slider.value_changed.connect(set_zoom)
	var location := Button.new()
	location.text = "My location"
	row.add_child(location)
	location.pressed.connect(func(): set_zoom(1.0))
	next_button = Button.new()
	next_button.name = "NextPage"
	next_button.text = "Next page  →"
	next_button.custom_minimum_size.x = 160
	row.add_child(next_button)
	next_button.pressed.connect(_continue)
	for button in [overview, location, next_button]:
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", Color("273d36"))
		button.add_theme_color_override("font_hover_color", Color("273d36"))
		button.add_theme_color_override("font_focus_color", Color("273d36"))
		button.add_theme_color_override("font_pressed_color", Color("273d36"))
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var next_paper := paper.duplicate()
	next_paper.bg_color = Color("34584e")
	next_paper.set_corner_radius_all(10)
	next_button.add_theme_stylebox_override("normal", next_paper)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		next_button.add_theme_color_override(state, Color("fff4da"))
	var hover_paper := next_paper.duplicate()
	hover_paper.bg_color = Color("466b5e")
	next_button.add_theme_stylebox_override("hover", hover_paper)
	next_button.add_theme_stylebox_override("pressed", next_paper)
	zoom_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	browse_panel.hide()

func await_next_page(stage: int, duration_scale: float) -> void:
	inspection_stage = stage
	zoom_amount = 1.0
	set_zoom(1.0)
	phase = "browse"
	caption.offset_top = -140
	caption.offset_bottom = -92
	browse_panel.show()
	next_button.disabled = false
	next_button.grab_focus()
	await next_page
	phase = "leaving"
	browse_panel.hide()
	caption.offset_top = -76
	caption.offset_bottom = -28
	# Return to the chapter location if the player was inspecting the full map.
	var tween := create_tween()
	tween.tween_method(_set_camera, camera.transform, _close_transform(stage), 0.55 * duration_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

func _continue() -> void:
	if phase != "browse": return
	next_button.disabled = true
	next_page.emit()

func set_zoom(value: float) -> void:
	zoom_target = clampf(value, 0.0, 1.0)
	zoom_slider.set_value_no_signal(zoom_target)

func _unhandled_input(event: InputEvent) -> void:
	if phase != "browse": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: set_zoom(zoom_target + 0.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: set_zoom(zoom_target - 0.12)
	elif event is InputEventMagnifyGesture:
		set_zoom(zoom_target + log(event.factor))
	elif event is InputEventPanGesture:
		set_zoom(zoom_target - event.delta.y * 0.025)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]: set_zoom(zoom_target + 0.12)
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]: set_zoom(zoom_target - 0.12)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER: set_zoom(zoom_target - 0.15)
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER: set_zoom(zoom_target + 0.15)

func _prepare_art() -> void:
	var copies := {}
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original: ShaderMaterial = mesh.get_active_material(surface)
			if not copies.has(original):
				copies[original] = original.duplicate()
				materials.append(copies[original])
			mesh.set_surface_override_material(surface, copies[original])
	stars = art.find_children("Drybrush_Star*", "Node3D", true, false)
	var original: AnimationPlayer = art.find_child("AnimationPlayer", true, false)
	# The three delivered clips animate independent properties; separate players
	# let foliage, water and clouds run together without replacing one another.
	for clip in original.get_animation_list():
		if clip == "RESET": continue
		var animator := AnimationPlayer.new()
		original.get_parent().add_child(animator)
		animator.root_node = original.root_node
		var library := AnimationLibrary.new()
		var animation: Animation = original.get_animation(clip).duplicate()
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation("Loop", animation)
		animator.add_animation_library("", library)
		animator.play("Loop")

func configure(from_stage: int, to_stage: int) -> void:
	_set_palette(_weights_for_stage(maxi(from_stage, 1)))
	_set_traveler(stage_offsets[maxi(from_stage, 1) - 1])
	hero.set_motion(false, false, true)
	caption.text = "PAWS & PEAKS" if from_stage == 0 else "CHAPTER %02d  ·  %s" % [to_stage, TITLES[to_stage - 1]]
	_set_camera(_full_transform() if from_stage == 0 else _close_transform(from_stage))
	phase = "overview" if from_stage == 0 else "return"

func play_route(from_stage: int, to_stage: int, duration_scale: float) -> void:
	if from_stage == 0:
		phase = "overview"
		await get_tree().create_timer(maxf(0.01, 1.3 * duration_scale)).timeout
	else:
		phase = "travel"
		hero.set_motion(true, false, true)
		var distance: float = stage_offsets[to_stage - 1] - stage_offsets[from_stage - 1]
		var seconds := maxf(3.4, distance / 3.0) * duration_scale
		var travel := create_tween().set_parallel(true)
		travel.tween_method(_set_traveler, stage_offsets[from_stage - 1], stage_offsets[to_stage - 1], seconds)
		travel.tween_method(_set_camera, camera.transform, _full_transform(), minf(seconds, 1.8 * duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		travel.tween_method(_set_palette, palette_weights, _weights_for_stage(to_stage), minf(seconds, 3.2 * duration_scale)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await travel.finished
		hero.set_motion(false, false, true)
		await get_tree().create_timer(maxf(0.01, 0.35 * duration_scale)).timeout
	phase = "zoom_in"
	caption.text = "CHAPTER %02d  ·  %s" % [to_stage, TITLES[to_stage - 1]]
	var closeup := create_tween()
	closeup.tween_method(_set_camera, camera.transform, _close_transform(to_stage), 1.65 * duration_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await closeup.finished
	phase = "arrival"
	await get_tree().create_timer(maxf(0.01, 0.3 * duration_scale)).timeout

func _weights_for_stage(stage: int) -> Vector3:
	if stage >= 5: return Vector3(0, 0, 1)
	if stage >= 3: return Vector3(0, 1, 0)
	return Vector3(1, 0, 0)

func _set_palette(value: Vector3) -> void:
	palette_weights = value
	for material in materials:
		material.set_shader_parameter("weights", value)

func _set_traveler(offset: float) -> void:
	traveler_offset = offset
	hero.position = route.sample_baked(offset)
	var forward := route.sample_baked(minf(offset + 0.2, route.get_baked_length())) - route.sample_baked(maxf(0, offset - 0.2))
	if forward.length_squared() > 0.0001:
		hero.rotation.y = atan2(-forward.x, -forward.z)

func _full_transform() -> Transform3D:
	# Keep the complete map in narrow windows as well as the reference 16:10.
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var pullback := maxf(1.0, 1.6 / aspect)
	return Transform3D(Basis.IDENTITY, FULL_TARGET + (FULL_POSITION - FULL_TARGET) * pullback).looking_at(FULL_TARGET)

func _close_transform(stage: int) -> Transform3D:
	var focus: Vector3 = RouteData.STAGES[stage - 1] + Vector3.UP * 0.9
	return Transform3D(Basis.IDENTITY, focus + (FULL_POSITION - FULL_TARGET).normalized() * 14.0).looking_at(focus)

func _set_camera(value: Transform3D) -> void:
	camera.transform = value

func _process(delta: float) -> void:
	if phase == "browse":
		zoom_amount = lerpf(zoom_amount, zoom_target, 1.0 - exp(-delta * 9.0))
		_set_camera(_full_transform().interpolate_with(_close_transform(inspection_stage), zoom_amount))
	motion_time += delta
	for i in stars.size():
		stars[i].scale = Vector3.ONE * (0.8 + 0.2 * sin(motion_time * 0.75 + i * 1.19))
