extends SceneTree

const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const TerrainModelClass = preload("res://scripts/terrain_model.gd")

const TEST_Z: float = 400.0

class FakeTerrain extends RefCounted:
	var blocker_points: Array = []
	var water_center: Vector3 = Vector3(9999.0, 0.0, 9999.0)
	var water_radius: float = 0.0
	var slope: Vector2 = Vector2.ZERO
	var hole_id: int = 1

	func height_at(point: Vector3) -> float:
		return sin(point.x * 0.01) * 0.35 + cos(point.z * 0.013) * 0.25

	func surface_at(point: Vector3) -> int:
		if Vector2(point.x, point.z).distance_to(Vector2(water_center.x, water_center.z)) <= water_radius:
			return 5
		return 2 if point.x > 200.0 else 1

	func green_owner(point: Vector3) -> int:
		return hole_id if surface_at(point) == 2 else -1

	func on_green(point: Vector3, hole: Dictionary) -> bool:
		if surface_at(point) == 5:
			return false
		var cup: Vector3 = Vector3(hole.get("cup", Vector3.ZERO))
		var radius: float = maxf(3.0, float(hole.get("green_radius", 16.0)))
		return Vector2(point.x, point.z).distance_to(Vector2(cup.x, cup.z)) <= radius

	func slope_at(_point: Vector3) -> Vector2:
		return slope

	func playable(point: Vector3) -> bool:
		return point.x >= 2.0 and point.x <= 1020.0 and point.z >= 2.0 and point.z <= 1020.0 and surface_at(point) != 5

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
	failures += _test_poor_green_putting()
	failures += _test_ob_replay_from_tee()
	failures += _test_deep_bunker_recovery()
	failures += _test_sloped_green_putting()
	failures += _test_shaped_green_boundary()
	failures += _test_hole_metrics()
	failures += _test_open_hole_aims_at_pin()
	failures += _test_water_guard_skill_split()
	failures += _test_long_hole_layup()
	failures += _test_lag_putt_option()
	if failures == 0:
		print("test_shots: all tests passed")
	else:
		printerr("test_shots: %d test(s) failed" % failures)
	quit(failures)

func _test_deterministic_shot() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(290.0, 0.0, TEST_Z))
	var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
	var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
	rng_a.seed = 77
	rng_b.seed = 77
	var first: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var second: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	return _expect(first == second, "same seed should produce identical shot dictionaries")

func _test_tree_layup() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.blocker_points.append(Vector3(180.0, 0.0, TEST_Z))
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(290.0, 0.0, TEST_Z))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12
	var result: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.72, rng)
	var reason: String = String(result.get("reason", ""))
	return _expect(reason.find("tree") >= 0, "blocked fairway should produce a tree layup reason")

func _test_water_recovery() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.water_center = Vector3(205.0, 0.0, TEST_Z)
	terrain.water_radius = 10.0
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(210.0, 0.0, TEST_Z))
	var start: Vector3 = Vector3(188.0, 0.0, TEST_Z)
	var recovered: bool = false
	for seed_value in range(80):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value + 3
		var result: Dictionary = ShotEngineClass.shot(terrain, start, hole, 0.9, rng)
		var end: Vector3 = Vector3(result.get("end", Vector3.ZERO))
		var hazard_ok: bool = bool(result.get("hazard", false)) and int(result.get("penalty", 0)) == 1
		var dry_end: bool = Vector2(end.x, end.z).distance_to(Vector2(terrain.water_center.x, terrain.water_center.z)) > terrain.water_radius
		if hazard_ok and dry_end:
			recovered = true
			break
	return _expect(recovered, "a miss into water should incur one penalty and recover to safe ground")

func _test_putting_and_cap() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(250.0, 0.0, TEST_Z), Vector3(258.0, 0.0, TEST_Z))
	var preview: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.55, 91)
	var shots: Array = preview.get("shots", [])
	var first: Dictionary = shots[0] if not shots.is_empty() else {}
	var putting: bool = String(first.get("club", "")) == "putter"
	var cap_ok: bool = int(preview.get("strokes", 99)) <= 14 and shots.size() <= 14
	return _expect(putting and cap_ok, "green preview should use a putter and obey the stroke cap")

