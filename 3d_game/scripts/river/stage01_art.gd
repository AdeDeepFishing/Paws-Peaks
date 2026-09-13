extends Node3D

## Keep paint overlays and water visual-only. Terrain and solid props use
## the delivered geometry, so slopes and shore edges match the artwork.
func _ready() -> void:
	# Move the far-bank bridge obstruction as one painted prop. Its collision
	# is generated below after relocation, so the old bridgehead stays clear.
	for label in ["Lavender_boulder_06", "Lavender_boulder_06_dry_brush"]:
		var rock := find_child(label, true, false) as Node3D
		if rock:
			rock.global_position += Vector3(5, 0, -5)
	for node in find_children("*", "MeshInstance3D", true, false):
		var label := String(node.name)
		if label.ends_with("_bank_meadow") or label.ends_with("_bank_painted_cliff") or label.ends_with("_painted_branches") or (label.begins_with("Lavender_boulder_") and not label.ends_with("_dry_brush")):
			node.create_trimesh_collision()
			# Mirrored bank geometry has opposite winding. Match its double-sided
			# visual material so both shore meshes support the player from above.
			for shape in node.find_children("*", "CollisionShape3D", true, false):
				if shape.shape is ConcavePolygonShape3D:
					shape.shape.backface_collision = true
	for player in find_children("*", "AnimationPlayer", true, false):
		for clip in player.get_animation_list():
			if "Creek_HandDrawn" in clip:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				player.play(clip)
