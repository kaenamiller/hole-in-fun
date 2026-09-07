class_name ResortUI
extends CanvasLayer

const INK = Color("24483b")
const MUTED = Color("74816f")
const PAPER = Color("f5f2e7")
const ACCENT = Color("cf7951")
const CARD = Color("eaeddd")
const CARD_HOVER = Color("dfe5cf")
const CARD_ACTIVE = Color("e4e8d5")
const RULE = Color("d3d8c5")
const OK = Color("6f9b6a")
const TOAST_COLORS: Dictionary = {
	"info": Color("6a8f9b"),
	"success": Color("6f9b6a"),
	"warning": Color("cf7951"),
	"critical": Color("b84a3a"),
}
const HEADER_H: int = 72
const FOOTER_H: int = 36
const GUTTER: int = 12
# Rail groups: Design / Operate / Grow / Reports. `null` entries are dividers.
const RAIL: Array = [
	["Terrain", "↟"], ["Holes", "⚑"], ["Build", "⌂"], null,
	["Guests", "♙"], ["Staff", "♧"], ["Money", "$"], null,
	["Reputation", "★"], ["Progress", "✦"], null,
	["Reports", "∿"],
]
# Legacy tab names still used by the simulation log targets and older callers.
const TAB_ALIASES: Dictionary = {
	"Marketing": "Reputation", "Events": "Reputation", "Statistics": "Reports", "Saves": "System", "Log": "Log",
}
const EYEBROWS: Dictionary = {
	"Terrain": "THE LAND", "Holes": "THE ROUND", "Build": "THE RESORT", "Guests": "THE PEOPLE",
	"Staff": "THE TEAM", "Money": "THE BUSINESS", "Reputation": "THE WORD", "Progress": "THE PLAN",
	"Reports": "THE RECORD", "System": "YOUR RESORT", "Log": "WHAT HAPPENED",
}
const SPEEDS: Array = [["Ⅱ", 0], ["1×", 1], ["2×", 2], ["4×", 4]]

var game
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var header_label: Label
var back_button: Button
var cash_label: Label
var cash_sub: Label
var visitor_label: Label
var visitor_sub: Label
var satisfaction_label: Label
var satisfaction_sub: Label
var grade_label: Label
var grade_sub: Label
var forecast_label: Label
var condition_label: Label
var day_label: Label
var clock_label: Label
var status_label: Label
var issue_button: Button
var sandbox_chip: Control
var mode_label: Label
var tool_label: Label
var dynamic_label: Label
var tab: String = "Terrain"
var view: String = "tab"
var menu: Control
var nav_buttons: Dictionary = {}
var speed_buttons: Dictionary = {}
var open_button: Button
var price_edits: Dictionary = {}
var event_days: int = 1
var toast_container: VBoxContainer
var bell_button: Button
var gear_button: Button
var pause_banner: Control
var reports_overlay: Control
var overlay_option: OptionButton
var overlay_legend_min: Label
var overlay_legend_max: Label
var overlay_legend_gradient: TextureRect
var overlay_landings_caption: Label
var grid_button: Button
var ongoing_row: HBoxContainer

var _log_category_filter: String = ""
var _log_severity_filter: String = ""
var _toast_entries: Array[Dictionary] = []
var _stats_range_days: int = 7
var _feedback_range_days: int = 1
var _course_sort_column: String = "rounds"
var _course_sort_desc: bool = true
var _selected_progress_node: String = ""
var _progress_branch: String = "operations"
var _money_view: String = "prices"
var _reputation_view: String = "reputation"
var _reports_view: String = "money"
var _expanded_sets: Dictionary = {}
var _reviews_expanded: bool = false
var _guest_list_expanded: bool = false
var _staff_expanded: Dictionary = {}
var _live: Dictionary = {}
var _target: VBoxContainer
var _stat_boxes: Dictionary = {}
var _title_label: Label
var _rail: VBoxContainer
var _rail_buttons: Array[Button] = []
var _workspace: VBoxContainer
var _view_row: HBoxContainer
var _ongoing_signature: String = ""
var _rail_width: int = 70
var _reports_body: VBoxContainer

# ---------------------------------------------------------------- setup

func setup(controller) -> void:
	game = controller
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = _make_theme()
	_build_header()
	_build_footer()
	_build_rail()
	_build_workspace()
	_build_panel()
	_build_toast_stack()
	_build_pause_banner()
	root.resized.connect(_apply_layout)
	_apply_layout()
	show_tab("Terrain")

func _make_theme() -> Theme:
	var theme = Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", Color("a2a99a"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c = PAPER
		if state == "hover": c = Color("e4e8d5")
		if state == "pressed": c = INK
		if state == "disabled": c = Color("e7e6dc")
		var style = box(c, 8, 10)
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("afbe8e")
			style.set_border_width_all(2)
		theme.set_stylebox(state, "Button", style)
	theme.set_stylebox("normal", "LineEdit", box(Color("ffffff"), 6, 8))
	theme.set_color("font_color", "LineEdit", INK)
	theme.set_color("caret_color", "LineEdit", INK)
	theme.set_color("font_color", "OptionButton", INK)
	theme.set_stylebox("normal", "OptionButton", box(Color("ffffff"), 6, 8))
	theme.set_stylebox("hover", "OptionButton", box(Color("f7f8ef"), 6, 8))
	theme.set_stylebox("pressed", "OptionButton", box(Color("e4e8d5"), 6, 8))
	theme.set_stylebox("panel", "PopupMenu", box(PAPER, 8, 8))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_stylebox("hover", "PopupMenu", box(CARD_HOVER, 6, 6))
	theme.set_color("font_color", "MenuButton", INK)
	theme.set_stylebox("normal", "SpinBox", box(Color("ffffff"), 6, 6))
	theme.set_color("font_color", "CheckBox", INK)
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_color", "ProgressBar", INK)
	theme.set_stylebox("background", "ProgressBar", box(Color("dfe3d3"), 6, 0))
	theme.set_stylebox("fill", "ProgressBar", box(OK, 6, 0))
	return theme

# ---------------------------------------------------------------- primitives

static func box(color: Color, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style

static func label(text: String, font_size: int = 14, color: Color = INK) -> Label:
	var item = Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	return item

func _parent(parent: Node) -> Node:
	return parent if parent != null else _target

func button(text: String, callback: Callable, parent: Node = null) -> Button:
	var item = Button.new()
	item.text = text
	item.alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y = 34
	item.pressed.connect(callback)
	_parent(parent).add_child(item)
	return item

func primary(text: String, callback: Callable, parent: Node = null) -> Button:
	var item = button(text, callback, parent)
	item.alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.add_theme_stylebox_override("normal", box(INK, 8, 10))
	item.add_theme_stylebox_override("hover", box(INK.lightened(0.12), 8, 10))
	item.add_theme_color_override("font_color", PAPER)
	item.add_theme_color_override("font_hover_color", PAPER)
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return item

func small_button(text: String, callback: Callable, parent: Node = null) -> Button:
	var item = button(text, callback, parent)
	item.custom_minimum_size = Vector2(0, 28)
	item.add_theme_font_size_override("font_size", 12)
	item.alignment = HORIZONTAL_ALIGNMENT_CENTER
	return item

func copy(text: String, size_value: int = 13, color: Color = MUTED, parent: Node = null) -> Label:
	var item = label(text, size_value, color)
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_parent(parent).add_child(item)
	return item

func heading(text: String, parent: Node = null) -> Label:
	return copy(text, 19, INK, parent)

func note(text: String, color: Color = MUTED, parent: Node = null) -> Label:
	return copy(text, 12, color, parent)

func section(text: String, parent: Node = null) -> void:
	var host = _parent(parent)
	var space = Control.new()
	space.custom_minimum_size.y = 8
	host.add_child(space)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	host.add_child(row)
	row.add_child(label(text.to_upper(), 11, MUTED))
	row.add_child(rule(row))

func rule(_parent_unused: Node = null) -> Control:
	var line = ColorRect.new()
	line.color = RULE
	line.custom_minimum_size.y = 1
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line

func card(parent: Node = null, tint: Color = CARD, selected: bool = false) -> VBoxContainer:
	var wrap = PanelContainer.new()
	var style = box(tint, 10, 12)
	if selected:
		style.border_color = ACCENT
		style.set_border_width_all(2)
	wrap.add_theme_stylebox_override("panel", style)
	_parent(parent).add_child(wrap)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	wrap.add_child(column)
	return column

func kv(parent: Node, key: String, value: String, color: Color = INK, size_value: int = 13) -> Label:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_parent(parent).add_child(row)
	var k = label(key, size_value, MUTED)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(k)
	var v = label(value, size_value, color)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(v)
	return v

func chip(text: String, fg: Color = MUTED, bg: Color = Color("e4e8d5")) -> PanelContainer:
	var wrap = PanelContainer.new()
	var style = box(bg, 6, 7)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	wrap.add_theme_stylebox_override("panel", style)
	wrap.add_child(label(text, 11, fg))
	return wrap

func actions(parent: Node = null) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_parent(parent).add_child(row)
	return row

func more_menu(parent: Node, entries: Array) -> MenuButton:
	var item = MenuButton.new()
	item.text = "…"
	item.flat = false
	item.custom_minimum_size = Vector2(38, 34)
	item.add_theme_stylebox_override("normal", box(PAPER, 8, 8))
	item.add_theme_stylebox_override("hover", box(CARD_HOVER, 8, 8))
	item.add_theme_stylebox_override("pressed", box(CARD_HOVER, 8, 8))
	var popup = item.get_popup()
	for index in range(entries.size()):
		popup.add_item(str(entries[index][0]), index)
	popup.id_pressed.connect(func(id: int) -> void:
		if id >= 0 and id < entries.size():
			(entries[id][1] as Callable).call()
	)
	_parent(parent).add_child(item)
	return item

func segmented(parent: Node, options: Array, current: Variant, on_pick: Callable) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_parent(parent).add_child(row)
	for pair in options:
		var value = pair[1]
		var seg = Button.new()
		seg.text = str(pair[0])
		seg.custom_minimum_size.y = 28
		seg.add_theme_font_size_override("font_size", 12)
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.alignment = HORIZONTAL_ALIGNMENT_CENTER
		var active: bool = value == current
		seg.add_theme_stylebox_override("normal", box(INK if active else CARD, 7, 6))
		seg.add_theme_stylebox_override("hover", box(INK if active else CARD_HOVER, 7, 6))
		seg.add_theme_color_override("font_color", PAPER if active else INK)
		seg.add_theme_color_override("font_hover_color", PAPER if active else INK)
		seg.pressed.connect(func(): on_pick.call(value))
		row.add_child(seg)
	return row

func list_item(title: String, meta: String, on_click: Callable, badge: String = "", badge_color: Color = MUTED, parent: Node = null, selected: bool = false) -> PanelContainer:
	var wrap = PanelContainer.new()
	var normal = box(CARD, 10, 10)
	var hover = box(CARD_HOVER, 10, 10)
	if selected:
		for style in [normal, hover]:
			style.border_color = ACCENT
			style.set_border_width_all(2)
	wrap.add_theme_stylebox_override("panel", normal)
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	wrap.mouse_entered.connect(func(): wrap.add_theme_stylebox_override("panel", hover))
	wrap.mouse_exited.connect(func(): wrap.add_theme_stylebox_override("panel", normal))
	wrap.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
	)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	wrap.add_child(row)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var title_label = label(title, 14, INK)
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_label)
	if not meta.is_empty():
		var meta_label = label(meta, 12, MUTED)
		meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(meta_label)
	if not badge.is_empty():
		var badge_chip = chip(badge, badge_color, Color("f5f2e7"))
		badge_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(badge_chip)
	_parent(parent).add_child(wrap)
	return wrap

func _percent(value: float) -> String:
	return "%.0f%%" % (value * 100.0)

# ---------------------------------------------------------------- chrome

func _build_header() -> void:
	var bar = PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = HEADER_H
	var style = box(PAPER, 0, 14)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bar.add_theme_stylebox_override("panel", style)
	root.add_child(bar)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	var logo = TextureRect.new()
	logo.texture = load("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(38, 38)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(logo)
	_title_label = label("Hole in Fun", 21)
	_title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_title_label)
	cash_label = _stat(row, "funds", "FUNDS", "$0")
	cash_sub = _stat_sub("funds")
	visitor_label = _stat(row, "visitors", "ON SITE", "0")
	visitor_sub = _stat_sub("visitors")
	satisfaction_label = _stat(row, "satisfaction", "SATISFACTION", "0%")
	satisfaction_sub = _stat_sub("satisfaction")
	grade_label = _stat(row, "rating", "RATING", "★ 3.0")
	grade_sub = _stat_sub("rating")
	forecast_label = _stat(row, "forecast", "TOMORROW", "—")
	_stat_sub("forecast").text = "expected guests"
	condition_label = _stat(row, "condition", "COURSE", "100%")
	_stat_sub("condition").text = "condition"
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var time_cluster = HBoxContainer.new()
	time_cluster.add_theme_constant_override("separation", 10)
	time_cluster.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(time_cluster)
	var speeds = HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 2)
	time_cluster.add_child(speeds)
	for pair in SPEEDS:
		var speed_value: int = int(pair[1])
		var b = button(str(pair[0]), func(): game.set_speed(speed_value), speeds)
		b.custom_minimum_size = Vector2(36, 34)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = "Pause (Space)" if speed_value == 0 else "Run at %d× speed" % speed_value
		speed_buttons[speed_value] = b
	var clock_col = VBoxContainer.new()
	clock_col.add_theme_constant_override("separation", 0)
	clock_col.custom_minimum_size.x = 118
	time_cluster.add_child(clock_col)
	clock_label = label("07:00", 18, INK)
	clock_col.add_child(clock_label)
	day_label = label("Day 1 · Spring", 11, MUTED)
	clock_col.add_child(day_label)
	open_button = button("Open", func(): game.toggle_open(), time_cluster)
	open_button.custom_minimum_size = Vector2(76, 34)
	open_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	open_button.tooltip_text = "Toggle arrivals. Current guests always finish their visits."
	bell_button = button("🔔", func(): show_log(), time_cluster)
	bell_button.custom_minimum_size = Vector2(44, 34)
	bell_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bell_button.tooltip_text = "Resort event log"
	gear_button = button("⚙", func(): show_system(), time_cluster)
	gear_button.custom_minimum_size = Vector2(40, 34)
	gear_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_button.tooltip_text = "Saves, settings, and help"

func _stat(parent: Node, key: String, caption: String, value: String) -> Label:
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(v)
	v.add_child(label(caption, 10, MUTED))
	var result = label(value, 18)
	v.add_child(result)
	var sub = label("", 11, MUTED)
	v.add_child(sub)
	_stat_boxes[key] = v
	return result

func _stat_sub(key: String) -> Label:
	var v: VBoxContainer = _stat_boxes[key]
	return v.get_child(2)

func _build_footer() -> void:
	var footer = PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -FOOTER_H
	var style = box(INK, 0, 14)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	footer.add_theme_stylebox_override("panel", style)
	root.add_child(footer)
	var frow = HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	footer.add_child(frow)
	status_label = label("Welcome to your little corner of the game.", 13, PAPER)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	frow.add_child(status_label)
	sandbox_chip = chip("SANDBOX", INK, Color("f2e9c9"))
	sandbox_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sandbox_chip.visible = false
	frow.add_child(sandbox_chip)
	issue_button = button("", func(): show_log(), frow)
	issue_button.custom_minimum_size.y = 26
	issue_button.add_theme_font_size_override("font_size", 12)
	issue_button.add_theme_stylebox_override("normal", box(ACCENT, 6, 8))
	issue_button.add_theme_stylebox_override("hover", box(ACCENT.lightened(0.1), 6, 8))
	issue_button.add_theme_color_override("font_color", PAPER)
	issue_button.add_theme_color_override("font_hover_color", PAPER)
	issue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	issue_button.visible = false
	issue_button.tooltip_text = "Latest warning. Click to open the log."

func _build_rail() -> void:
	_rail = VBoxContainer.new()
	_rail.add_theme_constant_override("separation", 6)
	_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.add_child(_rail)
	for entry in RAIL:
		if entry == null:
			var divider = ColorRect.new()
			divider.color = Color(PAPER, 0.35)
			divider.custom_minimum_size = Vector2(0, 1)
			_rail.add_child(divider)
			continue
		var name_value: String = str(entry[0])
		var icon: String = str(entry[1])
		var b = Button.new()
		b.text = icon + "\n" + name_value
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_font_size_override("font_size", 12)
		b.tooltip_text = name_value
		b.set_meta("icon", icon)
		b.set_meta("tab", name_value)
		b.pressed.connect(func(): show_tab(name_value))
		_rail.add_child(b)
		nav_buttons[name_value] = b
		_rail_buttons.append(b)

