extends RefCounted

## Boundary tests still cross real exits; only presentation time is shortened.
static func fast(tree: SceneTree) -> void:
	tree.root.get_node("Journey").duration_scale = 0.01

static func complete(tree: SceneTree) -> void:
	var journey := tree.root.get_node("Journey")
	for i in 1800:
		await tree.physics_frame
		await tree.process_frame
		if journey.phase == "start":
			tree.current_scene.start_button.pressed.emit()
		if not journey.busy: return
	push_error("Chapter presentation did not finish within 30 seconds")
	tree.quit(1)
