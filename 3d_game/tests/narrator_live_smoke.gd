extends SceneTree
## Explicit live integration check; never included in offline test discovery.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if "--allow-live" not in OS.get_cmdline_user_args():
		print("Pass -- --allow-live to authorize one narrator reply and voice generation.")
		quit(1)
		return
	var narrator := root.get_node("Narrator")
	narrator.enabled = true
	narrator.auto_narration = false
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(3).timeout
	for i in 200:
		if narrator.queue.is_empty() and narrator.active.is_empty() and not narrator.state.is_empty(): break
		await create_timer(0.1).timeout
	if narrator.state.is_empty():
		push_error("Narrator initialization failed")
		quit(1)
		return
	narrator.panel.open_dialogue()
	narrator.ask("Hello. I would like to rest for a moment, without ending my journey.")
	var reply_received := false
	for i in 900:
		await create_timer(0.1).timeout
		if not narrator.last_error.is_empty():
			push_error(narrator.last_error)
			quit(1)
			return
		if not narrator.last_utterance.is_empty(): reply_received = true
		if narrator.audio.playing: break
	print("LIVE NARRATOR: reply=", reply_received, " voice_playing=", narrator.audio.playing, " phase=", narrator.state.get("phase"), " ending=", narrator.state.get("ending"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/narrator63-live-game.png")
	var passed: bool = reply_received and narrator.audio.playing and narrator.state.get("ending") == null
	await create_timer(3).timeout
	quit(0 if passed else 1)
