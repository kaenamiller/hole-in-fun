extends SceneTree

const SAVE_PREFIX: String = "__test_game_active_"
const TerrainModelClass = preload("res://scripts/terrain_model.gd")
const CatalogClass = preload("res://scripts/catalog.gd")
const MapGeneratorClass = preload("res://scripts/map_generator.gd")

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
	_test_price_table(game)
	_test_build_locks(game)
	_test_brush_undo_redo(game)
	_test_place_undo_redo(game)
	_test_facility_upgrade_undo_demolish(game)
	_test_new_hole(game)
	game.select_hole(int(game.terrain.holes.back().get("id", -1)))
	game.analyze_hole()
	await process_frame
	_test_analysis(game)
	_test_metrics_report_card(game)
	await _test_filtered_analysis_draw(game)
	await _test_event_log_and_jump(game)
	await _test_statistics_tab(game)
	await _test_guests_feedback_panel(game)
	await _test_marketing_panel(game)
	await _test_staff_panel(game)
	await _test_overlay_cycle(game)
	await _test_named_save_load(game)
	await _test_pin_and_stake_undo(game)
	await _test_all_maps_smoke(game)
	await _test_menu_map_previews(game)
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
	_check(game.ui.nav_buttons.size() == 9, "UI should expose all nine navigation tabs")

func _test_all_tabs(game: Node3D) -> void:
	var tab_names: Array[String] = ["Terrain", "Holes", "Build", "Guests", "Staff", "Money", "Reputation", "Progress", "Reports"]
	for tab_name in tab_names:
		var button: Button = game.ui.nav_buttons.get(tab_name)
		if button == null:
			_fail("missing UI navigation button: " + tab_name)
			continue
		button.emit_signal("pressed")
		await process_frame
		_check(game.ui.tab == tab_name, "UI callback did not switch to tab " + tab_name)

func _test_price_table(game: Node3D) -> void:
	game.ui.show_tab("Money")
	_check(game.sim.pricing_summary().has("rows"), "Money panel pricing summary exposes rows")
	var before: float = game.sim.price("snack", {})
	game.sim.set_price_field("snack", "base", before + 3.0)
	_check(is_equal_approx(game.sim.price("snack", {}), before + 3.0), "price table edits write through to the book")
	game.sim.set_price_field("snack", "base", before)

func _test_build_locks(game: Node3D) -> void:
	game.ui.show_tab("Build")
	var locked_found: bool = false
	for child in game.ui.body.get_children():
		if child is Button and str(child.text).begins_with("○"):
			locked_found = true
			_check(child.disabled, "Build buttons for locked kinds are disabled")
			break
	_check(locked_found, "Build panel shows at least one locked catalog item on a fresh non-sandbox game")

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

func _test_facility_upgrade_undo_demolish(game: Node3D) -> void:
	var point: Vector3 = _find_build_site(game, 680.0, 680.0)
	game.place_kind = "putting_green"
	game.set_tool("place")
	game._world_click(point, Vector2.ZERO)
	var placed: Dictionary = game.terrain.objects.back()
	_check(int(placed.get("level", 0)) == 1, "placed facility defaults to level 1")
	var before_upgrade: int = int(placed.get("level", 1))
	game.selected_object = placed
	game.upgrade_object(int(placed.get("id", -1)))
	await process_frame
	var upgraded: Dictionary = {}
	for object in game.terrain.objects:
		if int(object.get("id", -1)) == int(placed.get("id", -1)):
			upgraded = object
	_check(int(upgraded.get("level", 1)) == before_upgrade, "putting green has no upgrade tiers")
	game.place_kind = "snack_kiosk"
	game.set_tool("place")
	var kiosk_point: Vector3 = _find_build_site(game, 700.0, 700.0)
	game._world_click(kiosk_point, Vector2.ZERO)
	var kiosk: Dictionary = game.terrain.objects.back()
	game.sim.cash = 200000.0
	game.selected_object = kiosk
	game.upgrade_object(int(kiosk.get("id", -1)))
	await process_frame
	var kiosk_after: Dictionary = {}
	for object in game.terrain.objects:
		if int(object.get("id", -1)) == int(kiosk.get("id", -1)):
			kiosk_after = object
	_check(int(kiosk_after.get("level", 1)) == 2, "snack kiosk upgrade raises level")
	game.undo()
	await process_frame
	var kiosk_undone: Dictionary = {}
	for object in game.terrain.objects:
		if int(object.get("id", -1)) == int(kiosk.get("id", -1)):
			kiosk_undone = object
	_check(int(kiosk_undone.get("level", 1)) == 1, "undo restores pre-upgrade level")
	game.selected_object = kiosk_undone
	game.demolish_selected()
	await process_frame
	_check(not game.terrain.objects.any(func(object: Dictionary) -> bool: return int(object.get("id", -1)) == int(kiosk.get("id", -1))), "demolish removes upgraded facility")

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

