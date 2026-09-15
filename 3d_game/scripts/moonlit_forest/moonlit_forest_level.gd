extends "res://scripts/woodland/woodland_level.gd"

## Explicit test/authoring preview only. Real play requires a narrator resolution.
@export var preview_ending_enabled := false
var daybreak: Node
var released := false
var stay_presented := false
var book: Control
var mood_label: Label
var mood_bar: ProgressBar
var mood_hint: Label
var mood_layer: CanvasLayer
var boss_revealed := false
var reveal_started := false
var reveal_timer := 0.0

func _ready() -> void:
	super._ready()
	daybreak = preload("res://scripts/moonlit_forest/daybreak.gd").new()
	add_child(daybreak)
	daybreak.setup(self)
	objective.text = "Meet the Storykeeper. Share an idea, a drawing, or a goodbye."
	status.text = objective.text
	status.set_meta("narrator_guidance", status.text)
	var narrator := get_node("/root/Narrator")
	narrator.state_changed.connect(_story_changed)
	narrator.reply_ready.connect(_reply)
	draw_button.tooltip_text = "E · Draw"
	draw_button.tooltip_text = "Share an idea with the Storykeeper."
	draw_button.pressed.connect(func(): narrator.panel.open_dialogue(); narrator.panel._draw_idea())
	_build_mood()
	$ObjectGeneration.setup()
	$Storykeeper/Character.hide()
	mood_layer.hide()

func _process(delta: float) -> void:
	super._process(delta)
	if not entering and not reveal_started:
		reveal_timer += delta
		var narrator = get_node("/root/Narrator")
		# Let live narration begin before the paper moves; offline/error paths are bounded.
		if narrator.enabled and reveal_timer < 8.0 and (narrator.panel.reveal_text.is_empty() or (narrator.voice_enabled and not narrator.panel.speech_started)):
			draw_button.disabled = true
			return
		reveal_started = true
		player.set_input_enabled(false)
		get_node("/root/Narrator").panel.animate_boss_reveal(_reveal_boss)
	draw_button.disabled = entering or stay_presented or not boss_revealed or $ObjectGeneration.request.state == "PENDING"
	if released and not entering and player.position.z <= -12 and not preview_ending_enabled and not get_node("/root/Narrator").panel.opened:
		get_node("/root/Narrator").crossed_exit()

func constrain_player(body: CharacterBody3D) -> void:
	if not preview_ending_enabled and not released:
		body.position.z = maxf(body.position.z, $Storykeeper.position.z)

func can_exit() -> bool:
	return preview_ending_enabled

func _reply(result: Dictionary) -> void:
	$Storykeeper.express(str(result.utterance.emotion))

func _story_changed(state: Dictionary) -> void:
	if state.get("stage") != 5: return
	_update_mood(int(state.get("mood", 37)))
	if state.get("exit_open", false) and not released:
		released = true
		get_node("/root/GameAudio").play_cue("ready")
		objective.text = "The way is open. Cross the clearing when you are ready."
		status.text = objective.text
		status.set_meta("narrator_guidance", status.text)
		$Storykeeper.make_way()
		player.visual.play_action("celebrate")
		daybreak.go(1.0, get_node("/root/Journey").duration_scale)
	if state.get("ending") == "stay" and not stay_presented:
		stay_presented = true
		get_node("/root/Journey").finish_stay(self)

func show_stay_book(memory: Texture2D) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.1, 0.12, 0.65)
	layer.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book = preload("res://scripts/ending/ending_book.gd").new()
	layer.add_child(book)
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var journey := get_node("/root/Journey")
	book.set_memory(memory, journey.visited_chapters, journey.sketches_shared)
	book.set_stay_ending()
	book.replay_requested.connect(func(): journey.start_intro())
	book.explore_requested.connect(func(): layer.hide(); player.set_input_enabled(true))
	var reopen := Button.new()
	reopen.text = "Your final page"
	reopen.position = Vector2(28, 185)
	hud_root.add_child(reopen)
	reopen.pressed.connect(func(): player.set_input_enabled(false); layer.show())

## Trusted completion hook; normal play reaches it after the exit event commits.
func complete_boss_encounter() -> void:
	$EndingExit.activate()


func _build_mood() -> void:
	mood_layer = CanvasLayer.new()
	mood_layer.layer = 25
	add_child(mood_layer)
	var card := PanelContainer.new()
	mood_layer.add_child(card)
	card.hide()
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -338
	card.offset_right = -28
	card.offset_top = 104
	card.offset_bottom = 204
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.07, 0.13, 0.14, 0.82)
	paper.set_corner_radius_all(14)
	paper.set_content_margin_all(14)
	card.add_theme_stylebox_override("panel", paper)
	var stack := VBoxContainer.new()
	card.add_child(stack)
	mood_label = Label.new()
	mood_label.add_theme_font_size_override("font_size", 18)
	mood_label.add_theme_color_override("font_color", Color("fff9ed"))
	stack.add_child(mood_label)
	mood_bar = ProgressBar.new()
	mood_bar.custom_minimum_size.y = 16
	mood_bar.min_value = 0
	mood_bar.max_value = 100
	mood_bar.step = 1
	var track := StyleBoxFlat.new()
	track.bg_color = Color("526561")
	track.set_corner_radius_all(2)
	track.set_content_margin_all(0)
	mood_bar.add_theme_stylebox_override("background", track)
	mood_bar.show_percentage = false
	stack.add_child(mood_bar)
	mood_hint = Label.new()
	mood_hint.add_theme_font_size_override("font_size", 14)
	mood_hint.add_theme_color_override("font_color", Color("e0e5d4"))
	stack.add_child(mood_hint)
	_update_mood(37)

func _update_mood(value: int) -> void:
	if mood_bar == null: return
	mood_bar.value = value
	mood_hint.text = "The way is open." if released or value >= 95 else "Reach 95% to open the way."
	mood_label.text = "Storykeeper's mood · %d%%" % value
	mood_label.tooltip_text = "Talk or share a drawing. Reach 95% to open the way."
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("df7064") if value < 20 else (Color("8fca98") if value > 80 else Color("edc66d"))
	fill.set_corner_radius_all(2)
	fill.set_content_margin_all(0)
	mood_bar.add_theme_stylebox_override("fill", fill)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sketchbook") and not entering and boss_revealed and not stay_presented:
		var panel = get_node("/root/Narrator").panel
		panel.open_dialogue()
		panel._draw_idea()
		get_viewport().set_input_as_handled()

## Journey waits for both atmosphere beats before the final page turn.
func finish_daybreak(timing: float) -> void:
	player.set_input_enabled(false)
	hud_root.hide()
	mood_layer.hide()
	await daybreak.go(1.0, timing)
	await daybreak.go(2.0, timing)
	await get_tree().create_timer(1.0 * timing).timeout

func _reveal_boss() -> void:
	boss_revealed = true
	$Storykeeper.block_enter()
	player.visual.play_action("greet")
	var character: Node3D = $Storykeeper/Character
	character.show()
	var final_scale := character.scale
	character.scale = final_scale * .04
	var pop := create_tween()
	pop.tween_property(character, "scale", final_scale * 1.06, .18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(character, "scale", final_scale, .22).set_trans(Tween.TRANS_SINE)
	pop.tween_callback(func(): player.set_input_enabled(true))
	get_node("/root/GameAudio").play_cue("reveal")
