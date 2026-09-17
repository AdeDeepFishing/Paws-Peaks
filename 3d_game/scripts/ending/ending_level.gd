extends "res://scripts/woodland/woodland_level.gd"

const EndingBook = preload("res://scripts/ending/ending_book.gd")
var book: Control
var veil: ColorRect
var exploration: Control
var memory: Texture2D
var presentation_phase := "arrival"
var book_tween: Tween
var ambience: Environment
signal preparation_finished
var prepared := false

func wait_until_prepared() -> void:
	if not prepared: await preparation_finished

func _ready() -> void:
	super._ready()
	player.set_input_enabled(false)
	await get_node(art_path).wait_until_prepared()
	var daybreak = preload("res://scripts/moonlit_forest/daybreak.gd").new()
	add_child(daybreak)
	daybreak.setup(self)
	daybreak.set_value(2.0)
	prepared = true
	preparation_finished.emit()
	ambience = $WorldEnvironment.environment
	# F6 remains a complete preview; Journey owns timing for the normal final exit.
	if not get_node("/root/Journey").busy:
		reveal_dawn.call_deferred(get_node("/root/Journey").duration_scale)

func reveal_dawn(timing: float = 1.0) -> void:
	if presentation_phase != "arrival": return
	presentation_phase = "dawn"
	await wait_until_prepared()
	await get_tree().create_timer(0.6 * timing).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		memory = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var journey := get_node("/root/Journey")
	book.set_memory(memory, journey.visited_chapters, journey.sketches_shared)
	await show_book(timing)

func _build_ui() -> void:
	var hud := CanvasLayer.new()
	hud.name = "EndingHUD"
	add_child(hud)
	hud_root = Control.new()
	hud.add_child(hud_root)
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil = ColorRect.new()
	hud_root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color("122c30")
	veil.modulate.a = 0.0
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exploration = Control.new()
	hud_root.add_child(exploration)
	exploration.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	exploration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	exploration.hide()
	status = _label(exploration, "Stay a while. A new day is beginning.", 16)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	status.position += Vector2(28, -52)
	status.add_theme_color_override("font_color", Color("fff9ed"))
	status.add_theme_color_override("font_outline_color", Color("273d36"))
	status.add_theme_constant_override("outline_size", 4)
	objective = status
	book = EndingBook.new()
	book.name = "VictoryBook"
	hud_root.add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.hide()
	book.replay_requested.connect(_replay)
	book.explore_requested.connect(_explore)

func show_book(timing: float = 1.0) -> void:
	if presentation_phase in ["book", "opening_book", "leaving"]: return
	presentation_phase = "opening_book"
	player.set_input_enabled(false)
	exploration.hide()
	book.show()
	book.modulate.a = 0.0
	book.set_actions_enabled(false)
	if book_tween: book_tween.kill()
	book_tween = create_tween().set_parallel(true)
	book_tween.tween_property(veil, "modulate:a", 0.0, 0.8 * timing).set_trans(Tween.TRANS_SINE)
	book_tween.tween_property(book, "modulate:a", 1.0, 0.8 * timing).set_trans(Tween.TRANS_SINE)
	await book_tween.finished
	presentation_phase = "book"
	book.set_actions_enabled(true)
	book.replay.grab_focus()

func _explore() -> void:
	if presentation_phase != "book": return
	presentation_phase = "closing_book"
	book.set_actions_enabled(false)
	book_tween = create_tween().set_parallel(true)
	book_tween.tween_property(book, "modulate:a", 0.0, 0.25)
	book_tween.tween_property(veil, "modulate:a", 0.0, 0.35)
	await book_tween.finished
	book.hide()
	exploration.show()
	presentation_phase = "explore"
	player.set_input_enabled(true)

func _replay() -> void:
	if presentation_phase != "book": return
	presentation_phase = "leaving"
	book.set_actions_enabled(false)
	get_node("/root/Journey").start_intro()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and presentation_phase == "book":
		get_viewport().set_input_as_handled()
		_explore()

func _start_entrance() -> void:
	# The epilogue owns its reveal; chapter entrance walks must not unlock its book.
	await get_node(art_path).wait_until_prepared()
	await get_tree().physics_frame
	player.show()
	entering = false
	player.walking_in = false
	player.set_input_enabled(false)
	hud_root.show()
