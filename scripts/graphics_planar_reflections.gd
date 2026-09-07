class_name GraphicsPlanarReflections
extends Node

## Optional planar lake reflection pass (package 13). High tier only.

const RendererComparisonClass = preload("res://scripts/renderer_comparison.gd")
const ReflectionProbesClass = preload("res://scripts/graphics_reflection_probes.gd")

const CAPTURE_MASK: int = ReflectionProbesClass.CAPTURE_MASK
const DEBOUNCE_SEC: float = 0.35
const BODY_SWITCH_RATIO: float = 1.15
const BODY_SWITCH_HOLD_SEC: float = 2.0
const CAMERA_POS_EPS: float = 1.25
const CAMERA_SIZE_EPS: float = 2.5
const CAMERA_YAW_EPS: float = 0.004
const CAMERA_ELEV_EPS: float = 0.01
const MAX_STATIC_SKIP_SEC: float = 0.14
const RESOLUTION_SCALE: float = 0.5

var _terrain_view: Node3D
var _settings: GraphicsSettings = GraphicsSettings.defaults()
var _viewport: SubViewport
var _capture_camera: Camera3D
var _water_texture: ViewportTexture
var _active_body_id: int = -1
var _candidate_body_id: int = -1
var _candidate_hold: float = 0.0
var _plane_y: float = 0.0
var _plane_center: Vector3 = Vector3.ZERO
var _placements: Array[Dictionary] = []
var _dirty: bool = true
var _awaiting_capture: bool = false
var _debounce_left: float = 0.0
var _enabled: bool = false
var _last_camera_key: PackedFloat64Array = PackedFloat64Array()
var _static_skip_left: float = 0.0
var _view_projection: Projection = Projection()


static func planar_supported() -> bool:
	return RendererComparisonClass.planar_reflections_supported()


static func active_for_settings(settings: GraphicsSettings) -> bool:
	return settings.reflection_mode == "planar" and planar_supported()


static func capture_resolution(settings: GraphicsSettings) -> int:
	var base: int = clampi(settings.reflection_resolution, 64, 1024)
	return maxi(64, int(round(float(base) * RESOLUTION_SCALE)))


static func reflect_transform_across_plane(xform: Transform3D, plane: Plane) -> Transform3D:
	var origin: Vector3 = xform.origin
	var reflected_origin: Vector3 = origin - 2.0 * plane.normal * plane.distance_to(origin)
	var basis: Basis = xform.basis
	var reflected_basis := Basis(
		basis.x - 2.0 * plane.normal * plane.normal.dot(basis.x),
		basis.y - 2.0 * plane.normal * plane.normal.dot(basis.y),
		basis.z - 2.0 * plane.normal * plane.normal.dot(basis.z),
	)
	return Transform3D(reflected_basis.orthonormalized(), reflected_origin)


func attach(terrain_view: Node3D, settings: GraphicsSettings) -> void:
	_terrain_view = terrain_view
	_settings = settings.duplicate_settings()
	_rebuild()


func apply_settings(settings: GraphicsSettings, terrain: TerrainModel) -> void:
	_settings = settings.duplicate_settings()
	if terrain != null:
		_placements = ReflectionProbesClass._compute_placements(terrain, 1)
		_init_active_body()
	_rebuild()


func mark_dirty() -> void:
	_dirty = true


func has_water_texture() -> bool:
	return _enabled and _water_texture != null


func reflection_view_projection() -> Projection:
	return _view_projection


func reflection_plane_y() -> float:
	return _plane_y


func active_body_id() -> int:
	return _active_body_id


func _ensure_nodes() -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "PlanarReflectionCapture"
	_viewport.disable_3d = false
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_capture_camera = Camera3D.new()
	_capture_camera.name = "ReflectedCamera"
	_capture_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_capture_camera.cull_mask = CAPTURE_MASK
	_viewport.add_child(_capture_camera)
	_water_texture = _viewport.get_texture()


func _teardown_nodes() -> void:
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_viewport.queue_free()
	_viewport = null
	_capture_camera = null
	_water_texture = null


func _process(delta: float) -> void:
	if _terrain_view == null or not _enabled:
		return
	_update_active_body(delta)
	if _debounce_left > 0.0:
		_debounce_left = maxf(0.0, _debounce_left - delta)
	if _awaiting_capture:
		_awaiting_capture = false
		_push_water_texture()
		return
	if _static_skip_left > 0.0:
		_static_skip_left = maxf(0.0, _static_skip_left - delta)
	if _dirty and _debounce_left <= 0.0:
		_dirty = false
		_debounce_left = DEBOUNCE_SEC
		_start_capture()
		return
	if _static_skip_left <= 0.0 and _camera_moved():
		_start_capture()


func _push_water_texture() -> void:
	if _terrain_view == null or _water_texture == null:
		return
	if _terrain_view.has_method("set_reflection_texture"):
		_terrain_view.set_reflection_texture(_water_texture)
	if _terrain_view.has_method("refresh_water_reflection_state"):
		_terrain_view.refresh_water_reflection_state()
	if _terrain_view.has_method("set_planar_reflection_matrix"):
		_terrain_view.set_planar_reflection_matrix(_view_projection, _plane_y)


func _start_capture() -> void:
	var main_camera: Camera3D = _main_camera()
	if main_camera == null or _placements.is_empty():
		return
	_configure_capture_camera(main_camera)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_awaiting_capture = true
	_static_skip_left = MAX_STATIC_SKIP_SEC
	_last_camera_key = _camera_key(main_camera)


