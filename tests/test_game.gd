extends SceneTree

const SAVE_PREFIX: String = "__test_game_active_"

var failures: Array[String] = []
var test_save_name: String = ""
var had_before_loading_save: bool = false

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	SaveStore.directory="user://test_saves/game_%d"%OS.get_process_id()
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("main scene could not be loaded")
		_finish()
		return
	var game: Node3D = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	if not is_instance_valid(game) or game.get("terrain") == null or game.get("sim") == null or game.get("ui") == null:
		_fail("main scene did not initialize terrain, simulation, and UI")
		_finish()
		return

	game.set_speed(0)
	game.ui.hide_menu()
	game.menu_open = false
	await process_frame
	await process_frame
	_test_initial_state(game)
	await _test_all_tabs(game)
	_test_brush_undo_redo(game)
	_test_place_undo_redo(game)
	_test_new_hole(game)
	game.select_hole(int(game.terrain.holes.back().get("id", -1)))
	game.analyze_hole()
	await process_frame
	_test_analysis(game)
	await _test_named_save_load(game)
	await _render_qa(game)
	_cleanup_test_saves()
	game.queue_free()
	await process_frame
	_finish()

func _test_initial_state(game: Node3D) -> void:
	_check(game.speed == 0, "simulation speed was not paused")
	_check(not game.menu_open and game.ui.menu == null, "menu was not hidden for integration checks")
	_check(game.terrain.holes.size() == 3, "starter game should contain three holes")
	_check(game.world.chunks.size() == 256, "terrain view should contain all 256 chunks")
	_check(game.ui.nav_buttons.size() == 8, "UI should expose all eight navigation tabs")

func _test_all_tabs(game: Node3D) -> void:
	var tab_names: Array[String] = ["Terrain", "Holes", "Build", "Guests", "Staff", "Money", "Events", "Saves"]
	for tab_name in tab_names:
		var button: Button = game.ui.nav_buttons.get(tab_name)
		if button == null:
			_fail("missing UI navigation button: " + tab_name)
			continue
		button.emit_signal("pressed")
		await process_frame
		_check(game.ui.tab == tab_name, "UI callback did not switch to tab " + tab_name)

func _test_brush_undo_redo(game: Node3D) -> void:
	var point: Vector3 = _ground(game, Vector3(780.0, 0.0, 760.0))
	var old_height: float = game.terrain.height_at(point)
	game.brush_strength = 0.8
	game.set_tool("raise")
	game._world_click(point, Vector2.ZERO)
	var raised_height: float = game.terrain.height_at(point)
	_check(raised_height > old_height, "raise brush callback did not change terrain")
	game.undo()
	_check(is_equal_approx(game.terrain.height_at(point), old_height), "brush undo did not restore terrain")
	game.redo()
	_check(is_equal_approx(game.terrain.height_at(point), raised_height), "brush redo did not reapply terrain")

func _test_place_undo_redo(game: Node3D) -> void:
	var point: Vector3 = _find_build_site(game, 720.0, 720.0)
	var before_count: int = game.terrain.objects.size()
	game.place_kind = "oak_tree"
	game.set_tool("place")
	game._world_click(point, Vector2.ZERO)
	var after_count: int = game.terrain.objects.size()
	_check(after_count == before_count + 1, "place callback did not add an object")
	game.undo()
	_check(game.terrain.objects.size() == before_count, "place undo did not remove object")
	game.redo()
	_check(game.terrain.objects.size() == after_count, "place redo did not restore object")

func _test_new_hole(game: Node3D) -> void:
	var before_count: int = game.terrain.holes.size()
	var tee: Vector3 = _ground(game, Vector3(760.0, 0.0, 500.0))
	var cup: Vector3 = _ground(game, Vector3(900.0, 0.0, 500.0))
	game.set_tool("hole_tee")
	game._world_click(tee, Vector2.ZERO)
	game._world_click(cup, Vector2.ZERO)
	_check(game.terrain.holes.size() == before_count + 1, "new hole tee/cup callbacks did not create a hole")
	var created: Dictionary = game.terrain.holes.back()
	_check(game.terrain.surface_at(created.get("tee", tee)) == 3, "new hole did not paint tee surface")
	_check(game.terrain.surface_at(created.get("cup", cup)) == 2, "new hole did not paint green surface")
	_check(game.terrain.hole_valid(created).is_empty(), "new hole should be valid after automatic tee/green painting")

