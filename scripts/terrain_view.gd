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
var cover_root = Node3D.new()
var overlay_mesh: MeshInstance3D
var analytics_source: AnalyticsGrid
var overlay = "none"
var _horizon_material: ShaderMaterial
var _turf_texture: ImageTexture
var _detail_texture: ImageTexture
var _pattern_texture: ImageTexture
var _pattern_image: Image
var _contour_texture: ImageTexture
var _contour_image: Image
var _water_field_texture: ImageTexture
var _water_ripples: WaterRipplePool = WaterRipplePool.new()
var _distant_veg_material: ShaderMaterial
var _cloud_material: ShaderMaterial
var _cloud_layer: MeshInstance3D
var _season_index: int = 1
var _graphics: GraphicsSettings = GraphicsSettings.defaults()
var _reflections: ReflectionProbesClass
var _planar: PlanarReflectionsClass
var _planar_view_projection: Projection = Projection()
var _planar_plane_y: float = 0.0
var _pending_dirty_chunks: Dictionary = {}
var _cover_regions: Dictionary = {}
var _pending_cover_regions: Dictionary = {}
const DIRTY_CHUNKS_PER_FRAME: int = 2
const COVER_REGIONS_PER_FRAME: int = 4
const ReflectionProbesClass = preload("res://scripts/graphics_reflection_probes.gd")
const PlanarReflectionsClass = preload("res://scripts/graphics_planar_reflections.gd")

func _process(_dt: float) -> void:
	_process_dirty_chunks(DIRTY_CHUNKS_PER_FRAME)
	if water_material != null:
		_water_ripples.apply_to_material(water_material, _cosmetic_time())
	_process_dirty_cover_regions(COVER_REGIONS_PER_FRAME)

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
	_update_water_field_maps(not model.changed_surface_chunks.is_empty() or model._water_dirty_full)

func _update_water_field_maps(full: bool) -> void:
	if model == null:
		return
	if full:
		model.mark_water_field_dirty()
	var image: Image = WaterField.build_image(model)
	if _water_field_texture == null:
		_water_field_texture = ImageTexture.create_from_image(image)
		ground_material.set_shader_parameter("water_field", _water_field_texture)
		water_material.set_shader_parameter("water_field", _water_field_texture)
	else:
		_water_field_texture.update(image)
	_apply_water_shader_quality()
	_water_ripples.apply_to_material(water_material, _cosmetic_time())

func _cosmetic_time() -> float:
	return float(Time.get_ticks_msec()) / 1000.0

func _apply_water_shader_quality() -> void:
	refresh_water_reflection_state()

func refresh_water_reflection_state() -> void:
	if water_material == null:
		return
	water_material.set_shader_parameter("wave_detail", _graphics.water_wave_detail)
	var reflection_ready: bool = false
	var planar_active: bool = _graphics.reflection_mode == "planar"
	if planar_active and _planar != null:
		reflection_ready = _planar.has_water_texture()
	elif _graphics.reflection_mode == "probe" and _reflections != null:
		reflection_ready = _reflections.has_water_texture()
	water_material.set_shader_parameter("planar_reflection", planar_active and reflection_ready)
	water_material.set_shader_parameter("reflection_plane_y", _planar_plane_y)
	water_material.set_shader_parameter("reflection_view_projection", _planar_view_projection)
	water_material.set_shader_parameter(
		"use_reflection",
		reflection_ready and _graphics.water_reflection_strength > 0.0,
	)
	water_material.set_shader_parameter("reflection_strength", _graphics.water_reflection_strength)
	_water_ripples.configure(_graphics.water_ripple_cap)

func set_planar_reflection_matrix(view_projection: Projection, plane_y: float) -> void:
	_planar_view_projection = view_projection
	_planar_plane_y = plane_y
	if water_material != null:
		water_material.set_shader_parameter("reflection_view_projection", _planar_view_projection)
		water_material.set_shader_parameter("reflection_plane_y", _planar_plane_y)

func set_reflection_texture(texture: Texture2D) -> void:
	if water_material == null:
		return
	water_material.set_shader_parameter("reflection_map", texture)

