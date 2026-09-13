extends Node3D

signal swooping
signal cleared

const FLAP = preload("res://models/bird/flap.glb")
const IDLE = preload("res://models/bird/idle.glb")
const VISUAL_SCALE := 4.0
const LAUNCH := Vector3(6.5, 0.2, -0.8)
var phase := "perched"
var elapsed := 0.0
var paused := false:
	set(value):
		paused = value
		for animator in animators:
			animator.speed_scale = 0.0 if value else 1.0
var visual: Node3D
var perch: Node3D
var animators: Array[AnimationPlayer] = []
var start := Vector3.ZERO
var swoop_target := Vector3.ZERO
var dodge := 0.0
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
	visual.position = LAUNCH
	visual.hide()
	perch = IDLE.instantiate()
	perch.name = "PerchedMoonwing"
	perch.scale = Vector3.ONE * VISUAL_SCALE
	perch.position = LAUNCH
	perch.rotation.y = -PI / 2
	add_child(perch)
	_play(perch, "BreathingIdle")

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
		"perched":
			if elapsed >= 1.4:
				perch.hide()
				visual.show()
				_enter("arriving")
		"arriving":
			_move(LAUNCH.lerp(_orbit(center, 0.0), smoothstep(0.0, 2.5, elapsed)), delta)
			if elapsed >= 2.5: _enter("circling")
		"circling":
			_move(_orbit(center, elapsed), delta)
			if elapsed >= 3.0:
				swoop_target = center + Vector3(0.0, 2.4, 0.0)
				_enter("swooping")
				swooping.emit()
		"swooping":
			var t := clampf(elapsed / 1.8, 0.0, 1.0)
			_move(_curve(start, swoop_target, swoop_target + Vector3(-4.5, 2.8, -1.0), t), delta)
			dodge = sin(PI * t)
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
	protection_top = top
	perch.hide()
	visual.show()
	dodge = 0.0
	level.player.visual.set_avoidance(0.0)
	_enter("blocked")
	return true

func _enter(next: String) -> void:
	phase = next
	elapsed = 0.0
	start = visual.position

func _orbit(center: Vector3, time: float) -> Vector3:
	var angle := time * 0.9
	return center + Vector3(6.5 * cos(angle), 3.8 + 0.35 * sin(angle * 2), 2.6 * sin(angle) - 0.8)

func _move(target: Vector3, delta: float) -> void:
	var direction := target - visual.position
	if Vector2(direction.x, direction.z).length() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), 1.0 - exp(-delta * 8.0))
	visual.position = target

func _curve(from: Vector3, middle: Vector3, to: Vector3, t: float) -> Vector3:
	if t < 0.5: return from.lerp(middle, smoothstep(0.0, 0.5, t))
	return middle.lerp(to, smoothstep(0.5, 1.0, t))
