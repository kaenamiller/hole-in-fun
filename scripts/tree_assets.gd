class_name TreeAssets
extends RefCounted

## Shipped second-generation tree meshes (package 07). GLTF assets are generated offline.

const MANIFEST_PATH := "res://assets/trees/manifest.json"

static var _manifest: Dictionary = {}
static var _mesh_cache: Dictionary = {}


static func manifest() -> Dictionary:
	if not _manifest.is_empty():
		return _manifest
	if not FileAccess.file_exists(MANIFEST_PATH):
		return {}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_manifest = parsed
	return _manifest


static func available() -> bool:
	return ResourceLoader.exists(mesh_path("oak", 0, "near"))


static func lod_thresholds() -> Dictionary:
	return manifest().get("lod_thresholds", {
		"near_end": 85.0,
		"mid_begin": 75.0,
		"mid_end": 190.0,
		"far_begin": 175.0,
		"far_end": 950.0,
	})


static func variant_scale(species: String, variant: int) -> float:
	for row in manifest().get("variants", []):
		if str(row.get("species", "")) == species and int(row.get("variant", -1)) == variant % 4:
			return float(row.get("scale", 1.0))
	if species == "pine":
		return 2.6 + (variant % 4) * 0.13
	return 2.8 + (variant % 4) * 0.16


static func mesh_path(species: String, variant: int, lod: String) -> String:
	return "res://assets/trees/%s_v%d_%s.gltf" % [species, variant % 4, lod]


static func load_part(species: String, variant: int, lod: String, part: String) -> ArrayMesh:
	var key: String = "%s:%d:%s:%s" % [species, variant % 4, lod, part]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var path: String = mesh_path(species, variant, lod)
	if not ResourceLoader.exists(path):
		return null
	var meshes: Dictionary = _extract_meshes(path)
	var mesh: ArrayMesh = meshes.get(part) as ArrayMesh
	if mesh != null:
		_mesh_cache[key] = mesh
	return mesh


static func shadow_mesh(pine: bool, variant: int) -> ArrayMesh:
	var species: String = "pine" if pine else "oak"
	var key: String = "shadow:%s:%d" % [species, variant % 4]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var path: String = mesh_path(species, variant, "shadow")
	if not ResourceLoader.exists(path):
		return null
	var meshes: Dictionary = _extract_meshes(path)
	var mesh: ArrayMesh = meshes.get("bark") as ArrayMesh
	if mesh == null and meshes.size() > 0:
		mesh = meshes.values()[0] as ArrayMesh
	if mesh != null:
		_mesh_cache[key] = mesh
	return mesh


static func clear_cache() -> void:
	_mesh_cache.clear()


static func _extract_meshes(path: String) -> Dictionary:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return {}
	var root: Node = scene.instantiate()
	var out: Dictionary = {}
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			out[str(child.name).to_lower()] = (child.mesh as ArrayMesh).duplicate()
	root.free()
	return out
