extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
func run() -> void:
	create_timer(20).timeout.connect(func(): push_error("Daybreak test timed out"); quit(1))
	var journey = root.get_node("Journey")
	journey.duration_scale = .02
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(.6).timeout
	var level = current_scene
	var atmosphere = level.daybreak
	check(atmosphere.value == 0 and not atmosphere.sun.visible,"Chapter 5 begins at night")
	level._story_changed({"stage":5,"mood":95,"exit_open":true})
	await atmosphere.settled
	check(atmosphere.value == 1 and not atmosphere.sun.visible,"Release reaches dawn without sunrise")
	check(atmosphere.night_meshes.all(func(mesh): return not mesh.visible),"Moon and firefly bodies vanish at dawn")
	for light in atmosphere.lights:
		if "firefly" in str(light.name).to_lower(): check(light.light_energy == 0,"No invisible firefly light at dawn")
	await atmosphere.go(2,.02)
	check(atmosphere.sun.visible and atmosphere.sun.position.y == 40,"Sun rises to delivered endpoint")
	atmosphere.set_value(0)
	atmosphere.go(1,.02)
	level.entering = false
	level.complete_boss_encounter()
	await journey.finished
	check(current_scene.name == "DawnForest" and current_scene.presentation_phase == "book","Sunrise leads to the victory book")
	check(current_scene.get_node("DawnArt").find_child("DaybreakSun",true,false).visible,"Epilogue preserves sunrise")
	print("DAYBREAK SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
