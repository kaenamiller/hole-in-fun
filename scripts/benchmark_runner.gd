class_name BenchmarkRunner
extends RefCounted

const CAPABILITIES: Dictionary = {
	"gpu_frame_time_ms": false,
	"gpu_draw_time_ms": false,
	"render_info": true,
	"render_info_headless": false,
	"memory_static": true,
	"memory_dynamic": false,
	"object_count": true,
}


static func parse_args(args: PackedStringArray) -> Dictionary:
	var config: Dictionary = {
		"scenario": "starter_lake",
		"duration_sec": 25.0,
		"warmup_sec": 5.0,
		"samples": 1,
		"seed": -1,
		"preset": "standard",
		"output_path": "",
		"legacy": false,
	}
	for arg in args:
		if arg == "--benchmark":
			config.legacy = true
			continue
		if arg.begins_with("--benchmark-"):
			var pair: PackedStringArray = arg.substr(12).split("=", false, 1)
			if pair.size() < 2:
				continue
			match pair[0]:
				"scenario":
					config.scenario = pair[1]
				"duration":
					config.duration_sec = maxf(1.0, float(pair[1]))
				"warmup":
					config.warmup_sec = maxf(0.0, float(pair[1]))
				"samples":
					config.samples = maxi(1, int(pair[1]))
				"seed":
					config.seed = int(pair[1])
				"preset":
					config.preset = pair[1].to_lower()
				"output":
					config.output_path = pair[1]
	return config


static func percentile(sorted_values: Array, ratio: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index: int = clampi(int(round(float(sorted_values.size() - 1) * ratio)), 0, sorted_values.size() - 1)
	return float(sorted_values[index])


static func summarize_frames(frame_ms: Array[float]) -> Dictionary:
	var sorted: Array[float] = frame_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	var worst: float = 0.0
	for value in sorted:
		total += value
		worst = maxf(worst, value)
	var avg_ms: float = total / maxf(float(sorted.size()), 1.0)
	return {
		"frames": sorted.size(),
		"avg_fps": 1000.0 / maxf(avg_ms, 0.001),
		"avg_ms": avg_ms,
		"p50_ms": percentile(sorted, 0.50),
		"p95_ms": percentile(sorted, 0.95),
		"p99_ms": percentile(sorted, 0.99),
		"worst_ms": worst,
		"outliers_over_33ms": _count_over(sorted, 33.0),
		"outliers_over_50ms": _count_over(sorted, 50.0),
	}


static func _count_over(sorted_values: Array, threshold: float) -> int:
	var count: int = 0
	for value in sorted_values:
		if float(value) > threshold:
			count += 1
	return count


static func capture_render_counters() -> Dictionary:
	return {
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"primitives": int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"memory_static_kb": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
		"memory_dynamic_kb": -1,
	}


static func build_report(game: Node, config: Dictionary, fixture: Dictionary, sample_rows: Array) -> Dictionary:
	var settings: GraphicsSettings = game.graphics.current if game.get("graphics") != null else GraphicsSettings.defaults()
	return {
		"benchmark_version": 1,
		"captured_at": Time.get_datetime_string_from_system(true),
		"scenario": config.scenario,
		"fixture": fixture,
		"config": config,
		"capabilities": CAPABILITIES,
		"hardware": GraphicsSettingsService.hardware_info(),
		"engine": GraphicsSettingsService.engine_info(),
		"runtime": GraphicsSettingsService.runtime_info(game),
		"graphics_settings": settings.to_dict(),
		"samples": sample_rows,
	}


static func format_summary(report: Dictionary) -> String:
	var sample: Dictionary = (report.samples as Array).back() if not (report.samples as Array).is_empty() else {}
	var frame: Dictionary = sample.get("frame", {})
	var render: Dictionary = sample.get("render", {})
	return "BENCHMARK scenario=%s preset=%s avg_fps=%.1f p50_ms=%.1f p95_ms=%.1f p99_ms=%.1f frames=%d guests=%d draw_calls=%d primitives=%d gpu_timings=%s" % [
		str(report.get("scenario", "")),
		str((report.get("graphics_settings", {}) as Dictionary).get("preset", "")),
		float(frame.get("avg_fps", 0.0)),
		float(frame.get("p50_ms", 0.0)),
		float(frame.get("p95_ms", 0.0)),
		float(frame.get("p99_ms", 0.0)),
		int(frame.get("frames", 0)),
		int(sample.get("guests", 0)),
		int(render.get("draw_calls", 0)),
		int(render.get("primitives", 0)),
		"unsupported" if not CAPABILITIES.gpu_frame_time_ms else "available",
	]


static func write_outputs(report: Dictionary, output_path: String) -> void:
	if output_path.is_empty():
		print(format_summary(report))
		return
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var json_path: String = output_path if output_path.ends_with(".json") else output_path + ".json"
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	var csv_path: String = json_path.get_basename() + ".csv"
	_write_csv(csv_path, report)
	var summary_path: String = json_path.get_basename() + ".txt"
	var summary_file := FileAccess.open(summary_path, FileAccess.WRITE)
	if summary_file != null:
		summary_file.store_string(format_summary(report) + "\n")
		summary_file.close()
	print(format_summary(report))


static func _write_csv(path: String, report: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray([
		"sample,avg_fps,p50_ms,p95_ms,p99_ms,worst_ms,frames,draw_calls,primitives,sim_ms_total,terrain_rebuild_ms_total,scene_sync_ms_total,guests",
	])
	for index in range((report.samples as Array).size()):
		var sample: Dictionary = report.samples[index]
		var frame: Dictionary = sample.get("frame", {})
		var render: Dictionary = sample.get("render", {})
		var workload: Dictionary = sample.get("workload", {})
		lines.append("%d,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%.2f,%.2f,%.2f,%d" % [
			index + 1,
			float(frame.get("avg_fps", 0.0)),
			float(frame.get("p50_ms", 0.0)),
			float(frame.get("p95_ms", 0.0)),
			float(frame.get("p99_ms", 0.0)),
			float(frame.get("worst_ms", 0.0)),
			int(frame.get("frames", 0)),
			int(render.get("draw_calls", 0)),
			int(render.get("primitives", 0)),
			float(workload.get("sim_ms_total", 0.0)),
			float(workload.get("terrain_rebuild_ms_total", 0.0)),
			float(workload.get("scene_sync_ms_total", 0.0)),
			int(sample.get("guests", 0)),
		])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