func _rebuild() -> void:
	_enabled = active_for_settings(_settings)
	if not _enabled:
		_teardown_nodes()
		_active_body_id = -1
		if _terrain_view != null:
			if _terrain_view.has_method("set_reflection_texture"):
				_terrain_view.set_reflection_texture(null)
			if _terrain_view.has_method("set_planar_reflection_matrix"):
				_terrain_view.set_planar_reflection_matrix(Projection(), 0.0)
			if _terrain_view.has_method("refresh_water_reflection_state"):
				_terrain_view.refresh_water_reflection_state()
		return
	_ensure_nodes()
	if _terrain_view != null and _terrain_view.get("model") != null:
		if _placements.is_empty():
			_placements = ReflectionProbesClass._compute_placements(_terrain_view.model, 1)
		_init_active_body()
	_configure_viewport()
	_dirty = true
	_debounce_left = 0.0
	_last_camera_key = PackedFloat64Array()


func _configure_viewport() -> void:
	var resolution: int = capture_resolution(_settings)
	_viewport.size = Vector2i(resolution, resolution)
	if get_viewport() != null:
		_viewport.world_3d = get_viewport().world_3d
	var aspect: float = 1.0
	if get_viewport() != null:
		var rect: Vector2 = get_viewport().get_visible_rect().size
		if rect.y > 0.0:
			aspect = rect.x / rect.y
	_capture_camera.set_keep_aspect_mode(Camera3D.KEEP_WIDTH)
	_capture_camera.set_cull_mask(CAPTURE_MASK)


func _configure_capture_camera(main_camera: Camera3D) -> void:
	if _placements.is_empty():
		return
	var placement: Dictionary = _placement_for_active_body()
	_plane_y = float(placement.get("water_y", 0.0))
	_plane_center = placement.get("center", Vector3.ZERO)
	var plane := Plane(Vector3.UP, -_plane_y)
	var reflected: Transform3D = reflect_transform_across_plane(main_camera.global_transform, plane)
	_capture_camera.global_transform = reflected
	_capture_camera.projection = main_camera.projection
	_capture_camera.size = main_camera.size
	_capture_camera.far = main_camera.far
	var clip_distance: float = absf(plane.distance_to(reflected.origin))
	_capture_camera.near = maxf(0.35, clip_distance + 0.08)
	_view_projection = _capture_camera.get_camera_projection() * Projection(_capture_camera.get_camera_transform().affine_inverse())


func _placement_for_active_body() -> Dictionary:
	for placement in _placements:
		if int(placement.get("body_id", -1)) == _active_body_id:
			return placement
	return _placements[0]


func _init_active_body() -> void:
	if _placements.is_empty():
		_active_body_id = -1
		return
	if _active_body_id < 0:
		_active_body_id = int(_placements[0].get("body_id", -1))


func _update_active_body(delta: float) -> void:
	if _placements.is_empty():
		_active_body_id = -1
		return
	_init_active_body()
	var largest: Dictionary = _placements[0]
	var largest_id: int = int(largest.get("body_id", -1))
	if largest_id == _active_body_id:
		_candidate_body_id = -1
		_candidate_hold = 0.0
		return
	var active_cells: int = _placement_cell_count(_active_body_id)
	var largest_cells: int = int(largest.get("cell_count", 0))
	if active_cells <= 0 or float(largest_cells) < float(active_cells) * BODY_SWITCH_RATIO:
		_candidate_body_id = -1
		_candidate_hold = 0.0
		return
	if _candidate_body_id != largest_id:
		_candidate_body_id = largest_id
		_candidate_hold = 0.0
		return
	_candidate_hold += delta
	if _candidate_hold >= BODY_SWITCH_HOLD_SEC:
		_active_body_id = largest_id
		_candidate_body_id = -1
		_candidate_hold = 0.0
		_dirty = true


func _placement_cell_count(body_id: int) -> int:
	for placement in _placements:
		if int(placement.get("body_id", -1)) == body_id:
			return int(placement.get("cell_count", 0))
	return 0


func _main_camera() -> Camera3D:
	if _terrain_view == null:
		return null
	var viewport: Viewport = _terrain_view.get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


func _camera_key(camera: Camera3D) -> PackedFloat64Array:
	return PackedFloat64Array([
		camera.global_position.x,
		camera.global_position.y,
		camera.global_position.z,
		camera.global_rotation.x,
		camera.global_rotation.y,
		camera.global_rotation.z,
		camera.size,
		_plane_y,
	])


func _camera_moved() -> bool:
	var camera: Camera3D = _main_camera()
	if camera == null:
		return false
	var key: PackedFloat64Array = _camera_key(camera)
	if _last_camera_key.size() != key.size():
		return true
	if absf(key[0] - _last_camera_key[0]) > CAMERA_POS_EPS or absf(key[2] - _last_camera_key[2]) > CAMERA_POS_EPS:
		return true
	if absf(key[1] - _last_camera_key[1]) > CAMERA_POS_EPS * 0.5:
		return true
	if absf(key[3] - _last_camera_key[3]) > CAMERA_ELEV_EPS or absf(key[4] - _last_camera_key[4]) > CAMERA_YAW_EPS:
		return true
	if absf(key[6] - _last_camera_key[6]) > CAMERA_SIZE_EPS:
		return true
	if absf(key[7] - _last_camera_key[7]) > 0.02:
		return true
	return false


func notify_edit_burst() -> void:
	_dirty = true
	_debounce_left = DEBOUNCE_SEC
