extends Node

## Owns chapter presentation and the session recap. Existing encounters decide
## whether an exit is unlocked; scene paths determine map position.
signal finished(stage: int)
signal failed(message: String)

const ENDING := "res://scenes/ending/dawn_forest.tscn"
const MAP := "res://scenes/overworld/overworld.tscn"
const STAGES := [
	"res://scenes/river/river_crossing.tscn",
	"res://scenes/woodland/woodland_path.tscn",
	"res://scenes/wind_hill/wind_hill.tscn",
	"res://scenes/sunset_cove/sunset_cove.tscn",
	"res://scenes/moonlit_forest/moonlit_forest.tscn",
]
var busy := false
## Test timing seam; production always uses the authored durations.
var duration_scale := 1.0
var from_stage := 0
var target_stage := 1
var current_stage := 0
var page: TextureRect
var page_material: ShaderMaterial
var overlay: CanvasLayer
var input_blocker: Control
var phase := "idle"
var visited_chapters: Array[int] = []
var sketches_shared := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	input_blocker = Control.new()
	overlay.add_child(input_blocker)
	input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_blocker.hide()
	page = TextureRect.new()
	overlay.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	page.stretch_mode = TextureRect.STRETCH_SCALE
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_material = ShaderMaterial.new()
	page_material.shader = preload("res://shaders/overworld/page_turn.gdshader")
	page.material = page_material
	page.hide()
	get_tree().scene_changed.connect(_observe_chapter)

func _observe_chapter() -> void:
	var scene := get_tree().current_scene
	if scene == null: return
	_record_chapter(stage_for_scene(scene.scene_file_path))
	for node in scene.find_children("*", "Node", true, false):
		if node.has_signal("request_prepared") and not node.is_connected("request_prepared", _record_sketch):
			node.connect("request_prepared", _record_sketch)

func _record_chapter(stage: int) -> void:
	if stage > 0 and stage not in visited_chapters: visited_chapters.append(stage)

func _record_sketch(_payload: Dictionary) -> void:
	# Count accepted submissions, including retries; never claim AI success.
	sketches_shared += 1

func _input(_event: InputEvent) -> void:
	if busy and phase != "start": get_viewport().set_input_as_handled()

func stage_for_scene(path: String) -> int:
	return STAGES.find(path) + 1

func travel_to(destination: String) -> Error:
	if busy: return ERR_BUSY
	var source := get_tree().current_scene
	if source == null: return ERR_UNCONFIGURED
	var origin := stage_for_scene(source.scene_file_path)
	var target := stage_for_scene(destination)
	_record_chapter(origin)
	if origin == 5 and destination == ENDING:
		if not ResourceLoader.exists(destination): return ERR_FILE_NOT_FOUND
		busy = true
		from_stage = 5
		target_stage = 6
		input_blocker.show()
		_run_ending.call_deferred()
		return OK
	# Back buttons retain their existing navigation.
	if origin == 0 or target != origin + 1:
		return get_tree().change_scene_to_file(destination)
	if not ResourceLoader.exists(destination) or not ResourceLoader.exists(MAP):
		return ERR_FILE_NOT_FOUND
	_begin(origin, target)
	return OK

func browse_map() -> Error:
	if busy: return ERR_BUSY
	var source := get_tree().current_scene
	if source == null or stage_for_scene(source.scene_file_path) == 0: return ERR_UNCONFIGURED
	if source.has_method("can_browse_map") and not source.can_browse_map(): return ERR_BUSY
	if not ResourceLoader.exists(MAP): return ERR_FILE_NOT_FOUND
	busy = true
	input_blocker.show()
	_browse_map.call_deferred(source)
	return OK

func _browse_map(source: Node3D) -> void:
	var packed := load(MAP) as PackedScene
	if packed == null:
		_recover(source, source.process_mode, "The map could not be opened. Try again.")
		return
	var old_mode := source.process_mode
	var stage := stage_for_scene(source.scene_file_path)
	var active_camera := get_viewport().get_camera_3d()
	source.process_mode = Node.PROCESS_MODE_DISABLED
	await _capture_page()
	# Keep the same chapter in the tree, paused and hidden, so drafts, generated
	# models, collision state and encounter progress survive a map visit.
	var layers: Dictionary = {}
	for layer in source.find_children("*", "CanvasLayer", true, false):
		layers[layer] = layer.visible
		layer.hide()
	source.hide()
	var map := packed.instantiate()
	map.autoplay = false
	get_tree().root.add_child(map)
	get_tree().current_scene = map
	map.configure(stage, stage)
	await get_tree().process_frame
	await _turn_page(true, 0.95, false, true)
	phase = "start"
	input_blocker.hide()
	await map.await_start(stage, true)
	phase = "loading"
	input_blocker.show()
	await _capture_page()
	get_tree().current_scene = source
	map.queue_free()
	source.show()
	for layer in layers: layer.visible = layers[layer]
	active_camera.make_current()
	await get_tree().process_frame
	await _turn_page(false)
	source.process_mode = old_mode
	# Confirm and jump can share a button; returning must not trigger a jump.
	source.player.set_input_enabled(source.player.input_enabled)
	_finish()
	finished.emit(stage)

func start_intro() -> void:
	if busy: return
	get_node("/root/Narrator").reset_journey()
	visited_chapters.clear()
	sketches_shared = 0
	_begin(0, 1)

func _begin(origin: int, target: int) -> void:
	busy = true
	from_stage = origin
	target_stage = target
	input_blocker.show()
	_run.call_deferred()