func _test_analysis_profiles() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(290.0, 0.0, TEST_Z))
	var result: Array = ShotEngineClass.analyze(terrain, hole, 30, 4242)
	var shape_ok: bool = result.size() == 3
	var metrics_ok: bool = true
	for value in result:
		var profile: Dictionary = value
		metrics_ok = metrics_ok and profile.has("label") and profile.has("skill") and profile.has("average") and profile.has("hazard_rate") and profile.has("shots")
		metrics_ok = metrics_ok and float(profile.get("average", 0.0)) >= 1.0 and float(profile.get("hazard_rate", -1.0)) >= 0.0
	return _expect(shape_ok and metrics_ok, "analysis should return all three bounded profile metrics")

func _test_poor_green_putting() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(250.0, 0.0, 250.0)
	var cup: Vector3 = Vector3(266.0, 0.0, 250.0)
	terrain.paint_disk(tee, 20.0, 2)
	terrain.paint_disk(cup, 20.0, 2)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var pristine_total: int = 0
	var worn_total: int = 0
	for seed_value in range(60):
		var pristine: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.35, seed_value + 11)
		pristine_total += int(pristine.get("strokes", 14))
		for index in range(terrain.condition.size()):
			if int(terrain.surfaces[index]) == 2:
				terrain.condition[index] = 0.15
		var worn: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.35, seed_value + 11)
		worn_total += int(worn.get("strokes", 14))
		for index in range(terrain.condition.size()):
			if int(terrain.surfaces[index]) == 2:
				terrain.condition[index] = 1.0
	return _expect(float(worn_total) > float(pristine_total), "worn greens should raise average putts on a fixed seed set")

