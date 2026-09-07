class_name TerrainModel
extends RefCounted

const CELLS = 256
const STEP = 4.0
const WIDTH = 1024.0
const NODES = 257
const SURFACE_NAMES = ["Rough", "Fairway", "Green", "Tee", "Sand", "Water", "Garden soil"]
const SURFACE_COLORS = [Color("637f3d"), Color("8cab4e"), Color("adc665"), Color("94b557"), Color("dfcb9e"), Color("65aaa8"), Color("b18b60")]
const DEFAULT_ENTRANCE: Vector3 = Vector3(64.0, 0.0, 64.0)
const DEFAULT_COST_MULTIPLIERS: Dictionary = {"raise": 1.0, "fairway": 1.0, "water": 1.0, "clear_tree": 1.0}
const TREE_KINDS: Array[String] = ["oak_tree", "pine_tree", "palm_tree", "desert_shrub", "dune_grass"]
var entrance: Vector3 = DEFAULT_ENTRANCE
var palette: PackedColorArray = _default_palette()
var cost_multipliers: Dictionary = DEFAULT_COST_MULTIPLIERS.duplicate()
var map_id: String = "cedar_house"
var rough_name: String = "Rough"
var water_color: Color = Color("65aaa8")
var heights = PackedFloat32Array()
var surfaces = PackedByteArray()
var water_levels = PackedFloat32Array()
var holes: Array[Dictionary] = []
var objects: Array[Dictionary] = []
var condition = PackedFloat32Array()
var revision = 0
var _hole_condition_cache: Dictionary = {}
var _hole_condition_revision: int = -1
var _hole_condition_minute: float = -1.0

var wear: float:
	get:
		return course_wear()
	set(value):
		_set_uniform_wear(value)
var next_id = 1
var changed_chunks: Dictionary = {}
var _walk: AStarGrid2D
var _cart: AStarGrid2D
var _nav_revision = -1
var _nav_y = PackedFloat32Array()
var _route_cache: Dictionary = {}
var _beauty_cache: Dictionary = {}
var _green_owner_map: PackedInt32Array = PackedInt32Array()
var _green_cells_cache: Dictionary = {}
var _bunkers_cache: Array = []
var _green_cache_revision: int = -1
var _bunkers_cache_revision: int = -1
var _water_points: PackedVector3Array = PackedVector3Array()
var _water_cache_revision: int = -1

static func _default_palette() -> PackedColorArray:
	return PackedColorArray(SURFACE_COLORS)

func _init() -> void:
	palette = _default_palette()
	heights.resize(NODES * NODES)
	surfaces.resize(CELLS * CELLS)
	condition.resize(CELLS * CELLS)
	condition.fill(1.0)
	water_levels.resize(CELLS * CELLS)
	water_levels.fill(-100.0)
	for z in range(NODES):
		for x in range(NODES):
			heights[z * NODES + x] = 1.8 * sin(x * 0.052) * sin(z * 0.037) + 0.7 * cos(z * 0.082)

func uid() -> int:
	var result = next_id
	next_id += 1
	return result

func touch() -> void:
	revision += 1
	_route_cache.clear()
	_beauty_cache.clear()
	_green_cache_revision = -1
	_bunkers_cache_revision = -1
	_water_cache_revision = -1

func height_at(p: Vector3) -> float:
	var gx = clampf(p.x / STEP, 0, CELLS - 0.0001)
	var gz = clampf(p.z / STEP, 0, CELLS - 0.0001)
	var x = int(gx)
	var z = int(gz)
	return lerpf(lerpf(heights[z*NODES+x], heights[z*NODES+x+1], gx-x), lerpf(heights[(z+1)*NODES+x], heights[(z+1)*NODES+x+1], gx-x), gz-z)

func surface_at(p: Vector3) -> int:
	return surfaces[clampi(int(p.z / STEP),0,255)*CELLS + clampi(int(p.x / STEP),0,255)]

func _cell_index(p: Vector3) -> int:
	return clampi(int(p.z / STEP), 0, 255) * CELLS + clampi(int(p.x / STEP), 0, 255)

static func _maintained_surface(surface: int) -> bool:
	return surface in [1, 2, 3, 4]

func condition_at(p: Vector3) -> float:
	return condition[_cell_index(p)]

func course_wear() -> float:
	var total: float = 0.0
	var count: int = 0
	for index in range(CELLS * CELLS):
		var surface: int = int(surfaces[index])
		if _maintained_surface(surface):
			total += condition[index]
			count += 1
	if count == 0:
		return 0.0
	return clampf(1.0 - total / float(count), 0.0, 1.0)

func _set_uniform_wear(value: float) -> void:
	var target: float = clampf(1.0 - value, 0.0, 1.0)
	for index in range(CELLS * CELLS):
		if _maintained_surface(int(surfaces[index])):
			condition[index] = target

func apply_wear_at(p: Vector3, amount: float) -> void:
	var index: int = _cell_index(p)
	if not _maintained_surface(int(surfaces[index])):
		return
	condition[index] = clampf(condition[index] - amount, 0.0, 1.0)

func restore_condition_at(p: Vector3, amount: float, neighborhood: int = 0) -> void:
	var cx: int = clampi(int(p.x / STEP), 0, 255)
	var cz: int = clampi(int(p.z / STEP), 0, 255)
	for dz in range(-neighborhood, neighborhood + 1):
		for dx in range(-neighborhood, neighborhood + 1):
			var x: int = clampi(cx + dx, 0, 255)
			var z: int = clampi(cz + dz, 0, 255)
			var index: int = z * CELLS + x
			if _maintained_surface(int(surfaces[index])):
				condition[index] = clampf(condition[index] + amount, 0.0, 1.0)

func refresh_hole_condition_cache(sim_minute: float) -> void:
	var bucket: float = floor(sim_minute)
	if bucket != _hole_condition_minute or _hole_condition_revision != revision:
		_hole_condition_cache.clear()
		_hole_condition_minute = bucket
		_hole_condition_revision = revision

func hole_condition(hole: Dictionary) -> Dictionary:
	var hole_id: int = int(hole.get("id", -1))
	if _hole_condition_cache.has(hole_id):
		return _hole_condition_cache[hole_id]
	var result: Dictionary = _compute_hole_condition(hole)
	_hole_condition_cache[hole_id] = result
	return result

