extends "res://tests/dog_presentation_smoke.gd"
func run():
	await fresh()
	level.presentation.duration_scale = .03
	await frames(120)
	start()
	await wait_until(func(): return level.presentation.phase == "waiting")
	level.player.set_physics_process(false)
	level.player.position = level.dog.home + Vector3(50,2,50)
	check(not level.near_dog(),"Player left offering proximity during generation")
	respond()
	check(is_instance_valid(level.offered),"Ready model is offered without another E press even away from the dog")
	await wait_until(func(): return level.dog.distracted)
	check(not "Offer" in level.draw_button.text,"Draw CTA has no second offer step")
	print("AUTOMATIC OFFERING SMOKE: ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
