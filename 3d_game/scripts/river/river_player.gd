extends "res://addons/proto_controller/proto_controller.gd"

## Third-person movement for the river prototype. The camera and visual facing
## are independent, so orbiting while idle never rotates the character body.
@export var camera_distance := 5.0
@export var turn_speed := 12.0

const DEFAULT_PITCH := -0.28
var input_enabled := true

@onready var visual: Node3D = $Model
@onready var arm: SpringArm3D = $Head/SpringArm3D
@onready var camera: Camera3D = $Head/SpringArm3D/Camera3D

func _ready() -> void:
	super._ready()
	arm.add_excluded_object(get_rid())
	arm.spring_length = camera_distance
	look_rotation = Vector2(DEFAULT_PITCH, 0.0)
	_update_camera_rotation()
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		capture_mouse()
	if event is InputEventMouseMotion and mouse_captured:
		rotate_look(event.relative)

func rotate_look(motion: Vector2) -> void:
	look_rotation.x = clampf(look_rotation.x - motion.y * look_speed, deg_to_rad(-55), deg_to_rad(15))
	look_rotation.y = wrapf(look_rotation.y - motion.x * look_speed, -PI, PI)
	_update_camera_rotation()

func _update_camera_rotation() -> void:
	head.rotation = Vector3(look_rotation.x, look_rotation.y, 0.0)

func _physics_process(delta: float) -> void:
	if has_gravity and not is_on_floor():
		velocity += get_gravity() * delta
	var direction := Vector3.ZERO
	if can_move and input_enabled and mouse_captured:
		var axes := Input.get_vector(input_left, input_right, input_forward, input_back)
		direction = Basis(Vector3.UP, look_rotation.y) * Vector3(axes.x, 0, axes.y)
		if can_jump and is_on_floor() and Input.is_action_just_pressed(input_jump):
			velocity.y = jump_velocity
	move_speed = sprint_speed if can_sprint and Input.is_action_pressed(input_sprint) else base_speed
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()
	if direction.length_squared() > 0.001:
		var facing := atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-turn_speed * delta))
	# Avoid seeing inside the placeholder if the camera is compressed against a wall.
	visual.visible = arm.get_hit_length() > 0.8

func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	velocity.x = 0.0
	velocity.z = 0.0
	if not enabled:
		release_mouse()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_mouse()

func respawn(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	look_rotation = Vector2(DEFAULT_PITCH, 0.0)
	rotation = Vector3.ZERO
	visual.rotation = Vector3.ZERO
	_update_camera_rotation()
