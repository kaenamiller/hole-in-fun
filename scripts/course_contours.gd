class_name CourseContours
extends RefCounted

## Continuous course feature outlines (graphics package 06).
## Raster `surfaces` / `height_at` remain authoritative for gameplay; optional
## vector features rasterize on commit so lies and masks agree within tolerance.

const SCHEMA_VERSION: int = 1
const GAMEPLAY_RES: int = 256
const RENDER_RES: int = 512
const STEP: float = TerrainModel.STEP
const SAMPLE_TOLERANCE_M: float = STEP * 0.5
const KINDS: Array[String] = ["green", "bunker"]
const SURFACE_BY_KIND: Dictionary = {"green": 2, "bunker": 4}
const DEFAULT_COLLAR_WIDTH: float = 1.6
const DEFAULT_LIP_WIDTH: float = 1.4
const DEFAULT_LIP_DEPTH: float = 0.55

static func sanitize_feature(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	var feature: Dictionary = raw
	var kind: String = str(feature.get("kind", ""))
	if kind not in KINDS:
		return {}
	var result: Dictionary = {
		"id": int(feature.get("id", -1)),
		"kind": kind,
		"hole_id": int(feature.get("hole_id", -1)),
		"points": _sanitize_points(feature.get("points", [])),
		"islands": _sanitize_islands(feature.get("islands", [])),
		"collar_width": clampf(float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH)), 0.4, 4.0),
		"lip_width": clampf(float(feature.get("lip_width", DEFAULT_LIP_WIDTH)), 0.4, 4.0),
		"lip_depth": clampf(float(feature.get("lip_depth", DEFAULT_LIP_DEPTH)), 0.1, 1.2),
	}
	if result["points"].size() < 3:
		return {}
	if result["id"] < 0:
		return {}
	return result

static func sanitize_saved_features(raw: Variant) -> Array:
	if not raw is Array:
		return []
	var result: Array = []
	for item in raw:
		var feature: Dictionary = sanitize_feature(item)
		if not feature.is_empty():
			result.append(feature)
	return result

static func surface_for_kind(kind: String) -> int:
	return int(SURFACE_BY_KIND.get(kind, -1))

static func contains_point(feature: Dictionary, world_xz: Vector2) -> bool:
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.size() < 3:
		return false
	if not _point_in_polygon(world_xz, polygon):
		return false
	for island_value in feature.get("islands", []):
		var island: PackedVector2Array = island_value
		if island.size() >= 3 and _point_in_polygon(world_xz, island):
			return false
	return true

static func render_weight(feature: Dictionary, world_xz: Vector2) -> float:
	if feature.is_empty():
		return 0.0
	if contains_point(feature, world_xz):
		return 1.0
	var boundary: float = boundary_distance(world_xz, feature)
	var band: float = _edge_band(feature)
	if boundary <= band:
		return smoothstep(band, 0.0, boundary)
	return 0.0

static func boundary_distance(world_xz: Vector2, feature: Dictionary) -> float:
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.size() < 2:
		return 1.0e9
	var best: float = _distance_to_ring(world_xz, polygon)
	for island_value in feature.get("islands", []):
		var island: PackedVector2Array = island_value
		if island.size() >= 2:
			best = minf(best, _distance_to_ring(world_xz, island))
	return best

static func signed_boundary_distance(world_xz: Vector2, feature: Dictionary) -> float:
	var distance: float = boundary_distance(world_xz, feature)
	if contains_point(feature, world_xz):
		return -distance
	return distance

static func gameplay_surface_matches(feature: Dictionary, terrain: TerrainModel, world_pos: Vector3) -> bool:
	var expected: int = surface_for_kind(str(feature.get("kind", "")))
	if expected < 0:
		return true
	var raster: int = int(terrain.surface_at(world_pos))
	var weight: float = render_weight(feature, Vector2(world_pos.x, world_pos.z))
	if weight >= 0.5:
		return raster == expected
	if weight <= 0.01:
		return raster != expected or boundary_distance(Vector2(world_pos.x, world_pos.z), feature) <= SAMPLE_TOLERANCE_M
	return true

static func feature_bounds(feature: Dictionary) -> Rect2:
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.is_empty():
		return Rect2()
	var min_x: float = polygon[0].x
	var max_x: float = polygon[0].x
	var min_z: float = polygon[0].y
	var max_z: float = polygon[0].y
	for index in range(1, polygon.size()):
		min_x = minf(min_x, polygon[index].x)
		max_x = maxf(max_x, polygon[index].x)
		min_z = minf(min_z, polygon[index].y)
		max_z = maxf(max_z, polygon[index].y)
	var pad: float = maxf(float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH)), float(feature.get("lip_width", DEFAULT_LIP_WIDTH))) + STEP
	return Rect2(min_x - pad, min_z - pad, max_x - min_x + pad * 2.0, max_z - min_z + pad * 2.0)