func submit_water_ripple(body_id: int, world_pos: Vector3, start_time: float, radius: float, strength: float) -> bool:
	if water_material == null or model == null:
		return false
	var accepted: bool = _water_ripples.submit(body_id, world_pos, start_time, radius, strength, model)
	if accepted:
		_water_ripples.apply_to_material(water_material, start_time)
	return accepted

func clear_water_ripples() -> void:
	_water_ripples.clear()
	if water_material != null:
		_water_ripples.apply_to_material(water_material, _cosmetic_time())

func _update_pattern_maps(full: bool) -> void:
	if model == null:
		return
	if full or _pattern_image == null:
		_pattern_image = HoleMowing.build_pattern_image(model)
		if _pattern_texture == null:
			_pattern_texture = ImageTexture.create_from_image(_pattern_image)
			ground_material.set_shader_parameter("pattern_map", _pattern_texture)
			ground_material.set_shader_parameter("default_stripe_dir", Vector2(HoleMowing.DEFAULT_DIR.x, HoleMowing.DEFAULT_DIR.y))
		else:
			_pattern_texture.update(_pattern_image)
		return
	for chunk in model.changed_surface_chunks.keys():
		var key: Vector2i = chunk
		var x0: int = key.x * 16
		var z0: int = key.y * 16
		for z in range(z0, z0 + 16):
			for x in range(x0, x0 + 16):
				HoleMowing.write_cell_pattern(model, _pattern_image, z * 256 + x)
	if _pattern_texture != null and _pattern_image != null:
		_pattern_texture.update(_pattern_image)

func _update_contour_maps(full: bool) -> void:
	if model == null:
		return
	if full or _contour_image == null:
		_contour_image = CourseContours.build_render_mask(model.course_features, model)
		if _contour_texture == null:
			_contour_texture = ImageTexture.create_from_image(_contour_image)
			ground_material.set_shader_parameter("contour_map", _contour_texture)
			ground_material.set_shader_parameter("use_contour_map", model.course_features.size() > 0)
		else:
			_contour_texture.update(_contour_image)
			ground_material.set_shader_parameter("use_contour_map", model.course_features.size() > 0)

func refresh_contour_maps(full: bool = true) -> void:
	_update_contour_maps(full)

func refresh_mowing_patterns(full: bool = true) -> void:
	_update_pattern_maps(full)

func set_stripe_overview_fade(camera_size: float) -> void:
	if ground_material == null:
		return
	ground_material.set_shader_parameter("stripe_overview_fade", HoleMowing.overview_fade(camera_size))


const CHUNK_OVERLAYS: Array[String] = ["beauty", "access", "elevation", "wear"]
const HEAT_OVERLAYS: Array[String] = ["traffic", "cart_traffic", "waiting"]

func setup(data: TerrainModel) -> void:
	model = data
	ground_material = ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/resort_ground.gdshader")
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://shaders/resort_water.gdshader")
	_update_surface_maps()
	refresh_mowing_patterns(true)
	refresh_contour_maps(true)
	for key in GraphicsPalette.surface_colors_for_terrain(data):
		ground_material.set_shader_parameter(key, GraphicsPalette.surface_colors_for_terrain(data)[key])
	_bind_ground_material_details()
	_apply_water_color(data.water_color)
	_apply_water_shader_quality()
	add_child(object_root)
	add_child(hole_root)
	add_child(instance_root)
	add_child(cover_root)
	overlay_mesh = MeshInstance3D.new()
	overlay_mesh.name = "AnalyticsOverlay"
	add_child(overlay_mesh)
	overlay_mesh.visible = false
	for z in range(16):
		for x in range(16): rebuild_chunk(Vector2i(x,z))
	model.changed_chunks.clear()
	model.changed_surface_chunks.clear()
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
	_build_distant_vegetation()
	_build_cloud_layer()
	apply_atmosphere(_season_index, _graphics)
	_ensure_reflection_probes()
	_ensure_planar_reflections()
	sync_objects()
	sync_holes()
	_rebuild_all_cover_regions()

func apply_graphics_settings(settings: GraphicsSettings) -> void:
	_graphics = settings.duplicate_settings()
	_apply_water_shader_quality()
	apply_atmosphere(_season_index, _graphics)
	if _reflections != null:
		_reflections.apply_settings(_graphics, model)
	if _planar != null:
		_planar.apply_settings(_graphics, model)
	_rebuild_scenery_instances()
	_rebuild_all_cover_regions()

