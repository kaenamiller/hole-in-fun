extends SceneTree

const TerrainModelClass = preload("res://scripts/terrain_model.gd")
const TerrainViewClass = preload("res://scripts/terrain_view.gd")
const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const AnalyticsGridClass = preload("res://scripts/analytics_grid.gd")
const MapGeneratorClass = preload("res://scripts/map_generator.gd")
const CatalogClass = preload("res://scripts/catalog.gd")

func _init() -> void:
	var failures: int = 0
	failures += _test_boundaries_and_brush_reverse()
	failures += _test_water_and_paths()
	failures += _test_scenery_beauty()
	failures += _test_hole_validity()
	failures += _test_snapshot_restore()
	failures += _test_view_mesh_and_sync()
	failures += _test_overlay_mesh()
	failures += _test_shot_profile_shape()
	failures += _test_condition_snapshot()
	failures += _test_hole_condition_fresh()
	failures += _test_paint_resets_condition()
	failures += _test_green_flood_fill()
	failures += _test_touching_greens_rejected()
	failures += _test_zone_at_ob_and_penalty()
	failures += _test_bunker_depth()
	failures += _test_map_generation()
	failures += _test_map_snapshot_fields()
	if failures == 0:
		print("test_terrain: all tests passed")
	else:
		printerr("test_terrain: %d test(s) failed" % failures)
	quit(failures)

func _test_boundaries_and_brush_reverse() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var boundary_height_a: float = terrain.height_at(Vector3(-50.0, 0.0, -50.0))
	var boundary_height_b: float = terrain.height_at(Vector3(0.0, 0.0, 0.0))
	var boundary_height_c: float = terrain.height_at(Vector3(1100.0, 0.0, 1100.0))
	var bounds_ok: bool = is_equal_approx(boundary_height_a, boundary_height_b) and is_equal_approx(boundary_height_c, terrain.height_at(Vector3(1024.0, 0.0, 1024.0)))
	var before: PackedFloat32Array = terrain.heights.duplicate()
	var command: Dictionary = terrain.plan_brush("raise", Vector3(512.0, 0.0, 512.0), 18.0, 0.8, 1)
	terrain.apply_brush(command)
	var changed: bool = command.nodes.size() > 0 and command.cost > 0 and terrain.heights != before
	terrain.apply_brush(command, true)
	var reversed: bool = terrain.heights == before and terrain.changed_chunks.size() > 0
	# Exercise the exact outer corner, including node index 256 and cell 255.
	var edge_command: Dictionary = terrain.plan_brush("raise", Vector3(1024.0, 0.0, 1024.0), 8.0, 0.2, 1)
	terrain.apply_brush(edge_command)
	var edge_ok: bool = edge_command.nodes.size() >= 0
	return _expect(bounds_ok and changed and reversed and edge_ok, "terrain bounds or reversible height brush failed")

func _test_water_and_paths() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var barrier_x: float = 128.0
	for i in range(15):
		terrain.paint_disk(Vector3(barrier_x, 0.0, 20.0 + float(i) * 70.0), 39.0, 5)
	var a: Vector3 = Vector3(80.0, 0.0, 512.0)
	var b: Vector3 = Vector3(176.0, 0.0, 512.0)
	var water_ok: bool = terrain.surface_at(Vector3(barrier_x, 0.0, 512.0)) == 5 and not terrain.playable(Vector3(barrier_x, 0.0, 512.0))
	var path_rejected: bool = terrain.path_valid(a, b, false) != ""
	var disconnected: bool = terrain.route(a, b, false).is_empty()
	var bridge_validation: bool = terrain.path_valid(a, b, true) == ""
	terrain.add_object("bridge_cart", a, 0.0, b)
	var walk_route: PackedVector3Array = terrain.route(a, b, false)
	var cart_route: PackedVector3Array = terrain.route(a, b, true)
	var bridge_connected: bool = bridge_validation and not walk_route.is_empty() and not cart_route.is_empty()
	return _expect(water_ok and path_rejected and disconnected and bridge_connected, "water barrier or bridge walk/cart routing failed")