func _compute_hole_condition(hole: Dictionary) -> Dictionary:
	var green_sum: float = 0.0
	var green_count: int = 0
	for index in green_cells(hole):
		green_sum += condition[index]
		green_count += 1
	var corridor: PackedVector3Array = _hole_corridor_points(hole)
	var fairway_sum: float = 0.0
	var fairway_count: int = 0
	var tee_sum: float = 0.0
	var tee_count: int = 0
	var bunker_sum: float = 0.0
	var bunker_count: int = 0
	var half_width: float = 6.0
	var bunker_radius: float = 60.0
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for point in corridor:
		min_x = minf(min_x, point.x - bunker_radius)
		max_x = maxf(max_x, point.x + bunker_radius)
		min_z = minf(min_z, point.z - bunker_radius)
		max_z = maxf(max_z, point.z + bunker_radius)
	for segment_index in range(corridor.size() - 1):
		var a: Vector3 = corridor[segment_index]
		var b: Vector3 = corridor[segment_index + 1]
		var length: float = a.distance_to(b)
		var steps: int = maxi(1, ceili(length / STEP))
		for step in range(steps + 1):
			var t: float = float(step) / float(steps)
			var center: Vector3 = a.lerp(b, t)
			var cx: int = clampi(int(center.x / STEP), 0, 255)
			var cz: int = clampi(int(center.z / STEP), 0, 255)
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					var x: int = clampi(cx + dx, 0, 255)
					var z: int = clampi(cz + dz, 0, 255)
					var cell_center: Vector3 = Vector3((x + 0.5) * STEP, 0.0, (z + 0.5) * STEP)
					if cell_center.distance_to(center) > half_width:
						continue
					var index: int = z * CELLS + x
					var surface: int = int(surfaces[index])
					if surface == 1:
						fairway_sum += condition[index]
						fairway_count += 1
					elif surface == 3:
						tee_sum += condition[index]
						tee_count += 1
	var bx0: int = clampi(int(min_x / STEP), 0, 255)
	var bx1: int = clampi(int(max_x / STEP), 0, 255)
	var bz0: int = clampi(int(min_z / STEP), 0, 255)
	var bz1: int = clampi(int(max_z / STEP), 0, 255)
	for z in range(bz0, bz1 + 1):
		for x in range(bx0, bx1 + 1):
			var index: int = z * CELLS + x
			if int(surfaces[index]) != 4:
				continue
			var cell_center: Vector3 = Vector3((x + 0.5) * STEP, 0.0, (z + 0.5) * STEP)
			if _distance_to_corridor(cell_center, corridor) > bunker_radius:
				continue
			bunker_sum += condition[index]
			bunker_count += 1
	return {
		"green": green_sum / float(green_count) if green_count > 0 else 1.0,
		"fairway": fairway_sum / float(fairway_count) if fairway_count > 0 else 1.0,
		"tee": tee_sum / float(tee_count) if tee_count > 0 else 1.0,
		"bunkers": bunker_sum / float(bunker_count) if bunker_count > 0 else 1.0,
	}

func _hole_corridor_points(hole: Dictionary) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	points.append(Vector3(hole.get("tee", Vector3.ZERO)))
	var waypoints_value: Variant = hole.get("waypoints", [])
	if waypoints_value is Array:
		for waypoint_value in waypoints_value:
			points.append(Vector3(waypoint_value))
	points.append(Vector3(hole.get("cup", Vector3.ZERO)))
	return points

func _distance_to_corridor(point: Vector3, corridor: PackedVector3Array) -> float:
	var best: float = INF
	for index in range(corridor.size() - 1):
		best = minf(best, segment_distance(point, corridor[index], corridor[index + 1]))
	return best

func worst_cell_for_hole(hole: Dictionary) -> Vector3:
	var worst: float = 2.0
	var best_pos: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
	var corridor: PackedVector3Array = _hole_corridor_points(hole)
	var owned: Dictionary = {}
	for index in green_cells(hole):
		owned[index] = true
	var min_x: float = INF
	var max_x: float = -INF
	var min_z: float = INF
	var max_z: float = -INF
	for point in corridor:
		min_x = minf(min_x, point.x - 60.0)
		max_x = maxf(max_x, point.x + 60.0)
		min_z = minf(min_z, point.z - 60.0)
		max_z = maxf(max_z, point.z + 60.0)
	var x0: int = clampi(int(min_x / STEP), 0, 255)
	var x1: int = clampi(int(max_x / STEP), 0, 255)
	var z0: int = clampi(int(min_z / STEP), 0, 255)
	var z1: int = clampi(int(max_z / STEP), 0, 255)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var index: int = z * CELLS + x
			if not _maintained_surface(int(surfaces[index])):
				continue
			var cell_center: Vector3 = Vector3((x + 0.5) * STEP, 0.0, (z + 0.5) * STEP)
			var in_zone: bool = false
			if owned.has(index):
				in_zone = true
			elif int(surfaces[index]) == 4 and _distance_to_corridor(cell_center, corridor) <= 60.0:
				in_zone = true
			elif _distance_to_corridor(cell_center, corridor) <= 6.0:
				in_zone = true
			if not in_zone:
				continue
			var value: float = condition[index]
			if value < worst:
				worst = value
				best_pos = cell_center
	return best_pos

func worst_cell_near(origin: Vector3, radius: float) -> Vector3:
	var worst: float = 2.0
	var best_pos: Vector3 = origin
	var cx: int = clampi(int(origin.x / STEP), 0, 255)
	var cz: int = clampi(int(origin.z / STEP), 0, 255)
	var cells: int = ceili(radius / STEP)
	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var x: int = clampi(cx + dx, 0, 255)
			var z: int = clampi(cz + dz, 0, 255)
			var cell_center: Vector3 = Vector3((x + 0.5) * STEP, 0.0, (z + 0.5) * STEP)
			if cell_center.distance_to(origin) > radius:
				continue
			var index: int = z * CELLS + x
			if not _maintained_surface(int(surfaces[index])):
				continue
			var value: float = condition[index]
			if value < worst:
				worst = value
				best_pos = cell_center
	return best_pos

func overnight_decay(has_maintenance_shed: bool) -> void:
	for index in range(CELLS * CELLS):
		var surface: int = int(surfaces[index])
		if _maintained_surface(surface):
			condition[index] = clampf(condition[index] - 0.01, 0.0, 1.0)
		if has_maintenance_shed and surface == 2:
			condition[index] = clampf(condition[index] + 0.03, 0.0, 1.0)

func slope_at(p: Vector3) -> Vector2:
	return Vector2(height_at(p+Vector3(2,0,0))-height_at(p-Vector3(2,0,0)),height_at(p+Vector3(0,0,2))-height_at(p-Vector3(0,0,2))) / 4.0

func playable(p: Vector3) -> bool:
	return p.x >= 2 and p.z >= 2 and p.x < WIDTH-2 and p.z < WIDTH-2 and surface_at(p) != 5 and slope_at(p).length() < 1.2

func nearest_safe(p: Vector3) -> Vector3:
	var q = Vector3(clampf(p.x,8,1016),0,clampf(p.z,8,1016))
	if playable(q):
		q.y = height_at(q)
		return q
	for r in range(1, 100):
		for k in range(12):
			var a = k * TAU / 12.0
			var candidate = q + Vector3(cos(a),0,sin(a)) * r * 4
			if playable(candidate):
				candidate.y = height_at(candidate)
				return candidate
	return Vector3(entrance.x, height_at(entrance), entrance.z)

