extends RefCounted

const FOCUS_FOV := 40.0

## Fit the participants and the submitted sketch into one readable encounter shot.
static func add_box(points: Array[Vector3], box: AABB, transform: Transform3D = Transform3D.IDENTITY) -> void:
	for i in 8: points.append(transform * box.get_endpoint(i))

static func add_visual(points: Array[Vector3], node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		add_box(points, node.get_aabb(), node.global_transform)
	for child in node.get_children(): add_visual(points, child)

static func add_sketch(points: Array[Vector3], preview: Control, basis: Basis) -> void:
	if not preview.visible: return
	var size: Vector2 = preview.submitted_rect.size / maxf(preview.submitted_pixels_per_unit, 0.001)
	# Include the mist around the square reference image, not just the ink.
	var padding := maxf(size.x, size.y) * 0.25
	for x in [-size.x * 0.5 - padding, size.x * 0.5 + padding]:
		for y in [-padding, size.y + padding]:
			points.append(preview.world_anchor + basis.x * x + basis.y * y)

static func fit(camera: Camera3D, points: Array[Vector3], center_points: Array[Vector3], basis: Basis, preview: Control, fov: float = FOCUS_FOV, magnification_limit: float = 1.3, vertical_fill: float = 0.58) -> Transform3D:
	var inverse := basis.inverse()
	var bounds := AABB(inverse * center_points[0], Vector3.ZERO)
	for point in center_points: bounds = bounds.expand(inverse * point)
	var focus := basis * bounds.get_center()
	var viewport := camera.get_viewport().get_visible_rect().size
	var aspect := viewport.x / viewport.y
	var tangent_y := tan(deg_to_rad(fov) * 0.5)
	if camera.keep_aspect == Camera3D.KEEP_WIDTH: tangent_y /= aspect
	var tangent_x := tangent_y * aspect
	var distance := 8.0
	if preview.visible:
		# Even a tiny sketch should not suddenly inflate when the lens changes.
		distance = maxf(distance, viewport.y / (2.0 * tangent_y * maxf(preview.submitted_pixels_per_unit * magnification_limit, 0.001)))
	for point in points:
		var relative := inverse * (point - focus)
		distance = maxf(distance, relative.z + maxf(absf(relative.x) / (tangent_x * 0.82), absf(relative.y) / (tangent_y * vertical_fill)))
	return Transform3D(basis, focus + basis.z * (distance + 0.5))
