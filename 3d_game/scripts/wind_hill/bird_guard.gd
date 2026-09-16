extends Node3D

signal swooping
signal cleared
signal departure_started

const FLAP = preload("res://models/bird/flap.glb")
const VISUAL_SCALE := 2.8
const ARRIVAL_SECONDS := 5.5
const ARRIVAL_DEPTH := 140.0
var phase := "loading"
var elapsed := 0.0
var paused := false:
	set(value):
		paused = value
		for animator in animators:
			animator.speed_scale = 0.0 if value else 1.0
var visual: Node3D
var arrival_origin := Vector3.ZERO
var arrival_control := Vector3.ZERO
var animators: Array[AnimationPlayer] = []
var start := Vector3.ZERO
var swoop_target := Vector3.ZERO
var dodge := 0.0
var hit_this_swoop := false
var protection_top := 4.5
@onready var level = get_parent()

func _ready() -> void:
	visual = Node3D.new()
	visual.name = "FlyingMoonwing"
	add_child(visual)
	var model := FLAP.instantiate()
	visual.add_child(model)
	model.scale = Vector3.ONE * VISUAL_SCALE
	_play(model, "FlapLoop")
	visual.hide()
	# The parent installs the authored camera after its children become ready.
	_start_arrival.call_deferred()

func _start_arrival() -> void:
	var camera: Camera3D = level.camera
	var viewport := get_viewport().get_visible_rect().size
	arrival_origin = camera.project_position(viewport * Vector2(0.84, 0.19), ARRIVAL_DEPTH)
	arrival_control = camera.project_position(viewport * Vector2(0.69, 0.30), 65.0)
	visual.global_position = arrival_origin
	visual.rotation.y = atan2(arrival_control.x - arrival_origin.x, arrival_control.z - arrival_origin.z)
	visual.show()
	_enter("arriving")

func _play(model: Node, clip: String) -> void:
	var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if animator == null: return
	for name in animator.get_animation_list():
		if clip in name:
			var animation: Animation = animator.get_animation(name).duplicate(true)
			animation.loop_mode = Animation.LOOP_LINEAR
			var library := AnimationLibrary.new()
			library.add_animation("loop", animation)
			animator.add_animation_library("bird", library)
			animator.play("bird/loop")
			break
	animators.append(animator)

func _process(delta: float) -> void:
	if paused or phase == "cleared": return
	elapsed += delta
	var center: Vector3 = level.player.position
	center.y = maxf(center.y, 0.0)
	match phase:
		"arriving":
			var t := smoothstep(0.0, ARRIVAL_SECONDS, elapsed)
			var endpoint := _orbit(center, 0.0)
			# Actual camera depth supplies perspective: the giant keeps its world size.
			var target := arrival_origin.lerp(arrival_control, t).lerp(arrival_control.lerp(endpoint, t), t)
			_move(target, delta)
			if elapsed >= ARRIVAL_SECONDS: _enter("circling")
		"circling":
			_move(_orbit(center, elapsed), delta)
			if elapsed >= 3.0:
				swoop_target = center + Vector3(0.0, 1.1, 0.0)
				_enter("swooping")
				swooping.emit()
		"swooping":
			var t := clampf(elapsed / 1.8, 0.0, 1.0)
			_move(_curve(start, swoop_target, swoop_target + Vector3(-4.5, 2.8, -1.0), t), delta)
			dodge = sin(PI * t)
			# Start the authored fall before the bird reaches its closest point.
			if t >= 0.2 and not hit_this_swoop:
				hit_this_swoop = true
				var player = level.player
				if player.input_enabled and player.is_on_floor() and not player.drawing_active and player.position.distance_to(swoop_target - Vector3(0, 1.1, 0)) < 2.5:
					player.visual.play_action("knockdown")
			if t >= 1.0:
				dodge = 0.0
				_enter("regrouping")
		"regrouping":
			_move(start.lerp(_orbit(center, 0.0), smoothstep(0.0, 1.2, elapsed)), delta)
			if elapsed >= 1.2: _enter("circling")
		"blocked":
			# Approach the raised protection, then recoil without touching the hero.
			var t := clampf(elapsed / 2.0, 0.0, 1.0)
			_move(_curve(start, center + Vector3(1.1, protection_top, 0), center + Vector3(4, protection_top + 3, -2), t), delta)
			if t >= 1.0: _enter("departing")
		"departing":
			var t := clampf(elapsed / 3.0, 0.0, 1.0)
			_move(start + Vector3(24, 13, -15) * t, delta)
			if t >= 1.0:
				phase = "cleared"
				hide()
				cleared.emit()
	level.player.visual.set_avoidance(dodge)

func protect(top: float) -> bool:
	if phase in ["blocked", "departing", "cleared"]: return false
	level.player.visual.cancel_action()
	protection_top = top
	visual.show()
	dodge = 0.0
	level.player.visual.set_avoidance(0.0)
	_enter("blocked")
	return true

func scare_away() -> bool:
	if phase in ["blocked", "departing", "cleared"]: return false
	level.player.visual.cancel_action()
	dodge = 0.0
	level.player.visual.set_avoidance(0.0)
	visual.show()
	_enter("departing")
	return true

func _enter(next: String) -> void:
	phase = next
	if next == "swooping": hit_this_swoop = false
	elapsed = 0.0
	start = visual.position
	if next == "departing": departure_started.emit()

func _orbit(center: Vector3, time: float) -> Vector3:
	var angle := time * 0.9
	return center + Vector3(6.5 * cos(angle), 3.8 + 0.35 * sin(angle * 2), 2.6 * sin(angle) - 0.8)

func _move(target: Vector3, delta: float) -> void:
	var direction := target - visual.position
	if Vector2(direction.x, direction.z).length() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-delta * 8.0))
		# The delivered model faces +Z; pitch its beak along the vertical flight path.
		var pitch := -atan2(direction.y, Vector2(direction.x, direction.z).length())
		visual.rotation.x = lerp_angle(visual.rotation.x, clampf(pitch, -0.7, 0.9), 1.0 - exp(-delta * 8.0))
	visual.position = target

func _curve(from: Vector3, middle: Vector3, to: Vector3, t: float) -> Vector3:
	if t < 0.5: return from.lerp(middle, smoothstep(0.0, 0.5, t))
	return middle.lerp(to, smoothstep(0.5, 1.0, t))