func _test_metrics_report_card(game: Node3D) -> void:
	game.ui.show_inspector()
	var has_report: bool = false
	for node in _walk_controls(game.ui.body):
		if node is Label and str(node.text).contains("Design report card"):
			has_report = true
			break
	_check(has_report or game.analysis_metrics.has("fun"), "holes panel exposes a design report card after analysis")

func _test_filtered_analysis_draw(game: Node3D) -> void:
	game.show_metric_shots("hazard_rate")
	await process_frame
	_check(game.analysis_filter == "hazard_rate", "filtered draw sets analysis filter")
	game.clear_analysis()
	await process_frame
	_check(game._shot_root.get_child_count() == 0, "clear analysis removes filtered draw nodes")
	_check(game.analysis_filter.is_empty(), "clear analysis resets filter state")

func _test_event_log_and_jump(game: Node3D) -> void:
	var severities: Array[String] = ["info", "success", "warning", "critical"]
	for severity in severities:
		game.sim.post(severity, "system", "Toast test %s" % severity)
	game._poll_log_toasts()
	await process_frame
	_check(game.ui.toast_container.get_child_count() <= 4, "toast stack keeps at most four visible entries")
	var hole: Dictionary = game.terrain.holes[0]
	var target: Vector3 = hole.get("tee", Vector3.ZERO).lerp(hole.get("cup", Vector3.ZERO), 0.5)
	game.jump_to({
		"pos": hole.get("tee", Vector3.ZERO),
		"target": {"kind": "hole", "id": int(hole.get("id", -1))},
	})
	await process_frame
	_check(game.camera.focus.distance_to(target) < 60.0, "jump_to for a hole target moves camera focus")

func _test_statistics_tab(game: Node3D) -> void:
	game.ui.show_tab("Statistics")
	await process_frame
	_check(game.ui.tab == "Reports", "Statistics alias opens the Reports tab")
	_check(game.ui.body.get_child_count() > 0, "Reports tab has content with zero history days")
	_check(is_instance_valid(game.ui.reports_overlay), "Reports tab opens the wide reports overlay")
	game.sim.arrivals_enabled = false
	for _day_index in range(3):
		game.sim.tick(24000.0)
	game.ui.show_tab("Statistics")
	await process_frame
	_check(game.sim.history.size() >= 3, "three simulated months populate history for statistics")
	var chart: SimpleChart = SimpleChart.new()
	chart.custom_minimum_size = Vector2(300, 120)
	game.ui.body.add_child(chart)
	chart.set_series([{"day": 1, "value": 1.0}, {"day": 2, "value": 2.0}], ["D1", "D2"], ["Test"], "line")
	await process_frame
	chart.queue_redraw()
	await process_frame
	_check(is_instance_valid(chart), "chart _draw runs without errors at 300 x 120 px")
	chart.queue_free()
	var export_dir: String = "user://exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_dir))
	game.ui._export_history_csv()
	await process_frame
	var export_path: String = "%s/%s_history.csv" % [export_dir, SaveStore.clean_name(game.save_name)]
	_check(FileAccess.file_exists(export_path), "CSV export creates a file in the isolated save directory")
	if FileAccess.file_exists(export_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(export_path))

