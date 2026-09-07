class_name BenchmarkFixtures
extends RefCounted

## Deterministic benchmark scenes. Each scenario uses fixed seeds and snapshots.

const SCENARIO_IDS: Array[String] = [
	"starter_lake",
	"dense_forest",
	"resort_18",
	"active_golfers",
	"terrain_edit",
]

const CAMERAS: Dictionary = {
	"starter_lake": {"focus": Vector3(310, 0, 305), "size": 470.0, "yaw": 0.3, "elevation": 0.9},
	"dense_forest": {"focus": Vector3(420, 0, 360), "size": 620.0, "yaw": -0.4, "elevation": 0.75},
	"resort_18": {"focus": Vector3(512, 0, 512), "size": 1100.0, "yaw": 0.15, "elevation": 0.85},
	"active_golfers": {"focus": Vector3(310, 0, 305), "size": 470.0, "yaw": 0.3, "elevation": 0.9},
	"terrain_edit": {"focus": Vector3(245, 0, 307), "size": 280.0, "yaw": -0.9, "elevation": 0.6},
}


static func is_valid(scenario: String) -> bool:
	return scenario in SCENARIO_IDS


static func setup(game: Node, scenario: String, seed_value: int) -> Dictionary:
	if not is_valid(scenario):
		scenario = "starter_lake"
	match scenario:
		"starter_lake":
			return _setup_starter_lake(game, seed_value)
		"dense_forest":
			return _setup_dense_forest(game, seed_value)
		"resort_18":
			return _setup_resort_18(game, seed_value)
		"active_golfers":
			return _setup_active_golfers(game, seed_value)
		"terrain_edit":
			return _setup_terrain_edit(game, seed_value)
	return {}


static func per_frame(game: Node, scenario: String, frame_index: int) -> Dictionary:
	var metrics: Dictionary = {"sim_ms": 0.0, "terrain_rebuild_ms": 0.0, "scene_sync_ms": 0.0}
	if scenario != "terrain_edit":
		return metrics
	if game.get("terrain") == null or game.get("world") == null:
		return metrics
	var terrain: TerrainModel = game.terrain
	var world: TerrainView = game.world
	var brush_points: Array[Vector3] = [
		Vector3(180, 0, 250), Vector3(200, 0, 260), Vector3(220, 0, 255),
		Vector3(240, 0, 270), Vector3(260, 0, 265), Vector3(280, 0, 280),
	]
	var point: Vector3 = brush_points[frame_index % brush_points.size()]
	var started: int = Time.get_ticks_usec()
	var command: Dictionary = terrain.plan_brush("paint", point, 10.0, 1.0, 1)
	terrain.apply_brush(command)
	var rebuild_started: int = Time.get_ticks_usec()
	world.rebuild_dirty()
	world.sync_objects()
	metrics.terrain_rebuild_ms = float(Time.get_ticks_usec() - rebuild_started) / 1000.0
	metrics.scene_sync_ms = metrics.terrain_rebuild_ms
	metrics.sim_ms = float(rebuild_started - started) / 1000.0
	return metrics


static func _apply_camera(game: Node, scenario: String) -> void:
	var camera_data: Dictionary = CAMERAS.get(scenario, CAMERAS.starter_lake)
	game.camera.focus = camera_data.focus
	game.camera.size = float(camera_data.size)
	game.camera.yaw = float(camera_data.yaw)
	game.camera.elevation = float(camera_data.elevation)


static func _setup_starter_lake(game: Node, seed_value: int) -> Dictionary:
	game.new_game(false, "cedar_house", seed_value if seed_value >= 0 else 730241, true)
	game.speed = 0
	game.menu_open = false
	_apply_camera(game, "starter_lake")
	return {
		"scenario": "starter_lake",
		"mode": "fixed_state",
		"map_id": "cedar_house",
		"seed": seed_value if seed_value >= 0 else 730241,
		"sim_speed": 0,
		"guest_target": 0,
	}


static func _setup_dense_forest(game: Node, seed_value: int) -> Dictionary:
	var map_seed: int = seed_value if seed_value >= 0 else 771204
	game.new_game(false, "pinewood_valley", map_seed, true)
	game.speed = 0
	game.menu_open = false
	_plant_dense_scenery(game.terrain)
	game.world.sync_objects()
	game.world.apply_graphics_settings(game.graphics.current if game.get("graphics") != null else GraphicsSettings.defaults())
	_apply_camera(game, "dense_forest")
	return {
		"scenario": "dense_forest",
		"mode": "fixed_state",
		"map_id": "pinewood_valley",
		"seed": map_seed,
		"sim_speed": 0,
		"objects": game.terrain.objects.size(),
	}


static func _setup_resort_18(game: Node, seed_value: int) -> Dictionary:
	var map_seed: int = seed_value if seed_value >= 0 else 771204
	game._create_resort(true, "pinewood_valley", map_seed, true, true)
	game.save_name = "Benchmark 18"
	game.speed = 0
	game.menu_open = false
	game.camera.reset_view(game.terrain.entrance)
	_apply_camera(game, "resort_18")
	return {
		"scenario": "resort_18",
		"mode": "fixed_state",
		"map_id": "pinewood_valley",
		"seed": map_seed,
		"holes": game.terrain.holes.size(),
		"sim_speed": 0,
	}


static func _setup_active_golfers(game: Node, seed_value: int) -> Dictionary:
	var fixture_seed: int = seed_value if seed_value >= 0 else 90210
	_setup_starter_lake(game, 730241)
	game.sim._rng.seed = fixture_seed
	game.sim._rng.state = fixture_seed
	game.sim.open = true
	game.speed = 1
	for _i in range(5):
		game.sim.admit_group(4)
	game.sim.open = false
	game.sim._arrival_target = 0
	return {
		"scenario": "active_golfers",
		"mode": "deterministic_simulation",
		"map_id": "cedar_house",
		"seed": fixture_seed,
		"sim_speed": 1,
		"guest_target": 20,
	}


static func _setup_terrain_edit(game: Node, seed_value: int) -> Dictionary:
	_setup_starter_lake(game, seed_value if seed_value >= 0 else 730241)
	game.speed = 0
	game.set_tool("paint")
	game.paint_surface = 1
	game.brush_radius = 10.0
	_apply_camera(game, "terrain_edit")
	return {
		"scenario": "terrain_edit",
		"mode": "repeated_edit",
		"map_id": "cedar_house",
		"seed": seed_value if seed_value >= 0 else 730241,
		"sim_speed": 0,
	}


static func _plant_dense_scenery(terrain: TerrainModel) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 552019
	var kinds: Array[String] = ["pine_tree", "oak_tree", "flower_bed", "bench", "gazebo"]
	for attempt in range(4200):
		if terrain.objects.size() > 520:
			break
		var p: Vector3 = Vector3(rng.randf_range(48, 960), 0, rng.randf_range(48, 960))
		if terrain.surface_at(p) != 0:
			continue
		if p.distance_to(terrain.entrance) < 48.0:
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if Catalog.find(kind).is_empty():
			continue
		terrain.add_object(kind, p, rng.randf() * TAU)
	var building_kinds: Array[String] = ["clubhouse", "restaurant", "pro_shop", "cart_barn", "maintenance_shed", "spa", "lodge"]
	for kind in building_kinds:
		for attempt in range(40):
			var p: Vector3 = Vector3(rng.randf_range(140, 860), 0, rng.randf_range(140, 860))
			if terrain.surface_at(p) != 0:
				continue
			if p.distance_to(terrain.entrance) < 72.0:
				continue
			terrain.add_object(kind, p, rng.randf() * TAU)
			break
	terrain.touch()
