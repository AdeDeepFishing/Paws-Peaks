extends SceneTree
var failed := false
var level
class MovementRig extends Node3D:
	var player
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failed = true
		push_error(message)
func frames(n):
	for i in n:
		if is_instance_valid(level): level.player.window_focused = true
		await physics_frame
		await process_frame
func capture(name: String):
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-hero-" + name + ".png")
func run():
	# Flat ground isolates the three-second transition from authored obstacles.
	level = MovementRig.new()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	level.add_child(floor_body)
	level.player = load("res://scenes/river/river_player.tscn").instantiate()
	level.add_child(level.player)
	root.add_child(level)
	await frames(30)
	Input.action_press("move_up")
	await frames(170)
	check(level.player.visual.state == "walk", "Under three seconds stays walking")
	check(absf(level.player.get_real_velocity().length() - level.player.base_speed) < 0.01, "First three seconds use walking speed")
	await frames(20)
	check(level.player.visual.state == "run", "Continuous walking switches to run after three seconds")
	check(is_equal_approx(level.player.velocity.length(), level.player.sprint_speed), "Automatic running actually increases travel speed")
	var running_start: Vector3 = level.player.position
	await frames(30)
	var running_distance: float = level.player.position.distance_to(running_start)
	check(running_distance > level.player.base_speed * 0.5 * 1.7, "Running covers clearly more ground than walking in the same time")
	Input.action_release("move_up")
	await frames(3)
	check(level.player.visual.state == "idle" and level.player.moving_seconds == 0, "Stopping clears the run timer")
	await frames(280)
	check(is_zero_approx(level.player.visual.position.y), "First idle hop waits five seconds")
	await frames(30)
	check(level.player.visual.position.y > 0.01, "Idle locator still appears after the delay")
	await frames(150)
	check(is_zero_approx(level.player.visual.position.y), "Idle cue rests after its short burst")
	Input.action_press("move_up")
	await frames(10)
	check(level.player.visual.state == "walk", "Restarting starts with walking")
	check(absf(level.player.get_real_velocity().length() - level.player.base_speed) < 0.01, "Restarting also returns to walking speed")
	Input.action_release("move_up")
	await frames(5)
	Input.action_press("sprint")
	Input.action_press("move_up")
	await frames(10)
	check(level.player.visual.state == "walk", "Shift does not bypass a fresh animation timer")
	check(absf(level.player.get_real_velocity().length() - level.player.sprint_speed) < 0.01, "Shift retains manual acceleration")
	Input.action_release("move_up")
	Input.action_release("sprint")
	level.queue_free()
	await frames(2)
	level = load("res://scenes/woodland/woodland_path.tscn").instantiate()
	root.add_child(level)
	await frames(45)
	var hero = level.player.visual
	check(hero.scale.is_equal_approx(Vector3.ONE * 1.2), "Woodland character is twenty percent larger")
	check(hero.character.find_children("*","Skeleton3D",true,false).size() == 1, "One shared skinned character")
	check(hero.state == "idle", "Standing uses delivered idle clip")
	check(hero.animator.current_animation == "gameplay/idle", "Standing plays the full listening gesture")
	check(is_equal_approx(hero.animator.get_animation("gameplay/idle").length, 9.4), "Idle uses the full Listening Gesture delivery")
	var idle_time: float = hero.animator.current_animation_position
	await frames(10)
	check(hero.animator.current_animation_position > idle_time, "Listening gesture advances while standing")
	for name in ["idle","walk","run"]:
		var clip: Animation = hero.animator.get_animation("gameplay/" + name)
		check(clip.length > 0.5 and clip.loop_mode == Animation.LOOP_LINEAR, "Full looping " + name + " clip")
		for track in clip.get_track_count():
			if clip.track_get_type(track)==Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)).ends_with(":Hips"):
				var initial: Vector3 = clip.track_get_key_value(track, 0)
				for frame in clip.track_get_key_count(track):
					var position: Vector3 = clip.track_get_key_value(track,frame)
					check(is_equal_approx(initial.x,position.x) and is_equal_approx(initial.z,position.z), "Animation cannot drift outside its collider")
	await capture("woodland")
	Input.action_press("move_up")
	await frames(20)
	check(hero.state == "walk", "Walking input selects walking animation")
	Input.action_press("sprint")
	await frames(15)
	check(hero.state == "walk", "Shift does not bypass the three-second animation delay")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await frames(5)
	Input.action_press("jump")
	await frames(4)
	Input.action_release("jump")
	check(hero.state == "air" and hero.animator.current_animation == "gameplay/stand", "Airborne fallback freezes pose without moving the collider")
	await frames(65)
	check(hero.state == "idle" and level.player.is_on_floor(), "Landing restores idle playback")
	level.player.set_input_enabled(false)
	await frames(3)
	check(hero.state == "idle", "Drawing or camera lock stops locomotion animation")
	level.queue_free()
	await frames(2)
	level = load("res://scenes/river/river_crossing.tscn").instantiate()
	root.add_child(level)
	await frames(45)
	check(level.player.visual.character != null, "River uses the same protagonist")
	check(level.player.visual.scale.is_equal_approx(Vector3.ONE * 2.0), "River displays the character at twice the original size")
	level.player.respawn(Vector3(-4.1, 1.5, -6.3))
	await frames(45)
	level._open_book()
	await frames(8)
	check(level.panel_mode == "draw" and level.player.visual.state == "think", "Drawing entry starts thinking animation")
	var thinking_time: float = level.player.visual.animator.current_animation_position
	await frames(10)
	check(level.player.visual.animator.current_animation_position > thinking_time, "Thinking clip plays while movement is locked")
	await capture("thinking")
	level._close_panel(true)
	await frames(5)
	check(level.player.visual.state == "idle" and level.player.input_enabled, "Cancel restores quiet idle and input")
	await capture("river")
	level.queue_free()
	await frames(2)
	print("HERO SMOKE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