static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap = Vector2(p.x-a.x,p.z-a.z)
	var ab = Vector2(b.x-a.x,b.z-a.z)
	return (ap - ab * clampf(ap.dot(ab)/maxf(ab.length_squared(),0.001),0,1)).length()

func segment_blocked(a: Vector3, b: Vector3) -> bool:
	for obj in objects:
		if str(obj.kind) in TREE_KINDS and segment_distance(obj.pos,a,b) < 3.0:
			var length_ab = a.distance_to(b)
			if obj.pos.distance_to(a) < minf(length_ab, 48.0):
				return true
	return false

func beauty_at(p: Vector3) -> float:
	var key = Vector2i(int(p.x/8),int(p.z/8))
	if _beauty_cache.has(key): return _beauty_cache[key]
	var score = 0.0
	var sets: Dictionary = {}
	for obj in objects:
		var def = Catalog.find(obj.kind)
		if not def.has("beauty"): continue
		var dist = Vector2(p.x-obj.pos.x,p.z-obj.pos.z).length()
		if dist < float(def.get("influence",40)):
			score += float(def.beauty) * (1.0-dist/float(def.influence))
			if not sets.has(def.set): sets[def.set] = {}
			sets[def.set][obj.kind] = true
	var bonus = 1.0
	for set_id in sets:
		bonus += minf(0.6, maxf(0,sets[set_id].size()-1)*0.2)
	score = minf(100,score*minf(bonus,1.8))
	_beauty_cache[key] = score
	return score

func plan_brush(mode: String, p: Vector3, radius: float, strength: float, paint: int, single_node: bool = false) -> Dictionary:
	var nodes: Array = []
	var cells: Array = []
	var x0 = clampi(int((p.x-radius)/STEP),0,CELLS)
	var x1 = clampi(int((p.x+radius)/STEP)+1,0,CELLS)
	var z0 = clampi(int((p.z-radius)/STEP),0,CELLS)
	var z1 = clampi(int((p.z+radius)/STEP)+1,0,CELLS)
	var target = height_at(p)
	var water_y = target - 0.35
	if surface_at(p) == 5:
		water_y = water_levels[clampi(int(p.z/STEP),0,255)*256+clampi(int(p.x/STEP),0,255)]
	var cost = 0.0
	if mode != "paint":
		for z in range(z0,z1+1):
			for x in range(x0,x1+1):
				var d = Vector2(x*STEP-p.x,z*STEP-p.z).length()
				if single_node:
					if x != clampi(roundi(p.x/STEP),0,CELLS) or z != clampi(roundi(p.z/STEP),0,CELLS): continue
				elif d > radius: continue
				var index = z*NODES+x
				var old = heights[index]
				var falloff = 1.0 if single_node else 0.25+0.75*(1.0-d/maxf(radius,1))
				var value = old
				match mode:
					"raise": value += strength*falloff
					"lower": value -= strength*falloff
					"flatten": value = move_toward(old,target,strength*falloff)
					"smooth":
						var avg = 0.0
						for off in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
							avg += heights[clampi(z+off.y,0,CELLS)*NODES+clampi(x+off.x,0,CELLS)]
						value = move_toward(old,avg*0.25,strength*falloff)
				value = clampf(value,-18,65)
				if absf(value-old)>0.001:
					nodes.append([index,old,value])
					cost += absf(value-old)*8.0*float(cost_multipliers.get("raise", 1.0))
	else:
		var paint_costs: Array = [3, 9, 14, 12, 8, 18, 4]
		var paint_mult: float = 1.0
		if paint == 1:
			paint_mult = float(cost_multipliers.get("fairway", 1.0))
		elif paint == 5:
			paint_mult = float(cost_multipliers.get("water", 1.0))
		for z in range(z0,mini(z1+1,CELLS)):
			for x in range(x0,mini(x1+1,CELLS)):
				if Vector2((x+0.5)*STEP-p.x,(z+0.5)*STEP-p.z).length()>radius: continue
				var index = z*CELLS+x
				if surfaces[index] == paint: continue
				cells.append([index,int(surfaces[index]),paint,water_levels[index],water_y if paint==5 else -100.0])
				cost += float(paint_costs[paint]) * paint_mult
	return {"nodes":nodes,"cells":cells,"cost":ceilf(cost),"center":p,"radius":radius}

func apply_brush(command: Dictionary, reverse: bool = false) -> void:
	for item in command.nodes:
		heights[item[0]] = item[1] if reverse else item[2]
		var gx = int(item[0])%NODES
		var gz = int(item[0])/NODES
		for dz in [-1,0]:
			for dx in [-1,0]:
				changed_chunks[Vector2i(clampi((gx+dx)/16,0,15),clampi((gz+dz)/16,0,15))] = true
	for item in command.cells:
		surfaces[item[0]] = item[1] if reverse else item[2]
		water_levels[item[0]] = item[3] if reverse else item[4]
		if not reverse:
			condition[item[0]] = 1.0
		changed_chunks[Vector2i((int(item[0])%256)/16,(int(item[0])/256)/16)] = true
	touch()

func paint_disk(p: Vector3, radius: float, surface: int) -> void:
	apply_brush(plan_brush("paint",p,radius,1,surface))

func add_object(kind: String, p: Vector3, rotation_value: float = 0.0, end: Vector3 = Vector3.INF) -> Dictionary:
	var obj = {"id":uid(),"kind":kind,"pos":Vector3(p.x,height_at(p),p.z),"rotation":rotation_value,"condition":1.0,"cleanliness":1.0}
	if end != Vector3.INF: obj.end = Vector3(end.x,height_at(end),end.z)
	objects.append(obj)
	touch()
	return obj

func add_hole(tee: Vector3, cup: Vector3, par: int = 4) -> Dictionary:
	var hole = {"id":uid(),"name":"Hole %02d" % (holes.size()+1),"tee":Vector3(tee.x,height_at(tee),tee.z),"cup":Vector3(cup.x,height_at(cup),cup.z),"green_radius":14.0,"par":par,"open":true,"waypoints":[],"pins":[],"pin_index":0,"tees":[]}
	holes.append(hole)
	touch()
	return hole

static func effective_cup(hole: Dictionary) -> Vector3:
	var pins_value: Variant = hole.get("pins", [])
	if pins_value is Array and (pins_value as Array).size() > 0:
		var index: int = clampi(int(hole.get("pin_index", 0)), 0, (pins_value as Array).size() - 1)
		return Vector3((pins_value as Array)[index])
	return Vector3(hole.get("cup", Vector3.ZERO))

func _rebuild_green_caches() -> void:
	if _green_cache_revision == revision:
		return
	_green_owner_map.resize(CELLS * CELLS)
	_green_owner_map.fill(-1)
	_green_cells_cache.clear()
	for hole in holes:
		var hole_id: int = int(hole.get("id", -1))
		var cup: Vector3 = effective_cup(hole)
		var cells: PackedInt32Array = _flood_green_from_cup(cup)
		_green_cells_cache[hole_id] = cells
		for index in cells:
			_green_owner_map[index] = hole_id
	_green_cache_revision = revision

