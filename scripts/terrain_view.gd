class_name TerrainView
extends Node3D

var model: TerrainModel
var chunks: Dictionary = {}
var object_nodes: Dictionary = {}
var hole_nodes: Dictionary = {}
var ground_material: ShaderMaterial
var water_material: ShaderMaterial
var object_root = Node3D.new()
var hole_root = Node3D.new()
var instance_root = Node3D.new()
var overlay_mesh: MeshInstance3D
var analytics_source: AnalyticsGrid
var overlay = "none"
var _horizon_material: ShaderMaterial
var _turf_texture: ImageTexture
var _detail_texture: ImageTexture
var _graphics: GraphicsSettings = GraphicsSettings.defaults()

# Two small control textures keep the editable four-metre simulation grid while
# drawing continuous contours. Updating them also updates neighbouring chunks.
func _update_surface_maps() -> void:
	var turf := PackedByteArray()
	var detail := PackedByteArray()
	turf.resize(256 * 256 * 4)
	detail.resize(256 * 256 * 4)
	for i in range(model.surfaces.size()):
		var kind: int = model.surfaces[i]
		if kind < 4: turf[i * 4 + kind] = 255
		else: detail[i * 4 + kind - 4] = 255
	var turf_image := Image.create_from_data(256,256,false,Image.FORMAT_RGBA8,turf)
	var detail_image := Image.create_from_data(256,256,false,Image.FORMAT_RGBA8,detail)
	if _turf_texture == null:
		_turf_texture = ImageTexture.create_from_image(turf_image)
		_detail_texture = ImageTexture.create_from_image(detail_image)
		ground_material.set_shader_parameter("turf_map",_turf_texture)
		ground_material.set_shader_parameter("detail_map",_detail_texture)
		water_material.set_shader_parameter("detail_map",_detail_texture)
	else:
		_turf_texture.update(turf_image)
		_detail_texture.update(detail_image)


const CHUNK_OVERLAYS: Array[String] = ["beauty", "access", "elevation", "wear"]
const HEAT_OVERLAYS: Array[String] = ["traffic", "cart_traffic", "waiting"]

func setup(data: TerrainModel) -> void:
	model = data
	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/resort_ground.gdshader")
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/resort_water.gdshader")
	_update_surface_maps()
	for pair in [["rough_color",0],["fairway_color",1],["green_color",2],["tee_color",3],["sand_color",4],["soil_color",6]]:
		ground_material.set_shader_parameter(pair[0], model.palette[pair[1]])
	_apply_water_color(data.water_color)
	add_child(object_root)
	add_child(hole_root)
	add_child(instance_root)
	overlay_mesh = MeshInstance3D.new()
	overlay_mesh.name = "AnalyticsOverlay"
	add_child(overlay_mesh)
	overlay_mesh.visible = false
	for z in range(16):
		for x in range(16): rebuild_chunk(Vector2i(x,z))
	model.changed_chunks.clear()
	var base = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1024,25,1024)
	base.mesh = box
	base.position = Vector3(512,-31,512)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("9d977c")
	base.material_override = mat
	add_child(base)
	_build_horizon()
	sync_objects()
	sync_holes()

func apply_graphics_settings(settings: GraphicsSettings) -> void:
	_graphics = settings.duplicate_settings()
	_rebuild_scenery_instances()

func _foliage_keep(object_id: int) -> bool:
	if _graphics.foliage_density >= 0.999:
		return true
	var step: int = maxi(1, int(round(1.0 / clampf(_graphics.foliage_density, 0.2, 1.0))))
	return object_id % step == 0

func set_grid(value: bool) -> void:
	ground_material.set_shader_parameter("show_grid",value)
	water_material.set_shader_parameter("show_grid",value)

func _apply_water_color(color: Color) -> void:
	if water_material != null:
		water_material.set_shader_parameter("water_tint", Vector3(color.r, color.g, color.b))

