extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mix = root.get_node("GameAudio")
	var expected := {"res://scenes/river/river_crossing.tscn": "chapters_1_3", "res://scenes/wind_hill/wind_hill.tscn": "chapters_1_3", "res://scenes/sunset_cove/sunset_cove.tscn": "otter", "res://scenes/moonlit_forest/moonlit_forest.tscn": "storykeeper", "res://scenes/ending/dawn_forest.tscn": "ending"}
	for path in expected: assert(mix.track_for(path) == expected[path])
	for track in mix.TRACKS:
		mix._select(track)
		assert(mix.streams[track].loop)
		assert(mix.streams[track].get_length() > 10)
		print("BGM ", track, ": ", snappedf(mix.streams[track].get_length(), 0.1), " seconds")
	mix._select("chapters_1_3")
	var slot: int = mix.slot
	mix._select("chapters_1_3")
	assert(mix.slot == slot, "Moving within Chapters 1–3 does not restart music")
	for cue in mix.cues: assert(mix.cues[cue].get_length() > 0)
	var narrator = root.get_node("Narrator")
	var music: float = mix.music_volume
	var effects: float = mix.effects_volume
	mix.set_voice_volume(0.25)
	assert(is_equal_approx(narrator.audio.volume_linear, 0.25))
	assert(mix.music_volume == music and mix.effects_volume == effects, "Voice volume leaves music and effects unchanged")
	mix.set_voice_volume(0.0)
	assert(is_zero_approx(narrator.audio.volume_linear))
	mix.set_voice_volume(1.0)
	mix.set_muted(true)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	mix.set_muted(false)
	print("GAME AUDIO SMOKE: PASS")
	quit()
