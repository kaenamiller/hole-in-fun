class_name ArchitectureMesh
extends RefCounted

## Native procedural architecture meshes for package 09 (clubhouse, cart, bridge).
## Used at runtime fallback and by the offline export script.

const AssetFactoryClass = preload("res://scripts/asset_factory.gd")


static func build_clubhouse(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = MaterialLibrary.material("arch.plaster")
	var accent: StandardMaterial3D = MaterialLibrary.material("arch.roof")
	var wood: StandardMaterial3D = MaterialLibrary.material("arch.timber")
	var stone: StandardMaterial3D = MaterialLibrary.material("prop.stone")
	var trim: StandardMaterial3D = MaterialLibrary.material("arch.timber")

	_beveled_box(root, Vector3(13.2, 0.42, 9.7), stone, Vector3(0, 0.21, 0), 0.06)
	_beveled_box(root, Vector3(12.0, 5.0, 8.6), wall, Vector3(0, 2.82, 0), 0.05)
	_roof_with_eaves(root, 14.0, 10.0, 1.15, 5.40, accent, wood)
	_beveled_box(root, Vector3(2.8, 0.20, 1.1), wood, Vector3(0, 0.45, -5.05), 0.04)
	_beveled_box(root, Vector3(2.4, 2.2, 0.28), wood, Vector3(0, 1.56, -4.50), 0.04)
	for x in [-4.2, -2.2, 2.2, 4.2]:
		_recessed_window(root, Vector3(x, 2.60, -4.48), Vector3(1.30, 1.35, 0.10), trim)
		_mesh(root, _box(Vector3(0.10, 1.55, 0.14)), wood, Vector3(x, 2.60, -4.57))
	for x in [-2.3, 2.3]:
		_porch_post(root, Vector3(x, 0.0, -5.05), 2.9, accent, wood)
	_beveled_box(root, Vector3(5.6, 0.18, 1.8), accent, Vector3(0, 3.95, -4.95), 0.03)
	_beveled_box(root, Vector3(5.6, 0.22, 0.22), wood, Vector3(0, 3.86, -5.86), 0.03)
	_beveled_box(root, Vector3(3.0, 0.18, 0.48), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(0, 4.05, -5.88), 0.03)
	_steps(root, Vector3(0, 0.40, -5.35), 3, 2.8)
	for z in [-4.34, 4.34]:
		for x in [-5.85, -3.0, 0.0, 3.0, 5.85]:
			_mesh(root, _box(Vector3(0.18, 5.0, 0.16)), wood, Vector3(x, 2.82, z))
		for y in [0.65, 3.6, 5.15]:
			_mesh(root, _box(Vector3(12.0, 0.18, 0.18)), wood, Vector3(0, y, z))
		for x in [-4.5, 4.5]:
			_mesh(root, _box(Vector3(0.13, 1.8, 0.12)), wood, Vector3(x, 4.35, z), Vector3.ONE, Vector3(0, 0, 0.7 if x > 0 else -0.7))
	_beveled_box(root, Vector3(1.25, 4.0, 1.15), AssetFactoryClass._material(Color("#9d9781")), Vector3(3.8, 7.0, 2.0), 0.04)
	_beveled_box(root, Vector3(1.45, 0.2, 1.35), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(3.8, 9.05, 2.0), 0.03)
	_beveled_box(root, Vector3(12.8, 0.24, 3.2), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(0, 0.20, 5.0), 0.04)
	for x in [-4.0, 0.0, 4.0]:
		_mesh(root, _cylinder(0.72, 0.12, AssetFactoryClass.WOOD, 24), wood, Vector3(x, 1.04, 5.1))
		_mesh(root, _cylinder(0.07, 2.6, AssetFactoryClass.WOOD, 12), wood, Vector3(x, 1.5, 5.1))
		_mesh(root, _cone(1.35, 0.38, AssetFactoryClass.CREAM, 32), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(x, 2.82, 5.1))
		for side in [-1, 1]:
			_mesh(root, _box(Vector3(0.6, 0.1, 0.6)), wood, Vector3(x + side * 0.96, 0.7, 5.1))

	if variant >= 1:
		var wing := Node3D.new()
		wing.name = "Wing"
		root.add_child(wing)
		wing.position.x = 7.2
		_beveled_box(wing, Vector3(4.8, 3.6, 5.2), wall, Vector3(0, 2.4, 0), 0.05)
		_roof_with_eaves(wing, 6.0, 5.8, 0.85, 4.2, accent, wood)
		_recessed_window(wing, Vector3(0, 2.8, -2.65), Vector3(1.4, 1.4, 0.1), wood)
	if variant >= 2:
		_beveled_box(root, Vector3(3.2, 2.4, 4.0), wall, Vector3(-7.0, 3.8, 1.2), 0.05)
		_mesh(root, _box(Vector3(0.18, 4.8, 0.18)), AssetFactoryClass._material(AssetFactoryClass.BRASS), Vector3(-7.0, 5.2, -0.8))


static func build_bridge(root: Node3D, _variant: int) -> void:
	var timber: StandardMaterial3D = MaterialLibrary.material("arch.timber")
	var stone: StandardMaterial3D = MaterialLibrary.material("prop.stone")
	var rail: StandardMaterial3D = MaterialLibrary.material("arch.timber")

	_beveled_box(root, Vector3(4.8, 0.35, 3.0), timber, Vector3(0, 0.45, 0), 0.05)
	for x in [-2.1, 2.1]:
		_bridge_arch(root, x, stone, timber)
		_mesh(root, _box(Vector3(0.18, 0.18, 4.5)), rail, Vector3(x, 1.55, 0))
	for z in [-1.15, 1.15]:
		_mesh(root, _box(Vector3(4.4, 0.12, 0.12)), rail, Vector3(0, 1.42, z))
	for x in [-1.2, 0, 1.2]:
		_mesh(root, _box(Vector3(0.12, 0.16, 2.65)), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(x, 0.70, 0))
	_beveled_box(root, Vector3(4.6, 0.08, 0.14), stone, Vector3(0, 0.18, -1.58), 0.02)
	_beveled_box(root, Vector3(4.6, 0.08, 0.14), stone, Vector3(0, 0.18, 1.58), 0.02)


static func build_cart(root: Node3D) -> void:
	root.name = "GolfCart"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var chassis_mat: StandardMaterial3D = AssetFactoryClass._material(AssetFactoryClass.WHITE)
	var trim_mat: StandardMaterial3D = AssetFactoryClass._material(AssetFactoryClass.DEEP_GREEN)
	var wood_mat: StandardMaterial3D = MaterialLibrary.material("arch.timber")

	_beveled_box(body, Vector3(1.60, 0.22, 2.35), chassis_mat, Vector3(0, 0.58, 0), 0.06)
	_beveled_box(body, Vector3(1.44, 0.08, 2.10), wood_mat, Vector3(0, 0.72, 0.20), 0.04)
	for x in [-0.62, 0.62]:
		_mesh(body, _box(Vector3(0.07, 1.28, 0.07)), trim_mat, Vector3(x, 1.30, 0.20))
	_beveled_box(body, Vector3(1.62, 0.10, 2.08), AssetFactoryClass._material(AssetFactoryClass.CREAM), Vector3(0, 1.94, 0.20), 0.05)
	_beveled_box(body, Vector3(1.30, 0.08, 0.08), trim_mat, Vector3(0, 1.00, -0.70), 0.03)
	_mesh(body, _cylinder(0.18, 0.04, AssetFactoryClass.BRASS, 12), AssetFactoryClass._material(AssetFactoryClass.BRASS), Vector3(0.42, 1.13, -0.80), Vector3.ONE, Vector3(PI / 2.0, 0, 0))

	var wheels := Node3D.new()
	wheels.name = "Wheels"
	root.add_child(wheels)
	var wheel_mat: StandardMaterial3D = AssetFactoryClass._material(AssetFactoryClass.WOOD_DARK)
	var wheel_specs: Array = [
		{"name": "WheelFL", "pos": Vector3(-0.72, 0.34, -0.72)},
		{"name": "WheelFR", "pos": Vector3(0.72, 0.34, -0.72)},
		{"name": "WheelRL", "pos": Vector3(-0.72, 0.34, 0.72)},
		{"name": "WheelRR", "pos": Vector3(0.72, 0.34, 0.72)},
	]
	for spec in wheel_specs:
		var pivot := Node3D.new()
		pivot.name = str(spec.name)
		pivot.position = spec.pos
		wheels.add_child(pivot)
		_mesh(pivot, _cylinder(0.30, 0.16, AssetFactoryClass.WOOD_DARK, 14), wheel_mat, Vector3.ZERO, Vector3.ONE, Vector3(0, 0, PI / 2.0))


static func bake_static(root: Node3D, lod_distance: float = 80.0) -> ArrayMesh:
	var groups: Dictionary = {}
	_gather_static(root, Transform3D.IDENTITY, groups)
	for child in root.get_children():
		child.free()
	var primary: ArrayMesh = null
	for group in groups.values():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(group.verts)
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(group.normals)
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(group.uvs)
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(group.colors)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var draw_material: Material = group.material
		if group.material is StandardMaterial3D:
			draw_material = (group.material as StandardMaterial3D).duplicate()
			(draw_material as StandardMaterial3D).vertex_color_use_as_albedo = true
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = draw_material
		root.add_child(instance)
		if primary == null:
			primary = mesh
	return primary


static func mesh_with_lods(mesh: ArrayMesh, lod_distance: float = 80.0) -> ArrayMesh:
	if mesh == null:
		return mesh
	var surface_tool := SurfaceTool.new()
	surface_tool.create_from(mesh, 0)
	surface_tool.index()
	var importer := ImporterMesh.new()
	importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, surface_tool.commit_to_arrays())
	importer.generate_lods(lod_distance, 25.0, [])
	return importer.get_mesh()


