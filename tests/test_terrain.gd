extends SceneTree

const TerrainModelClass = preload("res://scripts/terrain_model.gd")
const TerrainViewClass = preload("res://scripts/terrain_view.gd")
const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const AnalyticsGridClass = preload("res://scripts/analytics_grid.gd")
const MapGeneratorClass = preload("res://scripts/map_generator.gd")
const CatalogClass = preload("res://scripts/catalog.gd")
const HoleMowingClass = preload("res://scripts/hole_mowing.gd")
const CourseContoursClass = preload("res://scripts/course_contours.gd")
const WaterFieldClass = preload("res://scripts/water_field.gd")
const WaterRipplePoolClass = preload("res://scripts/water_ripple_pool.gd")
const GroundCoverClass = preload("res://scripts/ground_cover.gd")
const GroundCoverAssetsClass = preload("res://scripts/ground_cover_assets.gd")

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
	failures += _test_fairway_ownership_fallback()
	failures += _test_mowing_chunk_seam_stability()
	failures += _test_mowing_save_round_trip()
	failures += _test_contour_legacy_save()
	failures += _test_contour_save_round_trip()
	failures += _test_contour_gameplay_agreement()
	failures += _test_contour_undo()
	failures += _test_contour_cup_ownership()
	failures += _test_contour_chunk_bounds()
	failures += _test_ground_cover_determinism()
	failures += _test_ground_cover_snapshot_seed()
	failures += _test_water_depth_field()
	failures += _test_water_body_ids()
	failures += _test_water_field_restore()
	failures += _test_water_ripple_contract()
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

func _test_fairway_ownership_fallback() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee_a: Vector3 = Vector3(200.0, 0.0, 300.0)
	var cup_a: Vector3 = Vector3(360.0, 0.0, 300.0)
	var tee_b: Vector3 = Vector3(620.0, 0.0, 300.0)
	var cup_b: Vector3 = Vector3(780.0, 0.0, 300.0)
	for index in range(20):
		terrain.paint_disk(tee_a.lerp(cup_a, float(index) / 19.0), 16.0, 1)
		terrain.paint_disk(tee_b.lerp(cup_b, float(index) / 19.0), 16.0, 1)
	terrain.paint_disk(tee_a, 9.0, 3)
	terrain.paint_disk(cup_a, 16.0, 2)
	terrain.paint_disk(tee_b, 9.0, 3)
	terrain.paint_disk(cup_b, 16.0, 2)
	var hole_a: Dictionary = terrain.add_hole(tee_a, cup_a, 4)
	var hole_b: Dictionary = terrain.add_hole(tee_b, cup_b, 4)
	var midpoint: Vector3 = Vector3(490.0, 0.0, 300.0)
	terrain.paint_disk(midpoint, 10.0, 1)
	var owner_mid: int = terrain.fairway_owner(midpoint)
	var owner_near_a: int = terrain.fairway_owner(Vector3(330.0, 0.0, 300.0))
	var owner_near_b: int = terrain.fairway_owner(Vector3(650.0, 0.0, 300.0))
	var authored_index: int = terrain._cell_index(midpoint)
	hole_a["mowing"] = {"fairway_cells": [authored_index]}
	terrain.touch()
	var authored_owner: int = terrain.fairway_owner(midpoint)
	var fallback_ok: bool = owner_near_a == int(hole_a.get("id", -1))
	fallback_ok = fallback_ok and owner_near_b == int(hole_b.get("id", -1))
	fallback_ok = fallback_ok and owner_mid in [int(hole_a.get("id", -1)), int(hole_b.get("id", -1))]
	var authored_ok: bool = authored_owner == int(hole_a.get("id", -1))
	return _expect(fallback_ok and authored_ok, "fairway ownership fallback or authored override failed")

