extends Node

## Share the live world with one mirrored camera; never duplicate the scenery.
const WATER_HEIGHT := -0.07
const WATER_ONLY_LAYER := 1 << 19
const MAX_RENDER_SIZE := Vector2(1280, 720)
const EXCLUDED_PREFIXES := [
	"Calm_River_Surface", "Continuous_Ground_Underlay",
	"Flowing_Paint_Strokes", "Cel_Glints_Drawing", "Broken_Warm_Glints",
	"Quiet_Shore_Wash", "Drybrush_Shoreline",
	"Painted_Rock_Contact_Ripples", "Expanding_Drybrush_Ripples",
]

var viewport: SubViewport
var camera: Camera3D
var water_material: ShaderMaterial
@onready var source_camera: Camera3D = get_parent().get_node("StageCamera")

func _ready() -> void:
	# Run after the level's camera follow, before either viewport is rendered.
	process_priority = 100
	var art := get_parent().get_node("Stage04Art")
	for mesh in art.find_children("*", "MeshInstance3D", true, false):
		var ancestor: Node = mesh
		while ancestor != art:
			if EXCLUDED_PREFIXES.any(func(prefix): return str(ancestor.name).begins_with(prefix)):
				mesh.layers = WATER_ONLY_LAYER
				break
			ancestor = ancestor.get_parent()
	var water: MeshInstance3D = art.find_child("Calm_River_Surface", true, false)
	# ViewportTexture is scene-owned: do not retain it in the cached GLB material.
	water_material = water.get_active_material(0).duplicate()
	water.set_surface_override_material(0, water_material)
	viewport = SubViewport.new()
	viewport.name = "ReflectionViewport"
	viewport.world_3d = source_camera.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "ReflectionCamera"
	viewport.add_child(camera)
	camera.make_current()
	water_material.set_shader_parameter("reflection_texture", viewport.get_texture())
	water_material.set_shader_parameter("reflection_strength", 1.0)

func _process(_delta: float) -> void:
	var source_size := source_camera.get_viewport().get_visible_rect().size
	var render_scale := minf(1.0, minf(MAX_RENDER_SIZE.x / source_size.x, MAX_RENDER_SIZE.y / source_size.y))
	var target_size := Vector2i((source_size * render_scale).round()).max(Vector2i(2, 2))
	if viewport.size != target_size:
		viewport.size = target_size
	camera.projection = source_camera.projection
	camera.keep_aspect = source_camera.keep_aspect
	camera.fov = source_camera.fov
	camera.size = source_camera.size
	camera.near = source_camera.near
	camera.far = source_camera.far
	camera.cull_mask = source_camera.cull_mask & ~WATER_ONLY_LAYER
	camera.environment = source_camera.environment
	var mirrored := source_camera.global_transform
	mirrored.origin.y = 2.0 * WATER_HEIGHT - mirrored.origin.y
	# Reflect world Y, then invert camera-local Y to retain a right-handed basis.
	# The water shader undoes the resulting vertical image flip.
	var reflection := Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.BACK)
	mirrored.basis = reflection * mirrored.basis * reflection
	camera.global_transform = mirrored