static func apply_mesh_lods(root: Node3D, lod_distance: float = 80.0) -> int:
	var count: int = 0
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh is ArrayMesh:
			child.mesh = mesh_with_lods(child.mesh as ArrayMesh, lod_distance)
			count += 1
	return count


static func _beveled_box(parent: Node3D, size: Vector3, material: Material, position_value: Vector3, bevel: float) -> void:
	var inset: float = minf(bevel, minf(size.x, minf(size.y, size.z)) * 0.45)
	var inner: Vector3 = size - Vector3.ONE * inset * 2.0
	inner = Vector3(maxf(inner.x, 0.02), maxf(inner.y, 0.02), maxf(inner.z, 0.02))
	_mesh(parent, _box(inner), material, position_value)
	var edge := inset * 0.85
	for offset in [
		Vector3(size.x * 0.5 - edge, 0, size.z * 0.5 - edge),
		Vector3(-size.x * 0.5 + edge, 0, size.z * 0.5 - edge),
		Vector3(size.x * 0.5 - edge, 0, -size.z * 0.5 + edge),
		Vector3(-size.x * 0.5 + edge, 0, -size.z * 0.5 + edge),
	]:
		_mesh(parent, _box(Vector3(edge * 2.2, size.y, edge * 2.2)), material, position_value + offset)


