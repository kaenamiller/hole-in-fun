class_name CosmeticEffectManager
extends RefCounted

## Pooled cosmetic contact and ambient effects (graphics package 16).

const COSMETIC_RNG_SEED: int = 16001
const MARK_LIFETIME: float = 45.0
const PUFF_LIFETIME: float = 0.85
const CULL_DISTANCE_LOW: float = 80.0
const CULL_DISTANCE_STANDARD: float = 140.0
const CULL_DISTANCE_HIGH: float = 200.0
const MAX_FOUNTAIN_SPRAY: int = 6

const EffectEvent = preload("res://scripts/cosmetic_effect_event.gd")

var _root: Node3D
var _puff_root: Node3D
var _mark_root: Node3D

var _dedup_ring: Array[int] = []
var _dedup_lookup: Dictionary = {}
var _shot_fired: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _total_cap: int = 64
var _sand_cap: int = 12
var _mark_cap: int = 16
var _ambient_cap: int = 8

var _puff_pool: Array[CPUParticles3D] = []
var _mark_pool: Array[MeshInstance3D] = []
var _active_puffs: Array[Dictionary] = []
var _active_marks: Array[Dictionary] = []

var _flags: Array[Node3D] = []
var _fountains: Array[Node3D] = []
var _fountain_spray: Array[CPUParticles3D] = []

var _mark_material: ShaderMaterial
var _sand_material: StandardMaterial3D


func attach(root: Node3D) -> void:
	_root = root
	_puff_root = Node3D.new()
	_puff_root.name = "SandPuffs"
	_mark_root = Node3D.new()
	_mark_root.name = "TurfMarks"
	root.add_child(_puff_root)
	root.add_child(_mark_root)
	_rng.seed = COSMETIC_RNG_SEED
	_ensure_materials()


func reset() -> void:
	_dedup_reset()
	_shot_fired.clear()
	_clear_active()
	_flags.clear()
	_fountains.clear()
	for spray in _fountain_spray:
		if is_instance_valid(spray):
			spray.queue_free()
	_fountain_spray.clear()


func configure(settings: GraphicsSettings) -> void:
	_total_cap = maxi(0, settings.effect_instance_cap)
	if _total_cap <= 0:
		_sand_cap = 0
		_mark_cap = 0
		_ambient_cap = 0
		_clear_active()
		return
	_sand_cap = clampi(maxi(2, _total_cap / 6), 0, 24)
	_mark_cap = clampi(maxi(2, _total_cap / 4), 0, 32)
	_ambient_cap = clampi(mini(8, maxi(2, _total_cap / 8)), 0, 8)
	_trim_pools()


func stats() -> Dictionary:
	return {
		"total_cap": _total_cap,
		"sand_cap": _sand_cap,
		"mark_cap": _mark_cap,
		"ambient_cap": _ambient_cap,
		"active_puffs": _active_puffs.size(),
		"active_marks": _active_marks.size(),
		"dedup_seen": _dedup_ring.size(),
		"flags": _flags.size(),
		"fountains": _fountains.size(),
	}


func register_ambient_from_world(world) -> void:
	_flags.clear()
	_fountains.clear()
	if world == null or not is_instance_valid(world):
		return
	for child in world.hole_root.get_children():
		for node in child.get_children():
			if node.name == "flag" or str(node.name).begins_with("flag"):
				_flags.append(node)
	for node in world.object_nodes.values():
		if not is_instance_valid(node):
			continue
		var record: Dictionary = node.get_meta("record", {})
		if str(record.get("kind", node.name)) == "fountain":
			_fountains.append(node)
	_configure_fountain_spray()