func mark_reflections_dirty() -> void:
	if _reflections != null:
		_reflections.notify_edit_burst()
	if _planar != null:
		_planar.notify_edit_burst()

func _ensure_planar_reflections() -> void:
	if _planar == null:
		_planar = PlanarReflectionsClass.new()
		_planar.name = "PlanarReflections"
		add_child(_planar)
	_planar.attach(self, _graphics)

func _ensure_reflection_probes() -> void:
	if _reflections == null:
		_reflections = ReflectionProbesClass.new()
		_reflections.name = "ReflectionProbes"
		add_child(_reflections)
	_reflections.attach(self, _graphics)

func apply_atmosphere(season: int, settings: GraphicsSettings) -> void:
	_season_index = season
	if _horizon_material != null:
		GraphicsAtmosphere.apply_shader_material(
			_horizon_material,
			GraphicsAtmosphere.horizon_shader_params(season, settings),
		)
	if _distant_veg_material != null:
		GraphicsAtmosphere.apply_shader_material(
			_distant_veg_material,
			GraphicsAtmosphere.distant_foliage_shader_params(season, settings),
		)
	if _cloud_material != null and is_instance_valid(_cloud_layer):
		var cloud: Dictionary = GraphicsAtmosphere.cloud_shader_params(season, settings)
		GraphicsAtmosphere.apply_shader_material(_cloud_material, cloud)
		_cloud_layer.visible = bool(cloud.get("enabled", false))

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

func _bind_ground_material_details() -> void:
	if ground_material == null:
		return
	var fairway: Dictionary = MaterialLibrary.detail_textures("course.fairway")
	var rough: Dictionary = MaterialLibrary.detail_textures("course.rough")
	var sand: Dictionary = MaterialLibrary.detail_textures("course.sand")
	if fairway.albedo == null or rough.albedo == null or sand.albedo == null:
		ground_material.set_shader_parameter("use_material_details", false)
		return
	ground_material.set_shader_parameter("fairway_detail", fairway.albedo)
	ground_material.set_shader_parameter("rough_detail", rough.albedo)
	ground_material.set_shader_parameter("sand_detail", sand.albedo)
	ground_material.set_shader_parameter("fairway_repeat", fairway.meters_per_repeat)
	ground_material.set_shader_parameter("rough_repeat", rough.meters_per_repeat)
	ground_material.set_shader_parameter("sand_repeat", sand.meters_per_repeat)
	ground_material.set_shader_parameter("use_material_details", true)

func set_season(index: int) -> void:
	_season_index = index
	var tint: Vector3 = GraphicsPalette.terrain_season_tint(index)
	ground_material.set_shader_parameter("season_tint", tint)
	apply_atmosphere(index, _graphics)
	mark_reflections_dirty()

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
	refresh_mowing_patterns(true)
	refresh_contour_maps(true)
	_update_water_field_maps(true)
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
	mark_reflections_dirty()
	if model.changed_chunks.is_empty(): return
	if not model.changed_surface_chunks.is_empty():
		_update_surface_maps()
		_update_pattern_maps(false)
		_update_contour_maps(true)
		_update_water_field_maps(true)
	# Water geometry extends one cell past its mask; rebuild bordering chunks too.
	var dirty: Dictionary = {}
	for key in model.changed_chunks:
		for dz in range(-1,2):
			for dx in range(-1,2):
				var neighbour: Vector2i = key + Vector2i(dx,dz)
				if chunks.has(neighbour): dirty[neighbour] = true
	for key in dirty: _pending_dirty_chunks[key] = true
	_queue_cover_regions_for_chunks(model.changed_chunks)
	model.changed_chunks.clear()
	model.changed_surface_chunks.clear()

func _process_dirty_chunks(budget: int) -> void:
	var count: int = 0
	for key in _pending_dirty_chunks.keys():
		rebuild_chunk(key)
		_pending_dirty_chunks.erase(key)
		count += 1
		if count >= budget:
			break

