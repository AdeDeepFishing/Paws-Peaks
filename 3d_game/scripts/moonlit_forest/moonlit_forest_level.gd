extends "res://scripts/woodland/woodland_level.gd"

## Explicit test/authoring preview only. Real play requires a narrator resolution.
@export var preview_ending_enabled := false
var released := false
var stay_presented := false
var book: Control

func _ready() -> void:
	super._ready()
	objective.text = "Meet the Storykeeper. Share an idea, a drawing, or a goodbye."
	var narrator := get_node("/root/Narrator")
	narrator.state_changed.connect(_story_changed)
	narrator.reply_ready.connect(_reply)
	draw_button.text = "Talk or draw"
	draw_button.tooltip_text = "Share an idea with the Storykeeper."
	draw_button.pressed.connect(narrator.panel.open_dialogue)

func _process(delta: float) -> void:
	super._process(delta)
	draw_button.disabled = entering or stay_presented
	if released and not entering and player.position.z <= -12 and not preview_ending_enabled:
		get_node("/root/Narrator").crossed_exit()

func constrain_player(body: CharacterBody3D) -> void:
	if not preview_ending_enabled and not released:
		body.position.z = maxf(body.position.z, -10.8)

func can_exit() -> bool:
	return preview_ending_enabled

func _reply(result: Dictionary) -> void:
	$Storykeeper.express(str(result.utterance.emotion))

func _story_changed(state: Dictionary) -> void:
	if state.get("stage") != 5: return
	if state.get("exit_open", false) and not released:
		released = true
		objective.text = "The way is open. Cross the clearing when you are ready."
		$Storykeeper.make_way()
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
