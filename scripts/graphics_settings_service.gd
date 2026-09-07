class_name GraphicsSettingsService
extends RefCounted

signal settings_changed(previous: GraphicsSettings, current: GraphicsSettings)

const PATH: String = "user://settings/graphics.json"
const LEGACY_PATH: String = "user://graphics_settings.json"

var current: GraphicsSettings = GraphicsSettings.defaults()


static func load_or_default() -> GraphicsSettings:
	var service := GraphicsSettingsService.new()
	service.current = service._read_file()
	return service.current


func _init() -> void:
	current = _read_file()


func _read_file() -> GraphicsSettings:
	for path in [PATH, LEGACY_PATH]:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text: String = file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var settings: GraphicsSettings = GraphicsSettings.defaults()
			settings.load_dict(parsed)
			return settings
	return GraphicsSettings.defaults()


func save() -> String:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return "Could not save graphics settings: " + error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(current.to_dict(), "\t"))
	file.close()
	return "Graphics settings saved"


func set_preset(name_value: String) -> void:
	var previous: GraphicsSettings = current.duplicate_settings()
	current = GraphicsSettings.for_preset(name_value)
	settings_changed.emit(previous, current)
	save()


func replace(settings: GraphicsSettings) -> void:
	var previous: GraphicsSettings = current.duplicate_settings()
	current = settings.duplicate_settings()
	current.sanitize()
	settings_changed.emit(previous, current)
	save()


func apply_to_game(game: Node, rebuild_scenery: bool = true) -> void:
	if game == null:
		return
	var viewport: Viewport = game.get_viewport()
	if viewport != null:
		viewport.msaa_3d = clampi(current.msaa_3d, 0, 3) as Viewport.MSAA
	if game.has_method("_apply_graphics_lighting"):
		game.call("_apply_graphics_lighting", current)
	if game.has_method("_apply_graphics_environment"):
		game.call("_apply_graphics_environment", current)
	if game.has_method("_apply_graphics_weather"):
		game.call("_apply_graphics_weather", current)
	if rebuild_scenery and game.get("world") != null and is_instance_valid(game.world):
		if game.world.has_method("apply_graphics_settings"):
			game.world.apply_graphics_settings(current)


static func hardware_info() -> Dictionary:
	var adapter: String = RenderingServer.get_video_adapter_name()
	var runtime_method: String = _runtime_rendering_method()
	return {
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"cpu": OS.get_processor_name(),
		"gpu": adapter if not adapter.is_empty() else "unknown",
		"renderer": runtime_method,
		"project_renderer": ProjectSettings.get_setting("rendering/renderer/rendering_method", ""),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"video_adapter_type": RenderingServer.get_video_adapter_type(),
	}


static func engine_info() -> Dictionary:
	var runtime_method: String = _runtime_rendering_method()
	return {
		"godot": Engine.get_version_info(),
		"compatibility": runtime_method == "gl_compatibility",
		"runtime_method": runtime_method,
		"runtime_driver": RenderingServer.get_current_rendering_driver_name(),
	}


static func _runtime_rendering_method() -> String:
	var method: String = RenderingServer.get_current_rendering_method()
	if method.is_empty():
		method = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility"))
	return method


static func runtime_info(game: Node) -> Dictionary:
	var viewport: Viewport = game.get_viewport() if game != null else null
	var size: Vector2i = viewport.get_visible_rect().size if viewport != null else DisplayServer.window_get_size()
	return {
		"resolution": {"width": size.x, "height": size.y},
		"msaa_3d": viewport.msaa_3d if viewport != null else ProjectSettings.get_setting("anti_aliasing/quality/msaa_3d", 0),
	}