func _build_workspace() -> void:
	_workspace = VBoxContainer.new()
	_workspace.add_theme_constant_override("separation", 8)
	_workspace.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_workspace.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_workspace)
	var hud = PanelContainer.new()
	hud.add_theme_stylebox_override("panel", box(Color("23493cee"), 10, 10))
	hud.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_workspace.add_child(hud)
	var hud_row = HBoxContainer.new()
	hud_row.add_theme_constant_override("separation", 10)
	hud.add_child(hud_row)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	hud_row.add_child(v)
	tool_label = label("INSPECT YOUR RESORT", 12, Color("f2e9c9"))
	v.add_child(tool_label)
	mode_label = label("Click a golfer or object to inspect", 12, Color("c1d0ae"))
	v.add_child(mode_label)
	var undo = Button.new()
	undo.text = "↶"
	undo.tooltip_text = "Undo (⌘Z / Ctrl+Z)"
	undo.custom_minimum_size = Vector2(32, 30)
	undo.pressed.connect(func(): game.undo())
	hud_row.add_child(undo)
	var redo = Button.new()
	redo.text = "↷"
	redo.tooltip_text = "Redo (⌘⇧Z / Ctrl+Shift+Z)"
	redo.custom_minimum_size = Vector2(32, 30)
	redo.pressed.connect(func(): game.redo())
	hud_row.add_child(redo)
	_view_row = HBoxContainer.new()
	_view_row.add_theme_constant_override("separation", 8)
	_workspace.add_child(_view_row)
	var view_panel = PanelContainer.new()
	view_panel.add_theme_stylebox_override("panel", box(Color("f5f2e7dd"), 10, 8))
	_view_row.add_child(view_panel)
	var view_inner = HBoxContainer.new()
	view_inner.add_theme_constant_override("separation", 8)
	view_panel.add_child(view_inner)
	view_inner.add_child(label("VIEW", 10, MUTED))
	overlay_option = OptionButton.new()
	overlay_option.custom_minimum_size.x = 132
	for overlay_id in game.OVERLAY_IDS:
		overlay_option.add_item(_overlay_label(overlay_id))
	overlay_option.selected = maxi(0, game.OVERLAY_IDS.find(game.world.overlay))
	overlay_option.item_selected.connect(func(index: int): game.set_overlay(game.OVERLAY_IDS[index]))
	overlay_option.tooltip_text = "Data overlay on the land (O cycles)"
	view_inner.add_child(overlay_option)
	overlay_legend_min = label("0", 11, MUTED)
	overlay_legend_gradient = TextureRect.new()
	overlay_legend_gradient.custom_minimum_size = Vector2(90, 10)
	overlay_legend_gradient.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay_legend_gradient.stretch_mode = TextureRect.STRETCH_SCALE
	overlay_legend_gradient.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	overlay_legend_max = label("—", 11, MUTED)
	view_inner.add_child(overlay_legend_min)
	view_inner.add_child(overlay_legend_gradient)
	view_inner.add_child(overlay_legend_max)
	overlay_landings_caption = label("", 11, MUTED)
	view_inner.add_child(overlay_landings_caption)
	grid_button = Button.new()
	grid_button.text = "Grid"
	grid_button.custom_minimum_size = Vector2(0, 28)
	grid_button.add_theme_font_size_override("font_size", 12)
	grid_button.tooltip_text = "Toggle the 4 m editing grid"
	grid_button.pressed.connect(func(): game.toggle_grid(); _refresh_overlay_panel())
	view_inner.add_child(grid_button)
	ongoing_row = HBoxContainer.new()
	ongoing_row.add_theme_constant_override("separation", 6)
	_workspace.add_child(ongoing_row)
	_refresh_overlay_panel()

func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.add_theme_stylebox_override("panel", box(PAPER, 14, 16))
	root.add_child(panel)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	panel.add_child(outer)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	outer.add_child(top)
	header_label = label("THE LAND", 11, MUTED)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(header_label)
	back_button = small_button("‹ Back", func(): show_tab(tab), top)
	back_button.visible = false
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	_target = body

func _build_toast_stack() -> void:
	toast_container = VBoxContainer.new()
	toast_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	toast_container.alignment = BoxContainer.ALIGNMENT_END
	toast_container.add_theme_constant_override("separation", 8)
	toast_container.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(toast_container)

func _build_pause_banner() -> void:
	pause_banner = PanelContainer.new()
	pause_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pause_banner.add_theme_stylebox_override("panel", box(Color("f2e9c9"), 8, 10))
	pause_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_banner.visible = false
	var text = label("PAUSED  ·  Space or 1× to resume", 12, INK)
	pause_banner.add_child(text)
	root.add_child(pause_banner)

func _apply_layout() -> void:
	if root == null:
		return
	var vs: Vector2 = root.size
	if vs.x < 10.0 or vs.y < 10.0:
		vs = get_viewport().get_visible_rect().size
	var panel_w: float = clampf(vs.x * 0.26, 320.0, 420.0)
	panel.offset_left = -(panel_w + GUTTER)
	panel.offset_right = -GUTTER
	panel.offset_top = HEADER_H + GUTTER
	panel.offset_bottom = -(FOOTER_H + GUTTER)
	var compact: bool = vs.y < 760.0
	_rail_width = 52 if compact else 70
	for b in _rail_buttons:
		var icon: String = str(b.get_meta("icon"))
		var name_value: String = str(b.get_meta("tab"))
		b.text = icon if compact else icon + "\n" + name_value
		b.custom_minimum_size = Vector2(_rail_width, 40 if compact else 54)
	_rail.offset_left = GUTTER
	_rail.offset_top = HEADER_H + GUTTER
	_rail.offset_right = GUTTER + _rail_width
	_rail.offset_bottom = vs.y - FOOTER_H - GUTTER
	_workspace.offset_left = GUTTER * 2 + _rail_width
	_workspace.offset_top = HEADER_H + GUTTER
	_workspace.offset_right = vs.x - panel_w - GUTTER * 3
	_workspace.offset_bottom = _workspace.offset_top + 200
	toast_container.offset_right = -(panel_w + GUTTER * 2)
	toast_container.offset_left = toast_container.offset_right - 320
	toast_container.offset_bottom = -(FOOTER_H + GUTTER)
	toast_container.offset_top = toast_container.offset_bottom - 300
	pause_banner.offset_top = HEADER_H + GUTTER
	pause_banner.offset_bottom = HEADER_H + GUTTER + 36
	pause_banner.offset_left = -130
	pause_banner.offset_right = 130
	_title_label.visible = vs.x >= 1080.0
	_stat_boxes["condition"].visible = vs.x >= 1320.0
	_stat_boxes["forecast"].visible = vs.x >= 1180.0
	_stat_boxes["rating"].visible = vs.x >= 1000.0
	if is_instance_valid(reports_overlay):
		_layout_reports_overlay()

# ---------------------------------------------------------------- toasts

func show_toast(entry: Dictionary) -> void:
	if not is_instance_valid(toast_container):
		return
	while _toast_entries.size() >= 4:
		var old: Dictionary = _toast_entries.pop_front()
		if is_instance_valid(old.get("node")):
			old.node.queue_free()
	var stripe: Color = TOAST_COLORS.get(str(entry.get("severity", "info")), INK)
	var toast_panel = PanelContainer.new()
	toast_panel.add_theme_stylebox_override("panel", box(PAPER, 8, 10))
	toast_panel.custom_minimum_size = Vector2(300, 0)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	toast_panel.add_child(row)
	var bar = ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar.color = stripe
	row.add_child(bar)
	var text_col = VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	var text = label(str(entry.get("text", "")), 13, INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(text)
	var count = int(entry.get("count", 1))
	if count > 1:
		row.add_child(label("×%d" % count, 12, stripe))
	var severity = str(entry.get("severity", "info"))
	var lifetime = 12.0 if severity == "critical" else 6.0
	var toast_data = {"node": toast_panel, "entry": entry.duplicate(true), "born": Time.get_ticks_msec(), "lifetime": lifetime, "persist": severity == "critical"}
	toast_panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game.jump_to(entry)
			toast_panel.queue_free()
			_toast_entries.erase(toast_data)
	)
	toast_container.add_child(toast_panel)
	_toast_entries.append(toast_data)
	_refresh_toast_timers()

func _refresh_toast_timers() -> void:
	var now = Time.get_ticks_msec()
	for toast_data in _toast_entries.duplicate():
		if not is_instance_valid(toast_data.get("node")):
			_toast_entries.erase(toast_data)
			continue
		if bool(toast_data.get("persist", false)):
			continue
		if now - int(toast_data.get("born", 0)) >= int(float(toast_data.get("lifetime", 6.0)) * 1000.0):
			toast_data.node.queue_free()
			_toast_entries.erase(toast_data)

func refresh_bell() -> void:
	if not is_instance_valid(bell_button) or game == null or game.sim == null:
		return
	var unread = game.sim.unread_count("warning")
	bell_button.text = "🔔 %d" % unread if unread > 0 else "🔔"

# ---------------------------------------------------------------- navigation

func _selection_kind() -> String:
	if game == null:
		return ""
	if not game.selected_hole.is_empty():
		return "hole"
	if not game.selected_object.is_empty():
		return "object"
	if int(game.selected_guest_id) >= 0:
		return "guest"
	if int(game.selected_staff_id) >= 0:
		return "staff"
	return ""

func show_tab(value: String) -> void:
	var resolved: String = str(TAB_ALIASES.get(value, value))
	if resolved == "System":
		show_system()
		return
	if resolved == "Log":
		show_log()
		return
	tab = resolved
	view = "tab"
	_render()

func show_inspector() -> void:
	if _selection_kind().is_empty():
		show_tab(tab)
		return
	view = "inspector"
	_render()

func show_log() -> void:
	view = "log"
	_render()

func show_system() -> void:
	view = "system"
	_render()

func refresh_system_panel() -> void:
	if view == "system":
		show_system()

func _update_quality_buttons(buttons: Dictionary) -> void:
	var active: String = GraphicsSettings.preset_name(game.graphics.current.preset)
	for preset_name in buttons.keys():
		var item: Button = buttons[preset_name]
		var selected: bool = str(preset_name) == active
		item.add_theme_stylebox_override("normal", box(INK if selected else PAPER, 8, 6))
		item.add_theme_stylebox_override("hover", box(INK if selected else CARD_HOVER, 8, 6))
		item.add_theme_color_override("font_color", PAPER if selected else INK)
		item.add_theme_color_override("font_hover_color", PAPER if selected else INK)

func refresh_view() -> void:
	if view == "inspector" and _selection_kind().is_empty():
		view = "tab"
	_render()

func _render() -> void:
	for child in body.get_children():
		child.queue_free()
	dynamic_label = null
	_live.clear()
	price_edits.clear()
	_target = body
	if tab != "Reports" and is_instance_valid(reports_overlay):
		_close_reports()
	for name_value in nav_buttons:
		var active: bool = name_value == tab and view in ["tab", "inspector"]
		nav_buttons[name_value].add_theme_stylebox_override("normal", box(INK if active else PAPER, 10, 6))
		nav_buttons[name_value].add_theme_stylebox_override("hover", box(INK if active else CARD_HOVER, 10, 6))
		nav_buttons[name_value].add_theme_color_override("font_color", PAPER if active else INK)
		nav_buttons[name_value].add_theme_color_override("font_hover_color", PAPER if active else INK)
	back_button.visible = view != "tab"
	back_button.text = "‹ %s" % tab
	match view:
		"inspector":
			header_label.text = "SELECTED · " + _selection_kind().to_upper()
			_inspector_panel()
		"log":
			header_label.text = EYEBROWS["Log"]
			_log_panel()
		"system":
			header_label.text = EYEBROWS["System"]
			_system_panel()
		_:
			header_label.text = str(EYEBROWS.get(tab, tab.to_upper()))
			_selection_pill()
			match tab:
				"Terrain": _terrain_panel()
				"Holes": _holes_panel()
				"Build": _build_panel_view()
				"Guests": _guests_panel()
				"Staff": _staff_panel()
				"Money": _money_panel()
				"Reputation": _reputation_panel()
				"Progress": _progress_panel()
				"Reports": _reports_panel()

func _selection_pill() -> void:
	var kind: String = _selection_kind()
	if kind.is_empty():
		return
	var title: String = ""
	match kind:
		"hole": title = str(game.selected_hole.get("name", "Hole"))
		"object": title = str(Catalog.find(str(game.selected_object.get("kind", ""))).get("name", str(game.selected_object.get("kind", "")).replace("_", " ")))
		"guest":
			for guest in game.sim.guests:
				if int(guest.get("id", -1)) == int(game.selected_guest_id):
					title = str(guest.get("name", "Guest"))
		"staff":
			for worker in game.sim.staff:
				if int(worker.get("id", -1)) == int(game.selected_staff_id):
					title = str(worker.get("name", "Worker"))
	if title.is_empty():
		return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	body.add_child(row)
	var open = button("⌖  %s  ›" % title, func(): show_inspector(), row)
	open.custom_minimum_size.y = 30
	open.add_theme_font_size_override("font_size", 12)
	open.add_theme_stylebox_override("normal", box(CARD_ACTIVE, 8, 8))
	open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open.tooltip_text = "Open the selected %s" % kind
	var clear = small_button("×", func(): game.clear_selection(); refresh_view(), row)
	clear.custom_minimum_size = Vector2(30, 30)
	clear.tooltip_text = "Clear selection"

# ---------------------------------------------------------------- terrain

func _terrain_panel() -> void:
	heading("Shape the land.")
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for pair in [["↟  Raise", "raise"], ["↡  Lower", "lower"], ["≈  Smooth", "smooth"], ["—  Flatten", "flatten"]]:
		var mode = pair[1]
		var b = button(pair[0], func(): game.set_tool(mode); refresh_view(), grid)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_mark_active_tool(b, mode)
	section("Brush")
	var brush = card()
	var radius_label = kv(brush, "Radius", "%d m" % game.brush_radius)
	var radius = HSlider.new()
	radius.min_value = 4
	radius.max_value = 64
	radius.step = 2
	radius.value = game.brush_radius
	radius.value_changed.connect(func(v): game.brush_radius = v; radius_label.text = "%d m" % v)
	brush.add_child(radius)
	var strength_label = kv(brush, "Strength", "%.1f m" % game.brush_strength)
	var strength = HSlider.new()
	strength.min_value = 0.2
	strength.max_value = 6
	strength.step = 0.2
	strength.value = game.brush_strength
	strength.value_changed.connect(func(v): game.brush_strength = v; strength_label.text = "%.1f m" % v)
	brush.add_child(strength)
	var node_toggle = CheckButton.new()
	node_toggle.text = "Single height node"
	node_toggle.add_theme_font_size_override("font_size", 12)
	node_toggle.button_pressed = game.single_node
	node_toggle.toggled.connect(func(v): game.single_node = v)
	brush.add_child(node_toggle)
	section("Greens & bunkers")
	var green_locked: bool = not game.sim.sandbox and not game.sim.can_build("tool:green_shape")
	var bunker_locked: bool = not game.sim.sandbox and not game.sim.can_build("tool:bunker_shape")
	var shaping = GridContainer.new()
	shaping.columns = 2
	shaping.add_theme_constant_override("h_separation", 6)
	shaping.add_theme_constant_override("v_separation", 6)
	body.add_child(shaping)
	for entry in [["↟  Green up", "green_contour", green_locked], ["↡  Green down", "green_contour_lower", green_locked], ["◠  Bunker depth", "bunker_shape", bunker_locked]]:
		var mode: String = str(entry[1])
		var b = button(str(entry[0]), func(): game.set_tool(mode); refresh_view(), shaping)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = bool(entry[2])
		if b.disabled:
			b.tooltip_text = "Unlock in the Progress tree"
		_mark_active_tool(b, mode)
	if green_locked or bunker_locked:
		note("Contour tools unlock through the Course branch of the Progress tree.")
	section("Surface")
	var palette = GridContainer.new()
	palette.columns = 2
	palette.add_theme_constant_override("h_separation", 6)
	palette.add_theme_constant_override("v_separation", 6)
	body.add_child(palette)
	for i in range(7):
		var type = i
		var b = button("●  " + TerrainModel.SURFACE_NAMES[i], func(): game.paint_surface = type; game.set_tool("paint"); refresh_view(), palette)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var palette_color: Color = game.terrain.palette[i] if i < game.terrain.palette.size() else TerrainModel.SURFACE_COLORS[i]
		b.add_theme_color_override("font_color", palette_color.darkened(0.4))
		if game.tool == "paint" and int(game.paint_surface) == i:
			b.add_theme_stylebox_override("normal", box(CARD_ACTIVE, 8, 10))
	note("Every stroke shows its live cost in the tool badge before you click.")

