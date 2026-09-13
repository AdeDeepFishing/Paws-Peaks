extends AnimatableBody3D

signal collected
signal state_changed(state: String)

const CLIPS := {"idle": "Idle", "alert": "Idle_Alert", "walk": "Walk", "run": "Run", "jump": "Jump", "rest": "Rest_Pose"}
const ALERT_RADIUS := 13.0
const INTERCEPT_RADIUS := 10.0
const PATROL_RADII := Vector2(3.2, 1.8)
const GROUND_MASK := 2
const WALK_SPEED := 2.6
const RUN_SPEED := 10.0

var state := "idle"
var state_time := 0.0
var patrol_phase := 0.0
var home: Vector3
var target: Vector3
var offering_position: Vector3
var distracted := false
var solved := false
var paused := false:
	set(value):
		paused = value
		if animator:
			animator.speed_scale = 0.0 if value else 1.0
var animator: AnimationPlayer
var player: Node3D
@onready var character: Node3D = $Character

func _ready() -> void:
	# Motion is advanced in physics; the visual root carries authored bone motion.
	sync_to_physics = false
	home = global_position
	player = get_parent().get_node("Player")
	animator = character.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = character.find_child("Skeleton3D", true, false)
	var hips := skeleton.find_bone("Hips")
	var origin := skeleton.get_bone_rest(hips).origin
	var library := AnimationLibrary.new()
	for key in CLIPS:
		var clip: Animation = animator.get_animation(CLIPS[key]).duplicate(true)
		clip.loop_mode = Animation.LOOP_NONE if key in ["jump", "rest"] else Animation.LOOP_LINEAR
		for track in clip.get_track_count():
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)).ends_with(":Hips"):
				for frame in clip.track_get_key_count(track):
					var position: Vector3 = clip.track_get_key_value(track, frame)
					# Keep the hop; movement through the world belongs to this body.
					position.x = origin.x
					position.z = origin.z
					clip.track_set_key_value(track, frame, position)
		library.add_animation(key, clip)
	animator.add_animation_library("encounter", library)
	animator.play("encounter/idle")

func _physics_process(delta: float) -> void:
	if paused:
		return
	state_time += delta
	if solved:
		_face(offering_position - global_position, delta)
		return
	if distracted:
		if state == "jump":
			if state_time >= animator.get_animation("encounter/jump").length:
				_set_state("fetch_run", "run")
			return
		var remaining := _flat_distance(global_position, target)
		if remaining < 0.12:
			solved = true
			_set_state("content", "idle")
			collected.emit()
			return
		var slow := remaining < 1.7
		_set_state("fetch_walk" if slow else "fetch_run", "walk" if slow else "run")
		_move_toward(target, WALK_SPEED if slow else RUN_SPEED, delta)
		return
	# Measure from the guard post, not the circling dog, to avoid false approaches.
	# A wider release radius prevents repeated patrol/alert changes at the edge.
	var guarding := state in ["alert", "block_walk", "block_run"]
	var radius := ALERT_RADIUS if guarding else INTERCEPT_RADIUS
	var near := _flat_distance(player.global_position, home) < radius or player.global_position.z < home.z + 7.0
	if not near:
		_patrol(delta)
		return
	if state in ["idle", "patrol"]:
		_set_state("alert", "alert")
		return
	# Let the warning pose read before moving across the player's route.
	if state == "alert" and state_time < 0.65:
		_face(player.global_position - global_position, delta)
		return
	var intercept := Vector3(player.global_position.x, home.y, home.z)
	var distance := _flat_distance(global_position, intercept)
	if distance > 0.35:
		var running := distance > 2.3
		_set_state("block_run" if running else "block_walk", "run" if running else "walk")
		_move_toward(intercept, RUN_SPEED if running else WALK_SPEED, delta)
	else:
		_set_state("alert", "alert")
		_face(player.global_position - global_position, delta)

func _patrol(delta: float) -> void:
	_set_state("patrol", "walk")
	var waypoint := _patrol_position()
	# Rejoin the interrupted circuit by walking, without snapping or skipping ahead.
	if _flat_distance(global_position, waypoint) < 0.1:
		var tangent := Vector2(PATROL_RADII.x * cos(patrol_phase), -PATROL_RADII.y * sin(patrol_phase))
		patrol_phase = fposmod(patrol_phase + WALK_SPEED * delta / tangent.length(), TAU)
		waypoint = _patrol_position()
	_move_toward(waypoint, WALK_SPEED, delta)

func _patrol_position() -> Vector3:
	# Start at the authored post and loop behind it, always on the guarded side.
	return home + Vector3(PATROL_RADII.x * sin(patrol_phase), 0, PATROL_RADII.y * (cos(patrol_phase) - 1.0))

func distract(at: Vector3, offering: Vector3) -> bool:
	if distracted or solved:
		return false
	target = at
	offering_position = offering
	distracted = true
	_set_state("jump", "jump")
	return true

func _set_state(next: String, clip: String) -> void:
	if state == next:
		return
	state = next
	state_time = 0.0
	animator.play("encounter/" + clip, 0.18)
	state_changed.emit(state)

func _move_toward(at: Vector3, speed: float, delta: float) -> void:
	var direction := at - global_position
	direction.y = 0
	_face(direction, delta)
	global_position += direction.normalized() * minf(speed * delta, direction.length())
	# Probe terrain only: overhanging oak branches must never lift the dog.
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 10, global_position + Vector3.DOWN * 10, GROUND_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position.y = hit.position.y

func _face(direction: Vector3, delta: float) -> void:
	if Vector2(direction.x, direction.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-delta * 10.0))

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
