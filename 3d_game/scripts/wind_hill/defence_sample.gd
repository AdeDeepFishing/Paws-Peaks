extends RefCounted

## Deliberately authored offline stand-ins; live mode always uses the returned GLB.
static func create(shield: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "SampleShield" if shield else "SampleUmbrella"
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("bddbc9")
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("806347")
	if shield:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.25
		disc.bottom_radius = 1.25
		disc.height = 0.15
		var face := MeshInstance3D.new()
		face.mesh = disc
		face.material_override = cloth
		face.position.y = 0.25
		root.add_child(face)
	else:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 16:
			var a := TAU * i / 16.0
			var b := TAU * (i + 1) / 16.0
			surface.add_vertex(Vector3(0, 1.6, 0))
			surface.add_vertex(Vector3(cos(a) * 1.45, 1.0, sin(a) * 1.45))
			surface.add_vertex(Vector3(cos(b) * 1.45, 1.0, sin(b) * 1.45))
		surface.generate_normals()
		var canopy := MeshInstance3D.new()
		canopy.mesh = surface.commit()
		canopy.material_override = cloth
		root.add_child(canopy)
		var handle := MeshInstance3D.new()
		var pole := CylinderMesh.new()
		pole.top_radius = 0.045
		pole.bottom_radius = 0.045
		pole.height = 1.6
		handle.mesh = pole
		handle.position.y = 0.8
		handle.material_override = wood
		root.add_child(handle)
	return root
