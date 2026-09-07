class_name MapGenerator
extends RefCounted

const PREVIEW_SIZE: int = 128
const REACHABILITY_THRESHOLD: float = 0.70
const MAX_SEED_TRIES: int = 8
const ENTRANCE_CLEAR_RADIUS: float = 120.0


static func generate(definition: Dictionary) -> TerrainModel:
	var base_seed: int = int(definition.get("seed", 730241))
	var terrain: TerrainModel = null
	for attempt in range(MAX_SEED_TRIES):
		terrain = _generate_attempt(definition, base_seed + attempt)
		if _validate_reachability(terrain):
			return terrain
	return terrain


static func preview_texture(definition: Dictionary, preview_seed: int = -1) -> ImageTexture:
	var def: Dictionary = definition.duplicate()
	if preview_seed >= 0:
		def["seed"] = preview_seed
	var terrain: TerrainModel = _generate_attempt(def, int(def.get("seed", 730241)), true)
	var image: Image = Image.create(PREVIEW_SIZE, PREVIEW_SIZE, false, Image.FORMAT_RGBA8)
	var step: float = TerrainModel.WIDTH / float(PREVIEW_SIZE)
	for z in range(PREVIEW_SIZE):
		for x in range(PREVIEW_SIZE):
			var world: Vector3 = Vector3(float(x) * step + step * 0.5, 0.0, float(z) * step + step * 0.5)
			var surface: int = terrain.surface_at(world)
			var color: Color
			if surface == 5:
				color = terrain.water_color
			else:
				var height: float = terrain.height_at(world)
				var shade: float = clampf((height + 6.0) / 28.0, 0.0, 1.0)
				color = terrain.palette[surface].lerp(Color("2a2a2a"), 1.0 - shade * 0.35)
			image.set_pixel(x, z, color)
	return ImageTexture.create_from_image(image)


static func heights_hash(terrain: TerrainModel) -> int:
	var hash_value: int = 0
	for value in terrain.heights:
		hash_value = int(hash(value * 1000.0)) ^ ((hash_value << 5) - hash_value)
	return hash_value


static func reachability_ratio(terrain: TerrainModel) -> float:
	return _reachability_ratio(terrain)


static func river_crossing_count(terrain: TerrainModel) -> int:
	return _count_river_crossings(terrain)


static func _generate_attempt(definition: Dictionary, seed_value: int, preview: bool = false) -> TerrainModel:
	var terrain: TerrainModel = TerrainModel.new()
	var map_id: String = str(definition.get("id", "blank_meadow"))
	terrain.map_id = map_id
	terrain.generation_seed = seed_value
	terrain.entrance = Vector3(definition.get("entrance", TerrainModel.DEFAULT_ENTRANCE))
	terrain.rough_name = str(definition.get("rough_name", "Rough"))
	if definition.has("palette"):
		terrain.palette = definition.palette
	if definition.has("cost_multipliers"):
		terrain.cost_multipliers = (definition.cost_multipliers as Dictionary).duplicate()
	if definition.has("water_color"):
		terrain.water_color = Color(definition.water_color)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	match map_id:
		"cedar_house":
			_generate_cedar_house(terrain)
		"blank_meadow":
			_generate_blank_meadow(terrain)
		"harbour_links":
			_generate_harbour_links(terrain, rng)
		"stonebrook_hills":
			_generate_stonebrook_hills(terrain, rng)
		"red_mesa":
			_generate_red_mesa(terrain, rng)
		"pinewood_valley":
			_generate_pinewood_valley(terrain, rng)
		_:
			_generate_blank_meadow(terrain)
	_flatten_entrance(terrain)
	_apply_edge_falloff(terrain)
	_sync_water_surfaces(terrain)
	if not preview:
		_scatter_vegetation(terrain, definition, rng)
	terrain.touch()
	return terrain


static func _generate_cedar_house(terrain: TerrainModel) -> void:
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			terrain.heights[z * TerrainModel.NODES + x] = 1.8 * sin(x * 0.052) * sin(z * 0.037) + 0.7 * cos(z * 0.082)


static func _generate_blank_meadow(terrain: TerrainModel) -> void:
	terrain.heights.fill(1.8)