func _mark_active_tool(b: Button, mode: String) -> void:
	if str(game.tool) == mode:
		b.add_theme_stylebox_override("normal", box(INK, 8, 10))
		b.add_theme_color_override("font_color", PAPER)
		b.add_theme_color_override("font_hover_color", PAPER)

# ---------------------------------------------------------------- holes

func _hole_metric(hole_id: int, key: String) -> float:
	var cached: Dictionary = game.sim.hole_metrics.get(hole_id, {})
	var metrics: Dictionary = cached.get("metrics", {})
	return float(metrics.get(key, {}).get("value", -1.0))

func _holes_panel() -> void:
	heading("Every hole tells a story.")
	var course_summary: Dictionary = game.sim.course_metrics_summary()
	if not course_summary.is_empty():
		var summary = card()
		var design: float = float(course_summary.get("design_score", 0.0))
		var target: float = float(course_summary.get("grade_target", 45.0))
		kv(summary, "Design score", "%.0f / %.0f" % [design, target], OK if design >= target else ACCENT, 14)
		var par_mix: Dictionary = course_summary.get("par_mix", {})
		kv(summary, "Par %d" % int(course_summary.get("par_total", 0)), "%d · %d · %d  (3s · 4s · 5s)" % [int(par_mix.get("3", 0)), int(par_mix.get("4", 0)), int(par_mix.get("5", 0))])
		kv(summary, "Length", "%.0f m" % float(course_summary.get("length_total", 0.0)))
		var rating_row = kv(summary, "Rating · Slope", "%.1f · %.0f" % [float(course_summary.get("course_rating", 0.0)), float(course_summary.get("slope", 0.0))])
		rating_row.tooltip_text = "Course rating is the expected scratch score. Slope compares difficulty for bogey golfers."
		var signature: Dictionary = course_summary.get("signature_hole", {})
		if not signature.is_empty():
			kv(summary, "Signature hole", str(signature.get("name", "Hole")))
		var mix_note: String = str(course_summary.get("par_mix_note", ""))
		if not mix_note.is_empty():
			note(mix_note, ACCENT, summary)
		var routing: Dictionary = course_summary.get("routing", {})
		if int(routing.get("long_transfers", 0)) > 0:
			note(str(routing.get("note", "Long walks between holes.")), ACCENT, summary)
			var jump_row = actions(summary)
			for warning_value in routing.get("warnings", []):
				var warning: Dictionary = warning_value
				var from_id: int = int(warning.get("from_hole", -1))
				small_button("Hole %d walk" % from_id, func() -> void:
					game.select_hole(from_id)
					game.jump_to({"pos": game.selected_hole.get("tee", Vector3.ZERO), "target": {"kind": "hole", "id": from_id}})
				, jump_row)
	var new_hole = primary("+  Design a new hole", func(): game.set_tool("hole_tee"))
	new_hole.tooltip_text = "Click a tee location, then the cup. Tee and green surfaces are included in the cost."
	section("Holes")
	var weakest_fun: float = INF
	var weakest_id: int = -1
	for i in range(game.terrain.holes.size()):
		var hole = game.terrain.holes[i]
		var id = hole.id
		var fun_value: float = _hole_metric(id, "fun")
		if fun_value >= 0.0 and fun_value < weakest_fun:
			weakest_fun = fun_value
			weakest_id = id
		var yards = roundi(hole.tee.distance_to(hole.cup) * 1.09361)
		var badge: String = ""
		var badge_color: Color = MUTED
		if not hole.open:
			badge = "Closed"
			badge_color = ACCENT
		elif fun_value >= 0.0:
			badge = "Fun %.2f" % fun_value
			badge_color = OK if fun_value >= 0.55 else MUTED
		var selected: bool = not game.selected_hole.is_empty() and int(game.selected_hole.get("id", -1)) == int(id)
		list_item("%02d   %s" % [i + 1, hole.name], "Par %d  ·  %d yd" % [hole.par, yards], func(): game.select_hole(id), badge, badge_color, null, selected)
	if game.terrain.holes.is_empty():
		note("No holes yet. Design one to open the course.")
	if weakest_id >= 0:
		note("Weakest fun on hole %d. Tune hazards or add a decision line." % weakest_id, ACCENT)

func _hole_inspector() -> void:
	var hole = game.selected_hole
	var hole_id: int = int(hole.get("id", -1))
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	body.add_child(title_row)
	var name_edit = LineEdit.new()
	name_edit.text = hole.name
	name_edit.placeholder_text = "Hole name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 17)
	name_edit.tooltip_text = "Press Enter to rename"
	name_edit.text_submitted.connect(func(v): game.edit_hole_value("name", v))
	title_row.add_child(name_edit)
	var par = OptionButton.new()
	for value in [3, 4, 5]: par.add_item("Par %d" % value, value)
	par.select(clampi(int(hole.par) - 3, 0, 2))
	par.item_selected.connect(func(i): game.edit_hole_value("par", i + 3))
	title_row.add_child(par)
	more_menu(title_row, [
		["Reopen hole" if not hole.open else "Close for maintenance", func(): game.edit_hole_value("open", not hole.open)],
		["Move earlier in round", func(): game.reorder_hole(-1)],
		["Move later in round", func(): game.reorder_hole(1)],
		["Clear waypoints", func(): game.edit_hole_value("waypoints", [])],
		["Remove this hole", func(): game.remove_hole()],
	])
	var reason = game.terrain.hole_valid(hole)
	var facts = card()
	var status_row = HBoxContainer.new()
	facts.add_child(status_row)
	var status_text: String = "Ready for play" if reason.is_empty() else reason
	if not hole.open and reason.is_empty():
		status_text = "Closed for maintenance"
	var status = label(status_text, 13, OK if reason.is_empty() and hole.open else ACCENT)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status)
	kv(facts, "Length", "%d yd" % roundi(hole.tee.distance_to(hole.cup) * 1.09361))
	var area: float = game.terrain.green_area(hole) if game.terrain.has_method("green_area") else 0.0
	if area > 0.0:
		var slope_stats: Dictionary = game.terrain.green_slope_stats(hole) if game.terrain.has_method("green_slope_stats") else {}
		kv(facts, "Green", "%.0f m²  ·  slope %.1f%% (max %.1f%%)" % [area, float(slope_stats.get("mean", 0.0)) * 100.0, float(slope_stats.get("max", 0.0)) * 100.0])
	var hole_stats: Dictionary = game.terrain.hole_condition(hole) if game.terrain.has_method("hole_condition") else {}
	if not hole_stats.is_empty():
		var total: float = 0.0
		var parts: Array[String] = []
		for key in ["green", "fairway", "tee", "bunkers"]:
			var value: float = float(hole_stats.get(key, 1.0))
			total += value
			parts.append("%s %.0f%%" % [key.capitalize(), value * 100.0])
		var avg: float = total / 4.0
		var cond = kv(facts, "Condition", _percent(avg), OK if avg >= 0.7 else ACCENT)
		cond.tooltip_text = "  ·  ".join(parts)
	var disconnected: PackedInt32Array = game.terrain.disconnected_green_paint(hole) if game.terrain.has_method("disconnected_green_paint") else PackedInt32Array()
	if disconnected.size() > 0:
		note("%d painted green cells are disconnected from the cup and ignored by play." % disconnected.size(), ACCENT, facts)
	section("Layout")
	var layout = actions()
	_tool_button("Move tee", "edit_tee", layout)
	_tool_button("Move cup", "edit_cup", layout)
	_tool_button("Waypoint", "waypoint", layout)
	var green_row = HBoxContainer.new()
	green_row.add_theme_constant_override("separation", 6)
	body.add_child(green_row)
	var green_caption = label("Green radius", 13, MUTED)
	green_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	green_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	green_row.add_child(green_caption)
	var green_size = SpinBox.new()
	green_size.min_value = 8
	green_size.max_value = 40
	green_size.step = 2
	green_size.value = hole.green_radius
	green_size.suffix = "m"
	green_size.custom_minimum_size.x = 86
	green_row.add_child(green_size)
	small_button("Apply", func(): game.resize_green(green_size.value), green_row)
	section("Tees & pins")
	var tee_boxes: Array = hole.get("tees", [])
	var pins: Array = hole.get("pins", [])
	var tees_card = card()
	var tee_row = HBoxContainer.new()
	tee_row.add_theme_constant_override("separation", 6)
	tees_card.add_child(tee_row)
	var tee_caption = label("Tees", 13, MUTED)
	tee_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tee_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tee_row.add_child(tee_caption)
	tee_row.add_child(chip("main", INK, PAPER))
	for tee_entry in tee_boxes:
		var tee_name: String = str(tee_entry.get("name", "tee"))
		var remove = small_button("%s ×" % tee_name, func(): game.remove_tee(tee_name), tee_row)
		remove.tooltip_text = "Remove the %s tee" % tee_name
	if game.sim.sandbox or game.sim.can_build("tool:multi_tee"):
		var add_row = actions(tees_card)
		for tee_name in ["forward", "back"]:
			var tee_label: String = tee_name
			if tee_boxes.any(func(entry: Dictionary) -> bool: return str(entry.get("name", "")) == tee_label):
				continue
			small_button("+ %s tee at cursor" % tee_label, func(): game.add_tee_box(game.cursor_point if game._inside(game.cursor_point) else hole.tee, tee_label), add_row)
	else:
		note("Extra tee boxes unlock through the Progress tree.", MUTED, tees_card)
	var pin_row = HBoxContainer.new()
	pin_row.add_theme_constant_override("separation", 6)
	tees_card.add_child(pin_row)
	var pin_caption = label("Pins  ·  %d%s" % [pins.size(), ("  ·  active %d" % (int(hole.get("pin_index", 0)) + 1)) if pins.size() > 0 else ""], 13, MUTED)
	pin_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pin_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pin_row.add_child(pin_caption)
	_tool_button("+ Pin", "add_pin", pin_row, true)
	if pins.size() > 0:
		small_button("Remove last", func(): game.remove_pin(pins.size() - 1), pin_row)
	section("Upkeep")
	var gk_assign: OptionButton = OptionButton.new()
	gk_assign.add_item("Groundskeeper: automatic", -1)
	for worker in game.sim.staff:
		if str(worker.get("role", "")) == "groundskeeper":
			gk_assign.add_item("Groundskeeper: %s" % worker.get("name", "Groundskeeper"), int(worker.get("id", -1)))
	var assigned_worker_id: int = -1
	for worker in game.sim.staff:
		var assignment: Variant = worker.get("assignment", -1)
		if assignment is Dictionary and str(assignment.get("kind", "")) == "hole" and int(assignment.get("id", -1)) == hole_id:
			assigned_worker_id = int(worker.get("id", -1))
	for index in range(gk_assign.item_count):
		if gk_assign.get_item_id(index) == assigned_worker_id:
			gk_assign.select(index)
	gk_assign.item_selected.connect(func(selected_index: int) -> void:
		var worker_id: int = gk_assign.get_item_id(selected_index)
		for worker in game.sim.staff:
			if str(worker.get("role", "")) != "groundskeeper":
				continue
			var assignment: Variant = worker.get("assignment", -1)
			if assignment is Dictionary and str(assignment.get("kind", "")) == "hole" and int(assignment.get("id", -1)) == hole_id and int(worker.get("id", -1)) != worker_id:
				game.sim.assign_staff(int(worker.get("id", -1)), -1)
		if worker_id >= 0:
			game.sim.assign_staff(worker_id, {"kind": "hole", "id": hole_id})
	)
	body.add_child(gk_assign)
	section("Shot lab")
	var lab_row = actions()
	var analyze = primary("▶  Analyze  ·  30 rounds per skill", func(): game.analyze_hole(), lab_row)
	analyze.tooltip_text = "Simulates beginner, intermediate, and expert rounds and draws their trajectories."
	if not game.analysis_results.is_empty() or not game.analysis_filter.is_empty():
		small_button("Clear", func(): game.clear_analysis(); refresh_view(), lab_row)
	var report_metrics: Dictionary = game.analysis_metrics
	if report_metrics.is_empty():
		var cached: Dictionary = game.sim.hole_metrics.get(hole_id, {})
		report_metrics = cached.get("metrics", {})
	if not report_metrics.is_empty():
		var report = card()
		report.add_child(label("Design report card", 11, MUTED))
		for entry in [
			["Fun", "fun", ""],
			["Difficulty", "difficulty", ""],
			["Fairness", "fairness", "fairness"],
			["Decision", "decision", "decision"],
			["Variety", "variety", ""],
			["Hazard rate", "hazard_rate", "hazard_rate"],
			["Blow-up rate", "blowup_rate", "blowup_rate"],
			["Spread", "spread", ""],
			["Green hold", "green_receptiveness", "green_receptiveness"],
			["Pace (4-ball)", "pace_minutes", ""],
			["Scenery", "scenery", ""],
		]:
			var metric: Dictionary = report_metrics.get(entry[1], {})
			if metric.is_empty():
				continue
			var band: String = str(metric.get("band", "ok"))
			var band_color: Color = INK if band == "ok" else ACCENT
			var filter_id: String = str(entry[2])
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			report.add_child(row)
			if filter_id.is_empty():
				var k = label(str(entry[0]), 13, MUTED)
				k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(k)
			else:
				var link = Button.new()
				link.text = str(entry[0])
				link.flat = true
				link.alignment = HORIZONTAL_ALIGNMENT_LEFT
				link.add_theme_font_size_override("font_size", 13)
				link.add_theme_color_override("font_color", INK if game.analysis_filter != filter_id else ACCENT)
				link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				link.tooltip_text = "Show the shots behind this metric"
				link.pressed.connect(func() -> void: game.show_metric_shots(filter_id))
				row.add_child(link)
			var v = label("%.2f" % float(metric.get("value", 0.0)), 13, band_color)
			v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			v.tooltip_text = str(metric.get("note", ""))
			row.add_child(v)
			if band != "ok":
				note(str(metric.get("note", "")), ACCENT, report)
	if not game.analysis_results.is_empty():
		var results = card()
		for result in game.analysis_results:
			kv(results, str(result.label), "%.1f strokes  ·  %.0f%% hazards" % [result.average, result.hazard_rate * 100])
		if game.analysis_filter.is_empty():
			note("Blue beginner · Gold intermediate · Coral expert. Dots are landing samples.", MUTED, results)
		else:
			note("Filtered: %s. Clear to reset." % game.analysis_filter.replace("_", " "), MUTED, results)

func _tool_button(text: String, mode: String, parent: Node, small: bool = false) -> Button:
	var b: Button
	if small:
		b = small_button(text, func(): game.set_tool(mode); refresh_view(), parent)
	else:
		b = button(text, func(): game.set_tool(mode); refresh_view(), parent)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark_active_tool(b, mode)
	return b

# ---------------------------------------------------------------- build

func _build_panel_view() -> void:
	heading("A place worth visiting.")
	section("Facilities")
	for def in Catalog.buildings(): _catalog_button(def)
	section("Paths & bridges")
	for pair in [["Gravel path  ·  $8/m", "path_gravel"], ["Shared cart path  ·  $16/m", "path_paved"], ["Footbridge  ·  $90/m", "bridge_walk"], ["Cart bridge  ·  $150/m", "bridge_cart"]]:
		var kind = pair[1]
		var b = button(pair[0], func(): game.place_kind = kind; game.set_tool("path"); refresh_view())
		b.tooltip_text = "Two clicks: start, then end. Bridge ends must meet dry land."
		if game.tool == "path" and game.place_kind == kind:
			b.add_theme_stylebox_override("normal", box(CARD_ACTIVE, 8, 10))
	section("Course stakes")
	var stakes = actions()
	var ob = _tool_button("White OB  ·  $12/m", "ob_stakes", stakes)
	ob.tooltip_text = "Out of bounds: stroke and distance."
	var pen = _tool_button("Red penalty  ·  $12/m", "penalty_stakes", stakes)
	pen.tooltip_text = "Penalty area: one stroke and a drop."
	section("Scenery")
	for set_id in ["woodland", "garden", "resort"]:
		var items: Array = []
		for def in Catalog.scenery():
			if def.set == set_id:
				items.append(def)
		var expanded: bool = bool(_expanded_sets.get(set_id, false))
		var toggle = button("%s  %s collection  ·  %d" % ["▾" if expanded else "▸", set_id.capitalize(), items.size()], func():
			_expanded_sets[set_id] = not expanded
			refresh_view()
		)
		toggle.add_theme_stylebox_override("normal", box(CARD, 8, 10))
		toggle.tooltip_text = "Same-set pieces placed near each other amplify local beauty."
		if expanded:
			for def in items: _catalog_button(def)

