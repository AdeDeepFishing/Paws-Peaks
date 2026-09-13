extends Node

signal settled
var busy := false
var holding := false
var epoch := 0
var tween: Tween
var cover: Node3D
var overview: Transform3D
var overview_size := 18.6
var home: Transform3D
var home_size := 18.6
@export var duration_scale := 1.0
@onready var level = get_parent()
@onready var camera: Camera3D = level.get_node("StageCamera")

func _ready() -> void:
	home = camera.transform
	overview = camera.transform
	home_size = camera.size
	overview_size = camera.size

func begin(anchor: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	holding = true
	home = camera.transform
	home_size = camera.size
	_make_cover(anchor)
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(anchor, 12.0, 2.0)
	if token != epoch: return
	busy = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	# Keep this camera framing until the request resolves. Exploration and the
	# Stop waiting action remain available after the initial camera movement.
	settled.emit()

func reveal(target: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	if not holding:
		home = camera.transform
		home_size = camera.size
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(target, 12.0, 0.45)
	if token != epoch: return
	remove_cover()
	if level.bridge_built: level.bridge.show()
	if is_instance_valid(level.generated_visual):
		level.generated_visual.show()
	level.generation_preview.model_presented()
	await get_tree().create_timer(2.0 * duration_scale).timeout
	if token != epoch: return
	await _restore(1.0)
	if token != epoch: return
	busy = false
	holding = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	settled.emit()

func cancel() -> void:
	epoch += 1
	if tween and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	if busy or holding:
		camera.transform = home
		camera.size = home_size
	busy = false
	holding = false
	remove_cover()
	if is_instance_valid(level.normal_hud): level.normal_hud.show()
	if is_instance_valid(level.player): level.player.set_input_enabled(true)
	settled.emit()

func remove_cover() -> void:
	if is_instance_valid(cover):
		cover.get_parent().remove_child(cover)
		cover.queue_free()
	cover = null

func _make_cover(anchor: Vector3) -> void:
	remove_cover()
	cover = Node3D.new()
	cover.name = "ConstructionCover"
	level.add_child(cover)
	cover.position = anchor
	var query := PhysicsRayQueryParameters3D.create(Vector3(anchor.x, 4.0, anchor.z), Vector3(anchor.x, 0.0, anchor.z))
	query.exclude = [level.player.get_rid()]
	var ground: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if ground: cover.position.y = maxf(anchor.y, ground.position.y + 0.08)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ded4ad")
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(-3,0.35,-1.2), Vector3(3,0.35,-1.2), Vector3(-3,0.85,0), Vector3(3,0.85,0), Vector3(-3,0.35,1.2), Vector3(3,0.35,1.2)]
	for index in [0,2,1,1,2,3,2,4,3,3,4,5]: surface.add_vertex(points[index])
	surface.generate_normals()
	cloth.mesh = surface.commit()
	cloth.material_override = material
	cover.add_child(cloth)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("87654b")
	for x in [-3.0, 3.0]:
		for z in [-1.2, 1.2]:
			var post := MeshInstance3D.new()
			var pole := CylinderMesh.new()
			pole.top_radius = 0.05
			pole.bottom_radius = 0.06
			pole.height = 0.85
			post.mesh = pole
			post.material_override = wood
			post.position = Vector3(x, 0.425, z)
			cover.add_child(post)
	var label := Label3D.new()
	label.name = "Status"
	label.text = "Taking shape..."
	label.font_size = 58
	label.pixel_size = 0.012
	label.position.y = 1.65
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("fff9ed")
	label.outline_modulate = Color("273d36")
	cover.add_child(label)

func _focus(target: Vector3, size: float, seconds: float) -> void:
	var midpoint := get_viewport().get_visible_rect().size * 0.5
	var center = Plane(Vector3.UP, target.y).intersects_ray(camera.project_ray_origin(midpoint), camera.project_ray_normal(midpoint))
	var destination := camera.position
	if center is Vector3: destination += target - center
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "position", destination, seconds * duration_scale)
	tween.tween_property(camera, "size", size, seconds * duration_scale)
	await tween.finished

func _restore(seconds: float) -> void:
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", home, seconds * duration_scale)
	tween.tween_property(camera, "size", home_size, seconds * duration_scale)
	await tween.finished

func follow_player(delta: float) -> void:
	if busy or holding or level.panel_mode != "": return
	var viewport := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(level.player.global_position)
	var safe := screen.clamp(viewport * 0.22, viewport * 0.78)
	if screen.distance_to(safe) < 1.0: return
	var plane := Plane(Vector3.UP, level.player.position.y)
	var at = plane.intersects_ray(camera.project_ray_origin(safe), camera.project_ray_normal(safe))
	if at is Vector3:
		camera.position += (level.player.position - at) * minf(delta * 5, 1)
