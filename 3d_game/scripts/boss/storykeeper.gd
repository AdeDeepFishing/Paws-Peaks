extends StaticBody3D

## Visual reactions only; dialogue and decisions live in the narrator service.
var animator: AnimationPlayer
var grounded := false
var anger_clip := ""
var moved_aside := false

func _ready() -> void:
	animator = $Character.find_child("AnimationPlayer", true, false)
	if animator:
		for clip in animator.get_animation_list():
			if "BlockPageCycle" in clip:
				anger_clip = clip
				animator.get_animation(clip).loop_mode = Animation.LOOP_NONE
		animator.animation_finished.connect(func(_clip): _idle())
		_idle()
	_place_on_ground.call_deferred()

func _idle() -> void:
	if anger_clip.is_empty(): return
	animator.play(anger_clip)
	animator.seek(0.0,true)
	animator.pause()

func _place_on_ground() -> void:
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 10.0, global_position + Vector3.DOWN * 10.0)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = hit.position.y
		grounded = true

func express(emotion: String) -> void:
	if emotion == "angry" and not moved_aside and not anger_clip.is_empty():
		animator.play(anger_clip,0.2)
		animator.seek(0.0,true)
	elif not animator.is_playing():
		_idle()

func make_way() -> void:
	if moved_aside: return
	moved_aside = true
	_idle()
	# Move the body and its collider together to open the path.
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", PI / 2.0, 1.8)
	tween.tween_property(self, "position:x", position.x - 1.5, 1.8)
	tween.finished.connect(_place_on_ground)
