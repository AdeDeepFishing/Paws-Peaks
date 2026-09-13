extends CharacterBody3D

## Movement follows the active level camera's horizontal axes.
## Each level owns its camera; the player never rotates or captures it.
@export var base_speed := 4.0
@export var sprint_speed := 7.5
@export var jump_velocity := 4.5
@export var turn_speed := 12.0
@export var idle_hop_delay := 5.0
@export var appearance_scale := 1.0
@export var auto_run_after := 3.0
@export var idle_hop_height := 0.55

const HOP_DURATION := 0.38
const HOP_GAP := 0.14
const HOP_COUNT := 3
const HOP_REST := 12.0

signal entrance_finished
var walking_in := false
var entrance_target := Vector3.ZERO
var input_enabled := true
var window_focused := true
var idle_seconds := 0.0
var moving_seconds := 0.0
var drawing_active := false
var jump_armed := true
@onready var visual: Node3D = $Model

func _ready() -> void:
	visual.scale = Vector3.ONE * appearance_scale
	_reset_idle_hops()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if not Input.is_action_pressed("jump"):
		jump_armed = true
	var direction := Vector3.ZERO
	if input_enabled and window_focused:
		var axes := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var camera := get_viewport().get_camera_3d()
		var yaw := camera.global_rotation.y if camera else 0.0
		direction = Basis(Vector3.UP, yaw) * Vector3(axes.x, 0, axes.y)
		if jump_armed and is_on_floor() and Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	if walking_in:
		var remaining := entrance_target - global_position
		remaining.y = 0
		direction = remaining.normalized() * minf(1.0, remaining.length() / maxf(base_speed * delta, 0.001))
		if remaining.length() < 0.06 and is_on_floor():
			walking_in = false
			direction = Vector3.ZERO
			set_input_enabled(true)
			entrance_finished.emit()
	if get_parent().has_method("assist_crossing"):
		direction = get_parent().assist_crossing(direction)
	var auto_running := moving_seconds > auto_run_after and is_on_floor()
	var speed := sprint_speed if auto_running or Input.is_action_pressed("sprint") else base_speed
	if walking_in: speed = base_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if get_parent().has_method("constrain_player"):
		get_parent().constrain_player(self)
	var travel := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	var moving := travel > 0.1 and direction.length_squared() > 0.001 and (walking_in or (input_enabled and window_focused))
	moving_seconds = moving_seconds + delta if moving and is_on_floor() else 0.0
	visual.set_motion(moving, not walking_in and moving_seconds > auto_run_after, is_on_floor(), drawing_active)
	_update_idle_hops(delta, direction)
	if direction.length_squared() > 0.001:
		var facing := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))

func set_drawing_active(active: bool) -> void:
	drawing_active = active
	moving_seconds = 0.0
	_reset_idle_hops()

func set_input_enabled(enabled: bool) -> void:
	if walking_in and enabled: return
	input_enabled = enabled
	moving_seconds = 0.0
	# Accept and jump share the south button; closing a panel must not jump.
	jump_armed = not Input.is_action_pressed("jump")
	velocity.x = 0.0
	velocity.z = 0.0
	_reset_idle_hops()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
		moving_seconds = 0.0
		if is_instance_valid(visual):
			_reset_idle_hops()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true

func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	moving_seconds = 0.0
	drawing_active = false
	_reset_idle_hops()

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

func walk_into_scene(start: Vector3, target: Vector3) -> void:
	respawn(start)
	set_input_enabled(false)
	entrance_target = target
	walking_in = true
	var direction := target - start
	visual.rotation.y = atan2(-direction.x, -direction.z)
