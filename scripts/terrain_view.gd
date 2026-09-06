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
var overlay = "none"

func setup(data: TerrainModel) -> void:
	model = data
	ground_material = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_back;
uniform bool show_grid = false;
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 color = COLOR.rgb;
 if (show_grid) {
 vec2 coord = world_pos.xz / 4.0;
 vec2 grid = abs(fract(coord - 0.5) - 0.5) / max(fwidth(coord),vec2(0.015));
 float line = 1.0-min(min(grid.x,grid.y),1.0);
 color = mix(color,vec3(0.21,0.35,0.25),line*0.42);
 }
 ALBEDO=pow(color,vec3(1.4)); ROUGHNESS=0.95;
} """
	ground_material.shader = shader
	water_material = ShaderMaterial.new()
	var water_shader = Shader.new()
	water_shader.code = """shader_type spatial;
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float ripple=sin(world_pos.x*0.75+TIME*0.65)*sin(world_pos.z*0.48-TIME*0.55); ALBEDO=mix(vec3(0.22,0.52,0.53),vec3(0.40,0.69,0.65),ripple*0.22+0.55); ROUGHNESS=0.24; METALLIC=0.12;}
"""
	water_material.shader = water_shader
	add_child(object_root)
	add_child(hole_root)
	add_child(instance_root)
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
	sync_objects()
	sync_holes()

func set_grid(value: bool) -> void:
	ground_material.set_shader_parameter("show_grid",value)

func set_overlay(value: String) -> void:
	overlay = value
	for key in chunks: rebuild_chunk(key)

func rebuild_dirty() -> void:
	for key in model.changed_chunks: rebuild_chunk(key)
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
			var col = TerrainModel.SURFACE_COLORS[type]
			var center = Vector3(x*4+2,0,z*4+2)
			col = col.lightened(float((x*13+z*7)%11)/1200.0)
			if type == 1 and x%4 <2: col = col.lightened(0.025)
			if overlay == "beauty": col = Color("ad704e").lerp(Color("a2d88a"),model.beauty_at(center)/100.0)
			elif overlay == "access": col = Color("b07857") if not model.playable(center) else Color("8bae72")
			var points: Array[Vector3] = []
			for off in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
				points.append(Vector3((x+off.x)*4,model.heights[(z+off.y)*257+x+off.x],(z+off.y)*4))
			for i in [0,1,2,1,3,2]:
				var p = points[i]
				if type == 5:
					p.y = model.water_levels[z*256+x]
					water_verts.append(p)
					water_normals.append(Vector3.UP)
				else:
					verts.append(p)
					var slope = model.slope_at(p)
					normals.append(Vector3(-slope.x,1,-slope.y).normalized())
					colors.append(col)
	var root: Node3D
	if chunks.has(key):
		root = chunks[key]
		for child in root.get_children(): child.free()
	else:
		root = Node3D.new()
		add_child(root)
		chunks[key] = root
	if not verts.is_empty(): root.add_child(_mesh(verts,normals,colors,ground_material))
	if not water_verts.is_empty(): root.add_child(_mesh(water_verts,water_normals,PackedColorArray(),water_material))

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
			node = _path_visual(obj)
		else:
			node = AssetFactory.build(obj.kind,int(obj.id))
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
		instance.material_override=batch.material
		instance_root.add_child(instance)

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
	root.add_child(line_mesh(points,Color("adada1") if obj.kind=="path_paved" else Color("ceb88d"),width))
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

func sync_holes() -> void:
	for child in hole_root.get_children(): child.free()
	hole_nodes.clear()
	for i in range(model.holes.size()):
		var hole = model.holes[i]
		var root = Node3D.new()
		hole_root.add_child(root)
		var flag = AssetFactory.build("flag",i)
		flag.position = hole.cup
		flag.position.y = model.height_at(hole.cup)+0.1
		flag.scale = Vector3.ONE*1.4
		root.add_child(flag)
		var label = Label3D.new()
		label.text = "%02d" % (i+1)
		label.font_size = 64
		label.pixel_size = 0.075
		label.position = flag.position+Vector3(0,9,0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("fff5cf") if hole.open else Color("bdaaa1")
		label.outline_modulate=Color("26483c")
		label.no_depth_test=true
		root.add_child(label)
		var tee = MeshInstance3D.new()
		var box=BoxMesh.new()
		box.size=Vector3(5,0.25,2)
		tee.mesh=box
		tee.position=hole.tee+Vector3(0,0.25,0)
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color("f5e9cb")
		tee.material_override=mat
		root.add_child(tee)
		hole_nodes[hole.id]=root
