extends "res://addons/proto_controller/proto_controller.gd"

var input_enabled := true

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		capture_mouse()
	if event is InputEventMouseMotion and mouse_captured:
		rotate_look(event.relative)

func _physics_process(delta: float) -> void:
	if input_enabled and mouse_captured:
		super._physics_process(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()

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
	look_rotation = Vector2.ZERO
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
