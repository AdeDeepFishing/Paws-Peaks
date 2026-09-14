extends Node

signal focused
signal finished

const Framing = preload("res://scripts/woodland/encounter_framing.gd")

@export var duration_scale := 1.0
@export var focus_fov := Framing.FOCUS_FOV
@export var track_subjects := true
@export var focus_when_ready := false
var focus_started := false
var phase := "idle"
var active := false
var busy := false
var epoch := 0
var tween: Tween
var home: Transform3D
var home_fov := 49.0
var focus_anchor := Vector3.ZERO
@onready var level = get_parent()
@onready var camera: Camera3D = level.camera

func begin(anchor: Vector3) -> void:
	cancel()
	active = true
	focus_anchor = anchor
	if focus_when_ready:
		phase = "waiting"
		return
	_focus()

func _focus() -> void:
	phase = "focusing"
	focus_started = true
	var token := epoch
	var anchor := focus_anchor
	home = camera.transform
	home_fov = camera.fov
	level.camera_follow_enabled = false
	_lock(true)
	var focus := anchor + Vector3.UP * 1.1
	var destination := Transform3D(home.basis, focus + home.basis.z * 8.0)
	if level.has_method("presentation_camera_transform"):
		destination = level.presentation_camera_transform(anchor)
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", destination, 2.0 * duration_scale)
	tween.tween_property(camera, "fov", focus_fov, 2.0 * duration_scale)
	await tween.finished
	if token != epoch: return
	phase = "waiting"
	_lock(false)
	focused.emit()

func _process(delta: float) -> void:
	if active and focus_started and track_subjects and phase in ["waiting", "revealing"] and level.has_method("presentation_camera_transform"):
		var destination: Transform3D = level.presentation_camera_transform(focus_anchor)
		camera.transform = camera.transform.interpolate_with(destination, 1.0 - exp(-delta * 3.0))

func reveal(model: Node3D) -> void:
	if not active: begin(model.position)
	var token := epoch
	if not focus_started:
		_focus()
	# Completed models wait for the reveal camera to arrive.
	if phase == "focusing": await focused
	if token != epoch or not is_instance_valid(model): return
	phase = "revealing"
	_lock(true)
	await get_tree().create_timer(0.35 * duration_scale).timeout
	if token != epoch: return
	model.show()
	if model is RigidBody3D:
		model.freeze = false
	level.generation_preview.model_presented()
	await get_tree().create_timer(2.0 * duration_scale).timeout
	if token != epoch: return
	phase = "restoring"
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", home, 1.0 * duration_scale)
	tween.tween_property(camera, "fov", home_fov, 1.0 * duration_scale)
	await tween.finished
	if token != epoch: return
	active = false
	focus_started = false
	phase = "idle"
	level.camera_follow_enabled = true
	_lock(false)
	finished.emit()

func cancel() -> void:
	epoch += 1
	if tween and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	if active and focus_started:
		camera.transform = home
		camera.fov = home_fov
	active = false
	focus_started = false
	phase = "idle"
	level.camera_follow_enabled = true
	_lock(false)
	# Release a reveal awaiting the focus; its epoch rejects canceled work.
	focused.emit()

func _lock(value: bool) -> void:
	busy = value
	level.player.set_input_enabled(not value)
	if level.has_method("set_encounter_paused"):
		level.set_encounter_paused(value)
	else:
		level.dog.paused = value
	level.hud_root.visible = not value

func _exit_tree() -> void:
	cancel()
