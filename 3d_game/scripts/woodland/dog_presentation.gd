extends Node

signal focused
signal finished

@export var duration_scale := 1.0
var phase := "idle"
var active := false
var busy := false
var epoch := 0
var exiting := false
var cover: Node3D
var tween: Tween
var home: Transform3D
var home_fov := 49.0
@onready var level = get_parent()
@onready var camera: Camera3D = level.camera

func begin(anchor: Vector3) -> void:
	cancel()
	active = true
	phase = "focusing"
	var token := epoch
	home = camera.transform
	home_fov = camera.fov
	level.camera_follow_enabled = false
	_make_cover(anchor)
	_lock(true)
	var focus := anchor + Vector3.UP * 1.1
	var destination := Transform3D(home.basis, focus + home.basis.z * 8.0)
	if level.has_method("presentation_camera_transform"):
		destination = level.presentation_camera_transform(anchor)
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", destination, 2.0 * duration_scale)
	tween.tween_property(camera, "fov", 32.0, 2.0 * duration_scale)
	await tween.finished
	if token != epoch: return
	phase = "waiting"
	_lock(false)
	focused.emit()

func reveal(model: Node3D) -> void:
	if not active: begin(model.position)
	var token := epoch
	# Fast responses still let the initial camera movement finish.
	if phase == "focusing": await focused
	if token != epoch or not is_instance_valid(model): return
	phase = "revealing"
	_lock(true)
	if is_instance_valid(cover):
		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_property(cover, "position:y", cover.position.y + 1.2, 0.35 * duration_scale)
		tween.tween_property(cover, "scale", Vector3.ONE * 0.05, 0.35 * duration_scale)
		await tween.finished
		if token != epoch: return
	_remove_cover()
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
	phase = "idle"
	level.camera_follow_enabled = true
	_lock(false)
	finished.emit()

func cancel() -> void:
	epoch += 1
	if tween and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	if active:
		camera.transform = home
		camera.fov = home_fov
	active = false
	phase = "idle"
	level.camera_follow_enabled = true
	_remove_cover()
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

func _remove_cover() -> void:
	if is_instance_valid(cover):
		if not exiting: cover.get_parent().remove_child(cover)
		cover.queue_free()
	cover = null

func _make_cover(anchor: Vector3) -> void:
	cover = Node3D.new()
	cover.name = "ConstructionCover"
	level.add_child(cover)
	cover.position = anchor
	var cloth := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Closed cream cloth, pitched over the small offering like the river canopy.
	var points := [Vector3(-1.05,0,-0.9), Vector3(1.05,0,-0.9), Vector3(-1.05,0,0.9), Vector3(1.05,0,0.9), Vector3(-1.05,1.2,-0.9), Vector3(1.05,1.2,-0.9), Vector3(-1.05,1.2,0.9), Vector3(1.05,1.2,0.9), Vector3(0,1.9,-0.9), Vector3(0,1.9,0.9)]
	for index in [0,4,1,1,4,5,4,8,5,2,3,6,3,7,6,6,7,9,0,2,4,2,6,4,1,5,3,3,5,7,4,6,8,6,9,8,5,8,7,7,8,9]:
		surface.add_vertex(points[index])
	surface.generate_normals()
	cloth.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ded4ad")
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = material
	cover.add_child(cloth)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("87654b")
	wood.roughness = 1.0
	for x in [-1.08, 1.08]:
		for z in [-0.93, 0.93]:
			var post := MeshInstance3D.new()
			var pole := CylinderMesh.new()
			pole.top_radius = 0.035
			pole.bottom_radius = 0.045
			pole.height = 1.35
			post.mesh = pole
			post.material_override = wood
			post.position = Vector3(x, 0.675, z)
			cover.add_child(post)
	var label := Label3D.new()
	label.text = "Taking shape..."
	label.font_size = 48
	label.pixel_size = 0.006
	label.position.y = 2.35
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("fff9ed")
	label.outline_modulate = Color("273d36")
	cover.add_child(label)

func _exit_tree() -> void:
	exiting = true
	cancel()