static func _recessed_window(parent: Node3D, position_value: Vector3, size: Vector3, frame_mat: StandardMaterial3D) -> void:
	var recess_depth: float = 0.14
	_mesh(parent, _box(size + Vector3(0.20, 0.20, 0.03)), frame_mat, position_value + Vector3(0, 0, 0.025))
	_mesh(parent, _box(size - Vector3(0.08, 0.08, 0.0)), AssetFactoryClass._material(Color("#bdc9ab"), 0.22), position_value - Vector3(0, 0, recess_depth))
	_mesh(parent, _box(Vector3(size.x - 0.12, size.y - 0.12, recess_depth * 0.55)), AssetFactoryClass._material(Color("#2a241f")), position_value - Vector3(0, 0, recess_depth * 0.72))
	for x in [-0.5, 0.0, 0.5]:
		_mesh(parent, _box(Vector3(0.055, size.y + 0.08, 0.09)), frame_mat, position_value + Vector3(x * size.x, 0, -0.08))
	_mesh(parent, _box(Vector3(size.x + 0.1, 0.07, 0.09)), frame_mat, position_value + Vector3(0, 0, -0.08))
	_mesh(parent, _box(Vector3(size.x + 0.32, 0.12, 0.30)), AssetFactoryClass._material(AssetFactoryClass.CREAM), position_value + Vector3(0, -size.y * 0.5, -0.08))


static func _porch_post(parent: Node3D, base: Vector3, height: float, cap_mat: StandardMaterial3D, post_mat: StandardMaterial3D) -> void:
	_mesh(parent, _box(Vector3(0.22, height, 0.22)), cap_mat, base + Vector3(0, height * 0.5, 0))
	_mesh(parent, _cylinder(0.09, height + 0.12, AssetFactoryClass.WOOD_DARK, 10), post_mat, base + Vector3(0, height * 0.5, 0))


