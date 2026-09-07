class_name GraphicsReflectionProbes
extends Node

## Managed reflection probes (package 12). Small explicit budget, deterministic placement.

const RendererComparisonClass = preload("res://scripts/renderer_comparison.gd")

const LAYER_SCENE: int = 1
const LAYER_WATER: int = 2
const LAYER_DYNAMIC: int = 4
const LAYER_HELPER: int = 8

const CAPTURE_MASK: int = LAYER_SCENE
const MAX_PROBES_HIGH: int = 1
const MAX_PROBES_STANDARD: int = 1
const DEBOUNCE_SEC: float = 0.35
const STRUCTURE_MARGIN_M: float = 56.0
const MIN_PROBE_EXTENT_M: float = 96.0
const PROBE_HEIGHT_PAD_M: float = 28.0

var _terrain_view: Node3D
var _settings: GraphicsSettings = GraphicsSettings.defaults()
var _probe_root: Node3D
var _probes: Array[ReflectionProbe] = []
var _test_marker: MeshInstance3D
var _viewport: SubViewport
var _capture_camera: Camera3D
var _water_texture: ViewportTexture
var _placements: Array[Dictionary] = []
var _dirty: bool = true
var _awaiting_capture: bool = false
var _debounce_left: float = 0.0
var _water_capture_enabled: bool = false
var _enabled: bool = false


static func probes_supported() -> bool:
	return RendererComparisonClass.reflection_probes_supported()


static func max_probe_count(settings: GraphicsSettings) -> int:
	if not probes_supported():
		return 0
	match settings.preset:
		GraphicsSettings.Preset.HIGH:
			return MAX_PROBES_HIGH
		GraphicsSettings.Preset.STANDARD:
			if settings.reflection_mode != "probe":
				return 0
			return MAX_PROBES_STANDARD
		_:
			return 0


static func layer_contract() -> Dictionary:
	return {
		"scene": LAYER_SCENE,
		"water": LAYER_WATER,
		"dynamic": LAYER_DYNAMIC,
		"helper": LAYER_HELPER,
		"capture_mask": CAPTURE_MASK,
	}


static func tag_water_mesh(node: MeshInstance3D) -> void:
	if node != null:
		node.layers = LAYER_WATER


static func tag_dynamic(node: Node3D) -> void:
	_apply_layer_recursive(node, LAYER_DYNAMIC)


static func tag_helper(node: Node3D) -> void:
	_apply_layer_recursive(node, LAYER_HELPER)


static func _apply_layer_recursive(node: Node, layer: int) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = layer
	for child in node.get_children():
		_apply_layer_recursive(child, layer)


func attach(terrain_view: Node3D, settings: GraphicsSettings) -> void:
	_terrain_view = terrain_view
	_settings = settings.duplicate_settings()
	_ensure_nodes()
	_rebuild()


func apply_settings(settings: GraphicsSettings, terrain: TerrainModel) -> void:
	_settings = settings.duplicate_settings()
	if terrain != null:
		_placements = _compute_placements(terrain, max_probe_count(_settings))
	_rebuild()


func mark_dirty() -> void:
	_dirty = true


func has_water_texture() -> bool:
	return _water_capture_enabled and _water_texture != null


func _ensure_nodes() -> void:
	if _probe_root == null:
		_probe_root = Node3D.new()
		_probe_root.name = "ReflectionProbeRoot"
		add_child(_probe_root)
	if _viewport == null:
		_viewport = SubViewport.new()
		_viewport.name = "WaterReflectionCapture"
		_viewport.disable_3d = false
		_viewport.transparent_bg = true
		_viewport.handle_input_locally = false
		_viewport.gui_disable_input = true
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(_viewport)
		_capture_camera = Camera3D.new()
		_capture_camera.name = "CaptureCamera"
		_capture_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_capture_camera.near = 4.0
		_capture_camera.far = 420.0
		_capture_camera.cull_mask = CAPTURE_MASK
		_viewport.add_child(_capture_camera)
		_water_texture = _viewport.get_texture()
	if _test_marker == null:
		_test_marker = _build_test_marker()
		add_child(_test_marker)


func _build_test_marker() -> MeshInstance3D:
	var sphere := MeshInstance3D.new()
	sphere.name = "ReflectionTestMarker"
	var mesh := SphereMesh.new()
	mesh.radius = 1.35
	mesh.height = 2.7
	sphere.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d8dde2")
	mat.metallic = 0.92
	mat.roughness = 0.12
	sphere.material_override = mat
	sphere.layers = LAYER_SCENE
	sphere.position = Vector3(205.0, 0.0, 318.0)
	return sphere