func set_season(index: int) -> void:
	# Per-season ground tint: spring fresh, summer warm, fall amber, winter snow-dusted.
	var tints: Array[Vector3] = [
		Vector3(1.0, 1.03, 0.97), Vector3(1.02, 1.0, 0.9),
		Vector3(1.08, 0.95, 0.78), Vector3(1.15, 1.2, 1.3),
	]
	ground_material.set_shader_parameter("season_tint", tints[clampi(index, 0, 3)])
	if _horizon_material != null: _horizon_material.set_shader_parameter("season_tint",tints[clampi(index,0,3)])

func set_overlay(value: String) -> void:
	var previous: String = overlay
	overlay = value
	ground_material.set_shader_parameter("analysis",value in CHUNK_OVERLAYS)
	if previous in CHUNK_OVERLAYS or value in CHUNK_OVERLAYS or previous == "none" or value == "none":
		for key in chunks:
			rebuild_chunk(key)
	if value not in HEAT_OVERLAYS:
		_clear_overlay_mesh()

func rebuild_all_chunks() -> void:
	_update_surface_maps()
	for key in chunks:
		rebuild_chunk(key)

func refresh_overlay(sim) -> void:
	if overlay not in HEAT_OVERLAYS or sim == null:
		_clear_overlay_mesh()
		return
	analytics_source = sim.analytics
	var layer: String = overlay
	var grid: AnalyticsGrid = sim.analytics
	var peak: float = maxf(grid.max_value(layer), 0.0001)
	var verts: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	for z in range(AnalyticsGrid.SIZE):
		for x in range(AnalyticsGrid.SIZE):
			var x0: float = float(x) * AnalyticsGrid.CELL_METERS
			var z0: float = float(z) * AnalyticsGrid.CELL_METERS
			var x1: float = x0 + AnalyticsGrid.CELL_METERS
			var z1: float = z0 + AnalyticsGrid.CELL_METERS
			var sample: Vector3 = Vector3((x0 + x1) * 0.5, 0.0, (z0 + z1) * 0.5)
			var amount: float = grid.value(layer, sample) / peak
			var tint: Color = _heat_color(layer, amount)
			var corners: Array[Vector3] = [
				Vector3(x0, 0.0, z0), Vector3(x1, 0.0, z0), Vector3(x0, 0.0, z1),
				Vector3(x1, 0.0, z0), Vector3(x1, 0.0, z1), Vector3(x0, 0.0, z1),
			]
			for corner in corners:
				var draped: Vector3 = corner
				draped.y = model.height_at(corner) + 0.15
				verts.append(draped)
				colors.append(tint)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	overlay_mesh.mesh = mesh
	if overlay_mesh.material_override == null:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		overlay_mesh.material_override = mat
	overlay_mesh.visible = true

func _clear_overlay_mesh() -> void:
	if overlay_mesh == null:
		return
	overlay_mesh.visible = false
	overlay_mesh.mesh = null

func _heat_color(layer: String, amount: float) -> Color:
	var t: float = clampf(amount, 0.0, 1.0)
	match layer:
		"traffic":
			return Color(1.0, 0.55, 0.18, 0.0).lerp(Color(1.0, 0.45, 0.08, 0.72), t)
		"cart_traffic":
			return Color(0.35, 0.65, 1.0, 0.0).lerp(Color(0.15, 0.45, 0.95, 0.72), t)
		"waiting":
			return Color(1.0, 0.92, 0.35, 0.0).lerp(Color(0.92, 0.18, 0.12, 0.78), t)
	return Color(1, 1, 1, 0)

func rebuild_dirty() -> void:
	if model.changed_chunks.is_empty(): return
	_update_surface_maps()
	# Water geometry extends one cell past its mask; rebuild bordering chunks too.
	var dirty: Dictionary = {}
	for key in model.changed_chunks:
		for dz in range(-1,2):
			for dx in range(-1,2):
				var neighbour: Vector2i = key + Vector2i(dx,dz)
				if chunks.has(neighbour): dirty[neighbour] = true
	for key in dirty: rebuild_chunk(key)
	model.changed_chunks.clear()

