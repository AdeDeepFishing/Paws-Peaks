extends Node3D

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var label := str(node.name)
		if label == "Terrain_walkable_terrace" or label == "Hero_oak_sculpted_trunk" or label == "Fence_rough_hewn_wood" or (label.begins_with("Silver_birch_") and label.ends_with("_trunk")) or (label.begins_with("Rock_") and label.ends_with("_body")):
			node.create_trimesh_collision()
			if label == "Terrain_walkable_terrace":
				# Layer 2 is terrain-only for the dog's ground probe. Keep layer 1
				# enabled so ordinary player collision remains unchanged.
				for body in node.find_children("*", "StaticBody3D", true, false):
					body.set_collision_layer_value(2, true)
			for collider in node.find_children("*", "CollisionShape3D", true, false):
				if collider.shape is ConcavePolygonShape3D:
					collider.shape.backface_collision = true
	for animator in find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if "Breeze_8s" in clip:
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
