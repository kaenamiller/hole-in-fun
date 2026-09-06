class_name ResortUI
extends CanvasLayer

const INK = Color("24483b")
const MUTED = Color("74816f")
const PAPER = Color("f5f2e7")
const ACCENT = Color("cf7951")
var game
var root: Control
var panel: PanelContainer
var body: VBoxContainer
var header_label: Label
var cash_label: Label
var visitor_label: Label
var grade_label: Label
var day_label: Label
var status_label: Label
var mode_label: Label
var tool_label: Label
var dynamic_label: Label
var tab = "Terrain"
var menu: Control
var nav_buttons: Dictionary = {}
var price_edits: Dictionary = {}
var event_days = 1

func setup(controller) -> void:
	game=controller
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme=Theme.new()
	theme.default_font_size=15
	theme.set_color("font_color","Label",INK)
	theme.set_color("font_color","Button",INK)
	theme.set_color("font_hover_color","Button",INK)
	theme.set_color("font_pressed_color","Button",PAPER)
	theme.set_color("font_disabled_color","Button",Color("a2a99a"))
	for state in ["normal","hover","pressed","disabled","focus"]:
		var c=PAPER
		if state=="hover":c=Color("e4e8d5")
		if state=="pressed":c=INK
		if state=="disabled":c=Color("e7e6dc")
		var style=box(c,8,10)
		if state=="focus":
			style.bg_color=Color.TRANSPARENT
			style.border_color=Color("afbe8e")
			style.set_border_width_all(2)
		theme.set_stylebox(state,"Button",style)
	theme.set_stylebox("normal","LineEdit",box(Color("e7ebde"),6,10))
	theme.set_color("font_color","LineEdit",INK)
	theme.set_color("caret_color","LineEdit",INK)
	theme.set_color("font_color","OptionButton",INK)
	theme.set_stylebox("normal","OptionButton",box(Color("e7ebde"),6,10))
	theme.set_stylebox("panel","PopupMenu",box(PAPER,8,10))
	theme.set_color("font_color","PopupMenu",INK)
	root.theme=theme
	_build_header()
	_build_nav()
	panel=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left=-348
	panel.offset_right=-20
	panel.offset_top=104
	panel.offset_bottom=-68
	panel.add_theme_stylebox_override("panel",box(PAPER,14,20))
	root.add_child(panel)
	var outer=VBoxContainer.new()
	outer.add_theme_constant_override("separation",12)
	panel.add_child(outer)
	header_label=label("THE LAND",12,MUTED)
	outer.add_child(header_label)
	var scroll=ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	body=VBoxContainer.new()
	body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	scroll.add_child(body)
	var footer=PanelContainer.new()
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top=-48
	footer.add_theme_stylebox_override("panel",box(INK,0,14))
	root.add_child(footer)
	var frow=HBoxContainer.new()
	footer.add_child(frow)
	status_label=label("Welcome to your little corner of the game.",14,PAPER)
	status_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	frow.add_child(status_label)
	day_label=label("DAY 01  ·  07:00",14,Color("c9d5ab"))
	frow.add_child(day_label)
	var tool=PanelContainer.new()
	tool.position=Vector2(110,108)
	tool.add_theme_stylebox_override("panel",box(Color("23493cee"),10,12))
	tool.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(tool)
	var v=VBoxContainer.new()
	tool.add_child(v)
	tool_label=label("SHAPE SOMETHING SPECIAL",12,Color("f2e9c9"))
	tool_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	v.add_child(tool_label)
	mode_label=label("Select a brush to start designing",12,Color("c1d0ae"))
	mode_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	v.add_child(mode_label)
	show_tab("Terrain")