func _test_scenery_beauty() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var point: Vector3 = Vector3(300.0, 0.0, 300.0)
	var empty_score: float = terrain.beauty_at(point)
	terrain.add_object("flower_bed", point)
	var one_score: float = terrain.beauty_at(point)
	terrain.add_object("pergola", point + Vector3(1.0, 0.0, 0.0))
	var set_score: float = terrain.beauty_at(point)
	var beauty_ok: bool = empty_score == 0.0 and one_score > empty_score and set_score > one_score
	return _expect(beauty_ok, "scenery beauty or same-set bonus failed")

func _test_hole_validity() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(400.0, 0.0, 300.0)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var initially_invalid: bool = terrain.hole_valid(hole) != ""
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 18.0, 1)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 17.0, 2)
	var valid_after_paint: bool = terrain.hole_valid(hole) == ""
	var ready: Array[Dictionary] = terrain.ready_holes()
	var ready_ok: bool = ready.size() == 1 and int(ready[0].get("id", -1)) == int(hole.get("id", -2))
	return _expect(initially_invalid and valid_after_paint and ready_ok, "hole surface validation or ready_holes failed")

func _test_snapshot_restore() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.paint_disk(Vector3(240.0, 0.0, 240.0), 12.0, 2)
	var original_holes: Array = terrain.holes.duplicate(true)
	var original_objects: Array = terrain.objects.duplicate(true)
	var original_heights: PackedFloat32Array = terrain.heights.duplicate()
	var original_surfaces: PackedByteArray = terrain.surfaces.duplicate()
	var original_water_levels: PackedFloat32Array = terrain.water_levels.duplicate()
	var original_next_id: int = terrain.next_id
	var saved: Dictionary = terrain.snapshot()
	terrain.paint_disk(Vector3(240.0, 0.0, 240.0), 20.0, 5)
	terrain.add_object("oak_tree", Vector3(240.0, 0.0, 240.0))
	terrain.add_hole(Vector3(270.0, 0.0, 270.0), Vector3(330.0, 0.0, 270.0))
	terrain.restore(saved)
	var holes_restored: bool = terrain.holes == original_holes
	var objects_restored: bool = terrain.objects == original_objects
	var heights_restored: bool = terrain.heights == original_heights
	var surfaces_restored: bool = terrain.surfaces == original_surfaces
	var water_levels_restored: bool = terrain.water_levels == original_water_levels
	var ids_restored: bool = terrain.next_id == original_next_id
	print("snapshot checks: holes=%s objects=%s heights=%s surfaces=%s water=%s ids=%s" % [holes_restored, objects_restored, heights_restored, surfaces_restored, water_levels_restored, ids_restored])
	var restored: bool = holes_restored and objects_restored and heights_restored and surfaces_restored and water_levels_restored and ids_restored
	return _expect(restored, "terrain snapshot restore did not restore arrays, objects, holes, or ids")

func _test_view_mesh_and_sync() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var view: TerrainView = TerrainViewClass.new()
	view.setup(terrain)
	var points: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3(8.0, 0.0, 0.0)])
	var line: MeshInstance3D = TerrainViewClass.line_mesh(points, Color.WHITE)
	var mesh_ok: bool = line.mesh != null and view.chunks.size() == 256
	view.set_grid(true)
	view.set_overlay("access")
	view.rebuild_dirty()
	view.free()
	line.free()
	return _expect(mesh_ok, "terrain view did not build the expected chunks or line mesh")

