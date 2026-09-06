extends Node3D

var terrain: TerrainModel
var sim: ResortSimulation
var world: TerrainView
var camera: ResortCamera
var ui: ResortUI
var speed = 1
var menu_open = true
var save_name = "Cedar House"
var tool = "inspect"
var brush_radius = 16.0
var brush_strength = 1.0
var paint_surface = 1
var single_node = false
var place_kind = "oak_tree"
var place_rotation = PI
var pending_point = Vector3.INF
var cursor_point = Vector3.ZERO
var selected_hole: Dictionary = {}
var selected_object: Dictionary = {}
var selected_guest_id = -1
var selected_staff_id = -1
var follow_selected = false
var analysis_results: Array = []
var undo_stack: Array = []
var redo_stack: Array = []
var show_grid = false
var sound_enabled = true
var _agents: Dictionary = {}
var _staff_nodes: Dictionary = {}
var _carts: Dictionary = {}
var _balls: Dictionary = {}
var _visual_shots: Dictionary = {}
var _agent_root = Node3D.new()
var _shot_root = Node3D.new()
var _cursor_root = Node3D.new()
var _selection_root = Node3D.new()
var _ghost: Node3D
var _ui_timer = 0.0
var _cursor_timer = 0.0
var _visual_time = 0.0
var _last_day = 1
var _last_paint = Vector3.INF
var _dragging_brush = false
var _notice_time = 0.0
var _previous_notice = ""
var _sound: AudioStreamPlayer
var _autoplay = false
var _test_frames = 0
var _benchmark = false
var _frame_times: Array[float] = []
var _benchmark_elapsed = 0.0

func _ready() -> void:
	_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	_benchmark = "--benchmark" in OS.get_cmdline_user_args()
	RenderingServer.set_default_clear_color(Color("b8cabe"))
	_setup_light()
	add_child(_agent_root)
	add_child(_shot_root)
	add_child(_cursor_root)
	add_child(_selection_root)
	camera=ResortCamera.new()
	add_child(camera)
	_sound=AudioStreamPlayer.new()
	_sound.volume_db=-22
	add_child(_sound)
	_create_resort(false,true)
	ui=ResortUI.new()
	add_child(ui)
	ui.setup(self)
	if _autoplay or _benchmark:menu_open=false
	else:ui.show_menu()
	notify("Welcome to Cedar House. Your first three holes are ready for play.")
	if _benchmark:
		_create_resort(true,true,true)
		camera.focus=Vector3(512,0,512)
		camera.size=1100
		for i in range(25):sim.admit_group(4)
	if "--smoke" in OS.get_cmdline_user_args():
		menu_open=false
		_test_frames=120

func _setup_light() -> void:
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-30,0)
	light.light_color=Color("fff0d3")
	light.light_energy=0.85
	light.shadow_enabled=true
	light.directional_shadow_max_distance=1200
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(light)
	var env=WorldEnvironment.new()
	var settings=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("b8cabe")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("d6dfca")
	settings.ambient_light_energy=0.35
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment=settings
	add_child(env)

func _create_resort(sandbox_mode: bool, starter: bool, full: bool = false) -> void:
	terrain=TerrainModel.new()
	if starter:terrain.starter_resort(full)
	sim=ResortSimulation.new()
	sim.setup(terrain,sandbox_mode,starter)
	_recreate_world()
	_last_day=sim.day
	selected_hole={}
	selected_object={}
	selected_guest_id=-1
	selected_staff_id=-1
	undo_stack.clear()
	redo_stack.clear()
	clear_analysis()
	pending_point=Vector3.INF
	tool="inspect"

func _recreate_world() -> void:
	if is_instance_valid(world):world.free()
	world=TerrainView.new()
	add_child(world)
	world.setup(terrain)
	world.set_grid(show_grid)
	for root_node in [_agent_root,_selection_root]:
		for child in root_node.get_children():child.free()
	_agents.clear()
	_staff_nodes.clear()
	_carts.clear()
	_balls.clear()
	_visual_shots.clear()

func new_game(sandbox_mode: bool, starter: bool) -> void:
	save_current("Before new game")
	_create_resort(sandbox_mode,starter)
	save_name="Cedar House" if starter else "My resort"
	camera.reset_view()
	if not starter:camera.focus=Vector3(190,0,180)
	speed=1
	menu_open=false
	ui.show_tab("Terrain")
	notify("Resort ready. Build a clubhouse and one playable hole to welcome guests." if not starter else "Cedar House is open. Design, inspect, or let the day unfold.")

func quit_to_desktop() -> void:
	get_tree().quit()