func poll_shot_effects(
	motion: ActorMotion,
	terrain,
	world,
	camera_focus: Vector3,
	settings: GraphicsSettings,
) -> void:
	if _total_cap <= 0 or motion == null or terrain == null:
		return
	for actor_id_value in motion.visual_shots.keys():
		var actor_id: int = int(actor_id_value)
		var entry: Dictionary = motion.visual_shots[actor_id]
		var shot: Dictionary = entry.get("shot", {})
		var serial: int = int(entry.get("serial", shot.get("serial", 0)))
		if serial <= 0 or shot.is_empty():
			continue
		var dispatch_key: String = "%d:%d" % [actor_id, serial]
		if _shot_fired.has(dispatch_key):
			continue
		var is_putt: bool = str(shot.get("club", "")) == "putter"
		var timeline: Dictionary = ActorMotion.shot_visual_timeline(shot, is_putt)
		var launch_time: float = float(timeline.get("launch_time", 0.0))
		var visual_time: float = float(entry.get("time", 0.0))
		if visual_time < launch_time:
			continue
		_shot_fired[dispatch_key] = true
		var events: Array = EffectEvent.contact_events_for_shot(
			actor_id,
			shot,
			launch_time,
			terrain,
		)
		for event_value in events:
			var event: Dictionary = event_value
			if not _dedup_consume(int(event.get("id", -1))):
				continue
			_dispatch_event(event, terrain, world, camera_focus, settings, launch_time)


func update(
	presentation_time: float,
	cosmetic_time: float,
	camera_focus: Vector3,
	settings: GraphicsSettings,
) -> void:
	_update_active(presentation_time, camera_focus, settings)
	if _ambient_cap > 0:
		_update_ambient(cosmetic_time, camera_focus, settings)


func invalidate_region(center: Vector3, radius: float) -> void:
	if _active_marks.is_empty():
		return
	var kept: Array[Dictionary] = []
	for mark_value in _active_marks:
		var mark: Dictionary = mark_value
		var pos: Vector3 = mark.get("position", Vector3.ZERO)
		if pos.distance_to(center) <= radius + 2.0:
			_release_mark(int(mark.get("pool_index", -1)))
			continue
		kept.append(mark)
	_active_marks = kept


func _dispatch_event(
	event: Dictionary,
	terrain,
	world,
	camera_focus: Vector3,
	settings: GraphicsSettings,
	trigger_time: float,
) -> void:
	var pos: Vector3 = Vector3(event.get("position", Vector3.ZERO))
	if pos.distance_to(camera_focus) > _cull_distance(settings):
		return
	match int(event.get("type", -1)):
		EffectEvent.Type.SAND_PUFF:
			_spawn_sand_puff(pos, terrain, event, settings, trigger_time, camera_focus)
		EffectEvent.Type.TURF_DIVOT:
			_spawn_divot_mark(pos, terrain, event, settings, trigger_time, camera_focus)
		EffectEvent.Type.WATER_RIPPLE:
			_spawn_water_ripple(pos, terrain, world, event, trigger_time)


func _spawn_sand_puff(
	pos: Vector3,
	terrain,
	event: Dictionary,
	settings: GraphicsSettings,
	trigger_time: float,
	camera_focus: Vector3,
) -> void:
	if _sand_cap <= 0:
		return
	_prune_active_puffs(trigger_time)
	if _active_puffs.size() >= _sand_cap:
		_drop_lowest_priority_puff(camera_focus, settings)
		if _active_puffs.size() >= _sand_cap:
			return
	var puff: CPUParticles3D = _acquire_puff()
	if puff == null:
		return
	pos.y = float(terrain.height_at(pos)) + 0.06 if terrain != null else pos.y + 0.06
	puff.position = pos
	puff.rotation.y = _rng.randf_range(0.0, TAU)
	puff.amount = clampi(maxi(6, _sand_cap / 2), 6, 18)
	puff.lifetime = PUFF_LIFETIME
	puff.one_shot = true
	puff.emitting = true
	puff.visible = true
	_active_puffs.append({
		"node": puff,
		"pool_index": _puff_pool.find(puff),
		"start_time": trigger_time,
		"priority": int(event.get("priority", 0)),
		"position": pos,
	})