func _flood_green_from_cup(cup: Vector3) -> PackedInt32Array:
	var start: int = _cell_index(cup)
	if int(surfaces[start]) != 2:
		return PackedInt32Array()
	var result: PackedInt32Array = PackedInt32Array()
	var visited: Dictionary = {}
	var queue: Array[int] = [start]
	visited[start] = true
	while not queue.is_empty():
		var index: int = queue.pop_front()
		result.append(index)
		var x: int = index % CELLS
		var z: int = int(index / CELLS)
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + offset.x
			var nz: int = z + offset.y
			if nx < 0 or nz < 0 or nx >= CELLS or nz >= CELLS:
				continue
			var next: int = nz * CELLS + nx
			if visited.has(next) or int(surfaces[next]) != 2:
				continue
			visited[next] = true
			queue.append(next)
	return result

func green_cells(hole: Dictionary) -> PackedInt32Array:
	_rebuild_green_caches()
	var hole_id: int = int(hole.get("id", -1))
	if _green_cells_cache.has(hole_id):
		return (_green_cells_cache[hole_id] as PackedInt32Array).duplicate()
	return PackedInt32Array()

func green_owner(p: Vector3) -> int:
	_rebuild_green_caches()
	return _green_owner_map[_cell_index(p)]

func on_green(p: Vector3, hole: Dictionary) -> bool:
	return surface_at(p) == 2 and green_owner(p) == int(hole.get("id", -1))

func green_area(hole: Dictionary) -> float:
	return float(green_cells(hole).size()) * STEP * STEP

func green_slope_stats(hole: Dictionary) -> Dictionary:
	var cells: PackedInt32Array = green_cells(hole)
	if cells.is_empty():
		return {"mean": 0.0, "max": 0.0}
	var total: float = 0.0
	var peak: float = 0.0
	for index in cells:
		var center: Vector3 = Vector3((index % CELLS + 0.5) * STEP, 0.0, (int(index / CELLS) + 0.5) * STEP)
		var slope: float = slope_at(center).length()
		total += slope
		peak = maxf(peak, slope)
	return {"mean": total / float(cells.size()), "max": peak}

func disconnected_green_paint(hole: Dictionary) -> PackedInt32Array:
	var owned: Dictionary = {}
	for index in green_cells(hole):
		owned[index] = true
	var extras: PackedInt32Array = PackedInt32Array()
	var cup: Vector3 = effective_cup(hole)
	var radius: float = maxf(3.0, float(hole.get("green_radius", 14.0)))
	var x0: int = clampi(int((cup.x - radius) / STEP), 0, 255)
	var x1: int = clampi(int((cup.x + radius) / STEP), 0, 255)
	var z0: int = clampi(int((cup.z - radius) / STEP), 0, 255)
	var z1: int = clampi(int((cup.z + radius) / STEP), 0, 255)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var index: int = z * CELLS + x
			if int(surfaces[index]) != 2 or owned.has(index):
				continue
			extras.append(index)
	return extras

func bunkers() -> Array:
	_rebuild_green_caches()
	if _bunkers_cache_revision == revision:
		return _bunkers_cache.duplicate(true)
	var visited: Dictionary = {}
	var result: Array = []
	for index in range(CELLS * CELLS):
		if visited.has(index) or int(surfaces[index]) != 4:
			continue
		var cells: PackedInt32Array = PackedInt32Array()
		var queue: Array[int] = [index]
		visited[index] = true
		while not queue.is_empty():
			var current: int = queue.pop_front()
			cells.append(current)
			var x: int = current % CELLS
			var z: int = int(current / CELLS)
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + offset.x
				var nz: int = z + offset.y
				if nx < 0 or nz < 0 or nx >= CELLS or nz >= CELLS:
					continue
				var next: int = nz * CELLS + nx
				if visited.has(next) or int(surfaces[next]) != 4:
					continue
				visited[next] = true
				queue.append(next)
		var centre: Vector3 = Vector3.ZERO
		var rim_total: float = 0.0
		var rim_count: int = 0
		var depth_total: float = 0.0
		for cell_index in cells:
			var cx: int = int(cell_index) % CELLS
			var cz: int = int(cell_index) / CELLS
			centre += Vector3((cx + 0.5) * STEP, 0.0, (cz + 0.5) * STEP)
			var sand_height: float = heights[cz * NODES + cx]
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + offset.x
				var nz: int = cz + offset.y
				if nx < 0 or nz < 0 or nx >= CELLS or nz >= CELLS:
					continue
				var neighbor: int = nz * CELLS + nx
				if int(surfaces[neighbor]) == 4:
					continue
				var rim_height: float = heights[nz * NODES + nx]
				rim_total += rim_height
				rim_count += 1
				depth_total += maxf(0.0, rim_height - sand_height)
		centre /= float(maxi(1, cells.size()))
		var depth: float = depth_total / float(maxi(1, rim_count))
		result.append({
			"cells": cells,
			"centre": centre,
			"area": float(cells.size()) * STEP * STEP,
			"depth": depth,
		})
	_bunkers_cache = result.duplicate(true)
	_bunkers_cache_revision = revision
	return result.duplicate(true)

func bunker_at(p: Vector3) -> Dictionary:
	var index: int = _cell_index(p)
	for bunker in bunkers():
		var cells: PackedInt32Array = bunker.get("cells", PackedInt32Array())
		for cell_index in cells:
			if int(cell_index) == index:
				return bunker
	return {}

func zone_at(p: Vector3, hole: Dictionary = {}) -> String:
	if surface_at(p) == 5 or _distance_to_water(p) <= 3.0:
		return "penalty"
	for loop in _penalty_loops():
		if _point_in_polygon(Vector2(p.x, p.z), loop):
			return "penalty"
	if not hole.is_empty():
		for segment in _stake_segments("ob_stakes"):
			if _point_past_stake_boundary(p, segment, hole):
				return "ob"
	return ""

func _ensure_water_points() -> void:
	if _water_cache_revision == revision:
		return
	_water_points = PackedVector3Array()
	for z in range(CELLS):
		for x in range(CELLS):
			if int(surfaces[z * CELLS + x]) != 5:
				continue
			_water_points.append(Vector3((x + 0.5) * STEP, 0.0, (z + 0.5) * STEP))
	_water_cache_revision = revision

func _distance_to_water(p: Vector3) -> float:
	_ensure_water_points()
	if _water_points.is_empty():
		return 1.0e9
	var best: float = 1.0e9
	var px: float = p.x
	var pz: float = p.z
	for point in _water_points:
		var dx: float = px - point.x
		var dz: float = pz - point.z
		best = minf(best, sqrt(dx * dx + dz * dz) - STEP * 0.7)
	return best

func _stake_segments(kind: String) -> Array:
	var segments: Array = []
	for obj in objects:
		if str(obj.get("kind", "")) != kind or not obj.has("end"):
			continue
		segments.append({"a": Vector3(obj.pos), "b": Vector3(obj.end)})
	return segments