func _process(dt: float) -> void:
	if sim==null:return
	_visual_time+=dt
	var focus_control=get_viewport().gui_get_focus_owner()
	camera.enabled=not menu_open and not focus_control is LineEdit and not focus_control is TextEdit
	if not menu_open and speed>0:
		sim.tick(minf(dt,0.1)*60.0*speed)
	_update_people(dt)
	_update_balls(dt)
	_ui_timer+=dt
	_cursor_timer+=dt
	if _ui_timer>=0.5:
		_ui_timer=0
		ui.refresh()
		if sim.notice!=_previous_notice and not sim.notice.is_empty():
			_previous_notice=sim.notice
			notify(sim.notice)
		if sim.day!=_last_day:
			_last_day=sim.day
			save_current("Autosave")
	if _cursor_timer>0.09 and not menu_open:
		_cursor_timer=0
		_update_cursor()
	if _test_frames>0:
		_test_frames-=1
		if _test_frames==0:
			print("MAIN_SMOKE_OK guests=",sim.guests.size()," holes=",terrain.holes.size())
			get_tree().quit()
	if _benchmark:
		_benchmark_elapsed+=dt
		if _benchmark_elapsed>5:_frame_times.append(dt)
		if _benchmark_elapsed>40:
			_frame_times.sort()
			var total=0.0
			for value in _frame_times:total+=value
			print("BENCHMARK frames=%d avg_fps=%.1f p95_ms=%.2f guests=%d holes=%d"%[_frame_times.size(),_frame_times.size()/maxf(total,0.01),_frame_times[int(_frame_times.size()*0.95)]*1000,sim.guests.size(),terrain.holes.size()])
			get_viewport().get_texture().get_image().save_png("res://builds/benchmark.png")
			get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT:_dragging_brush=false
		if event.button_index in [MOUSE_BUTTON_MIDDLE,MOUSE_BUTTON_RIGHT]:camera.drag_mode=0


func _unhandled_input(event: InputEvent) -> void:
	if menu_open:return
	camera.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			set_tool("inspect")
			get_viewport().gui_release_focus()
		elif event.keycode==KEY_SPACE:set_speed(1 if speed==0 else 0)
		elif event.keycode==KEY_X:
			place_rotation+=PI/2
			if is_instance_valid(_ghost):_ghost.rotation.y=place_rotation
		elif event.keycode==KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			if event.shift_pressed:redo()
			else:undo()
		elif event.keycode==KEY_F5:save_current()
		elif event.keycode==KEY_F12:get_viewport().get_texture().get_image().save_png("res://builds/screenshot.png")
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			cursor_point=camera.ground_point(event.position,terrain)
			_world_click(cursor_point,event.position)
			_dragging_brush=tool in ["raise","lower","smooth","flatten","paint"]
			_last_paint=cursor_point
		else:_dragging_brush=false
	if event is InputEventMouseMotion and _dragging_brush and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var p=camera.ground_point(event.position,terrain)
		if p.distance_to(_last_paint)>maxf(3,brush_radius*0.45):
			_world_click(p,event.position)
			_last_paint=p

func set_speed(value: int) -> void:
	speed=value
	notify("Simulation paused" if value==0 else "Simulation speed %d×"%value)

func toggle_open() -> void:
	if sim.open:sim.open=false
	elif not sim.reopen():notify(sim.notice);return
	notify("Resort open to arrivals" if sim.open else "Closed to new arrivals. Current guests will finish.")

func set_tool(value: String) -> void:
	tool=value
	pending_point=Vector3.INF
	_dragging_brush=false
	if is_instance_valid(_ghost):_ghost.queue_free()
	_ghost=null
	if value=="place":
		_ghost=AssetFactory.build(place_kind,0)
		var mat=StandardMaterial3D.new()
		mat.albedo_color=Color(0.88,0.93,0.69,0.62)
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		_override_material(_ghost,mat)
		add_child(_ghost)
	var names={"inspect":"INSPECT YOUR RESORT","raise":"RAISE THE LAND","lower":"LOWER THE LAND","smooth":"SOFTEN THE SLOPES","flatten":"LEVEL THE GROUND","paint":"PAINT · "+TerrainModel.SURFACE_NAMES[paint_surface].to_upper(),"place":"PLACE · "+place_kind.replace("_"," ").to_upper(),"path":"CONNECT THE RESORT","hole_tee":"NEW HOLE · PLACE THE TEE","hole_cup":"NEW HOLE · PLACE THE CUP","edit_tee":"MOVE THE TEE","edit_cup":"MOVE THE CUP","waypoint":"PLAN A LAYUP ROUTE","move_object":"RELOCATE SELECTED OBJECT"}
	ui.tool_label.text=names.get(value,value.to_upper())
	ui.mode_label.text="Click a golfer or object to inspect" if value=="inspect" else "Click to build · R rotates · Esc cancels"