func _spawn_divot_mark(
	pos: Vector3,
	terrain,
	event: Dictionary,
	settings: GraphicsSettings,
	trigger_time: float,
	camera_focus: Vector3,
) -> void:
	if _mark_cap <= 0:
		return
	_prune_active_marks(trigger_time)
	if _active_marks.size() >= _mark_cap:
		_drop_lowest_priority_mark(camera_focus, settings)
		if _active_marks.size() >= _mark_cap:
			return
	var mark: MeshInstance3D = _acquire_mark()
	if mark == null:
		return
	pos.y = float(terrain.height_at(pos)) + 0.03 if terrain != null else pos.y + 0.03
	var size: float = _rng.randf_range(0.28, 0.42)
	mark.position = pos
	mark.rotation.y = _rng.randf_range(0.0, TAU)
	mark.scale = Vector3(size, 1.0, size * _rng.randf_range(0.75, 1.05))
	mark.visible = true
	if mark.material_override is ShaderMaterial:
		(mark.material_override as ShaderMaterial).set_shader_parameter("mark_fade", 1.0)
	_active_marks.append({
		"node": mark,
		"pool_index": _mark_pool.find(mark),
		"start_time": trigger_time,
		"expire_time": trigger_time + MARK_LIFETIME,
		"priority": int(event.get("priority", 0)),
		"position": pos,
	})


func _spawn_water_ripple(
	pos: Vector3,
	terrain,
	world,
	event: Dictionary,
	trigger_time: float,
) -> void:
	if world == null or not is_instance_valid(world):
		return
	var body_id: int = int(event.get("surface_id", -1))
	var strength: float = clampf(0.45 + _rng.randf() * 0.35, 0.0, 1.0)
	var radius: float = clampf(1.2 + _rng.randf_range(0.0, 1.6), 0.5, 24.0)
	var wall_time: float = float(Time.get_ticks_msec()) / 1000.0
	if world.has_method("submit_water_ripple"):
		world.call("submit_water_ripple", body_id, pos, wall_time, radius, strength)


func _update_active(now: float, camera_focus: Vector3, settings: GraphicsSettings) -> void:
	_prune_active_puffs(now)
	_prune_active_marks(now)
	var cull: float = _cull_distance(settings)
	for puff_value in _active_puffs:
		var puff: Dictionary = puff_value
		var node: CPUParticles3D = puff.get("node") as CPUParticles3D
		if node == null:
			continue
		node.visible = node.position.distance_to(camera_focus) <= cull + 12.0
	for mark_value in _active_marks:
		var mark: Dictionary = mark_value
		var node: MeshInstance3D = mark.get("node") as MeshInstance3D
		if node == null:
			continue
		var dist: float = node.position.distance_to(camera_focus)
		node.visible = dist <= cull + 8.0
		if not node.visible:
			continue
		var age: float = now - float(mark.get("start_time", now))
		var fade: float = clampf(1.0 - age / MARK_LIFETIME, 0.0, 1.0)
		if node.material_override is ShaderMaterial:
			(node.material_override as ShaderMaterial).set_shader_parameter("mark_fade", fade)


func _update_ambient(cosmetic_time: float, camera_focus: Vector3, settings: GraphicsSettings) -> void:
	var cull: float = _cull_distance(settings) + 40.0
	var flag_budget: int = mini(_flags.size(), _ambient_cap)
	for index in range(flag_budget):
		var flag: Node3D = _flags[index]
		if not is_instance_valid(flag):
			continue
		if flag.global_position.distance_to(camera_focus) > cull:
			continue
		var cloth: Node3D = flag.get_node_or_null("Cloth") as Node3D
		if cloth == null:
			continue
		var phase: float = float(index) * 1.73 + flag.global_position.x * 0.04
		cloth.rotation.z = sin(cosmetic_time * 2.4 + phase) * 0.11 + sin(cosmetic_time * 5.1 + phase * 1.7) * 0.04
	for index in range(_fountains.size()):
		var fountain: Node3D = _fountains[index]
		if not is_instance_valid(fountain):
			continue
		if fountain.global_position.distance_to(camera_focus) > cull:
			continue
		var spray: CPUParticles3D = _fountain_spray[index] if index < _fountain_spray.size() else null
		if spray != null:
			spray.emitting = index < mini(_fountains.size(), MAX_FOUNTAIN_SPRAY) and _ambient_cap > 0
		var anchor: Node3D = fountain.get_node_or_null("SprayAnchor") as Node3D
		if anchor != null:
			var bob: float = sin(cosmetic_time * 3.2 + float(index) * 2.1) * 0.035
			anchor.position.y = 1.88 + bob