func _test_mowing_chunk_seam_stability() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(500.0, 0.0, 300.0)
	for index in range(20):
		terrain.paint_disk(tee.lerp(cup, float(index) / 19.0), 16.0, 1)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 16.0, 2)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var pattern: Dictionary = HoleMowingClass.effective_pattern(hole)
	var dir: Vector2 = Vector2(cos(float(pattern["orientation"])), sin(float(pattern["orientation"])))
	var world_x: float = 512.0
	var sample_a: float = HoleMowingClass.stripe_sample(Vector2(world_x, 512.0), dir, float(pattern["width"]), float(pattern["phase"]))
	var sample_b: float = HoleMowingClass.stripe_sample(Vector2(world_x + 0.001, 512.0), dir, float(pattern["width"]), float(pattern["phase"]))
	var image: Image = HoleMowingClass.build_pattern_image(terrain)
	var cell_a: int = 128 * 256 + 128
	var cell_b: int = 128 * 256 + 129
	var bytes_a: Color = image.get_pixel(cell_a % 256, int(cell_a / 256))
	var bytes_b: Color = image.get_pixel(cell_b % 256, int(cell_b / 256))
	var seam_ok: bool = absf(sample_a - sample_b) < 0.02
	seam_ok = seam_ok and absf(bytes_a.r - bytes_b.r) < 0.02 and absf(bytes_a.g - bytes_b.g) < 0.02
	return _expect(seam_ok, "mowing stripe phase is not stable across adjacent cells")

func _test_mowing_save_round_trip() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 300.0)
	var cup: Vector3 = Vector3(420.0, 0.0, 300.0)
	terrain.paint_disk(tee, 9.0, 3)
	terrain.paint_disk(cup, 16.0, 2)
	for index in range(12):
		terrain.paint_disk(tee.lerp(cup, float(index) / 11.0), 14.0, 1)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	hole["mowing"] = {
		"orientation": 1.25,
		"width": 0.72,
		"phase": 0.4,
		"contrast": 0.8,
		"pattern_type": "straight",
		"fairway_cells": [terrain._cell_index(Vector3(360.0, 0.0, 300.0))],
	}
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var restored_hole: Dictionary = copy.holes[0]
	var mowing: Dictionary = restored_hole.get("mowing", {})
	var round_trip: bool = saved.has("mowing_version")
	round_trip = round_trip and is_equal_approx(float(mowing.get("orientation", 0.0)), 1.25)
	round_trip = round_trip and is_equal_approx(float(mowing.get("width", 0.0)), 0.72)
	round_trip = round_trip and is_equal_approx(float(mowing.get("phase", 0.0)), 0.4)
	round_trip = round_trip and is_equal_approx(float(mowing.get("contrast", 0.0)), 0.8)
	round_trip = round_trip and int((mowing.get("fairway_cells", []) as Array)[0]) == terrain._cell_index(Vector3(360.0, 0.0, 300.0))
	var legacy: TerrainModel = TerrainModelClass.new()
	legacy.starter_resort(false)
	var legacy_pattern: Dictionary = HoleMowingClass.effective_pattern(legacy.holes[0])
	var legacy_ok: bool = legacy_pattern.has("orientation") and float(legacy_pattern.get("width", 0.0)) > 0.0
	return _expect(round_trip and legacy_ok, "mowing metadata did not round-trip or legacy defaults missing")

func _ellipse_points(center: Vector2, radius_x: float, radius_z: float, segments: int = 28) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index in range(segments):
		var angle: float = float(index) / float(segments) * TAU
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_z))
	return points

func _test_contour_legacy_save() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.starter_resort(false)
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var legacy_ok: bool = not saved.has("course_features") or (saved.get("course_features", []) as Array).is_empty()
	legacy_ok = legacy_ok and copy.course_features.is_empty()
	legacy_ok = legacy_ok and copy.holes.size() == terrain.holes.size()
	return _expect(legacy_ok, "legacy saves without course_features should restore unchanged")

