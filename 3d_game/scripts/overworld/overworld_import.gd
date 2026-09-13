@tool
extends EditorScenePostImport

func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in node.mesh.get_surface_count():
			var original: Material = node.mesh.surface_get_material(surface)
			var index := original.resource_name.trim_prefix("Palette_").to_int()
			var material: Material = load("res://models/overworld/materials/palette_%02d.tres" % index)
			node.mesh.surface_set_material(surface, material)
	return scene