func _configure_fountain_spray() -> void:
	for spray in _fountain_spray:
		if is_instance_valid(spray):
			spray.queue_free()
	_fountain_spray.clear()
	var count: int = mini(mini(_fountains.size(), MAX_FOUNTAIN_SPRAY), _ambient_cap)
	for index in range(count):
		var fountain: Node3D = _fountains[index]
		if not is_instance_valid(fountain):
			continue
		var spray: CPUParticles3D = _build_fountain_spray()
		spray.name = "Spray"
		var anchor: Node3D = fountain.get_node_or_null("SprayAnchor") as Node3D
		if anchor != null:
			anchor.add_child(spray)
		else:
			fountain.add_child(spray)
		_fountain_spray.append(spray)


func _build_fountain_spray() -> CPUParticles3D:
	var spray := CPUParticles3D.new()
	spray.position = Vector3.ZERO
	spray.amount = 10
	spray.lifetime = 0.55
	spray.preprocess = 0.2
	spray.speed_scale = 0.65
	spray.direction = Vector3(0, 1, 0)
	spray.spread = 18.0
	spray.gravity = Vector3(0, -2.4, 0)
	spray.initial_velocity_min = 0.8
	spray.initial_velocity_max = 1.6
	spray.scale_amount_min = 0.5
	spray.scale_amount_max = 0.9
	spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	spray.emission_sphere_radius = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.37, 0.62, 0.63, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray.material_override = mat
	spray.emitting = true
	return spray


func _dedup_reset() -> void:
	_dedup_ring.clear()
	_dedup_lookup.clear()


func _dedup_consume(event_id: int) -> bool:
	if _dedup_lookup.has(event_id):
		return false
	if _dedup_ring.size() >= EffectEvent.DEDUP_CAPACITY:
		var oldest: int = int(_dedup_ring.pop_front())
		_dedup_lookup.erase(oldest)
	_dedup_ring.append(event_id)
	_dedup_lookup[event_id] = true
	return true


func _cull_distance(settings: GraphicsSettings) -> float:
	match settings.preset:
		GraphicsSettings.Preset.LOW:
			return CULL_DISTANCE_LOW
		GraphicsSettings.Preset.HIGH:
			return CULL_DISTANCE_HIGH
		_:
			return CULL_DISTANCE_STANDARD


func _ensure_materials() -> void:
	if _mark_material == null:
		_mark_material = ShaderMaterial.new()
		_mark_material.shader = preload("res://shaders/resort_effect_mark.gdshader")
	if _sand_material == null:
		_sand_material = StandardMaterial3D.new()
		_sand_material.albedo_color = Color("c9b48a")
		_sand_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_sand_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _acquire_puff() -> CPUParticles3D:
	for puff in _puff_pool:
		if puff.emitting:
			continue
		if not puff.visible:
			return puff
	for puff in _puff_pool:
		if not puff.emitting:
			return puff
	if _puff_pool.size() >= _sand_cap:
		return null
	var puff := _create_puff()
	_puff_root.add_child(puff)
	_puff_pool.append(puff)
	return puff


func _acquire_mark() -> MeshInstance3D:
	for mark in _mark_pool:
		if not mark.visible:
			return mark
	if _mark_pool.size() >= _mark_cap:
		return null
	var mark := _create_mark()
	_mark_root.add_child(mark)
	_mark_pool.append(mark)
	return mark


func _create_puff() -> CPUParticles3D:
	var puff := CPUParticles3D.new()
	puff.amount = 12
	puff.lifetime = PUFF_LIFETIME
	puff.one_shot = true
	puff.explosiveness = 0.92
	puff.direction = Vector3(0, 1, 0)
	puff.spread = 38.0
	puff.gravity = Vector3(0, -3.5, 0)
	puff.initial_velocity_min = 0.6
	puff.initial_velocity_max = 1.8
	puff.scale_amount_min = 0.35
	puff.scale_amount_max = 0.75
	puff.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	puff.emission_sphere_radius = 0.12
	puff.material_override = _sand_material
	puff.emitting = false
	puff.visible = false
	return puff


