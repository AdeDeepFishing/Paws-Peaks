extends Node3D

## Fraction of the delivered maximum wind deformation; 0 is the static base pose.
@export_range(0.0, 1.0, 0.05) var wind_strength := 0.8

const CLOUD_DRIFT_SECONDS := 64.0

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var label := str(node.name)
		# The path is a painted overlay on the terrain. Avoid overlapping colliders.
		# Wind-deformed branches keep their base-pose collision for this preview.
		if label == "Terrain_Ground" or label == "Branching_Tree_Trunks" or label.begins_with("Gouache_Rock"):
			node.create_trimesh_collision()
			if label == "Terrain_Ground":
				for body in node.find_children("*", "StaticBody3D", true, false):
					body.set_collision_layer_value(2, true)
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
				_separate_cloud_drift(animator, animation)
				animation.loop_mode = Animation.LOOP_LINEAR
				var library := AnimationLibrary.new()
				library.add_animation("Wind", animation)
				animator.add_animation_library("Preview", library)
				clip = "Preview/Wind"
				animator.play(clip)

func _separate_cloud_drift(wind_player: AnimationPlayer, wind: Animation) -> void:
	var drift := Animation.new()
	drift.length = CLOUD_DRIFT_SECONDS
	drift.loop_mode = Animation.LOOP_LINEAR
	# Cloud translation and baked cloud morphs both have mismatched endpoints.
	# Keep the rest of the wind and feathers on their original clock.
	for track in range(wind.get_track_count() - 1, -1, -1):
		var type := wind.track_get_type(track)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_BLEND_SHAPE:
			continue
		var path := wind.track_get_path(track)
		if not str(path.get_name(path.get_name_count() - 1)).begins_with("Cloud_Layer_"):
			continue
		var cloud_track := drift.add_track(type)
		drift.track_set_path(cloud_track, path)
		# A cosine drift stays within the delivered composition and slows to zero
		# at both turns. A plain ping-pong loop would reverse velocity abruptly.
		for key in 129:
			var phase := float(key) / 128.0
			var weight := 0.5 - 0.5 * cos(TAU * phase)
			var source_time := wind.length * weight
			if type == Animation.TYPE_POSITION_3D:
				drift.position_track_insert_key(cloud_track, CLOUD_DRIFT_SECONDS * phase, wind.position_track_interpolate(track, source_time))
			else:
				drift.blend_shape_track_insert_key(cloud_track, CLOUD_DRIFT_SECONDS * phase, wind.blend_shape_track_interpolate(track, source_time))
		wind.track_set_enabled(track, false)
	if drift.get_track_count() == 0:
		return
	var library := AnimationLibrary.new()
	library.add_animation("Drift", drift)
	var cloud_player := AnimationPlayer.new()
	cloud_player.name = "CloudDriftPlayer"
	cloud_player.root_node = wind_player.root_node
	cloud_player.add_animation_library("", library)
	wind_player.get_parent().add_child(cloud_player)
	cloud_player.play("Drift")
