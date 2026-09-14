extends RefCounted

const MaterialPalette = preload("res://scripts/river/material_palette.gd")

const MAX_BYTES := 32 * 1024 * 1024

static func load_visual(path: String, span: float, crossing: bool, item: Dictionary = {}) -> Node3D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 20 or file.get_length() > MAX_BYTES:
		return null
	var bytes := file.get_buffer(file.get_length())
	if bytes.decode_u32(0) != 0x46546c67 or bytes.decode_u32(4) != 2 or bytes.decode_u32(8) != bytes.size():
		return null
	var json_length := bytes.decode_u32(12)
	if bytes.decode_u32(16) != 0x4e4f534a or json_length > bytes.size() - 20:
		return null
	var metadata = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	if not metadata is Dictionary:
		return null
	for key in ["skins", "buffers", "images"]:
		if not metadata.get(key, []) is Array:
			return null
	if not metadata.get("skins", []).is_empty():
		return null
	# Generated GLBs must be self-contained. Never follow external asset URIs.
	for entry in metadata.get("buffers", []) + metadata.get("images", []):
		if not entry is Dictionary or entry.has("uri"):
			return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(bytes, "", state) != OK:
		return null
	var source := document.generate_scene(state)
	if source == null:
		return null
	var result := Node3D.new()
	result.name = "GeneratedModel"
	_copy_meshes(source, Transform3D.IDENTITY, result)
	source.free()
	if result.get_child_count() == 0:
		result.free()
		return null
	var bounds := _bounds(result)
	if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.length() < 0.001:
		result.free()
		return null
	if crossing:
		var axis := bounds.size.max_axis_index()
		var orientation := Basis.IDENTITY
		if axis == 1:
			orientation = Basis(Vector3.FORWARD, PI / 2)
		elif axis == 2:
			orientation = Basis(Vector3.UP, PI / 2)
		for child in result.get_children():
			child.transform = Transform3D(orientation, Vector3.ZERO) * child.transform
		bounds = _bounds(result)
	var factor := span / maxf(bounds.size.x if crossing else bounds.size[bounds.size.max_axis_index()], 0.001)
	for child in result.get_children():
		child.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * factor), Vector3.ZERO) * child.transform
	bounds = _bounds(result)
	var offset := Vector3(-bounds.get_center().x, -_deck_height(result, bounds) if crossing else -bounds.position.y, -bounds.get_center().z)
	for child in result.get_children():
		child.position += offset
	if not item.is_empty() and not apply_palette(result, item):
		result.free()
		return null
	preload("res://scripts/river/generated_object_diagnostics.gd").attach(result)
	return result

static func apply_palette(visual: Node3D, item: Dictionary) -> bool:
	var material := MaterialPalette.material(item.get("texture_key", ""), item.get("color", ""))
	if material == null: return false
	for mesh in visual.get_children():
		mesh.material_override = material
	return true

static func physics_body(visual: Node3D, movable: bool, fit_mesh := false) -> PhysicsBody3D:
	var body: PhysicsBody3D
	if movable:
		var dynamic := RigidBody3D.new()
		dynamic.continuous_cd = true
		body = dynamic
	else:
		body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_child(visual)
	var bounds := _bounds(visual)
	var collider := CollisionShape3D.new()
	if fit_mesh:
		# Bake mesh transforms into a single convex hull in body-local space.
		var points := PackedVector3Array()
		for mesh in visual.get_children():
			for point in mesh.mesh.get_faces():
				points.append(mesh.transform * point)
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		collider.shape = shape
	else:
		var shape := BoxShape3D.new()
		shape.size = bounds.size.max(Vector3.ONE * 0.05)
		collider.shape = shape
		collider.position = bounds.get_center()
	body.add_child(collider)
	return body

static func _copy_meshes(node: Node, inherited: Transform3D, target: Node3D) -> void:
	var transform := inherited
	if node is Node3D:
		transform *= node.transform
	if node is MeshInstance3D and node.mesh != null:
		var mesh := MeshInstance3D.new()
		mesh.mesh = node.mesh
		mesh.transform = transform
		target.add_child(mesh)
	for child in node.get_children():
		_copy_meshes(child, transform, target)

static func _bounds(node: Node3D) -> AABB:
	var bounds: AABB = node.get_child(0).transform * node.get_child(0).get_aabb()
	for child in node.get_children():
		bounds = bounds.merge(child.transform * child.get_aabb())
	return bounds

# The topmost point is usually a railing, not the walkable deck. Choose the
# dominant horizontal surface by triangle area; sparse frames fall back to top.
static func _deck_height(root: Node3D, bounds: AABB) -> float:
	var buckets := {}
	for mesh in root.get_children():
		var faces: PackedVector3Array = mesh.mesh.get_faces()
		for i in range(0, faces.size() - 2, 3):
			var a: Vector3 = mesh.transform * faces[i]
			var b: Vector3 = mesh.transform * faces[i + 1]
			var c: Vector3 = mesh.transform * faces[i + 2]
			var normal := (b - a).cross(c - a)
			if normal.length() < 0.00001 or absf(normal.normalized().y) < 0.8: continue
			var y := (a.y + b.y + c.y) / 3.0
			var key := roundi(y / 0.08)
			buckets[key] = buckets.get(key, 0.0) + normal.length()
	var best := 0.0
	var height := bounds.end.y
	for key in buckets:
		if buckets[key] > best:
			best = buckets[key]
			height = float(key) * 0.08
	return height
