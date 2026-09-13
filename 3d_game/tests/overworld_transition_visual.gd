extends SceneTree

var shots := {}
var journey: Node

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/map53-" + name + ".png")

func _process(_delta: float) -> bool:
	if journey == null or current_scene == null: return false
	var key := ""
	if journey.page.visible:
		var amount: float = journey.page_material.get_shader_parameter("progress")
		if amount > 0.47 and amount < 0.58:
			key = journey.phase
	elif current_scene.name == "Overworld" and current_scene.palette_weights.y > 0.45 and current_scene.palette_weights.y < 0.56:
		key = "sunset-blend"
	if key != "" and not shots.has(key):
		shots[key] = true
		capture(key)
	return false

func run() -> void:
	root.size = Vector2i(1152, 720)
	journey = root.get_node("Journey")
	journey.duration_scale = 0.7
	change_scene_to_file(journey.MAP)
	await scene_changed
	await journey.finished
	for stage in [2, 3]:
		journey.travel_to(journey.STAGES[stage - 1])
		while journey.phase != "browse": await process_frame
		await capture("chapter-%d-ready" % stage)
		await create_timer(0.2).timeout
		var point: Vector2 = current_scene.next_button.get_global_rect().get_center()
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		root.push_input(click)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		await journey.finished
	print("MAP VISUAL TRANSITIONS: PASS (native mouse clicks)")
	quit()
