extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func run() -> void:
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	var level = current_scene
	level.preview_ending_enabled = false
	await frames(45)
	var boss = level.get_node("Storykeeper")
	check(boss.grounded, "The Storykeeper settles on the forest terrain")
	check(boss.find_children("*", "MeshInstance3D", true, false).size() == 148, "All delivered boss meshes are retained")
	check(boss.get_node("Character").scale.is_equal_approx(Vector3.ONE * 1.6), "Boss retains its giant scale")
	var animator: AnimationPlayer = boss.animator
	check(animator.is_playing() and animator.current_animation == "boss/idle", "The delivered hand lift and sway play on entry")
	var clip := animator.get_animation("boss/idle")
	check(is_equal_approx(clip.length, 4.0) and clip.loop_mode == Animation.LOOP_LINEAR, "The four-second idle repeats")
	var skeleton: Skeleton3D = boss.find_child("Skeleton3D", true, false)
	check(skeleton != null and skeleton.get_bone_count() == 3, "The supplied rig survives import")
	for bone_name in ["body_sway", "right_hand_book"]:
		var bone := skeleton.find_bone(bone_name)
		animator.seek(0.0, true)
		var before := skeleton.get_bone_pose(bone)
		animator.seek(1.0, true)
		check(not skeleton.get_bone_pose(bone).is_equal_approx(before), "Delivered motion animates " + bone_name)
		animator.seek(3.99, true)
		before = skeleton.get_bone_pose(bone)
		animator.advance(0.02)
		var after := skeleton.get_bone_pose(bone)
		check(before.origin.distance_to(after.origin) < 0.05 and before.basis.get_rotation_quaternion().angle_to(after.basis.get_rotation_quaternion()) < 0.05, "The idle loop stays continuous for " + bone_name)
	Input.action_press("move_up")
	for i in 180:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < -2.0, "The player can approach the giant boss")
	check(level.player.position.z > boss.position.z + 2.1, "The player cannot walk through the boss body")
	check(level.player.is_on_floor(), "Approaching the boss keeps the player grounded")
	print("BOSS APPROACH: ", level.player.position, " BOSS: ", boss.position)
	print("BOSS SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