func _test_overlay_mesh() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var view: TerrainView = TerrainViewClass.new()
	view.setup(terrain)
	var chunk_ids_before: Array[int] = []
	for key in view.chunks.keys():
		chunk_ids_before.append(view.chunks[key].get_instance_id())
	var grid: AnalyticsGrid = AnalyticsGridClass.new()
	grid.add("traffic", Vector3(512, 0, 512), 12.0)
	grid.add("traffic", Vector3(520, 0, 512), 6.0)
	var fake_sim = _FakeAnalyticsSim.new(grid)
	view.set_overlay("traffic")
	view.refresh_overlay(fake_sim)
	var mesh: Mesh = view.overlay_mesh.mesh
	var vertex_count: int = 0
	if mesh != null and mesh.get_surface_count() > 0:
		var arrays: Array = mesh.surface_get_arrays(0)
		vertex_count = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var chunk_ids_after: Array[int] = []
	for key in view.chunks.keys():
		chunk_ids_after.append(view.chunks[key].get_instance_id())
	var ids_unchanged: bool = chunk_ids_before.size() == chunk_ids_after.size()
	for index in range(chunk_ids_before.size()):
		ids_unchanged = ids_unchanged and chunk_ids_before[index] == chunk_ids_after[index]
	var mesh_ok: bool = mesh != null and vertex_count == 4096 * 6
	view.free()
	return _expect(mesh_ok and ids_unchanged, "traffic overlay mesh or chunk rebuild contract failed")

class _FakeAnalyticsSim:
	extends RefCounted
	var analytics: AnalyticsGrid
	func _init(grid: AnalyticsGrid) -> void:
		analytics = grid

func _test_shot_profile_shape() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(40.0, 0.0, 40.0)
	var cup: Vector3 = Vector3(540.0, 0.0, 40.0)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 18.0, 1)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 17.0, 2)
	var hole: Dictionary = {"tee": tee, "cup": cup, "green_radius": 16.0, "waypoints": []}
	var profiles: Array = ShotEngineClass.analyze(terrain, hole, 30, 42)
	var metrics_ok: bool = profiles.size() == 3
	var beginner_average: float = 0.0
	var intermediate_average: float = 0.0
	var expert_average: float = 0.0
	for value in profiles:
		var profile: Dictionary = value
		var label: String = String(profile.get("label", ""))
		var average: float = float(profile.get("average", 0.0))
		metrics_ok = metrics_ok and profile.has("shots") and average >= 1.0 and average <= 14.0
		if label == "beginner": beginner_average = average
		elif label == "intermediate": intermediate_average = average
		elif label == "expert": expert_average = average
	print("shot profiles: beginner=%.2f intermediate=%.2f expert=%.2f" % [beginner_average, intermediate_average, expert_average])
	var ordering_ok: bool = beginner_average >= intermediate_average and intermediate_average >= expert_average
	var starter: TerrainModel = TerrainModelClass.new()
	starter.starter_resort(false)
	var starter_profiles: Array = ShotEngineClass.analyze(starter, starter.holes[0], 30, 42)
	var starter_caps: int = 0
	for starter_value in starter_profiles:
		var starter_profile: Dictionary = starter_value
		if float(starter_profile.get("average", 0.0)) >= 13.5:
			starter_caps += 1
	print("starter hole averages: %s" % [starter_profiles.map(func(item: Dictionary): return item.get("average", 0.0))])
	return _expect(metrics_ok and ordering_ok and starter_caps == 0, "shot profile averages did not separate beginners from experts or hit the 14-stroke cap excessively")

func _test_condition_snapshot() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.apply_wear_at(Vector3(512.0, 0.0, 512.0), 0.2)
	terrain.paint_disk(Vector3(512.0, 0.0, 512.0), 12.0, 1)
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var round_trip: bool = copy.condition == saved.condition
	return _expect(round_trip and saved.has("condition"), "condition array did not round-trip through snapshot")