func rebuild_chunk(key: Vector2i) -> void:
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var water_verts = PackedVector3Array()
	var water_normals = PackedVector3Array()
	for z in range(key.y*16,key.y*16+16):
		for x in range(key.x*16,key.x*16+16):
			var type = model.surfaces[z*256+x]
			var col = model.palette[type] if type < model.palette.size() else TerrainModel.SURFACE_COLORS[type]
			var center = Vector3(x*4+2,0,z*4+2)
			col = col.lightened(float((x*13+z*7)%11)/1200.0)
			if type == 1 and x%4 <2: col = col.lightened(0.025)
			if overlay == "beauty": col = Color("ad704e").lerp(Color("a2d88a"),model.beauty_at(center)/100.0)
			elif overlay == "access": col = Color("b07857") if not model.playable(center) else Color("8bae72")
			elif overlay == "elevation":
				var height: float = model.height_at(center)
				var step: float = floor(clampf((height + 4.0) / 20.0, 0.0, 1.0) * 5.0) / 5.0
				col = Color("5a5a5a").lerp(Color("dcdcdc"), step)
			elif overlay == "wear":
				var wear_mix: float = 0.0
				if model.has_method("condition_at"):
					wear_mix = clampf(1.0 - model.condition_at(center), 0.0, 1.0)
				else:
					var traffic_amount: float = 0.0
					if analytics_source != null:
						traffic_amount = analytics_source.value("traffic", center)
					wear_mix = clampf(model.wear * traffic_amount / maxf(analytics_source.max_value("traffic") if analytics_source != null else 1.0, 0.0001), 0.0, 1.0)
				col = Color("8bae72").lerp(Color("ad704e"), wear_mix)
			var points: Array[Vector3] = []
			for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				points.append(Vector3((x+off.x)*4,model.heights[(z+off.y)*257+x+off.x],(z+off.y)*4))
			var water_height: float = -100.0
			var water_count: int = 0
			var water_sum: float = 0.0
			for dz in range(-1,2):
				for dx in range(-1,2):
					var index: int = clampi(z+dz,0,255)*256+clampi(x+dx,0,255)
					if model.surfaces[index] == 5:
						water_sum += model.water_levels[index]
						water_count += 1
			if water_count > 0: water_height = water_sum / water_count
			for i in [0,1,2,1,3,2]:
				var p: Vector3 = points[i]
				verts.append(p)
				var slope: Vector2 = model.slope_at(p)
				normals.append(Vector3(-slope.x,1,-slope.y).normalized())
				colors.append(col)
				if water_count > 0:
					p.y = water_height + 0.04
					water_verts.append(p)
					water_normals.append(Vector3.UP)

	var root: Node3D
	if chunks.has(key):
		root = chunks[key]
		for child in root.get_children(): child.free()
	else:
		root = Node3D.new()
		add_child(root)
		chunks[key] = root
	if not verts.is_empty():
		var ground: MeshInstance3D = _mesh(verts,normals,colors,ground_material)
		# The heightfield receives building/tree shadows. Disabling its own shadow
		# pass avoids grazing-angle depth acne and hundreds of redundant draws.
		ground.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ground)
	if not water_verts.is_empty():
		root.add_child(_mesh(water_verts,water_normals,PackedColorArray(),water_material))
		root.add_child(_shore_details(key))

func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, material: Material) -> MeshInstance3D:
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not colors.is_empty(): arrays[Mesh.ARRAY_COLOR] = colors
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	return node

static func line_mesh(points: PackedVector3Array, color: Color, width: float = 0.6) -> MeshInstance3D:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(points.size()-1):
		var a = points[i]
		var b = points[i+1]
		var side = (b-a).cross(Vector3.UP).normalized()*width*0.5
		for p in [a-side,a+side,b-side,a+side,b+side,b-side]: mesh.surface_add_vertex(p)
	mesh.surface_end()
	var node = MeshInstance3D.new()
	node.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	return node

