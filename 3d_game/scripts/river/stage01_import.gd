@tool
extends EditorScenePostImport

## The shared unlit materials import without vertex-color modulation in Godot
## 4.7.2. Enable the supplied COLOR_0 data in both editor and runtime views.
func _post_import(scene: Node) -> Object:
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is BaseMaterial3D:
				material.vertex_color_use_as_albedo = true
	return scene
