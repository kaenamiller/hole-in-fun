class_name WaterField
extends RefCounted

## Maintained depth/shore/body fields for package 11. Gameplay water levels are unchanged.

const RES: int = 256
const MAX_DEPTH_M: float = 12.0
const SHORE_BAND_M: float = 16.0
const LEVEL_TOLERANCE: float = 0.25
const INF_DIST: float = 1.0e6

static func ensure_arrays(terrain: TerrainModel) -> void:
	if terrain._water_body_ids.size() == RES * RES:
		return
	terrain._water_body_ids.resize(RES * RES)
	terrain._water_body_ids.fill(-1)
	terrain._water_depth.resize(RES * RES)
	terrain._water_depth.fill(0.0)
	terrain._water_shore_dist.resize(RES * RES)
	terrain._water_shore_dist.fill(INF_DIST)
	terrain._water_dry_shore_dist.resize(RES * RES)
	terrain._water_dry_shore_dist.fill(INF_DIST)
	terrain._water_surface_cache.resize(RES * RES)
	terrain._water_surface_cache.fill(-100.0)

static func rebuild(terrain: TerrainModel, rect: Rect2i = Rect2i(0, 0, RES, RES)) -> void:
	ensure_arrays(terrain)
	var x0: int = clampi(rect.position.x, 0, RES - 1)
	var y0: int = clampi(rect.position.y, 0, RES - 1)
	var x1: int = clampi(rect.position.x + rect.size.x, 0, RES)
	var y1: int = clampi(rect.position.y + rect.size.y, 0, RES)
	# Shore distance bleeds across the band; expand the rebuild window.
	var pad: int = ceili(SHORE_BAND_M / TerrainModel.STEP) + 2
	x0 = maxi(0, x0 - pad)
	y0 = maxi(0, y0 - pad)
	x1 = mini(RES, x1 + pad)
	y1 = mini(RES, y1 + pad)
	_assign_body_ids(terrain, x0, y0, x1, y1)
	_compute_depths(terrain, x0, y0, x1, y1)
	_distance_to_dry(terrain, x0, y0, x1, y1)
	_distance_to_water(terrain, x0, y0, x1, y1)
	terrain._water_field_revision = terrain.revision

static func full_rebuild(terrain: TerrainModel) -> void:
	rebuild(terrain, Rect2i(0, 0, RES, RES))

static func mark_dirty(terrain: TerrainModel, bounds: Rect2) -> void:
	if bounds.size == Vector2.ZERO:
		terrain._water_dirty_full = true
		return
	var x0: int = clampi(int(bounds.position.x / TerrainModel.STEP), 0, RES - 1)
	var z0: int = clampi(int(bounds.position.y / TerrainModel.STEP), 0, RES - 1)
	var x1: int = clampi(int((bounds.position.x + bounds.size.x) / TerrainModel.STEP), 0, RES - 1)
	var z1: int = clampi(int((bounds.position.y + bounds.size.y) / TerrainModel.STEP), 0, RES - 1)
	var rect: Rect2i = Rect2i(x0, z0, x1 - x0 + 1, z1 - z0 + 1)
	if terrain._water_dirty_rect.size == Vector2i.ZERO:
		terrain._water_dirty_rect = rect
	else:
		var merged: Rect2i = terrain._water_dirty_rect
		var mx0: int = mini(merged.position.x, rect.position.x)
		var my0: int = mini(merged.position.y, rect.position.y)
		var mx1: int = maxi(merged.position.x + merged.size.x, rect.position.x + rect.size.x)
		var my1: int = maxi(merged.position.y + merged.size.y, rect.position.y + rect.size.y)
		terrain._water_dirty_rect = Rect2i(mx0, my0, mx1 - mx0, my1 - my0)

static func flush_dirty(terrain: TerrainModel) -> void:
	if terrain._water_field_revision == terrain.revision:
		return
	if terrain._water_dirty_full or terrain._water_dirty_rect.size == Vector2i.ZERO:
		full_rebuild(terrain)
	else:
		rebuild(terrain, terrain._water_dirty_rect)
	terrain._water_dirty_full = false
	terrain._water_dirty_rect = Rect2i()

static func build_image(terrain: TerrainModel) -> Image:
	flush_dirty(terrain)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(RES * RES * 4)
	for z in range(RES):
		for x in range(RES):
			var index: int = z * RES + x
			var is_water: bool = int(terrain.surfaces[index]) == 5
			var body_id: int = int(terrain._water_body_ids[index])
			var depth: float = terrain._water_depth[index]
			var shore: float = terrain._water_shore_dist[index] if is_water else terrain._water_dry_shore_dist[index]
			var i: int = index * 4
			bytes[i] = int(clampf(depth / MAX_DEPTH_M, 0.0, 1.0) * 255.0)
			bytes[i + 1] = int(clampf(shore / SHORE_BAND_M, 0.0, 1.0) * 255.0)
			bytes[i + 2] = int(clampf(float(maxi(body_id, 0)) / 255.0, 0.0, 1.0) * 255.0)
			bytes[i + 3] = 255 if is_water else 0
	return Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, bytes)