static func intersects_rect(feature: Dictionary, rect: Rect2) -> bool:
	return feature_bounds(feature).intersects(rect)

static func self_intersects(polygon: PackedVector2Array) -> bool:
	var count: int = polygon.size()
	if count < 4:
		return false
	for a in range(count):
		var a0: Vector2 = polygon[a]
		var a1: Vector2 = polygon[(a + 1) % count]
		for b in range(a + 1, count):
			if b == a or (a == 0 and b == count - 1) or (b == (a + 1) % count) or (a == (b + 1) % count):
				continue
			var b0: Vector2 = polygon[b]
			var b1: Vector2 = polygon[(b + 1) % count]
			if _segments_intersect(a0, a1, b0, b1):
				return true
	return false

static func validate_feature(feature: Dictionary) -> String:
	if feature.is_empty():
		return "Feature is empty"
	if self_intersects(feature.get("points", PackedVector2Array())):
		return "Outline self-intersects"
	for island_value in feature.get("islands", []):
		var island: PackedVector2Array = island_value
		if island.size() >= 4 and self_intersects(island):
			return "Island outline self-intersects"
	return ""

static func plan_raster(feature: Dictionary, terrain: TerrainModel) -> Dictionary:
	var cells: Array = []
	var cost: float = 0.0
	var paint_costs: Array = [3, 9, 14, 12, 8, 18, 4]
	var surface: int = surface_for_kind(str(feature.get("kind", "")))
	if surface < 0:
		return {"cells": cells, "cost": 0.0, "bounds": feature_bounds(feature)}
	var indices: PackedInt32Array = rasterize_feature(feature)
	for index in indices:
		if int(terrain.surfaces[index]) == surface:
			continue
		cells.append([index, int(terrain.surfaces[index]), surface, terrain.water_levels[index], -100.0])
		cost += float(paint_costs[surface])
	return {"cells": cells, "cost": ceilf(cost), "bounds": feature_bounds(feature)}

static func rasterize_feature(feature: Dictionary) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	var bounds: Rect2 = feature_bounds(feature)
	var x0: int = clampi(int(bounds.position.x / STEP), 0, GAMEPLAY_RES - 1)
	var x1: int = clampi(int((bounds.position.x + bounds.size.x) / STEP), 0, GAMEPLAY_RES - 1)
	var z0: int = clampi(int(bounds.position.y / STEP), 0, GAMEPLAY_RES - 1)
	var z1: int = clampi(int((bounds.position.y + bounds.size.y) / STEP), 0, GAMEPLAY_RES - 1)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var center: Vector2 = Vector2((x + 0.5) * STEP, (z + 0.5) * STEP)
			if contains_point(feature, center):
				result.append(z * GAMEPLAY_RES + x)
	return result

static func plan_profile(feature: Dictionary, terrain: TerrainModel) -> Dictionary:
	var nodes: Array = []
	var cost: float = 0.0
	var kind: String = str(feature.get("kind", ""))
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.size() < 3:
		return {"nodes": nodes, "cost": 0.0}
	var samples: PackedVector2Array = _resample_ring(polygon, STEP * 0.5)
	for sample in samples:
		var normal: Vector2 = _outward_normal(sample, polygon, contains_point(feature, sample))
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		if kind == "green":
			var width: float = float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH))
			for step in range(1, 3):
				var offset: float = float(step) * width / 3.0
				var point: Vector3 = Vector3(sample.x + normal.x * offset, 0.0, sample.y + normal.y * offset)
				_append_height_node(terrain, nodes, point, 0.08 * float(step))
		elif kind == "bunker":
			var width: float = float(feature.get("lip_width", DEFAULT_LIP_WIDTH))
			var depth: float = float(feature.get("lip_depth", DEFAULT_LIP_DEPTH))
			for step in range(1, 3):
				var offset: float = float(step) * width / 3.0
				var point: Vector3 = Vector3(sample.x + normal.x * offset, 0.0, sample.y + normal.y * offset)
				_append_height_node(terrain, nodes, point, -depth * 0.35 * float(step))
	for item in nodes:
		cost += absf(float(item[2]) - float(item[1])) * 8.0
	return {"nodes": nodes, "cost": ceilf(cost)}

