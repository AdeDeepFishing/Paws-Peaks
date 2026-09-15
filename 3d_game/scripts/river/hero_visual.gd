extends Node3D

const SOURCES := {
	"idle_variant": preload("res://models/hero/behaviors/idle_variant.glb"),
	"walk": preload("res://models/hero/behaviors/walk.glb"),
	"run": preload("res://models/hero/behaviors/run.glb"),
	"greet": preload("res://models/hero/behaviors/greet.glb"),
	"chat": preload("res://models/hero/behaviors/chat.glb"),
	"boss_talk": preload("res://models/hero/behaviors/boss_talk.glb"),
	"knockdown": preload("res://models/hero/behaviors/knockdown.glb"),
	"arise": preload("res://models/hero/behaviors/arise.glb"),
	"celebrate": preload("res://models/hero/behaviors/celebrate.glb")
}
const ONE_SHOTS := ["greet", "knockdown", "arise", "celebrate"]
var animator: AnimationPlayer
var state := ""
var character: Node3D
var standing_model: Node3D
var action := ""
var conversation := ""
var idle_time := 0.0
var action_time := 0.0
var blocks_movement: bool:
	get: return action in ["knockdown", "arise"]

func _ready() -> void:
	character = SOURCES.idle_variant.instantiate()
	character.name = "Character"
	# Delivered characters face +Z; controller forward is -Z.
	character.rotation.y = PI
	character.scale = Vector3.ONE * (1.8 / 1.7)
	add_child(character)
	standing_model = preload("res://models/hero/behaviors/stand.glb").instantiate()
	standing_model.rotation.y = PI
	standing_model.scale = character.scale
	add_child(standing_model)
	# The static stand was exported at a different scale from the rigged clips.
	var rig_bounds := _bounds(character)
	var stand_bounds := _bounds(standing_model)
	standing_model.scale *= rig_bounds.size.y / maxf(stand_bounds.size.y, 0.001)
	standing_model.position.y += rig_bounds.position.y - _bounds(standing_model).position.y
	animator = character.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = character.find_child("Skeleton3D", true, false)
	var rest := skeleton.get_bone_rest(skeleton.find_bone("Hips")).origin
	var library := AnimationLibrary.new()
	for key in SOURCES:
		var source: Node = SOURCES[key].instantiate()
		var player: AnimationPlayer = source.find_child("AnimationPlayer", true, false)
		var longest: Animation
		# Each rigged delivery also contains a two-frame reset clip.
		for name in player.get_animation_list():
			var clip := player.get_animation(name)
			if longest == null or clip.length > longest.length: longest = clip
		var animation: Animation = longest.duplicate(true)
		animation.loop_mode = Animation.LOOP_NONE if key in ONE_SHOTS else Animation.LOOP_LINEAR
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)).ends_with(":Hips"):
				for frame in animation.track_get_key_count(track):
					var position: Vector3 = animation.track_get_key_value(track, frame)
					# Keep authored vertical motion; the capsule owns horizontal travel.
					position.x = rest.x
					position.z = rest.z
					animation.track_set_key_value(track, frame, position)
		# Import optimization omits constant tracks. Reset them for every action so
		# a limb used only by a previous action cannot retain its old pose.
		for bone in skeleton.get_bone_count():
			var path := NodePath("Armature/Skeleton3D:" + skeleton.get_bone_name(bone))
			var bone_rest := skeleton.get_bone_rest(bone)
			var defaults := {
				Animation.TYPE_POSITION_3D: bone_rest.origin,
				Animation.TYPE_ROTATION_3D: bone_rest.basis.get_rotation_quaternion(),
				Animation.TYPE_SCALE_3D: bone_rest.basis.get_scale()
			}
			for type in defaults:
				if animation.find_track(path, type) == -1:
					var track := animation.add_track(type)
					animation.track_set_path(track, path)
					animation.track_insert_key(track, 0.0, defaults[type])
		library.add_animation(key, animation)
		source.free()
	# The default stand delivery has no rig or animation; display its static mesh.
	for key in ["idle", "stand"]:
		var pose: Animation = library.get_animation("idle_variant").duplicate(true)
		for track in pose.get_track_count():
			while pose.track_get_key_count(track) > 1:
				pose.track_remove_key(track, pose.track_get_key_count(track) - 1)
			if pose.track_get_key_count(track): pose.track_set_key_time(track, 0, 0.0)
		pose.length = 1.0
		pose.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(key, pose)
	animator.add_animation_library("gameplay", library)
	animator.animation_finished.connect(_action_finished)
	set_motion(false, false, true)

func _process(delta: float) -> void:
	if action == "knockdown":
		action_time += delta
		# Bound the long help performance, then play the complete getting-up clip.
		if action_time >= 2.0: play_action("arise")
	if state in ["idle", "idle_variant"]:
		idle_time += delta
		if idle_time >= 6.0 + animator.get_animation("gameplay/idle_variant").length:
			idle_time = 0.0
	else:
		idle_time = 0.0

func set_motion(moving: bool, sprinting: bool, grounded: bool, thinking: bool = false) -> void:
	if animator == null: return
	if thinking or ((moving or not grounded) and not blocks_movement): cancel_action()
	var next := "run" if moving and sprinting else ("walk" if moving else "idle")
	if not moving and idle_time >= 6.0: next = "idle_variant"
	if not grounded: next = "air"
	if not moving and grounded and not conversation.is_empty(): next = conversation
	if not action.is_empty(): next = action
	if thinking: next = "think"
	_play(next)

func _play(next: String) -> void:
	if next == state: return
	state = next
	character.visible = next not in ["idle", "air"]
	standing_model.visible = not character.visible
	animator.speed_scale = 0.7 if next == "think" else 1.0
	var clip := "stand" if next == "air" else ("idle_variant" if next == "think" else next)
	animator.play("gameplay/" + clip, 0.15)

func play_action(next: String) -> void:
	if next not in ONE_SHOTS: return
	if blocks_movement and next != "arise": return
	action = next
	action_time = 0.0
	_play(next)

func cancel_action() -> void:
	action = ""
	action_time = 0.0

func _action_finished(clip: StringName) -> void:
	if str(clip) != "gameplay/" + action: return
	if action == "knockdown":
		play_action("arise")
	else:
		cancel_action()
		_play("idle")

## Kept for encounter reset callers; authored reactions replace mesh squashing.
func set_avoidance(_amount: float) -> void:
	pass

func _bounds(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