func _test_contour_save_round_trip() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var cup: Vector3 = Vector3(360.0, 0.0, 360.0)
	var bunker: Vector3 = Vector3(390.0, 0.0, 330.0)
	var green_feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "green", 7, _ellipse_points(Vector2(cup.x, cup.z), 14.0, 12.0))
	var bunker_feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "bunker", 7, _ellipse_points(Vector2(bunker.x, bunker.z), 8.0, 7.0))
	terrain.course_features = [green_feature, bunker_feature]
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var round_trip: bool = saved.has("contours_version") and int(saved.get("contours_version", 0)) == CourseContoursClass.SCHEMA_VERSION
	round_trip = round_trip and copy.course_features.size() == 2
	round_trip = round_trip and int(copy.course_features[0].get("id", -1)) == int(green_feature.get("id", -2))
	round_trip = round_trip and str(copy.course_features[1].get("kind", "")) == "bunker"
	return _expect(round_trip, "course feature metadata did not round-trip")

func _test_contour_gameplay_agreement() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var cup: Vector3 = Vector3(360.0, 0.0, 360.0)
	var bunker: Vector3 = Vector3(390.0, 0.0, 330.0)
	var green_feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "green", 7, _ellipse_points(Vector2(cup.x, cup.z), 14.0, 12.0))
	var bunker_feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "bunker", 7, _ellipse_points(Vector2(bunker.x, bunker.z), 8.0, 7.0))
	var command: Dictionary = terrain.plan_feature_contour(green_feature)
	terrain.apply_contour_command(command)
	command = terrain.plan_feature_contour(bunker_feature)
	terrain.apply_contour_command(command)
	var inside_green: Vector3 = cup
	var outside_green: Vector3 = cup + Vector3(20.0, 0.0, 0.0)
	var inside_bunker: Vector3 = bunker
	var outside_bunker: Vector3 = bunker + Vector3(12.0, 0.0, 0.0)
	var agreement_ok: bool = terrain.surface_at(inside_green) == 2
	agreement_ok = agreement_ok and terrain.surface_at(outside_green) != 2
	agreement_ok = agreement_ok and terrain.surface_at(inside_bunker) == 4
	agreement_ok = agreement_ok and terrain.surface_at(outside_bunker) != 4
	agreement_ok = agreement_ok and CourseContoursClass.gameplay_surface_matches(green_feature, terrain, inside_green)
	agreement_ok = agreement_ok and CourseContoursClass.gameplay_surface_matches(bunker_feature, terrain, inside_bunker)
	var render_inside: float = CourseContoursClass.render_weight(green_feature, Vector2(inside_green.x, inside_green.z))
	var render_outside: float = CourseContoursClass.render_weight(green_feature, Vector2(outside_green.x, outside_green.z))
	agreement_ok = agreement_ok and render_inside > 0.9 and render_outside < 0.1
	return _expect(agreement_ok, "authored contours disagree with raster gameplay surfaces")

func _test_contour_undo() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var center: Vector3 = Vector3(420.0, 0.0, 420.0)
	var before_surfaces: PackedByteArray = terrain.surfaces.duplicate()
	var before_heights: PackedFloat32Array = terrain.heights.duplicate()
	var feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "green", 3, _ellipse_points(Vector2(center.x, center.z), 12.0, 10.0))
	var command: Dictionary = terrain.plan_feature_contour(feature)
	var cost: float = float(command.get("cost", 0.0))
	terrain.apply_contour_command(command)
	var changed: bool = terrain.surfaces != before_surfaces or terrain.heights != before_heights
	terrain.apply_contour_command(command, true)
	var restored: bool = terrain.surfaces == before_surfaces and terrain.heights == before_heights
	restored = restored and terrain.course_features.is_empty()
	return _expect(changed and restored and cost > 0.0, "contour undo did not restore raster, heights, and feature data")

