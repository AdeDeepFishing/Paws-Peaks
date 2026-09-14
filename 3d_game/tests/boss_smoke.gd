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
	check(boss.get_node("Character").scale.is_equal_approx(Vector3.ONE*1.6), "Boss retains giant scale")
	check(not boss.anger_clip.is_empty(), "Supplied page cycle is available")
	boss.express("angry")
	check(boss.animator.is_playing(), "Anger starts the delivered page cycle")
	check(is_equal_approx(boss.animator.current_animation_length,6.2), "Full delivered cycle is retained")
	boss._idle()
	Input.action_press("move_up")
	for i in 180:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < -2.0, "The player can approach the giant boss")
	check(level.player.position.z > boss.position.z + .5, "The player cannot walk through the boss body")
	check(level.player.is_on_floor(), "Approaching the boss keeps the player grounded")
	var start_position: Vector3 = boss.position
	boss.make_way()
	await frames(130)
	check(boss.position.is_equal_approx(start_position), "Release does not move the boss")
	check(absf(boss.rotation.y-PI/2)<.01, "Release turns the boss ninety degrees")
	level.released = true
	level.preview_ending_enabled = false
	level.player.position = Vector3(1.2,level.player.position.y,0)
	Input.action_press("move_up")
	for i in 170:
		level.player.window_focused = true
		await frames(1)
	Input.action_release("move_up")
	check(level.player.position.z < -8, "Player can pass beside the rotated narrow collider")
	print("BOSS APPROACH: ", level.player.position, " BOSS: ", boss.position)
	print("BOSS SMOKE: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
