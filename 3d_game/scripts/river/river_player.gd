extends CharacterBody3D

## Movement follows the active level camera's horizontal axes.
## Each level owns its camera; the player never rotates or captures it.
@export var base_speed := 4.0
@export var sprint_speed := 6.0
@export var jump_velocity := 4.5
@export var turn_speed := 12.0

var input_enabled := true
var window_focused := true
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
	var speed := sprint_speed if Input.is_action_pressed("sprint") else base_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	if direction.length_squared() > 0.001:
		var facing := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	velocity.x = 0.0
	velocity.z = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		window_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		window_focused = true

func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	visual.rotation = Vector3.ZERO