func _capture_page() -> void:
	# Headless tests still exercise all scene/state/timing code without GPU reads.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		page.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	page_material.set_shader_parameter("progress", 0.0)
	page.show()

func _turn_page(returning_to_map: bool, seconds: float = 0.95, final_page: bool = false, previous_page: bool = false) -> void:
	phase = "page_to_ending" if final_page else ("page_to_map" if returning_to_map else "page_to_stage")
	page_material.set_shader_parameter("previous_page", previous_page)
	page_material.set_shader_parameter("paper_tint", Color("aab3b0") if final_page else Color("f5ecd4"))
	var tween := create_tween()
	tween.tween_method(func(value: float): page_material.set_shader_parameter("progress", value), 0.0, 1.0, seconds * duration_scale).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	page.hide()
	page.texture = null

func _run() -> void:
	var source := get_tree().current_scene
	var old_mode := source.process_mode
	source.process_mode = Node.PROCESS_MODE_DISABLED
	var destination: String = STAGES[target_stage - 1]
	var map: Node
	if source.scene_file_path == MAP:
		map = source
		map.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		await _capture_page()
		var error := get_tree().change_scene_to_file(MAP)
		if error != OK:
			_recover(source, old_mode, "The map could not be opened.")
			return
		await get_tree().scene_changed
		map = get_tree().current_scene
	# Finish loading shared map scripts before starting a chapter load.
	var load_error := ResourceLoader.load_threaded_request(destination)
	if load_error != OK:
		_recover(map, map.process_mode, "The next chapter could not be loaded.")
		return
	map.configure(from_stage, target_stage)
	await get_tree().process_frame
	if page.visible: await _turn_page(true)
	if not is_instance_valid(map) or get_tree().current_scene != map:
		_finish()
		return
	phase = "map"
	await map.play_route(from_stage, target_stage, duration_scale)
	phase = "start"
	input_blocker.hide()
	await map.await_start(target_stage)
	phase = "loading"
	input_blocker.show()
	while ResourceLoader.load_threaded_get_status(destination) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(destination) != ResourceLoader.THREAD_LOAD_LOADED:
		_recover(map, Node.PROCESS_MODE_INHERIT, "The next chapter could not be loaded. Try again.")
		return
	var packed: PackedScene = ResourceLoader.load_threaded_get(destination)
	await _capture_page()
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		_recover(map, Node.PROCESS_MODE_INHERIT, "The next chapter could not be opened. Try again.")
		return
	await get_tree().scene_changed
	var level := get_tree().current_scene
	level.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await _turn_page(false)
	level.process_mode = Node.PROCESS_MODE_INHERIT
	current_stage = target_stage
	_finish()
	finished.emit(current_stage)

func _run_ending() -> void:
	var source := get_tree().current_scene
	var old_mode := source.process_mode
	source.process_mode = Node.PROCESS_MODE_DISABLED
	phase = "ending_prepare"
	var error := ResourceLoader.load_threaded_request(ENDING)
	if error != OK:
		_recover(source, old_mode, "The last page could not be loaded. Try again.")
		return
	while ResourceLoader.load_threaded_get_status(ENDING) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(ENDING) != ResourceLoader.THREAD_LOAD_LOADED:
		_recover(source, old_mode, "The last page could not be loaded. Try again.")
		return
	var packed: PackedScene = ResourceLoader.load_threaded_get(ENDING)
	# Let the night scene breathe, then turn its last page without a bright flash.
	var hud: Control = source.hud_root
	var fade := create_tween()
	fade.tween_property(hud, "modulate:a", 0.0, 0.45 * duration_scale)
	await fade.finished
	await _capture_page()
	error = get_tree().change_scene_to_packed(packed)
	if error != OK:
		hud.modulate.a = 1.0
		_recover(source, old_mode, "The last page could not be opened. Try again.")
		return
	await get_tree().scene_changed
	var ending := get_tree().current_scene
	await get_tree().process_frame
	await _turn_page(false, 1.65, true)
	phase = "dawn"
	await ending.reveal_dawn(duration_scale)
	current_stage = 6
	_finish()
	finished.emit(current_stage)

func _recover(source: Node, old_mode: ProcessMode, message: String) -> void:
	if is_instance_valid(source):
		source.process_mode = old_mode
		if source.scene_file_path == MAP:
			# Keep the map reviewable and provide recovery without a dead-end screen.
			source.caption.text = message
			var retry := Button.new()
			retry.text = "Try again"
			source.caption.get_parent().add_child(retry)
			retry.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			retry.pressed.connect(func():
				retry.queue_free()
				_begin(from_stage, target_stage)
			)
		else:
			if "transitioning" in source: source.transitioning = false
			for exit_node in source.find_children("*", "Marker3D", true, false):
				if "transitioning" in exit_node: exit_node.transitioning = false
	_finish()
	failed.emit(message)
	push_error(message)

func _finish() -> void:
	page.hide()
	page.texture = null
	input_blocker.hide()
	busy = false
	phase = "idle"

func finish_stay(source: Node) -> void:
	if busy: return
	busy = true
	input_blocker.show()
	source.player.set_input_enabled(false)
	source.hud_root.hide()
	get_node("/root/Narrator").skip()
	await _capture_page()
	source.show_stay_book(page.texture)
	source.hud_root.show()
	await get_tree().process_frame
	await _turn_page(false, 1.65, true)
	_finish()
