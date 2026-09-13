@tool
extends "res://scripts/river/stage01_import.gd"

const PAINT_SHADER = preload("res://scripts/sunset_cove/mirrored_paint.gdshader")
const MIRRORED_MATERIALS := [
	"Continuous_Gouache_Sunset", "Sand_Drybrush", "Ground_Foliage_Paint",
	"Bark_Broad_Brush", "Stone_Gouache", "Distant_Hill_Brush", "Painted_Water_Base",
]

func _post_import(scene: Node) -> Object:
	super._post_import(scene)
	var converted := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if not material is BaseMaterial3D or material.resource_name not in MIRRORED_MATERIALS:
				continue
			if not converted.has(material):
				var painted := ShaderMaterial.new()
				painted.resource_name = material.resource_name
				painted.shader = PAINT_SHADER
				painted.set_shader_parameter("paint", material.albedo_texture)
				painted.set_shader_parameter("tint", material.albedo_color)
				if material.resource_name == "Continuous_Gouache_Sunset":
					painted.set_shader_parameter("mirror_axes", Vector2(1, 0))
					painted.set_shader_parameter("drifting_sky", true)
				if material.resource_name == "Painted_Water_Base":
					painted.set_shader_parameter("flowing_water", true)
				converted[material] = painted
			node.set_surface_override_material(surface, converted[material])
	return scene
