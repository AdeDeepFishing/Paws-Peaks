extends Control

signal changed

const IMAGE_SIZE := 512
const PAPER := Color("fff9ed")
const INK := Color("293e3b")
const BRUSH_RADIUS := 3.0

var strokes: Array[PackedVector2Array] = []
var drawing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			strokes.append(PackedVector2Array([_to_image(event.position)]))
			drawing = true
			changed.emit()
		else:
			drawing = false
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and drawing:
		if not Rect2(Vector2.ZERO, size).has_point(event.position):
			drawing = false
			return
		var point := _to_image(event.position)
		if strokes[-1][-1].distance_to(point) >= 1.0:
			strokes[-1].append(point)
			queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		drawing = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_VISIBILITY_CHANGED:
		drawing = false

func _to_image(point: Vector2) -> Vector2:
	return (point / size * IMAGE_SIZE).clamp(Vector2.ZERO, Vector2.ONE * (IMAGE_SIZE - 1))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var scale_factor := size.x / IMAGE_SIZE
	for stroke in strokes:
		if stroke.is_empty():
			continue
		var points := PackedVector2Array()
		for point in stroke:
			points.append(point * size / IMAGE_SIZE)
		if points.size() > 1:
			draw_polyline(points, INK, BRUSH_RADIUS * 2.0 * scale_factor, true)
		for point in points:
			draw_circle(point, BRUSH_RADIUS * scale_factor, INK)

func undo() -> void:
	drawing = false
	if not strokes.is_empty():
		strokes.pop_back()
		queue_redraw()
		changed.emit()

func clear() -> void:
	drawing = false
	strokes.clear()
	queue_redraw()
	changed.emit()

func has_drawing() -> bool:
	return not strokes.is_empty()

func snapshot_png() -> PackedByteArray:
	if not has_drawing():
		return PackedByteArray()
	var bitmap := Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGB8)
	bitmap.fill(PAPER)
	for stroke in strokes:
		for i in stroke.size():
			var end := stroke[i]
			var start := end if i == 0 else stroke[i - 1]
			var steps := maxi(1, ceili(start.distance_to(end)))
			for step in range(steps + 1):
				_stamp(bitmap, start.lerp(end, float(step) / steps))
	return bitmap.save_png_to_buffer()

func _stamp(bitmap: Image, center: Vector2) -> void:
	for y in range(maxi(0, floori(center.y - BRUSH_RADIUS)), mini(IMAGE_SIZE, ceili(center.y + BRUSH_RADIUS) + 1)):
		for x in range(maxi(0, floori(center.x - BRUSH_RADIUS)), mini(IMAGE_SIZE, ceili(center.x + BRUSH_RADIUS) + 1)):
			if Vector2(x, y).distance_squared_to(center) <= BRUSH_RADIUS * BRUSH_RADIUS:
				bitmap.set_pixel(x, y, INK)