func _catalog_button(def: Dictionary) -> void:
	var kind = def.id
	var locked = not game.sim.sandbox and not game.sim.can_build(kind)
	var gate: Dictionary = Catalog.unlock_for(kind)
	var b = button("%s%s\n$%s  ·  %s" % ["○  " if locked else "+  ", def.name, format_money(def.cost), "Locked" if locked else "$%s/day" % format_money(def.upkeep)], func(): game.place_kind = kind; game.set_tool("place"); refresh_view())
	b.disabled = locked
	if locked and not gate.is_empty():
		b.tooltip_text = "Unlock via %s in the Progress tree" % gate.get("name", kind)
	elif def.has("beauty"):
		b.tooltip_text = "%s set · %d beauty · %dm influence" % [def.set, def.beauty, def.influence]
	if game.tool == "place" and game.place_kind == kind:
		b.add_theme_stylebox_override("normal", box(CARD_ACTIVE, 8, 10))

func _object_inspector() -> void:
	var obj = game.selected_object
	var def = Catalog.find(obj.kind)
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	body.add_child(title_row)
	var title = label(def.get("name", obj.kind.replace("_", " ")), 19, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_row.add_child(title)
	var facility_info: Dictionary = {}
	for facility in game.sim.facility_status():
		if facility.id == obj.id:
			facility_info = facility
			break
	var menu_entries: Array = []
	if not facility_info.is_empty():
		menu_entries.append(["Reopen facility" if bool(facility_info.get("closed", false)) else "Close for today", func(): game.toggle_facility_closed(int(obj.id))])
	menu_entries.append(["Demolish  ·  25% salvage", func(): game.demolish_selected()])
	more_menu(title_row, menu_entries)
	var facts = card()
	kv(facts, "Condition", _percent(obj.condition), OK if obj.condition >= 0.6 else ACCENT)
	kv(facts, "Cleanliness", _percent(obj.cleanliness), OK if obj.cleanliness >= 0.6 else ACCENT)
	if not facility_info.is_empty():
		if bool(facility_info.get("closed", false)):
			note("Closed to guests. Skipped by routing and exempt from decay.", ACCENT, facts)
		kv(facts, "Level", str(int(facility_info.get("level", 1))))
		kv(facts, "Capacity", "%d  ·  %d queued" % [int(facility_info.get("capacity", 0)), int(facility_info.get("queue", 0))])
		var staffed: bool = bool(facility_info.get("staffed", false))
		kv(facts, "Staff", "%d  ·  %s" % [int(facility_info.get("workers", 0)), "Staffed" if staffed else "Unstaffed"], INK if staffed else ACCENT)
		kv(facts, "Today", "$%s  ·  %d visits" % [format_money(float(facility_info.get("revenue_today", 0.0))), int(facility_info.get("visits_today", 0))])
		var upgrade: Dictionary = Catalog.facility_upgrade(str(obj.kind), int(facility_info.get("level", 1)))
		if not upgrade.is_empty():
			var grade_locked: bool = upgrade.has("grade") and not game.sim.sandbox and game.sim.grade < int(upgrade.get("grade", 1))
			var upgrade_button: Button = primary("Upgrade to %s  ·  $%s" % [str(upgrade.get("name", "next tier")), format_money(float(upgrade.get("cost", 0.0)))], func(): game.upgrade_object(int(obj.id)))
			upgrade_button.disabled = grade_locked
			if grade_locked:
				upgrade_button.tooltip_text = "Requires resort grade %d" % int(upgrade.get("grade", 1))
	elif def.has("beauty"):
		var beauty = kv(facts, "Local beauty", "%.0f / 100" % game.terrain.beauty_at(obj.pos))
		beauty.tooltip_text = "Same-set combinations amplify nearby scenery."
	var row = actions()
	_tool_button("Relocate", "move_object", row)
	var rotate = button("Rotate 90°", func(): game.rotate_selected(), row)
	rotate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate.alignment = HORIZONTAL_ALIGNMENT_CENTER

# ---------------------------------------------------------------- guests

func _waiting_count() -> int:
	var total: int = 0
	for group in game.sim.groups:
		var state: String = str(group.get("state", ""))
		if state.ends_with("_queue"):
			total += int(group.get("size", (group.get("members", []) as Array).size()))
	return total

func _guests_panel() -> void:
	heading("Good days, one guest at a time.")
	var now = card()
	kv(now, "On site", "%d golfers" % game.sim.guests.size(), INK, 14)
	var waiting: int = _waiting_count()
	kv(now, "Waiting in queues", str(waiting), ACCENT if waiting > 4 else INK)
	kv(now, "Satisfaction", _percent(game.sim.satisfaction))
	var today: Dictionary = game.sim.feedback_summary(1, game.sim.day)
	kv(now, "Today", "%.0f%% finished  ·  %.0f%% refunded" % [float(today.get("completion_rate", 0.0)) * 100.0, float(today.get("refund_rate", 0.0)) * 100.0])
	_guests_feedback_section()
	section("Visiting now")
	if game.sim.guests.is_empty():
		note("No one on the course right now.")
	var shown: int = 0
	var cap: int = 200 if _guest_list_expanded else 8
	for guest in game.sim.guests:
		if shown >= cap:
			break
		var id = guest.id
		var selected: bool = int(game.selected_guest_id) == int(id)
		list_item(str(guest.name), str(guest.activity).replace("_", " ").capitalize(), func(): game.select_guest(id), _mood_word(float(guest.get("mood", 0.5))), _mood_color(float(guest.get("mood", 0.5))), null, selected)
		shown += 1
	if game.sim.guests.size() > 8:
		small_button("Show all %d" % game.sim.guests.size() if not _guest_list_expanded else "Show fewer", func():
			_guest_list_expanded = not _guest_list_expanded
			refresh_view()
		)
	_guests_reviews_section()

func _feedback_end_day() -> int:
	return maxi(1, game.sim.day - 1)

func _feedback_line(entry: Dictionary) -> String:
	var tag: String = str(entry.get("tag", ""))
	var text: String = str(ResortSimulation.FEEDBACK_TEXT.get(tag, tag.replace("_", " ")))
	return "%s (%d guests)" % [text, int(entry.get("count", 0))]

func _mood_word(mood: float) -> String:
	if mood >= 0.82:
		return "Delighted"
	if mood >= 0.68:
		return "Pleased"
	if mood >= 0.45:
		return "Neutral"
	if mood >= 0.3:
		return "Disappointed"
	return "Upset"

func _mood_color(mood: float) -> Color:
	if mood >= 0.68:
		return OK
	if mood >= 0.45:
		return MUTED
	return ACCENT

func _guests_feedback_section() -> void:
	section("What guests are saying")
	segmented(null, [["Last month", 1], ["Last 3 months", 3]], _feedback_range_days, func(v): _feedback_range_days = int(v); refresh_view())
	var end_day: int = _feedback_end_day()
	var summary: Dictionary = game.sim.feedback_summary(_feedback_range_days, end_day)
	var complaints: Array = summary.get("top_complaints", [])
	var praise: Array = summary.get("top_praise", [])
	var feedback = card()
	if complaints.is_empty() and praise.is_empty():
		note("Guest feedback appears after the first full day.", MUTED, feedback)
		return
	for entry in complaints:
		var tag: String = str(entry.get("tag", ""))
		kv(feedback, "▼ " + str(ResortSimulation.FEEDBACK_TEXT.get(tag, tag.replace("_", " "))), str(int(entry.get("count", 0))), ACCENT)
	for entry in praise:
		var tag: String = str(entry.get("tag", ""))
		kv(feedback, "▲ " + str(ResortSimulation.FEEDBACK_TEXT.get(tag, tag.replace("_", " "))), str(int(entry.get("count", 0))), OK)

func _guests_reviews_section() -> void:
	section("Recent reviews")
	var recent: Array = game.sim.reviews
	if recent.is_empty():
		note("No guest reviews yet.")
		return
	var count: int = 30 if _reviews_expanded else 5
	var start_index: int = maxi(0, recent.size() - count)
	for index in range(recent.size() - 1, start_index - 1, -1):
		var review: Dictionary = recent[index]
		var guest_id: int = int(review.get("guest_id", -1))
		var live: bool = false
		for guest in game.sim.guests:
			if int(guest.get("id", -1)) == guest_id:
				live = true
				break
		var mood: float = float(review.get("mood", 0.5))
		var title: String = "“%s”" % str(review.get("headline", ""))
		var meta: String = "%s  ·  spent $%s" % [str(review.get("guest_name", "Guest")), format_money(float(review.get("spent", 0.0)))]
		var on_click: Callable = (func(): game.select_guest(guest_id)) if live else Callable(func(): pass)
		list_item(title, meta, on_click, _mood_word(mood), _mood_color(mood))
	if recent.size() > 5:
		small_button("Show more reviews" if not _reviews_expanded else "Show fewer", func():
			_reviews_expanded = not _reviews_expanded
			refresh_view()
		)

func _find_guest(id: int) -> Dictionary:
	for guest in game.sim.guests:
		if int(guest.get("id", -1)) == id:
			return guest
	return {}

func _guest_inspector() -> void:
	var guest: Dictionary = _find_guest(int(game.selected_guest_id))
	if guest.is_empty():
		note("This guest has left the resort.")
		return
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	body.add_child(title_row)
	var title = label(str(guest.name), 19, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var follow = small_button("● Following" if game.follow_selected else "Follow", func():
		game.follow_selected = not game.follow_selected
		refresh_view()
	, title_row)
	follow.tooltip_text = "Keep the camera with this guest"
	_live["activity"] = copy(str(guest.activity).replace("_", " ").capitalize(), 13, MUTED)
	var patron_line: String = game.sim.guest_patron_line(guest)
	var group_size: int = 1
	for group in game.sim.groups:
		if int(group.get("id", -2)) == int(guest.get("group_id", -1)):
			group_size = maxi(1, int(group.get("size", (group.get("members", []) as Array).size())))
	var who = card()
	if group_size > 1:
		kv(who, "Party", "playing with %d other%s" % [group_size - 1, "" if group_size == 2 else "s"])
	if not patron_line.is_empty():
		kv(who, "History", patron_line)
	kv(who, "Skill", _percent(guest.skill))
	_live["mood"] = kv(who, "Mood", _mood_word(guest.mood), _mood_color(guest.mood))
	_live["budget"] = kv(who, "Budget", "$%s  ·  spent $%s" % [format_money(guest.budget), format_money(guest.spent)])
	section("Needs")
	var needs = card()
	_live["energy"] = kv(needs, "Energy", _percent(guest.energy))
	_live["hunger"] = kv(needs, "Hunger", _percent(guest.hunger))
	_live["restroom"] = kv(needs, "Restroom", _percent(guest.restroom))
	section("Round")
	var round_card = card()
	_live["hole"] = kv(round_card, "Playing", "Hole %d  ·  %d strokes" % [int(guest.hole_index) + 1, int(guest.strokes)])
	_live["scorecard"] = kv(round_card, "Scorecard", _scorecard_text(guest.scorecard))
	_live["thought"] = note("“%s”" % str(guest.thought), INK, round_card)

func _scorecard_text(scorecard: Variant) -> String:
	if not (scorecard is Array) or (scorecard as Array).is_empty():
		return "—"
	var parts: Array[String] = []
	for value in scorecard:
		parts.append(str(value))
	return " ".join(parts)

func _refresh_guest_live() -> void:
	var guest: Dictionary = _find_guest(int(game.selected_guest_id))
	if guest.is_empty():
		return
	if _live.has("activity"): _live["activity"].text = str(guest.activity).replace("_", " ").capitalize()
	if _live.has("mood"):
		_live["mood"].text = _mood_word(guest.mood)
		_live["mood"].add_theme_color_override("font_color", _mood_color(guest.mood))
	if _live.has("budget"): _live["budget"].text = "$%s  ·  spent $%s" % [format_money(guest.budget), format_money(guest.spent)]
	if _live.has("energy"): _live["energy"].text = _percent(guest.energy)
	if _live.has("hunger"): _live["hunger"].text = _percent(guest.hunger)
	if _live.has("restroom"): _live["restroom"].text = _percent(guest.restroom)
	if _live.has("hole"): _live["hole"].text = "Hole %d  ·  %d strokes" % [int(guest.hole_index) + 1, int(guest.strokes)]
	if _live.has("scorecard"): _live["scorecard"].text = _scorecard_text(guest.scorecard)
	if _live.has("thought"): _live["thought"].text = "“%s”" % str(guest.thought)

# ---------------------------------------------------------------- staff

func _staff_panel() -> void:
	heading("A well-kept course takes a team.")
	var monthly_wages: float = 0.0
	var raise_count: int = 0
	for worker in game.sim.staff:
		monthly_wages += float(worker.get("wage", 0.0))
		if bool(worker.get("raise_requested", false)):
			raise_count += 1
	var payroll = card()
	kv(payroll, "Team", "%d people" % game.sim.staff.size(), INK, 14)
	kv(payroll, "Monthly payroll", "$%s" % format_money(monthly_wages))
	if raise_count > 0:
		kv(payroll, "Raise requests", str(raise_count), ACCENT)
	section("Applicants")
	if game.sim.candidates.is_empty():
		note("No applicants today. New candidates arrive each morning.")
	for candidate in game.sim.candidates:
		var candidate_id: int = int(candidate.get("id", -1))
		var trait_text: String = ", ".join((candidate.get("traits", []) as Array).map(func(t): return str(t).replace("_", " ")))
		var applicant = card()
		var candidate_name: String = str(candidate.get("name", "Applicant"))
		var role_text: String = str(candidate.get("role", "")).replace("_", " ")
		applicant.add_child(label(candidate_name if candidate_name.to_lower().contains(role_text) else "%s  ·  %s" % [candidate_name, role_text], 14, INK))
		kv(applicant, "Skill", _percent(float(candidate.get("skill", 0.0))))
		kv(applicant, "Wage", "$%s / month" % format_money(float(candidate.get("wage", 0.0))))
		if not trait_text.is_empty():
			kv(applicant, "Traits", trait_text)
		var hire = button("Hire  ·  signing $%s" % format_money(float(candidate.get("wage", 0.0)) * 2.0), func():
			game.sim.hire(candidate_id)
			refresh_view()
		, applicant)
		hire.alignment = HORIZONTAL_ALIGNMENT_CENTER
	section("Your team")
	if game.sim.staff.is_empty():
		note("Nobody on payroll. Hire from the applicants above.")
	for worker in game.sim.staff:
		var id: int = int(worker.get("id", -1))
		var effective: float = game.sim._effective_skill(worker)
		var badge: String = "Raise?" if bool(worker.get("raise_requested", false)) else ""
		var selected: bool = int(game.selected_staff_id) == id
		list_item(
			"%s  ·  %s" % [worker.get("name", "Worker"), str(worker.get("role", "")).replace("_", " ")],
			"Skill %.0f%%  ·  Morale %.0f%%  ·  %s" % [effective * 100.0, float(worker.get("morale", 0.0)) * 100.0, str(worker.get("activity", "idle")).replace("_", " ")],
			func(): game.select_staff(id), badge, ACCENT, null, selected)

func _find_worker(id: int) -> Dictionary:
	for worker in game.sim.staff:
		if int(worker.get("id", -1)) == id:
			return worker
	return {}

func _staff_inspector() -> void:
	var worker: Dictionary = _find_worker(int(game.selected_staff_id))
	if worker.is_empty():
		note("This worker is no longer on staff.")
		return
	var id: int = int(worker.get("id", -1))
	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	body.add_child(title_row)
	var title = label(str(worker.get("name", "Worker")), 19, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	more_menu(title_row, [["Dismiss %s" % str(worker.get("name", "worker")), func(): game.sim.fire(id); game.clear_selection(); show_tab("Staff")]])
	copy(str(worker.get("role", "")).replace("_", " ").capitalize(), 13, MUTED)
	var facts = card()
	var effective: float = game.sim._effective_skill(worker)
	kv(facts, "Effective skill", _percent(effective), INK, 14)
	var morale: float = float(worker.get("morale", 0.0))
	kv(facts, "Morale", _percent(morale), OK if morale >= 0.6 else ACCENT)
	var fatigue: float = float(worker.get("fatigue", 0.0))
	kv(facts, "Fatigue", _percent(fatigue), ACCENT if fatigue >= 0.8 else INK)
	kv(facts, "Wage", "$%s / month" % format_money(float(worker.get("wage", 0.0))))
	_live["staff_activity"] = kv(facts, "Right now", str(worker.get("activity", "idle")).replace("_", " ").capitalize())
	if bool(worker.get("raise_requested", false)):
		var raise = primary("Accept raise request  ·  +12%", func():
			game.sim.grant_raise(id)
			refresh_view()
		)
		raise.add_theme_stylebox_override("normal", box(ACCENT, 8, 10))
	section("Schedule")
	var shifts = OptionButton.new()
	for shift_index in range(3):
		var shift_id: String = ["early", "late", "full"][shift_index]
		shifts.add_item(shift_id.capitalize() + " shift", shift_index)
		shifts.set_item_metadata(shift_index, shift_id)
		if str(worker.get("shift", "full")) == shift_id:
			shifts.select(shift_index)
	shifts.item_selected.connect(func(i): game.sim.set_shift(id, shifts.get_item_metadata(i)))
	body.add_child(shifts)
	var assignments = OptionButton.new()
	assignments.add_item("Automatic assignment", -1)
	assignments.set_item_metadata(0, -1)
	for hole in game.terrain.holes:
		var hole_index: int = assignments.item_count
		assignments.add_item("Hole: %s" % hole.get("name", "Hole"), int(hole.get("id", -1)))
		assignments.set_item_metadata(hole_index, {"kind": "hole", "id": int(hole.get("id", -1))})
	for obj in game.terrain.objects:
		if Catalog.find(obj.kind).has("capacity"):
			var object_index: int = assignments.item_count
			assignments.add_item("%s #%d" % [obj.kind.replace("_", " "), obj.id], obj.id)
			assignments.set_item_metadata(object_index, {"kind": "object", "id": int(obj.id)})
	for i in range(assignments.item_count):
		var metadata: Variant = assignments.get_item_metadata(i)
		var assignment: Variant = worker.get("assignment", -1)
		var matches: bool = false
		if metadata is int and int(metadata) == -1:
			matches = assignment == -1
		elif metadata is Dictionary and assignment is Dictionary:
			matches = str(metadata.get("kind", "")) == str(assignment.get("kind", "")) and int(metadata.get("id", -2)) == int(assignment.get("id", -1))
		elif metadata is Dictionary and assignment is int and int(assignment) >= 0:
			matches = str(metadata.get("kind", "")) == "object" and int(metadata.get("id", -1)) == int(assignment)
		if matches:
			assignments.select(i)
	assignments.item_selected.connect(func(i): game.sim.assign_staff(id, assignments.get_item_metadata(i)))
	body.add_child(assignments)
	var courses: Array = []
	for course in Catalog.training():
		if str(course.get("role", "")) == str(worker.get("role", "")):
			courses.append(course)
	if not courses.is_empty():
		section("Training")
		for course in courses:
			var course_id: String = str(course.get("id", ""))
			button("%s  ·  $%s" % [course.get("name", course_id), format_money(float(course.get("cost", 0.0)))], func():
				game.sim.train(id, course_id)
				refresh_view())

func _refresh_staff_live() -> void:
	var worker: Dictionary = _find_worker(int(game.selected_staff_id))
	if worker.is_empty():
		return
	if _live.has("staff_activity"):
		_live["staff_activity"].text = str(worker.get("activity", "idle")).replace("_", " ").capitalize()

# ---------------------------------------------------------------- money

func _debt_total() -> float:
	var debt = 0.0
	for loan in game.sim.loans: debt += float(loan.get("balance", 0))
	return debt

func _days_to_settlement() -> int:
	return ResortSimulation.DAYS_PER_MONTH - int(game.sim.day_of_month()) + 1

func _money_panel() -> void:
	heading("Keep the good days growing.")
	var summary: Dictionary = game.sim.pricing_summary()
	var overview = card()
	var month_net: float = float(game.sim._today_revenue) - float(game.sim._today_expense)
	kv(overview, "This month so far", "%s$%s" % ["+" if month_net >= 0 else "−", format_money(absf(month_net))], OK if month_net >= 0 else ACCENT, 14)
	kv(overview, "Settlement", "in %d day%s" % [_days_to_settlement(), "" if _days_to_settlement() == 1 else "s"]).tooltip_text = "Wages, upkeep, and loan payments settle at month end."
	var debt: float = _debt_total()
	if debt > 0.0:
		kv(overview, "Debt", "$%s" % format_money(debt), ACCENT)
	kv(overview, "Revenue per visitor", "$%s" % format_money(float(summary.get("revenue_per_visitor", 0.0))))
	var balked: int = int(summary.get("balked_today", 0))
	kv(overview, "Balked at prices today", str(balked), ACCENT if balked > 0 else INK)
	segmented(null, [["Prices", "prices"], ["Members", "members"], ["Loans", "loans"], ["Ledger", "ledger"]], _money_view, func(v): _money_view = str(v); refresh_view())
	match _money_view:
		"prices": _money_prices_section(summary)
		"members": _money_members_section()
		"loans": _money_loans_section()
		"ledger": _money_ledger_section()

func _price_row(parent: Node, caption: String, suggested: float, key: String, field: String, value: float, max_value: float) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var text_col = VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)
	text_col.add_child(label(caption, 13, INK))
	if suggested > 0.0:
		var hint = label("suggested $%s" % format_money(suggested), 11, MUTED)
		hint.tooltip_text = "Heuristic from grade and guest rating"
		text_col.add_child(hint)
	var edit: SpinBox = SpinBox.new()
	edit.min_value = 0
	edit.max_value = max_value
	edit.step = 1
	edit.value = value
	edit.prefix = "$"
	edit.custom_minimum_size.x = 96
	edit.value_changed.connect(func(v: float) -> void: game.sim.set_price_field(key, field, v))
	row.add_child(edit)
	if not price_edits.has(key):
		price_edits[key] = {}
	price_edits[key][field] = edit

func _money_prices_section(summary: Dictionary) -> void:
	section("Prices")
	var prices = card()
	for row_data in summary.get("rows", []):
		var key: String = str(row_data.get("key", ""))
		var max_value: float = 400.0 if key == "room" else 250.0
		var suggested: float = float(row_data.get("suggested", 0.0))
		if key == "green_fee":
			_price_row(prices, "Green fee", suggested, key, "base", float(row_data.get("base", 0.0)), max_value)
			_price_row(prices, "    Twilight", 0.0, key, "twilight", float(row_data.get("twilight", row_data.get("base", 0.0))), max_value)
			_price_row(prices, "    Weekend", 0.0, key, "weekend", float(row_data.get("weekend", row_data.get("base", 0.0))), max_value)
		else:
			_price_row(prices, str(row_data.get("label", key)), suggested, key, "base", float(row_data.get("base", 0.0)), max_value)
	section("Discounts")
	var discounts = card()
	for entry in [["Group of 4", "group_discount", 0.10, ""], ["Member (social tier)", "member_discount", 0.15, "Applies when membership tiers are active"]]:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		discounts.add_child(row)
		var caption = label(str(entry[0]), 13, INK)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(caption)
		var edit = SpinBox.new()
		edit.min_value = 0
		edit.max_value = 50
		edit.step = 1
		edit.suffix = "%"
		var price_key: String = str(entry[1])
		edit.value = round(float(summary.get(price_key, entry[2])) * 100.0)
		edit.custom_minimum_size.x = 96
		if not str(entry[3]).is_empty():
			edit.tooltip_text = str(entry[3])
		edit.value_changed.connect(func(v: float) -> void: game.sim.prices[price_key] = v / 100.0)
		row.add_child(edit)
	var bundle_toggle = CheckBox.new()
	bundle_toggle.text = "Cart included with weekend fee"
	bundle_toggle.add_theme_font_size_override("font_size", 13)
	bundle_toggle.button_pressed = bool(summary.get("bundle_weekend_cart", false))
	bundle_toggle.toggled.connect(func(on: bool) -> void: game.sim.prices["bundle_weekend_cart"] = on)
	discounts.add_child(bundle_toggle)
	note("Prices shape demand and guest value. Suggested prices follow your grade and rating.")

func _money_members_section() -> void:
	var summary: Dictionary = game.sim.patron_summary()
	section("Members")
	var overview = card()
	kv(overview, "Members", "%d of %d patrons on file" % [int(summary.get("members_total", 0)), int(summary.get("total_patrons", 0))], INK, 14)
	kv(overview, "Monthly dues", "$%s" % format_money(float(summary.get("monthly_dues_income", 0.0))))
	var churn: int = int(summary.get("churn_30", 0))
	kv(overview, "Left in last 30 days", str(churn), ACCENT if churn > 0 else INK)
	var counts: Dictionary = summary.get("member_counts", {})
	var caps: Dictionary = summary.get("caps", {})
	for tier in Catalog.memberships():
		var tier_id: String = str(tier.get("id", ""))
		var tier_card = card()
		var top = HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		tier_card.add_child(top)
		var caption: Label = label("%s  ·  %d / %d" % [tier.get("name", tier_id), int(counts.get(tier_id, 0)), int(caps.get(tier_id, 0))], 14)
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(caption)
		var open_toggle: CheckBox = CheckBox.new()
		open_toggle.text = "Open"
		open_toggle.add_theme_font_size_override("font_size", 12)
		open_toggle.button_pressed = bool(summary.get("open", {}).get(tier_id, true))
		open_toggle.toggled.connect(func(on: bool) -> void: game.sim.membership_open[tier_id] = on)
		top.add_child(open_toggle)
		var dues_row = HBoxContainer.new()
		dues_row.add_theme_constant_override("separation", 8)
		tier_card.add_child(dues_row)
		var dues_caption = label("Dues every 30 days", 12, MUTED)
		dues_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dues_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dues_row.add_child(dues_caption)
		var dues_edit: SpinBox = SpinBox.new()
		dues_edit.min_value = 0
		dues_edit.max_value = 5000
		dues_edit.step = 10
		dues_edit.prefix = "$"
		dues_edit.value = float(summary.get("dues", {}).get(tier_id, tier.get("dues", 0.0)))
		dues_edit.custom_minimum_size.x = 96
		dues_edit.value_changed.connect(func(v: float) -> void: game.sim.membership_dues[tier_id] = v)
		dues_row.add_child(dues_edit)
	note("Returning guests build affinity over time. Members book independently of walk-in demand.")

func _money_loans_section() -> void:
	section("Outstanding")
	if game.sim.loans.is_empty():
		note("No debt. Nicely done.")
	for loan in game.sim.loans:
		var id = loan.get("id", -1)
		var loan_card = card()
		kv(loan_card, str(loan.get("name", loan.get("product", "Loan"))), "$%s" % format_money(loan.get("balance", 0)), ACCENT, 14)
		var row = actions(loan_card)
		for amount in [1000, 5000]:
			var value: int = amount
			small_button("Repay $%s" % format_money(value), func(): game.notify(game.sim.repay(id, value)); refresh_view(), row)
	section("Finance options")
	for def in Catalog.loans():
		var id = def.id
		var offer = card()
		kv(offer, str(def.name), "$%s" % format_money(def.principal), INK, 14)
		kv(offer, "Terms", "%.1f%% monthly  ·  %d months  ·  $%s / month + interest" % [def.interest * 100, def.term_days, format_money(def.payment)])
		var apply = button("Apply", func(): game.notify(game.sim.borrow(id)); refresh_view(), offer)
		apply.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if int(def.min_grade) > int(game.sim.grade) and not game.sim.sandbox:
			apply.disabled = true
			apply.tooltip_text = "Requires resort grade %d" % int(def.min_grade)
	var recovery = button("Request one-time recovery loan", func(): game.notify(game.sim.borrow("recovery")); refresh_view())
	recovery.tooltip_text = "Emergency funding when the resort cannot cover its bills."

func _money_ledger_section() -> void:
	section("Recent transactions")
	var ledger_card = card()
	var count = game.sim.ledger.size()
	if count == 0:
		note("No transactions yet.", MUTED, ledger_card)
	var last_day: int = -1
	for i in range(count - 1, maxi(-1, count - 31), -1):
		var item = game.sim.ledger[i]
		var day: int = int(item.get("day", 1))
		if day != last_day:
			last_day = day
			var day_label_item = label(game.sim.date_string_for(day).to_upper(), 10, MUTED)
			ledger_card.add_child(day_label_item)
		var amount: float = float(item.get("amount", 0))
		kv(ledger_card, str(item.get("description", item.get("category", ""))), "%s$%s" % ["+" if amount >= 0 else "−", format_money(absf(amount))], OK if amount >= 0 else INK, 12)
	small_button("Open reports", func(): show_tab("Reports"))

# ---------------------------------------------------------------- reputation

func _reputation_panel() -> void:
	heading("Spread the word and earn your stars.")
	segmented(null, [["Reputation", "reputation"], ["Campaigns", "campaigns"], ["Events", "events"]], _reputation_view, func(v): _reputation_view = str(v); refresh_view())
	match _reputation_view:
		"reputation": _reputation_overview()
		"campaigns": _reputation_campaigns()
		"events": _reputation_events()

func _reputation_overview() -> void:
	var breakdown: Dictionary = game.sim.rating_breakdown()
	var stars = card()
	var star_row = HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 10)
	stars.add_child(star_row)
	var big = label("★ %.1f" % float(breakdown.get("stars", 3.0)), 26, INK)
	star_row.add_child(big)
	var forecast: Dictionary = game.sim.forecast_arrivals()
	var forecast_col = VBoxContainer.new()
	forecast_col.add_theme_constant_override("separation", 0)
	forecast_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	forecast_col.alignment = BoxContainer.ALIGNMENT_END
	star_row.add_child(forecast_col)
	var forecast_label_item = label("%d–%d expected tomorrow" % [int(forecast.get("low", 0)), int(forecast.get("high", 0))], 12, MUTED)
	forecast_label_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forecast_col.add_child(forecast_label_item)
	for family in ["course", "facilities", "service", "value", "scenery"]:
		var value: float = float(breakdown.get(family, 3.0))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stars.add_child(row)
		var k = label(family.capitalize(), 13, MUTED)
		k.custom_minimum_size.x = 80
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(k)
		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 5
		bar.value = value
		bar.show_percentage = false
		bar.custom_minimum_size.y = 8
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", box(OK if value >= 3.5 else (MUTED if value >= 2.5 else ACCENT), 6, 0))
		row.add_child(bar)
		var v = label("%.1f" % value, 13, INK)
		v.custom_minimum_size.x = 30
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(v)
	section("Awareness & buzz")
	var reach = card()
	var awareness: float = game.sim.awareness
	kv(reach, "Awareness", "%.0f / 100" % awareness)
	var awareness_bar: ProgressBar = ProgressBar.new()
	awareness_bar.min_value = 0
	awareness_bar.max_value = 100
	awareness_bar.value = awareness
	awareness_bar.show_percentage = false
	awareness_bar.custom_minimum_size.y = 8
	reach.add_child(awareness_bar)
	var buzz: float = game.sim.buzz
	var buzz_word: String = "Quiet"
	if buzz > 4.0:
		buzz_word = "Buzzing"
	elif buzz < -4.0:
		buzz_word = "Cooling"
	kv(reach, "Buzz", "%s  ·  %+.0f" % [buzz_word, buzz], INK if absf(buzz) < 4.0 else ACCENT).tooltip_text = "Short-lived word of mouth and press."
	section("Press today")
	if game.sim.press_headlines.is_empty():
		note("No press headlines yet today.")
	else:
		var press = card()
		for headline in game.sim.press_headlines:
			note("• %s" % str(headline), INK, press)

func _reputation_campaigns() -> void:
	section("Running")
	if game.sim.campaigns.is_empty():
		note("No campaigns running. Two may run at once.")
	for active in game.sim.campaigns:
		var active_id: String = str(active.get("id", ""))
		var definition: Dictionary = Catalog.campaign(str(active_id))
		var running = card()
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		running.add_child(row)
		var text_col = VBoxContainer.new()
		text_col.add_theme_constant_override("separation", 0)
		text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_col)
		text_col.add_child(label(str(definition.get("name", active_id)), 14, INK))
		text_col.add_child(label("%d day(s) left  ·  $%s/day" % [int(active.get("days_left", 0)), format_money(float(definition.get("cost", 0.0)))], 12, MUTED))
		small_button("Stop", func():
			game.notify(game.sim.stop_campaign(active_id))
			refresh_view()
		, row)
	section("Available")
	for definition in Catalog.campaigns():
		var campaign_id: String = str(definition.get("id", ""))
		if game.sim.campaigns.any(func(item: Dictionary) -> bool: return str(item.get("id", "")) == campaign_id):
			continue
		var locked: bool = not game.sim.can_campaign(campaign_id)
		var start_button: Button = button("%s\n$%s / day  ·  %d days" % [str(definition.get("name", campaign_id)), format_money(float(definition.get("cost", 0.0))), int(definition.get("days", 1))], func():
			game.notify(game.sim.start_campaign(campaign_id))
			refresh_view()
		)
		start_button.disabled = locked or game.sim.campaigns.size() >= 2
		if locked:
			start_button.tooltip_text = "Unlock or requirements not met"
		elif game.sim.campaigns.size() >= 2:
			start_button.tooltip_text = "Two campaigns already running"
	note("The first day is charged when you start a campaign.")

