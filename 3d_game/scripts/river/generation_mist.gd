extends Control

## Shared, bounded screen-space mist. It follows the actual sketch while cameras move.
var particles: CPUParticles2D
var blur: ColorRect
var shader_material: ShaderMaterial
var active := false

func _ready() -> void:
	name = "GenerationMist"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur = ColorRect.new()
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_material = ShaderMaterial.new()
	shader_material.shader = preload("res://shaders/generation_mist.gdshader")
	blur.material = shader_material
	add_child(blur)
	particles = CPUParticles2D.new()
	particles.name = "SketchSparks"
	particles.amount = 64
	particles.lifetime = 2.4
	particles.preprocess = 1.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.direction = Vector2(0, -1)
	particles.spread = 65
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 10
	particles.initial_velocity_max = 28
	particles.scale_amount_min = 0.15
	particles.scale_amount_max = 0.45
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0, 0.2, 0.65, 1])
	fade.colors = PackedColorArray([Color(1,1,1,0), Color(1,0.94,0.84,0.95), Color(0.82,0.97,1,0.7), Color(0.96,0.85,1,0)])
	particles.color_ramp = fade
	var glow := GradientTexture2D.new()
	glow.width = 48
	glow.height = 48
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1, 0.5)
	glow.gradient = Gradient.new()
	glow.gradient.offsets = PackedFloat32Array([0, 0.16, 0.45, 1])
	glow.gradient.colors = PackedColorArray([Color.WHITE, Color(1,1,1,0.9), Color(1,1,1,0.3), Color(1,1,1,0)])
	particles.texture = glow
	add_child(particles)
	set_active(false)

func set_active(value: bool) -> void:
	active = value
	visible = value
	if not is_instance_valid(particles): return
	particles.emitting = value
	if value: particles.restart()

func follow_rect(sketch: Rect2, shown: bool) -> void:
	visible = active and shown and sketch.has_area()
	if not visible: return
	# Keep the blur local even for very large drawings; it never covers the whole screen.
	var padding := maxf(30.0, minf(sketch.size.x, sketch.size.y) * 0.22)
	position = sketch.position - Vector2.ONE * padding
	size = sketch.size + Vector2.ONE * padding * 2.0
	particles.position = size * 0.5
	particles.emission_rect_extents = sketch.size * 0.48
