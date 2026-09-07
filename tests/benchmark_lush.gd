extends SceneTree

const Runner = preload("res://scripts/benchmark_runner.gd")
const Fixtures = preload("res://scripts/benchmark_fixtures.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	SaveStore.directory = "user://test_saves/lush_benchmark_%d" % OS.get_process_id()
	var config: Dictionary = Runner.parse_args(OS.get_cmdline_user_args())
	if config.legacy and config.output_path.is_empty() and config.scenario == "starter_lake":
		config.scenario = "active_golfers"
		config.duration_sec = 25.0
		config.warmup_sec = 5.0
		config.samples = 1
		config.preset = "standard"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.ui.hide_menu()
	game.menu_open = false
	game.graphics.set_preset(str(config.preset))
	game.graphics.apply_to_game(game, false)
	if not Fixtures.is_valid(str(config.scenario)):
		push_error("Unknown benchmark scenario: " + str(config.scenario))
		quit(1)
		return
	var fixture: Dictionary = Fixtures.setup(game, str(config.scenario), int(config.seed))
	game.graphics.apply_to_game(game, true)
	await process_frame
	await process_frame
	var sample_rows: Array = []
	for sample_index in range(int(config.samples)):
		var sample: Dictionary = await _run_sample(game, config, sample_index)
		sample_rows.append(sample)
	var report: Dictionary = Runner.build_report(game, config, fixture, sample_rows)
	Runner.write_outputs(report, str(config.output_path))
	game.queue_free()
	await process_frame
	quit()

func _run_sample(game: Node, config: Dictionary, sample_index: int) -> Dictionary:
	var warmup_ms: float = float(config.warmup_sec) * 1000.0
	var duration_ms: float = float(config.duration_sec) * 1000.0
	var started: int = Time.get_ticks_msec()
	var previous: int = started
	var frame_ms: Array[float] = []
	var sim_ms_total: float = 0.0
	var terrain_rebuild_ms_total: float = 0.0
	var scene_sync_ms_total: float = 0.0
	var frame_index: int = 0
	var peak_render: Dictionary = {"draw_calls": 0, "primitives": 0}
	while Time.get_ticks_msec() - started < warmup_ms + duration_ms:
		if str(config.scenario) == "terrain_edit":
			var edit_metrics: Dictionary = Fixtures.per_frame(game, str(config.scenario), frame_index)
			terrain_rebuild_ms_total += float(edit_metrics.get("terrain_rebuild_ms", 0.0))
			scene_sync_ms_total += float(edit_metrics.get("scene_sync_ms", 0.0))
			sim_ms_total += float(edit_metrics.get("sim_ms", 0.0))
		elif int(game.speed) > 0:
			pass
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now - started > warmup_ms:
			frame_ms.append(float(now - previous))
			var counters: Dictionary = Runner.capture_render_counters()
			peak_render.draw_calls = maxi(int(peak_render.draw_calls), int(counters.draw_calls))
			peak_render.primitives = maxi(int(peak_render.primitives), int(counters.primitives))
		previous = now
		frame_index += 1
	var frame_summary: Dictionary = Runner.summarize_frames(frame_ms)
	var render: Dictionary = Runner.capture_render_counters()
	render.draw_calls = maxi(int(render.draw_calls), int(peak_render.draw_calls))
	render.primitives = maxi(int(render.primitives), int(peak_render.primitives))
	var profile: Dictionary = game.consume_profile_metrics() if game.has_method("consume_profile_metrics") else {}
	if str(config.scenario) == "terrain_edit":
		profile = {"sim_ms": sim_ms_total, "scene_sync_ms": scene_sync_ms_total, "terrain_rebuild_ms": terrain_rebuild_ms_total}
	else:
		sim_ms_total = float(profile.get("sim_ms", sim_ms_total))
		scene_sync_ms_total = float(profile.get("scene_sync_ms", scene_sync_ms_total))
	return {
		"sample": sample_index + 1,
		"warmup_sec": config.warmup_sec,
		"duration_sec": config.duration_sec,
		"frame": frame_summary,
		"render": render,
		"workload": {
			"sim_ms_total": sim_ms_total,
			"terrain_rebuild_ms_total": terrain_rebuild_ms_total,
			"scene_sync_ms_total": scene_sync_ms_total,
		},
		"guests": game.sim.guests.size() if game.get("sim") != null else 0,
		"holes": game.terrain.holes.size() if game.get("terrain") != null else 0,
	}