func _reputation_events() -> void:
	section("Host an event")
	var when_row = HBoxContainer.new()
	when_row.add_theme_constant_override("separation", 8)
	body.add_child(when_row)
	var when_caption = label("Schedule", 13, MUTED)
	when_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	when_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	when_row.add_child(when_caption)
	var day_picker = SpinBox.new()
	day_picker.min_value = 1
	day_picker.max_value = 30
	day_picker.value = event_days
	day_picker.suffix = " days out"
	day_picker.custom_minimum_size.x = 120
	day_picker.value_changed.connect(func(v): event_days = int(v))
	when_row.add_child(day_picker)
	for def in Catalog.events():
		var id = def.id
		var problem = game.sim.event_requirements(id)
		var event_card = card()
		kv(event_card, str(def.name), "$%s  ·  grade %d" % [format_money(def.cost), int(def.min_grade)], INK, 14)
		note(str(def.description), MUTED, event_card)
		if not problem.is_empty():
			note(problem, ACCENT, event_card)
		var host = button("Schedule", func(): game.notify(game.sim.schedule_event(id, event_days)); refresh_view(), event_card)
		host.alignment = HORIZONTAL_ALIGNMENT_CENTER
		host.disabled = not problem.is_empty()
	section("Calendar")
	if game.sim.scheduled_events.is_empty():
		note("Nothing scheduled.")
	for event in game.sim.scheduled_events:
		var cal = card()
		kv(cal, str(event.get("name", event.get("kind", "Event"))), "Day %s" % str(event.get("day", event.get("start_day", "?"))), INK, 14)
		kv(cal, str(event.get("status", "Scheduled")), "%d attended  ·  %d finished" % [int(event.get("attended", 0)), int(event.get("rounds_completed", 0))])
	if not game.sim.event_history.is_empty():
		section("Results")
		var shown: int = 0
		for index in range(game.sim.event_history.size() - 1, -1, -1):
			var event = game.sim.event_history[index]
			list_item(str(event.get("name", event.get("kind", "Event"))), str(event.get("result", "")), func(): pass)
			shown += 1
			if shown >= 6:
				break

