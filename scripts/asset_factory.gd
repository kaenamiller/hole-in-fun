class_name AssetFactory
extends RefCounted

## Lush resort assets: sculpted foliage, timber architecture and shared materials.
## Every returned model is centered on the origin with its feet on y=0.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _foliage_material: ShaderMaterial
static var _asset_cache: Dictionary = {}
static var _shipped_scenes: Dictionary = {}
static var _grain_texture: NoiseTexture2D
static var _occlusion_texture: NoiseTexture2D
static var foliage_lod_distance: float = 60.0
static var gen2_trees_enabled: bool = true
static var architecture_lod_distance: float = 80.0


const GREEN := Color("#69883d")
const DEEP_GREEN := Color("#3d602e")
const FAIRWAY := Color("#74a35b")
const CREAM := Color("#e2d3ad")
const TERRACOTTA := Color("#75604a")
const TERRACOTTA_DARK := Color("#493d32")
const WOOD := Color("#8b5a3c")
const WOOD_DARK := Color("#4e3326")
const BRASS := Color("#d5a84b")
const WATER := Color("#5e9da0")
const FLOWER_PINK := Color("#e4868b")
const FLOWER_YELLOW := Color("#f2c75b")
const FLOWER_BLUE := Color("#759bd1")
const SKIN := Color("#e4ad83")
const SHIRT_BLUE := Color("#527aa5")
const PANTS := Color("#394858")
const WHITE := Color("#f7f2df")

static func build(kind: String, variant: int = 0) -> Node3D:
	var cache_key: String = kind+":"+str(variant)
	if _asset_cache.has(cache_key):
		var cached: Dictionary = _asset_cache[cache_key]
		if cached.has("scene_path"):
			var shipped_cached: Node3D = (_load_shipped_scene(str(cached.scene_path)) as PackedScene).instantiate()
			shipped_cached.name = kind
			return shipped_cached
		var cached_root: Node3D = Node3D.new()
		cached_root.name = kind
		cached_root.scale = cached.scale
		for part in cached.parts:
			var instance: MeshInstance3D = _mesh(cached_root, part.mesh, part.material)
			if part.has("visibility_begin"):
				instance.visibility_range_begin = float(part.visibility_begin)
			if part.has("visibility_end"):
				instance.visibility_range_end = float(part.visibility_end)
		return cached_root
	var shipped: Node3D = _instantiate_shipped_architecture(kind, variant)
	if shipped != null:
		shipped.name = kind
		var scene_path: String = ArchitectureManifest.scene_path(kind, variant)
		_asset_cache[cache_key] = {"scene_path": scene_path}
		return shipped
	var root: Node3D = Node3D.new()
	root.name = kind
	var architecture_key: String = ArchitectureManifest.resolve_asset_key(kind)
	var skip_dress: bool = not architecture_key.is_empty()
	match kind:
		"clubhouse":
			ArchitectureMesh.build_clubhouse(root, variant)
		"driving_range":
			_build_driving_range(root, variant)
		"restroom":
			_build_restroom(root, variant)
		"snack_kiosk":
			_build_snack_kiosk(root, variant)
		"cart_barn":
			_build_cart_barn(root, variant)
		"maintenance_shed":
			_build_maintenance_shed(root, variant)
		"putting_green":
			_build_putting_green(root, variant)
		"halfway_house":
			_build_halfway_house(root, variant)
		"pro_shop":
			_build_pro_shop(root, variant)
		"caddie_house":
			_build_caddie_house(root, variant)
		"restaurant":
			_build_restaurant(root, variant)
		"bar_terrace":
			_build_bar_terrace(root, variant)
		"spa":
			_build_spa(root, variant)
		"lodge":
			_build_lodge(root, variant)
		"oak_tree", "tree":
			_build_oak_tree(root, variant)
		"pine_tree":
			_build_pine_tree(root, variant)
		"desert_shrub":
			_build_desert_shrub(root, variant)
		"dune_grass":
			_build_dune_grass(root, variant)
		"woodland_log":
			_build_log(root, variant)
		"woodland_boulder":
			_build_boulder(root, variant)
		"pergola":
			_build_pergola(root, variant)
		"fountain":
			_build_fountain(root, variant)
		"flower_bed":
			_build_flower_bed(root, variant)
		"topiary":
			_build_topiary(root, variant)
		"gazebo":
			_build_gazebo(root, variant)
		"palm_tree":
			_build_palm(root, variant)
		"bench":
			_build_bench(root, variant)
		"decorative_pond":
			_build_pond(root, variant)
		"flag":
			_build_flag(root, variant)
		"stake":
			_build_stake(root, variant)
		"bridge", "bridge_walk", "bridge_cart":
			ArchitectureMesh.build_bridge(root, variant)
		"sign":
			_build_sign(root, variant)
		_:
			_build_generic_prop(root, variant)
	if not skip_dress:
		_dress_facility(root, kind)
	if root.get_meta("skip_bake", false):
		_cache_gen2(root, cache_key)
	elif architecture_key.is_empty() or ArchitectureManifest.contracts()[architecture_key].get("static_bake", true):
		_bake_static(root, cache_key)
	return root

static func clear_tree_cache() -> void:
	TreeAssets.clear_cache()
	for key in _asset_cache.keys():
		if str(key).contains("oak_tree") or str(key).contains("pine_tree"):
			_asset_cache.erase(key)
	for key in _meshes.keys():
		if str(key).begins_with("tree_shadow:"):
			_meshes.erase(key)

# Collapse all static pieces sharing a material into one draw, then reuse meshes.
static func _bake_static(root: Node3D, key: String) -> void:
	var groups: Dictionary = {}
	_gather_static(root,Transform3D.IDENTITY,groups)
	for child in root.get_children(): child.free()
	var parts: Array = []
	for group in groups.values():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array(group.verts)
		arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array(group.normals)
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array(group.uvs)
		arrays[Mesh.ARRAY_COLOR]=PackedColorArray(group.colors)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		if group.material == _foliage():
			var surface_tool := SurfaceTool.new()
			surface_tool.create_from(mesh,0)
			surface_tool.index()
			var importer := ImporterMesh.new()
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES,surface_tool.commit_to_arrays())
			importer.generate_lods(foliage_lod_distance, 25.0, [])
			mesh=importer.get_mesh()
		parts.append({"mesh":mesh,"material":group.material})
		var draw_material: Material = group.material
		if group.material is StandardMaterial3D and group.material != _foliage():
			draw_material = (group.material as StandardMaterial3D).duplicate()
			(draw_material as StandardMaterial3D).vertex_color_use_as_albedo = true
		_mesh(root,mesh,draw_material)
	_asset_cache[key]={"scale":root.scale,"parts":parts}

static func _cache_gen2(root: Node3D, key: String) -> void:
	var parts: Array = []
	for child in root.get_children():
		if child is MeshInstance3D and child.mesh != null:
			parts.append({
				"mesh": child.mesh,
				"material": child.material_override,
				"visibility_begin": child.visibility_range_begin,
				"visibility_end": child.visibility_range_end,
			})
	_asset_cache[key] = {"scale": root.scale, "parts": parts, "gen2": true}

