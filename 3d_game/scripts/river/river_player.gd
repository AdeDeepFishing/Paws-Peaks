extends CharacterBody3D

## Movement follows the active level camera's horizontal axes.
## Each level owns its camera; the player never rotates or captures it.
@export var base_speed := 4.0
@export var sprint_speed := 6.0
@export var jump_velocity := 4.5
@export var turn_speed := 12.0
@export var idle_hop_delay := 0.8
@export var idle_hop_height := 0.55

const HOP_DURATION := 0.38
const HOP_GAP := 0.14
const HOP_COUNT := 3
const HOP_REST := 4.0

var input_enabled := true
var window_focused := true
var idle_seconds := 0.0
@onready var visual: Node3D = $Model

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	var direction := Vector3.ZERO
	if input_enabled and window_focused:
		var axes := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var camera := get_viewport().get_camera_3d()
		var yaw := camera.global_rotation.y if camera else 0.0
		direction = Basis(Vector3.UP, yaw) * Vector3(axes.x, 0, axes.y)
		if is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	if get_parent().has_method("assist_crossing"):
		direction = get_parent().assist_crossing(direction)
	var speed := sprint_speed if Input.is_action_pressed("sprint") else base_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	_update_idle_hops(delta, direction)
	if direction.length_squared() > 0.001:
		var facing := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	velocity.x = 0.0
	velocity.z = 0.0
	_reset_idle_hops()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
		if is_instance_valid(visual):
			_reset_idle_hops()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true

func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	idle_seconds = 0.0
	visual.position.y = 0.0

func _reset_idle_hops() -> void:
	idle_seconds = -idle_hop_delay
	visual.position.y = 0.0

func _update_idle_hops(delta: float, direction: Vector3) -> void:
	# Only the model hops: the grounded collider, camera and encounter state stay put.
	if not input_enabled or not window_focused or not is_on_floor() or direction.length_squared() > 0.001 or absf(velocity.y) > 0.1:
		_reset_idle_hops()
		return
	idle_seconds += delta
	if idle_seconds < 0.0:
		return
	var beat := HOP_DURATION + HOP_GAP
	var phase := fmod(idle_seconds, HOP_COUNT * beat + HOP_REST)
	var hop := floori(phase / beat)
	var progress := fmod(phase, beat) / HOP_DURATION
	visual.position.y = 0.0
	if hop < HOP_COUNT and progress < 1.0:
		visual.position.y = idle_hop_height * pow(0.82, hop) * 4.0 * progress * (1.0 - progress)