# ---------------------------------------------------------------- progress

func _progress_panel() -> void:
	heading("Research, milestones, and the path ahead.")
	_grade_card()
	if game.sim.sandbox:
		note("Sandbox bypasses locks. The tree is shown for reference.", ACCENT)
	section("Research")
	var running: int = game.sim.projects.size()
	note("%d of %d project slots in use. Cancel the same day for an 80%% refund." % [running, ResortSimulation.MAX_CONCURRENT_PROJECTS])
	segmented(null, [["Operations", "operations"], ["Course", "course"], ["Hospitality", "hospitality"], ["Prestige", "prestige"]], _progress_branch, func(v): _progress_branch = str(v); refresh_view())
	for node in Catalog.unlocks():
		if str(node.get("kind", "")) == "grade":
			continue
		if str(node.get("branch", "")) != _progress_branch:
			continue
		_progress_node_card(node)

func _grade_card() -> void:
	var grade: int = int(game.sim.grade)
	var names: Array[String] = ["Trailhead", "Club", "Resort"]
	var grade_box = card()
	kv(grade_box, "Resort grade", "%d  ·  %s" % [grade, names[clampi(grade - 1, 0, 2)]], INK, 15)
	if grade >= 3:
		note("Premier resort. Every grade milestone is complete.", OK, grade_box)
		return
	var target: int = grade + 1
	var requirements: Dictionary = game.sim._grade_definition(target).get("requirements", {})
	grade_box.add_child(label("TO REACH GRADE %d" % target, 10, MUTED))
	var checks: Array = [
		["Cash", float(game.sim.cash), float(requirements.get("cash", 0.0)), "$%s"],
		["Buildings", float(game.sim._building_count()), float(requirements.get("buildings", 0)), "%d"],
		["Playable holes", float(game.sim._course_holes.size()), float(requirements.get("holes", 0)), "%d"],
		["Publicity", float(game.sim.publicity), float(requirements.get("publicity", 0.0)), "%.0f"],
	]
	for entry in checks:
		var have: float = float(entry[1])
		var need: float = float(entry[2])
		var fmt: String = str(entry[3])
		var have_text: String = (fmt % format_money(have)) if fmt == "$%s" else (fmt % int(have) if fmt == "%d" else fmt % have)
		var need_text: String = (fmt % format_money(need)) if fmt == "$%s" else (fmt % int(need) if fmt == "%d" else fmt % need)
		kv(grade_box, "%s  %s" % ["✓" if have >= need else "○", str(entry[0])], "%s / %s" % [have_text, need_text], OK if have >= need else INK)
	var quality_satisfaction: float = 0.60 if target == 2 else 0.70
	var quality_wear: float = 0.50 if target == 2 else 0.35
	var sat_ok: bool = game.sim.satisfaction >= quality_satisfaction
	var wear_ok: bool = game.sim._terrain_wear() <= quality_wear
	var qualifying: bool = game.sim._has_qualifying_event(target)
	kv(grade_box, "%s  Qualifying event" % ("✓" if qualifying else "○"), "complete" if qualifying else "needed", OK if qualifying else INK)
	if not qualifying:
		note("Host " + ("an Open Day, Charity Scramble, or Beginner Clinic." if target == 2 else "a Club Championship or Regional Amateur."), MUTED, grade_box)
	grade_box.add_child(label("PLUS EITHER", 10, MUTED))
	var node_names: Array[String] = []
	var nodes_done: bool = true
	var grade_node: Dictionary = {}
	for node in Catalog.unlocks():
		if str(node.get("kind", "")) == "grade" and int(node.get("grade", -1)) == target:
			grade_node = node
	for node_id in grade_node.get("nodes", []):
		var branch_node: Dictionary = Catalog.unlock_node(str(node_id))
		var done: bool = game.sim.unlocked.has(str(node_id))
		nodes_done = nodes_done and done
		node_names.append(("✓ " if done else "○ ") + str(branch_node.get("name", node_id)))
	if not node_names.is_empty():
		kv(grade_box, "Progress nodes", "complete" if nodes_done else "in the tree", OK if nodes_done else INK, 12)
		note(", ".join(node_names), MUTED, grade_box)
	kv(grade_box, "or  Quality thresholds", "%s satisfaction ≥ %d%%  ·  %s wear ≤ %d%%" % ["✓" if sat_ok else "○", int(quality_satisfaction * 100), "✓" if wear_ok else "○", int(quality_wear * 100)], OK if sat_ok and wear_ok else INK, 12)

func _progress_node_card(node: Dictionary) -> void:
	var node_id: String = str(node.get("id", ""))
	var in_progress: Dictionary = {}
	for project in game.sim.projects:
		if str(project.get("id", "")) == node_id:
			in_progress = project
			break
	var complete: bool = game.sim.unlocked.has(node_id)
	var available: bool = game.sim.project_available(node_id)
	var state: String = "complete" if complete else ("in progress" if not in_progress.is_empty() else ("available" if available else "locked"))
	var selected: bool = _selected_progress_node == node_id
	var column = card(null, CARD_ACTIVE if state == "available" else CARD, selected)
	var wrap: PanelContainer = column.get_parent()
	wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_selected_progress_node = "" if selected else node_id
			refresh_view()
	)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	var title: Label = label(str(node.get("name", node_id)), 14, INK if state != "locked" else MUTED)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)
	var state_color: Color = OK if state == "complete" else (ACCENT if state == "in progress" else (INK if state == "available" else MUTED))
	var state_text: String = state.capitalize()
	if state == "in progress":
		state_text = "%d day(s) left" % int(in_progress.get("days_left", 0))
	var state_chip = chip(state_text, state_color, PAPER)
	state_chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(state_chip)
	if node.has("description") and (selected or state == "available"):
		note(str(node.get("description", "")), MUTED, column)
	var requires: Array = node.get("requires", [])
	if not requires.is_empty() and not complete:
		var req_names: Array[String] = []
		for req_id in requires:
			var req_node: Dictionary = Catalog.unlock_node(str(req_id))
			req_names.append(("✓ " if game.sim.unlocked.has(str(req_id)) else "○ ") + str(req_node.get("name", req_id)))
		note("Requires " + ", ".join(req_names), ACCENT if selected else MUTED, column)
	if node.has("milestone"):
		var progress: Dictionary = game.sim.milestone_progress(node_id)
		note(str(progress.get("label", "")), INK if available else MUTED, column)
	if state == "available":
		var commit = button("Commit  ·  $%s  ·  %d day(s)" % [format_money(float(node.get("cost", 0.0))), int(node.get("days", 1))], func():
			game.notify(game.sim.commit_project(node_id))
			refresh_view()
		, column)
		commit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif state == "locked":
		note("$%s  ·  %d day(s)" % [format_money(float(node.get("cost", 0.0))), int(node.get("days", 1))], MUTED, column)
	elif state == "in progress" and int(in_progress.get("started_day", -1)) == game.sim.day:
		small_button("Cancel  ·  80% refund", func():
			game.notify(game.sim.cancel_project(node_id))
			refresh_view()
		, column)

# ---------------------------------------------------------------- reports

func _reports_panel() -> void:
	heading("Trends, tables, and records.")
	var slice: Array[Dictionary] = _history_slice(1)
	var latest = card()
	if slice.is_empty():
		note("Records appear after the first settlement.", MUTED, latest)
	else:
		var record: Dictionary = slice.back()
		var income: float = 0.0
		var costs: float = 0.0
		for amount in (record.get("revenue", {}) as Dictionary).values(): income += float(amount)
		for amount in (record.get("expenses", {}) as Dictionary).values(): costs += float(amount)
		latest.add_child(label("LAST SETTLEMENT", 10, MUTED))
		kv(latest, "Income", "$%s" % format_money(income))
		kv(latest, "Costs", "$%s" % format_money(costs))
		kv(latest, "Net", "%s$%s" % ["+" if income >= costs else "−", format_money(absf(income - costs))], OK if income >= costs else ACCENT, 14)
		kv(latest, "Arrivals", str(int(record.get("arrivals", 0))))
		kv(latest, "Satisfaction", _percent(float(record.get("satisfaction", 0.0))))
	primary("Open full reports", func(): show_reports())
	_stats_records_section(body)
	small_button("Export history CSV", func(): _export_history_csv())
	if not is_instance_valid(reports_overlay):
		show_reports()

func show_reports() -> void:
	_close_reports()
	reports_overlay = Control.new()
	reports_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reports_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(reports_overlay)
	var card_panel = PanelContainer.new()
	card_panel.name = "Card"
	card_panel.add_theme_stylebox_override("panel", box(PAPER, 14, 18))
	reports_overlay.add_child(card_panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card_panel.add_child(column)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var title = label("Reports", 20, INK)
	top.add_child(title)
	var tabs = segmented(top, [["Money", "money"], ["Guests", "guests"], ["Operations", "operations"], ["Course", "course"], ["Today", "today"], ["Records", "records"]], _reports_view, func(v): _reports_view = str(v); _render_reports())
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	small_button("Export CSV", func(): _export_history_csv(), top)
	var close = small_button("✕", func(): _close_reports(), top)
	close.custom_minimum_size = Vector2(32, 28)
	var range_row = HBoxContainer.new()
	range_row.add_theme_constant_override("separation", 10)
	column.add_child(range_row)
	range_row.add_child(label("RANGE", 10, MUTED))
	var ranges = segmented(range_row, [["7 settlements", 7], ["30", 30], ["All", -1]], _stats_range_days, func(v): _stats_range_days = int(v); _render_reports())
	ranges.custom_minimum_size.x = 260
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_reports_body = VBoxContainer.new()
	_reports_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reports_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_reports_body)
	_layout_reports_overlay()
	_render_reports()

func _layout_reports_overlay() -> void:
	if not is_instance_valid(reports_overlay):
		return
	var card_panel: Control = reports_overlay.get_node("Card")
	var vs: Vector2 = root.size
	var left: float = GUTTER * 2 + _rail_width
	var width: float = minf(vs.x - left - GUTTER, 1240.0)
	card_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	card_panel.offset_left = left + (vs.x - left - GUTTER - width) * 0.5
	card_panel.offset_right = card_panel.offset_left + width
	card_panel.offset_top = HEADER_H + GUTTER
	card_panel.offset_bottom = vs.y - FOOTER_H - GUTTER
	panel.visible = false
	_workspace.visible = false

func _close_reports() -> void:
	if is_instance_valid(reports_overlay):
		reports_overlay.queue_free()
	reports_overlay = null
	if is_instance_valid(panel):
		panel.visible = true
	if is_instance_valid(_workspace):
		_workspace.visible = true

func _render_reports() -> void:
	if not is_instance_valid(_reports_body):
		return
	for child in _reports_body.get_children():
		child.queue_free()
	var previous_target = _target
	_target = _reports_body
	match _reports_view:
		"money": _stats_money_section(_reports_body)
		"guests": _stats_guests_section(_reports_body)
		"operations": _stats_operations_section(_reports_body)
		"course": _stats_course_section(_reports_body)
		"today": _stats_today_section(_reports_body)
		"records": _stats_records_section(_reports_body)
	_target = previous_target

func _history_slice(months: int) -> Array[Dictionary]:
	# History holds one record per monthly settlement; `months` counts records.
	var result: Array[Dictionary] = []
	if game == null or game.sim == null:
		return result
	var history: Array = game.sim.history
	var start: int = 0 if months < 0 else maxi(0, history.size() - months)
	for index in range(start, history.size()):
		result.append(history[index])
	if result.is_empty() and game.sim.day > 0:
		var live_revenue: Dictionary = game.sim._today_by_category.get("revenue", {})
		var live_expenses: Dictionary = game.sim._today_by_category.get("expenses", {})
		result.append({
			"day": game.sim.day,
			"cash_open": game.sim._today_cash_open,
			"cash_close": game.sim.cash,
			"revenue": live_revenue,
			"expenses": live_expenses,
		})
	return result

func daily_report() -> Array[String]:
	var lines: Array[String] = []
	for record in _history_slice(7):
		var income: float = 0.0
		var costs: float = 0.0
		for amount in (record.get("revenue", {}) as Dictionary).values(): income += float(amount)
		for amount in (record.get("expenses", {}) as Dictionary).values(): costs += float(amount)
		var finance: float = float(record.get("cash_close", 0.0)) - float(record.get("cash_open", 0.0)) - (income - costs)
		lines.append("Day %d · Income $%s · Costs $%s\nOperating net $%s · Financing $%s" % [int(record.get("day", 1)), format_money(income), format_money(costs), format_money(income - costs), format_money(finance)])
	return lines

func _add_chart(parent: Node, data: Array[Dictionary], day_labels: Array[String], legend: Array[String], mode: String = "line", height: float = 150.0, title: String = "") -> SimpleChart:
	var holder = card(parent, CARD)
	if not title.is_empty():
		holder.add_child(label(title.to_upper(), 10, MUTED))
	var chart: SimpleChart = SimpleChart.new()
	chart.custom_minimum_size = Vector2(280, height)
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_series(data, day_labels, legend, mode)
	holder.add_child(chart)
	return chart

func _table(parent: Node, headers: Array, rows: Array, on_header: Callable = Callable(), sort_keys: Array = []) -> void:
	var grid = GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	for index in range(headers.size()):
		var text: String = str(headers[index])
		if on_header.is_valid() and index < sort_keys.size() and not str(sort_keys[index]).is_empty():
			var key: String = str(sort_keys[index])
			var b = Button.new()
			b.flat = true
			b.text = text + ("  ▾" if _course_sort_column == key and _course_sort_desc else ("  ▴" if _course_sort_column == key else ""))
			b.add_theme_font_size_override("font_size", 11)
			b.add_theme_color_override("font_color", INK if _course_sort_column == key else MUTED)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.pressed.connect(func(): on_header.call(key))
			grid.add_child(b)
		else:
			grid.add_child(label(text.to_upper(), 11, MUTED))
	for row in rows:
		for cell in row:
			if cell is Control:
				grid.add_child(cell)
			else:
				grid.add_child(label(str(cell), 12, INK))

func _record_labels(slice: Array[Dictionary]) -> Array[String]:
	var labels: Array[String] = []
	for record in slice:
		labels.append(str(record.get("date", "?")).split(",")[0])
	return labels

