extends SceneTree

const Comparison = preload("res://scripts/renderer_comparison.gd")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var method: String = Comparison.runtime_method()
	var driver: String = Comparison.runtime_driver()
	var adapter: String = RenderingServer.get_video_adapter_name()
	print(
		"RENDERER_PROBE method=%s label=%s driver=%s adapter=%s headless=%s project=%s requested=%s"
		% [
			method,
			Comparison.method_label(method),
			driver,
			adapter,
			str(DisplayServer.get_name() == "headless"),
			Comparison.project_method(),
			Comparison.requested_method(),
		]
	)
	for row in Comparison.audit_shaders():
		var issues: String = ", ".join(row.get("issues", PackedStringArray()))
		print(
			"SHADER path=%s compiles=%s issues=%s"
			% [row.get("path", ""), str(row.get("compiles", false)), issues if not issues.is_empty() else "none"]
		)
	quit()
