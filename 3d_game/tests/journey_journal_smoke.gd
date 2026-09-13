extends SceneTree

const JourneyTest = preload("res://tests/journey_test_helpers.gd")
var failed := false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	var journey := root.get_node("Journey")
	JourneyTest.fast(self)
	change_scene_to_file(journey.STAGES[0])
	await scene_changed
	var request: Node = current_scene.get_node("DrawingRequest")
	current_scene.get_node("DesktopGeneration").mode = 0
	request.mock_mode = false
	check(journey.visited_chapters == [1], "A direct chapter launch records only that chapter")
	check(not request.submit(PackedByteArray(), "E01"), "Empty submissions are rejected")
	check(journey.sketches_shared == 0, "Rejected submissions do not count as shared sketches")
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color("b4955d"))
	var png := image.save_png_to_buffer()
	check(request.submit(png, "E01"), "A valid sketch is accepted")
	check(journey.sketches_shared == 1, "Accepted sketch counts through the real request signal")
	check(not request.submit(png, "E01") and journey.sketches_shared == 1, "Pending double-submit does not add another sketch")
	request.cancel()
	check(request.submit(png, "E01") and journey.sketches_shared == 2, "A deliberate resubmission counts as another shared sketch")
	request.cancel()
	await process_frame
	await process_frame
	change_scene_to_file(journey.STAGES[4])
	await scene_changed
	check(journey.visited_chapters == [1, 5], "Skipped chapters are never invented in the recap")
	current_scene.complete_boss_encounter()
	await process_frame
	await JourneyTest.complete(self)
	check(current_scene.book.chapters_value.text == "2 / 5", "Victory uses the actual visited chapter count")
	check(current_scene.book.sketches_value.text == "2", "Victory displays actual shared submissions")
	current_scene.book.replay.pressed.emit()
	await JourneyTest.complete(self)
	check(journey.visited_chapters == [1] and journey.sketches_shared == 0, "Replay starts a fresh session journal")
	print("JOURNEY JOURNAL SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