func _test_ob_replay_from_tee() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(80.0, 0.0, 500.0)
	var cup: Vector3 = Vector3(520.0, 0.0, 500.0)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 16.0, 1)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 16.0, 2)
	var hole: Dictionary = _hole(tee, cup)
	# Stakes crossing the corridor; a golfer standing past the line can only
	# play further into the out-of-bounds area, so every shot replays.
	terrain.add_object("ob_stakes", Vector3(310.0, 0.0, 440.0), 0.0, Vector3(310.0, 0.0, 560.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var replayed: bool = false
	for seed_value in range(40):
		rng.seed = seed_value + 900
		var result: Dictionary = ShotEngineClass.shot(terrain, Vector3(330.0, 0.0, 500.0), hole, 0.82, rng)
		if String(result.get("reason", "")) == "ob_penalty":
			replayed = is_equal_approx(float(result.get("end", Vector3.ZERO).x), 330.0) and is_equal_approx(float(result.get("end", Vector3.ZERO).z), 500.0)
			replayed = replayed and int(result.get("penalty", 0)) == 1
			if replayed:
				break
	return _expect(replayed, "OB drive should replay from the previous spot with a one-stroke penalty")

func _test_deep_bunker_recovery() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var bunker_center: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(360.0, 0.0, 300.0)
	terrain.paint_disk(bunker_center, 10.0, 4)
	terrain.paint_disk(cup, 16.0, 2)
	var flat_total: float = 0.0
	var deep_total: float = 0.0
	var hole: Dictionary = _hole(bunker_center + Vector3(-40.0, 0.0, 0.0), cup)
	for seed_value in range(30):
		var rng_a: RandomNumberGenerator = RandomNumberGenerator.new()
		rng_a.seed = seed_value + 40
		var flat_shot: Dictionary = ShotEngineClass.shot(terrain, bunker_center, hole, 0.7, rng_a)
		flat_total += _flat_distance(bunker_center, Vector3(flat_shot.get("end", bunker_center)))
		terrain.apply_brush(terrain.plan_bunker_shape(bunker_center, 8.0, 0.8))
		var rng_b: RandomNumberGenerator = RandomNumberGenerator.new()
		rng_b.seed = seed_value + 40
		var deep_shot: Dictionary = ShotEngineClass.shot(terrain, bunker_center, hole, 0.7, rng_b)
		deep_total += _flat_distance(bunker_center, Vector3(deep_shot.get("end", bunker_center)))
		for node in terrain.plan_bunker_shape(bunker_center, 8.0, 0.8).nodes:
			var index: int = int(node[0])
			terrain.heights[index] = float(node[1])
		terrain.touch()
	return _expect(deep_total < flat_total, "deep bunkers should shorten average recovery carry versus flat sand")

func _test_sloped_green_putting() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(240.0, 0.0, 250.0)
	var cup: Vector3 = Vector3(272.0, 0.0, 250.0)
	terrain.paint_disk(tee, 22.0, 2)
	terrain.paint_disk(cup, 22.0, 2)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var flat_total: int = 0
	var sloped_total: int = 0
	for seed_value in range(40):
		var flat: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.35, seed_value + 21)
		flat_total += int(flat.get("strokes", 14))
		terrain.apply_brush(terrain.plan_green_contour(cup + Vector3(-8.0, 0.0, 0.0), 6.0, 1.2, true))
		var sloped: Dictionary = ShotEngineClass.round_preview(terrain, hole, 0.35, seed_value + 21)
		sloped_total += int(sloped.get("strokes", 14))
		terrain.apply_brush(terrain.plan_green_contour(cup + Vector3(-8.0, 0.0, 0.0), 6.0, 1.2, false))
	return _expect(float(sloped_total) > float(flat_total), "sloped greens should raise average putts")

func _test_shaped_green_boundary() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var cup: Vector3 = Vector3(300.0, 0.0, 300.0)
	terrain.paint_disk(cup, 10.0, 2)
	var lobe: Vector3 = cup + Vector3(16.0, 0.0, 0.0)
	terrain.paint_disk(lobe, 8.0, 2)
	var hole: Dictionary = terrain.add_hole(Vector3(240.0, 0.0, 300.0), cup, 4)
	hole["green_radius"] = 12.0
	var on_lobe: bool = terrain.on_green(lobe, hole)
	var outside_radius: bool = lobe.distance_to(cup) > hole["green_radius"]
	return _expect(on_lobe and outside_radius, "connected green paint outside green_radius should still read as on the green")

func _test_hole_metrics() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(290.0, 0.0, TEST_Z))
	var first: Dictionary = ShotEngineClass.metrics(terrain, hole, 30, 4242)
	var second: Dictionary = ShotEngineClass.metrics(terrain, hole, 30, 4242)
	var failures: int = 0
	failures += _expect(first == second, "metrics are deterministic for a fixed seed")
	failures += _expect(first.has("difficulty") and first.has("fun") and first.has("pace_minutes"), "metrics expose report-card keys")

	var dry: FakeTerrain = FakeTerrain.new()
	var wet: FakeTerrain = FakeTerrain.new()
	wet.water_center = Vector3(195.0, 0.0, TEST_Z)
	wet.water_radius = 10.0
	var hazard_hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(210.0, 0.0, TEST_Z))
	var dry_metrics: Dictionary = ShotEngineClass.metrics(dry, hazard_hole, 30, 9001)
	var wet_metrics: Dictionary = ShotEngineClass.metrics(wet, hazard_hole, 30, 9001)
	failures += _expect(
		float(wet_metrics.get("decision", {}).get("value", 0.0)) > float(dry_metrics.get("decision", {}).get("value", 0.0)),
		"water guarding the green raises the decision score versus the dry hole"
	)
	failures += _expect(
		float(wet_metrics.get("beginner_avg", 0.0)) > float(dry_metrics.get("beginner_avg", 0.0)),
		"water guarding the green raises beginner scoring versus the dry hole"
	)

	var short_hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(210.0, 0.0, TEST_Z))
	short_hole["par"] = 4
	var short_metrics: Dictionary = ShotEngineClass.metrics(terrain, short_hole, 30, 5151)
	failures += _expect(float(short_metrics.get("difficulty", {}).get("value", 0.0)) < -0.5, "very short par 4 reads well below par difficulty")
	failures += _expect(str(short_metrics.get("difficulty", {}).get("note", "")).to_lower().contains("par 3"), "short par 4 suggests considering par 3")

	var medium_hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(290.0, 0.0, TEST_Z))
	medium_hole["par"] = 4
	var long_hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(400.0, 0.0, TEST_Z))
	long_hole["par"] = 4
	var medium_pace: float = float(ShotEngineClass.metrics(terrain, medium_hole, 20, 6060).get("pace_minutes", {}).get("value", 0.0))
	var long_pace: float = float(ShotEngineClass.metrics(terrain, long_hole, 20, 6060).get("pace_minutes", {}).get("value", 0.0))
	failures += _expect(long_pace > medium_pace, "pace_minutes grows with hole length")
	return failures

