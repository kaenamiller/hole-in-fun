extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var started: int = Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	print("Lush world ready in %d ms" % (Time.get_ticks_msec()-started))
	game.ui.hide_menu()
	game.speed=0
	game.set_tool("inspect")
	game.ui.refresh()
	game.camera.focus=Vector3(310,0,305)
	game.camera.size=470
	game.camera.elevation=0.9
	game.camera.yaw=0.3
	await capture("lush-overview.png")
	game.toggle_photo_mode()
	game.camera.focus=Vector3(245,0,307)
	game.camera.size=280
	game.camera.elevation=0.60
	game.camera.yaw=-0.9
	await capture("lush-resort.png")
	game.camera.focus=Vector3(272,0,230)
	game.camera.size=260
	game.camera.yaw=0.1
	game.camera.elevation=0.85
	await capture("lush-hole.png")
	game.camera.focus=Vector3(169,0,290)
	game.camera.size=64
	game.camera.yaw=1.9
	game.camera.elevation=0.7
	await capture("lush-clubhouse.png")
	game.camera.focus=Vector3(200,0,374)
	game.camera.size=80
	game.camera.yaw=0.7
	await capture("lush-trees.png")
	print("Lush screenshots complete. Draw calls: %d; primitives: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	game.queue_free()
	await process_frame
	quit()

func capture(filename: String) -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://builds/"+filename)
	print("Captured "+filename)
