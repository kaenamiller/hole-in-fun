class_name GroundCover
extends RefCounted

## Deterministic cosmetic ground cover (package 08). Uses a scatter seed separate
## from simulation RNG. Instances never affect gameplay collision or routing.

const GLOBAL_SCATTER_SEED: int = 0x080026
const REGION_SIZE: float = 128.0
const CLUSTER_SPACING: float = 16.0

const SURFACE_ROUGH: int = 0
const SURFACE_FAIRWAY: int = 1
const SURFACE_GREEN: int = 2
const SURFACE_TEE: int = 3
const SURFACE_SAND: int = 4
const SURFACE_WATER: int = 5
const SURFACE_GARDEN: int = 6

const PATH_KINDS: Array[String] = [
	"path_paved", "path_gravel", "bridge_cart", "bridge_walk", "bridge",
]
const BUILDING_KINDS: Array[String] = [
	"clubhouse", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed",
	"driving_range", "halfway_house", "pro_shop", "caddie_house", "restaurant", "spa", "lodge",
]
const TREE_KINDS: Array[String] = ["oak_tree", "pine_tree", "palm_tree"]

const FAMILIES: Dictionary = {
	"rough_tuft": {
		"surfaces": [SURFACE_ROUGH],
		"slope_max": 0.85,
		"cluster_keep": 0.42,
		"instances_min": 3,
		"instances_max": 7,
		"region_budget": 52,
		"scale": Vector3(0.85, 1.0, 0.85),
	},
	"bank_reed": {
		"surfaces": [SURFACE_ROUGH, SURFACE_GARDEN],
		"shore_max": 4.5,
		"slope_max": 0.65,
		"cluster_keep": 0.55,
		"instances_min": 4,
		"instances_max": 9,
		"region_budget": 36,
		"scale": Vector3(1.0, 1.15, 1.0),
	},
	"shrub": {
		"surfaces": [SURFACE_ROUGH, SURFACE_GARDEN],
		"slope_max": 0.55,
		"cluster_keep": 0.28,
		"instances_min": 2,
		"instances_max": 5,
		"region_budget": 28,
		"scale": Vector3(0.9, 0.95, 0.9),
		"margin_tree": 14.0,
		"margin_building": 10.0,
	},
	"flower": {
		"surfaces": [SURFACE_ROUGH, SURFACE_GARDEN, SURFACE_FAIRWAY],
		"slope_max": 0.45,
		"cluster_keep": 0.18,
		"instances_min": 2,
		"instances_max": 6,
		"region_budget": 20,
		"scale": Vector3(0.95, 1.0, 0.95),
		"margin_building": 8.0,
	},
	"leaf_litter": {
		"surfaces": [SURFACE_ROUGH],
		"slope_max": 0.75,
		"cluster_keep": 0.34,
		"instances_min": 4,
		"instances_max": 10,
		"region_budget": 44,
		"scale": Vector3(1.0, 1.0, 1.0),
		"margin_tree": 6.0,
	},
	"small_stone": {
		"surfaces": [SURFACE_ROUGH, SURFACE_GARDEN],
		"shore_max": 5.0,
		"slope_max": 0.9,
		"cluster_keep": 0.24,
		"instances_min": 1,
		"instances_max": 3,
		"region_budget": 18,
		"scale": Vector3(0.75, 0.75, 0.75),
		"margin_tree": 10.0,
	},
}

const REGION_TOTAL_BUDGET: int = 190
const EXCLUSION := {
	"cup_radius": 5.5,
	"tee_radius": 4.5,
	"green_buffer": 1.8,
	"fairway_buffer": 1.2,
	"tee_surface_buffer": 2.5,
	"path_half_width_paved": 3.4,
	"path_half_width_gravel": 2.0,
	"building_clear": 6.0,
	"entrance_radius": 28.0,
	"sim_tree_radius": 2.4,
}


static func scatter_seed_for(terrain: TerrainModel) -> int:
	return int(terrain.generation_seed) ^ GLOBAL_SCATTER_SEED


static func region_key_for_point(p: Vector3) -> Vector2i:
	return Vector2i(int(p.x / REGION_SIZE), int(p.z / REGION_SIZE))


static func region_rect(region: Vector2i) -> Rect2:
	return Rect2(region.x * REGION_SIZE, region.y * REGION_SIZE, REGION_SIZE, REGION_SIZE)