func _test_open_hole_aims_at_pin() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(210.0, 0.0, TEST_Z))
	var low: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.3, _rng(4))
	var high: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.9, _rng(4))
	var low_ok: bool = _flat_distance(Vector3(low.get("target", Vector3.ZERO)), Vector3(hole["cup"])) < 8.0
	var high_ok: bool = _flat_distance(Vector3(high.get("target", Vector3.ZERO)), Vector3(hole["cup"])) < 8.0
	return _expect(low_ok and high_ok, "an open reachable hole should aim near the pin at both skills")

func _test_water_guard_skill_split() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.water_center = Vector3(195.0, 0.0, TEST_Z)
	terrain.water_radius = 10.0
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(210.0, 0.0, TEST_Z))
	var low: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.28, _rng(11))
	var high: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.9, _rng(11))
	var low_reason: String = String(low.get("reason", ""))
	var high_reason: String = String(high.get("reason", ""))
	var low_safe: bool = String(low.get("plan", "")) == "conservative" or low_reason.contains("layup") or low_reason == "safe_side"
	var high_attack: bool = String(high.get("plan", "")) == "aggressive" or high_reason in ["approach", "carry_hazard", "green_hit"]
	var analysis: Array = ShotEngineClass.analyze(terrain, hole, 20, 77)
	var beginner_avg: float = 0.0
	var expert_avg: float = 0.0
	for profile_value in analysis:
		var profile: Dictionary = profile_value
		if String(profile.get("label", "")) == "beginner":
			beginner_avg = float(profile.get("average", 0.0))
		elif String(profile.get("label", "")) == "expert":
			expert_avg = float(profile.get("average", 0.0))
	return _expect(low_safe and high_attack and beginner_avg > expert_avg, "water in front of the green should make weak players lay up and keep expert scoring better")

func _test_long_hole_layup() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	var hole: Dictionary = _hole(Vector3(120.0, 0.0, TEST_Z), Vector3(330.0, 0.0, TEST_Z))
	var low: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.28, _rng(2))
	var high: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.88, _rng(2))
	var low_layup: bool = bool(low.get("layup", false)) or String(low.get("plan", "")) == "conservative"
	var high_go: bool = String(high.get("plan", "")) == "aggressive" or _flat_distance(Vector3(high.get("target", Vector3.ZERO)), Vector3(hole["cup"])) < 12.0
	return _expect(low_layup and high_go, "a long par 4 should be a layup for beginners and a go for experts")

func _test_lag_putt_option() -> int:
	var terrain: FakeTerrain = FakeTerrain.new()
	terrain.slope = Vector2(0.28, 0.0)
	var hole: Dictionary = _hole(Vector3(205.0, 0.0, TEST_Z), Vector3(226.0, 0.0, TEST_Z))
	hole["green_radius"] = 24.0
	var plan: Dictionary = ShotEngineClass._choose_target(terrain, hole["tee"], hole["cup"], hole, 0.18, 2, true)
	var lag: bool = String(plan.get("reason", "")) == "lag_putt" or String(plan.get("plan", "")) == "conservative"
	return _expect(lag, "a long sloped putt at low skill can lag short of the cup")

func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

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