func _penalty_loops() -> Array:
	var segments: Array = _stake_segments("penalty_stakes")
	var loops: Array = []
	if segments.is_empty():
		return loops
	var used: Dictionary = {}
	for start_index in range(segments.size()):
		if used.has(start_index):
			continue
		var chain: Array = [segments[start_index]]
		used[start_index] = true
		var tail: Vector3 = chain.back().b
		var extended: bool = true
		while extended:
			extended = false
			for index in range(segments.size()):
				if used.has(index):
					continue
				var seg: Dictionary = segments[index]
				if tail.distance_to(seg.a) <= 6.0:
					chain.append(seg)
					used[index] = true
					tail = seg.b
					extended = true
					break
				if tail.distance_to(seg.b) <= 6.0:
					chain.append({"a": seg.b, "b": seg.a})
					used[index] = true
					tail = seg.a
					extended = true
					break
		if chain.size() >= 3 and chain.front().a.distance_to(tail) <= 8.0:
			var polygon: PackedVector2Array = PackedVector2Array()
			for seg in chain:
				polygon.append(Vector2(seg.a.x, seg.a.z))
			loops.append(polygon)
	return loops

func _point_past_stake_boundary(p: Vector3, segment: Dictionary, hole: Dictionary) -> bool:
	var a: Vector3 = Vector3(segment.get("a", Vector3.ZERO))
	var b: Vector3 = Vector3(segment.get("b", Vector3.ZERO))
	var ab: Vector2 = Vector2(b.x - a.x, b.z - a.z)
	if ab.length_squared() < 0.001:
		return false
	var ap: Vector2 = Vector2(p.x - a.x, p.z - a.z)
	# The stakes are a boundary: any point whose projection falls within the
	# stake span and on the far side from the hole corridor is out of bounds.
	var along: float = ap.dot(ab) / ab.length_squared()
	if along < -0.05 or along > 1.05:
		return false
	var corridor: PackedVector3Array = _hole_corridor_points(hole)
	var reference: Vector3 = corridor[0].lerp(corridor[corridor.size() - 1], 0.5)
	var side_ref: float = _line_side(a, b, reference)
	var side_point: float = _line_side(a, b, p)
	if absf(side_ref) < 0.001:
		return false
	return sign(side_point) != sign(side_ref)

static func _line_side(a: Vector3, b: Vector3, p: Vector3) -> float:
	return (b.x - a.x) * (p.z - a.z) - (b.z - a.z) * (p.x - a.x)

