extends SceneTree

const Store = preload("res://scripts/river/draft_store.gd")
const Request = preload("res://scripts/river/drawing_request.gd")
var failed := false

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func write(path: String, bytes: PackedByteArray):
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
func run():
	var directory := "user://test-drawings/retention-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var bitmap := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	bitmap.fill(Color.WHITE)
	var first := bitmap.save_png_to_buffer()
	bitmap.fill(Color.BLACK)
	var second := bitmap.save_png_to_buffer()
	var old_name := "E01-2026-09-13T12-30-00-abcdef0123456789.png"
	write(directory.path_join(old_name), first)
	write(directory.path_join("E01-latest.png"), first)
	write(directory.path_join("notes.txt"), "Keep this unrelated file.".to_utf8_buffer())
	var river := Request.new()
	river.draft_directory = directory
	river.mock_delay = 60
	root.add_child(river)
	check(river.submit(first, "E01"), "River submission succeeds")
	check(not FileAccess.file_exists(directory.path_join(old_name)), "Successful save removes legacy timestamped exports")
	check(not FileAccess.file_exists(directory.path_join("E01-latest.png")), "Migration removes the previous stage-specific latest export")
	var dog := Request.new()
	dog.draft_directory = directory
	dog.mock_delay = 60
	root.add_child(dog)
	check(dog.submit(second, "E02"), "Another encounter saves through the same draft store")
	check(river.saved_draft_path == dog.saved_draft_path, "Stages share one latest draft path")
	check(FileAccess.get_file_as_bytes(dog.saved_draft_path) == second, "Latest draft contains the newest submission")
	check(river.snapshot == first, "Replacing the draft export cannot change an in-flight request's input")
	check(FileAccess.file_exists(directory.path_join("notes.txt")), "Cleanup preserves unrelated files")
	dog.cancel()
	check(not dog.submit(PackedByteArray(), "E02"), "Invalid submission is rejected")
	check(FileAccess.get_file_as_bytes(directory.path_join("latest.png")) == second, "Invalid submission cannot replace the latest draft")
	var failure_dir := directory.path_join("failure")
	DirAccess.make_dir_recursive_absolute(failure_dir.path_join("latest.png"))
	write(failure_dir.path_join(old_name), first)
	check(Store.save_latest(second, failure_dir).is_empty(), "Failed atomic replacement is reported")
	check(FileAccess.file_exists(failure_dir.path_join(old_name)), "Failed save cannot delete the last old draft")
	check(DirAccess.get_files_at(failure_dir).size() == 1, "Failed save removes its temporary file")
	river.queue_free()
	dog.queue_free()
	for name in DirAccess.get_files_at(failure_dir): DirAccess.remove_absolute(failure_dir.path_join(name))
	DirAccess.remove_absolute(failure_dir.path_join("latest.png"))
	DirAccess.remove_absolute(failure_dir)
	for name in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	await process_frame
	print("DRAFT RETENTION SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
