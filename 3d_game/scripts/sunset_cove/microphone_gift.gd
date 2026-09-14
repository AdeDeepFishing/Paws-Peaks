extends Node2D

signal received
signal conjured
const DURATION := 3.0
const ICON = preload("res://ui/microphone.svg")
var otter: Node3D
var elapsed := 0.0
var revealed := false
var conjuring_complete := false
var mist: Control

func _ready() -> void:
	mist = preload("res://scripts/river/generation_mist.gd").new()
	add_child(mist)
	mist.set_active(true)

func reveal() -> void:
	revealed = true
	elapsed = 0.0
	mist.set_active(false)

func _process(delta: float) -> void:
	elapsed += delta
	if revealed and elapsed >= DURATION:
		hide()
		received.emit()
		queue_free()
		return
	if not revealed and not conjuring_complete and elapsed >= 1.2:
		conjuring_complete = true
		conjured.emit()
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(otter) or camera == null: return
	# Rise from the otter's paws, then hover beside its head in a swirl of sparks.
	var rise := 1.0 if revealed else smoothstep(0.0, 0.8, elapsed)
	position = camera.unproject_position(otter.global_position + Vector3.UP * (1.0 + rise)) + Vector2(-52 * rise, -12)
	var appear := 1.0 if revealed else smoothstep(0.0, 0.35, elapsed)
	scale = Vector2.ONE * appear * (1.0 + sin(elapsed * 5) * 0.035)
	if not revealed: mist.follow_rect(Rect2(-40, -40, 80, 80), true)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 40, Color(1.0, 0.86, 0.54, 0.18))
	draw_circle(Vector2.ZERO, 29, Color("fff2cc"))
	draw_arc(Vector2.ZERO, 33, elapsed * 2, elapsed * 2 + TAU * 0.8, 40, Color("f5cb73"), 2, true)
	for i in 10:
		var angle := TAU * i / 10.0 + elapsed * 1.6
		var radius := 39 + sin(elapsed * 4 + i) * 9
		var point := Vector2(cos(angle), sin(angle)) * radius
		var extent := 2.0 + (sin(elapsed * 6 + i) + 1.0) * 1.5
		draw_line(point - Vector2(extent, 0), point + Vector2(extent, 0), Color("fff4ce"), 2, true)
		draw_line(point - Vector2(0, extent), point + Vector2(0, extent), Color("fff4ce"), 2, true)
	draw_texture_rect(ICON, Rect2(-18, -23, 36, 46), false, Color("745635"))