func _override_material(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:node.material_override=mat
	for child in node.get_children():_override_material(child,mat)

func _update_cursor() -> void:
	for child in _cursor_root.get_children():child.free()
	var hovered=get_viewport().gui_get_hovered_control()
	var blocked=hovered!=null and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE
	cursor_point=camera.ground_point(get_viewport().get_mouse_position(),terrain)
	if is_instance_valid(_ghost):
		_ghost.visible=not blocked and _inside(cursor_point)
		_ghost.position=cursor_point
		_ghost.rotation.y=place_rotation
	if blocked or not _inside(cursor_point):return
	var radius=2.5
	var color=Color("fff3c5")
	var cost=0.0
	var reason=""
	match tool:
		"raise","lower","smooth","flatten","paint":
			radius=2 if single_node and tool!="paint" else brush_radius
			var patch=terrain.plan_brush(tool,cursor_point,brush_radius,brush_strength,paint_surface,single_node)
			cost=patch.cost
		"place":
			var def=Catalog.find(place_kind)
			radius=def.get("radius",4)
			cost=def.get("cost",0)
			reason=_placement_reason(place_kind,cursor_point)
			if def.has("influence"):_cursor_root.add_child(_ring(cursor_point,def.influence,Color("b5d593"),0.25))
		"path":
			if pending_point!=Vector3.INF:
				cost=_path_cost(pending_point,cursor_point,place_kind)
				reason=terrain.path_valid(pending_point,cursor_point,place_kind.begins_with("bridge"))
				_cursor_root.add_child(TerrainView.line_mesh(_sample_line(pending_point,cursor_point),Color("eee4bd"),3))
		"hole_tee","edit_tee":radius=8
		"hole_cup","edit_cup":radius=14
		"inspect":return
	if not reason.is_empty() or (not sim.sandbox and sim.cash<cost):color=Color("eb9671")
	_cursor_root.add_child(_ring(cursor_point,radius,color,0.5))
	ui.mode_label.text=reason if not reason.is_empty() else ("$%s  ·  %s"%[ResortUI.format_money(cost),"Sandbox" if sim.sandbox else "Click to apply"] if cost>0 else "Click to select location · Esc cancels")

func _ring(p: Vector3, radius: float, color: Color, width: float = 0.6) -> MeshInstance3D:
	var points=PackedVector3Array()
	for i in range(49):
		var a=i*TAU/48.0
		var q=p+Vector3(cos(a),0,sin(a))*radius
		q.y=terrain.height_at(q)+0.35
		if terrain.surface_at(q)==5:q.y=maxf(q.y,terrain.water_levels[clampi(int(q.z/4),0,255)*256+clampi(int(q.x/4),0,255)]+0.2)
		points.append(q)
	return TerrainView.line_mesh(points,color,width)

func _sample_line(a: Vector3, b: Vector3) -> PackedVector3Array:
	var result=PackedVector3Array()
	var n=maxi(2,int(a.distance_to(b)/4))
	for i in range(n+1):
		var p=a.lerp(b,i/float(n))
		p.y=terrain.height_at(p)+0.4
		result.append(p)
	return result

func _inside(p: Vector3) -> bool:
	return p.x>=4 and p.z>=4 and p.x<1020 and p.z<1020

func _world_click(p: Vector3, screen: Vector2) -> void:
	if not _inside(p):return
	match tool:
		"raise","lower","smooth","flatten","paint":
			var patch=terrain.plan_brush(tool,p,brush_radius,brush_strength,paint_surface,single_node)
			if patch.cost>0:_commit({"kind":"brush","patch":patch,"cost":patch.cost,"center":p,"radius":brush_radius})
		"place":
			var reason=_placement_reason(place_kind,p)
			if not reason.is_empty():notify(reason);return
			var def=Catalog.find(place_kind)
			var obj={"id":terrain.uid(),"kind":place_kind,"pos":p,"rotation":place_rotation,"condition":1.0,"cleanliness":1.0}
			_commit({"kind":"object","before":{},"after":obj,"cost":def.cost,"center":p,"radius":def.radius+4})
		"path":
			if pending_point==Vector3.INF:
				pending_point=p
				notify("Choose the other end of the path or bridge.")
			else:
				var reason=terrain.path_valid(pending_point,p,place_kind.begins_with("bridge"))
				if not reason.is_empty():notify(reason);return
				var obj={"id":terrain.uid(),"kind":place_kind,"pos":pending_point,"end":p,"rotation":0.0,"condition":1.0,"cleanliness":1.0}
				if _commit({"kind":"object","before":{},"after":obj,"cost":_path_cost(pending_point,p,place_kind),"center":pending_point.lerp(p,0.5),"radius":pending_point.distance_to(p)*0.5+6}):pending_point=p
		"hole_tee":
			if terrain.holes.size()>=18:notify("An 18-hole course is the maximum.");return
			pending_point=p
			tool="hole_cup"
			ui.tool_label.text="NEW HOLE · PLACE THE CUP"
		"hole_cup":_create_hole(pending_point,p)
		"edit_tee","edit_cup":
			if selected_hole.is_empty():return
			var key="tee" if tool=="edit_tee" else "cup"
			var patch=terrain.plan_brush("paint",p,8 if key=="tee" else selected_hole.green_radius,1,3 if key=="tee" else 2)
			var after=selected_hole.duplicate(true)
			after[key]=p
			var commands=[{"kind":"brush","patch":patch,"cost":patch.cost,"center":p,"radius":18},{"kind":"hole","before":selected_hole.duplicate(true),"after":after,"index":terrain.holes.find(selected_hole),"cost":200.0,"center":p,"radius":maxf(18,p.distance_to(selected_hole[key]))}]
			_commit({"kind":"batch","commands":commands,"cost":patch.cost+200,"center":p,"radius":p.distance_to(selected_hole[key])+18})
			set_tool("inspect")
		"waypoint":
			if not selected_hole.is_empty():
				var points=selected_hole.waypoints.duplicate()
				points.append(p)
				edit_hole_value("waypoints",points)
		"move_object":_move_selected(p)
		_:_inspect_at(p,screen)

func _path_cost(a: Vector3, b: Vector3, kind: String) -> float:
	return ceilf(a.distance_to(b)*{"path_gravel":8,"path_paved":16,"bridge_walk":90,"bridge_cart":150}.get(kind,10))

func _placement_reason(kind: String, p: Vector3, ignore_id: int = -1) -> String:
	var def=Catalog.find(kind)
	if not sim.sandbox and def.get("grade",1)>sim.grade:return "Unlock this item by improving your course grade."
	if not terrain.playable(p):return "Place on dry, walkable terrain."
	var radius=float(def.get("radius",4))
	if p.x-radius<4 or p.z-radius<4 or p.x+radius>1020 or p.z+radius>1020:return "Keep the complete footprint inside the property."
	if terrain.slope_at(p).length()>0.35:return "Flatten this site before building."
	for obj in terrain.objects:
		if obj.id==ignore_id or obj.has("end"):continue
		var other=Catalog.find(obj.kind)
		if Vector2(p.x-obj.pos.x,p.z-obj.pos.z).length()<radius+float(other.get("radius",2)):return "This footprint overlaps another object."
	return ""

func _create_hole(tee: Vector3, cup: Vector3) -> void:
	if tee.distance_to(cup)<35:notify("Place the cup at least 38 yards from the tee.");return
	if not terrain.playable(tee) or not terrain.playable(cup):notify("Tee and cup must be on dry walkable land.");return
	var tee_patch=terrain.plan_brush("paint",tee,8,1,3)
	var cup_patch=terrain.plan_brush("paint",cup,14,1,2)
	var hole={"id":terrain.uid(),"name":"Hole %02d"%(terrain.holes.size()+1),"tee":tee,"cup":cup,"green_radius":14.0,"par":3 if tee.distance_to(cup)<220 else (4 if tee.distance_to(cup)<430 else 5),"open":true,"waypoints":[]}
	var commands=[{"kind":"brush","patch":tee_patch},{"kind":"brush","patch":cup_patch},{"kind":"hole","before":{},"after":hole,"index":terrain.holes.size()}]
	if _commit({"kind":"batch","commands":commands,"cost":500+tee_patch.cost+cup_patch.cost,"center":tee.lerp(cup,0.5),"radius":tee.distance_to(cup)*0.5+16}):
		selected_hole=terrain.holes.back()
		set_tool("inspect")
		ui.show_tab("Holes")

func _commit(command: Dictionary, add_history: bool = true, reverse: bool = false) -> bool:
	var amount=float(command.get("cost",0))*(-1 if reverse else 1)
	if amount>0 and not sim.charge(amount,"construction","%s%s"%["Undo " if reverse else "",command.kind.capitalize()]):
		notify("Insufficient funds or unpaid bills. Check the finance panel.")
		return false
	if amount<0:sim.credit(-amount,"construction","Construction reversal / salvage")
	_apply(command,reverse)
	var removed=-1
	if command.kind=="hole" and (command.before if reverse else command.after).is_empty():removed=(command.after if reverse else command.before).id
	for obj in terrain.objects:
		obj.pos.y=terrain.height_at(obj.pos)
		if obj.has("end"):obj.end.y=terrain.height_at(obj.end)
	for hole in terrain.holes:
		hole.tee.y=terrain.height_at(hole.tee)
		hole.cup.y=terrain.height_at(hole.cup)
	terrain.touch()
	sim.on_construction(command.get("center",Vector3.ZERO) if command.get("radius",0)>0 else Vector3(-10000,0,-10000),command.get("radius",0),removed)
	world.rebuild_dirty()
	world.sync_objects()
	world.sync_holes()
	if add_history:
		undo_stack.append(command.duplicate(true))
		if undo_stack.size()>100:undo_stack.pop_front()
		redo_stack.clear()
	_reselect()
	_sound_effect()
	return true

func _apply(command: Dictionary, reverse: bool) -> void:
	match command.kind:
		"brush":terrain.apply_brush(command.patch,reverse)
		"object","hole":
			var from: Dictionary=command.after if reverse else command.before
			var to: Dictionary=command.before if reverse else command.after
			var array=terrain.objects if command.kind=="object" else terrain.holes
			var index=int(command.get("index",array.size()))
			if not from.is_empty():
				for i in range(array.size()):
					if array[i].id==from.id:
						index=i
						array.remove_at(i)
						break
			if not to.is_empty():array.insert(clampi(index,0,array.size()),to.duplicate(true))
		"batch":
			var commands=command.commands.duplicate()
			if reverse:commands.reverse()
			for child in commands:_apply(child,reverse)
		"reorder":
			var from=command.to if reverse else command.from
			var to=command.from if reverse else command.to
			var item=terrain.holes.pop_at(from)
			terrain.holes.insert(to,item)

func undo() -> void:
	if undo_stack.is_empty():notify("Nothing to undo.");return
	var command=undo_stack.back()
	if _commit(command,false,true):
		undo_stack.pop_back()
		redo_stack.append(command)
		notify("Construction undone. Visits and elapsed time are preserved.")

func redo() -> void:
	if redo_stack.is_empty():notify("Nothing to redo.");return
	var command=redo_stack.back()
	if _commit(command,false,false):
		redo_stack.pop_back()
		undo_stack.append(command)
		notify("Construction reapplied.")

func _reselect() -> void:
	if not selected_hole.is_empty():
		var id=selected_hole.id
		selected_hole={}
		for hole in terrain.holes:
			if hole.id==id:selected_hole=hole
	if not selected_object.is_empty():
		var id=selected_object.id
		selected_object={}
		for obj in terrain.objects:
			if obj.id==id:selected_object=obj
	_draw_selection()

func edit_hole_value(key: String, value) -> void:
	if selected_hole.is_empty():return
	var after=selected_hole.duplicate(true)
	after[key]=value
	_commit({"kind":"hole","before":selected_hole.duplicate(true),"after":after,"index":terrain.holes.find(selected_hole),"cost":0,"center":after.tee.lerp(after.cup,0.5),"radius":0 if key in ["name","par","open"] else after.tee.distance_to(after.cup)*0.5+10})
	ui.show_tab("Holes")

func resize_green(radius: float) -> void:
	if selected_hole.is_empty():return
	var after=selected_hole.duplicate(true)
	after.green_radius=radius
	var patch=terrain.plan_brush("paint",after.cup,radius,1,2)
	var commands=[]
	var cost=float(patch.cost)
	if radius<float(selected_hole.green_radius):
		var trim=terrain.plan_brush("paint",after.cup,selected_hole.green_radius,1,1)
		var cells=[]
		for cell in trim.cells:
			var p=Vector3((int(cell[0])%256)*4+2,0,(int(cell[0])/256)*4+2)
			if cell[1]==2 and Vector2(p.x-after.cup.x,p.z-after.cup.z).length()>radius:cells.append(cell)
		trim.cells=cells
		trim.cost=cells.size()*9
		cost+=trim.cost
		commands.append({"kind":"brush","patch":trim})
	commands.append({"kind":"brush","patch":patch})
	commands.append({"kind":"hole","before":selected_hole.duplicate(true),"after":after,"index":terrain.holes.find(selected_hole)})
	_commit({"kind":"batch","commands":commands,"cost":cost,"center":after.cup,"radius":maxf(radius,selected_hole.green_radius)})
	ui.show_tab("Holes")


func reorder_hole(direction: int) -> void:
	if selected_hole.is_empty():return
	var index=terrain.holes.find(selected_hole)
	var to=clampi(index+direction,0,terrain.holes.size()-1)
	if to!=index:_commit({"kind":"reorder","from":index,"to":to,"cost":0,"center":Vector3.ZERO,"radius":0})
	ui.show_tab("Holes")

func remove_hole() -> void:
	if selected_hole.is_empty():return
	_commit({"kind":"hole","before":selected_hole.duplicate(true),"after":{},"index":terrain.holes.find(selected_hole),"cost":0,"center":selected_hole.tee.lerp(selected_hole.cup,0.5),"radius":selected_hole.tee.distance_to(selected_hole.cup)*0.5+20})
	selected_hole={}
	ui.show_tab("Holes")

func rotate_selected() -> void:
	if selected_object.is_empty():return
	var after=selected_object.duplicate(true)
	after.rotation+=PI/2
	if after.has("end"):
		after.end=after.pos+(after.end-after.pos).rotated(Vector3.UP,PI/2)
		var reason=terrain.path_valid(after.pos,after.end,after.kind.begins_with("bridge"))
		if not reason.is_empty():notify(reason);return
	_commit({"kind":"object","before":selected_object.duplicate(true),"after":after,"cost":0,"center":after.pos,"radius":Catalog.find(after.kind).get("radius",6)})
	ui.show_tab("Build")

func _move_selected(p: Vector3) -> void:
	if selected_object.is_empty():return
	var reason=_placement_reason(selected_object.kind,p,selected_object.id)
	if not reason.is_empty():notify(reason);return
	var after=selected_object.duplicate(true)
	if after.has("end"):
		after.end+=p-after.pos
		reason=terrain.path_valid(p,after.end,after.kind.begins_with("bridge"))
		if not reason.is_empty():notify(reason);return
	var old=after.pos
	after.pos=p
	_commit({"kind":"object","before":selected_object.duplicate(true),"after":after,"cost":Catalog.find(after.kind).get("cost",100)*0.1,"center":old.lerp(p,0.5),"radius":old.distance_to(p)*0.5+12})
	set_tool("inspect")
	ui.show_tab("Build")

func demolish_selected() -> void:
	if selected_object.is_empty():return
	var obj=selected_object
	var salvage=(_path_cost(obj.pos,obj.end,obj.kind) if obj.has("end") else Catalog.find(obj.kind).get("cost",0))*0.25
	_commit({"kind":"object","before":obj.duplicate(true),"after":{},"cost":-salvage,"center":obj.pos.lerp(obj.end,0.5) if obj.has("end") else obj.pos,"radius":obj.pos.distance_to(obj.end)*0.5+8 if obj.has("end") else Catalog.find(obj.kind).get("radius",6)+4})
	selected_object={}
	ui.show_tab("Build")

func _inspect_at(p: Vector3, screen: Vector2) -> void:
	var best=18.0
	var guest_id=-1
	for guest in sim.guests:
		var visible_pos=_agents[guest.id].position if _agents.has(guest.id) else guest.pos
		var point=camera.unproject_position(visible_pos+Vector3.UP)
		if point.distance_to(screen)<best:
			best=point.distance_to(screen)
			guest_id=guest.id
	if guest_id>=0:select_guest(guest_id);return
	for worker in sim.staff:
		if camera.unproject_position(worker.pos+Vector3.UP).distance_to(screen)<16:select_staff(worker.id);return
	var candidate={}
	var distance=INF
	for obj in terrain.objects:
		var d=TerrainModel.segment_distance(p,obj.pos,obj.end) if obj.has("end") else p.distance_to(obj.pos)
		var radius=6 if obj.has("end") else Catalog.find(obj.kind).get("radius",5)+2
		if d<radius and d<distance:
			candidate=obj
			distance=d
	if not candidate.is_empty():
		selected_object=candidate
		selected_hole={}
		selected_guest_id=-1
		_draw_selection()
		ui.show_tab("Build")
		return
	for hole in terrain.holes:
		if p.distance_to(hole.cup)<20 or p.distance_to(hole.tee)<14:select_hole(hole.id);return
	selected_object={}
	selected_hole={}
	selected_guest_id=-1
	_draw_selection()

func select_hole(id: int) -> void:
	for hole in terrain.holes:
		if hole.id==id:
			selected_hole=hole
			selected_object={}
			camera.focus=hole.tee.lerp(hole.cup,0.5)
			camera.size=maxf(140,hole.tee.distance_to(hole.cup)*1.5)
			_draw_selection()
			ui.show_tab("Holes")
			return

func select_guest(id: int) -> void:
	selected_guest_id=id
	selected_staff_id=-1
	selected_object={}
	selected_hole={}
	for guest in sim.guests:
		if guest.id==id:camera.focus=guest.pos;camera.size=minf(camera.size,120)
	set_tool("inspect")
	ui.show_tab("Guests")
	ui.refresh()

func select_staff(id: int) -> void:
	selected_staff_id=id
	selected_guest_id=-1
	for worker in sim.staff:
		if worker.id==id:
			camera.focus=worker.pos
			camera.size=100
			notify("%s · %s · %s"%[worker.name,worker.role.replace("_"," "),worker.activity])

func guest_details() -> String:
	for guest in sim.guests:
		if guest.id==selected_guest_id:
			return "%s\n%s · Group %d\n\nSkill %.0f%% · Mood %.0f%%\nEnergy %.0f%% · Hunger %.0f%%\nRestroom need %.0f%%\nBudget $%s · Spent $%s\n\nHole %d · %d strokes\nScorecard %s\n\n“%s”\n\nDestination %.0f, %.0f"%[guest.name,str(guest.activity).replace("_"," ").capitalize(),guest.group_id,guest.skill*100,guest.mood*100,guest.energy*100,guest.hunger*100,guest.restroom*100,ResortUI.format_money(guest.budget),ResortUI.format_money(guest.spent),guest.hole_index+1,guest.strokes,str(guest.scorecard),guest.thought,guest.destination.x,guest.destination.z]
	return "%d golfers visiting\n%.0f%% overall satisfaction\n\nClick a golfer on the course or select one below to see their day unfold."%[sim.guests.size(),sim.satisfaction*100]

func _draw_selection() -> void:
	for child in _selection_root.get_children():child.free()
	if not selected_object.is_empty():_selection_root.add_child(_ring(selected_object.pos,Catalog.find(selected_object.kind).get("radius",6)+1,Color("f1c777"),0.7))
	if not selected_hole.is_empty():
		_selection_root.add_child(_ring(selected_hole.cup,selected_hole.green_radius,Color("fff0bf"),0.4))
		var points=PackedVector3Array([selected_hole.tee])
		for p in selected_hole.waypoints:points.append(p)
		points.append(selected_hole.cup)
		for i in range(points.size()-1):_selection_root.add_child(TerrainView.line_mesh(_sample_line(points[i],points[i+1]),Color("eacf8c"),0.5))

func analyze_hole() -> void:
	if selected_hole.is_empty():notify("Select a hole first.");return
	clear_analysis()
	analysis_results=ShotEngine.analyze(terrain,selected_hole,30,42)
	var palette=[Color("79b9d5"),Color("f1cf79"),Color("dd8e70")]
	for tier in range(analysis_results.size()):
		var result=analysis_results[tier]
		var count=0
		for shot in result.shots:
			count+=1
			if count>90:break
			var points=PackedVector3Array()
			for i in range(17):
				var t=i/16.0
				var p=shot.start.lerp(shot.landing,t)
				p.y+=sin(t*PI)*shot.arc+0.3
				points.append(p)
			_shot_root.add_child(TerrainView.line_mesh(points,palette[tier],0.25))
			var dot=MeshInstance3D.new()
			var sphere=SphereMesh.new()
			sphere.radius=0.65
			sphere.height=1.3
			dot.mesh=sphere
			dot.position=shot.landing+Vector3.UP*0.5
			var mat=StandardMaterial3D.new()
			mat.albedo_color=palette[tier]
			mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			dot.material_override=mat
			_shot_root.add_child(dot)
	ui.show_tab("Holes")
	notify("Shot lab complete · 90 seeded rounds across three skill levels.")

func clear_analysis() -> void:
	analysis_results.clear()
	for child in _shot_root.get_children():child.queue_free()

func toggle_grid() -> void:
	show_grid=not show_grid
	world.set_grid(show_grid)

func toggle_overlay(value: String) -> void:
	world.set_overlay("none" if world.overlay==value else value)
	notify("Overlay: "+world.overlay)

func _update_people(dt: float) -> void:
	var alive={}
	for guest in sim.guests:
		alive[guest.id]=true
		if not _agents.has(guest.id):
			var node=AssetFactory.golfer(guest.id)
			node.position=guest.pos
			_agent_root.add_child(node)
			_agents[guest.id]=node
		var avatar=_agents[guest.id]
		var previous=avatar.position
		var target_position:Vector3=guest.pos
		if str(guest.activity) not in ["swinging","putting","walking_to_ball","riding"]:
			target_position+=Vector3((guest.id%2-0.5)*1.4,0,((guest.id/2)%2-0.5)*1.3)
		if str(guest.activity)=="riding":target_position+=Vector3((guest.id%2-0.5)*0.65,0.3,((guest.id/2)%2-0.5)*0.7)
		avatar.position=avatar.position.lerp(target_position,minf(1,dt*10))
		var delta=target_position-previous
		if Vector2(delta.x,delta.z).length()>0.2:avatar.rotation.y=atan2(delta.x,delta.z)+PI
		var activity=str(guest.activity)
		if not guest.get("shot",{}).is_empty():activity="putting" if guest.shot.get("club","")=="putter" else "swinging"
		elif activity=="riding":activity="seated"
		elif delta.length()>0.4:activity="walking"
		var animation_phase=_visual_time*1.8
		if _visual_shots.has(guest.id) and _visual_shots[guest.id].time<0.7:
			activity="putting" if _visual_shots[guest.id].shot.get("club","")=="putter" else "swinging"
			animation_phase=clampf(_visual_shots[guest.id].time/0.7,0,1)
		AssetFactory.animate_golfer(avatar,activity,animation_phase)
		var serial=guest.get("shot_serial",0)
		if serial>0 and avatar.get_meta("shot_serial",0)!=serial:
			avatar.set_meta("shot_serial",serial)
			_visual_shots[guest.id]={"shot":guest.get("last_shot",guest.get("shot",{})).duplicate(true),"time":0.0}
			if not _balls.has(guest.id):
				var ball=MeshInstance3D.new()
				var sphere=SphereMesh.new()
				sphere.radius=0.28
				sphere.height=0.56
				ball.mesh=sphere
				var mat=StandardMaterial3D.new()
				mat.albedo_color=Color("fffbef")
				ball.material_override=mat
				_agent_root.add_child(ball)
				_balls[guest.id]=ball
		if guest.get("cart",false):
			if not _carts.has(guest.group_id):
				var cart=AssetFactory.cart()
				_agent_root.add_child(cart)
				_carts[guest.group_id]=cart
			var cart_node=_carts[guest.group_id]
			var pos=guest.get("cart_pos",guest.pos)
			if cart_node.position==Vector3.ZERO:cart_node.position=pos
			var old=cart_node.position
			cart_node.position=old.lerp(pos,minf(1,dt*8))
			var difference=pos-old
			if difference.length()>0.2:cart_node.rotation.y=atan2(difference.x,difference.z)
		if guest.id==selected_guest_id:
			if follow_selected:camera.focus=avatar.position
			if not avatar.has_node("Selection"):
				var ring=_ring(Vector3.ZERO,1.5,Color("fff0b3"),0.22)
				ring.name="Selection"
				avatar.add_child(ring)
		elif avatar.has_node("Selection"):avatar.get_node("Selection").queue_free()
	for id in _agents.keys():
		if not alive.has(id):
			_agents[id].queue_free()
			_agents.erase(id)
			if _balls.has(id):_balls[id].queue_free();_balls.erase(id)
			_visual_shots.erase(id)
	var staff_alive={}
	for worker in sim.staff:
		staff_alive[worker.id]=true
		if not _staff_nodes.has(worker.id):
			var node=AssetFactory.golfer(worker.id+8)
			node.position=worker.pos
			_agent_root.add_child(node)
			_staff_nodes[worker.id]=node
		var node=_staff_nodes[worker.id]
		var delta=worker.pos-node.position
		node.position=node.position.lerp(worker.pos,minf(1,dt*10))
		if delta.length()>0.2:node.rotation.y=atan2(delta.x,delta.z)+PI
		AssetFactory.animate_golfer(node,"walking" if delta.length()>0.5 else "idle",_visual_time*4)
	for id in _staff_nodes.keys():
		if not staff_alive.has(id):_staff_nodes[id].queue_free();_staff_nodes.erase(id)
	var cart_groups={}
	for guest in sim.guests:
		if guest.get("cart",false):cart_groups[guest.group_id]=true
	for id in _carts.keys():
		if not cart_groups.has(id):_carts[id].queue_free();_carts.erase(id)

func _update_balls(dt: float) -> void:
	for id in _visual_shots:
		var data=_visual_shots[id]
		data.time+=dt*speed if not menu_open else 0
		var shot=data.shot
		if shot.is_empty() or not _balls.has(id):continue
		var t=clampf(data.time/maxf(0.8,float(shot.get("physics_duration",1.6))),0,1)
		var p: Vector3
		if t<0.8:
			var f=t/0.8
			p=shot.start.lerp(shot.landing,f)
			p.y+=sin(f*PI)*shot.arc+0.25
		else:
			p=shot.landing.lerp(shot.end,(t-0.8)/0.2)
			p.y+=0.2+absf(sin((t-0.8)*PI*15))*0.3*(1-t)
		_balls[id].position=p
		_balls[id].visible=not shot.holed or t<1

func save_current(name_override: String = "") -> void:
	if sim==null:return
	var result=SaveStore.save_game(save_name if name_override.is_empty() else name_override,terrain,sim,{"focus":camera.focus,"yaw":camera.yaw,"size":camera.size,"elevation":camera.elevation})
	if is_instance_valid(ui):notify(result)

func load_saved(name_value: String) -> void:
	var data=SaveStore.load_game(name_value)
	if data.is_empty():notify("This save could not be read. Its backup was also unavailable.");return
	save_current("Before loading")
	terrain=TerrainModel.new()
	terrain.restore(data.terrain)
	sim=ResortSimulation.new()
	sim.setup(terrain,data.simulation.get("sandbox",false),false)
	sim.restore(data.simulation)
	_recreate_world()
	save_name=name_value
	_last_day=sim.day
	selected_hole={}
	selected_object={}
	selected_guest_id=-1
	selected_staff_id=-1
	undo_stack.clear()
	redo_stack.clear()
	clear_analysis()
	var c=data.get("camera",{})
	camera.focus=c.get("focus",Vector3(248,0,238))
	camera.yaw=c.get("yaw",0.3)
	camera.size=c.get("size",480)
	menu_open=false
	set_tool("inspect")
	ui.show_tab("Saves")
	notify("Loaded “%s”. Active visits and the simulation clock were restored."%name_value)

func notify(message: String) -> void:
	if is_instance_valid(ui) and is_instance_valid(ui.status_label):ui.status_label.text=message
	_notice_time=_visual_time

func _sound_effect() -> void:
	if not sound_enabled:return
	var wave=AudioStreamWAV.new()
	wave.format=AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate=22050
	var bytes=PackedByteArray()
	bytes.resize(2205*2)
	for i in range(2205):
		var t=i/22050.0
		var sample=sin(TAU*(520.0+180.0*t)*t)*exp(-t*55)*0.3
		bytes.encode_s16(i*2,int(sample*32767))
	wave.data=bytes
	_sound.stream=wave
	_sound.play()
