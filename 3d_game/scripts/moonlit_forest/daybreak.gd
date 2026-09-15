extends Node
## Continuous atmosphere port of the designer's forest-daybreak-v1 delivery.
const DAWN_TEXTURE = preload("res://models/stage05/daybreak/drybrush-dawn-sky.png")
const CLOUD_ATLAS = preload("res://models/stage05/daybreak/daybreak-cloud-atlas.png")

signal settled
var value := 0.0
var transition: Tween
var art: Node3D
var environment: Environment
var paints: Array[ShaderMaterial] = []
var night_meshes: Array[GeometryInstance3D] = []
var lights: Dictionary = {}
var sun: MeshInstance3D
var sunlight: DirectionalLight3D

func setup(world: Node3D) -> void:
	art = world.get_node(world.art_path)
	environment = world.get_node("WorldEnvironment").environment.duplicate()
	world.get_node("WorldEnvironment").environment = environment
	var dawn_texture = DAWN_TEXTURE
	var atlas = CLOUD_ATLAS
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		if label == "Sky_dome":
			var material: ShaderMaterial = mesh.get_active_material(0)
			material.set_shader_parameter("dawn_paint", dawn_texture)
			paints.append(material)
		elif label.begins_with("Cloud_layer"):
			var original: BaseMaterial3D = mesh.get_active_material(0)
			var material := ShaderMaterial.new()
			material.shader = preload("res://scripts/moonlit_forest/daybreak_cloud.gdshader")
			material.set_shader_parameter("paint", original.albedo_texture)
			material.set_shader_parameter("tint", original.albedo_color)
			material.set_shader_parameter("dawn_paint", atlas)
			var tile := 3 if "wisp" in label else int(label.get_slice("_", 2)) % 4
			material.set_shader_parameter("atlas_rect", Vector4((tile % 2)*0.5, 0.5-floorf(tile/2.0)*0.5, 0.5, 0.5))
			mesh.set_surface_override_material(0, material)
			paints.append(material)
		elif label == "Painted_moon" or label.begins_with("Luminous_body"):
			night_meshes.append(mesh)
	for light in art.find_children("*", "Light3D", true, false):
		lights[light] = light.light_energy
	sun = MeshInstance3D.new()
	sun.name = "DaybreakSun"
	var sphere := SphereMesh.new()
	sphere.radius = 3.4
	sphere.height = 6.8
	sun.mesh = sphere
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var sun_paint := StandardMaterial3D.new()
	sun_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sun_paint.disable_fog = true
	sun_paint.albedo_color = Color("ff990f")
	sun.material_override = sun_paint
	art.add_child(sun)
	sun.position = Vector3(-8,33.5,-140)
	sunlight = DirectionalLight3D.new()
	sunlight.name = "DaybreakSunlight"
	art.add_child(sunlight)
	sunlight.position = Vector3(-2,9,-36)
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 60
	set_value(0.0)

func go(target: float, timing: float = 1.0) -> void:
	target = clampf(target,0,2)
	if transition and transition.is_running():
		await settled
	if value >= target: return
	transition = create_tween()
	transition.tween_method(set_value,value,target,12.0*timing).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await transition.finished
	settled.emit()

func set_value(amount: float) -> void:
	value = clampf(amount,0,2)
	var dawn := clampf(value,0,1)
	var rise := clampf(value-1,0,1)
	var night := 1.0-smoothstep(0.0,0.88,dawn)
	for material in paints:
		material.set_shader_parameter("dawn",dawn)
		material.set_shader_parameter("sunrise",rise)
	for mesh in night_meshes:
		mesh.transparency = 1.0-night
		mesh.visible = night > 0
	for light in lights:
		var label := str(light.name)
		if "firefly" in label.to_lower() or label == "Moon_key":
			light.light_energy = lights[light]*night
		elif light is OmniLight3D:
			light.light_energy = lights[light]*lerpf(1,.22,dawn)*lerpf(1,.6,rise)
		else:
			light.light_energy = lights[light]*lerpf(1,1.5,dawn)
	environment.fog_light_color = Color("263655").lerp(Color("797d9c"),dawn).lerp(Color("d89e85"),rise)
	environment.fog_density = lerpf(lerpf(.003,.0025,dawn),.002,rise)
	environment.ambient_light_color = Color("a9b7d8").lerp(Color("b7b8da"),dawn).lerp(Color("ffd6a6"),rise)
	environment.ambient_light_energy = lerpf(lerpf(.4,.49,dawn),.59,rise)
	environment.tonemap_exposure = lerpf(lerpf(1,.98,dawn),.95,rise)
	sun.visible = rise > 0
	sun.position.y = lerpf(33.5,40,rise)
	sunlight.light_energy = lerpf(.12*dawn,1.25,rise)
	sunlight.light_color = Color("efb7c9").lerp(Color("ffb95d"),rise)
	sunlight.position.y = lerpf(9,12,rise)
	sunlight.look_at(art.to_global(Vector3(0,0,-4)))
