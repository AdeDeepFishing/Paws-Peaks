@tool
extends "res://scripts/river/stage01_import.gd"

func _post_import(scene: Node) -> Object:
	super._post_import(scene)
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for surface in node.mesh.get_surface_count():
			var material = node.get_active_material(surface)
			if material is BaseMaterial3D:
				# Original Canvas PNGs use the opposite V origin to glTF images.
				material.uv1_scale = Vector3(1, -1, 1)
				material.uv1_offset = Vector3(0, 1, 0)
				# glTF does not retain Three.js BackSide on the surrounding sky dome.
				if material.resource_name == "Gouache_Sky":
					material.cull_mode = BaseMaterial3D.CULL_FRONT
	return scene
