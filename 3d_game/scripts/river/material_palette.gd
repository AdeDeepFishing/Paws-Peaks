extends RefCounted

const DIRECTORY := "res://assets/materials/"
static var _entries: Dictionary = {}

static func entries() -> Dictionary:
	if _entries.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "palette.json"))
		if parsed is Dictionary: _entries = parsed
	return _entries

static func valid_selection(key: Variant, tint: Variant) -> bool:
	return key is String and entries().has(key) and tint is String and tint.length() == 7 and tint.begins_with("#") and Color.html_is_valid(tint)

static func material(key: String, tint: String) -> StandardMaterial3D:
	if not valid_selection(key, tint): return null
	var preset: Dictionary = entries()[key]
	var texture := load(DIRECTORY + key + ".png") as Texture2D
	if texture == null: return null
	var result := StandardMaterial3D.new()
	result.albedo_texture = texture
	result.albedo_color = Color(tint)
	result.roughness = preset.roughness
	result.metallic = preset.metallic
	result.metallic_specular = 0.25
	result.uv1_triplanar = true
	result.uv1_world_triplanar = false
	result.uv1_scale = Vector3.ONE * 2.0
	result.texture_repeat = true
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return result