static func hash_u32(a: int, b: int, c: int, d: int) -> int:
	var value: int = a & 0xFFFFFFFF
	value = (value ^ (b & 0xFFFFFFFF)) * 0x9E3779B1 & 0xFFFFFFFF
	value = (value ^ (c & 0xFFFFFFFF)) * 0x85EBCA77 & 0xFFFFFFFF
	value = (value ^ (d & 0xFFFFFFFF)) * 0xC2B2AE3D & 0xFFFFFFFF
	return value & 0xFFFFFFFF


static func hash_unit(world_seed: int, region: Vector2i, family: String, index: int) -> float:
	var family_id: int = family.hash()
	var h: int = hash_u32(world_seed, region.x, region.y * 997 + family_id, index)
	return float(h) / 4294967295.0


static func density_keep(stable_id: int, density: float) -> bool:
	if density >= 0.999:
		return true
	var step: int = maxi(1, int(round(1.0 / clampf(density, 0.2, 1.0))))
	return stable_id % step == 0


static func build_region_batches(
	terrain: TerrainModel,
	region: Vector2i,
	settings: GraphicsSettings,
) -> Array:
	if not GroundCoverAssets.available():
		return []
	var world_seed: int = scatter_seed_for(terrain)
	var rect: Rect2 = region_rect(region)
	var context: Dictionary = _build_region_context(terrain, rect)
	var accepted: Array[Dictionary] = []
	for family_id in FAMILIES.keys():
		var family: String = str(family_id)
		var rules: Dictionary = FAMILIES[family]
		var cluster_index: int = 0
		var x0: float = rect.position.x
		var z0: float = rect.position.y
		var cols: int = maxi(1, int(REGION_SIZE / CLUSTER_SPACING))
		for gz in range(cols):
			for gx in range(cols):
				var keep: float = hash_unit(world_seed, region, family, cluster_index)
				cluster_index += 1
				if keep > float(rules.get("cluster_keep", 0.3)):
					continue
				var anchor := Vector3(
					x0 + float(gx) * CLUSTER_SPACING + hash_unit(world_seed, region, family + ":x", cluster_index) * 8.0,
					0.0,
					z0 + float(gz) * CLUSTER_SPACING + hash_unit(world_seed, region, family + ":z", cluster_index) * 8.0,
				)
				var count: int = int(rules.get("instances_min", 2)) + int(
					hash_unit(world_seed, region, family + ":n", cluster_index)
					* float(int(rules.get("instances_max", 4)) - int(rules.get("instances_min", 2)) + 1)
				)
				for instance_index in range(count):
					var offset_angle: float = hash_unit(world_seed, region, family, cluster_index * 17 + instance_index) * TAU
					var offset_radius: float = 0.6 + hash_unit(world_seed, region, family + ":r", cluster_index * 31 + instance_index) * 2.8
					var pos: Vector3 = anchor + Vector3(cos(offset_angle) * offset_radius, 0.0, sin(offset_angle) * offset_radius)
					var stable_id: int = hash_u32(world_seed, cluster_index, instance_index, family.hash())
					if not density_keep(stable_id, settings.foliage_density):
						continue
					var variant: int = stable_id % GroundCoverAssets.variant_count(family)
					var score: float = hash_unit(world_seed, region, family + ":score", stable_id)
					if not _accept_instance(context, terrain, pos, family, rules):
						continue
					pos.y = terrain.height_at(pos)
					var slope: Vector2 = terrain.slope_at(pos)
					if slope.length() > float(rules.get("slope_max", 1.0)):
						continue
					var yaw: float = hash_unit(world_seed, region, family + ":yaw", stable_id) * TAU
					var basis: Basis = _slope_basis(slope, yaw)
					var scale_rules: Vector3 = rules.get("scale", Vector3.ONE)
					var scale_jitter: float = 0.85 + hash_unit(world_seed, region, family + ":s", stable_id) * 0.35
					var transform: Transform3D = Transform3D(
						Basis.from_scale(scale_rules * scale_jitter) * basis,
						pos,
					)
					accepted.append({
						"family": family,
						"variant": variant,
						"transform": transform,
						"score": score,
						"stable_id": stable_id,
					})
	var by_family: Dictionary = {}
	for row in accepted:
		var family_name: String = str(row.get("family", ""))
		if not by_family.has(family_name):
			by_family[family_name] = []
		(by_family[family_name] as Array).append(row)
	var batches: Array = []
	var region_used: int = 0
	for family_name in FAMILIES.keys():
		if not by_family.has(family_name):
			continue
		var rows: Array = by_family[family_name]
		rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return float(a.get("score", 0.0)) < float(b.get("score", 0.0))
		)
		var family_budget: int = mini(int(FAMILIES[family_name].get("region_budget", 24)), maxi(0, REGION_TOTAL_BUDGET - region_used))
		if rows.size() > family_budget:
			rows = rows.slice(0, family_budget)
		region_used += rows.size()
		if rows.is_empty():
			continue
		batches.append({"family": family_name, "instances": rows})
	return batches