func _process(delta: float) -> void:
	if _terrain_view == null:
		return
	if _debounce_left > 0.0:
		_debounce_left = maxf(0.0, _debounce_left - delta)
	if not _enabled:
		return
	if _awaiting_capture:
		_awaiting_capture = false
		if _water_capture_enabled and _terrain_view != null and _water_texture != null and _terrain_view.has_method("set_reflection_texture"):
			_terrain_view.set_reflection_texture(_water_texture)
			if _terrain_view.has_method("refresh_water_reflection_state"):
				_terrain_view.refresh_water_reflection_state()
		return
	if _dirty and _debounce_left <= 0.0:
		_dirty = false
		_debounce_left = DEBOUNCE_SEC
		_start_capture()


func _start_capture() -> void:
	_refresh_probes()
	if not _water_capture_enabled:
		return
	_configure_capture_camera()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_awaiting_capture = true


func _rebuild() -> void:
	_ensure_nodes()
	_enabled = max_probe_count(_settings) > 0
	_water_capture_enabled = _settings.reflection_mode == "probe" and _enabled
	_probe_root.visible = _enabled
	_test_marker.visible = _enabled
	if not _enabled:
		_clear_probes()
		if _terrain_view != null and _terrain_view.has_method("set_reflection_texture"):
			_terrain_view.set_reflection_texture(null)
			if _terrain_view.has_method("refresh_water_reflection_state"):
				_terrain_view.refresh_water_reflection_state()
		return
	if _terrain_view != null and _terrain_view.get("model") != null and _placements.is_empty():
		_placements = _compute_placements(_terrain_view.model, max_probe_count(_settings))
	_sync_probe_nodes()
	if _water_capture_enabled:
		_configure_viewport()
	_position_test_marker()
	_dirty = true
	_debounce_left = 0.0


func _clear_probes() -> void:
	for probe in _probes:
		if is_instance_valid(probe):
			probe.free()
	_probes.clear()


func _sync_probe_nodes() -> void:
	_clear_probes()
	for placement in _placements:
		var probe := ReflectionProbe.new()
		probe.name = "ManagedProbe_%d" % int(placement.get("body_id", 0))
		probe.size = placement.get("size", Vector3.ONE * MIN_PROBE_EXTENT_M)
		probe.origin_offset = Vector3.ZERO
		probe.box_projection = true
		probe.intensity = 1.0
		probe.cull_mask = CAPTURE_MASK
		probe.max_distance = float(placement.get("max_distance", probe.size.length()))
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.position = placement.get("center", Vector3.ZERO)
		_probe_root.add_child(probe)
		_probes.append(probe)


func _configure_viewport() -> void:
	var resolution: int = clampi(_settings.reflection_resolution, 64, 1024)
	_viewport.size = Vector2i(resolution, resolution)
	if get_viewport() != null:
		_viewport.world_3d = get_viewport().world_3d


func _refresh_probes() -> void:
	for probe in _probes:
		if is_instance_valid(probe):
			probe.update_mode = ReflectionProbe.UPDATE_ONCE
	_configure_capture_camera()


func _configure_capture_camera() -> void:
	if _placements.is_empty():
		return
	var placement: Dictionary = _placements[0]
	var center: Vector3 = placement.get("center", Vector3(512, 0, 512))
	var size: Vector3 = placement.get("size", Vector3(MIN_PROBE_EXTENT_M, 20, MIN_PROBE_EXTENT_M))
	var water_y: float = float(placement.get("water_y", center.y))
	var span_x: float = maxf(size.x, MIN_PROBE_EXTENT_M)
	var span_z: float = maxf(size.z, MIN_PROBE_EXTENT_M)
	var height: float = water_y + PROBE_HEIGHT_PAD_M + size.y * 0.5
	_capture_camera.global_position = Vector3(center.x, height, center.z)
	_capture_camera.global_rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_capture_camera.size = maxf(span_x, span_z) * 0.55
	_capture_camera.far = height + 80.0


func _position_test_marker() -> void:
	if _placements.is_empty() or _terrain_view == null or _terrain_view.get("model") == null:
		return
	var placement: Dictionary = _placements[0]
	var shore: Vector3 = placement.get("shore_anchor", Vector3(205, 0, 318))
	shore.y = _terrain_view.model.height_at(shore) + 1.35
	_test_marker.global_position = shore


