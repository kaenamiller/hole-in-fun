extends SceneTree

const CalibrationClass = preload("res://scripts/color_calibration.gd")
const PaletteClass = preload("res://scripts/graphics_palette.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://builds/color_calibration")
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	camera.position = Vector3(8, 11, 14)
	camera.rotation_degrees = Vector3(-42, 35, 0)
	root.add_child(camera)
	camera.current = true

	for season in range(4):
		var scene := CalibrationClass.build_root(season)
		root.add_child(scene)
		await _capture_season(scene, season, "overview")
		camera.size = 7.0
		camera.position = Vector3(4, 5.5, 7)
		camera.rotation_degrees = Vector3(-35, 28, 0)
		await _capture_season(scene, season, "close")
		camera.size = 14.0
		camera.position = Vector3(8, 11, 14)
		camera.rotation_degrees = Vector3(-42, 35, 0)
		scene.queue_free()
		await process_frame

	print(
		"Color calibration captures complete. Draw calls: %d; primitives: %d"
		% [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		]
	)
	quit()

func _capture_season(_scene: Node3D, season: int, view: String) -> void:
	for i in range(12):
		await process_frame
	var name: String = PaletteClass.season_name(season)
	var path: String = "res://builds/color_calibration/%s-%s.png" % [name, view]
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