func _stats_money_section(parent: Node) -> void:
	var slice: Array[Dictionary] = _history_slice(_stats_range_days)
	var labels: Array[String] = _record_labels(slice)
	var cash_series: Array[Dictionary] = []
	var net_series: Array[Dictionary] = []
	for record in slice:
		var day_num: int = int(record.get("day", 0))
		cash_series.append({"day": day_num, "cash": float(record.get("cash_close", 0.0))})
		var income: float = 0.0
		var costs: float = 0.0
		for amount in (record.get("revenue", {}) as Dictionary).values(): income += float(amount)
		for amount in (record.get("expenses", {}) as Dictionary).values(): costs += float(amount)
		net_series.append({"day": day_num, "net": income - costs})
	var debt: float = _debt_total()
	if debt > 0.0:
		var debt_card = card(parent)
		kv(debt_card, "Outstanding loan balance", "$%s" % format_money(debt), ACCENT, 14)
	_add_chart(parent, cash_series, labels, ["Cash at close"], "line", 150.0, "Cash")
	_add_chart(parent, net_series, labels, ["Net"], "line", 150.0, "Operating net")
	var categories: Dictionary = {}
	for record in slice:
		for key in (record.get("revenue", {}) as Dictionary).keys():
			categories[key] = true
	if not categories.is_empty():
		var stacked: Array[Dictionary] = []
		for record in slice:
			var point: Dictionary = {"day": int(record.get("day", 0))}
			for key in categories.keys():
				point[str(key)] = float((record.get("revenue", {}) as Dictionary).get(key, 0.0))
			stacked.append(point)
		var legend: Array[String] = []
		for key in categories.keys():
			legend.append(str(key).replace("_", " "))
		_add_chart(parent, stacked, labels, legend, "stacked_bar", 170.0, "Revenue by source")

func _stats_guests_section(parent: Node) -> void:
	var slice: Array[Dictionary] = _history_slice(_stats_range_days)
	var labels: Array[String] = _record_labels(slice)
	var arrivals_series: Array[Dictionary] = []
	var quality_series: Array[Dictionary] = []
	var rows: Array = []
	for record in slice:
		var day_num: int = int(record.get("day", 0))
		arrivals_series.append({"day": day_num, "arrivals": float(record.get("arrivals", 0)), "rounds": float(record.get("completed_rounds", 0))})
		quality_series.append({"day": day_num, "satisfaction": float(record.get("satisfaction", 0.0)) * 100.0, "spend": float(record.get("average_spend", 0.0))})
		rows.append([str(record.get("date", "Day %d" % day_num)), "%.0f%%" % (float(record.get("completion_rate", 0.0)) * 100.0), "$%s" % format_money(float(record.get("refunds", 0.0)))])
	_add_chart(parent, arrivals_series, labels, ["Arrivals", "Rounds"], "line", 150.0, "Visits")
	_add_chart(parent, quality_series, labels, ["Satisfaction %", "Avg spend"], "line", 150.0, "Quality")
	if not rows.is_empty():
		var table_card = card(parent)
		_table(table_card, ["Settlement", "Completion", "Refunds"], rows)

func _stats_operations_section(parent: Node) -> void:
	var slice: Array[Dictionary] = _history_slice(_stats_range_days)
	var labels: Array[String] = _record_labels(slice)
	var wait_series: Array[Dictionary] = []
	var staff_series: Array[Dictionary] = []
	for record in slice:
		var day_num: int = int(record.get("day", 0))
		wait_series.append({"day": day_num, "tee_wait": float(record.get("average_wait_tee", 0.0)), "wear": float(record.get("wear", 0.0)) * 100.0})
		staff_series.append({"day": day_num, "staff": float(record.get("staff_count", 0)), "wages": float(record.get("wages", 0.0))})
	_add_chart(parent, wait_series, labels, ["Tee wait (s)", "Wear %"], "line", 150.0, "Flow & condition")
	_add_chart(parent, staff_series, labels, ["Staff", "Wages"], "line", 150.0, "Team")
	var facility_totals: Dictionary = {}
	for record in slice:
		for kind in (record.get("facility_visits", {}) as Dictionary).keys():
			var entry: Dictionary = facility_totals.get(kind, {"visits": 0, "revenue": 0.0})
			entry["visits"] = int(entry.get("visits", 0)) + int((record.get("facility_visits", {}) as Dictionary).get(kind, 0))
			entry["revenue"] = float(entry.get("revenue", 0.0)) + float((record.get("facility_revenue", {}) as Dictionary).get(kind, 0.0))
			facility_totals[kind] = entry
	var facility_rows: Array = []
	for kind in facility_totals.keys():
		var entry: Dictionary = facility_totals[kind]
		facility_rows.append([str(kind).replace("_", " ").capitalize(), str(int(entry.get("visits", 0))), "$%s" % format_money(float(entry.get("revenue", 0.0))), float(entry.get("revenue", 0.0))])
	facility_rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[3]) > float(b[3]))
	if not facility_rows.is_empty():
		var table_card = card(parent)
		table_card.add_child(label("FACILITIES", 10, MUTED))
		var trimmed: Array = []
		for row in facility_rows:
			trimmed.append(row.slice(0, 3))
		_table(table_card, ["Facility", "Visits", "Revenue"], trimmed)

func _course_rows() -> Array[Dictionary]:
	var hole_stats: Dictionary = {}
	for record in game.sim.history:
		for hole_id_value in (record.get("hole_stats", {}) as Dictionary).keys():
			var hole_id: int = int(hole_id_value)
			if not hole_stats.has(hole_id):
				hole_stats[hole_id] = {"rounds": 0, "strokes_sum": 0.0, "hazards": 0, "minutes_sum": 0.0, "par": 4}
			var raw: Dictionary = (record.get("hole_stats", {}) as Dictionary)[hole_id]
			var agg: Dictionary = hole_stats[hole_id]
			var rounds: int = int(raw.get("rounds", 0))
			agg["rounds"] = int(agg.get("rounds", 0)) + rounds
			agg["strokes_sum"] = float(agg.get("strokes_sum", 0.0)) + float(raw.get("average_strokes", 0.0)) * float(rounds)
			agg["hazards"] = int(agg.get("hazards", 0)) + int(raw.get("hazards", 0))
			agg["minutes_sum"] = float(agg.get("minutes_sum", 0.0)) + float(raw.get("average_minutes", 0.0)) * float(rounds)
	for hole_id_value in game.sim._hole_stats_today.keys():
		var hole_id: int = int(hole_id_value)
		var raw: Dictionary = game.sim._hole_stats_today[hole_id]
		if not hole_stats.has(hole_id):
			hole_stats[hole_id] = {"rounds": 0, "strokes_sum": 0.0, "hazards": 0, "minutes_sum": 0.0, "par": 4}
		var agg: Dictionary = hole_stats[hole_id]
		agg["rounds"] = int(agg.get("rounds", 0)) + int(raw.get("rounds", 0))
		agg["strokes_sum"] = float(agg.get("strokes_sum", 0.0)) + float(raw.get("strokes_sum", 0.0))
		agg["hazards"] = int(agg.get("hazards", 0)) + int(raw.get("hazards", 0))
		agg["minutes_sum"] = float(agg.get("minutes_sum", 0.0)) + float(raw.get("minutes_sum", 0.0))
	var rows: Array[Dictionary] = []
	for hole_id_value in hole_stats.keys():
		var hole_id: int = int(hole_id_value)
		var agg: Dictionary = hole_stats[hole_id]
		var rounds: int = int(agg.get("rounds", 0))
		if rounds <= 0:
			continue
		var name: String = "Hole %d" % hole_id
		var par: int = 4
		for hole in game.terrain.holes:
			if int(hole.get("id", -1)) == hole_id:
				name = str(hole.get("name", name))
				par = int(hole.get("par", 4))
		rows.append({"id": hole_id, "name": name, "rounds": rounds, "avg_strokes": float(agg.get("strokes_sum", 0.0)) / float(rounds), "par": par, "hazards": int(agg.get("hazards", 0)), "minutes": float(agg.get("minutes_sum", 0.0)) / float(rounds)})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var av = a.get(_course_sort_column, 0)
		var bv = b.get(_course_sort_column, 0)
		if av is String:
			return (str(av) > str(bv)) if _course_sort_desc else (str(av) < str(bv))
		return (float(av) > float(bv)) if _course_sort_desc else (float(av) < float(bv))
	)
	return rows

func _stats_course_section(parent: Node) -> void:
	var rows: Array[Dictionary] = _course_rows()
	if rows.is_empty():
		note("Hole statistics appear once rounds are played.", MUTED, parent)
		return
	var table_card = card(parent)
	var table_rows: Array = []
	for row in rows:
		var captured_id: int = int(row.get("id", -1))
		var link = Button.new()
		link.flat = true
		link.text = str(row.get("name", ""))
		link.alignment = HORIZONTAL_ALIGNMENT_LEFT
		link.add_theme_font_size_override("font_size", 12)
		link.pressed.connect(func(): _close_reports(); game.select_hole(captured_id))
		var over: float = float(row.get("avg_strokes", 0.0)) - float(row.get("par", 4))
		table_rows.append([link, str(int(row.get("rounds", 0))), "%.1f (%+.1f)" % [float(row.get("avg_strokes", 0.0)), over], str(int(row.get("hazards", 0))), "%.0f min" % float(row.get("minutes", 0.0))])
	_table(table_card, ["Hole", "Rounds", "Avg vs par", "Hazards", "Pace"], table_rows, func(key: String):
		if _course_sort_column == key:
			_course_sort_desc = not _course_sort_desc
		else:
			_course_sort_column = key
			_course_sort_desc = true
		_render_reports()
	, ["name", "rounds", "avg_strokes", "hazards", "minutes"])

func _stats_today_section(parent: Node) -> void:
	var labels: Array[String] = []
	var guest_series: Array[Dictionary] = []
	var queue_series: Array[Dictionary] = []
	for point in game.sim.today_series:
		var t_value: float = float(point.get("minute", point.get("t", 0.0)))
		var sample_hours: float = fmod(t_value / 800.0 * 24.0 + 6.0, 24.0)
		labels.append("%02d:%02d" % [int(sample_hours), int(fmod(sample_hours, 1.0) * 60.0)])
		guest_series.append({"minute": t_value, "guests": float(point.get("guests_on_site", 0))})
		queue_series.append({"minute": t_value, "queues": float(point.get("tee_queue_total", 0)) + float(point.get("facility_queue_total", 0))})
	if guest_series.is_empty():
		note("Intraday samples appear every ~27 simulated seconds.", MUTED, parent)
		return
	_add_chart(parent, guest_series, labels, ["Guests on site"], "line", 150.0, "Occupancy · now %s" % game.sim.clock_string())
	_add_chart(parent, queue_series, labels, ["Queue total"], "line", 150.0, "Queues")

func _stats_records_section(parent: Node) -> void:
	var rec: Dictionary = game.sim.records
	var records = card(parent)
	records.add_child(label("RECORDS", 10, MUTED))
	if rec.is_empty():
		note("Records appear after the first full operating day.", MUTED, records)
		return
	var best_rev: Dictionary = rec.get("best_revenue_day", {})
	if not best_rev.is_empty():
		kv(records, "Best revenue day", "Day %d  ·  $%s" % [int(best_rev.get("day", 0)), format_money(float(best_rev.get("amount", 0.0)))])
	var most_rounds: Dictionary = rec.get("most_rounds_day", {})
	if not most_rounds.is_empty():
		kv(records, "Most rounds", "Day %d  ·  %d" % [int(most_rounds.get("day", 0)), int(most_rounds.get("rounds", 0))])
	kv(records, "Longest positive streak", "%d days" % int(rec.get("longest_positive_streak", 0)))
	var course_record: Dictionary = rec.get("course_record", {})
	if not course_record.is_empty():
		kv(records, "Course record", "%s  ·  %d strokes  ·  Day %d" % [str(course_record.get("name", "Golfer")), int(course_record.get("strokes", 0)), int(course_record.get("day", 0))])
	var largest_refund: Dictionary = rec.get("largest_refund_day", {})
	if not largest_refund.is_empty() and float(largest_refund.get("amount", 0.0)) > 0.0:
		kv(records, "Largest refund day", "Day %d  ·  $%s" % [int(largest_refund.get("day", 0)), format_money(float(largest_refund.get("amount", 0.0)))], ACCENT)

func _export_history_csv() -> void:
	if game == null or game.sim == null:
		return
	var save_label: String = SaveStore.clean_name(game.save_name)
	var dir_path: String = "user://exports"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var path: String = "%s/%s_history.csv" % [dir_path, save_label]
	var categories: Dictionary = {}
	for record in game.sim.history:
		for key in (record.get("revenue", {}) as Dictionary).keys():
			categories["rev_%s" % key] = true
		for key in (record.get("expenses", {}) as Dictionary).keys():
			categories["exp_%s" % key] = true
	var headers: Array[String] = [
		"day", "weekday", "cash_open", "cash_close", "arrivals", "groups", "completed_rounds",
		"completion_rate", "refunds", "average_spend", "satisfaction", "average_mood", "rating",
		"publicity", "grade", "wear", "average_wait_tee", "max_tee_queue", "average_wait_checkin",
		"staff_count", "wages", "holes_open", "peak_guests", "peak_queue_minute", "net",
	]
	for key in categories.keys():
		headers.append(str(key))
	var lines: Array[String] = [",".join(headers)]
	for record in game.sim.history:
		var row: Array[String] = []
		for header in headers:
			if header.begins_with("rev_"):
				row.append(str(float((record.get("revenue", {}) as Dictionary).get(header.substr(4), 0.0))))
			elif header.begins_with("exp_"):
				row.append(str(float((record.get("expenses", {}) as Dictionary).get(header.substr(4), 0.0))))
			else:
				row.append(str(record.get(header, "")))
		lines.append(",".join(row))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		game.notify("Could not write export file.")
		return
	file.store_string("\n".join(lines))
	file.close()
	game.notify("Exported history to %s" % path)

# ---------------------------------------------------------------- inspector / log / system

func _inspector_panel() -> void:
	match _selection_kind():
		"hole": _hole_inspector()
		"object": _object_inspector()
		"guest": _guest_inspector()
		"staff": _staff_inspector()

func _log_panel() -> void:
	heading("Event log")
	var filter_row = HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	body.add_child(filter_row)
	var category_pick = OptionButton.new()
	category_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var categories: Array[String] = ["", "finance", "guest", "staff", "facility", "course", "event", "construction", "system"]
	for index in range(categories.size()):
		category_pick.add_item("All categories" if categories[index].is_empty() else categories[index].capitalize(), index)
		if categories[index] == _log_category_filter:
			category_pick.select(index)
	category_pick.item_selected.connect(func(index: int): _log_category_filter = categories[index]; show_log())
	filter_row.add_child(category_pick)
	var severity_pick = OptionButton.new()
	severity_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var severities: Array[String] = ["", "info", "success", "warning", "critical"]
	for index in range(severities.size()):
		severity_pick.add_item("Any severity" if severities[index].is_empty() else severities[index].capitalize(), index)
		if severities[index] == _log_severity_filter:
			severity_pick.select(index)
	severity_pick.item_selected.connect(func(index: int): _log_severity_filter = severities[index]; show_log())
	filter_row.add_child(severity_pick)
	small_button("Mark all read", func():
		if not game.sim.log.is_empty():
			game.sim.last_seen_log_id = int(game.sim.log.back().get("id", 0))
		refresh_bell()
		show_log()
	)
	var shown = 0
	var last_day: int = -1
	for index in range(game.sim.log.size() - 1, -1, -1):
		var entry: Dictionary = game.sim.log[index]
		if not _log_category_filter.is_empty() and str(entry.get("category", "")) != _log_category_filter:
			continue
		if not _log_severity_filter.is_empty() and str(entry.get("severity", "")) != _log_severity_filter:
			continue
		var day = int(entry.get("day", 1))
		if day != last_day:
			last_day = day
			section(game.sim.date_string_for(day))
		var minute_value = float(entry.get("minute", 0.0))
		var entry_hours: float = fmod(minute_value * 60.0 / 800.0 * 24.0 + 6.0, 24.0)
		var clock = "%02d:%02d" % [int(entry_hours), int(fmod(entry_hours, 1.0) * 60.0)]
		var count = int(entry.get("count", 1))
		var severity = str(entry.get("severity", "info"))
		var color = TOAST_COLORS.get(severity, INK)
		var unread: bool = int(entry.get("id", 0)) > int(game.sim.last_seen_log_id)
		var captured = entry.duplicate(true)
		var item = list_item(str(entry.get("text", "")), "%s  ·  %s%s" % [clock, str(entry.get("category", "")).capitalize(), ("  ·  ×%d" % count) if count > 1 else ""], func(): game.jump_to(captured), severity.capitalize() if severity != "info" else ("New" if unread else ""), color)
		if severity in ["warning", "critical"]:
			var style: StyleBoxFlat = item.get_theme_stylebox("panel")
			style.border_color = color
			style.border_width_left = 3
		shown += 1
		if shown >= 80:
			break
	if shown == 0:
		note("No log entries match these filters.")