static func _slope_basis(slope: Vector2, yaw: float) -> Basis:
	var normal: Vector3 = Vector3(-slope.x, 1.0, -slope.y).normalized()
	var forward: Vector3 = Vector3(sin(yaw), 0.0, cos(yaw))
	var tangent: Vector3 = forward - normal * forward.dot(normal)
	if tangent.length_squared() < 0.0001:
		tangent = Vector3(1, 0, 0) - normal * normal.x
	tangent = tangent.normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	return Basis(tangent, normal, bitangent)


static func _build_region_context(terrain: TerrainModel, rect: Rect2) -> Dictionary:
	var shore_dim: int = int(REGION_SIZE / TerrainModel.STEP) + 3
	var shore_grid: PackedFloat32Array = PackedFloat32Array()
	shore_grid.resize(shore_dim * shore_dim)
	for z in range(shore_dim):
		for x in range(shore_dim):
			var sample: Vector3 = Vector3(rect.position.x + float(x) * TerrainModel.STEP, 0.0, rect.position.y + float(z) * TerrainModel.STEP)
			shore_grid[z * shore_dim + x] = _shore_distance_raster(terrain, sample)
	var paths: Array = []
	for obj in terrain.objects:
		if str(obj.get("kind", "")) not in PATH_KINDS or not obj.has("end"):
			continue
		var half_width: float = EXCLUSION.path_half_width_paved if str(obj.kind).begins_with("path_paved") or str(obj.kind).begins_with("bridge") else EXCLUSION.path_half_width_gravel
		paths.append({"start": Vector2(obj.pos.x, obj.pos.z), "end": Vector2(obj.end.x, obj.end.z), "half_width": half_width})
	var buildings: Array = []
	for obj in terrain.objects:
		if str(obj.get("kind", "")) not in BUILDING_KINDS:
			continue
		buildings.append({
			"pos": Vector2(obj.pos.x, obj.pos.z),
			"clear": float(Catalog.find(str(obj.kind)).get("radius", 6.0)) + EXCLUSION.building_clear,
		})
	var trees: Array = []
	for obj in terrain.objects:
		if str(obj.get("kind", "")) not in TREE_KINDS:
			continue
		trees.append({
			"pos": Vector2(obj.pos.x, obj.pos.z),
			"radius": float(Catalog.find(str(obj.kind)).get("radius", 1.5)),
		})
	var holes: Array = []
	for hole in terrain.holes:
		holes.append({
			"cup": Vector2(TerrainModel.effective_cup(hole).x, TerrainModel.effective_cup(hole).z),
			"tee": Vector2(hole.get("tee", Vector3.ZERO).x, hole.get("tee", Vector3.ZERO).z),
		})
	return {
		"rect": rect,
		"shore_dim": shore_dim,
		"shore_grid": shore_grid,
		"paths": paths,
		"buildings": buildings,
		"trees": trees,
		"holes": holes,
		"entrance": Vector2(terrain.entrance.x, terrain.entrance.z),
	}


static func _shore_distance_raster(terrain: TerrainModel, p: Vector3) -> float:
	if terrain.surface_at(p) == SURFACE_WATER:
		return 0.0
	var cx: int = clampi(int(p.x / TerrainModel.STEP), 0, 255)
	var cz: int = clampi(int(p.z / TerrainModel.STEP), 0, 255)
	var best: float = 999.0
	for dz in range(-16, 17):
		for dx in range(-16, 17):
			var nx: int = cx + dx
			var nz: int = cz + dz
			if nx < 0 or nz < 0 or nx > 255 or nz > 255:
				continue
			if int(terrain.surfaces[nz * 256 + nx]) != SURFACE_WATER:
				continue
			best = minf(best, Vector2(float(dx), float(dz)).length() * TerrainModel.STEP)
	return best


static func _shore_distance(context: Dictionary, p: Vector3) -> float:
	var rect: Rect2 = context.get("rect", Rect2())
	var dim: int = int(context.get("shore_dim", 0))
	if dim <= 0:
		return 999.0
	var local_x: int = clampi(int((p.x - rect.position.x) / TerrainModel.STEP), 0, dim - 1)
	var local_z: int = clampi(int((p.z - rect.position.y) / TerrainModel.STEP), 0, dim - 1)
	return float((context.get("shore_grid", PackedFloat32Array()) as PackedFloat32Array)[local_z * dim + local_x])