func rebuild_chunk(key: Vector2i) -> void:
	var verts = PackedVector3Array()
	var normals = PackedVector3Array()
	var colors = PackedColorArray()
	var water_verts = PackedVector3Array()
	var water_normals = PackedVector3Array()
	for z in range(key.y*16,key.y*16+16):
		for x in range(key.x*16,key.x*16+16):
			var type = model.surfaces[z*256+x]
			var col = model.palette[type] if type < model.palette.size() else GraphicsPalette.SURFACE_COLORS[type]
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
		# Editable terrain receives shadows but does not cast them globally: the
		# heightfield pass is costly and grazing-angle acne is hard to tune on slopes.
		# Package 10 evaluated bounded bank casting; keep OFF until a chunked caster exists.
		ground.cast_shadow=GraphicsShadow.terrain_cast_shadow_mode(_graphics.terrain_cast_shadows)
		root.add_child(ground)
	if not water_verts.is_empty():
		var water_mesh: MeshInstance3D = _mesh(water_verts, water_normals, PackedColorArray(), water_material)
		ReflectionProbesClass.tag_water_mesh(water_mesh)
		root.add_child(water_mesh)
	root.add_child(_contour_details(key))

func _contour_details(key: Vector2i) -> Node3D:
	var root := Node3D.new()
	if model.course_features.is_empty():
		return root
	var features: Array = model.contour_features_for_chunk(key)
	if features.is_empty():
		return root
	for feature_value in features:
		var feature: Dictionary = feature_value
		var kind: String = str(feature.get("kind", ""))
		var verts: PackedVector3Array = PackedVector3Array()
		if kind == "green":
			verts = CourseContours.collar_ribbon(feature, model)
		elif kind == "bunker":
			verts = CourseContours.lip_ribbon(feature, model)
		if verts.is_empty():
			continue
		var normals: PackedVector3Array = PackedVector3Array()
		normals.resize(verts.size())
		for index in range(verts.size()):
			normals[index] = Vector3.UP
		var color: Color = model.palette[2] if kind == "green" else model.palette[4]
		var colors: PackedColorArray = PackedColorArray()
		for index in range(verts.size()):
			colors.append(color.lightened(0.04 if index % 2 == 0 else -0.03))
		var mesh_node: MeshInstance3D = _mesh(verts, normals, colors, ground_material)
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mesh_node)
	return root

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

func sync_objects(rebuild_scenery: bool = true) -> void:
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
	if rebuild_scenery:
		_rebuild_scenery_instances()
	_queue_cover_regions_for_objects(model.objects)
	mark_reflections_dirty()

func _queue_cover_regions_for_chunks(chunks: Dictionary) -> void:
	for key in chunks.keys():
		_queue_cover_region(GroundCover.region_key_for_point(Vector3(float(key.x) * 64.0 + 32.0, 0.0, float(key.y) * 64.0 + 32.0)))

func _queue_cover_regions_for_objects(objects: Array) -> void:
	for obj_value in objects:
		var obj: Dictionary = obj_value
		_queue_cover_region(GroundCover.region_key_for_point(obj.pos))
		if obj.has("end"):
			_queue_cover_region(GroundCover.region_key_for_point(obj.end))

func _queue_cover_region(region: Vector2i) -> void:
	_pending_cover_regions[region] = true

func _process_dirty_cover_regions(budget: int) -> void:
	var count: int = 0
	for region in _pending_cover_regions.keys():
		_rebuild_cover_region(region)
		_pending_cover_regions.erase(region)
		count += 1
		if count >= budget:
			break

func _rebuild_all_cover_regions() -> void:
	for child in cover_root.get_children():
		child.free()
	_cover_regions.clear()
	_pending_cover_regions.clear()
	if model == null or not GroundCoverAssets.available():
		return
	var cols: int = ceili(TerrainModel.WIDTH / GroundCover.REGION_SIZE)
	for z in range(cols):
		for x in range(cols):
			_pending_cover_regions[Vector2i(x, z)] = true