static func _layered_height(x: int, z: int, rng: RandomNumberGenerator, amplitude: float, ridge: float = 0.0) -> float:
	var noises: Array[FastNoiseLite] = []
	for layer in range(3):
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = rng.randi()
		noise.frequency = 0.004 + float(layer) * 0.006
		noise.fractal_octaves = 3
		noises.append(noise)
	var value: float = 0.0
	value += noises[0].get_noise_2d(float(x), float(z)) * amplitude
	value += noises[1].get_noise_2d(float(x), float(z)) * amplitude * 0.45
	value += noises[2].get_noise_2d(float(x), float(z)) * amplitude * 0.2
	if ridge > 0.0:
		value += absf(noises[1].get_noise_2d(float(x) * 1.4, float(z) * 1.4)) * ridge
	return 1.8 + value


static func _generate_stonebrook_hills(terrain: TerrainModel, rng: RandomNumberGenerator) -> void:
	terrain.cost_multipliers = {"raise": 1.35, "fairway": 1.0, "water": 1.0, "clear_tree": 1.0}
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			terrain.heights[z * TerrainModel.NODES + x] = _layered_height(x, z, rng, 12.0, 4.0)
	_carve_river(terrain, rng, Vector2(180.0, 120.0), Vector2(820.0, 880.0), 11.0, 0.55)


static func _generate_harbour_links(terrain: TerrainModel, rng: RandomNumberGenerator) -> void:
	terrain.palette = PackedColorArray([
		Color("8a9a62"), Color("9cb070"), Color("b8c888"), Color("a0b878"),
		Color("e8d8a8"), Color("4a8aaa"), Color("c4a878"),
	])
	terrain.water_color = Color("4a8aaa")
	terrain.rough_name = "Links rough"
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			var wx: float = float(x) * TerrainModel.STEP
			var wz: float = float(z) * TerrainModel.STEP
			var dune: float = sin(wx * 0.018 + wz * 0.011) * 2.5
			dune += rng.randf_range(-0.4, 0.4)
			terrain.heights[z * TerrainModel.NODES + x] = 2.2 + dune + _layered_height(x, z, rng, 3.5) - 1.8
	for z in range(TerrainModel.CELLS):
		for x in range(TerrainModel.CELLS):
			if float(x) * TerrainModel.STEP < 90.0:
				var index: int = z * TerrainModel.CELLS + x
				var height: float = terrain.heights[z * TerrainModel.NODES + x]
				terrain.water_levels[index] = -0.8
				if height < -0.2:
					terrain.heights[z * TerrainModel.NODES + x] = -0.5
			elif float(x) * TerrainModel.STEP < 130.0:
				var index: int = z * TerrainModel.CELLS + x
				terrain.surfaces[index] = 4


static func _generate_red_mesa(terrain: TerrainModel, rng: RandomNumberGenerator) -> void:
	terrain.palette = PackedColorArray([
		Color("a88458"), Color("b89868"), Color("c8b080"), Color("b09060"),
		Color("e0c898"), Color("6a9aaa"), Color("c09070"),
	])
	terrain.water_color = Color("6a9aaa")
	terrain.rough_name = "Scrub"
	terrain.cost_multipliers = {"raise": 1.1, "fairway": 1.45, "water": 1.6, "clear_tree": 0.85}
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			terrain.heights[z * TerrainModel.NODES + x] = _layered_height(x, z, rng, 8.0, 6.0)
	var oasis: Vector3 = Vector3(640.0, 0.0, 520.0)
	terrain.paint_disk(oasis, 36.0, 5)
	_scatter_kind(terrain, rng, "desert_shrub", 180, 8.0, oasis, 80.0)
	_scatter_kind(terrain, rng, "dune_grass", 120, 10.0, oasis, 60.0)