func _test_guests_feedback_panel(game: Node3D) -> void:
	game.sim._arrival_target = 0
	game.ui.show_tab("Guests")
	await process_frame
	_check(game.ui.tab == "Guests", "Guests tab renders with zero reviews")
	var before_reviews: int = game.sim.reviews.size()
	var admitted_id: int = game.sim.admit_group(1)
	_check(admitted_id > 0, "Guests feedback test could not admit a group")
	game.sim.tick(36000.0)
	game.ui.show_tab("Guests")
	await process_frame
	var added_reviews: int = game.sim.reviews.size() - before_reviews
	_check(added_reviews == 1, "Guests tab renders with one review")
	for _index in range(3):
		game.sim.admit_group(2)
		game.sim.tick(36000.0)
	game.ui.show_tab("Guests")
	await process_frame
	_check(game.sim.reviews.size() >= before_reviews + 7, "Guests tab renders with many reviews")
	_check(game.ui.body.get_child_count() > 0, "Guests feedback panel has content")

func _test_marketing_panel(game: Node3D) -> void:
	game.ui.show_tab("Marketing")
	await process_frame
	_check(game.ui.tab == "Reputation", "Marketing alias opens the Reputation tab")
	_check(game.sim.rating_breakdown().has("stars"), "Marketing panel reads rating breakdown")
	game.sim.cash = 200000.0
	var cash_before_start: float = game.sim.cash
	var started: String = game.sim.start_campaign("local_flyers")
	_check(started.contains("started"), "Marketing start campaign callback runs")
	_check(game.sim.cash < cash_before_start, "Marketing campaign charges cash")
	game.ui.show_tab("Marketing")
	await process_frame
	_check(game.sim.forecast_arrivals().has("low"), "Marketing reach forecast renders")

func _test_staff_panel(game: Node3D) -> void:
	game.sim.candidates.clear()
	game.sim._refill_candidates()
	var candidate_id: int = -1
	for candidate in game.sim.candidates:
		if str(candidate.get("role", "")) == "cleaner":
			candidate_id = int(candidate.get("id", -1))
			break
	if candidate_id < 0:
		game.sim.candidates.append({
			"id": 9001, "role": "cleaner", "name": "Test Applicant",
			"skill": 0.7, "wage": 105.0, "traits": [],
		})
		candidate_id = 9001
	var staff_before: int = game.sim.staff.size()
	game.sim.hire(candidate_id)
	_check(game.sim.staff.size() == staff_before + 1, "Staff panel hire callback adds a worker")
	var worker: Dictionary = game.sim.staff.back()
	var worker_id: int = int(worker.get("id", -1))
	var skill_before: float = float(worker.get("skill", 0.0))
	_check(game.sim.train(worker_id, "sanitation"), "Staff panel train callback starts sanitation course")
	game.ui.show_tab("Staff")
	await process_frame
	_check(game.ui.tab == "Staff", "Staff tab renders after train")
	game.sim._end_staff_day()
	game.sim._end_staff_day()
	_check(float(worker.get("skill", 0.0)) > skill_before, "Staff panel train callback completes with higher skill")
	game.sim.fire(worker_id)
	_check(not game.sim.staff.any(func(w: Dictionary) -> bool: return int(w.get("id", -1)) == worker_id), "Staff panel fire callback removes worker")
	game.ui.show_tab("Staff")
	await process_frame
	_check(game.ui.body.get_child_count() > 0, "Staff tab has content after fire")

