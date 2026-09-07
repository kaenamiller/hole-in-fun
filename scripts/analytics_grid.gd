class_name AnalyticsGrid
extends RefCounted

## Spatial heat grids for analytics overlays (64 x 64 cells, 16 m each).

const SIZE: int = 64
const CELL_METERS: float = 16.0
const CELL_COUNT: int = SIZE * SIZE

var _layers: Dictionary = {}


func _ensure(layer: String) -> PackedFloat32Array:
	if not _layers.has(layer):
		var data: PackedFloat32Array = PackedFloat32Array()
		data.resize(CELL_COUNT)
		_layers[layer] = data
	return _layers[layer]


func _index(pos: Vector3) -> int:
	var x: int = clampi(int(floor(pos.x / CELL_METERS)), 0, SIZE - 1)
	var z: int = clampi(int(floor(pos.z / CELL_METERS)), 0, SIZE - 1)
	return z * SIZE + x


func add(layer: String, pos: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var data: PackedFloat32Array = _ensure(layer)
	data[_index(pos)] += amount


func decay(layer: String, factor: float) -> void:
	if not _layers.has(layer):
		return
	var data: PackedFloat32Array = _layers[layer]
	for index in range(data.size()):
		data[index] *= factor


func value(layer: String, pos: Vector3) -> float:
	if not _layers.has(layer):
		return 0.0
	return _layers[layer][_index(pos)]


func max_value(layer: String) -> float:
	if not _layers.has(layer):
		return 0.0
	var data: PackedFloat32Array = _layers[layer]
	var best: float = 0.0
	for index in range(data.size()):
		best = maxf(best, data[index])
	return best


func snapshot() -> Dictionary:
	var out: Dictionary = {}
	for key in _layers.keys():
		out[key] = (_layers[key] as PackedFloat32Array).duplicate()
	return out


func restore(data: Dictionary) -> void:
	_layers.clear()
	for key in data.keys():
		var raw = data[key]
		if raw is PackedFloat32Array:
			var arr: PackedFloat32Array = (raw as PackedFloat32Array).duplicate()
			if arr.size() == CELL_COUNT:
				_layers[key] = arr