static func build_render_mask(features: Array, terrain: TerrainModel) -> Image:
	var data: PackedByteArray = PackedByteArray()
	data.resize(RENDER_RES * RENDER_RES * 4)
	for z in range(RENDER_RES):
		for x in range(RENDER_RES):
			var world: Vector2 = Vector2((float(x) + 0.5) / float(RENDER_RES) * TerrainModel.WIDTH, (float(z) + 0.5) / float(RENDER_RES) * TerrainModel.WIDTH)
			var green_w: float = 0.0
			var sand_w: float = 0.0
			var collar_w: float = 0.0
			var lip_w: float = 0.0
			for feature_value in features:
				var feature: Dictionary = feature_value
				var kind: String = str(feature.get("kind", ""))
				var weight: float = render_weight(feature, world)
				if kind == "green":
					green_w = maxf(green_w, weight)
					if not contains_point(feature, world):
						var dist: float = boundary_distance(world, feature)
						collar_w = maxf(collar_w, smoothstep(float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH)), 0.0, dist))
				elif kind == "bunker":
					sand_w = maxf(sand_w, weight)
					if not contains_point(feature, world):
						var dist: float = boundary_distance(world, feature)
						lip_w = maxf(lip_w, smoothstep(float(feature.get("lip_width", DEFAULT_LIP_WIDTH)), 0.0, dist))
			# Fall back to raster for legacy cells without authored outlines.
			if green_w < 0.01 and sand_w < 0.01:
				var raster: int = int(terrain.surfaces[clampi(int(world.y / STEP), 0, 255) * GAMEPLAY_RES + clampi(int(world.x / STEP), 0, 255)])
				if raster == 2:
					green_w = 1.0
				elif raster == 4:
					sand_w = 1.0
			var offset: int = (z * RENDER_RES + x) * 4
			data[offset] = int(clampf(green_w, 0.0, 1.0) * 255.0)
			data[offset + 1] = int(clampf(sand_w, 0.0, 1.0) * 255.0)
			data[offset + 2] = int(clampf(collar_w, 0.0, 1.0) * 255.0)
			data[offset + 3] = int(clampf(lip_w, 0.0, 1.0) * 255.0)
	return Image.create_from_data(RENDER_RES, RENDER_RES, false, Image.FORMAT_RGBA8, data)

static func boundary_polyline(feature: Dictionary, terrain: TerrainModel, lift: float = 0.12) -> PackedVector3Array:
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.size() < 3:
		return PackedVector3Array()
	var samples: PackedVector2Array = _resample_ring(polygon, STEP * 0.45)
	var points: PackedVector3Array = PackedVector3Array()
	for sample in samples:
		var point: Vector3 = Vector3(sample.x, 0.0, sample.y)
		point.y = terrain.height_at(point) + lift
		points.append(point)
	if points.size() >= 3:
		points.append(points[0])
	return points

static func collar_ribbon(feature: Dictionary, terrain: TerrainModel) -> PackedVector3Array:
	return _profile_ribbon(feature, terrain, float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH)), true)

static func lip_ribbon(feature: Dictionary, terrain: TerrainModel) -> PackedVector3Array:
	return _profile_ribbon(feature, terrain, float(feature.get("lip_width", DEFAULT_LIP_WIDTH)), false)

static func water_body_query(terrain: TerrainModel, world_pos: Vector3) -> Dictionary:
	return WaterField.sample(terrain, world_pos)

static func approximate_outline_from_cells(cells: PackedInt32Array) -> PackedVector2Array:
	if cells.is_empty():
		return PackedVector2Array()
	var owned: Dictionary = {}
	for index in cells:
		owned[int(index)] = true
	var edge: Dictionary = {}
	for index in cells:
		var x: int = int(index) % GAMEPLAY_RES
		var z: int = int(index / GAMEPLAY_RES)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + offset.x
			var nz: int = z + offset.y
			var neighbor: int = nz * GAMEPLAY_RES + nx
			if nx < 0 or nz < 0 or nx >= GAMEPLAY_RES or nz >= GAMEPLAY_RES or not owned.has(neighbor):
				var key: Vector2i = Vector2i(x * 2 + maxi(0, offset.x), z * 2 + maxi(0, offset.y))
				edge[key] = Vector2((x + 0.5 + offset.x * 0.5) * STEP, (z + 0.5 + offset.y * 0.5) * STEP)
	var points: PackedVector2Array = PackedVector2Array()
	for key in edge.keys():
		points.append(edge[key])
	return _order_boundary_points(points)

static func make_feature(id_value: int, kind: String, hole_id: int, points: PackedVector2Array) -> Dictionary:
	return {
		"id": id_value,
		"kind": kind,
		"hole_id": hole_id,
		"points": points,
		"islands": [],
		"collar_width": DEFAULT_COLLAR_WIDTH,
		"lip_width": DEFAULT_LIP_WIDTH,
		"lip_depth": DEFAULT_LIP_DEPTH,
	}

static func _edge_band(feature: Dictionary) -> float:
	var kind: String = str(feature.get("kind", ""))
	if kind == "green":
		return float(feature.get("collar_width", DEFAULT_COLLAR_WIDTH))
	if kind == "bunker":
		return float(feature.get("lip_width", DEFAULT_LIP_WIDTH))
	return STEP

