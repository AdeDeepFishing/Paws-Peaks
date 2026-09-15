extends StaticBody3D

## Visual reactions only; dialogue and decisions live in the narrator service.
var animator: AnimationPlayer
var grounded := false
var anger_clip := ""
var moved_aside := false

const SOURCES := {
	"idle": preload("res://models/boss/behaviors/idle.glb"),
	"block": preload("res://models/boss/behaviors/block.glb"),
	"angry": preload("res://models/boss/behaviors/angry.glb"),
	"satisfied": preload("res://models/boss/behaviors/satisfied.glb")
}
var variants: Dictionary = {}
var behavior := ""

func _ready() -> void:
	_play("idle")
	_place_on_ground.call_deferred()

func _play(next: String) -> void:
	if behavior == next and animator and animator.is_playing(): return
	# These deliveries have different rigs and additional paper/heart nodes.
	# Keep each complete scene, with only the active scene visible and processing.
	if not variants.has(next):
		var model: Node3D = SOURCES[next].instantiate()
		$Character.add_child(model)
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		var selected := ""
		for clip in player.get_animation_list():
			if clip != "RESET": selected = clip
		var animation: Animation = player.get_animation(selected).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR if next == "idle" else Animation.LOOP_NONE
		var library := AnimationLibrary.new()
		library.add_animation("reaction", animation)
		player.add_animation_library("behavior", library)
		player.animation_finished.connect(func(_clip): _idle())
		variants[next] = {"model": model, "player": player}
	for key in variants:
		variants[key].model.visible = key == next
		if key != next: variants[key].player.stop()
	behavior = next
	animator = variants[next].player
	anger_clip = "behavior/reaction"
	animator.play("behavior/reaction")

func _idle() -> void:
	_play("idle")

func block_enter() -> void:
	if not moved_aside: _play("block")

func _place_on_ground() -> void:
	if get_parent().has_method("wait_until_prepared"):
		await get_parent().wait_until_prepared()
	await get_tree().physics_frame
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 10.0, global_position + Vector3.DOWN * 10.0)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		global_position.y = hit.position.y
		grounded = true

func express(emotion: String) -> void:
	if moved_aside:
		if emotion in ["accepting", "amused", "warm"]: _play("satisfied")
		return
	if emotion == "angry": _play("angry")
	elif emotion in ["warm", "accepting", "amused"]: _play("satisfied")
	else: _idle()

func make_way() -> void:
	if moved_aside: return
	moved_aside = true
	_play("satisfied")
	# Move the body and its collider together to open the path.
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", PI / 2.0, 1.8)
	tween.tween_property(self, "position:x", position.x - 1.5, 1.8)
	tween.finished.connect(_place_on_ground)
