extends Node3D

const MODEL = preload("res://models/otter/otter.scn")
const ANIMATIONS = preload("res://models/otter/animations.res")
const IDLE := "otter/Idle_11"
const WAVE := "otter/Big_Wave_Hello"

@export var approach_distance := 2.5
@export var visual_height := 2.2

var animation_options: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://models/otter/animations.json"))
var animator: AnimationPlayer
var phase := "idle"
var grounded := false
var elapsed := 0.0
@onready var player: Node3D = get_parent().get_node("Player")

func _ready() -> void:
	var model := MODEL.instantiate()
	add_child(model)
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var factor := visual_height / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * factor
	model.position.y = -(bounds.position.y - global_position.y) * factor
	animator = model.find_child("AnimationPlayer", true, false)
	animator.add_animation_library("otter", ANIMATIONS)
	animator.animation_finished.connect(func(_clip: StringName):
		if phase == "waiting": animator.play("otter/Confused_Scratch", 0.25)
		elif phase == "waving": animator.play(WAVE, 0.25)
	)
	animator.play(IDLE)
	_place_on_sand.call_deferred()

func _place_on_sand() -> void:
	await get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 20, global_position + Vector3.DOWN * 20, 1)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		push_error("Otter greeting position needs solid ground")
		return
	global_position.y = hit.position.y
	grounded = true
	_face_player(1.0)

func _physics_process(delta: float) -> void:
	if not grounded: return
	_face_player(1.0 - exp(-delta * 6.0))
	var distance := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if phase == "reacting":
		elapsed += delta
		if elapsed >= reaction_seconds:
			phase = "idle"
			animator.play(IDLE, 0.25)
	elif phase != "waiting":
		var next_phase := "waving" if distance > approach_distance else "idle"
		if phase != next_phase:
			phase = next_phase
			animator.play(WAVE if phase == "waving" else IDLE, 0.25)

func _face_player(weight: float) -> void:
	var direction := player.global_position - global_position
	if Vector2(direction.x, direction.z).length_squared() > 0.001:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), weight)

var reaction_seconds := 0.0

func play_option(key: String) -> bool:
	if not animation_options.has(key) or not animator.has_animation("otter/" + key):
		return false
	phase = "reacting"
	elapsed = 0.0
	reaction_seconds = animator.get_animation("otter/" + key).length
	animator.play("otter/" + key, 0.25)
	return true

func wait_for_drawing() -> void:
	phase = "waiting"
	animator.play("otter/Confused_Scratch", 0.25)

func stop_waiting() -> void:
	if phase == "waiting":
		phase = "idle"
		animator.play(IDLE, 0.25)
