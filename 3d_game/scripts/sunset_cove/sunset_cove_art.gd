extends Node3D

const SOLID_NAMES := [
	"Crescent_Sand_Beach", "Right_River_Bank", "Left_River_Bank",
	"Root_Bank_Arch", "Cave_Grassy_Brow", "Hollow_Tunnel_Interior",
	"Shelter_Sandy_Floor", "Cave_Grassy_Hill_Roof",
]

func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var label := str(node.name)
		# Underlay and distant landscape are visual scenery, not walkable water.
		if label in SOLID_NAMES or label.begins_with("Painted_River_Stone") or label.begins_with("Painted_Trunk") or label.begins_with("Pine_Trunk"):
			node.create_trimesh_collision()
			for collider in node.find_children("*", "CollisionShape3D", true, false):
				if collider.shape is ConcavePolygonShape3D:
					collider.shape.backface_collision = true
	for animator in find_children("*", "AnimationPlayer", true, false):
		for clip in animator.get_animation_list():
			# Godot consumes the source's _Loop suffix as an import hint.
			if "Handpainted_Breeze_And_Water" in clip:
				animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				animator.play(clip)
