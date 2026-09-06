class_name TerrainModel
extends RefCounted

const CELLS = 256
const STEP = 4.0
const WIDTH = 1024.0
const NODES = 257
const SURFACE_NAMES = ["Rough", "Fairway", "Green", "Tee", "Sand", "Water", "Garden soil"]
const SURFACE_COLORS = [Color("6f9250"), Color("8caf59"), Color("b4ca74"), Color("95b568"), Color("e6cf96"), Color("65aaa8"), Color("b18b60")]
var heights = PackedFloat32Array()
var surfaces = PackedByteArray()
var water_levels = PackedFloat32Array()
var holes: Array[Dictionary] = []
var objects: Array[Dictionary] = []
var wear = 0.0
var revision = 0
var next_id = 1
var changed_chunks: Dictionary = {}
var _walk: AStarGrid2D
var _cart: AStarGrid2D
var _nav_revision = -1
var _nav_y = PackedFloat32Array()
var _route_cache: Dictionary = {}
var _beauty_cache: Dictionary = {}

func _init() -> void:
	heights.resize(NODES * NODES)
	surfaces.resize(CELLS * CELLS)
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

func height_at(p: Vector3) -> float:
	var gx = clampf(p.x / STEP, 0, CELLS - 0.0001)
	var gz = clampf(p.z / STEP, 0, CELLS - 0.0001)
	var x = int(gx)
	var z = int(gz)
	return lerpf(lerpf(heights[z*NODES+x], heights[z*NODES+x+1], gx-x), lerpf(heights[(z+1)*NODES+x], heights[(z+1)*NODES+x+1], gx-x), gz-z)

func surface_at(p: Vector3) -> int:
	return surfaces[clampi(int(p.z / STEP),0,255)*CELLS + clampi(int(p.x / STEP),0,255)]

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
	return Vector3(64,height_at(Vector3(64,0,64)),64)

static func segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap = Vector2(p.x-a.x,p.z-a.z)
	var ab = Vector2(b.x-a.x,b.z-a.z)
	return (ap - ab * clampf(ap.dot(ab)/maxf(ab.length_squared(),0.001),0,1)).length()

func segment_blocked(a: Vector3, b: Vector3) -> bool:
	for obj in objects:
		if obj.kind in ["oak_tree","pine_tree","palm_tree"] and segment_distance(obj.pos,a,b) < 3.0:
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
					cost += absf(value-old)*8.0
	else:
		for z in range(z0,mini(z1+1,CELLS)):
			for x in range(x0,mini(x1+1,CELLS)):
				if Vector2((x+0.5)*STEP-p.x,(z+0.5)*STEP-p.z).length()>radius: continue
				var index = z*CELLS+x
				if surfaces[index] == paint: continue
				cells.append([index,int(surfaces[index]),paint,water_levels[index],water_y if paint==5 else -100.0])
				cost += [3,9,14,12,8,18,4][paint]
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
	var hole = {"id":uid(),"name":"Hole %02d" % (holes.size()+1),"tee":Vector3(tee.x,height_at(tee),tee.z),"cup":Vector3(cup.x,height_at(cup),cup.z),"green_radius":14.0,"par":par,"open":true,"waypoints":[]}
	holes.append(hole)
	touch()
	return hole

func hole_valid(hole: Dictionary) -> String:
	if not playable(hole.tee): return "Tee is on water or steep terrain"
	if not playable(hole.cup): return "Cup is on water or steep terrain"
	if surface_at(hole.cup) != 2: return "Paint a green around the cup"
	if surface_at(hole.tee) != 3: return "Paint a tee surface under the tee"
	if hole.tee.distance_to(hole.cup) < 35: return "Hole must be at least 38 yards"
	if route(hole.tee,hole.cup).is_empty(): return "Green cannot be reached on foot"
	if route(Vector3(64,0,64),hole.tee).is_empty(): return "Tee cannot be reached from the resort entrance"
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
			_cart.set_point_solid(id,blocked or not has_cart)
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
	return {"heights":heights.duplicate(),"surfaces":surfaces.duplicate(),"water_levels":water_levels.duplicate(),"holes":holes.duplicate(true),"objects":objects.duplicate(true),"wear":wear,"next_id":next_id}

func restore(data: Dictionary) -> void:
	heights = data.heights.duplicate()
	surfaces = data.surfaces.duplicate()
	water_levels = data.water_levels.duplicate()
	holes.assign(data.holes)
	objects.assign(data.objects)
	wear = data.get("wear",0.0)
	next_id = data.next_id
	touch()

func starter_resort(full: bool = false) -> void:
	add_object("clubhouse",Vector3(104,0,94),PI)
	add_object("restroom",Vector3(151,0,96),PI)
	add_object("snack_kiosk",Vector3(170,0,101),PI)
	add_object("cart_barn",Vector3(80,0,116),PI)
	add_object("maintenance_shed",Vector3(68,0,150),PI)
	add_object("driving_range",Vector3(221,0,86),PI)
	add_object("path_paved",Vector3(64,0,64),0,Vector3(64,0,180))
	add_object("path_paved",Vector3(64,0,120),0,Vector3(240,0,120))
	add_object("path_gravel",Vector3(104,0,112),0,Vector3(104,0,120))
	for pos in [Vector3(151,0,101),Vector3(170,0,105),Vector3(221,0,94),Vector3(80,0,121)]:
		add_object("path_gravel",pos,0,Vector3(pos.x,0,120))
	for i in range(8):
		add_object("oak_tree" if i%2 else "pine_tree",Vector3(100+i*17,0,155+(i%2)*7),i*0.6)
	add_object("path_gravel",Vector3(140,0,120),0,Vector3(140,0,145))
	add_object("path_gravel",Vector3(140,0,145),0,Vector3(220,0,145))
	var count = 18 if full else 3
	for i in range(count):
		var col = i%6
		var row = i/6
		var base = Vector3(125+col*142,0,190+row*252)
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
		add_object("path_paved",Vector3(64,0,170+row*252),0,side_a)
		for j in range(10):
			var p = base+Vector3(48+sin(j*7.0)*7,0,j*22)
			add_object("oak_tree" if j%3 else "pine_tree",p,j*0.7)
	for pair in [["flower_bed",Vector3(124,0,111)],["pergola",Vector3(195,0,144)],["fountain",Vector3(141,0,139)],["bench",Vector3(134,0,116)],["gazebo",Vector3(212,0,141)],["palm_tree",Vector3(184,0,128)],["topiary",Vector3(128,0,131)]]:
		add_object(pair[0],pair[1])
	touch()
