class_name SimpleChart
extends Control

const INK = Color("24483b")
const MUTED = Color("74816f")
const ACCENT = Color("cf7951")
const GREEN_A = Color("6f9b6a")
const GREEN_B = Color("afbe8e")

var series: Array[Dictionary] = []
var labels: Array[String] = []
var chart_mode: String = "line"
var range_days: int = 7
var _hover_index: int = -1
var _legend: Array[String] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(280, 120)


func set_series(data: Array[Dictionary], day_labels: Array[String], legend_names: Array[String], mode: String = "line") -> void:
	series = data
	labels = day_labels
	_legend = legend_names
	chart_mode = mode
	_hover_index = -1
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(36, 8), size - Vector2(44, 28))
	if rect.size.x < 20 or rect.size.y < 20:
		return
	draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), MUTED, 1.0)
	draw_line(rect.position, rect.position + Vector2(0, rect.size.y), MUTED, 1.0)
	draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, MUTED, 1.0)
	if series.is_empty():
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, rect.size.y * 0.5), "No data yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, MUTED)
		_draw_legend()
		return
	var palette: Array[Color] = [INK, ACCENT, GREEN_A, GREEN_B]
	var min_v: float = INF
	var max_v: float = -INF
	for point in series:
		for key in point.keys():
			if key == "day":
				continue
			min_v = minf(min_v, float(point[key]))
			max_v = maxf(max_v, float(point[key]))
	if is_equal_approx(min_v, max_v):
		min_v -= 1.0
		max_v += 1.0
	var keys: Array[String] = []
	if not series.is_empty():
		for key in series[0].keys():
			if key != "day":
				keys.append(str(key))
	var count: int = series.size()
	for index in range(count):
		var x: float = rect.position.x + (float(index) / maxf(1.0, float(count - 1))) * rect.size.x
		if chart_mode == "bar" and keys.size() == 1:
			var value: float = float(series[index].get(keys[0], 0.0))
			var height: float = (value - min_v) / (max_v - min_v) * rect.size.y
			var bar_rect: Rect2 = Rect2(Vector2(x - 6, rect.position.y + rect.size.y - height), Vector2(12, height))
			draw_rect(bar_rect, palette[0])
		elif chart_mode == "stacked_bar":
			var stack_base: float = rect.position.y + rect.size.y
			for key_index in range(keys.size()):
				var value: float = float(series[index].get(keys[key_index], 0.0))
				var height: float = (value - min_v) / (max_v - min_v) * rect.size.y
				var bar_rect: Rect2 = Rect2(Vector2(x - 8, stack_base - height), Vector2(16 / maxi(1, keys.size()), height))
				draw_rect(bar_rect, palette[key_index % palette.size()])
				stack_base -= height
		else:
			for key_index in range(keys.size()):
				var value: float = float(series[index].get(keys[key_index], 0.0))
				var y: float = rect.position.y + rect.size.y - (value - min_v) / (max_v - min_v) * rect.size.y
				if index > 0:
					var prev: Dictionary = series[index - 1]
					var prev_value: float = float(prev.get(keys[key_index], 0.0))
					var prev_y: float = rect.position.y + rect.size.y - (prev_value - min_v) / (max_v - min_v) * rect.size.y
					var prev_x: float = rect.position.x + (float(index - 1) / maxf(1.0, float(count - 1))) * rect.size.x
					draw_line(Vector2(prev_x, prev_y), Vector2(x, y), palette[key_index % palette.size()], 2.0)
				draw_circle(Vector2(x, y), 3.0, palette[key_index % palette.size()])
		if index == _hover_index:
			draw_line(Vector2(x, rect.position.y), Vector2(x, rect.position.y + rect.size.y), ACCENT.lightened(0.2), 1.0)
	if _hover_index >= 0 and _hover_index < labels.size():
		var tip: String = labels[_hover_index]
		for key_index in range(keys.size()):
			tip += "\n%s: %.1f" % [_legend[key_index] if key_index < _legend.size() else keys[key_index], float(series[_hover_index].get(keys[key_index], 0.0))]
		draw_string(ThemeDB.fallback_font, Vector2(4, 4), tip, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK)
	_draw_legend()


func _draw_legend() -> void:
	var palette: Array[Color] = [INK, ACCENT, GREEN_A, GREEN_B]
	var x: float = 40.0
	for index in range(_legend.size()):
		draw_rect(Rect2(Vector2(x, size.y - 16), Vector2(10, 10)), palette[index % palette.size()])
		draw_string(ThemeDB.fallback_font, Vector2(x + 14, size.y - 6), _legend[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, MUTED)
		x += 14.0 + float(_legend[index].length()) * 6.5


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed):
		var rect: Rect2 = Rect2(Vector2(36, 8), size - Vector2(44, 28))
		var local: Vector2 = (event as InputEventMouse).position
		if not rect.has_point(local) or series.is_empty():
			_hover_index = -1
		else:
			var ratio: float = clampf((local.x - rect.position.x) / maxf(1.0, rect.size.x), 0.0, 1.0)
			_hover_index = clampi(int(round(ratio * float(series.size() - 1))), 0, series.size() - 1)
		queue_redraw()