static func _compute_placements(terrain: TerrainModel, max_count: int) -> Array[Dictionary]:
	var placements: Array[Dictionary] = []
	if terrain == null or max_count <= 0:
		return placements
	var bodies: Array[Dictionary] = []
	for body_id in WaterField.active_body_ids(terrain):
		var bounds: Dictionary = _water_body_bounds(terrain, body_id)
		if bounds.is_empty():
			continue
		bodies.append(bounds)
	bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("cell_count", 0)) > int(b.get("cell_count", 0))
	)
	for index in range(mini(max_count, bodies.size())):
		var bounds: Dictionary = bodies[index]
		var expanded: Dictionary = _expand_for_structures(terrain, bounds)
		var center: Vector3 = expanded.get("center", Vector3.ZERO)
		var size: Vector3 = expanded.get("size", Vector3.ONE * MIN_PROBE_EXTENT_M)
		size.y = maxf(size.y, PROBE_HEIGHT_PAD_M)
		placements.append({
			"body_id": int(bounds.get("body_id", -1)),
			"center": center,
			"size": size,
			"water_y": float(bounds.get("water_y", center.y)),
			"cell_count": int(bounds.get("cell_count", 0)),
			"max_distance": maxf(size.length(), MIN_PROBE_EXTENT_M),
			"shore_anchor": expanded.get("shore_anchor", center),
		})
	return placements


static func _water_body_bounds(terrain: TerrainModel, body_id: int) -> Dictionary:
	WaterField.flush_dirty(terrain)
	var min_x: int = 9999
	var min_z: int = 9999
	var max_x: int = -1
	var max_z: int = -1
	var cell_count: int = 0
	var level_sum: float = 0.0
	for z in range(WaterField.RES):
		for x in range(WaterField.RES):
			var index: int = z * WaterField.RES + x
			if int(terrain._water_body_ids[index]) != body_id:
				continue
			min_x = mini(min_x, x)
			min_z = mini(min_z, z)
			max_x = maxi(max_x, x)
			max_z = maxi(max_z, z)
			cell_count += 1
			level_sum += terrain.water_levels[index]
	if cell_count <= 0:
		return {}
	var water_y: float = level_sum / float(cell_count)
	var min_pos: Vector3 = Vector3(float(min_x) * TerrainModel.STEP, water_y, float(min_z) * TerrainModel.STEP)
	var max_pos: Vector3 = Vector3(float(max_x + 1) * TerrainModel.STEP, water_y, float(max_z + 1) * TerrainModel.STEP)
	var center: Vector3 = (min_pos + max_pos) * 0.5
	center.y = water_y + 6.0
	var size: Vector3 = max_pos - min_pos
	size.y = PROBE_HEIGHT_PAD_M
	return {
		"body_id": body_id,
		"center": center,
		"size": size,
		"water_y": water_y,
		"cell_count": cell_count,
		"min_pos": min_pos,
		"max_pos": max_pos,
	}


static func _expand_for_structures(terrain: TerrainModel, bounds: Dictionary) -> Dictionary:
	var min_pos: Vector3 = bounds.get("min_pos", Vector3.ZERO)
	var max_pos: Vector3 = bounds.get("max_pos", Vector3.ZERO)
	var water_y: float = float(bounds.get("water_y", 0.0))
	var center: Vector3 = bounds.get("center", Vector3.ZERO)
	var expanded_min: Vector3 = min_pos - Vector3(STRUCTURE_MARGIN_M, 0.0, STRUCTURE_MARGIN_M)
	var expanded_max: Vector3 = max_pos + Vector3(STRUCTURE_MARGIN_M, 0.0, STRUCTURE_MARGIN_M)
	var shore_anchor: Vector3 = center
	var best_score: float = INF
	for obj in terrain.objects:
		if obj.has("end"):
			continue
		var pos: Vector3 = obj.pos
		if pos.x < expanded_min.x or pos.z < expanded_min.z:
			continue
		if pos.x > expanded_max.x or pos.z > expanded_max.z:
			continue
		expanded_min.x = minf(expanded_min.x, pos.x - 12.0)
		expanded_min.z = minf(expanded_min.z, pos.z - 12.0)
		expanded_max.x = maxf(expanded_max.x, pos.x + 12.0)
		expanded_max.z = maxf(expanded_max.z, pos.z + 12.0)
		var dist: float = Vector2(pos.x - center.x, pos.z - center.z).length()
		var score: float = dist
		if str(obj.kind) == "clubhouse":
			score *= 0.55
		if score < best_score:
			best_score = score
			shore_anchor = pos
	expanded_min.x = clampf(expanded_min.x, 0.0, TerrainModel.WIDTH)
	expanded_min.z = clampf(expanded_min.z, 0.0, TerrainModel.WIDTH)
	expanded_max.x = clampf(expanded_max.x, 0.0, TerrainModel.WIDTH)
	expanded_max.z = clampf(expanded_max.z, 0.0, TerrainModel.WIDTH)
	var size: Vector3 = expanded_max - expanded_min
	size.x = maxf(size.x, MIN_PROBE_EXTENT_M)
	size.z = maxf(size.z, MIN_PROBE_EXTENT_M)
	center = (expanded_min + expanded_max) * 0.5
	center.y = water_y + 6.0
	return {
		"center": center,
		"size": size,
		"shore_anchor": shore_anchor,
	}


func notify_edit_burst() -> void:
	_dirty = true
	_debounce_left = DEBOUNCE_SEC