func _test_contour_cup_ownership() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var tee: Vector3 = Vector3(300.0, 0.0, 360.0)
	var cup: Vector3 = Vector3(360.0, 0.0, 360.0)
	var hole: Dictionary = terrain.add_hole(tee, cup, 4)
	var feature: Dictionary = CourseContoursClass.make_feature(int(hole.get("id", -1)), "green", int(hole.get("id", -1)), _ellipse_points(Vector2(cup.x, cup.z), 15.0, 13.0))
	var command: Dictionary = terrain.plan_feature_contour(feature)
	terrain.apply_contour_command(command)
	var owned: bool = terrain.on_green(cup, hole)
	var lobe: Vector3 = cup + Vector3(8.0, 0.0, 6.0)
	var lobe_owned: bool = terrain.on_green(lobe, hole)
	return _expect(owned and lobe_owned, "cup ownership should follow rasterized green feature")

func _test_contour_chunk_bounds() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var center: Vector3 = Vector3(132.0, 0.0, 132.0)
	var feature: Dictionary = CourseContoursClass.make_feature(terrain.uid(), "bunker", -1, _ellipse_points(Vector2(center.x, center.z), 10.0, 9.0))
	var command: Dictionary = terrain.plan_feature_contour(feature)
	terrain.changed_chunks.clear()
	terrain.apply_contour_command(command)
	var chunk: Vector2i = Vector2i(int(center.x / 64.0), int(center.z / 64.0))
	var marked: bool = terrain.changed_chunks.has(chunk)
	var view: TerrainView = TerrainViewClass.new()
	view.setup(terrain)
	view.rebuild_dirty()
	var has_mesh: bool = view.chunks.has(chunk)
	view.free()
	return _expect(marked and has_mesh, "contour edits should mark and rebuild intersecting chunks")

func _test_ground_cover_determinism() -> int:
	if not GroundCoverAssetsClass.available():
		return 0
	var terrain: TerrainModel = MapGeneratorClass.generate(CatalogClass.map("cedar_house"))
	terrain.starter_resort()
	var settings: GraphicsSettings = GraphicsSettings.defaults()
	var region: Vector2i = GroundCoverClass.region_key_for_point(Vector3(280.0, 0.0, 280.0))
	var first: Array = GroundCoverClass.build_region_batches(terrain, region, settings)
	terrain.paint_disk(Vector3(900.0, 0.0, 900.0), 12.0, 1)
	var second: Array = GroundCoverClass.build_region_batches(terrain, region, settings)
	var stable: bool = str(first) == str(second)
	return _expect(stable, "distant terrain edits must not reshuffle unrelated ground-cover regions")

func _test_ground_cover_snapshot_seed() -> int:
	var terrain: TerrainModel = MapGeneratorClass.generate(CatalogClass.map("cedar_house"))
	terrain.generation_seed = 51515
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var restored: bool = int(copy.generation_seed) == 51515
	restored = restored and GroundCoverClass.scatter_seed_for(copy) == GroundCoverClass.scatter_seed_for(terrain)
	return _expect(restored, "generation_seed round-trips for scatter determinism")

func _paint_water_cell(terrain: TerrainModel, x: int, z: int, level: float) -> void:
	var index: int = z * 256 + x
	terrain.surfaces[index] = 5
	terrain.water_levels[index] = level
	terrain.mark_water_field_dirty(Rect2(float(x) * 4.0, float(z) * 4.0, 4.0, 4.0))

func _test_water_depth_field() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	var center: Vector3 = Vector3(512.0, 0.0, 512.0)
	terrain.paint_disk(center, 10.0, 5)
	for z in range(120, 136):
		for x in range(120, 136):
			var index: int = z * 256 + x
			terrain.water_levels[index] = 1.2
	terrain.mark_water_field_dirty(Rect2(480.0, 480.0, 64.0, 64.0))
	terrain.ensure_water_field()
	var shallow: Dictionary = terrain.water_body_at(center + Vector3(-8.0, 0.0, 0.0))
	var deep: Dictionary = terrain.water_body_at(center)
	terrain.apply_brush(terrain.plan_brush("lower", center, 8.0, 1.2, 0))
	var lowered: Dictionary = terrain.water_body_at(center)
	var depth_ok: bool = float(deep.get("depth", 0.0)) > float(shallow.get("depth", 0.0)) + 0.05
	depth_ok = depth_ok and float(lowered.get("depth", 0.0)) > float(deep.get("depth", 0.0)) + 0.05
	depth_ok = depth_ok and float(shallow.get("shore_distance", 0.0)) < float(deep.get("shore_distance", 0.0))
	return _expect(depth_ok, "water depth and shore distance should follow basin height")

