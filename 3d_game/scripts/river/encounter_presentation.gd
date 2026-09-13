extends Node

signal settled
var busy := false
var holding := false
var epoch := 0
var tween: Tween
var overview: Transform3D
var overview_size := 18.6
var home: Transform3D
var home_size := 18.6
@export var duration_scale := 1.0
@onready var level = get_parent()
@onready var camera: Camera3D = level.get_node("StageCamera")

func _ready() -> void:
	home = camera.transform
	overview = camera.transform
	home_size = camera.size
	overview_size = camera.size

func begin(anchor: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	holding = true
	home = camera.transform
	home_size = camera.size
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(anchor, 12.0, 2.0)
	if token != epoch: return
	busy = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	# Keep this camera framing until the request resolves. Exploration and the
	# Stop waiting action remain available after the initial camera movement.
	settled.emit()

func reveal(target: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	if not holding:
		home = camera.transform
		home_size = camera.size
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(target, 12.0, 0.45)
	if token != epoch: return
	if level.bridge_built: level.bridge.show()
	if is_instance_valid(level.generated_visual):
		level.generated_visual.show()
	level.generation_preview.model_presented()
	await get_tree().create_timer(2.0 * duration_scale).timeout
	if token != epoch: return
	await _restore(1.0)
	if token != epoch: return
	busy = false
	holding = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	settled.emit()

func cancel() -> void:
	epoch += 1
	if tween and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	if busy or holding:
		camera.transform = home
		camera.size = home_size
	busy = false
	holding = false
	if is_instance_valid(level.normal_hud): level.normal_hud.show()
	if is_instance_valid(level.player): level.player.set_input_enabled(true)
	settled.emit()

func _focus(target: Vector3, size: float, seconds: float) -> void:
	var midpoint := get_viewport().get_visible_rect().size * 0.5
	var center = Plane(Vector3.UP, target.y).intersects_ray(camera.project_ray_origin(midpoint), camera.project_ray_normal(midpoint))
	var destination := camera.position
	if center is Vector3: destination += target - center
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", destination, seconds * duration_scale)
	tween.tween_property(camera, "size", size, seconds * duration_scale)
	await tween.finished

func _restore(seconds: float) -> void:
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", home, seconds * duration_scale)
	tween.tween_property(camera, "size", home_size, seconds * duration_scale)
	await tween.finished

func follow_player(delta: float) -> void:
	if busy or holding or level.panel_mode != "": return
	var viewport := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(level.player.global_position)
	var safe := screen.clamp(viewport * 0.22, viewport * 0.78)
	if screen.distance_to(safe) < 1.0: return
	var plane := Plane(Vector3.UP, level.player.position.y)
	var at = plane.intersects_ray(camera.project_ray_origin(safe), camera.project_ray_normal(safe))
	if at is Vector3:
		camera.position += (level.player.position - at) * minf(delta * 5, 1)
