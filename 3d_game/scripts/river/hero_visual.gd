extends Node3D

const SOURCES := {
	"idle": preload("res://models/hero/listening.glb"),
	"walk": preload("res://models/hero/walk.glb"),
	"run": preload("res://models/hero/run.glb")
}
var animator: AnimationPlayer
var state := ""
var character: Node3D

func _ready() -> void:
	character = SOURCES.idle.instantiate()
	character.name = "Character"
	# Delivered character faces +Z; controller forward is -Z.
	character.rotation.y = PI
	character.scale = Vector3.ONE * (1.8 / 1.7)
	add_child(character)
	animator = character.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = character.find_child("Skeleton3D", true, false)
	var hips := skeleton.find_bone("Hips")
	var rest := skeleton.get_bone_rest(hips).origin
	var library := AnimationLibrary.new()
	for key in SOURCES:
		var source: Node = SOURCES[key].instantiate()
		var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
		var longest: Animation
		# Each delivery also contains a two-frame reset clip with a similar name.
		for name in player.get_animation_list():
			var clip := player.get_animation(name)
			if longest == null or clip.length > longest.length: longest = clip
		var animation: Animation = longest.duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":Hips"):
				for frame in animation.track_get_key_count(track):
					var position: Vector3 = animation.track_get_key_value(track, frame)
					# Keep vertical bounce but let CharacterBody3D own horizontal travel.
					position.x = rest.x
					position.z = rest.z
					animation.track_set_key_value(track, frame, position)
		library.add_animation(key, animation)
		source.free()
	# Keep a constant listening pose for the airborne fallback.
	var stand: Animation = library.get_animation("idle").duplicate(true)
	stand.length = 1.0
	for track in stand.get_track_count():
		while stand.track_get_key_count(track) > 1:
			stand.track_remove_key(track, stand.track_get_key_count(track) - 1)
		if stand.track_get_key_count(track) == 1:
			stand.track_set_key_time(track, 0, 0.0)
	# Import optimization can omit constant bone tracks. Restore those explicitly
	# so a bone animated only by running cannot retain its last running pose.
	for bone in skeleton.get_bone_count():
		var path := NodePath("Armature/Skeleton3D:" + skeleton.get_bone_name(bone))
		var bone_rest := skeleton.get_bone_rest(bone)
		var defaults := {
			Animation.TYPE_POSITION_3D: bone_rest.origin,
			Animation.TYPE_ROTATION_3D: bone_rest.basis.get_rotation_quaternion(),
			Animation.TYPE_SCALE_3D: bone_rest.basis.get_scale()
		}
		for type in defaults:
			var idle: Animation = library.get_animation("idle")
			if idle.find_track(path, type) == -1:
				var idle_track := idle.add_track(type)
				idle.track_set_path(idle_track, path)
				idle.track_insert_key(idle_track, 0.0, defaults[type])
			if stand.find_track(path, type) == -1:
				var track := stand.add_track(type)
				stand.track_set_path(track, path)
				stand.track_insert_key(track, 0.0, defaults[type])
	library.add_animation("stand", stand)
	animator.add_animation_library("gameplay", library)
	set_motion(false, false, true)

func set_motion(moving: bool, sprinting: bool, grounded: bool, thinking: bool = false) -> void:
	if animator == null: return
	var next := "run" if moving and sprinting else ("walk" if moving else "idle")
	if not grounded: next = "air"
	if thinking: next = "think"
	if next != state:
		state = next
		animator.speed_scale = 1.0
		var clip := "stand" if next == "air" else ("idle" if next == "think" else next)
		animator.play("gameplay/" + clip, 0.15)
		if next == "think":
			# Listening is a temporary drawing pose; Stand and Chat is reserved for E04.
			animator.speed_scale = 0.7
