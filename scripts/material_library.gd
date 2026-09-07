class_name MaterialLibrary
extends RefCounted

## Shared procedural material instances keyed by stable family IDs (package 04).

const MANIFEST_PATH := "res://assets/materials/manifest.json"
const TEXTURE_ROOT := "res://assets/materials"

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}
static var _manifest: Dictionary = {}
static var _loaded: bool = false

static func family_ids() -> PackedStringArray:
	_ensure_loaded()
	var ids: PackedStringArray = []
	for key in GraphicsPalette.MATERIAL_FAMILIES.keys():
		ids.append(key)
	return ids

static func material(family_id: String, variant: String = "default") -> StandardMaterial3D:
	_ensure_loaded()
	var cache_key: String = "%s:%s" % [family_id, variant]
	if _materials.has(cache_key):
		return _materials[cache_key] as StandardMaterial3D
	var def: Dictionary = GraphicsPalette.material_family(family_id)
	var folder: String = str(def.get("folder", ""))
	var mat := StandardMaterial3D.new()
	mat.resource_name = family_id
	mat.albedo_color = GraphicsPalette.material_tint_color(family_id)
	mat.roughness = float(def.get("roughness", 0.85))
	mat.metallic = 0.0
	mat.albedo_texture = _load_map(folder, "albedo")
	mat.roughness_texture = _load_map(folder, "roughness")
	var normal_tex: Texture2D = _load_map(folder, "normal")
	if normal_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
	if bool(def.get("triplanar", false)):
		mat.uv1_triplanar = true
		var repeat: float = float(def.get("meters_per_repeat", 1.0))
		var scale: float = 1.0 / maxf(repeat, 0.05)
		mat.uv1_scale = Vector3(scale, scale, scale)
		if family_id.begins_with("arch.timber") or family_id == "prop.bark":
			mat.uv1_scale = Vector3(scale * 0.5, scale * 2.0, scale * 0.5)
	_materials[cache_key] = mat
	return mat

static func detail_textures(family_id: String) -> Dictionary:
	_ensure_loaded()
	var def: Dictionary = GraphicsPalette.material_family(family_id)
	var folder: String = str(def.get("folder", ""))
	return {
		"albedo": _load_map(folder, "albedo"),
		"roughness": _load_map(folder, "roughness"),
		"normal": _load_map(folder, "normal"),
		"meters_per_repeat": float(def.get("meters_per_repeat", 1.0)),
	}

static func apply_season(index: int) -> void:
	var season: int = GraphicsPalette.clamp_season(index)
	var target: Color = GraphicsPalette.foliage_season_target(season)
	for family_id in GraphicsPalette.season_tinted_material_ids():
		var mat: StandardMaterial3D = material(family_id)
		var base: Color = GraphicsPalette.material_tint_color(family_id)
		var mix_amount: float = GraphicsPalette.material_season_mix(family_id, season)
		var rough_before: float = mat.roughness
		var metallic_before: float = mat.metallic
		mat.albedo_color = base.lerp(target, mix_amount)
		mat.roughness = rough_before
		mat.metallic = metallic_before

static func reset_season() -> void:
	apply_season(1)

static func manifest() -> Dictionary:
	_ensure_loaded()
	return _manifest.duplicate(true)

static func shared_instance_count() -> int:
	return _materials.size()

static func clear_cache() -> void:
	_materials.clear()
	_textures.clear()
	_loaded = false
	_manifest.clear()

static func _ensure_loaded() -> void:
	if _loaded:
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_manifest = parsed
	_loaded = true

static func _load_map(folder: String, channel: String) -> Texture2D:
	var key: String = "%s/%s" % [folder, channel]
	if _textures.has(key):
		return _textures[key] as Texture2D
	var path: String = "%s/%s/%s.png" % [TEXTURE_ROOT, folder, channel]
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_textures[key] = tex
	return tex
