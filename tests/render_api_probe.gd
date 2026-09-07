extends SceneTree
func _init():
	print("adapter=", RenderingServer.get_video_adapter_name())
	print("method=", RenderingServer.get_current_rendering_method())
	print("driver=", RenderingServer.get_current_rendering_driver_name())
	print("project=", ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	quit()
