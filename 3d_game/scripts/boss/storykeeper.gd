extends StaticBody3D

## Supplied visual and idle loop only. Personality and dialogue belong to #63.
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