func _rebuild_cover_region(region: Vector2i) -> void:
	if model == null or not GroundCoverAssets.available():
		return
	if _cover_regions.has(region):
		(_cover_regions[region] as Node3D).free()
		_cover_regions.erase(region)
	var batches: Array = GroundCover.build_region_batches(model, region, _graphics)
	if batches.is_empty():
		return
	var root := Node3D.new()
	root.name = "Cover_%d_%d" % [region.x, region.y]
	for batch_value in batches:
		var batch: Dictionary = batch_value
		var family: String = str(batch.get("family", ""))
		var instances: Array = batch.get("instances", [])
		if instances.is_empty():
			continue
		var groups: Dictionary = {}
		for row_value in instances:
			var row: Dictionary = row_value
			var variant: int = int(row.get("variant", 0))
			var key: String = "%d" % variant
			if not groups.has(key):
				groups[key] = []
			(groups[key] as Array).append(row)
		var thresholds: Dictionary = GroundCoverAssets.lod_thresholds()
		var material: Material = GroundCoverAssets.material_for(family)
		var shadow_mode: int = GroundCoverAssets.casts_shadow(family)
		for group_key in groups.keys():
			var group: Array = groups[group_key]
			var variant: int = int(group_key)
			var near_mesh: ArrayMesh = GroundCoverAssets.load_mesh(family, variant, "near")
			var far_mesh: ArrayMesh = GroundCoverAssets.load_mesh(family, variant, "far")
			if near_mesh == null:
				continue
			for lod_mesh_pair in [[near_mesh, float(thresholds.get("far_begin", 82.0)), float(thresholds.get("near_end", 95.0))], [far_mesh, float(thresholds.get("far_begin", 82.0)), _graphics.foliage_view_distance]]:
				var lod_mesh: ArrayMesh = lod_mesh_pair[0]
				if lod_mesh == null:
					continue
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = lod_mesh
				mm.instance_count = group.size()
				for i in range(group.size()):
					mm.set_instance_transform(i, (group[i] as Dictionary).get("transform", Transform3D.IDENTITY))
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				node.material_override = material
				node.lod_bias = _graphics.foliage_lod_bias
				node.visibility_range_begin = float(lod_mesh_pair[1])
				node.visibility_range_end = float(lod_mesh_pair[2])
				node.cast_shadow = shadow_mode
				root.add_child(node)
	cover_root.add_child(root)
	_cover_regions[region] = root

func refresh_chunk_overlay_budget(count: int = 16) -> void:
	if chunks.is_empty():
		return
	var keys: Array = chunks.keys()
	var start: int = int(Time.get_ticks_msec() / 2000) * count % keys.size()
	for offset in range(mini(count, keys.size())):
		rebuild_chunk(keys[(start + offset) % keys.size()])

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
	if color.is_equal_approx(Color("c3b589")) or color.is_equal_approx(Color("c9b083")):
		var node_mesh: MeshInstance3D = _mesh(vertices,normals,PackedColorArray(),MaterialLibrary.material("course.gravel"))
		node_mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return node_mesh
	material.shader=preload("res://shaders/resort_path.gdshader")
	material.set_shader_parameter("path_color",color)
	var node: MeshInstance3D = _mesh(vertices,normals,PackedColorArray(),material)
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

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
				var dist_norm: float = clampf((distance_edge - 120.0) / 780.0, 0.0, 1.0)
				var hill_col: Color = Color(model.palette[0]).lerp(
					GraphicsPalette.HORIZON_LAKE_TINT,
					clampf(distance_edge / 900.0, 0.0, 0.7),
				)
				colors.append(Color(hill_col.r, hill_col.g, hill_col.b, dist_norm))
	_horizon_material=ShaderMaterial.new()
	_horizon_material.shader=preload("res://shaders/resort_horizon.gdshader")
	var mesh: MeshInstance3D = _mesh(vertices,normals,colors,_horizon_material)
	mesh.name="Distant countryside"
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

const DISTANT_VEG_SEED: int = 1407
const DISTANT_VEG_LAYERS: Array[Dictionary] = [
	{"layer": 0, "ring_min": 380.0, "ring_max": 620.0, "count": 48, "height": 18.0, "radius": 5.5},
	{"layer": 1, "ring_min": 620.0, "ring_max": 920.0, "count": 64, "height": 24.0, "radius": 6.5},
	{"layer": 2, "ring_min": 920.0, "ring_max": 1280.0, "count": 40, "height": 30.0, "radius": 7.5},
]

