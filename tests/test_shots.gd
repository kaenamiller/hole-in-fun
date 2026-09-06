extends SceneTree

const ShotEngineClass = preload("res://scripts/shot_engine.gd")

class FakeTerrain extends RefCounted:
	var blocker_points: Array = []
	var water_center: Vector3 = Vector3(9999.0, 0.0, 9999.0)
	var water_radius: float = 0.0
	var slope: Vector2 = Vector2.ZERO

	func height_at(point: Vector3) -> float:
		return sin(point.x * 0.01) * 0.35 + cos(point.z * 0.013) * 0.25

	func surface_at(point: Vector3) -> int:
		if Vector2(point.x, point.z).distance_to(Vector2(water_center.x, water_center.z)) <= water_radius:
			return 5
		return 2 if point.x > 200.0 else 1

	func slope_at(_point: Vector3) -> Vector2:
		return slope

	func playable(point: Vector3) -> bool:
		if point.x < 0.0 or point.x > 1024.0 or point.z < 0.0 or point.z > 1024.0:
			return false
		return surface_at(point) != 5

	func segment_blocked(start: Vector3, end: Vector3) -> bool:
		for blocker_value in blocker_points:
			var blocker: Vector3 = Vector3(blocker_value)
			var segment: Vector2 = Vector2(end.x - start.x, end.z - start.z)
			var length_squared: float = segment.length_squared()
			var along: float = 0.0
			if length_squared > 0.001:
				along = clampf(Vector2(blocker.x - start.x, blocker.z - start.z).dot(segment) / length_squared, 0.0, 1.0)
			var closest: Vector2 = Vector2(start.x, start.z) + segment * along
			if closest.distance_to(Vector2(blocker.x, blocker.z)) <= 3.5:
				return true
		return false

	func beauty_at(_point: Vector3) -> float:
		return 0.6

	func route(start: Vector3, end: Vector3, _cart: bool = false) -> PackedVector3Array:
		return PackedVector3Array([start, end])

	func nearest_safe(point: Vector3) -> Vector3:
		var safe_x: float = clampf(point.x, 4.0, 1020.0)
		var safe_z: float = clampf(point.z, 4.0, 1020.0)
		if water_radius > 0.0 and Vector2(safe_x, safe_z).distance_to(Vector2(water_center.x, water_center.z)) <= water_radius:
			safe_x = water_center.x - water_radius - 3.0
		return Vector3(safe_x, 0.0, safe_z)

func _init() -> void:
	var failures: int = 0
	failures += _test_deterministic_shot()
	failures += _test_tree_layup()
	failures += _test_water_recovery()
	failures += _test_putting_and_cap()
	failures += _test_analysis_profiles()
	if failures == 0:
		print("test_shots: all tests passed")
	else:
		printerr("test_shots: %d test(s) failed" % failures)
	quit(failures)

func _test_deterministic_shot() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(0.0, 0.0, 0.0), Vector3(140.0, 0.0, 0.0))
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 77
	rng_b.seed = 77
	var first: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var second: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	return _expect(first == second, "same seed should produce identical shot dictionaries")

func _test_tree_layup() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.blocker_points.append(Vector3(60.0, 0.0, 0.0))
	var hole: Dictionary = _hole(Vector3(0.0, 0.0, 0.0), Vector3(140.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12
	var result: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.72, rng)
	var reason: String = String(result.get("reason", ""))
	return _expect(reason.find("tree") >= 0, "blocked fairway should produce a tree layup reason")

func _test_water_recovery() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.water_center = Vector3(85.0, 0.0, 0.0)
	terrain.water_radius = 18.0
	var hole: Dictionary = _hole(Vector3(0.0, 0.0, 0.0), Vector3(85.0, 0.0, 0.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var result: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.9, rng)
	var end: Vector3 = Vector3(result.get("end", Vector3.ZERO))
	var hazard_ok: bool = bool(result.get("hazard", false)) and int(result.get("penalty", 0)) == 1
	var recovered: bool = end.x < terrain.water_center.x - terrain.water_radius
	return _expect(hazard_ok and recovered, "water landing should incur one penalty and recover to safe ground")

func _test_putting_and_cap() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(250.0, 0.0, 0.0), Vector3(258.0, 0.0, 0.0))
	var preview: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.55, 91)
	var shots: Array = preview.get("shots", [])
	var first: Dictionary = shots[0] if not shots.is_empty() else {}
	var putting: bool = String(first.get("club", "")) == "putter"
	var cap_ok: bool = int(preview.get("strokes", 99)) <= 14 and shots.size() <= 14
	return _expect(putting and cap_ok, "green preview should use a putter and obey the stroke cap")

func _test_analysis_profiles() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(0.0, 0.0, 0.0), Vector3(170.0, 0.0, 0.0))
	var result: Array = ShotEngineClass.analyze(terrain, hole, 30, 4242)
	var shape_ok: bool = result.size() == 3
	var metrics_ok: bool = true
	for value in result:
		var profile: Dictionary = value
		metrics_ok = metrics_ok and profile.has("label") and profile.has("skill") and profile.has("average") and profile.has("hazard_rate") and profile.has("shots")
		metrics_ok = metrics_ok and float(profile.get("average", 0.0)) >= 1.0 and float(profile.get("hazard_rate", -1.0)) >= 0.0
	return _expect(shape_ok and metrics_ok, "analysis should return all three bounded profile metrics")

func _hole(tee: Vector3, cup: Vector3) -> Dictionary:
	return {
		"id": 1,
		"name": "Test Hole",
		"tee": tee,
		"cup": cup,
		"green_radius": 18.0,
		"par": 4,
		"open": true,
		"waypoints": []
	}

func _expect(condition: bool, message: String) -> int:
	if condition:
		return 0
	printerr("FAIL: " + message)
	return 1