static func sample(terrain: TerrainModel, world_pos: Vector3) -> Dictionary:
	flush_dirty(terrain)
	var index: int = terrain._cell_index(world_pos)
	var is_water: bool = int(terrain.surfaces[index]) == 5
	var basin: float = terrain.height_at(world_pos)
	if not is_water:
		return {
			"body_id": -1,
			"depth": 0.0,
			"shore_distance": terrain._water_dry_shore_dist[index],
			"surface_y": 0.0,
			"basin_y": basin,
		}
	var surface_y: float = terrain.water_levels[index]
	return {
		"body_id": int(terrain._water_body_ids[index]),
		"depth": terrain._water_depth[index],
		"shore_distance": terrain._water_shore_dist[index],
		"surface_y": surface_y,
		"basin_y": basin,
	}

static func body_exists(terrain: TerrainModel, body_id: int) -> bool:
	if body_id < 0:
		return false
	flush_dirty(terrain)
	for index in range(RES * RES):
		if int(terrain._water_body_ids[index]) == body_id:
			return true
	return false

static func active_body_ids(terrain: TerrainModel) -> PackedInt32Array:
	flush_dirty(terrain)
	var seen: Dictionary = {}
	var result: PackedInt32Array = PackedInt32Array()
	for index in range(RES * RES):
		var body_id: int = int(terrain._water_body_ids[index])
		if body_id < 0 or seen.has(body_id):
			continue
		seen[body_id] = true
		result.append(body_id)
	return result

static func _assign_body_ids(terrain: TerrainModel, x0: int, y0: int, x1: int, y1: int) -> void:
	for z in range(y0, y1):
		for x in range(x0, x1):
			terrain._water_body_ids[z * RES + x] = -1
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(RES * RES)
	visited.fill(0)
	for z in range(RES):
		for x in range(RES):
			var start: int = z * RES + x
			if visited[start] != 0 or int(terrain.surfaces[start]) != 5:
				continue
			var level_seed: float = terrain.water_levels[start]
			var queue: Array = [start]
			visited[start] = 1
			var members: Array = [start]
			while not queue.is_empty():
				var current: int = int(queue.pop_front())
				var cx: int = current % RES
				var cz: int = int(current / RES)
				for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = cx + offset.x
					var nz: int = cz + offset.y
					if nx < 0 or nz < 0 or nx >= RES or nz >= RES:
						continue
					var neighbor: int = nz * RES + nx
					if visited[neighbor] != 0 or int(terrain.surfaces[neighbor]) != 5:
						continue
					if absf(terrain.water_levels[neighbor] - level_seed) > LEVEL_TOLERANCE:
						continue
					visited[neighbor] = 1
					queue.append(neighbor)
					members.append(neighbor)
			var body_id: int = _body_id_for_members(members)
			for member in members:
				terrain._water_body_ids[int(member)] = body_id

static func _body_id_for_members(members: Array) -> int:
	var min_index: int = int(members[0])
	for member in members:
		min_index = mini(min_index, int(member))
	return min_index

static func _compute_depths(terrain: TerrainModel, x0: int, y0: int, x1: int, y1: int) -> void:
	for z in range(y0, y1):
		for x in range(x0, x1):
			var index: int = z * RES + x
			if int(terrain.surfaces[index]) != 5:
				terrain._water_depth[index] = 0.0
				terrain._water_surface_cache[index] = -100.0
				continue
			var center: Vector3 = Vector3((x + 0.5) * TerrainModel.STEP, 0.0, (z + 0.5) * TerrainModel.STEP)
			var basin: float = terrain.height_at(center)
			var surface_y: float = terrain.water_levels[index]
			terrain._water_surface_cache[index] = surface_y
			terrain._water_depth[index] = maxf(0.0, surface_y - basin)

static func _distance_to_dry(terrain: TerrainModel, x0: int, y0: int, x1: int, y1: int) -> void:
	for z in range(y0, y1):
		for x in range(x0, x1):
			var index: int = z * RES + x
			if int(terrain.surfaces[index]) != 5:
				terrain._water_shore_dist[index] = INF_DIST
				continue
			var best: float = INF_DIST
			for dz in range(-16, 17):
				for dx in range(-16, 17):
					var nx: int = x + dx
					var nz: int = z + dz
					if nx < 0 or nz < 0 or nx >= RES or nz >= RES:
						continue
					if int(terrain.surfaces[nz * RES + nx]) == 5:
						continue
					var dist: float = sqrt(float(dx * dx + dz * dz)) * TerrainModel.STEP
					best = minf(best, dist)
			terrain._water_shore_dist[index] = best

static func _distance_to_water(terrain: TerrainModel, x0: int, y0: int, x1: int, y1: int) -> void:
	for z in range(y0, y1):
		for x in range(x0, x1):
			var index: int = z * RES + x
			if int(terrain.surfaces[index]) == 5:
				terrain._water_dry_shore_dist[index] = 0.0
				continue
			var best: float = INF_DIST
			for dz in range(-16, 17):
				for dx in range(-16, 17):
					var nx: int = x + dx
					var nz: int = z + dz
					if nx < 0 or nz < 0 or nx >= RES or nz >= RES:
						continue
					if int(terrain.surfaces[nz * RES + nx]) != 5:
						continue
					var dist: float = sqrt(float(dx * dx + dz * dz)) * TerrainModel.STEP
					best = minf(best, dist)
			terrain._water_dry_shore_dist[index] = best
