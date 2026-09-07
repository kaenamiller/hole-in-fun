extends SceneTree

const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const SettingsService = preload("res://scripts/graphics_settings_service.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	SaveStore.directory = "user://test_saves/graphics_%d" % OS.get_process_id()
	_test_defaults()
	_test_invalid_fallback()
	_test_persistence_round_trip()
	await _test_quality_does_not_touch_sim()
	await _test_low_survives_world_recreation()
	print("test_graphics: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _test_defaults() -> void:
	var settings: GraphicsSettings = SettingsClass.defaults()
	check(settings.preset == SettingsClass.Preset.STANDARD, "default preset is Standard")
	check(is_equal_approx(settings.shadow_distance, 1100.0), "default shadow distance matches current lighting")
	check(settings.shadow_resolution == 4096, "default shadow resolution matches project")
	check(settings.msaa_3d == 2, "default MSAA matches project 4x setting")
	check(is_equal_approx(settings.foliage_density, 1.0), "default foliage density is full")

func _test_invalid_fallback() -> void:
	var settings: GraphicsSettings = SettingsClass.defaults()
	settings.load_dict({
		"preset": "ultra",
		"foliage_density": 9.0,
		"shadow_resolution": 3333,
		"reflection_mode": "planar",
		"msaa_3d": 99,
	})
	check(settings.preset == SettingsClass.Preset.STANDARD, "unknown preset falls back to Standard")
	check(is_equal_approx(settings.foliage_density, 1.0), "out-of-range foliage density clamps")
	check(settings.shadow_resolution == 4096, "unknown shadow resolution snaps to nearest supported size")
	check(settings.reflection_mode == "sky", "unsupported reflection mode stays on sky")
	check(settings.msaa_3d == 3, "MSAA clamps to supported range")

func _test_persistence_round_trip() -> void:
	var service: GraphicsSettingsService = SettingsService.new()
	service.current.apply_preset(SettingsClass.Preset.LOW)
	var err: String = service.save()
	check(err.find("Could not") < 0, "graphics settings save succeeds")
	var reloaded: GraphicsSettingsService = SettingsService.new()
	check(reloaded.current.preset == SettingsClass.Preset.LOW, "graphics settings reload preset")
	check(is_equal_approx(reloaded.current.foliage_density, 0.55), "graphics settings reload low foliage density")
	service.current.apply_preset(SettingsClass.Preset.STANDARD)
	service.save()

func _test_quality_does_not_touch_sim() -> void:
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var hole: Dictionary = terrain.holes[0]
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var shot_a: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var rng_state_before: int = int(game.sim._rng.state)
	game.graphics.set_preset("low")
	game.graphics.apply_to_game(game, true)
	check(int(game.sim._rng.state) == rng_state_before, "graphics apply does not advance simulation RNG")
	game.graphics.set_preset("high")
	game.graphics.apply_to_game(game, true)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var shot_b: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	check(str(shot_a) == str(shot_b), "graphics quality does not change shot results")
	game.queue_free()
	await process_frame

func _test_low_survives_world_recreation() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.graphics.set_preset("low")
	game.graphics.apply_to_game(game, true)
	var rng_state: int = int(game.sim._rng.state)
	game._recreate_world()
	await process_frame
	check(game.graphics.current.preset == SettingsClass.Preset.LOW, "low preset survives world recreation")
	check(int(game.sim._rng.state) == rng_state, "world recreation keeps simulation RNG")
	game.queue_free()
	await process_frame