static func _gather_static(node: Node3D, parent: Transform3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if not child is Node3D: continue
		var transform: Transform3D = parent*child.transform
		if child is MeshInstance3D and child.mesh != null:
			var mat: Material = child.material_override
			var key: int = mat.get_instance_id()
			if not groups.has(key): groups[key]={"material":mat,"verts":[],"normals":[],"uvs":[],"colors":[]}
			var group: Dictionary = groups[key]
			for surface in range(child.mesh.get_surface_count()):
				var a: Array = child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
				var normal_basis: Basis = transform.basis.inverse().transposed()
				for n in range(indices.size() if not indices.is_empty() else vertices.size()):
					var i: int = indices[n] if not indices.is_empty() else n
					group.verts.append(transform*vertices[i])
					group.normals.append((normal_basis*a[Mesh.ARRAY_NORMAL][i]).normalized() if a[Mesh.ARRAY_NORMAL] != null else Vector3.UP)
					group.uvs.append(a[Mesh.ARRAY_TEX_UV][i] if a[Mesh.ARRAY_TEX_UV] != null else Vector2.ZERO)
					var base_color: Color = a[Mesh.ARRAY_COLOR][i] if a[Mesh.ARRAY_COLOR] != null else Color.WHITE
					var local_normal: Vector3 = (normal_basis*a[Mesh.ARRAY_NORMAL][i]).normalized() if a[Mesh.ARRAY_NORMAL] != null else Vector3.UP
					var local_pos: Vector3 = transform*vertices[i]
					if mat is StandardMaterial3D and mat != _foliage():
						var occlusion: float = _vertex_self_occlusion(local_normal, local_pos)
						var albedo: Color = (mat as StandardMaterial3D).albedo_color
						group.colors.append(Color(albedo.r * occlusion, albedo.g * occlusion, albedo.b * occlusion, 1.0))
					else:
						group.colors.append(base_color)
		_gather_static(child,transform,groups)

static func _dress_facility(root: Node3D, kind: String) -> void:
	var sizes: Dictionary = {"clubhouse":Vector3(12,5,8.6),"restroom":Vector3(6.4,3.2,4.8),"snack_kiosk":Vector3(5.4,3.1,4.0),"cart_barn":Vector3(9.4,3.8,6.2),"maintenance_shed":Vector3(7.6,3.4,5.8),"halfway_house":Vector3(6.6,3.6,4.8),"pro_shop":Vector3(8.8,4.2,6),"caddie_house":Vector3(6.8,3.6,4.8),"restaurant":Vector3(13,5.2,9),"spa":Vector3(11,4,7.5),"lodge":Vector3(15,5.5,10)}
	if not sizes.has(kind): return
	var size: Vector3 = sizes[kind]
	var wood := _material(WOOD_DARK)
	_mesh(root,_box(Vector3(size.x+0.18,0.55,size.z+0.18)),_material(Color("#a49c83")),Vector3(0,0.3,0))
	# Side and rear faces matter when players orbit the camera.
	for face in range(1,4):
		var facade := Node3D.new()
		root.add_child(facade)
		facade.rotation.y=face*PI*0.5
		var width: float = size.z if face%2 else size.x
		var depth: float = size.x if face%2 else size.z
		for x in [-width*0.32,width*0.32]:
			_window(facade,Vector3(x,size.y*0.55,-depth*0.5-0.10),Vector3(1.05,1.25,0.10),wood)
		for x in [-width*0.48,0,width*0.48]:
			_mesh(facade,_box(Vector3(0.15,size.y,0.13)),wood,Vector3(x,size.y*0.5+0.3,-depth*0.5-0.08))
		for y in [0.6,size.y+0.14]:
			_mesh(facade,_box(Vector3(width,0.16,0.15)),wood,Vector3(0,y,-depth*0.5-0.08))

static func golfer(variant: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Golfer"
	var shirts = [SHIRT_BLUE,Color("b76554"),Color("e0bb66"),Color("719078"),Color("8c78a8"),Color("c6d4bf")]
	var shirt_color: Color = shirts[variant % shirts.size()]
	var skin_mat: StandardMaterial3D = _material(SKIN)
	var shirt_mat: StandardMaterial3D = _material(shirt_color)
	var pants_mat: StandardMaterial3D = _material(PANTS)
	var shoe_mat: StandardMaterial3D = _material(WOOD_DARK)
	var hair_mat: StandardMaterial3D = _material(Color("#3b2926"))
	var torso: Node3D = Node3D.new()
	torso.name = "Torso"
	root.add_child(torso)
	_mesh(torso, _sphere(0.31,SHIRT_BLUE), shirt_mat, Vector3(0, 1.20, 0),Vector3(0.8,1.1,0.57))
	var head: MeshInstance3D = _mesh(root, _sphere(0.18, SKIN), skin_mat, Vector3(0, 1.70, 0))
	head.name = "Head"
	_mesh(root, _sphere(0.185, Color("#3b2926")), hair_mat, Vector3(0, 1.81, -0.01), Vector3(1.0, 0.55, 1.0))
	var arm_l: Node3D = _limb(root, "ArmL", Vector3(-0.29, 1.36, 0), Vector3(0.11, 0.47, 0.11), skin_mat)
	var arm_r: Node3D = _limb(root, "ArmR", Vector3(0.29, 1.36, 0), Vector3(0.11, 0.47, 0.11), skin_mat)
	var leg_l: Node3D = _limb(root, "LegL", Vector3(-0.12, 0.66, 0), Vector3(0.14, 0.64, 0.14), pants_mat)
	var leg_r: Node3D = _limb(root, "LegR", Vector3(0.12, 0.66, 0), Vector3(0.14, 0.64, 0.14), pants_mat)
	_mesh(root, _box(Vector3(0.22, 0.10, 0.38)), shoe_mat, Vector3(-0.12, 0.22, -0.08))
	_mesh(root, _box(Vector3(0.22, 0.10, 0.38)), shoe_mat, Vector3(0.12, 0.22, -0.08))
	var club: Node3D = Node3D.new()
	club.name = "Club"
	root.add_child(club)
	_mesh(club, _box(Vector3(0.035, 0.88, 0.035)), _material(BRASS), Vector3(0.40, 0.77, -0.10), Vector3.ONE, Vector3(0, 0, -0.25))
	_mesh(club, _box(Vector3(0.20, 0.06, 0.10)), _material(TERRACOTTA_DARK), Vector3(0.40, 0.32, -0.10))
	root.set_meta("asset_type", "golfer")
	return root

static func staff_uniform(role: String) -> Color:
	match role:
		"groundskeeper":
			return DEEP_GREEN
		"service_attendant":
			return SHIRT_BLUE
		"cleaner":
			return Color("#8c9aa8")
		"golf_pro":
			return Color("#1f4d3a")
		"shop_clerk":
			return Color("#6b4f7b")
		"marshal":
			return Color("#c45c2a")
		"head_greenkeeper":
			return Color("#2d6b4f")
		_:
			return SHIRT_BLUE

static func staff_golfer(role: String, variant: int = 0) -> Node3D:
	var root: Node3D = golfer(variant + 8)
	root.name = "Staff_%s" % role
	var torso: Node3D = root.get_node_or_null("Torso") as Node3D
	var shirt_color: Color = staff_uniform(role)
	var shirt_mat: StandardMaterial3D = _material(shirt_color)
	if torso != null:
		for child in torso.get_children():
			if child is MeshInstance3D:
				(child as MeshInstance3D).material_override = shirt_mat
	return root

static func cart() -> Node3D:
	var shipped: Node3D = _instantiate_shipped_architecture("cart", 0)
	if shipped != null:
		return shipped
	var root: Node3D = Node3D.new()
	ArchitectureMesh.build_cart(root)
	return root


static func _load_shipped_scene(path: String) -> Resource:
	if _shipped_scenes.has(path):
		return _shipped_scenes[path]
	if not ResourceLoader.exists(path):
		return null
	var scene: Resource = load(path)
	_shipped_scenes[path] = scene
	return scene


static func _instantiate_shipped_architecture(kind: String, variant: int) -> Node3D:
	if not ArchitectureManifest.has_shipped_asset(kind):
		return null
	var path: String = ArchitectureManifest.scene_path(kind, variant)
	var scene: Resource = _load_shipped_scene(path)
	if scene == null or not scene is PackedScene:
		return null
	return (scene as PackedScene).instantiate() as Node3D

static func animate_golfer(node: Node3D, activity: String, phase: float, aim_yaw: float = NAN, simplified: bool = false) -> void:
	if node == null:
		return
	var torso: Node3D = node.get_node_or_null("Torso") as Node3D
	var head: Node3D = node.get_node_or_null("Head") as Node3D
	var arm_l: Node3D = node.get_node_or_null("ArmL") as Node3D
	var arm_r: Node3D = node.get_node_or_null("ArmR") as Node3D
	var leg_l: Node3D = node.get_node_or_null("LegL") as Node3D
	var leg_r: Node3D = node.get_node_or_null("LegR") as Node3D
	var club: Node3D = node.get_node_or_null("Club") as Node3D
	if simplified:
		for part in [arm_l, arm_r, leg_l, leg_r, club]:
			var part_node: Node3D = part as Node3D
			if part_node != null:
				part_node.rotation = Vector3.ZERO
		if torso != null:
			torso.rotation.y = 0.0
		if head != null:
			head.rotation = Vector3.ZERO
		return
	var sway: float = sin(phase * TAU)
	var stride: float = sin(phase * TAU)
	var head_aim: float = 0.0
	if not is_nan(aim_yaw):
		head_aim = clampf(aim_yaw - node.rotation.y, -0.75, 0.75)
	if activity == "walking":
		if leg_l != null:
			leg_l.rotation.x = stride * 0.45
		if leg_r != null:
			leg_r.rotation.x = -stride * 0.45
		if arm_l != null:
			arm_l.rotation.x = -stride * 0.28
		if arm_r != null:
			arm_r.rotation.x = stride * 0.28
		if torso != null:
			torso.rotation.z = sway * 0.035
		if head != null:
			head.rotation.y = head_aim * 0.25
	elif activity == "address":
		if torso != null:
			torso.rotation.x = -0.12
		if arm_l != null:
			arm_l.rotation.z = -0.35
			arm_l.rotation.x = -0.18
		if arm_r != null:
			arm_r.rotation.z = 0.35
			arm_r.rotation.x = -0.18
		if club != null:
			club.rotation.z = -0.15 - phase * 0.12
		if head != null:
			head.rotation.y = head_aim * 0.55
	elif activity == "backswing":
		var back: float = sin(clampf(phase, 0.0, 1.0) * PI * 0.5)
		if arm_l != null:
			arm_l.rotation.z = -0.45 - back * 1.05
		if arm_r != null:
			arm_r.rotation.z = 0.45 + back * 1.05
		if torso != null:
			torso.rotation.y = -back * 0.42
		if club != null:
			club.rotation.z = -0.25 - back * 1.25
		if head != null:
			head.rotation.y = head_aim * 0.35
	elif activity == "contact":
		var hit: float = clampf(phase, 0.0, 1.0)
		if arm_l != null:
			arm_l.rotation.z = -0.95 - hit * 0.35
		if arm_r != null:
			arm_r.rotation.z = 0.95 + hit * 0.35
		if torso != null:
			torso.rotation.y = hit * 0.55
		if club != null:
			club.rotation.z = -0.85 - hit * 0.55
		if head != null:
			head.rotation.y = head_aim * 0.65
	elif activity == "follow_through":
		var follow: float = sin(clampf(phase, 0.0, 1.0) * PI * 0.5)
		if arm_l != null:
			arm_l.rotation.z = -0.25 - follow * 0.45
		if arm_r != null:
			arm_r.rotation.z = 0.25 + follow * 0.45
		if torso != null:
			torso.rotation.y = 0.35 + follow * 0.45
		if club != null:
			club.rotation.z = -0.15 - follow * 0.35
		if head != null:
			head.rotation.y = head_aim * 0.8
	elif activity == "swinging":
		var swing: float = sin(clamp(phase, 0.0, 1.0) * PI)
		if arm_l != null:
			arm_l.rotation.z = -0.55 - swing * 1.2
		if arm_r != null:
			arm_r.rotation.z = 0.55 + swing * 1.2
		if torso != null:
			torso.rotation.y = swing * 0.65
		if club != null:
			club.rotation.z = -0.45 - swing * 1.4
		if head != null:
			head.rotation.y = head_aim * 0.6
	elif activity == "putting":
		if torso != null:
			torso.rotation.x = -0.48
		if arm_l != null:
			arm_l.rotation.z = -0.28 + sway * 0.30
		if arm_r != null:
			arm_r.rotation.z = 0.28 - sway * 0.30
		if club != null:
			club.rotation.z = sway * 0.20
		if head != null:
			head.rotation.y = head_aim * 0.45
	elif activity == "mowing":
		if torso != null:
			torso.rotation.x = -0.35 + sway * 0.08
		if arm_l != null:
			arm_l.rotation.z = -0.55 + sway * 0.55
		if arm_r != null:
			arm_r.rotation.z = 0.45 - sway * 0.55
		if leg_l != null:
			leg_l.rotation.x = stride * 0.18
		if leg_r != null:
			leg_r.rotation.x = -stride * 0.18
		if club != null:
			club.rotation.z = -0.25 + sway * 0.35
	elif activity == "seated":
		if torso != null:
			torso.rotation.x = -0.22
		if leg_l != null:
			leg_l.rotation.x = -1.05
		if leg_r != null:
			leg_r.rotation.x = -1.05
		if arm_l != null:
			arm_l.rotation.z = -0.20
		if arm_r != null:
			arm_r.rotation.z = 0.20
	else:
		for part in [arm_l, arm_r, leg_l, leg_r, torso, club, head]:
			var part_node: Node3D = part as Node3D
			if part_node != null:
				part_node.rotation = Vector3.ZERO
		if leg_l != null:
			leg_l.position.y = 0.0
		if leg_r != null:
			leg_r.position.y = 0.0

static func _family(family_id: String) -> StandardMaterial3D:
	return MaterialLibrary.material(family_id)

static func _build_clubhouse(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _family("arch.plaster")
	var accent: StandardMaterial3D = _family("arch.roof")
	var wood: StandardMaterial3D = _family("arch.timber")
	_mesh(root, _box(Vector3(13.0, 0.35, 9.5)), _material(WOOD_DARK), Vector3(0, 0.18, 0))
	_mesh(root, _box(Vector3(12.0, 5.0, 8.6)), wall, Vector3(0, 2.82, 0))
	_roof(root, 14.0, 10.0, 1.15, 5.40, accent)
	_mesh(root, _box(Vector3(2.8, 0.20, 1.1)), wood, Vector3(0, 0.45, -5.05))
	_mesh(root, _box(Vector3(2.4, 2.2, 0.28)), wood, Vector3(0, 1.56, -4.50))
	for x in [-4.2, -2.2, 2.2, 4.2]:
		_window(root, Vector3(x, 2.60, -4.48), Vector3(1.30, 1.35, 0.10), _material(Color("#9bc6bd")))
		_mesh(root, _box(Vector3(0.10, 1.55, 0.14)), wood, Vector3(x, 2.60, -4.57))
	for x in [-2.3, 2.3]:
		_mesh(root, _box(Vector3(0.22, 2.9, 0.22)), accent, Vector3(x, 1.80, -5.05))
	_mesh(root, _box(Vector3(5.6, 0.18, 1.8)), accent, Vector3(0, 3.95, -4.95))
	_mesh(root, _box(Vector3(5.6, 0.22, 0.22)), wood, Vector3(0, 3.86, -5.86))
	_mesh(root, _box(Vector3(3.0, 0.18, 0.48)), _material(CREAM), Vector3(0, 4.05, -5.88))
	_steps(root, Vector3(0, 0.40, -5.35), 3, 2.8)
	for z in [-4.34,4.34]:
		for x in [-5.85,-3.0,0.0,3.0,5.85]:
			_mesh(root,_box(Vector3(0.18,5.0,0.16)),wood,Vector3(x,2.82,z))
		for y in [0.65,3.6,5.15]:
			_mesh(root,_box(Vector3(12.0,0.18,0.18)),wood,Vector3(0,y,z))
		for x in [-4.5,4.5]:
			_mesh(root,_box(Vector3(0.13,1.8,0.12)),wood,Vector3(x,4.35,z),Vector3.ONE,Vector3(0,0,0.7 if x>0 else -0.7))
	_mesh(root,_box(Vector3(1.25,4.0,1.15)),_material(Color("#9d9781")),Vector3(3.8,7.0,2.0))
	_mesh(root,_box(Vector3(1.45,0.2,1.35)),_material(CREAM),Vector3(3.8,9.05,2.0))
	# Rear terrace, tables and canvas parasols.
	_mesh(root,_box(Vector3(12.8,0.24,3.2)),_material(CREAM),Vector3(0,0.20,5.0))
	for x in [-4.0,0.0,4.0]:
		_mesh(root,_cylinder(0.72,0.12,WOOD,24),_material(WOOD),Vector3(x,1.04,5.1))
		_mesh(root,_cylinder(0.07,2.6,WOOD,12),wood,Vector3(x,1.5,5.1))
		_mesh(root,_cone(1.35,0.38,CREAM,32),_material(CREAM),Vector3(x,2.82,5.1))
		for side in [-1,1]:
			_mesh(root,_box(Vector3(0.6,0.1,0.6)),wood,Vector3(x+side*0.96,0.7,5.1))

	if variant >= 1:
		var wing := Node3D.new()
		root.add_child(wing)
		wing.position.x=7.2
		_mesh(wing, _box(Vector3(4.8, 3.6, 5.2)), wall, Vector3(0, 2.4, 0))
		_roof(wing, 6.0, 5.8, 0.85, 4.2, accent)
		_window(wing,Vector3(0,2.8,-2.65),Vector3(1.4,1.4,0.1),wood)
	if variant >= 2:
		_mesh(root, _box(Vector3(3.2, 2.4, 4.0)), wall, Vector3(-7.0, 3.8, 1.2))
		_mesh(root, _box(Vector3(0.18, 4.8, 0.18)), _material(BRASS), Vector3(-7.0, 5.2, -0.8))

static func _build_driving_range(root: Node3D, variant: int) -> void:
	var turf: StandardMaterial3D = _family("course.fairway")
	var frame: StandardMaterial3D = _family("arch.timber")
	var net: StandardMaterial3D = _material(Color("#b7ccb2"), 1.0)
	_mesh(root, _box(Vector3(14.0, 0.25, 8.0)), turf, Vector3(0, 0.12, 0))
	_mesh(root, _box(Vector3(13.0, 0.16, 1.6)), _material(WOOD), Vector3(0, 0.34, -2.8))
	for x in [-5.5, -1.85, 1.85, 5.5]:
		_mesh(root, _box(Vector3(0.18, 3.8, 0.18)), frame, Vector3(x, 2.2, -3.1))
		_mesh(root, _box(Vector3(0.18, 3.8, 0.18)), frame, Vector3(x, 2.2, 2.8))
	for x in [-3.7, 0, 3.7]:
		_mesh(root, _box(Vector3(0.12, 3.2, 0.12)), frame, Vector3(x, 1.9, 2.8))
	_mesh(root, _box(Vector3(12.0, 0.15, 0.15)), frame, Vector3(0, 4.0, -3.1))
	_mesh(root, _box(Vector3(12.0, 0.15, 0.15)), frame, Vector3(0, 4.0, 2.8))
	for x in [-5.2, -1.75, 1.75, 5.2]:
		_mesh(root, _box(Vector3(0.14, 2.7, 0.08)), net, Vector3(x, 2.05, 0.0))
	for x in [-4.0, -1.3, 1.3, 4.0]:
		_mesh(root, _box(Vector3(2.30, 0.08, 0.95)), _material(CREAM), Vector3(x, 0.55, -2.75))
		_mesh(root, _box(Vector3(0.08, 0.75, 0.08)), frame, Vector3(x - 0.7, 0.72, -2.75))
		_mesh(root, _box(Vector3(0.08, 0.75, 0.08)), frame, Vector3(x + 0.7, 0.72, -2.75))
	if variant >= 1:
		for x in [-4.8, 4.8]:
			_mesh(root, _box(Vector3(3.6, 2.8, 0.12)), _material(WOOD), Vector3(x, 1.8, -3.05))
			_mesh(root, _box(Vector3(3.4, 0.12, 0.12)), frame, Vector3(x, 3.2, -3.18))

static func _build_restroom(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(7.2, 0.30, 5.5)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(6.6, 3.8, 4.9)), wall, Vector3(0, 2.15, 0))
	_roof(root, 7.4, 5.6, 0.85, 4.15, accent)
	for x in [-1.75, 1.75]:
		_mesh(root, _box(Vector3(1.35, 2.0, 0.25)), _material(WOOD), Vector3(x, 1.18, -2.58))
		_mesh(root, _box(Vector3(0.55, 0.10, 0.05)), _material(BRASS), Vector3(x, 1.55, -2.73))
	_window(root, Vector3(0, 2.65, -2.52), Vector3(1.7, 0.72, 0.10), _material(Color("#9bc6bd")))
	_steps(root, Vector3(0, 0.35, -3.00), 2, 2.9)
	_mesh(root, _box(Vector3(0.90, 0.10, 0.20)), accent, Vector3(0, 3.95, -2.85))
	if variant >= 1:
		_mesh(root, _box(Vector3(2.4, 2.2, 4.2)), wall, Vector3(3.8, 2.0, 0))
		_mesh(root, _box(Vector3(2.4, 2.2, 4.2)), wall, Vector3(-3.8, 2.0, 0))

static func _build_snack_kiosk(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(TERRACOTTA)
	var trim: StandardMaterial3D = _material(CREAM)
	_mesh(root, _box(Vector3(6.4, 0.28, 4.3)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(5.8, 3.5, 3.8)), wall, Vector3(0, 2.0, 0.1))
	_roof(root, 6.5, 4.6, 0.75, 3.95, trim)
	_mesh(root, _box(Vector3(5.3, 1.2, 0.18)), trim, Vector3(0, 2.15, -2.05))
	_mesh(root, _box(Vector3(5.2, 0.16, 0.90)), _material(WOOD), Vector3(0, 1.30, -2.16))
	for x in [-2.0, 0, 2.0]:
		_mesh(root, _cylinder(0.23, 0.62, WOOD_DARK, 10), _material(WOOD_DARK), Vector3(x, 0.82, -2.16))
		_mesh(root, _cylinder(0.45, 0.10, CREAM, 12), trim, Vector3(x, 1.18, -2.16))
	_mesh(root, _box(Vector3(3.4, 0.12, 0.18)), trim, Vector3(0, 3.20, -2.05))
	_mesh(root, _box(Vector3(3.2, 0.30, 0.12)), _material(BRASS), Vector3(0, 2.98, -2.15))
	if variant >= 1:
		_mesh(root, _box(Vector3(2.2, 2.4, 3.2)), wall, Vector3(3.4, 2.0, 0.2))
		_mesh(root, _box(Vector3(1.8, 0.14, 0.14)), trim, Vector3(3.4, 3.2, -1.5))

static func _build_cart_barn(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(WOOD)
	var trim: StandardMaterial3D = _material(CREAM)
	_mesh(root, _box(Vector3(13.0, 0.30, 8.6)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(12.3, 4.9, 7.8)), wall, Vector3(0, 2.60, 0))
	_roof(root, 13.5, 9.0, 1.15, 5.25, _material(TERRACOTTA))
	for x in [-5.1, -1.7, 1.7, 5.1]:
		_mesh(root, _box(Vector3(0.25, 5.2, 0.25)), trim, Vector3(x, 2.72, -4.02))
	for x in [-3.4, 0, 3.4]:
		_mesh(root, _box(Vector3(2.7, 3.9, 0.16)), _material(WOOD_DARK), Vector3(x, 2.14, -4.02))
		_mesh(root, _box(Vector3(2.4, 0.15, 0.15)), trim, Vector3(x, 3.55, -4.14))
	_mesh(root, _box(Vector3(12.0, 0.20, 0.26)), trim, Vector3(0, 4.82, -4.08))
	_mesh(root, _box(Vector3(3.6, 0.16, 0.20)), _material(BRASS), Vector3(0, 4.50, -4.17))
	if variant >= 1:
		_mesh(root, _box(Vector3(4.2, 3.8, 7.2)), wall, Vector3(0, 2.2, 3.8))
		for x in [-2.0, 2.0]:
			_mesh(root, _box(Vector3(2.8, 3.2, 0.16)), _material(WOOD_DARK), Vector3(x, 2.0, 4.02))

static func _build_maintenance_shed(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(Color("#c7955c"))
	var trim: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(8.4, 0.28, 6.0)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(7.7, 4.2, 5.4)), wall, Vector3(0, 2.28, 0))
	_roof(root, 8.5, 6.4, 0.85, 4.60, trim)
	_mesh(root, _box(Vector3(3.8, 2.85, 0.18)), _material(WOOD_DARK), Vector3(0, 1.58, -2.78))
	_mesh(root, _box(Vector3(0.12, 2.85, 0.12)), trim, Vector3(0, 1.58, -2.90))
	for x in [-2.4, 2.4]:
		_window(root, Vector3(x, 2.95, -2.75), Vector3(1.20, 0.95, 0.10), _material(Color("#9bc6bd")))
	_mesh(root, _cylinder(0.42, 0.62, TERRACOTTA_DARK, 12), _material(TERRACOTTA_DARK), Vector3(4.15, 0.58, -1.7), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.42, 0.62, WOOD, 12), _material(WOOD), Vector3(4.15, 0.58, -0.65), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	if variant >= 1:
		_mesh(root, _box(Vector3(3.2, 2.6, 4.8)), wall, Vector3(-3.2, 1.5, 1.0))
		_mesh(root, _cylinder(0.35, 0.55, DEEP_GREEN, 10), _material(DEEP_GREEN), Vector3(-3.2, 0.5, 2.8), Vector3.ONE, Vector3(0, 0, PI / 2.0))

static func _build_putting_green(root: Node3D, variant: int) -> void:
	var turf: StandardMaterial3D = _family("course.fairway")
	_mesh(root, _cylinder(5.5, 0.18, FAIRWAY, 24), turf, Vector3(0, 0.09, 0))
	_mesh(root, _cylinder(0.12, 0.9, WOOD_DARK, 8), _material(WOOD_DARK), Vector3(0, 0.45, 0))
	_mesh(root, _box(Vector3(0.55, 0.04, 0.38)), _material(WHITE), Vector3(0.35, 0.92, 0))
	for a in range(0, 360, 90):
		var radians: float = deg_to_rad(float(a))
		_mesh(root, _sphere(0.12, WHITE), _material(WHITE), Vector3(cos(radians) * 4.2, 0.18, sin(radians) * 4.2))

static func _build_halfway_house(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(TERRACOTTA)
	_mesh(root, _box(Vector3(8.0, 0.28, 5.8)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(7.2, 3.4, 5.0)), wall, Vector3(0, 1.95, 0))
	_roof(root, 8.0, 5.8, 0.75, 3.85, accent)
	_mesh(root, _box(Vector3(4.8, 1.0, 0.18)), _material(WOOD), Vector3(0, 1.5, -2.65))
	_mesh(root, _cylinder(0.35, 0.55, TERRACOTTA, 10), _material(TERRACOTTA), Vector3(-2.2, 0.55, -2.65))
	_mesh(root, _cylinder(0.35, 0.55, CREAM, 10), _material(CREAM), Vector3(0.0, 0.55, -2.65))
	_mesh(root, _cylinder(0.35, 0.55, TERRACOTTA_DARK, 10), _material(TERRACOTTA_DARK), Vector3(2.2, 0.55, -2.65))

static func _build_pro_shop(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(Color("#6b4f7b"))
	_mesh(root, _box(Vector3(9.6, 0.30, 6.8)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(8.8, 4.2, 6.0)), wall, Vector3(0, 2.35, 0))
	_roof(root, 10.2, 7.0, 0.9, 4.55, accent)
	for x in [-3.0, 0.0, 3.0]:
		_window(root, Vector3(x, 2.8, -3.15), Vector3(1.4, 1.5, 0.10), _material(Color("#9bc6bd")))
	_mesh(root, _box(Vector3(2.4, 2.4, 0.22)), _material(WOOD), Vector3(0, 1.35, -3.18))
	_mesh(root, _box(Vector3(3.6, 0.14, 0.18)), accent, Vector3(0, 4.05, -3.25))
	_steps(root, Vector3(0, 0.35, -3.55), 2, 2.6)

static func _build_caddie_house(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(WOOD)
	var trim: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(7.4, 0.28, 5.4)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(6.8, 3.6, 4.8)), wall, Vector3(0, 2.05, 0))
	_roof(root, 7.6, 5.6, 0.8, 3.95, trim)
	_mesh(root, _box(Vector3(2.2, 2.2, 0.20)), _material(WOOD_DARK), Vector3(0, 1.25, -2.55))
	for x in [-1.8, 1.8]:
		_mesh(root, _box(Vector3(0.9, 1.6, 0.45)), _material(CREAM), Vector3(x, 1.5, 0.8))

static func _build_restaurant(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(TERRACOTTA)
	_mesh(root, _box(Vector3(14.0, 0.35, 10.0)), _material(WOOD_DARK), Vector3(0, 0.18, 0))
	_mesh(root, _box(Vector3(13.0, 5.2, 9.0)), wall, Vector3(0, 2.95, 0))
	_roof(root, 14.5, 10.5, 1.0, 5.55, accent)
	for x in [-4.5, -1.5, 1.5, 4.5]:
		_window(root, Vector3(x, 3.0, -4.65), Vector3(1.2, 1.4, 0.10), _material(Color("#9bc6bd")))
	_mesh(root, _box(Vector3(4.0, 0.20, 1.4)), _material(WOOD), Vector3(0, 0.45, -5.05))
	_steps(root, Vector3(0, 0.40, -5.35), 3, 3.2)

static func _build_bar_terrace(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	var trim: StandardMaterial3D = _material(TERRACOTTA)
	_mesh(root, _box(Vector3(11.0, 0.28, 7.5)), _material(WOOD), Vector3(0, 0.14, 0))
	for x in [-4.0, -1.3, 1.3, 4.0]:
		_mesh(root, _box(Vector3(0.22, 2.8, 0.22)), wood, Vector3(x, 1.55, -2.8))
	_mesh(root, _box(Vector3(10.5, 0.16, 0.16)), wood, Vector3(0, 2.95, -2.8))
	_mesh(root, _box(Vector3(10.0, 0.14, 3.8)), trim, Vector3(0, 2.75, 0.2))
	for x in [-3.5, 0.0, 3.5]:
		_mesh(root, _cylinder(0.28, 0.62, WOOD, 10), _material(WOOD), Vector3(x, 0.62, 1.2))
		_mesh(root, _cylinder(0.42, 0.10, TERRACOTTA, 12), trim, Vector3(x, 1.05, 1.2))

static func _build_spa(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(Color("#d8e8df"))
	var accent: StandardMaterial3D = _material(WATER)
	_mesh(root, _box(Vector3(12.0, 0.30, 8.5)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(11.0, 4.0, 7.5)), wall, Vector3(0, 2.25, 0))
	_roof(root, 12.5, 9.0, 0.85, 4.25, _material(DEEP_GREEN))
	_mesh(root, _cylinder(2.2, 0.22, WATER, 20), accent, Vector3(0, 0.28, 0.5))
	_mesh(root, _box(Vector3(3.6, 0.18, 2.4)), accent, Vector3(-3.2, 0.35, 1.0), Vector3.ONE, Vector3(0, 0.05, 0))
	for x in [-3.5, 3.5]:
		_mesh(root, _sphere(0.35, FLOWER_PINK), _material(FLOWER_PINK), Vector3(x, 0.55, -2.5))

static func _build_lodge(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(WOOD_DARK)
	_mesh(root, _box(Vector3(16.0, 0.35, 11.0)), accent, Vector3(0, 0.18, 0))
	_mesh(root, _box(Vector3(15.0, 5.5, 10.0)), wall, Vector3(0, 3.05, 0))
	_roof(root, 16.5, 11.5, 1.15, 5.75, _material(TERRACOTTA))
	for x in [-5.5, -1.8, 1.8, 5.5]:
		_window(root, Vector3(x, 3.2, -5.25), Vector3(1.1, 1.5, 0.10), _material(Color("#9bc6bd")))
	_mesh(root, _box(Vector3(3.2, 2.6, 0.24)), accent, Vector3(0, 1.55, -5.28))
	_steps(root, Vector3(0, 0.40, -5.65), 4, 3.0)
	if variant >= 1:
		_mesh(root, _box(Vector3(5.0, 4.0, 6.0)), wall, Vector3(8.5, 2.5, 0))
		_roof(root, 6.0, 6.8, 0.85, 4.4, _material(DEEP_GREEN))

static func _foliage() -> ShaderMaterial:
	if _foliage_material == null:
		_foliage_material = ShaderMaterial.new()
		_foliage_material.shader = preload("res://shaders/resort_foliage.gdshader")
	return _foliage_material

# Shared, smoothly shaded, irregular leaf clusters: four meshes batch across trees.
static func _canopy(variant: int, pine: bool = false) -> ArrayMesh:
	var key: String = "canopy:%d:%s" % [variant % 4,str(pine)]
	if _meshes.has(key): return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4721 + variant % 4
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var source: Array = _sphere(1.0,GREEN,24).get_mesh_arrays()
	var sv: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	var lobes: int = 18 if pine else 22
	for lobe in range(lobes):
		var center: Vector3
		var scale_blob: Vector3
		if pine:
			var tier: int = lobe / 3
			var angle: float = lobe * 2.4
			var radius: float = 1.2 - tier * 0.16
			center = Vector3(cos(angle)*radius*0.48,2.0+tier*0.66,sin(angle)*radius*0.48)
			scale_blob = Vector3(radius,0.95,radius)
		else:
			var angle: float = lobe * 2.4
			var radius: float = 1.2 if lobe < 15 else 0.55
			center = Vector3(cos(angle)*radius,3.15+rng.randf_range(-0.35,0.65)+(0.7 if lobe>=15 else 0.0),sin(angle)*radius)
			scale_blob = Vector3(rng.randf_range(0.65,0.95),rng.randf_range(0.6,0.95),rng.randf_range(0.65,0.95))
		var tint: Color = DEEP_GREEN.lerp(GREEN,rng.randf_range(0.25,0.9))
		for idx in indices:
			var point: Vector3 = sv[idx]
			var bump: float = 1.0+0.025*sin(point.x*11.0+point.y*7.0)*cos(point.z*9.0+point.y*5.0)
			var pos: Vector3 = center+point*scale_blob*bump
			verts.append(pos)
			normals.append((sn[idx]/scale_blob).normalized())
			var top: float = clampf(point.y*0.18+0.88,0.66,1.1)
			colors.append(Color(tint.r*top,tint.g*top,tint.b*top,1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=verts
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_COLOR]=colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes[key]=mesh
	return mesh

static func _build_oak_tree(root: Node3D, variant: int) -> void:
	if _build_gen2_tree(root, "oak", variant):
		return
	root.scale=Vector3.ONE*(2.8+(variant%4)*0.16)
	_mesh(root,_cylinder(0.23,3.2,WOOD_DARK,16),_family("prop.bark"),Vector3(0,1.6,0))
	for side in [-1,1]:
		_mesh(root,_cylinder(0.12,1.8,WOOD,12),_family("arch.timber"),Vector3(side*0.42,2.25,0),Vector3.ONE,Vector3(0,0,side*-0.48))
	_mesh(root,_canopy(variant),_foliage())

static func _build_pine_tree(root: Node3D, variant: int) -> void:
	if _build_gen2_tree(root, "pine", variant):
		return
	root.scale=Vector3.ONE*(2.6+(variant%4)*0.13)
	_mesh(root,_cylinder(0.20,4.1,WOOD_DARK,16),_family("prop.bark"),Vector3(0,2.05,0))
	_mesh(root,_canopy(variant,true),_foliage())

static func _build_gen2_tree(root: Node3D, species: String, variant: int) -> bool:
	if not gen2_trees_enabled or not TreeAssets.available():
		return false
	var v: int = variant % 4
	var thresholds: Dictionary = TreeAssets.lod_thresholds()
	root.scale = Vector3.ONE * TreeAssets.variant_scale(species, v)
	var bark_material: StandardMaterial3D = _family("prop.bark")
	var foliage_material: ShaderMaterial = _foliage()
	var lod_ranges: Array = [
		{"lod": "near", "begin": 0.0, "end": float(thresholds.get("near_end", 85.0))},
		{"lod": "mid", "begin": float(thresholds.get("mid_begin", 75.0)), "end": float(thresholds.get("mid_end", 190.0))},
		{"lod": "far", "begin": float(thresholds.get("far_begin", 175.0)), "end": float(thresholds.get("far_end", 950.0))},
	]
	for entry in lod_ranges:
		var bark: ArrayMesh = TreeAssets.load_part(species, v, str(entry.lod), "bark")
		var foliage: ArrayMesh = TreeAssets.load_part(species, v, str(entry.lod), "foliage")
		if bark == null or foliage == null:
			return false
		var bark_instance: MeshInstance3D = _mesh(root, bark, bark_material)
		bark_instance.visibility_range_begin = float(entry.begin)
		bark_instance.visibility_range_end = float(entry.end)
		var foliage_instance: MeshInstance3D = _mesh(root, foliage, foliage_material)
		foliage_instance.visibility_range_begin = float(entry.begin)
		foliage_instance.visibility_range_end = float(entry.end)
	root.set_meta("skip_bake", true)
	return true

static func _build_desert_shrub(root: Node3D, variant: int) -> void:
	root.scale = Vector3.ONE * (1.2 + (variant % 3) * 0.1)
	var scrub: Color = Color("#8a6a48")
	_mesh(root, _cylinder(0.12, 0.55, WOOD_DARK, 8), _material(WOOD_DARK), Vector3(0, 0.28, 0))
	for offset in [Vector3(-0.35, 0.55, 0), Vector3(0.28, 0.62, -0.18), Vector3(0.05, 0.72, 0.22)]:
		_mesh(root, _sphere(0.42, scrub), _material(scrub), offset)

static func _build_dune_grass(root: Node3D, variant: int) -> void:
	root.scale = Vector3.ONE * (1.0 + (variant % 4) * 0.08)
	var grass: Color = Color("#b8b070")
	for angle in range(0, 360, 40):
		var radians: float = deg_to_rad(float(angle + variant * 7))
		_mesh(root, _box(Vector3(0.06, 0.55, 0.06)), _material(grass), Vector3(cos(radians) * 0.18, 0.28, sin(radians) * 0.18), Vector3.ONE, Vector3(0.15, 0, radians))

static func _build_log(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.42, 2.8, WOOD, 10), _material(WOOD), Vector3(0, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.32, 0.08, CREAM, 10), _material(CREAM), Vector3(-1.42, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.32, 0.08, CREAM, 10), _material(CREAM), Vector3(1.42, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))

static func _build_boulder(root: Node3D, variant: int) -> void:
	var stone: StandardMaterial3D = _family("prop.stone")
	_mesh(root, _sphere(1.0, Color("#777b70")), stone, Vector3(0, 0.72, 0), Vector3(1.45, 0.82, 1.05))
	_mesh(root, _sphere(0.35, Color("#9a9c8a")), stone, Vector3(-0.35, 1.30, -0.40), Vector3(1.2, 0.35, 0.8))

static func _build_pergola(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	for x in [-2.2, 2.2]:
		for z in [-1.6, 1.6]:
			_mesh(root, _box(Vector3(0.25, 3.4, 0.25)), wood, Vector3(x, 1.7, z))
	for x in [-1.5, 0, 1.5]:
		_mesh(root, _box(Vector3(0.22, 0.24, 3.8)), wood, Vector3(x, 3.38, 0))
	_mesh(root, _box(Vector3(4.6, 0.16, 3.8)), _material(GREEN), Vector3(0, 3.00, 0))
	_build_flower_ring(root, 0.0)

static func _build_fountain(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(1.55, 0.24, CREAM, 20), _material(CREAM), Vector3(0, 0.12, 0))
	_mesh(root, _cylinder(1.35, 0.18, WATER, 20), _material(WATER), Vector3(0, 0.28, 0))
	_mesh(root, _cylinder(0.24, 1.35, CREAM, 14), _material(CREAM), Vector3(0, 0.95, 0))
	_mesh(root, _cylinder(0.62, 0.18, CREAM, 16), _material(CREAM), Vector3(0, 1.62, 0))
	var spray_anchor := Node3D.new()
	spray_anchor.name = "SprayAnchor"
	spray_anchor.position = Vector3(0, 1.88, 0)
	root.add_child(spray_anchor)
	_mesh(spray_anchor, _sphere(0.18, WATER), _material(WATER), Vector3(0, 0.0, 0))
	for a in range(0, 360, 45):
		var radians: float = deg_to_rad(float(a))
		_mesh(spray_anchor, _sphere(0.10, WATER), _material(WATER), Vector3(cos(radians) * 0.72, -0.52, sin(radians) * 0.72))

static func _build_flower_bed(root: Node3D, variant: int) -> void:
	_mesh(root,_box(Vector3(4.2,0.22,1.7)),_material(WOOD),Vector3(0,0.11,0))
	var rng := RandomNumberGenerator.new()
	rng.seed=941+variant
	for i in range(17):
		var p := Vector3(rng.randf_range(-1.8,1.8),rng.randf_range(0.4,0.65),rng.randf_range(-0.6,0.6))
		_mesh(root,_sphere(0.28,GREEN),_material(GREEN),p-Vector3.UP*0.15,Vector3(1.2,0.8,1))
		var color: Color = [FLOWER_PINK,FLOWER_YELLOW,FLOWER_BLUE][i%3]
		_mesh(root,_sphere(0.14,color),_material(color),p+Vector3.UP*0.18,Vector3(1,0.65,1))
		_mesh(root,_sphere(0.045,CREAM),_material(CREAM),p+Vector3.UP*0.27)

static func _build_topiary(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.28, 1.15, WOOD, 10), _material(WOOD), Vector3(0, 0.58, 0))
	_mesh(root, _sphere(0.75, DEEP_GREEN), _material(DEEP_GREEN), Vector3(0, 1.42, 0))
	_mesh(root, _sphere(0.50, GREEN), _material(GREEN), Vector3(0, 2.10, 0))

static func _build_gazebo(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	for a in range(0, 360, 60):
		var radians: float = deg_to_rad(float(a))
		_mesh(root, _box(Vector3(0.20, 2.65, 0.20)), wood, Vector3(cos(radians) * 1.55, 1.33, sin(radians) * 1.55))
	_mesh(root, _cylinder(1.90, 0.16, WOOD, 6), _material(WOOD), Vector3(0, 2.75, 0))
	_mesh(root, _cone(2.2, 1.55, TERRACOTTA), _material(TERRACOTTA), Vector3(0, 3.58, 0))
	_mesh(root, _cylinder(1.22, 0.16, CREAM, 16), _material(CREAM), Vector3(0, 0.28, 0))

static func _build_palm(root: Node3D, variant: int) -> void:
	_mesh(root,_cylinder(0.25,6.6,WOOD,18),_material(WOOD),Vector3(-0.16,3.3,0),Vector3.ONE,Vector3(0,0,0.05))
	for ring in range(17):
		_mesh(root,_cylinder(0.27,0.055,WOOD_DARK,18),_material(WOOD_DARK),Vector3(-ring*0.018,0.3+ring*0.37,0))
	for leaf in range(10):
		var angle: float = leaf*TAU/10+variant*0.2
		var direction := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-sin(angle),0,cos(angle))
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		for step in range(9):
			var points: Array[Vector3] = []
			for k in [step,step+1]:
				var t: float = k/9.0
				var center := Vector3(-0.33,6.5,0)+direction*t*3.1+Vector3.UP*(sin(t*PI)*0.7-t*t*1.1)
				var width: float = sin(t*PI)*0.43
				points.append(center-across*width)
				points.append(center+across*width)
			for index in [0,2,1,1,2,3,1,2,0,3,2,1]:
				verts.append(points[index])
				normals.append(Vector3.UP)
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=verts
		arrays[Mesh.ARRAY_NORMAL]=normals
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		_mesh(root,mesh,_material(GREEN if leaf%2 else DEEP_GREEN))
	_mesh(root,_sphere(0.4,WOOD_DARK),_material(WOOD_DARK),Vector3(-0.33,6.3,0))

static func _build_bench(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _family("arch.timber")
	_mesh(root, _box(Vector3(3.2, 0.22, 0.58)), wood, Vector3(0, 1.05, 0))
	_mesh(root, _box(Vector3(3.2, 0.22, 0.58)), wood, Vector3(0, 1.60, 0.20), Vector3.ONE, Vector3(-0.28, 0, 0))
	for x in [-1.2, 1.2]:
		_mesh(root, _box(Vector3(0.18, 1.0, 0.18)), _material(WOOD_DARK), Vector3(x, 0.50, 0))
	_mesh(root, _box(Vector3(3.5, 0.10, 0.10)), _material(CREAM), Vector3(0, 1.86, 0.20))

static func _build_pond(root: Node3D, variant: int) -> void:
	_mesh(root, _sphere(2.0, WATER), _material(WATER, 0.2), Vector3(0, 0.20, 0), Vector3(1.5, 0.14, 1.0))
	_mesh(root, _sphere(2.15, GREEN), _material(GREEN), Vector3(0, 0.06, 0), Vector3(1.55, 0.06, 1.05))
	for x in [-1.6, 1.6]:
		_mesh(root, _sphere(0.35, Color("#777b70")), _material(Color("#777b70")), Vector3(x, 0.20, 0.2))

static func _build_flag(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.035, 2.7, CREAM, 8), _material(CREAM), Vector3(0, 1.35, 0))
	var cloth := _mesh(root, _box(Vector3(0.70, 0.38, 0.05)), _material(TERRACOTTA), Vector3(0.34, 2.35, 0.0), Vector3.ONE, Vector3(0, 0, 0.05))
	cloth.name = "Cloth"
	_mesh(root, _cylinder(0.22, 0.08, CREAM, 12), _material(CREAM), Vector3(0, 0.06, 0))

static func _build_stake(root: Node3D, variant: int) -> void:
	var color: Color = WHITE if variant == 0 else Color("d25555")
	_mesh(root, _cylinder(0.05, 1.1, color, 8), _material(color), Vector3(0, 0.55, 0))
	_mesh(root, _cylinder(0.12, 0.06, color, 10), _material(color), Vector3(0, 0.06, 0))

static func _build_bridge(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(4.8, 0.35, 3.0)), _material(WOOD), Vector3(0, 0.45, 0))
	for x in [-2.1, 2.1]:
		for z in [-1.15, 1.15]:
			_mesh(root, _box(Vector3(0.18, 1.15, 0.18)), _material(WOOD_DARK), Vector3(x, 1.10, z))
		_mesh(root, _box(Vector3(0.18, 0.18, 4.5)), _material(WOOD_DARK), Vector3(x, 1.55, 0))
	for x in [-1.2, 0, 1.2]:
		_mesh(root, _box(Vector3(0.12, 0.16, 2.65)), _material(CREAM), Vector3(x, 0.70, 0))

static func _build_sign(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(0.20, 2.0, 0.20)), _material(WOOD_DARK), Vector3(0, 1.0, 0))
	_mesh(root, _box(Vector3(2.1, 0.72, 0.16)), _material(TERRACOTTA), Vector3(0, 2.02, 0))
	_mesh(root, _box(Vector3(1.6, 0.10, 0.05)), _material(CREAM), Vector3(0, 2.02, -0.11))

static func _build_generic_prop(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(1.4, 1.0, 1.4)), _material(WOOD), Vector3(0, 0.5, 0))
	_mesh(root, _sphere(0.55, GREEN), _material(GREEN), Vector3(0, 1.35, 0))

static func _build_flower_ring(root: Node3D, y: float) -> void:
	for a in range(0, 360, 45):
		var radians: float = deg_to_rad(float(a))
		var p: Vector3 = Vector3(cos(radians) * 2.0, y + 0.42, sin(radians) * 1.45)
		_mesh(root, _sphere(0.22, FLOWER_YELLOW), _material(FLOWER_YELLOW), p)

static func _limb(parent: Node3D, name_value: String, position_value: Vector3, size: Vector3, material: StandardMaterial3D) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = name_value
	parent.add_child(pivot)
	var limb := CapsuleMesh.new()
	limb.radius=size.x*0.52
	limb.height=size.y
	limb.radial_segments=12
	limb.rings=4
	_mesh(pivot,limb,material,Vector3(0,-size.y*0.28,0))
	pivot.position = position_value
	return pivot

static func _steps(root: Node3D, center: Vector3, count: int, width: float) -> void:
	for i in range(count):
		_mesh(root, _box(Vector3(width - float(i) * 0.25, 0.18, 0.48)), _material(CREAM), center + Vector3(0, float(i) * 0.18, float(i) * 0.42))

static func _window(root: Node3D, position_value: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	var frame: StandardMaterial3D = _material(WOOD_DARK)
	_mesh(root,_box(size+Vector3(0.20,0.20,0.03)),frame,position_value+Vector3(0,0,0.025))
	_mesh(root,_box(size),_material(Color("#bdc9ab"),0.22),position_value-Vector3(0,0,0.025))
	for x in [-0.5,0.0,0.5]:
		_mesh(root,_box(Vector3(0.055,size.y+0.08,0.09)),frame,position_value+Vector3(x*size.x,0,-0.08))
	_mesh(root,_box(Vector3(size.x+0.1,0.07,0.09)),frame,position_value+Vector3(0,0,-0.08))
	_mesh(root,_box(Vector3(size.x+0.32,0.12,0.30)),_material(CREAM),position_value+Vector3(0,-size.y*0.5,-0.08))

static func _roof(root: Node3D, width: float, depth: float, thickness: float, y: float, material: StandardMaterial3D) -> void:
	var angle: float = 0.55
	var rise: float = width * 0.5 * tan(angle)
	var pitch_length: float = width * 0.5 / cos(angle)
	var slab: float = thickness * 0.3
	_mesh(root, _box(Vector3(pitch_length, slab, depth + 0.7)), material, Vector3(-width * 0.25, y + rise * 0.5, 0), Vector3.ONE, Vector3(0, 0, angle))
	_mesh(root, _box(Vector3(pitch_length, slab, depth + 0.7)), material, Vector3(width * 0.25, y + rise * 0.5, 0), Vector3.ONE, Vector3(0, 0, -angle))
	_mesh(root, _box(Vector3(0.26, slab, depth + 0.8)), _material(TERRACOTTA_DARK), Vector3(0, y + rise, 0))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-width*0.45,y,-depth*0.46),Vector3(width*0.45,y,-depth*0.46),Vector3(0,y+rise,-depth*0.46),Vector3(width*0.45,y,depth*0.46),Vector3(-width*0.45,y,depth*0.46),Vector3(0,y+rise,depth*0.46)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	var gable=ArrayMesh.new()
	gable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_mesh(root,gable,_material(CREAM))
	# Fascia and regular shingle courses make the silhouette read at close zoom.
	for side in [-1,1]:
		for z in [-depth*0.5-0.36,depth*0.5+0.36]:
			_mesh(root,_box(Vector3(pitch_length+0.12,0.14,0.12)),_material(WOOD_DARK),Vector3(side*width*0.25,y+rise*0.5,z),Vector3.ONE,Vector3(0,0,-side*angle))
		for row in range(1,9):
			var t: float = row/9.0
			_mesh(root,_box(Vector3(0.055,0.05,depth+0.72)),_material(TERRACOTTA_DARK),Vector3(side*width*0.5*t,y+rise*(1.0-t)+slab*0.65,0),Vector3.ONE,Vector3(0,0,-side*angle))
		for row in range(1,8):
			var t: float = (row+0.5)/9.0
			for column in range(1,int(depth/0.8)):
				var z: float = -depth*0.5+column*0.8+(0.4 if row%2 else 0.0)
				_mesh(root,_box(Vector3(pitch_length/9.5,0.025,0.025)),_material(TERRACOTTA_DARK),Vector3(side*width*0.5*t,y+rise*(1.0-t)+slab*0.63,z),Vector3.ONE,Vector3(0,0,-side*angle))
	for z in [-depth*0.46-0.03,depth*0.46+0.03]:
		_mesh(root,_box(Vector3(0.16,rise,0.12)),_material(WOOD_DARK),Vector3(0,y+rise*0.5,z))
		_mesh(root,_box(Vector3(width*0.9,0.16,0.12)),_material(WOOD_DARK),Vector3(0,y,z))



static func tree_shadow_mesh(pine: bool, variant: int = 0) -> ArrayMesh:
	var key: String = "tree_shadow:%s:%d" % [str(pine), variant % 4]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	if gen2_trees_enabled:
		var shipped: ArrayMesh = TreeAssets.shadow_mesh(pine, variant)
		if shipped != null:
			_meshes[key] = shipped
			return shipped
	if _meshes.has("tree_shadow:%s:0" % str(pine)):
		return _meshes["tree_shadow:%s:0" % str(pine)] as ArrayMesh
	var legacy_key: String = "tree_shadow:%s" % str(pine)
	if _meshes.has(legacy_key):
		return _meshes[legacy_key] as ArrayMesh
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	if pine:
		_append_shadow_cone(verts, normals, indices, Vector3(0, 2.0, 0), Vector3(1.05, 2.2, 1.05), 10)
		_append_shadow_cone(verts, normals, indices, Vector3(0, 3.35, 0), Vector3(0.82, 1.55, 0.82), 10)
		_append_shadow_cone(verts, normals, indices, Vector3(0, 4.35, 0), Vector3(0.55, 1.15, 0.55), 8)
		_append_shadow_cylinder(verts, normals, indices, Vector3(0, 1.05, 0), 0.18, 2.1, 8)
	else:
		_append_shadow_sphere(verts, normals, indices, Vector3(0, 3.15, 0), Vector3(1.55, 1.25, 1.55), 12)
		_append_shadow_sphere(verts, normals, indices, Vector3(0, 4.05, 0), Vector3(1.05, 0.95, 1.05), 10)
		_append_shadow_sphere(verts, normals, indices, Vector3(0.55, 2.85, 0.35), Vector3(0.75, 0.72, 0.75), 8)
		_append_shadow_cylinder(verts, normals, indices, Vector3(0, 0.95, 0), 0.21, 1.9, 8)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	_meshes[legacy_key] = mesh
	return mesh

static func _append_shadow_sphere(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	scale_value: Vector3,
	segments: int,
) -> void:
	var base: int = verts.size()
	var source: Array = _sphere(1.0, Color.WHITE, segments).get_mesh_arrays()
	var sv: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var mesh_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	for i in range(sv.size()):
		verts.append(center + sv[i] * scale_value)
		normals.append((sn[i] / scale_value).normalized())
	for idx in mesh_indices:
		indices.append(base + idx)

static func _append_shadow_cone(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	scale_value: Vector3,
	segments: int,
) -> void:
	var base: int = verts.size()
	var source: Array = _cone(1.0, 2.0, Color.WHITE, segments).get_mesh_arrays()
	var sv: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var mesh_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	for i in range(sv.size()):
		verts.append(center + sv[i] * scale_value)
		normals.append((sn[i] / scale_value).normalized())
	for idx in mesh_indices:
		indices.append(base + idx)

static func _append_shadow_cylinder(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	radius: float,
	height: float,
	segments: int,
) -> void:
	var base: int = verts.size()
	var source: Array = _cylinder(radius, height, Color.WHITE, segments).get_mesh_arrays()
	var sv: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var sn: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var mesh_indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
	for i in range(sv.size()):
		verts.append(center + sv[i])
		normals.append(sn[i])
	for idx in mesh_indices:
		indices.append(base + idx)

static func _vertex_self_occlusion(normal: Vector3, position: Vector3) -> float:
	var cavity: float = clampf(1.0 - normal.y, 0.0, 1.0)
	var overhang: float = clampf((1.2 - position.y) * 0.18, 0.0, 0.35)
	var inset: float = clampf(absf(normal.x * normal.z) * 0.55, 0.0, 0.22)
	return clampf(1.0 - cavity * 0.28 - overhang - inset, 0.48, 1.0)

static func _tint_with_occlusion(color: Color, occlusion: float) -> Color:
	return Color(color.r * occlusion, color.g * occlusion, color.b * occlusion, color.a)

static func _occlusion_texture_resource() -> NoiseTexture2D:
	if _occlusion_texture == null:
		_occlusion_texture = NoiseTexture2D.new()
		_occlusion_texture.width = 128
		_occlusion_texture.height = 128
		_occlusion_texture.seamless = true
		var noise := FastNoiseLite.new()
		noise.frequency = 0.24
		noise.fractal_octaves = 4
		_occlusion_texture.noise = noise
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.42, 0.42, 0.42))
		ramp.set_color(1, Color.WHITE)
		_occlusion_texture.color_ramp = ramp
	return _occlusion_texture

static func _mesh(parent: Node3D, mesh: Mesh, material: Material, position_value: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation = rotation_value
	parent.add_child(instance)
	return instance

static func apply_season(index: int) -> void:
	var clamped: int = GraphicsPalette.clamp_season(index)
	_foliage().set_shader_parameter("season_color", GraphicsPalette.foliage_season_target(clamped))
	_foliage().set_shader_parameter("season_mix", GraphicsPalette.foliage_season_mix(clamped))
	MaterialLibrary.apply_season(clamped)
	var mix_amount: float = GraphicsPalette.foliage_season_mix_raw(clamped)
	for base_color in [GREEN, DEEP_GREEN]:
		var material := _material(base_color)
		var roughness_before: float = material.roughness
		var metallic_before: float = material.metallic
		material.albedo_color = base_color.lerp(GraphicsPalette.foliage_season_target(clamped), mix_amount)
		material.roughness = roughness_before
		material.metallic = metallic_before

static func _material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = color.to_html(false) + ":" + str(roughness) + ":" + str(metallic)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color in [WOOD,WOOD_DARK,CREAM,TERRACOTTA,TERRACOTTA_DARK]:
		if _grain_texture == null:
			_grain_texture = NoiseTexture2D.new()
			_grain_texture.width=128
			_grain_texture.height=128
			_grain_texture.seamless=true
			var grain := FastNoiseLite.new()
			grain.frequency=0.18
			grain.fractal_octaves=3
			_grain_texture.noise=grain
			var ramp := Gradient.new()
			ramp.set_color(0,Color(0.73,0.73,0.73))
			ramp.set_color(1,Color.WHITE)
			_grain_texture.color_ramp=ramp
		material.albedo_texture=_grain_texture
		material.uv1_triplanar=true
		material.uv1_scale=Vector3(0.5,2.0,0.5) if color in [WOOD,WOOD_DARK] else Vector3.ONE*0.7
		material.ao_enabled = true
		material.ao_texture = _occlusion_texture_resource()
		material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
		material.ao_light_affect = 0.62
	_materials[key] = material
	return material

static func _box(size: Vector3) -> BoxMesh:
	var key: String = "box:" + str(size)
	if _meshes.has(key):
		return _meshes[key] as BoxMesh
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_meshes[key] = mesh
	return mesh

static func _cylinder(radius: float, height: float, color: Color, segments: int = 12) -> CylinderMesh:
	var key: String = "cyl:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as CylinderMesh
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	_meshes[key] = mesh
	return mesh

static func _cone(radius: float, height: float, color: Color, segments: int = 12) -> CylinderMesh:
	var key: String = "cone:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as CylinderMesh
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	_meshes[key] = mesh
	return mesh

static func _sphere(radius: float, color: Color, segments: int = 24) -> SphereMesh:
	var key: String = "sphere:" + str(radius) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as SphereMesh
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 12
	_meshes[key] = mesh
	return mesh