func _test_analysis(game: Node3D) -> void:
	_check(game.analysis_results.size() == 3, "shot analysis should return beginner/intermediate/expert profiles")
	_check(game.ui.tab == "Holes", "shot analysis should return to the Holes tab")
	var averages: Array[float] = []
	for result_value in game.analysis_results:
		var result: Dictionary = result_value
		_check(result.has("label") and result.has("average") and result.has("hazard_rate") and result.has("shots"), "analysis result is missing overlay metrics")
		averages.append(float(result.get("average", 0.0)))
	_check(averages.size() == 3 and averages[0] >= averages[1] and averages[1] >= averages[2], "shot analysis skill ordering is implausible")

func _test_named_save_load(game: Node3D) -> void:
	var stamp: int = Time.get_ticks_msec()
	test_save_name = SAVE_PREFIX + str(stamp)
	had_before_loading_save = SaveStore.list_saves().has("Before loading")
	var admitted_id: int = game.sim.admit_group(2)
	_check(admitted_id > 0 and game.sim.guests.size() == 2, "active visit could not be admitted before save")
	game.sim.minute = 137.0
	var saved_guest_count: int = game.sim.guests.size()
	var saved_group_count: int = game.sim.groups.size()
	var saved_minute: float = game.sim.minute
	var saved_surface_point: Vector3 = _ground(game, Vector3(950.0, 0.0, 780.0))
	var saved_surface: int = game.terrain.surface_at(saved_surface_point)
	game.save_name = test_save_name
	game.save_current()
	_check(SaveStore.list_saves().has(test_save_name), "named save was not created")
	game.terrain.paint_disk(saved_surface_point, 18.0, 5)
	game.sim.minute = 22.0
	game.sim.guests.clear()
	game.load_saved(test_save_name)
	await process_frame
	_check(game.save_name == test_save_name and game.ui.tab == "Saves", "named save load did not restore active save context")
	_check(game.sim.guests.size() == saved_guest_count and game.sim.groups.size() == saved_group_count, "load did not restore active visit guests/groups")
	_check(is_equal_approx(game.sim.minute, saved_minute), "load did not restore simulation clock")
	_check(game.terrain.surface_at(saved_surface_point) == saved_surface, "load did not restore terrain state")

func _render_qa(game: Node3D) -> void:
	if not "--render-qa" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		print("test_game: --render-qa requested but display is headless; skipping screenshots")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
	var captures: Array[String] = ["Terrain", "Holes", "Build", "Guests"]
	var files: Array[String] = ["qa_overview.png", "qa_holes.png", "qa_build.png", "qa_guests.png"]
	for index in range(captures.size()):
		game.ui.show_tab(captures[index])
		await process_frame
		await process_frame
		var image: Image = get_root().get_texture().get_image()
		image.save_png("res://builds/" + files[index])
		_check(FileAccess.file_exists("res://builds/" + files[index]), "QA screenshot was not written: " + files[index])

func _ground(game: Node3D, point: Vector3) -> Vector3:
	return Vector3(point.x, game.terrain.height_at(point), point.z)

func _find_build_site(game: Node3D, start_x: float, start_z: float) -> Vector3:
	for row in range(18):
		for column in range(18):
			var point: Vector3 = _ground(game, Vector3(start_x + float(column) * 12.0, 0.0, start_z + float(row) * 12.0))
			if not game.terrain.playable(point) or game.terrain.slope_at(point).length() > 0.35:
				continue
			var reason: String = game._placement_reason("oak_tree", point)
			if reason.is_empty():
				return point
	return _ground(game, Vector3(start_x, 0.0, start_z))

func _cleanup_test_saves() -> void:
	if not test_save_name.is_empty():
		_remove_save(test_save_name)
	if not had_before_loading_save:
		_remove_save("Before loading")

func _remove_save(name_value: String) -> void:
	var path: String = SaveStore.directory.path_join(SaveStore.clean_name(name_value) + ".hif")
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	printerr("FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("test_game: all integration tests passed")
	else:
		printerr("test_game: %d integration test(s) failed" % failures.size())
	quit(failures.size())
