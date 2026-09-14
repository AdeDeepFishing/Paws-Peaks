extends Node

## Opt-in local transform sampling. No provider payloads or asset paths are logged.
const FLAG := "--generated-object-diagnostics"
const INTERVAL_SECONDS := 1.0
static var log_path := ""
var target: Node3D
var object_id := 0
var previous_position := Vector3.ZERO
var previous_time := 0

static func attach(visual: Node3D) -> void:
	if not OS.get_cmdline_user_args().has(FLAG): return
	visual.ready.connect(func():
		var tracker := new()
		tracker.target = visual
		visual.get_tree().root.add_child.call_deferred(tracker)
	, CONNECT_ONE_SHOT)

func _ready() -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	if log_path.is_empty():
		var folder := "user://diagnostics"
		if DirAccess.make_dir_recursive_absolute(folder) != OK:
			push_warning("Could not create the generated-object diagnostics folder.")
			queue_free()
			return
		log_path = folder.path_join("generated-objects-%d-%d.jsonl" % [int(Time.get_unix_time_from_system()), OS.get_process_id()])
		print("Generated-object diagnostics: ", ProjectSettings.globalize_path(log_path))
	object_id = target.get_instance_id()
	previous_position = target.global_position
	previous_time = Time.get_ticks_msec()
	_sample("spawn")

func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		_write({"event": "removed", "object_id": object_id, "elapsed_ms": Time.get_ticks_msec()})
		queue_free()
		return
	if Time.get_ticks_msec() - previous_time >= int(INTERVAL_SECONDS * 1000):
		_sample("sample")

func _sample(event: String) -> void:
	var now := Time.get_ticks_msec()
	var location := target.global_position
	var velocity := (location - previous_position) / maxf((now - previous_time) / 1000.0, 0.001)
	var parent := target.get_parent()
	if parent is RigidBody3D: velocity = parent.linear_velocity
	var row := {"event": event, "object_id": object_id, "elapsed_ms": now,
		"unix_time": Time.get_unix_time_from_system(), "world_position": _vector(location),
		"velocity": _vector(velocity), "visible_in_tree": target.is_visible_in_tree()}
	var camera := target.get_viewport().get_camera_3d()
	if camera:
		var screen := camera.unproject_position(location)
		row["screen_position"] = [screen.x, screen.y]
		row["origin_in_view"] = not camera.is_position_behind(location) and target.get_viewport().get_visible_rect().has_point(screen)
	_write(row)
	previous_position = location
	previous_time = now

func _write(row: Dictionary) -> void:
	# Open per sample so multiple objects append safely and crashes retain prior rows.
	var output := FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if output == null:
		push_warning("Could not write generated-object diagnostics.")
		set_process(false)
		return
	output.seek_end()
	output.store_line(JSON.stringify(row))
	output.close()

static func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
