extends Node3D

const FOLIAGE_SHADER := preload("res://scripts/moonlit_forest/painted_foliage.gdshader")
const SKY_SHADER := preload("res://scripts/moonlit_forest/painted_sky.gdshader")
const BARK_SHADER := preload("res://scripts/moonlit_forest/painted_bark.gdshader")
const BARK_PREFIXES := ["Flowing_painted_trunk", "Midground_painted_trunk", "Bough_", "Twig_", "Buttress_root", "Exposed_forest_root"]

func _ready() -> void:
	var materials := {}
	for mesh in find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		# glTF does not carry the delivery's per-mesh shadow flags. The sky and
		# celestial decorations must not enclose the level in a giant shadow.
		if label == "Sky_dome" or label == "Painted_moon" or label.begins_with("Cloud_layer") or label.begins_with("Luminous_body"):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var original: BaseMaterial3D = mesh.get_active_material(surface)
			var extras: Dictionary = original.get_meta("extras", {})
			if extras.has("windStrength"):
				if not materials.has(original):
					materials[original] = _foliage_material(original, extras.windStrength)
				mesh.set_surface_override_material(surface, materials[original])
				mesh.extra_cull_margin = 0.35
			elif BARK_PREFIXES.any(func(prefix): return label.begins_with(prefix)):
				if not materials.has(original):
					materials[original] = _paint_material(original, BARK_SHADER)
				mesh.set_surface_override_material(surface, materials[original])
			elif label == "Sky_dome":
				var painted_sky := ShaderMaterial.new()
				painted_sky.shader = SKY_SHADER
				painted_sky.set_shader_parameter("paint", original.albedo_texture)
				painted_sky.set_shader_parameter("tint", original.albedo_color)
				painted_sky.set_shader_parameter("paint_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
				painted_sky.set_shader_parameter("paint_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
				mesh.set_surface_override_material(surface, painted_sky)
			elif label == "Painted_moon" or label.begins_with("Cloud_layer"):
				var sky_material: BaseMaterial3D = original.duplicate()
				sky_material.disable_fog = true
				mesh.set_surface_override_material(surface, sky_material)
			elif label.begins_with("Luminous_body"):
				if not materials.has(original):
					var glow: BaseMaterial3D = original.duplicate()
					glow.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					glow.emission_enabled = true
					glow.emission = original.albedo_color
					glow.emission_energy_multiplier = 2.5
					materials[original] = glow
				mesh.set_surface_override_material(surface, materials[original])
		if label == "Continuous_organic_forest_terrain" or label.begins_with("Painted_rounded_rock") or label.begins_with("Flowing_painted_trunk") or label.begins_with("Midground_painted_trunk") or label.begins_with("Buttress_root") or label.begins_with("Embedded_trail_edge_stone"):
			mesh.create_trimesh_collision()
			for collider in mesh.find_children("*", "CollisionShape3D", true, false):
				if collider.shape is ConcavePolygonShape3D:
					collider.shape.backface_collision = true
	for animator in find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			if "Forest_wind_clouds_fireflies" in clip:
				# The supplied cloud/flight paths are not seamless at 12 seconds.
				# Reverse their playback instead of teleporting to the first frame.
				animator.get_animation(clip).loop_mode = Animation.LOOP_PINGPONG
				animator.play(clip)
	var moon: DirectionalLight3D = find_child("Moon_key", true, false)
	if moon:
		moon.shadow_enabled = true
		moon.directional_shadow_max_distance = 60.0
	# The renderer's light response differs from the source's Three.js/Blender
	# previews. Keep night colors readable without washing out the glowing plants.
	for light in find_children("*", "Light3D", true, false):
		light.light_energy *= 0.5 if light is DirectionalLight3D else 0.3

func _foliage_material(original: BaseMaterial3D, strength: float) -> ShaderMaterial:
	var material := _paint_material(original, FOLIAGE_SHADER)
	material.set_shader_parameter("alpha_cutoff", original.alpha_scissor_threshold)
	material.set_shader_parameter("wind_strength", strength)
	return material

func _paint_material(original: BaseMaterial3D, shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("paint", original.albedo_texture)
	material.set_shader_parameter("tint", original.albedo_color)
	material.set_shader_parameter("emission_tint", original.emission)
	material.set_shader_parameter("emission_strength", original.emission_energy_multiplier)
	material.set_shader_parameter("paint_scale", Vector2(original.uv1_scale.x, original.uv1_scale.y))
	material.set_shader_parameter("paint_offset", Vector2(original.uv1_offset.x, original.uv1_offset.y))
	return material