func sync_objects() -> void:
	var live: Dictionary = {}
	for obj in model.objects:
		live[obj.id] = true
		if object_nodes.has(obj.id):
			var old = object_nodes[obj.id]
			if old.get_meta("record",{}) == obj: continue
			old.free()
		var node: Node3D
		if obj.has("end"):
			if obj.kind in ["ob_stakes", "penalty_stakes"]:
				node = _stake_visual(obj)
			else:
				node = _path_visual(obj)
		else:
			var level: int = maxi(1, int(obj.get("level", 1))) - 1
			node = AssetFactory.build(obj.kind, int(obj.id) % 4 if Catalog.find(obj.kind).has("beauty") else level)
			node.position = obj.pos
			node.position.y = model.height_at(obj.pos)
			node.rotation.y = obj.rotation
		node.set_meta("record",obj.duplicate(true))
		object_root.add_child(node)
		object_nodes[obj.id] = node
	for id in object_nodes.keys():
		if not live.has(id):
			object_nodes[id].free()
			object_nodes.erase(id)
	_rebuild_scenery_instances()

func _rebuild_scenery_instances() -> void:
	for child in instance_root.get_children():child.free()
	var batches: Dictionary = {}
	for obj in model.objects:
		if not Catalog.find(obj.kind).has("beauty"):continue
		if not _foliage_keep(int(obj.id)): continue
		var source=object_nodes.get(obj.id)
		if source==null:continue
		source.visible=false
		var region=Vector2i(int(obj.pos.x/128),int(obj.pos.z/128))
		_collect_instances(source,Transform3D.IDENTITY,str(region),batches)
	for batch in batches.values():
		var multimesh=MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=batch.mesh
		multimesh.instance_count=batch.transforms.size()
		for i in range(batch.transforms.size()):multimesh.set_instance_transform(i,batch.transforms[i])
		var instance=MultiMeshInstance3D.new()
		instance.multimesh=multimesh
		instance.lod_bias=_graphics.foliage_lod_bias
		instance.visibility_range_end=_graphics.foliage_view_distance
		instance.material_override=batch.material
		if batch.material == AssetFactory._foliage():
			instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance_root.add_child(instance)
	if _graphics.tree_shadow_volumes:
		_tree_shadow_instances()

func _collect_instances(node: Node3D, parent_transform: Transform3D, region: String, batches: Dictionary) -> void:
	var transform=parent_transform*node.transform
	if node is MeshInstance3D and node.mesh!=null:
		var material=node.material_override
		var key=region+":"+str(node.mesh.get_instance_id())+":"+str(material.get_instance_id() if material else 0)
		if not batches.has(key):batches[key]={"mesh":node.mesh,"material":material,"transforms":[]}
		batches[key].transforms.append(transform)
	for child in node.get_children():
		if child is Node3D:_collect_instances(child,transform,region,batches)


func _path_visual(obj: Dictionary) -> Node3D:
	var root = Node3D.new()
	var length_path = Vector2(obj.end.x-obj.pos.x,obj.end.z-obj.pos.z).length()
	var bridge = obj.kind.begins_with("bridge")
	var width = 5.6 if obj.kind in ["path_paved","bridge_cart"] else 3.0
	var points = PackedVector3Array()
	var n = maxi(2,ceili(length_path/3))
	var deck = maxf(obj.pos.y,obj.end.y)+1.3
	for i in range(n+1):
		var p = obj.pos.lerp(obj.end,i/float(n))
		p.y = deck if bridge else model.height_at(p)+0.09
		points.append(p)
	root.add_child(_path_ribbon(points,width+0.55,Color("9d916e"),0.0,not bridge))
	root.add_child(_path_ribbon(points,width,Color("c3b589") if obj.kind=="path_paved" else Color("c9b083"),0.025,not bridge))
	if bridge:
		var direction = (obj.end-obj.pos).normalized()
		var side = direction.cross(Vector3.UP).normalized()*(width*0.5)
		for sign_value in [-1,1]:
			var rails = PackedVector3Array()
			for p in points: rails.append(p+side*sign_value+Vector3.UP*1.5)
			root.add_child(line_mesh(rails,Color("755942"),0.3))
		for i in range(0,n+1,3):
			for sign_value in [-1,1]:
				var p = points[i]+side*sign_value
				var post = MeshInstance3D.new()
				var box = BoxMesh.new()
				var ground = model.height_at(p)-0.5
				box.size = Vector3(0.35,deck-ground+1.7,0.35)
				post.mesh = box
				post.position = Vector3(p.x,ground+box.size.y*0.5,p.z)
				var mat = StandardMaterial3D.new()
				mat.albedo_color=Color("8d7051")
				post.material_override=mat
				root.add_child(post)
	return root