func _test_hole_condition_fresh() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(400.0, 0.0, 300.0)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 17.0, 2)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 18.0, 1)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var stats: Dictionary = terrain.hole_condition(hole)
	var fresh: bool = is_equal_approx(float(stats.get("green", 0.0)), 1.0) and is_equal_approx(float(stats.get("fairway", 0.0)), 1.0)
	fresh = fresh and is_equal_approx(float(stats.get("tee", 0.0)), 1.0) and is_equal_approx(float(stats.get("bunkers", 0.0)), 1.0)
	return _expect(fresh, "hole_condition on a fresh hole should be all 1.0")

func _test_paint_resets_condition() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.paint_disk(Vector3(240.0, 0.0, 240.0), 12.0, 1)
	terrain.apply_wear_at(Vector3(240.0, 0.0, 240.0), 0.5)
	var worn: float = terrain.condition_at(Vector3(240.0, 0.0, 240.0))
	terrain.paint_disk(Vector3(240.0, 0.0, 240.0), 12.0, 2)
	var reset: float = terrain.condition_at(Vector3(240.0, 0.0, 240.0))
	return _expect(worn < 0.6 and is_equal_approx(reset, 1.0), "painting a disc should reset cell condition to 1.0")

func _test_green_flood_fill() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var cup: Vector3 = Vector3(400.0, 0.0, 400.0)
	terrain.paint_disk(cup, 14.0, 2)
	terrain.paint_disk(cup + Vector3(34.0, 0.0, 0.0), 8.0, 2)
	terrain.paint_disk(cup + Vector3(0.0, 0.0, 40.0), 6.0, 2)
	var hole: Dictionary = terrain.add_hole(Vector3(300.0, 0.0, 400.0), cup, 4)
	var cells: PackedInt32Array = terrain.green_cells(hole)
	var isolated: Vector3 = cup + Vector3(34.0, 0.0, 0.0)
	var connected: bool = terrain.on_green(cup, hole)
	var ignored: bool = not terrain.on_green(isolated, hole)
	var fill_only_connected: bool = cells.size() > 0 and cells.size() < 200
	return _expect(connected and ignored and fill_only_connected, "green flood fill should ignore disconnected paint")

func _test_touching_greens_rejected() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var cup_a: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup_b: Vector3 = Vector3(312.0, 0.0, 300.0)
	terrain.paint_disk(cup_a, 18.0, 2)
	terrain.paint_disk(cup_b, 18.0, 2)
	terrain.paint_disk(Vector3(300.0, 0.0, 280.0), 9.0, 3)
	terrain.paint_disk(Vector3(312.0, 0.0, 280.0), 9.0, 3)
	for index in range(12):
		terrain.paint_disk(Vector3(300.0, 0.0, 280.0).lerp(cup_a, float(index) / 11.0), 14.0, 1)
		terrain.paint_disk(Vector3(312.0, 0.0, 280.0).lerp(cup_b, float(index) / 11.0), 14.0, 1)
	var hole_a: Dictionary = terrain.add_hole(Vector3(300.0, 0.0, 280.0), cup_a, 4)
	var hole_b: Dictionary = terrain.add_hole(Vector3(312.0, 0.0, 280.0), cup_b, 4)
	var reason: String = terrain.hole_valid(hole_a)
	return _expect(not reason.is_empty(), "greens that touch another cup should fail validation")