static func _profile_ribbon(feature: Dictionary, terrain: TerrainModel, width: float, inward: bool) -> PackedVector3Array:
	var polygon: PackedVector2Array = feature.get("points", PackedVector2Array())
	if polygon.size() < 3:
		return PackedVector3Array()
	var samples: PackedVector2Array = _resample_ring(polygon, STEP * 0.45)
	var inner: PackedVector3Array = PackedVector3Array()
	var outer: PackedVector3Array = PackedVector3Array()
	for sample in samples:
		var inside: bool = contains_point(feature, sample)
		var normal: Vector2 = _outward_normal(sample, polygon, inside)
		if normal.length_squared() < 0.0001:
			continue
		normal = normal.normalized()
		if inward:
			normal *= -1.0
		var base: Vector3 = Vector3(sample.x, terrain.height_at(Vector3(sample.x, 0.0, sample.y)), sample.y)
		var lip: Vector3 = Vector3(sample.x + normal.x * width, terrain.height_at(Vector3(sample.x + normal.x * width, 0.0, sample.y + normal.y * width)), sample.y + normal.y * width)
		inner.append(base)
		outer.append(lip)
	return _stitch_ribbon(inner, outer)

static func _stitch_ribbon(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var verts: PackedVector3Array = PackedVector3Array()
	var count: int = mini(a.size(), b.size())
	for index in range(count - 1):
		verts.append(a[index])
		verts.append(b[index])
		verts.append(a[index + 1])
		verts.append(b[index])
		verts.append(b[index + 1])
		verts.append(a[index + 1])
	return verts

static func _append_height_node(terrain: TerrainModel, nodes: Array, point: Vector3, delta: float) -> void:
	var gx: int = clampi(int(point.x / STEP), 0, TerrainModel.CELLS - 1)
	var gz: int = clampi(int(point.z / STEP), 0, TerrainModel.CELLS - 1)
	var node_index: int = gz * TerrainModel.NODES + gx
	var old: float = terrain.heights[node_index]
	var value: float = clampf(old + delta, -18.0, 65.0)
	if absf(value - old) > 0.001:
		nodes.append([node_index, old, value])

static func _sanitize_points(raw: Variant) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if raw is PackedVector2Array:
		return raw
	if not raw is Array:
		return result
	for item in raw:
		if item is Vector2:
			result.append(item)
		elif item is Vector3:
			result.append(Vector2(item.x, item.z))
		elif item is Array and item.size() >= 2:
			result.append(Vector2(float(item[0]), float(item[1])))
	return result

static func _sanitize_islands(raw: Variant) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for island_value in raw:
		var island: PackedVector2Array = _sanitize_points(island_value)
		if island.size() >= 3:
			result.append(island)
	return result

static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside: bool = false
	var j: int = polygon.size() - 1
	for i in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside

static func _distance_to_ring(point: Vector2, polygon: PackedVector2Array) -> float:
	var best: float = 1.0e9
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		best = minf(best, _distance_to_segment(point, a, b))
	return best

static func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq < 0.0001:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)

static func _segments_intersect(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> bool:
	var d1: float = _cross(b0, b1, a0)
	var d2: float = _cross(b0, b1, a1)
	var d3: float = _cross(a0, a1, b0)
	var d4: float = _cross(a0, a1, b1)
	if ((d1 > 0.0 and d2 < 0.0) or (d1 < 0.0 and d2 > 0.0)) and ((d3 > 0.0 and d4 < 0.0) or (d3 < 0.0 and d4 > 0.0)):
		return true
	return false

static func _cross(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)

static func _resample_ring(polygon: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if polygon.size() < 2:
		return result
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var length: float = a.distance_to(b)
		var steps: int = maxi(1, ceili(length / spacing))
		for step in range(steps):
			result.append(a.lerp(b, float(step) / float(steps)))
	return result

static func _outward_normal(sample: Vector2, polygon: PackedVector2Array, inside: bool) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	var best_distance: float = 1.0e9
	for index in range(polygon.size()):
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[(index + 1) % polygon.size()]
		var distance: float = _distance_to_segment(sample, a, b)
		if distance < best_distance:
			best_distance = distance
			var edge: Vector2 = (b - a).normalized()
			best = Vector2(-edge.y, edge.x)
	if inside:
		best *= -1.0
	return best

static func _order_boundary_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var center: Vector2 = Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	var ordered: Array = points.duplicate()
	ordered.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return atan2(a.y - center.y, a.x - center.x) < atan2(b.y - center.y, b.x - center.x)
	)
	var result: PackedVector2Array = PackedVector2Array()
	for point in ordered:
		result.append(point)
	return result