static func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	var inside: bool = false
	var j: int = polygon.size() - 1
	for i in range(polygon.size()):
		var pi: Vector2 = polygon[i]
		var pj: Vector2 = polygon[j]
		# PNPOLY: the crossing test guarantees a non-zero y span, so the raw
		# signed delta is safe (clamping it breaks downward edges).
		if ((pi.y > point.y) != (pj.y > point.y)) and (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside

func penalty_drop(entry: Vector3, landing: Vector3) -> Vector3:
	var direction: Vector3 = _flat_direction(entry, landing)
	var best: Vector3 = entry
	var best_distance: float = INF
	for step in range(1, 40):
		var candidate: Vector3 = entry + direction * float(step) * 2.0
		if not playable(candidate):
			break
		if zone_at(candidate) == "penalty":
			continue
		var distance: float = candidate.distance_to(landing)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	if best_distance < INF:
		best.y = height_at(best)
		return best
	return nearest_safe(entry)

static func _flat_direction(a: Vector3, b: Vector3) -> Vector3:
	var delta: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if delta.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return delta.normalized()

func plan_green_contour(p: Vector3, radius: float, strength: float, raise: bool) -> Dictionary:
	var hole_id: int = green_owner(p)
	var hole: Dictionary = {}
	for candidate in holes:
		if int(candidate.get("id", -1)) == hole_id:
			hole = candidate
			break
	var allowed: Dictionary = {}
	for index in green_cells(hole):
		allowed[index] = true
	var nodes: Array = []
	var x0: int = clampi(int((p.x - radius) / STEP), 0, CELLS - 1)
	var x1: int = clampi(int((p.x + radius) / STEP), 0, CELLS - 1)
	var z0: int = clampi(int((p.z - radius) / STEP), 0, CELLS - 1)
	var z1: int = clampi(int((p.z + radius) / STEP), 0, CELLS - 1)
	var cost: float = 0.0
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var cell_index: int = z * CELLS + x
			if not allowed.has(cell_index):
				continue
			var d: float = Vector2((x + 0.5) * STEP - p.x, (z + 0.5) * STEP - p.z).length()
			if d > radius:
				continue
			var node_index: int = z * NODES + x
			var old: float = heights[node_index]
			var falloff: float = 0.25 + 0.75 * (1.0 - d / maxf(radius, 1.0))
			var delta: float = strength * 0.25 * falloff
			var value: float = old + delta if raise else old - delta
			value = clampf(value, -18.0, 65.0)
			if absf(value - old) > 0.001:
				nodes.append([node_index, old, value])
				cost += absf(value - old) * 8.0
	return {"nodes": nodes, "cells": [], "cost": ceilf(cost), "center": p, "radius": radius}

func plan_bunker_shape(p: Vector3, radius: float, strength: float) -> Dictionary:
	var nodes: Array = []
	var x0: int = clampi(int((p.x - radius) / STEP), 0, CELLS - 1)
	var x1: int = clampi(int((p.x + radius) / STEP), 0, CELLS - 1)
	var z0: int = clampi(int((p.z - radius) / STEP), 0, CELLS - 1)
	var z1: int = clampi(int((p.z + radius) / STEP), 0, CELLS - 1)
	var cost: float = 0.0
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var cell_index: int = z * CELLS + x
			if int(surfaces[cell_index]) != 4:
				continue
			var d: float = Vector2((x + 0.5) * STEP - p.x, (z + 0.5) * STEP - p.z).length()
			if d > radius:
				continue
			var node_index: int = z * NODES + x
			var old: float = heights[node_index]
			var lip: float = 1.0 if d > radius * 0.82 else 0.35
			var depth: float = clampf(strength * lip, 0.3, 0.8)
			var value: float = clampf(old - depth, -18.0, 65.0)
			if absf(value - old) > 0.001:
				nodes.append([node_index, old, value])
				cost += absf(value - old) * 8.0
	return {"nodes": nodes, "cells": [], "cost": ceilf(cost), "center": p, "radius": radius}

func green_outline_points(hole: Dictionary) -> PackedVector3Array:
	var cells: PackedInt32Array = green_cells(hole)
	if cells.is_empty():
		return PackedVector3Array()
	var owned: Dictionary = {}
	for index in cells:
		owned[index] = true
	var edge: Dictionary = {}
	for index in cells:
		var x: int = int(index) % CELLS
		var z: int = int(index) / CELLS
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + offset.x
			var nz: int = z + offset.y
			var neighbor: int = nz * CELLS + nx
			if nx < 0 or nz < 0 or nx >= CELLS or nz >= CELLS or not owned.has(neighbor):
				var key: Vector2i = Vector2i(x * 2 + maxi(0, offset.x), z * 2 + maxi(0, offset.y))
				edge[key] = Vector3((x + 0.5 + offset.x * 0.5) * STEP, 0.0, (z + 0.5 + offset.y * 0.5) * STEP)
	var points: PackedVector3Array = PackedVector3Array()
	for key in edge.keys():
		var point: Vector3 = edge[key]
		point.y = height_at(point) + 0.35
		points.append(point)
	if points.size() >= 3:
		points.append(points[0])
	return points

func hole_valid(hole: Dictionary) -> String:
	if not playable(hole.tee): return "Tee is on water or steep terrain"
	if not playable(hole.cup): return "Cup is on water or steep terrain"
	if surface_at(hole.cup) != 2: return "Paint a green around the cup"
	if surface_at(hole.tee) != 3: return "Paint a tee surface under the tee"
	if hole.tee.distance_to(hole.cup) < 35: return "Hole must be at least 38 yards"
	var area: float = green_area(hole)
	if area < 250.0: return "Green is too small (%.0f m², need at least 250)" % area
	if area > 2500.0: return "Green is too large (%.0f m², maximum 2,500)" % area
	for other in holes:
		if int(other.get("id", -1)) == int(hole.get("id", -1)):
			continue
		var other_cup: Vector3 = effective_cup(other)
		for index in green_cells(hole):
			var center: Vector3 = Vector3((int(index) % CELLS + 0.5) * STEP, 0.0, (int(index) / CELLS + 0.5) * STEP)
			if center.distance_to(other_cup) <= STEP:
				return "Green touches another hole's cup"
	if route(hole.tee,hole.cup).is_empty(): return "Green cannot be reached on foot"
	if route(entrance,hole.tee).is_empty(): return "Tee cannot be reached from the resort entrance"
	return ""

func ready_holes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for hole in holes:
		if hole.open and hole_valid(hole).is_empty(): result.append(hole)
	return result

func _rebuild_navigation() -> void:
	_walk = AStarGrid2D.new()
	_cart = AStarGrid2D.new()
	for graph in [_walk,_cart]:
		graph.region = Rect2i(0,0,129,129)
		graph.cell_size = Vector2(8,8)
		graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		graph.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		graph.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		graph.update()
	_nav_y.resize(129*129)
	# Rasterize narrow path footprints once, rather than testing every path at every grid point.
	var paths: Dictionary = {}
	var obstacles: Dictionary = {}
	for obj in objects:
		if obj.has("end"):
			var n = maxi(1,ceili(obj.pos.distance_to(obj.end)/4.0))
			for i in range(n+1):
				var p = obj.pos.lerp(obj.end,i/float(n))
				var center = Vector2i(roundi(p.x/8),roundi(p.z/8))
				for dz in range(-1,2):
					for dx in range(-1,2):
						var id = center+Vector2i(dx,dz)
						if id.x<0 or id.y<0 or id.x>128 or id.y>128:continue
						if segment_distance(Vector3(id.x*8,0,id.y*8),obj.pos,obj.end)>6.0:continue
						var data = paths.get(id,{"cart":false,"weight":1.0,"bridge":false,"height":0.0})
						if obj.kind in ["path_paved","bridge_cart"]:data.cart=true;data.weight=0.7
						if obj.kind.begins_with("bridge"):
							data.bridge=true
							data.height=maxf(obj.pos.y,obj.end.y)+1.3
						paths[id]=data
		elif obj.kind in ["clubhouse","driving_range","restroom","snack_kiosk","cart_barn","maintenance_shed"]:
			var radius = float(Catalog.find(obj.kind).get("radius",8))*0.6
			for z in range(maxi(0,int((obj.pos.z-radius)/8)),mini(128,ceili((obj.pos.z+radius)/8))+1):
				for x in range(maxi(0,int((obj.pos.x-radius)/8)),mini(128,ceili((obj.pos.x+radius)/8))+1):
					if Vector2(x*8-obj.pos.x,z*8-obj.pos.z).length()<radius:obstacles[Vector2i(x,z)]=true
	for z in range(129):
		for x in range(129):
			var id = Vector2i(x,z)
			var p = Vector3(x*8,0,z*8)
			var h = height_at(p)
			var blocked = not playable(p) or obstacles.has(id)
			var has_cart = false
			var weight = 3.0
			if paths.has(id):
				var data = paths[id]
				if data.bridge:
					blocked = false
					h = data.height
				weight=data.weight
				has_cart=data.cart
			_nav_y[z*129+x] = h
			_walk.set_point_solid(id,blocked)
			_walk.set_point_weight_scale(id,weight)
			# Carts may leave the paved network at a penalty so buildings on
			# paths or fairway destinations never sever cart connectivity.
			_cart.set_point_solid(id,blocked)
			_cart.set_point_weight_scale(id,weight if has_cart else (2.5 if surface_at(p) in [1,2,3,4] else 6.0))
	_nav_revision = revision

func _nearest_nav(p: Vector3, graph: AStarGrid2D, max_radius: int = 10) -> Vector2i:
	var center = Vector2i(clampi(roundi(p.x/8),1,127),clampi(roundi(p.z/8),1,127))
	if not graph.is_point_solid(center): return center
	for r in range(1,max_radius+1):
		var best = Vector2i(-1,-1)
		var distance = INF
		for z in range(maxi(1,center.y-r),mini(127,center.y+r)+1):
			for x in range(maxi(1,center.x-r),mini(127,center.x+r)+1):
				if abs(x-center.x)!=r and abs(z-center.y)!=r: continue
				var id = Vector2i(x,z)
				if not graph.is_point_solid(id) and Vector2(x*8-p.x,z*8-p.z).length_squared()<distance:
					best = id
					distance = Vector2(x*8-p.x,z*8-p.z).length_squared()
		if best.x>=0: return best
	return Vector2i(-1,-1)

func route(a: Vector3, b: Vector3, cart: bool = false) -> PackedVector3Array:
	if _nav_revision != revision: _rebuild_navigation()
	var graph = _cart if cart else _walk
	var from = _nearest_nav(a,graph,20 if cart else 5)
	var to = _nearest_nav(b,graph,20 if cart else 5)
	if from.x<0 or to.x<0: return PackedVector3Array()
	var key = "%s:%s:%s" % [from,to,cart]
	if _route_cache.has(key): return _route_cache[key].duplicate()
	var ids = graph.get_id_path(from,to)
	var result = PackedVector3Array()
	for id in ids:
		result.append(Vector3(id.x*8,_nav_y[id.y*129+id.x],id.y*8))
	if not cart and not result.is_empty() and playable(b) and not graph.is_point_solid(Vector2i(clampi(roundi(b.x/8),0,128),clampi(roundi(b.z/8),0,128))):
		result.append(Vector3(b.x,height_at(b),b.z))
	if _route_cache.size()>1500: _route_cache.clear()
	_route_cache[key] = result
	return result.duplicate()

func path_valid(a: Vector3, b: Vector3, bridge: bool) -> String:
	if a.distance_to(b)<8: return "Choose endpoints at least 8 meters apart"
	if a.distance_to(b)>160 and bridge: return "Bridges may span at most 160 meters"
	if bridge:
		if not playable(a) or not playable(b): return "Both bridge ends must be on dry, walkable land"
		if absf(height_at(a)-height_at(b))>4: return "Flatten the shores to within 4 meters of one another"
	else:
		for i in range(int(a.distance_to(b)/4)+1):
			var p = a.lerp(b,float(i)/maxf(1,int(a.distance_to(b)/4)))
			if not playable(p): return "Use a bridge over water; paths need walkable terrain"
	return ""

func snapshot() -> Dictionary:
	return {
		"heights": heights.duplicate(), "surfaces": surfaces.duplicate(),
		"water_levels": water_levels.duplicate(), "condition": condition.duplicate(),
		"holes": holes.duplicate(true), "objects": objects.duplicate(true),
		"wear": course_wear(), "next_id": next_id,
		"entrance": entrance, "palette": palette, "cost_multipliers": cost_multipliers.duplicate(),
		"map_id": map_id, "rough_name": rough_name, "water_color": water_color,
	}

func restore(data: Dictionary) -> void:
	heights = data.heights.duplicate()
	surfaces = data.surfaces.duplicate()
	water_levels = data.water_levels.duplicate()
	if data.has("condition") and (data.condition as PackedFloat32Array).size() == CELLS * CELLS:
		condition = (data.condition as PackedFloat32Array).duplicate()
	else:
		condition.resize(CELLS * CELLS)
		condition.fill(1.0)
	holes.assign(data.holes)
	objects.assign(data.objects)
	next_id = data.next_id
	entrance = Vector3(data.get("entrance", DEFAULT_ENTRANCE))
	if data.has("palette") and (data.palette as PackedColorArray).size() == 7:
		palette = (data.palette as PackedColorArray).duplicate()
	else:
		palette = _default_palette()
	cost_multipliers = DEFAULT_COST_MULTIPLIERS.duplicate()
	if data.has("cost_multipliers") and data.cost_multipliers is Dictionary:
		for key in (data.cost_multipliers as Dictionary).keys():
			cost_multipliers[key] = float((data.cost_multipliers as Dictionary)[key])
	map_id = str(data.get("map_id", "cedar_house"))
	rough_name = str(data.get("rough_name", "Rough"))
	water_color = Color(data.get("water_color", Color("65aaa8")))
	_hole_condition_cache.clear()
	_hole_condition_revision = -1
	_hole_condition_minute = -1.0
	touch()

func starter_resort(full: bool = false) -> void:
	if not full and map_id == "cedar_house":
		_starter_lakeside()
		return
	var offset: Vector3 = entrance - DEFAULT_ENTRANCE
	add_object("clubhouse",Vector3(104,0,94)+offset,PI)
	add_object("restroom",Vector3(151,0,96)+offset,PI)
	add_object("snack_kiosk",Vector3(170,0,101)+offset,PI)
	add_object("cart_barn",Vector3(80,0,116)+offset,PI)
	add_object("maintenance_shed",Vector3(68,0,150)+offset,PI)
	add_object("driving_range",Vector3(221,0,86)+offset,PI)
	add_object("path_paved",Vector3(64,0,64)+offset,0,Vector3(64,0,180)+offset)
	add_object("path_paved",Vector3(64,0,120)+offset,0,Vector3(240,0,120)+offset)
	add_object("path_gravel",Vector3(104,0,112)+offset,0,Vector3(104,0,120)+offset)
	for pos in [Vector3(151,0,101),Vector3(170,0,105),Vector3(221,0,94),Vector3(80,0,121)]:
		add_object("path_gravel",pos+offset,0,Vector3(pos.x,0,120)+offset)
	for i in range(8):
		add_object("oak_tree" if i%2 else "pine_tree",Vector3(100+i*17,0,155+(i%2)*7)+offset,i*0.6)
	add_object("path_gravel",Vector3(140,0,120)+offset,0,Vector3(140,0,145)+offset)
	add_object("path_gravel",Vector3(140,0,145)+offset,0,Vector3(220,0,145)+offset)
	var count = 18 if full else 3
	for i in range(count):
		var col = i%6
		var row = i/6
		var base = Vector3(125+col*142,0,190+row*252) + offset
		var tee = base + Vector3(-12,0,8)
		var cup = base + Vector3(23,0,190)
		if i%2==1:
			tee = base+Vector3(23,0,190)
			cup = base+Vector3(-12,0,8)
		for step in range(22):
			var p = tee.lerp(cup,step/21.0)
			p.x += sin(step/21.0*PI)*18.0
			paint_disk(p,16.0+sin(step*0.4)*3,1)
		paint_disk(tee,8,3)
		paint_disk(cup,15,2)
		paint_disk(cup+Vector3(20,0,-12),8,4)
		paint_disk(base+Vector3(-29,0,106),18,5)
		var h = add_hole(tee,cup,3 if i%3==0 else 4)
		h.name = ["First Light","Willow Bend","The Homecoming"][i] if i<3 else "Hole %02d" % (i+1)
		var side_a = base+Vector3(-44,0,-20)
		var side_b = base+Vector3(-44,0,213)
		add_object("path_paved",side_a,0,side_b)
		add_object("path_gravel",side_a,0,tee)
		add_object("path_gravel",side_b,0,cup+Vector3(-16,0,0))
		add_object("path_paved",Vector3(64,0,170+row*252)+offset,0,side_a)
		for j in range(10):
			var p = base+Vector3(48+sin(j*7.0)*7,0,j*22)
			add_object("oak_tree" if j%3 else "pine_tree",p,j*0.7)
	for pair in [["flower_bed",Vector3(124,0,111)],["pergola",Vector3(195,0,144)],["fountain",Vector3(141,0,139)],["bench",Vector3(134,0,116)],["gazebo",Vector3(212,0,141)],["palm_tree",Vector3(184,0,128)],["topiary",Vector3(128,0,131)]]:
		add_object(pair[0],pair[1]+offset)
	if not full and map_id == "cedar_house":
		_plant_starter_woodland(offset)
	touch()


func _plant_starter_woodland(offset: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=18764
	var planted: Array[Vector3] = []
	for attempt in range(2600):
		if planted.size() >= 220: break
		var p: Vector3 = Vector3(rng.randf_range(36,560),0,rng.randf_range(65,550))+offset
		if surface_at(p) != 0: continue
		# Keep the arrival court, hitting corridors and path shoulders generous.
		if p.z < 168+offset.z and p.x < 245+offset.x: continue
		var clear: bool = true
		for dz in [-12,0,12]:
			for dx in [-12,0,12]:
				if surface_at(p+Vector3(dx,0,dz)) != 0: clear=false
		if not clear: continue
		for obj in objects:
			if obj.has("end"):
				if segment_distance(p,obj.pos,obj.end)<9: clear=false; break
			elif p.distance_to(obj.pos)<8:
				clear=false; break
		if not clear: continue
		planted.append(p)
		add_object("pine_tree" if rng.randf()<0.24 else "oak_tree",p,rng.randf()*TAU)

# A composed, playable starter landscape. Existing saves keep their own layouts;
# the large 18-hole stress fixture continues to use the regular starter grid.
func _starter_lakeside() -> void:
	var offset: Vector3 = entrance - DEFAULT_ENTRANCE
	# Lake with a gently indented shoreline, safely inside the three hole routings.
	for z in range(55,111):
		for x in range(53,109):
			var p: Vector3 = Vector3(x*4+2,0,z*4+2)+offset
			var q := Vector2((p.x-offset.x-323.0)/100.0,(p.z-offset.z-329.0)/84.0)
			var angle: float = atan2(q.y,q.x)
			if q.length() < 1.0+0.07*sin(angle*3.0)+0.035*cos(angle*5.0):
				var cell: int = _cell_index(p)
				surfaces[cell]=5
				water_levels[cell]=0.25
	# Give the banks a continuous basin. Visual water and the simulation share it.
	for z in range(52,114):
		for x in range(50,112):
			var p: Vector3 = Vector3(x*4,0,z*4)+offset
			var q := Vector2((p.x-offset.x-323.0)/112.0,(p.z-offset.z-329.0)/97.0)
			var index: int = clampi(roundi(p.z/4),0,256)*257+clampi(roundi(p.x/4),0,256)
			heights[index]=lerpf(-1.2,heights[index],smoothstep(0.7,1.13,q.length()))
	# Raise the mixed land/water nodes into a low, consistent shoreline lip.
	for z in range(54,113):
		for x in range(52,111):
			var gx: int = clampi(x+roundi(offset.x/4),1,255)
			var gz: int = clampi(z+roundi(offset.z/4),1,255)
			var wet: int = 0
			for dz in [-1,0]:
				for dx in [-1,0]:
					if surfaces[(gz+dz)*256+gx+dx]==5: wet+=1
			if wet>0 and wet<4: heights[gz*257+gx]=0.55
	var layouts: Array = [
		[Vector3(165,0,205),Vector3(368,0,188),Vector3(256,0,162),3,"First Light"],
		[Vector3(451,0,222),Vector3(469,0,436),Vector3(495,0,325),4,"Willow Bend"],
		[Vector3(402,0,465),Vector3(173,0,383),Vector3(270,0,455),4,"The Homecoming"],
	]
	for layout in layouts:
		var tee: Vector3 = layout[0]+offset
		var cup: Vector3 = layout[1]+offset
		var bend: Vector3 = layout[2]+offset
		for step in range(65):
			var t: float = step/64.0
			var p: Vector3 = tee*(1-t)*(1-t)+bend*2*t*(1-t)+cup*t*t
			paint_disk(p,20.0+7.0*sin(t*PI)+3.0*sin(t*TAU),1)
		paint_disk(tee,9.0,3)
		paint_disk(cup,16.0,2)
		var side: Vector3 = (cup-tee).normalized().cross(Vector3.UP)
		paint_disk(cup+side*22-Vector3(0,0,5),8.5,4)
		paint_disk(cup+side*25+Vector3(5,0,1),6.0,4)
		paint_disk(cup-side*21+Vector3(0,0,7),7.0,4)
		var hole: Dictionary = add_hole(tee,cup,int(layout[3]))
		hole.name=layout[4]
		hole.waypoints=[tee.lerp(bend,0.7),bend.lerp(cup,0.4)]
	# A real connected route, built from short segments so carts follow its curves.
	var route_points: Array[Vector3] = [
		Vector3(64,0,64),Vector3(105,0,108),Vector3(117,0,163),Vector3(124,0,222),
		Vector3(125,0,276),Vector3(130,0,328),Vector3(126,0,375),Vector3(158,0,430),
		Vector3(205,0,476),Vector3(264,0,495),Vector3(327,0,508),Vector3(389,0,503),
		Vector3(447,0,491),Vector3(512,0,465),Vector3(537,0,403),Vector3(542,0,334),
		Vector3(527,0,266),Vector3(489,0,197),Vector3(430,0,151),Vector3(366,0,137),
		Vector3(299,0,119),Vector3(236,0,125),Vector3(169,0,136),Vector3(117,0,163),
	]
	for i in range(route_points.size()-1):
		add_object("path_paved",route_points[i]+offset,0,route_points[i+1]+offset)
	for hole in holes:
		for target in [hole.tee,hole.cup]:
			var nearest: Vector3 = route_points[0]+offset
			for point in route_points:
				if (point+offset).distance_to(target)<nearest.distance_to(target): nearest=point+offset
			add_object("path_gravel",nearest,0,target)
	for z in range(55,72):
		var left: int = 256
		var right: int = -1
		for x in range(53,109):
			if surface_at(Vector3(x*4+2,0,z*4+2)+offset)==5:
				left=mini(left,x)
				right=maxi(right,x)
		if right<left: continue
		var a: Vector3 = Vector3(left*4-5,0,z*4+2)+offset
		var b: Vector3 = Vector3(right*4+9,0,z*4+2)+offset
		add_object("bridge_walk",a,0,b)
		add_object("path_gravel",a,0,Vector3(a.x,0,215+offset.z))
		add_object("path_gravel",b,0,Vector3(b.x,0,215+offset.z))
		break
	for item in [["clubhouse",Vector3(171,0,290),-PI/2],["restroom",Vector3(153,0,252),PI/2],["snack_kiosk",Vector3(164,0,337),PI/2],["cart_barn",Vector3(103,0,292),-PI/2],["maintenance_shed",Vector3(92,0,333),-PI/2],["driving_range",Vector3(156,0,100),PI]]:
		var p: Vector3 = item[1]+offset
		# Flatten just the foundation, preserving the surrounding rolling land.
		apply_brush(plan_brush("flatten",p,9,8,0))
		add_object(item[0],p,item[2])
		var join: Vector3 = Vector3(126,0,p.z-offset.z)+offset
		add_object("path_gravel",join,0,p)
	# Terrace planting and lakeshore details are selectable standard scenery.
	for item in [["pergola",Vector3(190,0,307)],["flower_bed",Vector3(168,0,278)],["flower_bed",Vector3(176,0,303)],["fountain",Vector3(149,0,307)],["bench",Vector3(196,0,298)],["gazebo",Vector3(213,0,374)],["palm_tree",Vector3(197,0,275)],["palm_tree",Vector3(184,0,322)],["topiary",Vector3(157,0,279)]]:
		add_object(item[0],item[1]+offset)
	_plant_starter_woodland(offset)
	touch()
