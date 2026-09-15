extends SceneTree

## Rebuild after changing the Chapter 5 mesh delivery. Uses the same shapes as
## MeshInstance3D.create_trimesh_collision(), without rebuilding during gameplay.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var level = load("res://scenes/moonlit_forest/moonlit_forest.tscn").instantiate()
	var art = level.get_node(level.art_path)
	var shapes := {}
	var elapsed := 0
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		if label == "Continuous_organic_forest_terrain" or label.begins_with("Painted_rounded_rock") or label.begins_with("Flowing_painted_trunk") or label.begins_with("Midground_painted_trunk") or label.begins_with("Buttress_root") or label.begins_with("Embedded_trail_edge_stone"):
			var start := Time.get_ticks_usec()
			var shape: ConcavePolygonShape3D = mesh.mesh.create_trimesh_shape()
			shape.backface_collision = true
			elapsed += Time.get_ticks_usec() - start
			shapes[str(art.get_path_to(mesh))] = shape
	var cache := Resource.new()
	cache.set_meta("shapes", shapes)
	var error := ResourceSaver.save(cache, "res://models/stage05/collision_shapes.res")
	print("FOREST COLLISION BAKE: ", shapes.size(), " shapes, build ms=", elapsed / 1000.0, ", save=", error)
	level.free()
	quit(error)