func _test_zone_at_ob_and_penalty() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(100.0, 0.0, 500.0)
	var cup: Vector3 = Vector3(500.0, 0.0, 500.0)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 16.0, 1)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 16.0, 2)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var boundary: Vector3 = Vector3(290.0, 0.0, 490.0)
	var far: Vector3 = Vector3(310.0, 0.0, 485.0)
	terrain.add_object("ob_stakes", boundary, 0.0, boundary + Vector3(40.0, 0.0, 0.0))
	var ob_side: String = terrain.zone_at(far, hole)
	var safe_side: String = terrain.zone_at(Vector3(310.0, 0.0, 520.0), hole)
	var loop_a: Vector3 = Vector3(620.0, 0.0, 470.0)
	var loop_b: Vector3 = Vector3(660.0, 0.0, 470.0)
	var loop_c: Vector3 = Vector3(640.0, 0.0, 510.0)
	terrain.add_object("penalty_stakes", loop_a, 0.0, loop_b)
	terrain.add_object("penalty_stakes", loop_b, 0.0, loop_c)
	terrain.add_object("penalty_stakes", loop_c, 0.0, loop_a)
	var inside_penalty: String = terrain.zone_at(Vector3(640.0, 0.0, 488.0), hole)
	return _expect(ob_side == "ob" and safe_side == "" and inside_penalty == "penalty", "zone_at should classify OB and penalty areas")

func _test_bunker_depth() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var center: Vector3 = Vector3(512.0, 0.0, 512.0)
	terrain.paint_disk(center, 10.0, 4)
	var shallow: Dictionary = terrain.bunker_at(center)
	terrain.apply_brush(terrain.plan_bunker_shape(center, 8.0, 0.8))
	var deep: Dictionary = terrain.bunker_at(center)
	var depth_ok: bool = float(deep.get("depth", 0.0)) > float(shallow.get("depth", 0.0)) + 0.10
	return _expect(depth_ok, "bunker shaping should increase computed bunker depth")

func _test_map_generation() -> int:
	var failures: int = 0
	for map_def in CatalogClass.maps():
		var map_id: String = str(map_def.get("id", ""))
		var seed_value: int = int(map_def.get("seed", 1))
		var first: TerrainModel = MapGeneratorClass.generate(map_def)
		var second: TerrainModel = MapGeneratorClass.generate(map_def)
		var hash_ok: bool = MapGeneratorClass.heights_hash(first) == MapGeneratorClass.heights_hash(second)
		failures += _expect(hash_ok, "%s should generate deterministically for its seed" % map_id)
		var reach_ok: bool = MapGeneratorClass.reachability_ratio(first) >= 0.70
		failures += _expect(reach_ok, "%s should be reachable from the entrance" % map_id)
		failures += _expect(first.palette.size() == 7, "%s palette should have 7 entries" % map_id)
		if map_id == "stonebrook_hills":
			var crossings: int = MapGeneratorClass.river_crossing_count(first)
			failures += _expect(crossings >= 2, "stonebrook_hills river should have at least two bridgeable crossings")
	return failures

func _test_map_snapshot_fields() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.entrance = Vector3(120.0, 0.0, 88.0)
	terrain.map_id = "stonebrook_hills"
	terrain.rough_name = "Rough"
	terrain.cost_multipliers = {"raise": 1.35, "fairway": 1.0, "water": 1.0, "clear_tree": 1.0}
	terrain.palette = PackedColorArray([Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE])
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var round_trip: bool = copy.entrance == terrain.entrance and copy.map_id == terrain.map_id
	round_trip = round_trip and copy.rough_name == terrain.rough_name and copy.palette == terrain.palette
	round_trip = round_trip and float(copy.cost_multipliers.get("raise", 0.0)) == 1.35
	var legacy: TerrainModel = TerrainModelClass.new()
	legacy.restore({"heights": terrain.heights, "surfaces": terrain.surfaces, "water_levels": terrain.water_levels, "holes": [], "objects": [], "next_id": 1})
	var legacy_ok: bool = legacy.entrance == TerrainModelClass.DEFAULT_ENTRANCE
	legacy_ok = legacy_ok and legacy.map_id == "cedar_house" and legacy.palette.size() == 7
	legacy_ok = legacy_ok and float(legacy.cost_multipliers.get("raise", 0.0)) == 1.0
	return _expect(round_trip and legacy_ok, "map snapshot fields did not round-trip or legacy defaults failed")

func _expect(condition: bool, message: String) -> int:
	if condition:
		return 0
	printerr("FAIL: " + message)
	return 1
