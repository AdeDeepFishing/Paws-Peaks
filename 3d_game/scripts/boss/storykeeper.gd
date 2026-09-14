extends StaticBody3D

## Visual reactions only; dialogue and decisions live in the narrator service.
const IDLE_CLIP := "Storykeeper_RightHandLift_BodySway"
var animator: AnimationPlayer
var grounded := false

func _ready() -> void:
	animator = $Character.find_child("AnimationPlayer", true, false)
	if animator:
		for name in animator.get_animation_list():
			if IDLE_CLIP in name:
				var clip: Animation = animator.get_animation(name).duplicate(true)
				clip.loop_mode = Animation.LOOP_LINEAR
				var library := AnimationLibrary.new()
				library.add_animation("idle", clip)
				animator.add_animation_library("boss", library)
				animator.play("boss/idle")
				break
	_place_on_ground.call_deferred()

func _place_on_ground() -> void:
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 10.0, global_position + Vector3.DOWN * 10.0)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = hit.position.y
		grounded = true

var moved_aside := false

func express(emotion: String) -> void:
	# Use delivered clips when available; current asset safely retains its idle.
	var preferred: String = {"warm": "TalkWarm", "curious": "Listen", "amused": "Amused", "worried": "Plead", "hesitant": "Hesitate", "accepting": "Release"}.get(emotion, "Idle")
	for clip in animator.get_animation_list():
		if clip.get_file() == preferred:
			animator.play(clip, 0.25)
			return
	animator.play("boss/idle", 0.25)

func make_way() -> void:
	if moved_aside: return
	moved_aside = true
	express("accepting")
	# The game moves the wrapper; the delivered skeleton keeps its authored motion.
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:x", position.x - 3.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property($Character, "rotation:y", -0.35, 1.8).set_trans(Tween.TRANS_SINE)