func _test_water_body_ids() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	_paint_water_cell(terrain, 40, 40, 0.5)
	_paint_water_cell(terrain, 41, 40, 0.5)
	_paint_water_cell(terrain, 80, 80, 2.0)
	_paint_water_cell(terrain, 81, 80, 2.0)
	WaterFieldClass.full_rebuild(terrain)
	var low: Dictionary = terrain.water_body_at(Vector3(162.0, 0.0, 162.0))
	var high: Dictionary = terrain.water_body_at(Vector3(322.0, 0.0, 322.0))
	var ids_ok: bool = int(low.get("body_id", -1)) >= 0 and int(high.get("body_id", -1)) >= 0
	ids_ok = ids_ok and int(low.get("body_id", -1)) != int(high.get("body_id", -1))
	ids_ok = ids_ok and int(low.get("body_id", -1)) == int(terrain.water_body_at(Vector3(166.0, 0.0, 162.0)).get("body_id", -2))
	return _expect(ids_ok, "connected water at matching levels should share a stable body id")

func _test_water_field_restore() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.paint_disk(Vector3(300.0, 0.0, 300.0), 12.0, 5)
	var before: Dictionary = terrain.water_body_at(Vector3(300.0, 0.0, 300.0))
	var saved: Dictionary = terrain.snapshot()
	var copy: TerrainModel = TerrainModelClass.new()
	copy.restore(saved)
	var after: Dictionary = copy.water_body_at(Vector3(300.0, 0.0, 300.0))
	var restored: bool = is_equal_approx(float(before.get("depth", 0.0)), float(after.get("depth", 0.0)))
	restored = restored and int(before.get("body_id", -2)) == int(after.get("body_id", -3))
	copy.paint_disk(Vector3(300.0, 0.0, 300.0), 12.0, 0)
	copy.ensure_water_field()
	var drained: Dictionary = copy.water_body_at(Vector3(300.0, 0.0, 300.0))
	restored = restored and int(drained.get("body_id", -1)) == -1
	return _expect(restored, "water field should restore and invalidate after drain")

func _test_water_ripple_contract() -> int:
	var terrain: TerrainModel = TerrainModelClass.new()
	terrain.paint_disk(Vector3(400.0, 0.0, 400.0), 10.0, 5)
	var center: Vector3 = Vector3(400.0, 0.0, 400.0)
	var center_index: int = terrain._cell_index(center)
	terrain.water_levels[center_index] = terrain.height_at(center) + 1.0
	terrain.mark_water_field_dirty(Rect2(360.0, 360.0, 80.0, 80.0))
	terrain.ensure_water_field()
	var sample: Dictionary = terrain.water_body_at(center)
	var body_id: int = int(sample.get("body_id", -1))
	var pool: WaterRipplePool = WaterRipplePoolClass.new()
	pool.configure(4)
	var accepted: bool = body_id >= 0 and float(sample.get("depth", 0.0)) > 0.0
	accepted = accepted and pool.submit(body_id, center, 1.0, 6.0, 0.8, terrain)
	var rejected_body: bool = not pool.submit(body_id + 999, center, 1.1, 6.0, 0.8, terrain)
	var rejected_dry: bool = not pool.submit(body_id, Vector3(700.0, 0.0, 700.0), 1.2, 6.0, 0.8, terrain)
	terrain.paint_disk(center, 10.0, 0)
	terrain.ensure_water_field()
	var rejected_removed: bool = not pool.submit(body_id, center, 1.3, 6.0, 0.8, terrain)
	return _expect(accepted and rejected_body and rejected_dry and rejected_removed, "ripple pool should accept valid water impacts only")

func _expect(condition: bool, message: String) -> int:
	if condition:
		return 0
	printerr("FAIL: " + message)
	return 1
