extends SceneTree

## Offline architecture exporter (package 09). Native Godot mesh generation — no Blender.

const OUTPUT_ROOT := "res://assets/architecture"


func _init() -> void:
	var manifest_entries: Dictionary = {}
	for asset_key in ArchitectureManifest.shipped_kinds():
		var contract: Dictionary = ArchitectureManifest.contracts()[asset_key]
		var tiers: int = int(contract.get("tiers", 1))
		var variant_entries: Array = []
		for variant in range(tiers):
			var root := _build_asset(asset_key, variant)
			var bounds: AABB = _bounds(root)
			var out_dir: String = "%s/%s" % [OUTPUT_ROOT, asset_key]
			_ensure_dir(out_dir)
			var scene_path: String = "%s/v%d.tscn" % [out_dir, variant]
			var lod_count: int = 0
			if bool(contract.get("static_bake", true)):
				lod_count = ArchitectureMesh.apply_mesh_lods(root, AssetFactory.architecture_lod_distance)
			_set_owner_recursive(root, root)
			var packed := PackedScene.new()
			packed.pack(root)
			var err: Error = ResourceSaver.save(packed, scene_path)
			assert(err == OK, "Failed to save %s err=%d" % [scene_path, err])
			variant_entries.append({
				"variant": variant,
				"scene": scene_path,
				"lod_count": lod_count,
				"bounds": {
					"position": [bounds.position.x, bounds.position.y, bounds.position.z],
					"size": [bounds.size.x, bounds.size.y, bounds.size.z],
				},
			})
			root.free()
		manifest_entries[asset_key] = contract.duplicate(true)
		manifest_entries[asset_key]["variants"] = variant_entries
	ArchitectureManifest.write_manifest(manifest_entries)
	print("generate_architecture: exported %d assets to %s" % [ArchitectureManifest.shipped_kinds().size(), OUTPUT_ROOT])
	quit()


func _build_asset(asset_key: String, variant: int) -> Node3D:
	var root := Node3D.new()
	root.name = asset_key
	match asset_key:
		"clubhouse":
			ArchitectureMesh.build_clubhouse(root, variant)
			ArchitectureMesh.bake_static(root, AssetFactory.architecture_lod_distance)
		"bridge":
			ArchitectureMesh.build_bridge(root, variant)
			ArchitectureMesh.bake_static(root, AssetFactory.architecture_lod_distance)
		"cart":
			ArchitectureMesh.build_cart(root)
	return root


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _bounds(node: Node) -> AABB:
	var result: AABB = AABB()
	var has_bounds: bool = false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			var child_bounds: AABB = mesh_node.transform * mesh_node.get_aabb()
			if not has_bounds:
				result = child_bounds
				has_bounds = true
			else:
				result = result.merge(child_bounds)
		var nested: AABB = _bounds(child)
		if nested.size != Vector3.ZERO:
			if not has_bounds:
				result = nested
				has_bounds = true
			else:
				result = result.merge(nested)
	return result


func _ensure_dir(path: String) -> void:
	var relative: String = path.replace("res://", "")
	var parts: PackedStringArray = relative.split("/", false)
	var current: String = "res://"
	for part in parts:
		current = "%s/%s" % [current, part]
		var dir := DirAccess.open(current.get_base_dir())
		if dir != null and not dir.dir_exists(current.get_file()):
			dir.make_dir(current.get_file())