static func _roof_with_eaves(parent: Node3D, width: float, depth: float, thickness: float, y: float, material: StandardMaterial3D, fascia_mat: StandardMaterial3D) -> void:
	var angle: float = 0.55
	var rise: float = width * 0.5 * tan(angle)
	var pitch_length: float = width * 0.5 / cos(angle)
	var slab: float = thickness * 0.35
	for side in [-1, 1]:
		_mesh(parent, _box(Vector3(pitch_length, slab, depth + 0.82)), material, Vector3(side * width * 0.25, y + rise * 0.5, 0), Vector3.ONE, Vector3(0, 0, -side * angle))
		_mesh(parent, _box(Vector3(pitch_length + 0.28, 0.12, depth + 0.92)), fascia_mat, Vector3(side * width * 0.25, y + rise * 0.5 - slab * 0.35, 0), Vector3.ONE, Vector3(0, 0, -side * angle))
	_mesh(parent, _box(Vector3(0.30, slab, depth + 0.85)), AssetFactoryClass._material(AssetFactoryClass.TERRACOTTA_DARK), Vector3(0, y + rise, 0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-width * 0.45, y, -depth * 0.46), Vector3(width * 0.45, y, -depth * 0.46), Vector3(0, y + rise, -depth * 0.46),
		Vector3(width * 0.45, y, depth * 0.46), Vector3(-width * 0.45, y, depth * 0.46), Vector3(0, y + rise, depth * 0.46),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var gable := ArrayMesh.new()
	gable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh(parent, gable, AssetFactoryClass._material(AssetFactoryClass.CREAM))


static func _bridge_arch(parent: Node3D, x: float, stone: StandardMaterial3D, timber: StandardMaterial3D) -> void:
	for z in [-1.15, 1.15]:
		_mesh(parent, _box(Vector3(0.18, 1.15, 0.18)), timber, Vector3(x, 1.10, z))
	_mesh(parent, _cylinder(0.62, 0.22, AssetFactoryClass.WOOD_DARK, 14), stone, Vector3(x, 0.62, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(parent, _box(Vector3(0.14, 0.72, 2.2)), timber, Vector3(x, 0.92, 0))


static func _steps(parent: Node3D, center: Vector3, count: int, width: float) -> void:
	for i in range(count):
		_mesh(parent, _box(Vector3(width - float(i) * 0.25, 0.18, 0.48)), AssetFactoryClass._material(AssetFactoryClass.CREAM), center + Vector3(0, float(i) * 0.18, float(i) * 0.42))


static func _gather_static(node: Node3D, parent: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D:
			continue
		var transform: Transform3D = parent * child.transform
		if child is MeshInstance3D and child.mesh != null:
			var mat: Material = child.material_override
			var key: int = mat.get_instance_id()
			if not groups.has(key):
				groups[key] = {"material": mat, "verts": [], "normals": [], "uvs": [], "colors": []}
			var group: Dictionary = groups[key]
			for surface in range(child.mesh.get_surface_count()):
				var a: Array = child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var normal_basis: Basis = transform.basis.inverse().transposed()
				for n in range(indices.size() if not indices.is_empty() else vertices.size()):
					var i: int = indices[n] if not indices.is_empty() else n
					group.verts.append(transform * vertices[i])
					group.normals.append((normal_basis * a[Mesh.ARRAY_NORMAL][i]).normalized() if a[Mesh.ARRAY_NORMAL] != null else Vector3.UP)
					group.uvs.append(a[Mesh.ARRAY_TEX_UV][i] if a[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO)
					var local_normal: Vector3 = (normal_basis * a[Mesh.ARRAY_NORMAL][i]).normalized() if a[Mesh.ARRAY_NORMAL] != null else Vector3.UP
					var local_pos: Vector3 = transform * vertices[i]
					if mat is StandardMaterial3D:
						var occlusion: float = AssetFactoryClass._vertex_self_occlusion(local_normal, local_pos)
						var albedo: Color = (mat as StandardMaterial3D).albedo_color
						group.colors.append(Color(albedo.r * occlusion, albedo.g * occlusion, albedo.b * occlusion, 1.0))
					else:
						group.colors.append(Color.WHITE)
		_gather_static(child, transform, groups)


static func _mesh(parent: Node3D, mesh: Mesh, material: Material, position_value: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return AssetFactoryClass._mesh(parent, mesh, material, position_value, scale_value, rotation_value)


static func _box(size: Vector3) -> BoxMesh:
	return AssetFactoryClass._box(size)


static func _cylinder(radius: float, height: float, _color: Color, segments: int = 12) -> CylinderMesh:
	return AssetFactoryClass._cylinder(radius, height, _color, segments)


static func _cone(radius: float, height: float, _color: Color, segments: int = 12) -> CylinderMesh:
	return AssetFactoryClass._cone(radius, height, _color, segments)
