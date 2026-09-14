extends SceneTree
func _initialize(): call_deferred("run")
func shot(label):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/private/tmp/boss72-"+label+".png")
func run():
	root.size = Vector2i(1152,720)
	change_scene_to_file("res://scenes/moonlit_forest/moonlit_forest.tscn")
	await scene_changed
	await create_timer(3).timeout
	var boss = current_scene.get_node("Storykeeper")
	await shot("idle")
	boss.express("angry")
	await create_timer(2.8).timeout
	await shot("angry")
	boss.make_way()
	await create_timer(2).timeout
	assert(absf(boss.rotation.y-PI/2)<.01)
	assert(is_zero_approx(boss.position.x))
	await shot("release")
	print("BOSS72 VISUAL: PASS")
	quit()