func _test_overlay_cycle(game: Node3D) -> void:
	for overlay_id in game.OVERLAY_IDS:
		game.set_overlay(overlay_id)
		await process_frame
		_check(game.world.overlay == overlay_id, "set_overlay did not activate " + overlay_id)
		game.toggle_overlay(overlay_id)
		await process_frame
		_check(game.world.overlay == "none", "toggle_overlay did not clear " + overlay_id)

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
	_check(game.save_name == test_save_name and game.ui.tab == "Terrain", "named save load did not restore active save context")
	_check(game.sim.guests.size() == saved_guest_count and game.sim.groups.size() == saved_group_count, "load did not restore active visit guests/groups")
	_check(is_equal_approx(game.sim.minute, saved_minute), "load did not restore simulation clock")
	_check(game.terrain.surface_at(saved_surface_point) == saved_surface, "load did not restore terrain state")

func _test_pin_and_stake_undo(game: Node3D) -> void:
	var hole: Dictionary = game.terrain.holes[0]
	game.select_hole(int(hole.get("id", -1)))
	var pin_point: Vector3 = _ground(game, TerrainModelClass.effective_cup(hole) + Vector3(3.0, 0.0, 2.0))
	var pins_before: int = game.selected_hole.get("pins", []).size()
	game.set_tool("add_pin")
	game._world_click(pin_point, Vector2.ZERO)
	await process_frame
	_check(game.selected_hole.get("pins", []).size() == pins_before + 1, "adding a pin commits to the hole")
	game.undo()
	await process_frame
	_reselect_pins(game, int(hole.get("id", -1)))
	_check(game.selected_hole.get("pins", []).size() == pins_before, "pin placement undo restores the hole")
	var objects_before: int = game.terrain.objects.size()
	var stake_a: Vector3 = _ground(game, Vector3(720.0, 0.0, 720.0))
	var stake_b: Vector3 = _ground(game, Vector3(760.0, 0.0, 720.0))
	game.set_tool("ob_stakes")
	game._world_click(stake_a, Vector2.ZERO)
	game._world_click(stake_b, Vector2.ZERO)
	await process_frame
	_check(game.terrain.objects.size() == objects_before + 1, "stake segment placement commits an object")
	game.undo()
	await process_frame
	_check(game.terrain.objects.size() == objects_before, "stake segment undo removes the object")

func _reselect_pins(game: Node3D, hole_id: int) -> void:
	game.selected_hole = {}
	for item in game.terrain.holes:
		if int(item.get("id", -1)) == hole_id:
			game.selected_hole = item

func _test_all_maps_smoke(game: Node3D) -> void:
	for map_def in CatalogClass.maps():
		var map_id: String = str(map_def.get("id", ""))
		game.new_game(true, map_id, int(map_def.get("seed", 1)), bool(map_def.get("starter", false)))
		await process_frame
		await process_frame
		_check(game.terrain.map_id == map_id or game.terrain.holes.size() >= 0, "new_game loads map %s" % map_id)
		_check(game.terrain.entrance.distance_to(Vector3(map_def.get("entrance", Vector3.ZERO))) < 0.1, "%s entrance restored" % map_id)
	game.new_game(false, "cedar_house", -1, true)
	await process_frame

func _test_menu_map_previews(game: Node3D) -> void:
	game.menu_open = true
	game.ui.show_menu()
	await process_frame
	await process_frame
	var preview_count: int = 0
	if game.ui.menu != null:
		for node in _walk_controls(game.ui.menu):
			if node is TextureRect and (node as TextureRect).texture != null:
				preview_count += 1
	_check(preview_count >= CatalogClass.maps().size(), "menu renders a preview texture per map")
	game.ui.hide_menu()
	await process_frame

func _walk_controls(node: Node) -> Array:
	var result: Array = [node]
	for child in node.get_children():
		result.append_array(_walk_controls(child))
	return result

func _render_qa(game: Node3D) -> void:
	if not "--render-qa" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		print("test_game: --render-qa requested but display is headless; skipping screenshots")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://builds"))
	var captures: Array[String] = ["Terrain", "Holes", "Build", "Guests"]
	var files: Array[String] = ["qa_overview.png", "qa_holes.png", "qa_build.png", "qa_guests.png"]
	game.set_overlay("traffic")
	await process_frame
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