func _create_mark() -> MeshInstance3D:
	var mark := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	mesh.orientation = PlaneMesh.FACE_Y
	mark.mesh = mesh
	var mat: ShaderMaterial = _mark_material.duplicate() as ShaderMaterial
	mark.material_override = mat
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mark.visible = false
	return mark


func _release_puff(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= _puff_pool.size():
		return
	var puff: CPUParticles3D = _puff_pool[pool_index]
	puff.emitting = false
	puff.visible = false


func _release_mark(pool_index: int) -> void:
	if pool_index < 0 or pool_index >= _mark_pool.size():
		return
	var mark: MeshInstance3D = _mark_pool[pool_index]
	mark.visible = false


func _clear_active() -> void:
	for puff_value in _active_puffs:
		_release_puff(int((puff_value as Dictionary).get("pool_index", -1)))
	for mark_value in _active_marks:
		_release_mark(int((mark_value as Dictionary).get("pool_index", -1)))
	_active_puffs.clear()
	_active_marks.clear()


func _trim_pools() -> void:
	while _puff_pool.size() > _sand_cap:
		var puff: CPUParticles3D = _puff_pool.pop_back()
		if is_instance_valid(puff):
			puff.queue_free()
	while _mark_pool.size() > _mark_cap:
		var mark: MeshInstance3D = _mark_pool.pop_back()
		if is_instance_valid(mark):
			mark.queue_free()
	_clear_active()


func _prune_active_puffs(now: float) -> void:
	var kept: Array[Dictionary] = []
	for puff_value in _active_puffs:
		var puff: Dictionary = puff_value
		var age: float = now - float(puff.get("start_time", now))
		if age > PUFF_LIFETIME + 0.2:
			_release_puff(int(puff.get("pool_index", -1)))
			continue
		kept.append(puff)
	_active_puffs = kept


func _prune_active_marks(now: float) -> void:
	var kept: Array[Dictionary] = []
	for mark_value in _active_marks:
		var mark: Dictionary = mark_value
		if now >= float(mark.get("expire_time", now)):
			_release_mark(int(mark.get("pool_index", -1)))
			continue
		kept.append(mark)
	_active_marks = kept


func _drop_lowest_priority_puff(camera_focus: Vector3, settings: GraphicsSettings) -> void:
	if _active_puffs.is_empty():
		return
	var worst_index: int = 0
	var worst_score: float = 999999.0
	for index in range(_active_puffs.size()):
		var puff: Dictionary = _active_puffs[index]
		var pos: Vector3 = puff.get("position", Vector3.ZERO)
		var score: float = pos.distance_to(camera_focus) - float(puff.get("priority", 0)) * 25.0
		if score < worst_score:
			worst_score = score
			worst_index = index
	var dropped: Dictionary = _active_puffs[worst_index]
	_release_puff(int(dropped.get("pool_index", -1)))
	_active_puffs.remove_at(worst_index)


func _drop_lowest_priority_mark(camera_focus: Vector3, settings: GraphicsSettings) -> void:
	if _active_marks.is_empty():
		return
	var worst_index: int = 0
	var worst_score: float = 999999.0
	for index in range(_active_marks.size()):
		var mark: Dictionary = _active_marks[index]
		var pos: Vector3 = mark.get("position", Vector3.ZERO)
		var score: float = pos.distance_to(camera_focus) - float(mark.get("priority", 0)) * 20.0
		if score < worst_score:
			worst_score = score
			worst_index = index
	var dropped: Dictionary = _active_marks[worst_index]
	_release_mark(int(dropped.get("pool_index", -1)))
	_active_marks.remove_at(worst_index)


func teardown() -> void:
	reset()
	for puff in _puff_pool:
		if is_instance_valid(puff):
			puff.queue_free()
	for mark in _mark_pool:
		if is_instance_valid(mark):
			mark.queue_free()
	_puff_pool.clear()
	_mark_pool.clear()
	if is_instance_valid(_puff_root):
		_puff_root.queue_free()
	if is_instance_valid(_mark_root):
		_mark_root.queue_free()
