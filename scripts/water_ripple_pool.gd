class_name WaterRipplePool
extends RefCounted

## Cosmetic ripple receiver for package 11. Package 16 dispatches events via submit().

const MAX_SLOTS: int = 16
const DEFAULT_LIFETIME: float = 3.2

var _ripples: Array = []
var _cap: int = 8

func configure(cap: int) -> void:
	_cap = clampi(cap, 0, MAX_SLOTS)
	while _ripples.size() > _cap:
		_ripples.pop_back()

func clear() -> void:
	_ripples.clear()

func active_count() -> int:
	return _ripples.size()

func submit(body_id: int, world_pos: Vector3, start_time: float, radius: float, strength: float, terrain: TerrainModel) -> bool:
	if _cap <= 0 or strength <= 0.0 or radius <= 0.0:
		return false
	if body_id < 0 or not WaterField.body_exists(terrain, body_id):
		return false
	var sample: Dictionary = WaterField.sample(terrain, world_pos)
	if int(sample.get("body_id", -1)) != body_id:
		return false
	if float(sample.get("depth", 0.0)) <= 0.0:
		return false
	_prune(start_time)
	if _ripples.size() >= _cap:
		_ripples.pop_front()
	_ripples.append({
		"body_id": body_id,
		"position": Vector2(world_pos.x, world_pos.z),
		"start_time": start_time,
		"radius": clampf(radius, 0.5, 24.0),
		"strength": clampf(strength, 0.0, 1.0),
	})
	return true

func update(now: float) -> void:
	_prune(now)

func apply_to_material(material: ShaderMaterial, now: float) -> void:
	if material == null:
		return
	update(now)
	var positions: PackedVector4Array = PackedVector4Array()
	var meta: PackedVector4Array = PackedVector4Array()
	for index in range(MAX_SLOTS):
		positions.append(Vector4.ZERO)
		meta.append(Vector4.ZERO)
	for index in range(mini(_ripples.size(), MAX_SLOTS)):
		var ripple: Dictionary = _ripples[index]
		var pos: Vector2 = ripple.get("position", Vector2.ZERO)
		positions[index] = Vector4(
			pos.x,
			pos.y,
			float(ripple.get("start_time", 0.0)),
			float(ripple.get("strength", 0.0)),
		)
		meta[index] = Vector4(
			float(ripple.get("radius", 1.0)),
			float(int(ripple.get("body_id", -1))) / 255.0,
			0.0,
			0.0,
		)
	material.set_shader_parameter("ripple_positions", positions)
	material.set_shader_parameter("ripple_meta", meta)
	material.set_shader_parameter("ripple_count", mini(_ripples.size(), MAX_SLOTS))

func _prune(now: float) -> void:
	var kept: Array = []
	for ripple_value in _ripples:
		var ripple: Dictionary = ripple_value
		var age: float = now - float(ripple.get("start_time", 0.0))
		var lifetime: float = DEFAULT_LIFETIME + float(ripple.get("radius", 1.0)) * 0.12
		if age <= lifetime:
			kept.append(ripple)
	_ripples = kept