func _stake_visual(obj: Dictionary) -> Node3D:
	var root = Node3D.new()
	var points = PackedVector3Array()
	var n = maxi(2, ceili(obj.pos.distance_to(obj.end) / 3.0))
	for i in range(n + 1):
		var p = obj.pos.lerp(obj.end, i / float(n))
		p.y = model.height_at(p) + 0.09
		points.append(p)
	var color = Color.WHITE if obj.kind == "ob_stakes" else Color("d25555")
	root.add_child(line_mesh(points, color, 0.35))
	for i in range(0, n + 1, 2):
		var p = points[i]
		var post = AssetFactory.build("stake", 0 if obj.kind == "ob_stakes" else 1)
		post.position = p
		post.position.y = model.height_at(p)
		root.add_child(post)
	return root

func sync_holes() -> void:
	for child in hole_root.get_children(): child.free()
	hole_nodes.clear()
	for i in range(model.holes.size()):
		var hole = model.holes[i]
		var root = Node3D.new()
		hole_root.add_child(root)
		var flag = AssetFactory.build("flag",i)
		var cup_pos = TerrainModel.effective_cup(hole)
		flag.position = cup_pos
		flag.position.y = model.height_at(cup_pos)+0.1
		flag.scale = Vector3.ONE*1.4
		root.add_child(flag)
		var label = Label3D.new()
		label.text = "%02d" % (i+1)
		label.font_size = 64
		label.pixel_size = 0.045
		label.position = flag.position+Vector3(0,9,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("fff5cf") if hole.open else Color("bdaaa1")
		label.outline_modulate=Color("26483c")
		label.no_depth_test=false
		label.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(label)
		for side in [-1,1]:
			var tee := MeshInstance3D.new()
			var marker := SphereMesh.new()
			marker.radius=0.28
			marker.height=0.32
			tee.mesh=marker
			tee.position=hole.tee+Vector3(side*2.3,0.16,0)
			tee.material_override=AssetFactory._material(Color("e8dfbd"))
			root.add_child(tee)
		hole_nodes[hole.id]=root


func _path_ribbon(points: PackedVector3Array, width: float, color: Color, lift: float, drape: bool = true) -> MeshInstance3D:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var side: Vector3 = (points[-1]-points[0]).cross(Vector3.UP).normalized()*width*0.5
	for i in range(points.size()-1):
		for p in [points[i]+side,points[i]-side,points[i+1]+side,points[i]-side,points[i+1]-side,points[i+1]+side]:
			vertices.append(Vector3(p.x,model.height_at(p)+0.14+lift,p.z) if drape else p+Vector3.UP*lift)
			normals.append(Vector3.UP)
	# Round caps hide seams at the joins between independently editable segments.
	for end in [points[0],points[-1]]:
		for i in range(20):
			for p in [end,end+Vector3(cos(i*TAU/20),0,sin(i*TAU/20))*width*0.5,end+Vector3(cos((i+1)*TAU/20),0,sin((i+1)*TAU/20))*width*0.5]:
				vertices.append(Vector3(p.x,model.height_at(p)+0.14+lift,p.z) if drape else p+Vector3.UP*lift)
				normals.append(Vector3.UP)
	var material := ShaderMaterial.new()
	material.shader=preload("res://shaders/resort_path.gdshader")
	material.set_shader_parameter("path_color",color)
	var node: MeshInstance3D = _mesh(vertices,normals,PackedColorArray(),material)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _shore_details(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	var batches: Dictionary = {}
	for z in range(key.y*16,key.y*16+16):
		for x in range(key.x*16,key.x*16+16):
			if model.surfaces[z*256+x] != 0: continue
			if (x*7+z*13)%5 != 0: continue
			var near_water: bool = false
			for off in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
				if model.surfaces[clampi(z+off.y,0,255)*256+clampi(x+off.x,0,255)] == 5: near_water=true
			if not near_water: continue
			var kind: String = "woodland_boulder" if (x+z)%3 == 0 else "dune_grass"
			var source: Node3D = AssetFactory.build(kind)
			source.position=Vector3(x*4+2,0,z*4+2)
			source.position.y=model.height_at(source.position)
			source.scale*=1.3 if kind=="dune_grass" else 0.65
			source.rotation.y=float(x*13+z)*0.37
			_collect_instances(source,Transform3D.IDENTITY,"shore",batches)
			source.free()
	for batch in batches.values():
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=batch.mesh
		mm.instance_count=batch.transforms.size()
		for i in range(batch.transforms.size()): mm.set_instance_transform(i,batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh=mm
		instance.material_override=batch.material
		root.add_child(instance)
	return root

func _horizon_height(p: Vector3) -> float:
	var edge := Vector3(clampf(p.x,0,1024),0,clampf(p.z,0,1024))
	var distance_edge: float = Vector2(p.x-edge.x,p.z-edge.z).length()
	var hills: float = 24.0+21.0*sin(p.x*0.004+p.z*0.002)+16.0*cos(p.z*0.009-p.x*0.003)
	return lerpf(model.height_at(edge),hills,smoothstep(0,420,distance_edge))

func _build_horizon() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for z in range(-24,56):
		for x in range(-24,56):
			if x>=0 and x<32 and z>=0 and z<32: continue
			for off in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p := Vector3((x+off.x)*32,0,(z+off.y)*32)
				p.y=_horizon_height(p)
				vertices.append(p)
				var slope := Vector2(_horizon_height(p+Vector3(2,0,0))-_horizon_height(p-Vector3(2,0,0)),_horizon_height(p+Vector3(0,0,2))-_horizon_height(p-Vector3(0,0,2)))/4.0
				normals.append(Vector3(-slope.x,1,-slope.y).normalized())
				var distance_edge: float = Vector2(p.x-clampf(p.x,0,1024),p.z-clampf(p.z,0,1024)).length()
				colors.append(Color(model.palette[0]).lerp(Color("8caaa0"),clampf(distance_edge/900,0,0.7)))
	_horizon_material=ShaderMaterial.new()
	_horizon_material.shader=preload("res://shaders/resort_horizon.gdshader")
	var mesh: MeshInstance3D = _mesh(vertices,normals,colors,_horizon_material)
	mesh.name="Distant countryside"
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


# Stable, inexpensive canopy shadow volumes prevent aggressive shadow-pass LOD
# from collapsing the foliage silhouette at the high management camera.
func _tree_shadow_instances() -> void:
	var groups: Dictionary = {}
	for obj in model.objects:
		if obj.kind not in ["oak_tree","pine_tree"]: continue
		var source: Node3D = object_nodes.get(obj.id)
		if source == null: continue
		var pine: bool = obj.kind=="pine_tree"
		var region := Vector2i(int(obj.pos.x/128),int(obj.pos.z/128))
		var key: String = str(region)+str(pine)
		if not groups.has(key): groups[key]={"pine":pine,"transforms":[]}
		var shape_scale := Vector3(1.45,2.35,1.45) if pine else Vector3(1.85,1.6,1.85)
		var center := Vector3(0,3.4,0) if pine else Vector3(0,3.65,0)
		groups[key].transforms.append(source.transform*Transform3D(Basis.IDENTITY.scaled(shape_scale),center))
	for group in groups.values():
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=AssetFactory._cone(1.0,2.0,Color.WHITE,12) if group.pine else AssetFactory._sphere(1.0,Color.WHITE,12)
		mm.instance_count=group.transforms.size()
		for i in range(group.transforms.size()):mm.set_instance_transform(i,group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh=mm
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		instance_root.add_child(node)