func _distant_tree_mesh(height: float, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments: int = 4
	for i in range(segments):
		var a0: float = float(i) * TAU / float(segments)
		var a1: float = float(i + 1) * TAU / float(segments)
		st.set_normal(Vector3(0.0, 0.35, 0.92).normalized())
		st.add_vertex(Vector3(cos(a0) * radius, 0.0, sin(a0) * radius))
		st.set_normal(Vector3(0.0, 0.35, 0.92).normalized())
		st.add_vertex(Vector3(cos(a1) * radius, 0.0, sin(a1) * radius))
		st.set_normal(Vector3(0.0, 1.0, 0.0))
		st.add_vertex(Vector3(0.0, height, 0.0))
	return st.commit()

func _distant_vegetation_point(layer: Dictionary, index: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = DISTANT_VEG_SEED + int(layer.layer) * 1000 + index
	var angle: float = rng.randf() * TAU
	var radius: float = lerpf(float(layer.ring_min), float(layer.ring_max), rng.randf())
	var center := Vector3(512.0 + cos(angle) * radius, 0.0, 512.0 + sin(angle) * radius)
	center.y = _horizon_height(center) + rng.randf_range(0.0, 4.0)
	return center

func _build_distant_vegetation() -> void:
	var root := Node3D.new()
	root.name = "Distant vegetation"
	_distant_veg_material = ShaderMaterial.new()
	_distant_veg_material.shader = preload("res://shaders/resort_distant_foliage.gdshader")
	for layer in DISTANT_VEG_LAYERS:
		var mesh: ArrayMesh = _distant_tree_mesh(float(layer.height), float(layer.radius))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = int(layer.count)
		for i in range(int(layer.count)):
			var pos: Vector3 = _distant_vegetation_point(layer, i)
			var yaw: float = float((DISTANT_VEG_SEED + int(layer.layer) * 1000 + i) % 628) / 100.0
			var scale: float = lerpf(0.85, 1.15, float(i % 7) / 6.0)
			mm.set_instance_transform(
				i,
				Transform3D(Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3.ONE * scale), pos),
			)
		var instance := MultiMeshInstance3D.new()
		instance.name = "Layer%d" % int(layer.layer)
		instance.multimesh = mm
		instance.material_override = _distant_veg_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(instance)
	add_child(root)

func _build_cloud_layer() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4096.0, 4096.0)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = preload("res://shaders/resort_cloud_layer.gdshader")
	_cloud_layer = MeshInstance3D.new()
	_cloud_layer.name = "CloudLayer"
	_cloud_layer.mesh = plane
	_cloud_layer.material_override = _cloud_material
	_cloud_layer.position = Vector3(512.0, 92.0, 512.0)
	_cloud_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud_layer.visible = false
	add_child(_cloud_layer)


# Shadows-only canopy proxies keep foliage batches off the shadow pass.
# Revalidate silhouettes after package 07 species/LOD shadow meshes land.
func _tree_shadow_instances() -> void:
	var groups: Dictionary = {}
	for obj in model.objects:
		if obj.kind not in ["oak_tree","pine_tree"]: continue
		var source: Node3D = object_nodes.get(obj.id)
		if source == null: continue
		var pine: bool = obj.kind=="pine_tree"
		var variant: int = int(obj.id) % 4
		var region := Vector2i(int(obj.pos.x/128),int(obj.pos.z/128))
		var key: String = str(region)+str(pine)+":"+str(variant)
		if not groups.has(key): groups[key]={"pine":pine,"variant":variant,"transforms":[]}
		var record: Dictionary = obj
		var pos: Vector3 = record.pos
		pos.y = model.height_at(pos)
		var shadow_transform := Transform3D(Basis.from_euler(Vector3(0, float(record.get("rotation", 0.0)), 0)), pos)
		groups[key].transforms.append(shadow_transform)
	for group in groups.values():
		var mm := MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=AssetFactory.tree_shadow_mesh(group.pine, int(group.get("variant", 0)))
		mm.instance_count=group.transforms.size()
		for i in range(group.transforms.size()):mm.set_instance_transform(i,group.transforms[i])
		var node := MultiMeshInstance3D.new()
		node.multimesh=mm
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		instance_root.add_child(node)
