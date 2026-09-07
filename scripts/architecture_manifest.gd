class_name ArchitectureManifest
extends RefCounted

## Stable architecture asset contracts for package 09 (catalogue IDs, tiers, pivots, dynamic nodes).

const GENERATOR_VERSION := "1.0.0"
const GENERATOR_SEED := 0x092026
const ASSET_ROOT := "res://assets/architecture"
const MANIFEST_PATH := "res://assets/architecture/manifest.json"

const PIVOT := "center_origin_feet_y0"

static var _manifest: Dictionary = {}
static var _loaded: bool = false


static func contracts() -> Dictionary:
	return {
		"clubhouse": {
			"catalog_id": "clubhouse",
			"kind_aliases": ["clubhouse"],
			"tiers": 3,
			"footprint": {"x": 12.0, "y": 5.35, "z": 8.6},
			"catalog_radius": 9.0,
			"pivot": PIVOT,
			"rotation_y_default": 0.0,
			"dynamic_nodes": [],
			"static_bake": true,
			"material_families": ["arch.plaster", "arch.timber", "arch.roof", "prop.stone"],
		},
		"cart": {
			"catalog_id": "cart",
			"kind_aliases": ["cart", "golf_cart"],
			"tiers": 1,
			"footprint": {"x": 1.62, "y": 1.94, "z": 2.35},
			"catalog_radius": 1.4,
			"pivot": PIVOT,
			"rotation_y_default": 0.0,
			"dynamic_nodes": ["Wheels/WheelFL", "Wheels/WheelFR", "Wheels/WheelRL", "Wheels/WheelRR"],
			"static_bake": false,
			"material_families": ["arch.timber"],
		},
		"bridge": {
			"catalog_id": "bridge",
			"kind_aliases": ["bridge", "bridge_walk", "bridge_cart"],
			"tiers": 1,
			"footprint": {"x": 4.8, "y": 1.55, "z": 3.0},
			"catalog_radius": 3.2,
			"pivot": PIVOT,
			"rotation_y_default": 0.0,
			"dynamic_nodes": [],
			"static_bake": true,
			"material_families": ["arch.timber", "prop.stone"],
		},
	}


static func shipped_kinds() -> PackedStringArray:
	return PackedStringArray(["clubhouse", "cart", "bridge"])


static func resolve_asset_key(kind: String) -> String:
	for key in shipped_kinds():
		var aliases: Array = contracts()[key].get("kind_aliases", [])
		if kind in aliases or key == kind:
			return key
	return ""


static func has_shipped_asset(kind: String) -> bool:
	return not resolve_asset_key(kind).is_empty()


static func scene_path(kind: String, variant: int = 0) -> String:
	var asset_key: String = resolve_asset_key(kind)
	if asset_key.is_empty():
		return ""
	var contract: Dictionary = contracts()[asset_key]
	var tiers: int = int(contract.get("tiers", 1))
	var clamped: int = clampi(variant, 0, maxi(0, tiers - 1))
	return "%s/%s/v%d.tscn" % [ASSET_ROOT, asset_key, clamped]


static func lod_path(kind: String, variant: int, lod_index: int) -> String:
	return "%s/%s/v%d_lod%d.res" % [ASSET_ROOT, resolve_asset_key(kind), variant, lod_index]


static func manifest() -> Dictionary:
	_ensure_loaded()
	return _manifest.duplicate(true)


static func write_manifest(entries: Dictionary) -> Dictionary:
	var payload := {
		"generator_version": GENERATOR_VERSION,
		"seed": GENERATOR_SEED,
		"tool": "godot-native",
		"pivot": PIVOT,
		"assets": entries,
	}
	var dir := DirAccess.open("res://assets")
	if dir != null and not dir.dir_exists("architecture"):
		dir.make_dir("architecture")
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))
	_manifest = payload
	_loaded = true
	return payload


static func _ensure_loaded() -> void:
	if _loaded:
		return
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			_manifest = parsed
	_loaded = true
