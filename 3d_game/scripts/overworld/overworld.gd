extends Node3D

signal start_requested

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
var start_button: Button
var review_stage := 1
var browsing_current := false
var zoom_amount := 0.0
var zoom_target := 0.0
var chapter_card: Control
var title_lines: Array[Label3D] = []
var title_progress := 0.0
const INTRO_HOLD := 2.5
const TITLE_FONT = preload("res://ui/title/cormorant_upright_semibold.ttf")

func _ready() -> void:
	_build_route()
	_build_hero()
	_build_caption()
	_build_start_button()
	_build_title()
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

func _build_start_button() -> void:
	chapter_card = preload("res://ui/title/chapter_card.gd").new()
	caption.get_parent().add_child(chapter_card)
	chapter_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	start_button = chapter_card.play
	start_button.pressed.connect(_start)
	start_button.hide()
	caption.hide()

func _build_title() -> void:
	for index in 2:
		var line := Label3D.new()
		line.text = "The Tale" if index == 0 else "We Drew"
		line.font = TITLE_FONT
		line.font_size = 160
		line.outline_size = 0
		line.modulate = Color("303632")
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		line.shaded = false
		line.no_depth_test = false
		line.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		add_child(line)
		title_lines.append(line)

func _set_title_progress(value: float) -> void:
	title_progress = value
	_layout_title()

func _layout_title() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var scale_factor := minf(viewport.x / 1280.0, viewport.y / 800.0)
	var depth := lerpf(72.0, 1.0, title_progress)
	var size_px := lerpf(138.0, 46.0, title_progress) * scale_factor
	var origin := Vector2(viewport.x * .07, viewport.y * .075)
	var spacing := lerpf(142.0, 49.0, title_progress) * scale_factor
	for index in title_lines.size():
		var line := title_lines[index]
		line.global_transform = Transform3D(camera.global_basis, camera.project_position(origin + Vector2(0, spacing * index), depth))
		line.pixel_size = 2.0 * depth * tan(deg_to_rad(camera.fov * .5)) / viewport.y * size_px / 160.0

func await_start(stage: int = 1, resume_chapter: bool = false) -> void:
	phase = "start"
	review_stage = stage
	browsing_current = resume_chapter
	zoom_amount = 0.0
	zoom_target = 0.0
	chapter_card.configure(stage, resume_chapter)
	chapter_card.set_progress(1.0)
	caption.text = "Draw something, help someone, and have fun ✨" if stage == 1 else "CHAPTER %02d  ·  %s" % [stage, TITLES[stage - 1]]
	if resume_chapter:
		start_button.text = "Return"
		caption.text = "CHAPTER %02d  ·  %s" % [stage, TITLES[stage - 1]]
	start_button.disabled = false
	start_button.show()
	start_button.grab_focus()
	await start_requested
	phase = "leaving"
	start_button.hide()
	caption.text = "CHAPTER %02d  ·  %s" % [stage, TITLES[stage - 1]]

func _start() -> void:
	if phase != "start" or start_button.disabled: return
	start_button.disabled = true
	start_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if phase != "start": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(-0.12 * event.factor)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(0.12 * event.factor)
		else: return
	elif event is InputEventMagnifyGesture:
		_zoom_by(-(event.factor - 1.0) * 2.0)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			_zoom_by(-0.12)
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom_by(0.12)
		else: return
	else: return
	get_viewport().set_input_as_handled()

func _zoom_by(amount: float) -> void:
	zoom_target = clampf(zoom_target + amount, 0.0, 1.0)

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
	caption.text = "CHAPTER %02d  ·  %s" % [to_stage, TITLES[to_stage - 1]]
	chapter_card.configure(to_stage)
	chapter_card.set_progress(0.0)
	_set_title_progress(0.0 if from_stage == 0 else 1.0)
	hero.visible = from_stage != 0
	_set_camera(_full_transform() if from_stage == 0 else _close_transform(from_stage))
	phase = "overview" if from_stage == 0 else "return"

func play_route(from_stage: int, to_stage: int, duration_scale: float) -> void:
	if from_stage == 0:
		phase = "overview"
		await get_tree().create_timer(maxf(0.01, INTRO_HOLD * duration_scale)).timeout
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
	var closeup := create_tween().set_parallel(true)
	closeup.tween_method(_set_title_progress, title_progress, 1.0, 1.65 * duration_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	closeup.tween_method(chapter_card.set_progress, 0.0, 1.0, 1.65 * duration_scale).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	start_button.disabled = true
	start_button.show()
	closeup.tween_method(_set_camera, camera.transform, _close_transform(to_stage), 1.65 * duration_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await closeup.finished
	if from_stage == 0:
		hero.show()
		hero.set_motion(true, false, true)
		var goal: Vector3 = route.sample_baked(stage_offsets[0])
		var entry := goal + Vector3(0, -.1, 10.0)
		hero.position = entry
		hero.rotation.y = 0.0
		var walk := create_tween()
		walk.tween_property(hero, "position", goal, 1.2 * duration_scale)
		await walk.finished
		_set_traveler(stage_offsets[0])
		hero.set_motion(false, false, true)
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
	for line in title_lines:
		line.modulate = Color("303632").lerp(Color("f3ebda"), value.z)

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
	var focus: Vector3 = RouteData.STAGES[stage - 1] + Vector3.DOWN * 1.2
	return Transform3D(Basis.IDENTITY, focus + (FULL_POSITION - FULL_TARGET).normalized() * 25.0).looking_at(focus)

func _set_camera(value: Transform3D) -> void:
	camera.transform = value

func _process(delta: float) -> void:
	_layout_title()
	if phase == "start":
		zoom_amount = lerpf(zoom_amount, zoom_target, 1.0 - exp(-delta * 9.0))
		_set_camera(_close_transform(review_stage).interpolate_with(_full_transform(), zoom_amount))
	motion_time += delta
	for i in stars.size():
		stars[i].scale = Vector3.ONE * (0.8 + 0.2 * sin(motion_time * 0.75 + i * 1.19))
