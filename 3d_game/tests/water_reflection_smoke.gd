extends SceneTree

var failed := false
var visual := "--visual" in OS.get_cmdline_user_args()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func capture(viewport: Viewport) -> Image:
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func projected_uv(camera: Camera3D, point: Vector3) -> Vector2:
	return camera.unproject_position(point) / camera.get_viewport().get_visible_rect().size

func sample(image: Image, uv: Vector2) -> Color:
	var pixel := Vector2i(uv * Vector2(image.get_size()))
	return image.get_pixelv(pixel.clamp(Vector2i.ZERO, image.get_size() - Vector2i.ONE))

func run() -> void:
	var level = load("res://scenes/sunset_cove/sunset_cove.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	await frames(45)
	level.set_process(false)
	level.player.set_physics_process(false)
	var reflection = level.get_node("WaterReflection")
	var material: ShaderMaterial = reflection.water_material
	check(reflection.viewport.world_3d == level.get_world_3d(), "Reflection shares the live world")
	check(root.get_camera_3d() == level.camera, "Reflection camera does not replace the gameplay camera")
	check((reflection.camera.cull_mask & reflection.WATER_ONLY_LAYER) == 0, "Reflection excludes water to prevent recursive feedback")
	var water: MeshInstance3D = level.get_node("Stage04Art").find_child("Calm_River_Surface", true, false)
	check((water.layers & reflection.camera.cull_mask) == 0, "Water is absent from its own render target")
	var underlay: MeshInstance3D = level.get_node("Stage04Art").find_child("Continuous_Ground_Underlay", true, false)
	check((underlay.layers & reflection.camera.cull_mask) == 0, "Background underlay cannot occlude the mirrored sky")
	check((water.layers & level.camera.cull_mask) != 0, "Gameplay still renders the water")
	if visual:
		var gameplay := await capture(root)
		gameplay.save_png("/private/tmp/paws-stage04-reflections.png")
		var reflected_view := await capture(reflection.viewport)
		reflected_view.save_png("/private/tmp/paws-stage04-reflection-target.png")

	# A saturated live object over open water detects upside-down, stale and
	# incorrectly projected captures independently of the authored paint texture.
	# Keep the protagonist from covering the sampled water pixel when panning.
	level.player.hide()
	var probe := MeshInstance3D.new()
	probe.mesh = BoxMesh.new()
	probe.mesh.size = Vector3(2, 2, 2)
	var pigment := StandardMaterial3D.new()
	pigment.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pigment.albedo_color = Color(1, 0, 1)
	probe.material_override = pigment
	level.add_child(probe)
	probe.position = Vector3(-5, 3, -10)
	var initial_camera: Transform3D = level.camera.global_transform
	for offset in [Vector3.ZERO, Vector3(3, 0, -2)]:
		level.camera.global_transform = initial_camera
		level.camera.global_position += offset
		await frames(4)
		var mirrored_point := probe.global_position
		mirrored_point.y = 2.0 * reflection.WATER_HEIGHT - mirrored_point.y
		var expected_uv := projected_uv(level.camera, mirrored_point)
		var reflected_uv := projected_uv(reflection.camera, probe.global_position)
		check(expected_uv.distance_to(Vector2(reflected_uv.x, 1.0 - reflected_uv.y)) < 0.003, "Reflection stays aligned after camera movement")
		if visual:
			var target := await capture(reflection.viewport)
			var color := sample(target, reflected_uv)
			check(color.r > 0.85 and color.b > 0.85 and color.g < 0.15, "Live probe appears in the reflection camera at its projected position")
			material.set_shader_parameter("reflection_strength", 0.0)
			await frames(3)
			var without := await capture(root)
			material.set_shader_parameter("reflection_strength", 1.0)
			await frames(3)
			var with_reflection := await capture(root)
			var before := sample(without, expected_uv)
			var after := sample(with_reflection, expected_uv)
			check(after.r > before.r + 0.08 and after.b > before.b + 0.08, "Water samples the live reflected object instead of only the painted texture")
			with_reflection.save_png("/private/tmp/paws-stage04-reflection-probe.png")
	probe.queue_free()
	level.player.show()
	# Change aspect ratio as well as camera position; the two passes must agree.
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(960, 720)
	await frames(5)
	check(absf(float(reflection.viewport.size.x) / reflection.viewport.size.y - root.get_visible_rect().size.aspect()) < 0.003, "Reflection follows viewport aspect ratio on resize")
	check(reflection.viewport.size.x <= 1280 and reflection.viewport.size.y <= 720, "Reflection render size stays bounded")
	if visual:
		var resized := await capture(root)
		resized.save_png("/private/tmp/paws-stage04-reflection-resized.png")
	var old_viewport: WeakRef = weakref(reflection.viewport)
	var old_material: WeakRef = weakref(material)
	material = null
	change_scene_to_file("res://scenes/wind_hill/wind_hill.tscn")
	await frames(10)
	check(old_viewport.get_ref() == null, "Leaving Stage 4 frees the reflection viewport")
	check(old_material.get_ref() == null, "Cached environment does not retain the scene's reflection material")
	change_scene_to_file("res://scenes/sunset_cove/sunset_cove.tscn")
	await frames(10)
	check(current_scene.get_node("WaterReflection").viewport.get_texture() != null, "Re-entering Stage 4 creates a fresh reflection target")
	print("WATER REFLECTION SMOKE: ", "FAIL" if failed else "PASS", " (rendered)" if visual else " (headless)")
	quit(1 if failed else 0)