static func box(color: Color, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var style=StyleBoxFlat.new()
	style.bg_color=color
	style.set_corner_radius_all(radius)
	style.content_margin_left=margin
	style.content_margin_right=margin
	style.content_margin_top=margin
	style.content_margin_bottom=margin
	return style

static func label(text: String, font_size: int = 15, color: Color = INK) -> Label:
	var item=Label.new()
	item.text=text
	item.add_theme_font_size_override("font_size",font_size)
	item.add_theme_color_override("font_color",color)
	return item

func button(text: String, callback: Callable, parent: Node = null) -> Button:
	var item=Button.new()
	item.text=text
	item.alignment=HORIZONTAL_ALIGNMENT_LEFT
	item.custom_minimum_size.y=37
	item.pressed.connect(callback)
	(parent if parent else body).add_child(item)
	return item

func copy(text: String, size_value: int = 14, color: Color = MUTED) -> Label:
	var item=label(text,size_value,color)
	item.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.add_child(item)
	return item

func section(text: String) -> void:
	var space=Control.new()
	space.custom_minimum_size.y=3
	body.add_child(space)
	body.add_child(label(text.to_upper(),11,MUTED))

func _build_header() -> void:
	var bar=PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom=84
	bar.add_theme_stylebox_override("panel",box(PAPER,0,18))
	root.add_child(bar)
	var row=HBoxContainer.new()
	row.add_theme_constant_override("separation",24)
	bar.add_child(row)
	var logo=TextureRect.new()
	logo.texture=load("res://assets/icon.svg")
	logo.custom_minimum_size=Vector2(48,48)
	logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(logo)
	var title=VBoxContainer.new()
	title.custom_minimum_size.x=175
	title.add_theme_constant_override("separation",-1)
	row.add_child(title)
	title.add_child(label("Hole in Fun",26))
	title.add_child(label("A LITTLE LAND. A GREAT GAME.",10,MUTED))
	cash_label=_stat(row,"AVAILABLE FUNDS","$180,000")
	visitor_label=_stat(row,"ON THE COURSE","0 golfers")
	grade_label=_stat(row,"COURSE GRADE","01 / Trailhead")
	var spacer=Control.new()
	spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var speeds=HBoxContainer.new()
	row.add_child(speeds)
	for pair in [["Ⅱ",0],["1×",1],["2×",2],["4×",4]]:
		var speed_value=pair[1]
		var b=button(pair[0],func():game.set_speed(speed_value),speeds)
		b.custom_minimum_size.x=38
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
	var opened=button("Open / close",func():game.toggle_open(),row)
	opened.tooltip_text="Close arrivals; current guests finish their visits."

func _stat(parent: Node, caption: String, value: String) -> Label:
	var v=VBoxContainer.new()
	v.add_theme_constant_override("separation",2)
	parent.add_child(v)
	v.add_child(label(caption,10,MUTED))
	var result=label(value,21)
	v.add_child(result)
	return result

func _build_nav() -> void:
	var rail=VBoxContainer.new()
	rail.position=Vector2(15,110)
	rail.add_theme_constant_override("separation",7)
	root.add_child(rail)
	for pair in [["Terrain","↟"],["Holes","⚑"],["Build","⌂"],["Guests","♙"],["Staff","♧"],["Money","$"],["Events","☆"],["Saves","≡"]]:
		var name_value=pair[0]
		var b=button(pair[1]+"\n"+name_value,func():show_tab(name_value),rail)
		b.custom_minimum_size=Vector2(73,64)
		b.add_theme_font_size_override("font_size",13)
		b.alignment=HORIZONTAL_ALIGNMENT_CENTER
		nav_buttons[name_value]=b

func show_tab(value: String) -> void:
	tab=value
	for child in body.get_children():child.queue_free()
	dynamic_label=null
	for name_value in nav_buttons:
		nav_buttons[name_value].add_theme_stylebox_override("normal",box(INK if name_value==value else PAPER,10,8))
		nav_buttons[name_value].add_theme_color_override("font_color",PAPER if name_value==value else INK)
	header_label.text={"Terrain":"THE LAND","Holes":"THE ROUND","Build":"THE RESORT","Guests":"THE PEOPLE","Staff":"THE TEAM","Money":"THE BUSINESS","Events":"THE OCCASION","Saves":"YOUR RESORT"}.get(value,value)
	match value:
		"Terrain":_terrain_panel()
		"Holes":_holes_panel()
		"Build":_build_panel()
		"Guests":_guests_panel()
		"Staff":_staff_panel()
		"Money":_money_panel()
		"Events":_events_panel()
		"Saves":_saves_panel()

func _terrain_panel() -> void:
	copy("Make room for a great round.",23,INK)
	copy("Sculpt the ground, then paint your course. Click or drag to build; every stroke has a live cost estimate.")
	var grid=GridContainer.new()
	grid.columns=2
	body.add_child(grid)
	for pair in [["↟  Raise","raise"],["↡  Lower","lower"],["≈  Smooth","smooth"],["—  Flatten","flatten"]]:
		var mode=pair[1]
		button(pair[0],func():game.set_tool(mode),grid).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	section("Brush")
	var radius_label=copy("Radius  ·  %d m"%game.brush_radius)
	var radius=HSlider.new()
	radius.min_value=4
	radius.max_value=64
	radius.step=2
	radius.value=game.brush_radius
	radius.value_changed.connect(func(v):game.brush_radius=v;radius_label.text="Radius  ·  %d m"%v)
	body.add_child(radius)
	var strength_label=copy("Strength  ·  %.1f m"%game.brush_strength)
	var strength=HSlider.new()
	strength.min_value=0.2
	strength.max_value=6
	strength.step=0.2
	strength.value=game.brush_strength
	strength.value_changed.connect(func(v):game.brush_strength=v;strength_label.text="Strength  ·  %.1f m"%v)
	body.add_child(strength)
	var node_toggle=CheckButton.new()
	node_toggle.text="Edit a single height node"
	node_toggle.button_pressed=game.single_node
	node_toggle.toggled.connect(func(v):game.single_node=v)
	body.add_child(node_toggle)
	section("Surface palette")
	for i in range(7):
		var type=i
		var b=button("●   "+TerrainModel.SURFACE_NAMES[i],func():game.paint_surface=type;game.set_tool("paint"))
		b.add_theme_color_override("font_color",TerrainModel.SURFACE_COLORS[i].darkened(0.4))
	section("View & history")
	button("Grid  ·  on / off",func():game.toggle_grid())
	button("Beauty overlay",func():game.toggle_overlay("beauty"))
	button("Accessibility overlay",func():game.toggle_overlay("access"))
	button("Undo  ⌘ Z",func():game.undo())
	button("Redo  ⌘ ⇧ Z",func():game.redo())

func _holes_panel() -> void:
	copy("Every hole tells a story.",23,INK)
	button("+  Design a new hole",func():game.set_tool("hole_tee"))
	copy("Click a tee location, then the cup. Tee and green surfaces are included in the cost.")
	for i in range(game.terrain.holes.size()):
		var hole=game.terrain.holes[i]
		var id=hole.id
		var yards=roundi(hole.tee.distance_to(hole.cup)*1.09361)
		button("%02d   %s\nPar %d  ·  %d yd  ·  %s"%[i+1,hole.name,hole.par,yards,"Open" if hole.open else "Closed"],func():game.select_hole(id))
	if not game.selected_hole.is_empty():
		var hole=game.selected_hole
		section("Selected hole")
		var name_edit=LineEdit.new()
		name_edit.text=hole.name
		name_edit.placeholder_text="Hole name"
		body.add_child(name_edit)
		name_edit.text_submitted.connect(func(v):game.edit_hole_value("name",v))
		button("Apply name",func():game.edit_hole_value("name",name_edit.text))
		var par=OptionButton.new()
		for value in [3,4,5]:par.add_item("Par %d"%value,value)
		par.select(clampi(int(hole.par)-3,0,2))
		par.item_selected.connect(func(i):game.edit_hole_value("par",i+3))
		body.add_child(par)
		var reason=game.terrain.hole_valid(hole)
		copy("Ready for play" if reason.is_empty() else reason,14,INK if reason.is_empty() else ACCENT)
		button("Move tee",func():game.set_tool("edit_tee"))
		button("Move cup / green",func():game.set_tool("edit_cup"))
		var green_size=SpinBox.new()
		green_size.min_value=8
		green_size.max_value=40
		green_size.step=2
		green_size.value=hole.green_radius
		green_size.suffix="m green radius"
		body.add_child(green_size)
		button("Apply green boundary",func():game.resize_green(green_size.value))
		button("Add routing waypoint",func():game.set_tool("waypoint"))
		button("Clear waypoints",func():game.edit_hole_value("waypoints",[]))
		button("Reopen hole" if not hole.open else "Close hole to new play",func():game.edit_hole_value("open",not hole.open))
		button("Move earlier in round",func():game.reorder_hole(-1))
		button("Move later in round",func():game.reorder_hole(1))
		button("Remove this hole",func():game.remove_hole())
		section("Shot lab · 30 rounds per skill")
		button("▶  Analyze this hole",func():game.analyze_hole())
		button("Clear trajectories",func():game.clear_analysis())
		if not game.analysis_results.is_empty():
			for result in game.analysis_results:
				copy("%s\n%.1f average strokes  ·  %.0f%% hazard shots"%[result.label,result.average,result.hazard_rate*100],14,INK)
			copy("Blue: beginner · Gold: intermediate · Coral: expert. Dots show sample landing positions.")

func _build_panel() -> void:
	copy("A place worth visiting.",23,INK)
	copy("Select an item, then click the land. R rotates. Escape returns to inspection.")
	section("Facilities")
	for def in Catalog.buildings():_catalog_button(def)
	section("Paths & bridges")
	for pair in [["Gravel path  ·  $8/m","path_gravel"],["Shared cart path  ·  $16/m","path_paved"],["Footbridge  ·  $90/m","bridge_walk"],["Cart bridge  ·  $150/m","bridge_cart"]]:
		var kind=pair[1]
		button(pair[0],func():game.place_kind=kind;game.set_tool("path"))
	copy("Paths and bridges use two clicks: start, then end. Bridge ends must meet dry land.")
	for set_id in ["woodland","garden","resort"]:
		section(set_id+" collection")
		for def in Catalog.scenery():
			if def.set==set_id:_catalog_button(def)
	if not game.selected_object.is_empty():
		section("Selected object")
		var obj=game.selected_object
		copy(Catalog.find(obj.kind).get("name",obj.kind.replace("_"," ")),19,INK)
		copy("Condition %.0f%% · Cleanliness %.0f%%"%[obj.condition*100,obj.cleanliness*100])
		for facility in game.sim.facility_status():
			if facility.id==obj.id:copy("Capacity %d · Queued groups %d
Workers nearby %d"%[facility.capacity,facility.queue,facility.workers])
		if Catalog.find(obj.kind).has("beauty"):copy("Local beauty %.0f / 100
Same-set combinations amplify nearby scenery."%game.terrain.beauty_at(obj.pos))
		button("Relocate",func():game.set_tool("move_object"))
		button("Rotate 90°",func():game.rotate_selected())
		button("Demolish · 25% salvage",func():game.demolish_selected())

func _catalog_button(def: Dictionary) -> void:
	var kind=def.id
	var locked=not game.sim.sandbox and int(def.grade)>game.sim.grade
	var b=button("%s%s\n$%s  ·  %s"%["○  " if locked else "+  ",def.name,format_money(def.cost),"Grade %d"%def.grade if locked else "$%s/day"%format_money(def.upkeep)],func():game.place_kind=kind;game.set_tool("place"))
	b.disabled=locked
	if def.has("beauty"):b.tooltip_text="%s set · %d beauty · %dm influence"%[def.set,def.beauty,def.influence]

func _guests_panel() -> void:
	copy("Good days, one guest at a time.",23,INK)
	button("Inspect golfers on the course",func():game.set_tool("inspect"))
	dynamic_label=copy("",14,INK)
	button("Follow selected guest",func():game.follow_selected=not game.follow_selected)
	section("Visiting now")
	for guest in game.sim.guests:
		var id=guest.id
		button("%s  ·  %s"%[guest.name,str(guest.activity).replace("_"," ")],func():game.select_guest(id))

func _staff_panel() -> void:
	copy("A well-kept course takes a team.",23,INK)
	copy("Staff travel to work. Attendants increase service capacity; cleaners restore comfort; groundskeepers maintain turf and buildings.")
	for def in Catalog.staff_roles():
		var role=def.id
		button("Hire %s\n$%s per day"%[def.name,format_money(def.wage)],func():game.sim.hire(role);show_tab("Staff"))
	section("Your team")
	for worker in game.sim.staff:
		var id=worker.id
		copy("%s · %s"%[worker.name,worker.role.replace("_"," ")],16,INK)
		copy(str(worker.activity).replace("_"," "))
		button("Inspect / follow",func():game.select_staff(id))
		var assignments=OptionButton.new()
		assignments.add_item("Automatic assignment",-1)
		for obj in game.terrain.objects:
			if Catalog.find(obj.kind).has("capacity"):
				assignments.add_item("%s #%d"%[obj.kind.replace("_"," "),obj.id],obj.id)
		for i in range(assignments.item_count):
			if assignments.get_item_id(i)==worker.get("assignment",-1):assignments.select(i)
		assignments.item_selected.connect(func(i):game.sim.assign_staff(id,assignments.get_item_id(i)))
		body.add_child(assignments)
		button("Dismiss",func():game.sim.fire(id);show_tab("Staff"))

func _money_panel() -> void:
	copy("Keep the good days growing.",23,INK)
	copy("Every transaction is recorded. Prices influence demand and guest value; unpaid bills impair operations.")
	dynamic_label=copy("",14,INK)
	section("Prices")
	price_edits.clear()
	for key in ["green_fee","cart","range","snack"]:
		var price_key=key
		var row=HBoxContainer.new()
		body.add_child(row)
		var caption=label(key.replace("_"," ").capitalize(),14)
		caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var edit=SpinBox.new()
		edit.min_value=0
		edit.max_value=200
		edit.step=1
		edit.value=game.sim.prices.get(key,10)
		edit.custom_minimum_size.x=110
		edit.value_changed.connect(func(v):game.sim.prices[price_key]=v)
		row.add_child(edit)
	section("Daily report")
	for line in daily_report():copy(line,13,INK)
	section("Finance options")
	for def in Catalog.loans():
		var id=def.id
		copy("%s · $%s\n%.1f%% annual interest · %d days\n$%s per day + interest · Grade %d"%[def.name,format_money(def.principal),def.interest*100,def.term_days,format_money(def.payment),def.min_grade],14,INK)
		button("Apply · "+def.name,func():game.notify(game.sim.borrow(id));show_tab("Money"))
	button("Request one-time recovery loan",func():game.notify(game.sim.borrow("recovery"));show_tab("Money"))
	section("Outstanding loans")
	for loan in game.sim.loans:
		var id=loan.get("id",-1)
		copy("%s\nBalance $%s"%[loan.get("name",loan.get("product","Loan")),format_money(loan.get("balance",0))])
		button("Repay $1,000",func():game.notify(game.sim.repay(id,1000));show_tab("Money"))
	section("Recent transactions")
	var count=game.sim.ledger.size()
	for i in range(count-1,maxi(-1,count-16),-1):
		var item=game.sim.ledger[i]
		copy("Day %s  ·  %s\n%s  $%s"%[item.get("day",1),item.get("description",item.get("category","")),"+" if item.get("amount",0)>=0 else "−",format_money(absf(item.get("amount",0)))],12)
	button("Bankruptcy / restart…",func():show_menu())

func daily_report() -> Array[String]:
	var by_day: Dictionary = {}
	for item in game.sim.ledger:
		var d=int(item.get("day",1))
		if d<game.sim.day-6:continue
		if not by_day.has(d):by_day[d]={"income":0.0,"expenses":0.0,"finance":0.0}
		var amount=float(item.get("amount",0))
		if item.get("category","") in ["capital","loan","loan_payment"]:by_day[d].finance+=amount
		elif amount>0:by_day[d].income+=amount
		else:by_day[d].expenses-=amount
	var lines: Array[String] = []
	for d in range(game.sim.day,maxi(0,game.sim.day-7),-1):
		if not by_day.has(d):continue
		var data=by_day[d]
		lines.append("Day %d · Income $%s · Costs $%s\nOperating net $%s · Financing $%s"%[d,format_money(data.income),format_money(data.expenses),format_money(data.income-data.expenses),format_money(data.finance)])
	return lines


func _events_panel() -> void:
	copy("Give them something to talk about.",23,INK)
	copy(game.sim.grade_requirements(),14,INK)
	section("Schedule an event")
	var day_picker=SpinBox.new()
	day_picker.min_value=1
	day_picker.max_value=30
	day_picker.value=event_days
	day_picker.suffix="days from today"
	day_picker.value_changed.connect(func(v):event_days=int(v))
	body.add_child(day_picker)
	for def in Catalog.events():
		var id=def.id
		copy(def.description,13)
		var problem=game.sim.event_requirements(id)
		if not problem.is_empty():copy(problem,12,ACCENT)
		button("%s\n$%s hosting · Grade %d"%[def.name,format_money(def.cost),def.min_grade],func():game.notify(game.sim.schedule_event(id,event_days));show_tab("Events"))
	section("Calendar")
	for event in game.sim.scheduled_events:
		copy("Day %s · %s\n%s"%[event.get("day",event.get("start_day","?")),event.get("name",event.get("kind","Event")),"%s · %d attended · %d finished"%[event.get("status","Scheduled"),event.get("attended",0),event.get("rounds_completed",0)]],14,INK)
	section("Results")
	for event in game.sim.event_history:
		copy("%s\n%s"%[event.get("name",event.get("kind","Event")),event.get("result",str(event))],13)

func _saves_panel() -> void:
	copy("Your next great course awaits.",23,INK)
	var edit=LineEdit.new()
	edit.text=game.save_name
	edit.placeholder_text="Save name"
	body.add_child(edit)
	button("Save resort",func():game.save_name=edit.text;game.save_current();show_tab("Saves"))
	section("Saved resorts")
	for name_value in SaveStore.list_saves():
		var selected=name_value
		button("Load · "+name_value,func():game.load_saved(selected))
	section("Settings")
	button("Sound  ·  on / off",func():game.sound_enabled=not game.sound_enabled)
	button("Camera  ·  reset",func():game.camera.reset_view())
	button("New game / main menu",func():show_menu())
	copy("WASD / arrows: pan\nMiddle drag: pan · Right drag: rotate\nQ / E: rotate · Wheel: zoom\nR: rotate placement · Esc: inspect\nSpace: pause · ⌘Z / Ctrl+Z: undo\nF5: quick save\n\nAutosaves run each day and before replacing your current resort.",13)
	copy("Hole in Fun · Godot 4.7\nOriginal procedural models and sounds. Offline, single-player development build.",12)

func refresh() -> void:
	if not is_instance_valid(cash_label):return
	cash_label.text="$"+format_money(game.sim.cash)
	visitor_label.text="%d golfers"%game.sim.guests.size()
	grade_label.text="%02d / %s"%[game.sim.grade,["Trailhead","Club","Resort"][clampi(game.sim.grade-1,0,2)]]
	day_label.text="DAY %02d  ·  %02d:%02d  ·  %s  ·  %s"%[game.sim.day,7+int(game.sim.minute)/60,int(game.sim.minute)%60,"OPEN" if game.sim.open else "CLOSED","SANDBOX" if game.sim.sandbox else "MANAGEMENT"]
	if is_instance_valid(dynamic_label):
		if tab=="Guests":dynamic_label.text=game.guest_details()
		elif tab=="Money":
			var debt=0.0
			for loan in game.sim.loans:debt+=float(loan.get("balance",0))
			dynamic_label.text="Cash  $%s\nDebt  $%s\nGuest satisfaction  %.0f%%\nCourse condition  %.0f%%\nCompleted visits  %d"%[format_money(game.sim.cash),format_money(debt),game.sim.satisfaction*100,(1.0-game.terrain.wear)*100,game.sim.completed_visits]

static func format_money(value: float) -> String:
	var text_value=str(roundi(value))
	var output=""
	var count=0
	for i in range(text_value.length()-1,-1,-1):
		if count>0 and count%3==0 and text_value[i]!="-":output=","+output
		output=text_value[i]+output
		count+=1
	return output

func show_menu() -> void:
	game.menu_open=true
	if is_instance_valid(menu):menu.queue_free()
	menu=Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var shade=ColorRect.new()
	shade.color=Color(0.06,0.14,0.10,0.54)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(shade)
	var center=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var card=PanelContainer.new()
	card.custom_minimum_size=Vector2(560,0)
	card.add_theme_stylebox_override("panel",box(PAPER,22,36))
	center.add_child(card)
	var v=VBoxContainer.new()
	v.add_theme_constant_override("separation",16)
	card.add_child(v)
	v.add_child(label("WELCOME TO YOUR LITTLE CORNER OF THE GAME",11,MUTED))
	v.add_child(label("Hole in Fun",48,INK))
	var intro=label("Shape the land. Design the round.\nBuild a place people love coming back to.",18,MUTED)
	v.add_child(intro)
	var sandbox_toggle=CheckButton.new()
	sandbox_toggle.text="Sandbox · unlimited funds & all unlocks"
	v.add_child(sandbox_toggle)
	button("Start at Cedar House  →",func():hide_menu();game.new_game(sandbox_toggle.button_pressed,true),v)
	button("Begin with a blank property  →",func():hide_menu();game.new_game(sandbox_toggle.button_pressed,false),v)
	button("Continue current resort",func():hide_menu(),v)
	if not SaveStore.list_saves().is_empty():button("Load a saved resort",func():hide_menu();show_tab("Saves"),v)
	button("Quit to Desktop",func():game.quit_to_desktop(),v)
	v.add_child(label("18 HOLES  /  LIVING GOLFERS  /  YOUR DESIGN",11,MUTED))

func hide_menu() -> void:
	if is_instance_valid(menu):menu.queue_free()
	game.menu_open=false
