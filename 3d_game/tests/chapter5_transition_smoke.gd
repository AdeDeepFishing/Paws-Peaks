extends SceneTree

## Guard the measured 590 ms entry regression. Cold GPU upload still varies;
## this is a desktop regression budget, not a 60 FPS or Web performance claim.
func _initialize(): call_deferred("run")
func run():
	root.get_node("Narrator").enabled = false
	var journey = root.get_node("Journey")
	journey.duration_scale = 0.1
	var map = load(journey.MAP).instantiate()
	map.autoplay = false
	root.add_child(map)
	current_scene = map
	await process_frame
	journey._begin(4, 5)
	var previous := Time.get_ticks_usec()
	var previous_phase := "begin"
	var maxima := {}
	for i in 1800:
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - previous) / 1000.0
		maxima[previous_phase] = maxf(maxima.get(previous_phase, 0.0), ms)
		previous = now
		previous_phase = journey.phase
		if journey.phase == "start": current_scene.start_button.pressed.emit()
		if not journey.busy: break
	print("CHAPTER 5 FRAME MAX MS: ", maxima)
	var worst := 0.0
	for key in maxima: worst = maxf(worst, maxima[key])
	print("CHAPTER 5 TRANSITION: ", "STALL" if worst > 350.0 else "PASS", " max=", worst)
	quit(1 if worst > 350.0 else 0)
