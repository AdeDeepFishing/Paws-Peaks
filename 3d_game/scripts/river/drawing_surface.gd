extends Control

signal changed

const IMAGE_SIZE := 512
const BRUSH_RADIUS := 3.0
const INK := Color.BLACK
const OUTLINE := Color("fff9ed")

# Points use a persistent isotropic coordinate system, not stretched UVs.
var strokes: Array[PackedVector2Array] = []
var drawing := false
var reference_size := Vector2.ZERO
var excluded_control: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)
	mouse_exited.connect(func(): drawing = false)

func _scale_factor() -> float:
	if reference_size.x <= 0 or reference_size.y <= 0:
		return 1.0
	return minf(size.x / reference_size.x, size.y / reference_size.y)

func _offset() -> Vector2:
	return (size - reference_size * _scale_factor()) * 0.5

func _to_draft(point: Vector2) -> Vector2:
	return (point - _offset()) / maxf(_scale_factor(), 0.001)

func _to_screen(point: Vector2) -> Vector2:
	return point * _scale_factor() + _offset()

func _can_draw(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) and not (
		is_instance_valid(excluded_control) and excluded_control.is_visible_in_tree()
		and excluded_control.get_global_rect().has_point(global_position + point))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _can_draw(event.position):
			if reference_size == Vector2.ZERO:
				reference_size = size
			strokes.append(PackedVector2Array([_to_draft(event.position)]))
			drawing = true
			changed.emit()
		else:
			drawing = false
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if not _can_draw(event.position):
			drawing = false
			return
		var point := _to_draft(event.position)
		if strokes[-1][-1].distance_to(point) >= 1.0:
			strokes[-1].append(point)
			queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = false
	elif event is InputEventMouseMotion and drawing:
		if not _can_draw(event.position - global_position):
			drawing = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		drawing = false

func _draw() -> void:
	# No paper rectangle: the running scene remains visible beneath the ink.
	var radius := BRUSH_RADIUS * _scale_factor()
	for stroke in strokes:
		if stroke.is_empty():
			continue
		var points := PackedVector2Array()
		for point in stroke:
			points.append(_to_screen(point))
		_draw_stroke(points, OUTLINE, radius + 1.5)
		_draw_stroke(points, INK, radius)

func _draw_stroke(points: PackedVector2Array, color: Color, radius: float) -> void:
	if points.size() > 1:
		draw_polyline(points, color, radius * 2.0, true)
	for point in points:
		draw_circle(point, radius, color)

func undo() -> void:
	drawing = false
	if not strokes.is_empty():
		strokes.pop_back()
		queue_redraw()
		changed.emit()

func clear() -> void:
	drawing = false
	strokes.clear()
	reference_size = Vector2.ZERO
	queue_redraw()
	changed.emit()

func has_drawing() -> bool:
	return not strokes.is_empty()

func _snapshot_bounds() -> Rect2:
	if not has_drawing():
		return Rect2()
	var bounds := Rect2(strokes[0][0], Vector2.ZERO)
	for stroke in strokes:
		for point in stroke:
			bounds = bounds.expand(point)
	bounds = bounds.grow(BRUSH_RADIUS)
	bounds = bounds.grow(maxf(12.0, maxf(bounds.size.x, bounds.size.y) * 0.06))
	return bounds

func snapshot_screen_rect() -> Rect2:
	if not has_drawing():
		return Rect2()
	var bounds := _snapshot_bounds()
	var side := maxf(bounds.size.x, bounds.size.y)
	var square := Rect2(bounds.get_center() - Vector2.ONE * side * 0.5, Vector2.ONE * side)
	return Rect2(global_position + _to_screen(square.position), square.size * _scale_factor())

func snapshot_png() -> PackedByteArray:
	if not has_drawing():
		return PackedByteArray()
	var bounds := _snapshot_bounds()
	var fit := float(IMAGE_SIZE - 1) / maxf(bounds.size.x, bounds.size.y)
	var padding := (Vector2.ONE * (IMAGE_SIZE - 1) - bounds.size * fit) * 0.5
	var bitmap := Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.TRANSPARENT)
	for stroke in strokes:
		for i in stroke.size():
			var end := (stroke[i] - bounds.position) * fit + padding
			var start := end if i == 0 else (stroke[i - 1] - bounds.position) * fit + padding
			var steps := maxi(1, ceili(start.distance_to(end)))
			for step in range(steps + 1):
				_stamp(bitmap, start.lerp(end, float(step) / steps), BRUSH_RADIUS * fit)
	return bitmap.save_png_to_buffer()

func _stamp(bitmap: Image, center: Vector2, radius: float) -> void:
	radius = maxf(radius, 0.75)
	for y in range(maxi(0, floori(center.y - radius)), mini(IMAGE_SIZE, ceili(center.y + radius) + 1)):
		for x in range(maxi(0, floori(center.x - radius)), mini(IMAGE_SIZE, ceili(center.x + radius) + 1)):
			if Vector2(x, y).distance_squared_to(center) <= radius * radius:
				bitmap.set_pixel(x, y, Color.BLACK)