func _system_panel() -> void:
	heading("Your resort.")
	section("Save")
	var save_card = card()
	var edit = LineEdit.new()
	edit.text = game.save_name
	edit.placeholder_text = "Save name"
	save_card.add_child(edit)
	var save_row = actions(save_card)
	primary("Save resort", func(): game.save_name = edit.text; game.save_current(); show_system(), save_row).tooltip_text = "F5 quick-saves under the current name"
	var saves: Array = SaveStore.list_saves()
	if not saves.is_empty():
		section("Load")
		for name_value in saves:
			var selected = name_value
			list_item(str(name_value), "", func(): game.load_saved(selected))
		note("Autosaves run at each settlement and before replacing your current resort.")
	section("Settings")
	var settings = card()
	var quality_row = HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 8)
	settings.add_child(quality_row)
	var quality_label = Label.new()
	quality_label.text = "Graphics quality"
	quality_label.add_theme_font_size_override("font_size", 13)
	quality_row.add_child(quality_label)
	var quality_buttons: Dictionary = {}
	for preset_name in ["low", "standard", "high"]:
		var selected_preset: String = preset_name
		var button: Button = small_button(preset_name.capitalize(), func(): game.set_graphics_preset(selected_preset), quality_row)
		quality_buttons[preset_name] = button
	_update_quality_buttons(quality_buttons)
	var quality_note = Label.new()
	quality_note.text = "Low trims foliage, shadows and particles. Standard matches the current default look."
	quality_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quality_note.add_theme_font_size_override("font_size", 11)
	quality_note.add_theme_color_override("font_color", MUTED)
	settings.add_child(quality_note)
	var pause_toggle = CheckButton.new()
	pause_toggle.text = "Pause on critical alerts"
	pause_toggle.add_theme_font_size_override("font_size", 13)
	pause_toggle.button_pressed = game.pause_on_critical
	pause_toggle.toggled.connect(func(v): game.pause_on_critical = v)
	settings.add_child(pause_toggle)
	var sound_toggle = CheckButton.new()
	sound_toggle.text = "Sound effects"
	sound_toggle.add_theme_font_size_override("font_size", 13)
	sound_toggle.button_pressed = game.sound_enabled
	sound_toggle.toggled.connect(func(v): game.sound_enabled = v)
	settings.add_child(sound_toggle)
	small_button("Reset camera", func(): game.reset_resort_camera(), settings)
	section("Game")
	var game_row = actions()
	button("New game / main menu", func(): show_menu(), game_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section("Controls")
	var help = card()
	for pair in [["Pan", "WASD / arrows · middle drag"], ["Rotate", "Q / E · right drag"], ["Zoom", "Wheel"], ["Placement", "R rotates · Esc inspects"], ["Time", "Space pauses"], ["Edit", "⌘Z undo · ⌘⇧Z redo"], ["Save", "F5"]]:
		kv(help, str(pair[0]), str(pair[1]), INK, 12)
	note("Hole in Fun · Godot 4.7 · Original procedural models and sounds. Offline, single-player development build.")

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	if not is_instance_valid(cash_label): return
	refresh_bell()
	_refresh_toast_timers()
	var sim = game.sim
	cash_label.text = "$" + format_money(sim.cash)
	var delta: float = float(sim.cash) - float(sim._today_cash_open)
	cash_sub.text = "%s$%s this month" % ["▲ " if delta >= 0 else "▼ ", format_money(absf(delta))]
	cash_sub.add_theme_color_override("font_color", OK if delta >= 0 else ACCENT)
	var waiting: int = _waiting_count()
	visitor_label.text = "%d golfers" % sim.guests.size()
	visitor_sub.text = "%d waiting" % waiting if waiting > 0 else "no queues"
	visitor_sub.add_theme_color_override("font_color", ACCENT if waiting > 4 else MUTED)
	satisfaction_label.text = "%.0f%%" % (sim.satisfaction * 100.0)
	var summary: Dictionary = sim.feedback_summary(1, _feedback_end_day())
	var complaints: Array = summary.get("top_complaints", [])
	if complaints.is_empty():
		satisfaction_sub.text = "no complaints"
		satisfaction_label.tooltip_text = "Guest satisfaction"
	else:
		var tag: String = str(complaints[0].get("tag", ""))
		satisfaction_sub.text = str(ResortSimulation.FEEDBACK_TEXT.get(tag, tag.replace("_", " ")))
		satisfaction_label.tooltip_text = "Top complaint: " + _feedback_line(complaints[0])
	satisfaction_sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	satisfaction_sub.custom_minimum_size.x = 104
	grade_label.text = "★ %.1f" % sim.rating_or_satisfaction()
	grade_sub.text = "Grade %d · %s" % [sim.grade, ["Trailhead", "Club", "Resort"][clampi(sim.grade - 1, 0, 2)]]
	var forecast: Dictionary = sim.forecast_arrivals()
	forecast_label.text = "%d–%d" % [int(forecast.get("low", 0)), int(forecast.get("high", 0))]
	var condition: float = 1.0 - float(game.terrain.wear)
	condition_label.text = "%.0f%%" % (condition * 100.0)
	condition_label.add_theme_color_override("font_color", INK if condition >= 0.6 else ACCENT)
	clock_label.text = sim.clock_string()
	day_label.text = "%s · %s" % [sim.date_string(), sim.season_name()]
	for speed_value in speed_buttons:
		var b: Button = speed_buttons[speed_value]
		var active: bool = int(game.speed) == int(speed_value)
		b.add_theme_stylebox_override("normal", box(INK if active else PAPER, 8, 6))
		b.add_theme_stylebox_override("hover", box(INK if active else CARD_HOVER, 8, 6))
		b.add_theme_color_override("font_color", PAPER if active else INK)
		b.add_theme_color_override("font_hover_color", PAPER if active else INK)
	pause_banner.visible = int(game.speed) == 0 and not game.menu_open
	open_button.text = "Open" if sim.open else "Closed"
	open_button.add_theme_stylebox_override("normal", box(OK if sim.open else ACCENT, 8, 6))
	open_button.add_theme_color_override("font_color", PAPER)
	open_button.add_theme_color_override("font_hover_color", PAPER)
	sandbox_chip.visible = bool(sim.sandbox)
	var unread_warnings: int = sim.unread_count("warning")
	issue_button.visible = unread_warnings > 0 and not str(sim.notice).is_empty()
	if issue_button.visible:
		var text: String = str(sim.notice)
		issue_button.text = "⚠ " + (text.substr(0, 60) + "…" if text.length() > 60 else text)
	_refresh_ongoing()
	_refresh_overlay_panel()
	if view == "inspector":
		match _selection_kind():
			"guest": _refresh_guest_live()
			"staff": _refresh_staff_live()

func _refresh_ongoing() -> void:
	var items: Array = []
	for project in game.sim.projects:
		var node: Dictionary = Catalog.unlock_node(str(project.get("id", "")))
		items.append(["✦ %s · %dd" % [str(node.get("name", project.get("id", "Project"))), int(project.get("days_left", 0))], "Progress"])
	for active in game.sim.campaigns:
		var definition: Dictionary = Catalog.campaign(str(active.get("id", "")))
		items.append(["◎ %s · %dd" % [str(definition.get("name", active.get("id", "Campaign"))), int(active.get("days_left", 0))], "Reputation"])
	for event in game.sim.scheduled_events:
		var event_day: int = int(event.get("day", event.get("start_day", 0)))
		var delta: int = event_day - int(game.sim.day)
		if delta < 0 or delta > 30:
			continue
		var when: String = "today" if delta == 0 else ("tomorrow" if delta == 1 else "in %dd" % delta)
		items.append(["☆ %s · %s" % [str(event.get("name", event.get("kind", "Event"))), when], "Reputation"])
	var signature: String = str(items)
	if signature == _ongoing_signature:
		return
	_ongoing_signature = signature
	for child in ongoing_row.get_children():
		child.queue_free()
	for entry in items.slice(0, 4):
		var target_tab: String = str(entry[1])
		var b = Button.new()
		b.text = str(entry[0])
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size.y = 26
		b.add_theme_stylebox_override("normal", box(Color("f5f2e7dd"), 8, 8))
		b.add_theme_stylebox_override("hover", box(PAPER, 8, 8))
		b.pressed.connect(func():
			if target_tab == "Reputation":
				_reputation_view = "events" if str(entry[0]).begins_with("☆") else "campaigns"
			show_tab(target_tab)
		)
		ongoing_row.add_child(b)

func _overlay_label(overlay_id: String) -> String:
	match overlay_id:
		"none": return "No overlay"
		"beauty": return "Beauty"
		"access": return "Accessibility"
		"traffic": return "Foot traffic"
		"cart_traffic": return "Cart traffic"
		"waiting": return "Waiting"
		"landings": return "Landings"
		"wear": return "Wear"
		"coverage": return "Coverage"
		"elevation": return "Elevation"
	return overlay_id.capitalize()

func _refresh_overlay_panel() -> void:
	if not is_instance_valid(overlay_option) or not is_instance_valid(game.world):
		return
	var selected: int = maxi(0, game.OVERLAY_IDS.find(game.world.overlay))
	if overlay_option.selected != selected:
		overlay_option.selected = selected
	var has_overlay: bool = str(game.world.overlay) != "none"
	var legend: Dictionary = game.overlay_legend()
	overlay_legend_min.visible = has_overlay
	overlay_legend_gradient.visible = has_overlay
	overlay_legend_max.visible = has_overlay
	if has_overlay:
		overlay_legend_min.text = str(legend.get("min", "0"))
		overlay_legend_max.text = str(legend.get("max", "—"))
		var colors = legend.get("colors", PackedColorArray())
		if colors is PackedColorArray and (colors as PackedColorArray).size() >= 2:
			overlay_legend_gradient.texture = _gradient_texture(colors[0], colors[colors.size() - 1])
	var caption: String = game.landing_caption()
	overlay_landings_caption.text = caption
	overlay_landings_caption.visible = not caption.is_empty()
	if is_instance_valid(grid_button):
		var grid_on: bool = bool(game.show_grid)
		grid_button.add_theme_stylebox_override("normal", box(INK if grid_on else PAPER, 7, 8))
		grid_button.add_theme_color_override("font_color", PAPER if grid_on else INK)
		grid_button.add_theme_color_override("font_hover_color", PAPER if grid_on else INK)

func _gradient_texture(start: Color, finish: Color) -> ImageTexture:
	var image = Image.create(128, 1, false, Image.FORMAT_RGBA8)
	for x in range(128):
		image.set_pixel(x, 0, start.lerp(finish, float(x) / 127.0))
	return ImageTexture.create_from_image(image)

static func format_money(value: float) -> String:
	var text_value = str(roundi(value))
	var output = ""
	var count = 0
	for i in range(text_value.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0 and text_value[i] != "-": output = "," + output
		output = text_value[i] + output
		count += 1
	return output

# ---------------------------------------------------------------- main menu

func show_menu() -> void:
	game.menu_open = true
	_close_reports()
	if is_instance_valid(menu): menu.queue_free()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade = ColorRect.new()
	shade.color = Color(0.06, 0.14, 0.10, 0.54)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(minf(720.0, root.size.x - 40.0), 0)
	card_panel.add_theme_stylebox_override("panel", box(PAPER, 22, 32))
	center.add_child(card_panel)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card_panel.add_child(v)
	v.add_child(label("WELCOME TO YOUR LITTLE CORNER OF THE GAME", 11, MUTED))
	v.add_child(label("Hole in Fun", 40, INK))
	var menu_message := "Choose a property, tune the seed, and begin shaping your resort."
	if game.sim != null and game.sim.game_over:
		menu_message = "Game over · %s. Start or load a resort to continue." % game.sim.game_over_reason
	v.add_child(label(menu_message, 16, MUTED))
	var sandbox_toggle = CheckButton.new()
	sandbox_toggle.text = "Sandbox · unlimited funds & all unlocks"
	v.add_child(sandbox_toggle)
	var starter_toggle = CheckButton.new()
	starter_toggle.text = "Start with Cedar House club layout"
	starter_toggle.button_pressed = true
	v.add_child(starter_toggle)
	var seed_row = HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	seed_row.add_child(label("Seed", 14, INK))
	var seed_field = LineEdit.new()
	seed_field.placeholder_text = "Map default"
	seed_field.custom_minimum_size = Vector2(140, 0)
	seed_row.add_child(seed_field)
	var selected_map_id: String = "cedar_house"
	var random_button = Button.new()
	random_button.text = "Random"
	random_button.pressed.connect(func():
		seed_field.text = str(randi() % 1000000)
		_refresh_map_previews(v, seed_field, selected_map_id)
	)
	seed_row.add_child(random_button)
	v.add_child(seed_row)
	var map_scroll = ScrollContainer.new()
	map_scroll.custom_minimum_size = Vector2(0, minf(320.0, root.size.y * 0.35))
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(map_scroll)
	var map_grid = VBoxContainer.new()
	map_grid.add_theme_constant_override("separation", 10)
	map_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.add_child(map_grid)
	var map_cards: Dictionary = {}
	for map_def in Catalog.maps():
		var map_id: String = str(map_def.get("id", ""))
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var preview = TextureRect.new()
		preview.custom_minimum_size = Vector2(112, 112)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.texture = MapGenerator.preview_texture(map_def)
		row.add_child(preview)
		var info = VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 4)
		var title_row = HBoxContainer.new()
		title_row.add_theme_constant_override("separation", 8)
		title_row.add_child(label(str(map_def.get("name", map_id)), 18, INK))
		var diff_chip = chip(str(map_def.get("difficulty", "easy")).capitalize())
		diff_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		title_row.add_child(diff_chip)
		info.add_child(title_row)
		var desc = label(str(map_def.get("description", "")), 13, MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)
		var features: Array = map_def.get("features", [])
		if not features.is_empty():
			info.add_child(label(", ".join(features), 12, MUTED))
		var pick = Button.new()
		pick.text = "Select"
		pick.custom_minimum_size.y = 30
		pick.pressed.connect(func():
			selected_map_id = map_id
			var picked: Dictionary = Catalog.map(map_id)
			starter_toggle.disabled = not bool(picked.get("starter", false))
			if starter_toggle.disabled:
				starter_toggle.button_pressed = false
			for key in map_cards:
				var map_panel: PanelContainer = map_cards[key]
				var style = box(CARD if key == selected_map_id else PAPER, 10, 12)
				if key == selected_map_id:
					style.border_color = INK
					style.set_border_width_all(2)
				map_panel.add_theme_stylebox_override("panel", style)
		)
		info.add_child(pick)
		row.add_child(info)
		var map_card = PanelContainer.new()
		map_card.add_theme_stylebox_override("panel", box(PAPER, 10, 12))
		map_card.add_child(row)
		map_grid.add_child(map_card)
		map_cards[map_id] = map_card
	if map_cards.has(selected_map_id):
		var style = box(CARD, 10, 12)
		style.border_color = INK
		style.set_border_width_all(2)
		map_cards[selected_map_id].add_theme_stylebox_override("panel", style)
	seed_field.text_changed.connect(func(_value: String): _refresh_map_previews(v, seed_field, selected_map_id))
	primary("Begin new resort  →", func():
		var seed_value: int = -1
		if not seed_field.text.strip_edges().is_empty():
			seed_value = int(seed_field.text.strip_edges())
		hide_menu()
		game.new_game(sandbox_toggle.button_pressed, selected_map_id, seed_value, starter_toggle.button_pressed and not starter_toggle.disabled)
	, v)
	var menu_row = HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 8)
	v.add_child(menu_row)
	if game.sim == null or not game.sim.game_over:
		button("Continue current resort", func(): hide_menu(), menu_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not SaveStore.list_saves().is_empty():
		button("Load a saved resort", func(): hide_menu(); show_system(), menu_row).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button("Quit to Desktop", func(): game.quit_to_desktop(), menu_row)
	v.add_child(label("18 HOLES  /  LIVING GOLFERS  /  YOUR DESIGN", 11, MUTED))

func _refresh_map_previews(menu_root: VBoxContainer, seed_field: LineEdit, _selected_map_id: String) -> void:
	var seed_text: String = seed_field.text.strip_edges()
	var preview_seed: int = -1
	if not seed_text.is_empty():
		preview_seed = int(seed_text)
	for child in menu_root.get_children():
		if child is ScrollContainer:
			var grid: VBoxContainer = child.get_child(0)
			var map_index: int = 0
			for map_def in Catalog.maps():
				var row: HBoxContainer = (grid.get_child(map_index) as PanelContainer).get_child(0)
				var preview: TextureRect = row.get_child(0)
				preview.texture = MapGenerator.preview_texture(map_def, preview_seed)
				map_index += 1
			break

func hide_menu() -> void:
	if is_instance_valid(menu): menu.queue_free()
	menu = null
	game.menu_open = false
