extends SceneTree

# Run with --script and pass the folder containing the original Meshy imports after --.
func _initialize(): call_deferred("run")

func load_model(path: String) -> Node3D:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_buffer(FileAccess.get_file_as_bytes(path), "", state) != OK:
		return null
	return document.generate_scene(state)

func run():
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Provide the source import directory")
		quit(1)
		return
	var library := AnimationLibrary.new()
	var base: Node3D
	var skeleton_signature: Array = []
	for index in 13:
		var name := "Otterly Adorable" + ("_" + str(index) if index else "")
		var model := load_model(args[0].path_join(name).path_join(name + ".glb"))
		assert(model != null, "Source model must load")
		var skeleton = model.find_child("Skeleton3D", true, false)
		assert(skeleton != null, "Source needs a skeleton")
		var signature: Array = []
		for bone in skeleton.get_bone_count():
			signature.append([skeleton.get_bone_name(bone), skeleton.get_bone_parent(bone), skeleton.get_bone_rest(bone)])
		if index == 0: skeleton_signature = signature
		assert(signature == skeleton_signature, "All source skeletons must match")
		var animator: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
		var count := 0
		for clip in animator.get_animation_list():
			var animation := animator.get_animation(clip)
			if clip == "RESET" or animation.length < 0.1: continue
			assert(not library.has_animation(clip), "Full clip names must be unique")
			animation = animation.duplicate(true)
			animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Idle_11", "Walking", "Swim_Idle"] else Animation.LOOP_NONE
			library.add_animation(clip, animation)
			count += 1
		assert(count == 1, "Each source supplies one full clip")
		if index == 10:
			base = model
			for key in animator.get_animation_library_list(): animator.remove_animation_library(key)
		else:
			model.free()
	assert(library.get_animation_list().size() == 13)
	var folder := "res://models/otter"
	DirAccess.make_dir_recursive_absolute(folder)
	assert(ResourceSaver.save(library, folder + "/animations.res", ResourceSaver.FLAG_COMPRESS) == OK)
	var scene := PackedScene.new()
	assert(scene.pack(base) == OK)
	assert(ResourceSaver.save(scene, folder + "/otter.scn", ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) == OK)
	base.free()
	print("OTTER EXTRACTION: PASS — one model and 13 animations")
	quit()
