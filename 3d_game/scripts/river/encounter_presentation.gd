extends Node

signal settled
var busy := false
var epoch := 0
var tween: Tween
var cover: Node3D
var coin_tweens: Array[Tween] = []
var coins_released := false
var coin_rng := RandomNumberGenerator.new()
const COIN_SPACING := 3.2
var overview: Transform3D
var home: Transform3D
var home_size := 22.0
@export var duration_scale := 1.0
@onready var level = get_parent()
@onready var camera: Camera3D = level.get_node("StageCamera")

func _ready() -> void:
	home = camera.transform
	overview = camera.transform
	home_size = camera.size
	coin_rng.randomize()
	reset_coins()

func reset_coins() -> void:
	coins_released = false
	for animation in coin_tweens:
		if animation.is_valid():
			animation.kill()
	coin_tweens.clear()
	for coin in level.get_node("Coins").get_children():
		coin.hide()

func begin(anchor: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	home = camera.transform
	home_size = camera.size
	_make_cover(anchor)
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(cover.position, 12.0, 0.55)
	if token != epoch: return
	await get_tree().create_timer(0.7 * duration_scale).timeout
	if token != epoch: return
	await _restore(0.55)
	if token != epoch: return
	busy = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	release_coins()
	settled.emit()

func reveal(target: Vector3) -> void:
	epoch += 1
	var token := epoch
	busy = true
	home = camera.transform
	home_size = camera.size
	level.player.set_input_enabled(false)
	level.normal_hud.hide()
	await _focus(target, 12.0, 0.55)
	if token != epoch: return
	remove_cover()
	if level.bridge_built: level.bridge.show()
	if is_instance_valid(level.generated_visual):
		level.generated_visual.show()
	await get_tree().create_timer(0.9 * duration_scale).timeout
	if token != epoch: return
	await _restore(0.55)
	if token != epoch: return
	busy = false
	level.normal_hud.show()
	level.player.set_input_enabled(true)
	settled.emit()

func cancel() -> void:
	epoch += 1
	if tween and tween.is_valid():
		tween.kill()
		tween.finished.emit()
	if busy:
		camera.transform = home
		camera.size = home_size
	busy = false
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

func release_coins() -> void:
	if coins_released: return
	coins_released = true
	var spots := scatter_positions(level.get_node("Coins").get_child_count())
	var index := 0
	for coin in level.get_node("Coins").get_children():
		if index >= spots.size():
			push_warning("Not enough clear ground for all reward coins.")
			break
		var destination: Vector3 = spots[index]
		coin.position = destination + Vector3.UP * 2.0
		if not level.collected.has(coin.name): coin.show()
		var fall := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		fall.tween_interval(index * 0.06 * duration_scale)
		fall.tween_property(coin, "position", destination, 0.65 * duration_scale)
		coin_tweens.append(fall)
		index += 1

# Rejection sampling keeps each reward well separated on clear near-bank ground.
# Physics checks reject water, tree/rock tops and cramped standing positions.
func scatter_positions(count: int) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	var space = level.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65
	capsule.height = 1.9
	for attempt in 1600:
		if spots.size() == count: break
		var point := Vector3(coin_rng.randf_range(-15.0, -6.2), 20.0, coin_rng.randf_range(-16.0, 1.0))
		var flat_player := Vector2(level.player.position.x, level.player.position.z)
		if Vector2(point.x, point.z).distance_to(flat_player) < 2.8: continue
		var separated := true
		for other in spots:
			if Vector2(point.x, point.z).distance_to(Vector2(other.x, other.z)) < COIN_SPACING:
				separated = false
				break
		if not separated: continue
		var ray := PhysicsRayQueryParameters3D.create(point, Vector3(point.x, 0.0, point.z))
		ray.exclude = [level.player.get_rid()]
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or not str(hit.collider.name).ends_with("Left_bank_meadow_col"): continue
		if hit.normal.y < 0.85: continue
		var standing := PhysicsShapeQueryParameters3D.new()
		standing.shape = capsule
		standing.transform.origin = hit.position + Vector3.UP * 1.05
		standing.exclude = [level.player.get_rid()]
		if not space.intersect_shape(standing).is_empty(): continue
		spots.append(hit.position + Vector3.UP * 0.7)
	return spots

func follow_player(delta: float) -> void:
	if busy or level.panel_mode != "": return
	# Hold the original composition on the far bank so the path exit stays
	# near the lower-right screen edge instead of following the player away.
	if level.completed:
		camera.position = camera.position.lerp(overview.origin, 1.0 - exp(-delta * 4.0))
		return
	var viewport := get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(level.player.global_position)
	var safe := screen.clamp(viewport * 0.22, viewport * 0.78)
	if screen.distance_to(safe) < 1.0: return
	var plane := Plane(Vector3.UP, level.player.position.y)
	var at = plane.intersects_ray(camera.project_ray_origin(safe), camera.project_ray_normal(safe))
	if at is Vector3:
		camera.position += (level.player.position - at) * minf(delta * 5, 1)
