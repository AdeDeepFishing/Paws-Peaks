extends Node2D

## A screen-space heart follows the otter's head without rotating with its body.
var otter: Node3D
var happy := false
var time := 0.0

func _ready() -> void:
	hide()

func _process(delta: float) -> void:
	time += delta
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(otter) or camera == null:
		hide()
		return
	var head: Vector3 = otter.global_position + Vector3.UP * otter.visual_height
	visible = not camera.is_position_behind(head) and otter.is_visible_in_tree() and (happy or (otter.mood_revealed and otter.phase not in ["waving", "waiting"] and not otter.get_parent().drawing))
	position = camera.unproject_position(head) + Vector2(38, -18 + sin(time * 2.0) * 3)
	scale = Vector2.ONE * (1.0 + sin(time * (4.0 if happy else 2.0)) * 0.045)
	queue_redraw()

func _shape(points: PackedVector2Array, tint: Color) -> void:
	draw_colored_polygon(points, tint)
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color("fff5e8"), 2.5, true)

func _draw() -> void:
	if happy:
		var heart := PackedVector2Array()
		for i in 64:
			var t := TAU * i / 64.0
			heart.append(Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2*t) - 2 * cos(3*t) - cos(4*t))) * 1.35)
		_shape(heart, Color("ed7090"))
	else:
		var gap := 3.0 + (sin(time * 2.0) + 1.0) * 1.5
		draw_set_transform(Vector2(-gap, 0), -0.08)
		_shape(PackedVector2Array([Vector2(0,-8), Vector2(-8,-17), Vector2(-18,-15), Vector2(-24,-7), Vector2(-23,3), Vector2(-15,13), Vector2(0,24), Vector2(-3,12), Vector2(3,5), Vector2(-3,-1)]), Color("b987a2"))
		draw_set_transform(Vector2(gap, 0), 0.08)
		_shape(PackedVector2Array([Vector2(0,-8), Vector2(8,-17), Vector2(18,-15), Vector2(24,-7), Vector2(23,3), Vector2(15,13), Vector2(0,24), Vector2(-3,12), Vector2(3,5), Vector2(-3,-1)]), Color("b987a2"))
