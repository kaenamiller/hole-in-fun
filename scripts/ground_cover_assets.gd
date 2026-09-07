class_name GroundCoverAssets
extends RefCounted

## Shipped ground-cover meshes (package 08). GLTF assets are generated offline.

const MANIFEST_PATH := "res://assets/ground_cover/manifest.json"

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
	return ResourceLoader.exists(mesh_path("rough_tuft", 0, "near"))


static func lod_thresholds() -> Dictionary:
	return manifest().get("lod_thresholds", {
		"near_end": 95.0,
		"far_begin": 82.0,
		"far_end": 420.0,
	})


static func mesh_path(family: String, variant: int, lod: String) -> String:
	return "res://assets/ground_cover/%s_v%d_%s.gltf" % [family, variant % variant_count(family), lod]


static func variant_count(family: String) -> int:
	for row in manifest().get("variants", []):
		if str(row.get("family", "")) == family:
			var count: int = 0
			for other in manifest().get("variants", []):
				if str(other.get("family", "")) == family:
					count += 1
			return maxi(count, 1)
	return 1


static func load_mesh(family: String, variant: int, lod: String) -> ArrayMesh:
	var key: String = "%s:%d:%s" % [family, variant % variant_count(family), lod]
	if _mesh_cache.has(key):
		return _mesh_cache[key] as ArrayMesh
	var path: String = mesh_path(family, variant, lod)
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	var mesh: ArrayMesh = null
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			mesh = (child.mesh as ArrayMesh).duplicate()
			break
	root.free()
	if mesh != null:
		_mesh_cache[key] = mesh
	return mesh


static func material_for(family: String) -> Material:
	if family in ["rough_tuft", "bank_reed", "shrub", "flower"]:
		return AssetFactory._foliage()
	if family == "leaf_litter":
		return MaterialLibrary.material("course.rough")
	return MaterialLibrary.material("prop.stone")


static func casts_shadow(family: String) -> int:
	if family in ["shrub", "small_stone"]:
		return GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func clear_cache() -> void:
	_mesh_cache.clear()
