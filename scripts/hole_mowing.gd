class_name HoleMowing
extends RefCounted

## Cosmetic per-hole mowing patterns (graphics package 05).
## Fairway ownership and stripe orientation are visual-only; they do not affect
## surface classification, shots, or routing.

const MAP_SIZE: int = 256
const DEFAULT_DIR: Vector2 = Vector2(0.78, 0.63)
const DEFAULT_FREQ: float = 0.56
const GREEN_ORIENTATION_OFFSET: float = deg_to_rad(12.0)
const PATTERN_TYPES: Array[String] = ["straight"]
const SCHEMA_VERSION: int = 1

static func defaults_from_routing(hole: Dictionary) -> Dictionary:
	var tee: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
	var cup: Vector3 = TerrainModel.effective_cup(hole)
	var play: Vector2 = Vector2(cup.x - tee.x, cup.z - tee.z)
	if play.length_squared() < 1.0:
		play = Vector2(0.0, 1.0)
	play = play.normalized()
	var dir: Vector2 = Vector2(-play.y, play.x)
	return {
		"orientation": atan2(dir.y, dir.x),
		"width": DEFAULT_FREQ,
		"phase": 0.0,
		"contrast": 1.0,
		"pattern_type": "straight",
	}

static func effective_pattern(hole: Dictionary) -> Dictionary:
	var result: Dictionary = defaults_from_routing(hole)
	var overrides: Variant = hole.get("mowing", {})
	if overrides is Dictionary:
		for key in ["orientation", "width", "phase", "contrast", "pattern_type", "fairway_cells"]:
			if (overrides as Dictionary).has(key):
				result[key] = (overrides as Dictionary)[key]
	if not str(result.get("pattern_type", "straight")) in PATTERN_TYPES:
		result["pattern_type"] = "straight"
	return result

static func sanitize_saved_mowing(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var result: Dictionary = {}
	var mowing: Dictionary = raw
	if mowing.has("orientation"):
		result["orientation"] = float(mowing["orientation"])
	if mowing.has("width"):
		result["width"] = clampf(float(mowing["width"]), 0.2, 2.0)
	if mowing.has("phase"):
		result["phase"] = float(mowing["phase"])
	if mowing.has("contrast"):
		result["contrast"] = clampf(float(mowing["contrast"]), 0.0, 1.0)
	if mowing.has("pattern_type") and str(mowing["pattern_type"]) in PATTERN_TYPES:
		result["pattern_type"] = str(mowing["pattern_type"])
	if mowing.has("fairway_cells"):
		var cells: Array = []
		for item in mowing["fairway_cells"]:
			cells.append(int(item))
		result["fairway_cells"] = cells
	return result

static func stripe_coord(world_xz: Vector2, dir: Vector2, freq: float, phase: float) -> float:
	return world_xz.dot(dir.normalized()) * freq + phase

static func stripe_sample(world_xz: Vector2, dir: Vector2, freq: float, phase: float) -> float:
	var coord: float = stripe_coord(world_xz, dir, freq, phase)
	var aa: float = 0.001
	return smoothstep(-0.13 - aa, 0.13 + aa, sin(coord))

static func build_pattern_image(terrain: TerrainModel) -> Image:
	terrain.rebuild_mowing_maps()
	var data: PackedByteArray = PackedByteArray()
	data.resize(MAP_SIZE * MAP_SIZE * 4)
	for index in range(MAP_SIZE * MAP_SIZE):
		_write_cell_bytes(data, index, _cell_pattern(terrain, index))
	return Image.create_from_data(MAP_SIZE, MAP_SIZE, false, Image.FORMAT_RGBA8, data)

static func write_cell_pattern(terrain: TerrainModel, image: Image, index: int) -> void:
	terrain.rebuild_mowing_maps()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	_write_cell_bytes(bytes, 0, _cell_pattern(terrain, index))
	var x: int = index % MAP_SIZE
	var z: int = int(index / MAP_SIZE)
	image.set_pixel(x, z, Color(bytes[0] / 255.0, bytes[1] / 255.0, bytes[2] / 255.0, bytes[3] / 255.0))

static func overview_fade(camera_size: float) -> float:
	return clampf(1.0 - smoothstep(280.0, 900.0, camera_size), 0.12, 1.0)

static func _cell_pattern(terrain: TerrainModel, index: int) -> Dictionary:
	var surface: int = int(terrain.surfaces[index])
	if surface not in [1, 2, 3]:
		return _neutral_pattern()
	var hole_id: int = -1
	if surface == 2:
		hole_id = terrain.green_owner(_cell_center(index))
	else:
		hole_id = terrain.fairway_owner(_cell_center(index))
	if hole_id < 0:
		return _neutral_pattern()
	var hole: Dictionary = terrain.hole_by_id(hole_id)
	if hole.is_empty():
		return _neutral_pattern()
	var pattern: Dictionary = effective_pattern(hole)
	var dir: Vector2 = Vector2(cos(float(pattern["orientation"])), sin(float(pattern["orientation"])))
	if surface == 2:
		dir = dir.rotated(GREEN_ORIENTATION_OFFSET)
	var contrast: float = float(pattern["contrast"]) * _surface_contrast(surface)
	return {
		"dir": dir.normalized(),
		"freq": float(pattern["width"]),
		"phase": float(pattern["phase"]),
		"contrast": contrast,
	}

static func _neutral_pattern() -> Dictionary:
	return {
		"dir": DEFAULT_DIR.normalized(),
		"freq": DEFAULT_FREQ,
		"phase": 0.0,
		"contrast": 0.35,
	}

static func _surface_contrast(surface: int) -> float:
	match surface:
		1: return 1.0
		2: return 1.08
		3: return 0.92
	return 0.0

static func _cell_center(index: int) -> Vector3:
	var x: int = index % MAP_SIZE
	var z: int = int(index / MAP_SIZE)
	return Vector3((x + 0.5) * TerrainModel.STEP, 0.0, (z + 0.5) * TerrainModel.STEP)

static func _write_cell_bytes(data: PackedByteArray, byte_index: int, pattern: Dictionary) -> void:
	var dir: Vector2 = pattern["dir"]
	var offset: int = byte_index * 4
	data[offset] = int(clampf(dir.x * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	data[offset + 1] = int(clampf(dir.y * 0.5 + 0.5, 0.0, 1.0) * 255.0)
	data[offset + 2] = int(clampf(float(pattern["freq"]) / 1.5, 0.0, 1.0) * 255.0)
	data[offset + 3] = int(clampf(float(pattern["contrast"]), 0.0, 1.0) * 255.0)
