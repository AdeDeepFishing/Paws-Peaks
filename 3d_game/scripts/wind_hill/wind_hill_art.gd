extends Node3D

## Fraction of the delivered maximum wind deformation; 0 is the static base pose.
@export_range(0.0, 1.0, 0.05) var wind_strength := 0.8

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var label := str(node.name)
		# The path is a painted overlay on the terrain. Avoid overlapping colliders.
		# Wind-deformed branches keep their base-pose collision for this preview.
		if label == "Terrain_Ground" or label == "Branching_Tree_Trunks" or label.begins_with("Gouache_Rock"):
			node.create_trimesh_collision()
			for collider in node.find_children("*", "CollisionShape3D", true, false):
				if collider.shape is ConcavePolygonShape3D:
					collider.shape.backface_collision = true
	for animator in find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if "Strong_Wind_16s" in clip:
				# Keep the imported resource intact when the preview is re-entered.
				var animation: Animation = animator.get_animation(clip).duplicate(true)
				for track in animation.get_track_count():
					if animation.track_get_type(track) == Animation.TYPE_BLEND_SHAPE:
						for key in animation.track_get_key_count(track):
							animation.track_set_key_value(track, key, animation.track_get_key_value(track, key) * wind_strength)
				animation.loop_mode = Animation.LOOP_LINEAR
				var library := AnimationLibrary.new()
				library.add_animation("Wind", animation)
				animator.add_animation_library("Preview", library)
				clip = "Preview/Wind"
				animator.play(clip)