static func _generate_pinewood_valley(terrain: TerrainModel, rng: RandomNumberGenerator) -> void:
	terrain.cost_multipliers = {"raise": 1.0, "fairway": 1.0, "water": 1.0, "clear_tree": 1.55}
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			var valley: float = 1.0 - absf(float(z) - 128.0) / 128.0
			terrain.heights[z * TerrainModel.NODES + x] = 2.0 + valley * 6.0 + _layered_height(x, z, rng, 5.0)
	var lake: Vector3 = Vector3(512.0, 0.0, 512.0)
	for z in range(TerrainModel.CELLS):
		for x in range(TerrainModel.CELLS):
			var center: Vector3 = Vector3((x + 0.5) * TerrainModel.STEP, 0.0, (z + 0.5) * TerrainModel.STEP)
			if center.distance_to(lake) < 88.0:
				var index: int = z * TerrainModel.CELLS + x
				terrain.water_levels[index] = terrain.height_at(center) - 1.2
	_scatter_kind(terrain, rng, "pine_tree", 420, 7.0, lake, 100.0)


static func _carve_river(terrain: TerrainModel, rng: RandomNumberGenerator, start: Vector2, finish: Vector2, width: float, depth: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 48
	for step in range(steps + 1):
		var t: float = float(step) / float(steps)
		var point: Vector2 = start.lerp(finish, t)
		point += Vector2(sin(t * TAU * 2.3) * 48.0, cos(t * TAU * 1.7) * 36.0) * rng.randf_range(0.6, 1.0)
		points.append(point)
	for z in range(TerrainModel.CELLS):
		for x in range(TerrainModel.CELLS):
			var center: Vector2 = Vector2((x + 0.5) * TerrainModel.STEP, (z + 0.5) * TerrainModel.STEP)
			var best: float = INF
			for index in range(points.size() - 1):
				best = minf(best, _segment_distance_2d(center, points[index], points[index + 1]))
			if best <= width:
				var cell_index: int = z * TerrainModel.CELLS + x
				var node_x: int = clampi(x, 0, TerrainModel.CELLS)
				var node_z: int = clampi(z, 0, TerrainModel.CELLS)
				var node_index: int = node_z * TerrainModel.NODES + node_x
				terrain.heights[node_index] -= depth * (1.0 - best / width)
				terrain.water_levels[cell_index] = terrain.heights[node_index] - 0.4


static func _segment_distance_2d(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ap: Vector2 = point - a
	var ab: Vector2 = b - a
	return (ap - ab * clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)).length()


static func _flatten_entrance(terrain: TerrainModel) -> void:
	var target: float = terrain.height_at(terrain.entrance)
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			var world: Vector3 = Vector3(float(x) * TerrainModel.STEP, 0.0, float(z) * TerrainModel.STEP)
			var dist: float = Vector2(world.x - terrain.entrance.x, world.z - terrain.entrance.z).length()
			if dist > ENTRANCE_CLEAR_RADIUS:
				continue
			var blend: float = smoothstep(ENTRANCE_CLEAR_RADIUS, 0.0, dist)
			var index: int = z * TerrainModel.NODES + x
			terrain.heights[index] = lerpf(terrain.heights[index], target, blend)


static func _apply_edge_falloff(terrain: TerrainModel) -> void:
	var margin: float = 48.0
	for z in range(TerrainModel.NODES):
		for x in range(TerrainModel.NODES):
			var wx: float = float(x) * TerrainModel.STEP
			var wz: float = float(z) * TerrainModel.STEP
			var edge: float = minf(minf(wx, wz), minf(TerrainModel.WIDTH - wx, TerrainModel.WIDTH - wz))
			if edge >= margin:
				continue
			var factor: float = smoothstep(0.0, margin, edge)
			var index: int = z * TerrainModel.NODES + x
			terrain.heights[index] = lerpf(-4.0, terrain.heights[index], factor)


static func _sync_water_surfaces(terrain: TerrainModel) -> void:
	for index in range(TerrainModel.CELLS * TerrainModel.CELLS):
		if terrain.water_levels[index] > -50.0:
			terrain.surfaces[index] = 5


static func _scatter_vegetation(terrain: TerrainModel, definition: Dictionary, rng: RandomNumberGenerator) -> void:
	var biome: String = str(definition.get("biome", "meadow"))
	match biome:
		"meadow":
			if str(definition.get("id", "")) == "cedar_house":
				return
			_scatter_kind(terrain, rng, "oak_tree", 40, 14.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS + 20.0)
			_scatter_kind(terrain, rng, "pine_tree", 24, 14.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS + 20.0)
		"coastal":
			_scatter_kind(terrain, rng, "dune_grass", 90, 9.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS)
			_scatter_kind(terrain, rng, "palm_tree", 36, 12.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS)
		"hills":
			_scatter_kind(terrain, rng, "oak_tree", 70, 11.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS)
			_scatter_kind(terrain, rng, "pine_tree", 50, 11.0, terrain.entrance, ENTRANCE_CLEAR_RADIUS)
		"desert":
			pass
		"valley":
			pass


static func _scatter_kind(terrain: TerrainModel, rng: RandomNumberGenerator, kind: String, count: int, min_spacing: float, avoid: Vector3, avoid_radius: float) -> void:
	var accepted: Array[Vector2] = []
	var attempts: int = count * 40
	while accepted.size() < count and attempts > 0:
		attempts -= 1
		var point: Vector2 = Vector2(rng.randf_range(40.0, TerrainModel.WIDTH - 40.0), rng.randf_range(40.0, TerrainModel.WIDTH - 40.0))
		if point.distance_to(Vector2(avoid.x, avoid.z)) < avoid_radius:
			continue
		var ok: bool = true
		for other in accepted:
			if point.distance_to(other) < min_spacing:
				ok = false
				break
		if not ok:
			continue
		var world: Vector3 = Vector3(point.x, 0.0, point.y)
		if not terrain.playable(world) or terrain.slope_at(world).length() > 0.9:
			continue
		accepted.append(point)
		terrain.add_object(kind, world, rng.randf() * TAU)


static func _validate_reachability(terrain: TerrainModel) -> bool:
	return _reachability_ratio(terrain) >= REACHABILITY_THRESHOLD


static func _reachability_ratio(terrain: TerrainModel) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 90210
	var samples: int = 64
	var reached: int = 0
	for _i in range(samples):
		var point: Vector3 = Vector3(rng.randf_range(80.0, 944.0), 0.0, rng.randf_range(80.0, 944.0))
		if not terrain.playable(point):
			continue
		if not terrain.route(terrain.entrance, point).is_empty():
			reached += 1
	return float(reached) / float(samples)


static func _count_river_crossings(terrain: TerrainModel) -> int:
	# A crossing is a water band narrow enough to bridge: playable ground on
	# both sides within a few cells and a span a bridge can cover.
	var crossings: int = 0
	var seen: Dictionary = {}
	for z in range(2, TerrainModel.CELLS - 2):
		for x in range(2, TerrainModel.CELLS - 2):
			var center: Vector3 = Vector3((x + 0.5) * TerrainModel.STEP, 0.0, (z + 0.5) * TerrainModel.STEP)
			if terrain.surface_at(center) != 5:
				continue
			for axis in ["x", "z"]:
				var bank_a: Vector3 = Vector3(1e9, 0.0, 1e9)
				var bank_b: Vector3 = Vector3(1e9, 0.0, 1e9)
				for offset in range(1, 5):
					if axis == "x":
						if bank_a.x > 1e8:
							var west: Vector3 = Vector3((x - offset) * TerrainModel.STEP + 2.0, 0.0, center.z)
							if terrain.playable(west):
								bank_a = west
						if bank_b.x > 1e8:
							var east: Vector3 = Vector3((x + offset) * TerrainModel.STEP + 2.0, 0.0, center.z)
							if terrain.playable(east):
								bank_b = east
					else:
						if bank_a.x > 1e8:
							var north: Vector3 = Vector3(center.x, 0.0, (z - offset) * TerrainModel.STEP + 2.0)
							if terrain.playable(north):
								bank_a = north
						if bank_b.x > 1e8:
							var south: Vector3 = Vector3(center.x, 0.0, (z + offset) * TerrainModel.STEP + 2.0)
							if terrain.playable(south):
								bank_b = south
				if bank_a.x > 1e8 or bank_b.x > 1e8:
					continue
				if bank_a.distance_to(bank_b) > 30.0:
					continue
				var key: Vector2i = Vector2i(int(center.x / 16.0), int(center.z / 16.0))
				if seen.has(key):
					continue
				seen[key] = true
				crossings += 1
	return crossings
