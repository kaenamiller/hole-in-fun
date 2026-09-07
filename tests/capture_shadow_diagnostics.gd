extends SceneTree

const DiagnosticsClass = preload("res://scripts/shadow_diagnostics.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/shadow_diagnostics")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.position = Vector3(12, 14, 18)
	camera.rotation_degrees = Vector3(-40, 38, 0)
	root.add_child(camera)
	camera.current = true

	for preset_name in ["standard", "low", "high"]:
		var settings: GraphicsSettings = SettingsClass.for_preset(preset_name)
		var scene := DiagnosticsClass.build_root(settings)
		root.add_child(scene)
		await _capture(scene, preset_name, "overview")
		camera.size = 9.0
		camera.position = Vector3(4, 6, 7)
		camera.rotation_degrees = Vector3(-32, 30, 0)
		await _capture(scene, preset_name, "contact")
		camera.size = 18.0
		camera.position = Vector3(12, 14, 18)
		camera.rotation_degrees = Vector3(-40, 38, 0)
		scene.queue_free()
		await process_frame

	print(
		"Shadow diagnostics captures complete. Draw calls: %d; primitives: %d"
		% [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		]
	)
	quit()

func _capture(_scene: Node3D, preset_name: String, view: String) -> void:
	for i in range(12):
		await process_frame
	var path: String = "res://builds/shadow_diagnostics/%s-%s.png" % [preset_name, view]
	var tex: Texture2D = root.get_texture()
	if tex == null:
		print("Skipped %s (headless dummy framebuffer)" % path)
		return
	var image: Image = tex.get_image()
	if image != null and not image.is_empty():
		image.save_png(path)
		print("Captured %s" % path)
	else:
		print("Skipped %s (empty framebuffer)" % path)
