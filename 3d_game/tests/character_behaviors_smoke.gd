extends SceneTree

var failed := false
var player
var camera: Camera3D
var stage: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func frames(count: int) -> void:
	for i in count:
		player.window_focused = true
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	if "--visual" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/paws-behavior-" + label + ".png")

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	shape.shape = box
	ground.position.y = -0.5
	ground.add_child(shape)
	stage.add_child(ground)
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(3, 2.2, 5)
	camera.look_at(Vector3(0, 0.9, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	stage.add_child(light)
	player = load("res://scenes/river/river_player.tscn").instantiate()
	stage.add_child(player)
	await frames(20)
	var hero = player.visual
	check(hero.state == "idle" and hero.standing_model.visible and not hero.character.visible, "Default idle displays the static stand delivery")
	check(absf(hero._bounds(hero.character).size.y - hero._bounds(hero.standing_model).size.y) < 0.01, "Static and rigged deliveries have matching height")
	await capture("stand")
	hero.idle_time = 6.0
	await frames(2)
	check(hero.state == "idle_variant" and hero.character.visible, "Remaining idle starts the alternative delivery")
	await capture("idle-variant")
	Input.action_press("move_up")
	Input.action_press("sprint")
	await frames(10)
	check(hero.state == "run", "Manual fast movement uses Running immediately")
	Input.action_release("sprint")
	await frames(3)
	check(hero.state == "walk", "Normal movement uses Walking")
	Input.action_release("move_up")
	player.respawn(Vector3.ZERO)
	await frames(5)
	hero.play_action("greet")
	await frames(30)
	check(hero.state == "greet", "Greeting survives stationary locomotion updates")
	await capture("greet")
	Input.action_press("move_up")
	await frames(3)
	check(hero.action.is_empty() and hero.state == "walk", "Movement interrupts greeting")
	Input.action_release("move_up")
	player.respawn(Vector3.ZERO)
	await frames(3)
	hero.play_action("knockdown")
	var start: Vector3 = player.position
	Input.action_press("move_up")
	await frames(60)
	check(hero.state == "knockdown" and player.position.distance_to(start) < 0.01, "Knockdown holds the capsule still")
	await capture("knockdown")
	await frames(70)
	check(hero.state == "arise", "Knockdown transitions into full Arise")
	await frames(125)
	check(not hero.blocks_movement and hero.state == "walk", "Recovery restores held movement input")
	Input.action_release("move_up")
	hero.play_action("knockdown")
	player.set_drawing_active(true)
	await frames(2)
	check(not hero.blocks_movement and hero.state == "think", "Drawing cancels knockdown without stale movement locks")
	player.set_drawing_active(false)
	hero.play_action("knockdown")
	player.respawn(Vector3.ZERO)
	check(hero.action.is_empty(), "Respawn clears reactions")
	var narrator = root.get_node("Narrator")
	narrator.panel.mic.set_process(false)
	narrator.scene = stage
	narrator.chapter = 4
	narrator.panel.mic.recording = true
	await frames(3)
	check(hero.state == "chat", "Chapter 4 recording selects Chat")
	narrator.chapter = 5
	await frames(3)
	check(hero.state == "boss_talk", "Chapter 5 recording selects Talk with boss")
	await capture("boss-talk")
	narrator.panel.mic.recording = false
	await frames(3)
	check(hero.state == "idle", "Recording completion restores locomotion")
	narrator.scene = null
	hero.play_action("celebrate")
	await frames(45)
	check(hero.state == "celebrate", "Celebration plays")
	await capture("celebrate")
	# Check every imported animation target, including bones only used by actions.
	for key in hero.SOURCES:
		var clip: Animation = hero.animator.get_animation("gameplay/" + key)
		for track in clip.get_track_count():
			var path := clip.track_get_path(track)
			check(hero.character.get_node_or_null(NodePath(str(path).split(":")[0])) != null, "Track resolves: " + str(path))
	player.hide()
	var boss = load("res://scenes/boss/storykeeper.tscn").instantiate()
	stage.add_child(boss)
	camera.position = Vector3(10, 8, 19)
	camera.look_at(Vector3(0, 5, 0))
	await frames(5)
	check(boss.behavior == "idle" and boss.animator.is_playing(), "Boss plays delivered idle loop")
	boss.block_enter()
	await frames(50)
	check(boss.behavior == "block", "Boss entrance plays page cycle")
	await capture("boss-block")
	boss.express("angry")
	await frames(60)
	check(boss.behavior == "angry", "Anger selects FuriousPages")
	await capture("boss-angry")
	boss.express("accepting")
	await frames(60)
	check(boss.behavior == "satisfied", "Acceptance selects SatisfiedWarm")
	await capture("boss-satisfied")
	boss.make_way()
	var next_x: float = boss.position.x - 1.5
	boss.make_way()
	await frames(120)
	check(absf(boss.position.x - next_x) < 0.01, "Repeated release does not move the boss twice")
	boss.express("angry")
	check(boss.behavior != "angry", "Released boss cannot re-enter the angry blockade")
	for key in boss.variants:
		check(boss.variants[key].model.visible == (key == boss.behavior), "Only one complete boss variant is visible")
	print("CHARACTER BEHAVIORS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
