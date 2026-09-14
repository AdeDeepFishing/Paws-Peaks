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
	mix.set_muted(true)
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	mix.set_muted(false)
	print("GAME AUDIO SMOKE: PASS")
	quit()