static func _accept_instance(context: Dictionary, terrain: TerrainModel, p: Vector3, family: String, rules: Dictionary) -> bool:
	if p.x < 4.0 or p.z < 4.0 or p.x > TerrainModel.WIDTH - 4.0 or p.z > TerrainModel.WIDTH - 4.0:
		return false
	var surface: int = terrain.surface_at(p)
	if surface == SURFACE_WATER:
		return false
	if surface == SURFACE_GREEN or surface == SURFACE_TEE:
		return false
	if surface == SURFACE_SAND and family != "leaf_litter":
		return false
	var allowed: Array = rules.get("surfaces", [])
	if not allowed.is_empty() and surface not in allowed:
		return false
	if surface == SURFACE_FAIRWAY and family != "flower":
		return false
	if terrain.boundary_distance_at(p, "green") <= EXCLUSION.green_buffer:
		return false
	if surface == SURFACE_FAIRWAY and terrain.boundary_distance_at(p, "") <= EXCLUSION.fairway_buffer:
		return false
	for hole in context.get("holes", []):
		var row: Dictionary = hole
		if Vector2(p.x, p.z).distance_to(row.get("cup", Vector2.ZERO)) <= EXCLUSION.cup_radius:
			return false
		if Vector2(p.x, p.z).distance_to(row.get("tee", Vector2.ZERO)) <= EXCLUSION.tee_radius:
			return false
	if Vector2(p.x, p.z).distance_to(context.get("entrance", Vector2.ZERO)) <= EXCLUSION.entrance_radius:
		return false
	if _distance_to_paths(context, p) <= 0.0:
		return false
	if _distance_to_building_clear(context, p) <= 0.0:
		return false
	if _distance_to_sim_trees(context, p) <= EXCLUSION.sim_tree_radius:
		return false
	var shore_distance: float = _shore_distance(context, p)
	if rules.has("shore_max"):
		if shore_distance > float(rules.shore_max):
			return false
	elif shore_distance < 1.5 and family not in ["bank_reed", "small_stone"]:
		return false
	if rules.has("margin_tree"):
		if _nearest_tree_distance(context, p) > float(rules.margin_tree):
			if family in ["shrub", "leaf_litter", "small_stone"]:
				return false
	if rules.has("margin_building"):
		if _nearest_building_distance(context, p) > float(rules.margin_building):
			if family == "flower":
				return false
	return true


static func _distance_to_paths(context: Dictionary, p: Vector3) -> float:
	var best: float = 999.0
	for row_value in context.get("paths", []):
		var row: Dictionary = row_value
		var start: Vector2 = row.get("start", Vector2.ZERO)
		var end: Vector2 = row.get("end", Vector2.ZERO)
		var segment: Vector2 = end - start
		var length_sq: float = segment.length_squared()
		if length_sq < 0.0001:
			continue
		var t: float = clampf((Vector2(p.x, p.z) - start).dot(segment) / length_sq, 0.0, 1.0)
		var closest: Vector2 = start + segment * t
		best = minf(best, Vector2(p.x, p.z).distance_to(closest) - float(row.get("half_width", 2.0)))
	return best


static func _distance_to_building_clear(context: Dictionary, p: Vector3) -> float:
	var best: float = 999.0
	for row_value in context.get("buildings", []):
		var row: Dictionary = row_value
		best = minf(best, Vector2(p.x, p.z).distance_to(row.get("pos", Vector2.ZERO)) - float(row.get("clear", 6.0)))
	return best


static func _nearest_building_distance(context: Dictionary, p: Vector3) -> float:
	var best: float = 999.0
	for row_value in context.get("buildings", []):
		var row: Dictionary = row_value
		best = minf(best, Vector2(p.x, p.z).distance_to(row.get("pos", Vector2.ZERO)))
	return best


static func _nearest_tree_distance(context: Dictionary, p: Vector3) -> float:
	var best: float = 999.0
	for row_value in context.get("trees", []):
		var row: Dictionary = row_value
		best = minf(best, Vector2(p.x, p.z).distance_to(row.get("pos", Vector2.ZERO)))
	return best


static func _distance_to_sim_trees(context: Dictionary, p: Vector3) -> float:
	var best: float = 999.0
	for row_value in context.get("trees", []):
		var row: Dictionary = row_value
		best = minf(best, Vector2(p.x, p.z).distance_to(row.get("pos", Vector2.ZERO)) - float(row.get("radius", 1.5)))
	return best
