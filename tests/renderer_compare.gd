extends SceneTree

const Runner = preload("res://scripts/benchmark_runner.gd")
const Fixtures = preload("res://scripts/benchmark_fixtures.gd")
const Comparison = preload("res://scripts/renderer_comparison.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	SaveStore.directory = "user://test_saves/renderer_compare_%d" % OS.get_process_id()
	var config: Dictionary = _parse_args(OS.get_cmdline_user_args())
	var method: String = Comparison.runtime_method()
	if not Comparison.is_valid_method(method):
		push_error("Unsupported runtime renderer: " + method)
		quit(1)
		return
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
		sample_rows.append(await _run_sample(game, config, sample_index))
	var shader_audit: Array = Comparison.audit_shaders()
	var visual_notes: Dictionary = _visual_notes(game, config)
	var report: Dictionary = Comparison.build_handoff(config, fixture, sample_rows, shader_audit, visual_notes)
	report.runtime = GraphicsSettingsService.runtime_info(game)
	report.graphics_settings = game.graphics.current.to_dict()
	report.hardware.renderer = method
	report.engine.compatibility = method == "gl_compatibility"
	report.engine.runtime_method = method
	report.engine.runtime_driver = Comparison.runtime_driver()
	report.capabilities = Comparison.capabilities_for(method)
	_write_outputs(report, str(config.output_path))
	game.queue_free()
	await process_frame
	quit()

func _parse_args(args: PackedStringArray) -> Dictionary:
	var config: Dictionary = Runner.parse_args(args)
	config["comparison_mode"] = "feature_matched"
	config["renderer_extras"] = false
	for arg in args:
		if arg.begins_with("--comparison-mode="):
			config.comparison_mode = str(arg.substr(18)).strip_edges().to_lower()
		elif arg == "--renderer-extras":
			config.renderer_extras = true
		elif arg.begins_with("--benchmark-renderer="):
			config.requested_renderer = str(arg.substr(20)).strip_edges().to_lower()
	return config

func _visual_notes(game: Node, config: Dictionary) -> Dictionary:
	var counters: Dictionary = Runner.capture_render_counters()
	return {
		"headless": DisplayServer.get_name() == "headless",
		"comparison_mode": config.comparison_mode,
		"renderer_extras": bool(config.renderer_extras),
		"draw_calls_peak": counters.draw_calls,
		"primitives_peak": counters.primitives,
		"materials": "custom spatial shaders only; no StandardMaterial3D terrain",
		"foliage_wind": "vertex sway in resort_foliage.gdshader",
		"water": "procedural waves; sky-only reflections until package 12",
		"overlays": "ground analysis/show_grid modes compile on all audited shaders",
		"photo_mode": "uses same viewport; not isolated in headless",
		"ui": "canvas_items stretch; not benchmarked headless",
		"color_space": "source_color uniforms on ground/water/foliage/path",
		"transparent_order": "water discard after turf; path/horizon opaque",
		"startup_ms": Time.get_ticks_msec(),
	}

func _run_sample(game: Node, config: Dictionary, sample_index: int) -> Dictionary:
	var warmup_ms: float = float(config.warmup_sec) * 1000.0
	var duration_ms: float = float(config.duration_sec) * 1000.0
	var started: int = Time.get_ticks_msec()
	var previous: int = started
	var frame_ms: Array[float] = []
	var peak_render: Dictionary = {"draw_calls": 0, "primitives": 0}
	while Time.get_ticks_msec() - started < warmup_ms + duration_ms:
		if str(config.scenario) == "terrain_edit":
			Fixtures.per_frame(game, str(config.scenario), sample_index)
		await process_frame
		var now: int = Time.get_ticks_msec()
		if now - started > warmup_ms:
			frame_ms.append(float(now - previous))
			var counters: Dictionary = Runner.capture_render_counters()
			peak_render.draw_calls = maxi(int(peak_render.draw_calls), int(counters.draw_calls))
			peak_render.primitives = maxi(int(peak_render.primitives), int(counters.primitives))
		previous = now
	var frame_summary: Dictionary = Runner.summarize_frames(frame_ms)
	var render: Dictionary = Runner.capture_render_counters()
	render.draw_calls = maxi(int(render.draw_calls), int(peak_render.draw_calls))
	render.primitives = maxi(int(render.primitives), int(peak_render.primitives))
	return {
		"sample": sample_index + 1,
		"warmup_sec": config.warmup_sec,
		"duration_sec": config.duration_sec,
		"frame": frame_summary,
		"render": render,
		"workload": {"sim_ms_total": 0.0, "terrain_rebuild_ms_total": 0.0, "scene_sync_ms_total": 0.0},
		"guests": game.sim.guests.size() if game.get("sim") != null else 0,
		"holes": game.terrain.holes.size() if game.get("terrain") != null else 0,
	}

func _write_outputs(report: Dictionary, output_path: String) -> void:
	if output_path.is_empty():
		print(_summary_line(report))
		return
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var json_path: String = output_path if output_path.ends_with(".json") else output_path + ".json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	var txt_path: String = json_path.get_basename() + ".txt"
	var txt := FileAccess.open(txt_path, FileAccess.WRITE)
	if txt != null:
		txt.store_string(_summary_line(report) + "\n")
		txt.close()
	print(_summary_line(report))

func _summary_line(report: Dictionary) -> String:
	var sample: Dictionary = (report.samples as Array).back() if not (report.samples as Array).is_empty() else {}
	var frame: Dictionary = sample.get("frame", {})
	return "RENDERER_COMPARE renderer=%s driver=%s scenario=%s avg_fps=%.1f p95_ms=%.1f p99_ms=%.1f draw_calls=%d gpu_timings=%s headless=%s" % [
		str(report.get("runtime_renderer", "")),
		str(report.get("runtime_driver", "")),
		str(report.get("scenario", "")),
		float(frame.get("avg_fps", 0.0)),
		float(frame.get("p95_ms", 0.0)),
		float(frame.get("p99_ms", 0.0)),
		int((sample.get("render", {}) as Dictionary).get("draw_calls", 0)),
		"unsupported" if not (report.get("capabilities", {}) as Dictionary).get("gpu_frame_time_ms", false) else "available",
		str((report.get("visual_notes", {}) as Dictionary).get("headless", true)),
	]
