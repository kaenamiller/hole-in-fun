class_name RendererComparison
extends RefCounted

## Renderer trial helpers for package 02. Does not change production defaults.

const METHODS: Array[String] = ["gl_compatibility", "mobile", "forward_plus"]
const METHOD_LABELS: Dictionary = {
	"gl_compatibility": "Compatibility",
	"mobile": "Mobile",
	"forward_plus": "Forward+",
}

const SHADER_PATHS: Array[String] = [
	"res://shaders/resort_ground.gdshader",
	"res://shaders/resort_water.gdshader",
	"res://shaders/resort_foliage.gdshader",
	"res://shaders/resort_path.gdshader",
	"res://shaders/resort_horizon.gdshader",
]

const FEATURE_MATRIX: Dictionary = {
	"gl_compatibility": {
		"reflection_probes": true,
		"ssao": true,
		"basic_fog": true,
		"ssr": false,
		"volumetric_fog": false,
		"decals": false,
		"gpu_profile": false,
	},
	"mobile": {
		"reflection_probes": true,
		"ssao": true,
		"basic_fog": true,
		"ssr": true,
		"volumetric_fog": true,
		"decals": true,
		"gpu_profile": true,
	},
	"forward_plus": {
		"reflection_probes": true,
		"ssao": true,
		"basic_fog": true,
		"ssr": true,
		"volumetric_fog": true,
		"decals": true,
		"gpu_profile": true,
	},
}


static func requested_method() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-renderer="):
			return str(arg.substr(20)).strip_edges().to_lower()
		if arg.begins_with("--renderer="):
			return str(arg.substr(11)).strip_edges().to_lower()
	return ""


static func project_method() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))


static func runtime_method() -> String:
	var method: String = RenderingServer.get_current_rendering_method()
	if method.is_empty():
		method = requested_method()
	if method.is_empty():
		method = project_method()
	return method


static func runtime_driver() -> String:
	return RenderingServer.get_current_rendering_driver_name()


static func method_label(method: String) -> String:
	return str(METHOD_LABELS.get(method, method))


static func is_valid_method(method: String) -> bool:
	return method in METHODS


static func capabilities_for(method: String) -> Dictionary:
	var base: Dictionary = BenchmarkRunner.CAPABILITIES.duplicate(true)
	var matrix: Dictionary = FEATURE_MATRIX.get(method, FEATURE_MATRIX.gl_compatibility)
	base["gpu_frame_time_ms"] = method != "gl_compatibility" and not DisplayServer.get_name() == "headless"
	base["gpu_draw_time_ms"] = base.gpu_frame_time_ms
	base["render_info_headless"] = method != "gl_compatibility"
	base["memory_dynamic"] = method != "gl_compatibility"
	base["renderer_features"] = matrix
	return base


static func audit_shaders() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for path in SHADER_PATHS:
		var row: Dictionary = {
			"path": path,
			"exists": ResourceLoader.exists(path),
			"compiles": false,
			"shader_type": "",
			"render_modes": PackedStringArray(),
			"issues": PackedStringArray(),
		}
		if not row.exists:
			row.issues.append("missing file")
			rows.append(row)
			continue
		var shader: Shader = load(path) as Shader
		if shader == null:
			row.issues.append("failed to load")
			rows.append(row)
			continue
		row.shader_type = "spatial"
		row.compiles = true
		var text: String = FileAccess.get_file_as_string(path)
		for token in ["discard", "NORMAL=", "EMISSION=", "METALLIC=", "SPECULAR=", "source_color", "TIME", "MODEL_MATRIX"]:
			if text.find(token) >= 0:
				row.render_modes.append(token)
		if text.find("hint_screen_texture") >= 0:
			row.issues.append("uses hint_screen_texture (Compatibility unsupported)")
		if text.find("hint_depth_texture") >= 0:
			row.issues.append("uses hint_depth_texture (Compatibility unsupported)")
		if text.find("render_mode unshaded") < 0 and text.find("shader_type spatial") >= 0:
			row.issues.append("uses standard spatial lighting path")
		rows.append(row)
	return rows


static func build_handoff(
	config: Dictionary,
	fixture: Dictionary,
	sample_rows: Array,
	shader_audit: Array,
	visual_notes: Dictionary
) -> Dictionary:
	var method: String = runtime_method()
	return {
		"comparison_version": 1,
		"captured_at": Time.get_datetime_string_from_system(true),
		"decision": "keep_compatibility",
		"scenario": config.get("scenario", ""),
		"comparison_mode": config.get("comparison_mode", "feature_matched"),
		"requested_renderer": requested_method(),
		"project_renderer": project_method(),
		"runtime_renderer": method,
		"runtime_renderer_label": method_label(method),
		"runtime_driver": runtime_driver(),
		"fixture": fixture,
		"config": config,
		"capabilities": capabilities_for(method),
		"hardware": GraphicsSettingsService.hardware_info(),
		"engine": GraphicsSettingsService.engine_info(),
		"runtime": {},
		"graphics_settings": {},
		"samples": sample_rows,
		"shader_audit": shader_audit,
		"visual_notes": visual_notes,
		"platform_coverage": {
			"macos_m2": method == "gl_compatibility" or not DisplayServer.get_name() == "headless",
			"windows": "untested",
		},
	}
