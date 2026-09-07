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
var analysis_metrics: Dictionary = {}
var analysis_filter: String = ""
var undo_stack: Array = []
var redo_stack: Array = []
var show_grid = false
var service_range = 90.0
var sound_enabled = true
var pause_on_critical = false
var _agents: Dictionary = {}
var _staff_nodes: Dictionary = {}
var _carts: Dictionary = {}
var _balls: Dictionary = {}
var _visual_shots: Dictionary = {}
var _agent_root = Node3D.new()
var _shot_root = Node3D.new()
var _cursor_root = Node3D.new()
var _selection_root = Node3D.new()
var _overlay_root = Node3D.new()
var _ghost: Node3D
var _ui_timer = 0.0
var _cursor_timer = 0.0
var _visual_time = 0.0
var _last_day = 1
var _last_settlements = 0
var _last_season = 0
var _weather_particles: Node3D
var _environment: Environment
var _last_paint = Vector3.INF
var _dragging_brush = false
var _notice_time = 0.0
var _last_toast_log_id = 0
var _sound: AudioStreamPlayer
var _autoplay = false
var _test_frames = 0
var _photo_mode = false
var _benchmark = false
var _frame_times: Array[float] = []
var _benchmark_elapsed = 0.0
var _overlay_refresh_timer = 0.0
var _overlay_history: Array[String] = ["traffic", "beauty"]
var _game_over_handled := false
var graphics: GraphicsSettingsService = GraphicsSettingsService.new()
var _directional_light: DirectionalLight3D
var _world_environment: WorldEnvironment
var _profile_sim_ms: float = 0.0
var _profile_sync_ms: float = 0.0

const OVERLAY_IDS: Array[String] = [
	"none", "beauty", "access", "traffic", "cart_traffic", "waiting",
	"landings", "wear", "coverage", "elevation",
]

func _ready() -> void:
	_autoplay = "--autoplay" in OS.get_cmdline_user_args()
	_benchmark = "--benchmark" in OS.get_cmdline_user_args()
	graphics.settings_changed.connect(_on_graphics_settings_changed)
	RenderingServer.set_default_clear_color(Color("b8cabe"))
	_setup_light()
	add_child(_agent_root)
	add_child(_shot_root)
	add_child(_cursor_root)
	add_child(_selection_root)
	add_child(_overlay_root)
	camera=ResortCamera.new()
	add_child(camera)
	_sound=AudioStreamPlayer.new()
	_sound.volume_db=-22
	add_child(_sound)
	_create_resort(false, "cedar_house", -1, true)
	camera.focus=Vector3(310,0,305)
	camera.size=470
	ui=ResortUI.new()
	add_child(ui)
	ui.setup(self)
	graphics.apply_to_game(self, false)
	if _autoplay or _benchmark:menu_open=false
	else:ui.show_menu()
	notify("Welcome to Cedar House. Your first three holes are ready for play.")
	if _benchmark:
		_create_resort(true, "pinewood_valley", -1, true, true)
		camera.focus=Vector3(512,0,512)
		camera.size=1100
		for i in range(25):sim.admit_group(4)
	if "--smoke" in OS.get_cmdline_user_args():
		menu_open=false
		_test_frames=120

func _setup_light() -> void:
	var light=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-38,-38,0)
	light.light_color=Color("fff0d3")
	light.light_energy=1.12
	light.shadow_enabled=true
	light.directional_shadow_max_distance=1100
	light.directional_shadow_blend_splits=true
	light.shadow_blur=1.6
	light.shadow_bias=0.15
	light.shadow_normal_bias=1.5
	light.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(light)
	_directional_light=light
	var env=WorldEnvironment.new()
	var settings=Environment.new()
	settings.background_mode=Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color=Color("789fb4")
	sky_material.sky_horizon_color=Color("dce4cd")
	sky_material.ground_horizon_color=Color("dce4cd")
	sky_material.ground_bottom_color=Color("66734a")
	sky_material.sun_angle_max=8.0
	sky.sky_material=sky_material
	settings.sky=sky
	settings.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	settings.background_color=Color("b8cabe")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("c6d8cf")
	settings.ambient_light_energy=0.48
	settings.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	env.environment=settings
	_environment=settings
	_world_environment=env
	add_child(env)
	graphics.apply_to_game(self, false)

func _apply_graphics_lighting(settings: GraphicsSettings) -> void:
	if not is_instance_valid(_directional_light):
		return
	_directional_light.directional_shadow_max_distance=settings.shadow_distance
	RenderingServer.directional_shadow_atlas_set_size(settings.shadow_resolution, true)

func _apply_graphics_environment(settings: GraphicsSettings) -> void:
	if not is_instance_valid(_environment):
		return
	match settings.reflection_mode:
		"probe", "planar":
			_environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
		_:
			_environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	AssetFactory.foliage_lod_distance=clampf(settings.foliage_view_distance*0.08, 35.0, 120.0)

func _apply_graphics_weather(settings: GraphicsSettings) -> void:
	if not is_instance_valid(_weather_particles):
		return
	_weather_particles.amount=mini(_weather_particles.amount, settings.weather_particle_cap)

func _on_graphics_settings_changed(_previous: GraphicsSettings, current: GraphicsSettings) -> void:
	graphics.apply_to_game(self, _needs_scenery_rebuild(current))
	if is_instance_valid(ui):
		ui.refresh_system_panel()

func _needs_scenery_rebuild(current: GraphicsSettings) -> bool:
	return true

func set_graphics_preset(name_value: String) -> void:
	graphics.set_preset(name_value)
	notify("Graphics quality: " + name_value.capitalize())

func consume_profile_metrics() -> Dictionary:
	var metrics: Dictionary = {"sim_ms": _profile_sim_ms, "scene_sync_ms": _profile_sync_ms}
	_profile_sim_ms=0.0
	_profile_sync_ms=0.0
	return metrics

func _apply_season() -> void:
	if sim==null:return
	var index:int=sim.season_index()
	var palettes=[
		{"bg":Color("b8cabe"),"amb":Color("d6dfca")},
		{"bg":Color("c2d2b2"),"amb":Color("e0e2c4")},
		{"bg":Color("c9bda1"),"amb":Color("ddd2b6")},
		{"bg":Color("c9d3da"),"amb":Color("dfe6ec")},
	]
	var palette:Dictionary=palettes[clampi(index,0,3)]
	if is_instance_valid(_environment):
		_environment.background_color=palette.bg
		_environment.ambient_light_color=palette.amb
	if world!=null and is_instance_valid(world):world.set_season(index)
	AssetFactory.apply_season(index)
	_update_weather_particles(index)

func _update_weather_particles(index:int) -> void:
	var particles:CPUParticles3D
	if is_instance_valid(_weather_particles):
		particles=_weather_particles
	else:
		particles=CPUParticles3D.new()
		particles.emission_shape=CPUParticles3D.EMISSION_SHAPE_BOX
		particles.emission_box_extents=Vector3(120,2,120)
		particles.lifetime=14.0
		particles.preprocess=8.0
		var mesh:BoxMesh=BoxMesh.new()
		mesh.size=Vector3(0.08,0.08,0.08)
		particles.mesh=mesh
		_weather_particles=particles
		add_child(particles)
	var rain:BoxMesh=BoxMesh.new()
	rain.size=Vector3(0.04,1.4,0.04)
	match index:
		0:
			particles.emitting=true
			particles.amount=520
			particles.mesh=rain
			particles.color=Color(0.62,0.74,0.86,0.55)
			particles.gravity=Vector3(0,-42,0)
			particles.initial_velocity_min=6.0
			particles.initial_velocity_max=10.0
			particles.direction=Vector3(0.2,-1,0.1)
			particles.spread=4.0
		1:
			particles.emitting=false
		2:
			particles.emitting=true
			particles.amount=160
			var leaf:BoxMesh=BoxMesh.new()
			leaf.size=Vector3(0.3,0.06,0.22)
			particles.mesh=leaf
			particles.color=Color(0.72,0.5,0.24,0.9)
			particles.gravity=Vector3(0,-1.6,0)
			particles.initial_velocity_min=0.5
			particles.initial_velocity_max=1.6
			particles.direction=Vector3(1,-0.3,0.4)
			particles.spread=40.0
		3:
			particles.emitting=true
			particles.amount=600
			var flake:SphereMesh=SphereMesh.new()
			flake.radius=0.09
			flake.height=0.18
			particles.mesh=flake
			particles.color=Color(0.96,0.97,1.0,0.85)
			particles.gravity=Vector3(0,-2.4,0)
			particles.initial_velocity_min=0.4
			particles.initial_velocity_max=1.2
			particles.direction=Vector3(0,-1,0)
			particles.spread=12.0
	if is_instance_valid(particles):
		particles.amount=mini(particles.amount, graphics.current.weather_particle_cap)

func _create_resort(sandbox_mode: bool, map_id: String, seed_value: int, starter: bool, full: bool = false) -> void:
	var map_def: Dictionary = Catalog.map(map_id)
	if map_def.is_empty():
		map_def = Catalog.map("cedar_house")
	if seed_value >= 0:
		map_def = map_def.duplicate(true)
		map_def["seed"] = seed_value
	terrain = MapGenerator.generate(map_def)
	if starter and bool(map_def.get("starter", false)):
		terrain.starter_resort(full)
	sim = ResortSimulation.new()
	sim.setup(terrain, sandbox_mode, starter, map_def)
	_game_over_handled = false
	_recreate_world()
	_last_day=sim.day
	_last_toast_log_id=sim.log.back().get("id",0) if not sim.log.is_empty() else 0
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
	world.apply_graphics_settings(graphics.current)
	for root_node in [_agent_root,_selection_root,_overlay_root]:
		for child in root_node.get_children():child.free()
	_agents.clear()
	_staff_nodes.clear()
	_carts.clear()
	_balls.clear()
	_visual_shots.clear()

func new_game(sandbox_mode: bool, map_id: String, seed_value: int, starter: bool) -> void:
	save_current("Before new game")
	var map_def: Dictionary = Catalog.map(map_id)
	if map_def.is_empty():
		map_def = Catalog.map("cedar_house")
	_create_resort(sandbox_mode, map_id, seed_value, starter)
	save_name = str(map_def.get("name", "My resort"))
	camera.reset_view(terrain.entrance)
	if starter and terrain.map_id == "cedar_house":
		camera.focus=Vector3(310,0,305)+terrain.entrance-TerrainModel.DEFAULT_ENTRANCE
		camera.size=470
	if not starter:
		camera.focus = terrain.entrance + Vector3(126.0, 0.0, 116.0)
	speed = 1
	menu_open = false
	ui.show_tab("Terrain")
	var map_name: String = str(map_def.get("name", "resort"))
	notify("Resort ready. Build a clubhouse and one playable hole to welcome guests." if not starter else "%s is open. Design, inspect, or let the day unfold." % map_name)

func quit_to_desktop() -> void:
	get_tree().quit()

func _process(dt: float) -> void:
	if sim==null:return
	_visual_time+=dt
	var focus_control=get_viewport().gui_get_focus_owner()
	camera.enabled=not menu_open and not focus_control is LineEdit and not focus_control is TextEdit
	if not menu_open and speed>0:
		var sim_started: int = Time.get_ticks_usec()
		sim.tick(minf(dt,0.1)*60.0*speed)
		_profile_sim_ms += float(Time.get_ticks_usec()-sim_started)/1000.0
	if sim.game_over and not _game_over_handled:
		_game_over_handled = true
		speed = 0
		menu_open = true
		ui.show_menu()
	var sync_started: int = Time.get_ticks_usec()
	_update_people(dt)
	_update_balls(dt)
	_profile_sync_ms += float(Time.get_ticks_usec()-sync_started)/1000.0
	if is_instance_valid(_weather_particles):_weather_particles.position=Vector3(camera.focus.x,42,camera.focus.z)
	_ui_timer+=dt
	_cursor_timer+=dt
	if _ui_timer>=0.5:
		_ui_timer=0
		ui.refresh()
		_poll_log_toasts()
		if sim.settlements!=_last_settlements:
			_last_settlements=sim.settlements
			save_current("Autosave")
		if sim.season_index()!=_last_season:
			_last_season=sim.season_index()
			_apply_season()
	if _cursor_timer>0.09 and not menu_open:
		_cursor_timer=0
		_update_cursor()
	if world != null and world.overlay != "none":
		_overlay_refresh_timer += dt
		if _overlay_refresh_timer >= 2.0:
			_overlay_refresh_timer = 0.0
			_refresh_overlay_visuals()
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
	var over_ui=get_viewport().gui_get_hovered_control()!=null
	if not over_ui or (not event is InputEventPanGesture and not event is InputEventMagnifyGesture):
		camera.handle_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if _photo_mode: toggle_photo_mode()
			set_tool("inspect")
			get_viewport().gui_release_focus()
		elif event.keycode==KEY_SPACE:set_speed(1 if speed==0 else 0)
		elif event.keycode==KEY_X:
			place_rotation+=PI/2
			if is_instance_valid(_ghost):_ghost.rotation.y=place_rotation
		elif event.keycode==KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			if event.shift_pressed:redo()
			else:undo()
		elif event.keycode==KEY_F9:toggle_photo_mode()
		elif event.keycode==KEY_F5:save_current()
		elif event.keycode==KEY_F12:save_screenshot()
		elif event.keycode==KEY_O:cycle_overlay_hotkey()
	if _photo_mode: return
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
	elif not sim.reopen():return
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
	var names={"inspect":"INSPECT YOUR RESORT","raise":"RAISE THE LAND","lower":"LOWER THE LAND","smooth":"SOFTEN THE SLOPES","flatten":"LEVEL THE GROUND","paint":"PAINT · "+TerrainModel.SURFACE_NAMES[paint_surface].to_upper(),"place":"PLACE · "+place_kind.replace("_"," ").to_upper(),"path":"CONNECT THE RESORT","hole_tee":"NEW HOLE · PLACE THE TEE","hole_cup":"NEW HOLE · PLACE THE CUP","edit_tee":"MOVE THE TEE","edit_cup":"MOVE THE CUP","waypoint":"PLAN A LAYUP ROUTE","move_object":"RELOCATE SELECTED OBJECT","green_contour":"GREEN CONTOUR · RAISE","green_contour_lower":"GREEN CONTOUR · LOWER","bunker_shape":"BUNKER SHAPING · LOWER SAND","ob_stakes":"OUT OF BOUNDS · WHITE STAKES","penalty_stakes":"PENALTY AREA · RED STAKES","add_pin":"ADD PIN POSITION","add_tee":"ADD TEE BOX"}
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
		"raise","lower","smooth","flatten","paint","green_contour","green_contour_lower","bunker_shape":
			radius=2 if single_node and tool not in ["paint","green_contour","green_contour_lower","bunker_shape"] else brush_radius
			if tool in ["green_contour","green_contour_lower"]:
				radius=6.0
			elif tool=="bunker_shape":
				radius=brush_radius
			var patch: Dictionary
			if tool in ["green_contour","green_contour_lower"]:
				patch=terrain.plan_green_contour(cursor_point,6.0,brush_strength,tool=="green_contour")
			elif tool=="bunker_shape":
				patch=terrain.plan_bunker_shape(cursor_point,brush_radius,brush_strength)
			else:
				patch=terrain.plan_brush(tool,cursor_point,brush_radius,brush_strength,paint_surface,single_node)
			cost=patch.cost
			if tool in ["green_contour","green_contour_lower","bunker_shape"] and not sim.sandbox:
				var gate_kind="tool:green_shape" if tool in ["green_contour","green_contour_lower"] else "tool:bunker_shape"
				if not sim.can_build(gate_kind):
					color=Color("eb9671")
		"place":
			var def=Catalog.find(place_kind)
			radius=def.get("radius",4)
			cost=def.get("cost",0)
			reason=_placement_reason(place_kind,cursor_point)
			if def.has("influence"):_cursor_root.add_child(_ring(cursor_point,def.influence,Color("b5d593"),0.25))
		"path","ob_stakes","penalty_stakes":
			if pending_point!=Vector3.INF:
				cost=_path_cost(pending_point,cursor_point,place_kind if tool=="path" else tool)
				reason=terrain.path_valid(pending_point,cursor_point,place_kind.begins_with("bridge")) if tool=="path" else ""
				_cursor_root.add_child(TerrainView.line_mesh(_sample_line(pending_point,cursor_point),Color("eee4bd") if tool=="path" else (Color.WHITE if tool=="ob_stakes" else Color("d25555")),3))
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
		"raise","lower","smooth","flatten","paint","green_contour","green_contour_lower","bunker_shape":
			var patch: Dictionary
			if tool in ["green_contour","green_contour_lower"]:
				if not sim.sandbox and not sim.can_build("tool:green_shape"):
					notify("Unlock Green Complex in the Progress tree.");return
				patch=terrain.plan_green_contour(p,6.0,brush_strength,tool=="green_contour")
			elif tool=="bunker_shape":
				if not sim.sandbox and not sim.can_build("tool:bunker_shape"):
					notify("Unlock Bunker Craft in the Progress tree.");return
				patch=terrain.plan_bunker_shape(p,brush_radius,brush_strength)
			else:
				patch=terrain.plan_brush(tool,p,brush_radius,brush_strength,paint_surface,single_node)
			if patch.cost>0:_commit({"kind":"brush","patch":patch,"cost":patch.cost,"center":p,"radius":brush_radius})
		"place":
			var reason=_placement_reason(place_kind,p)
			if not reason.is_empty():notify(reason);return
			var def=Catalog.find(place_kind)
			var obj={"id":terrain.uid(),"kind":place_kind,"pos":p,"rotation":place_rotation,"condition":1.0,"cleanliness":1.0,"level":1}
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
		"ob_stakes","penalty_stakes":
			if pending_point==Vector3.INF:
				pending_point=p
				notify("Choose the other end of the stake line.")
			else:
				var obj={"id":terrain.uid(),"kind":tool,"pos":pending_point,"end":p,"rotation":0.0,"condition":1.0,"cleanliness":1.0}
				if _commit({"kind":"object","before":{},"after":obj,"cost":ceilf(pending_point.distance_to(p)*12.0),"center":pending_point.lerp(p,0.5),"radius":pending_point.distance_to(p)*0.5+4}):pending_point=p
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
		"add_pin":
			if selected_hole.is_empty():return
			if not terrain.on_green(p,selected_hole):
				notify("Place a pin inside the connected green fill.");return
			var pins=selected_hole.get("pins",[]).duplicate()
			if pins.size()>=4:
				notify("Each hole supports up to four pin positions.");return
			pins.append(Vector3(p.x,terrain.height_at(p),p.z))
			edit_hole_value("pins",pins)
		"add_tee":
			if selected_hole.is_empty():return
			if terrain.surface_at(p)!=3:
				notify("Paint a tee surface before adding a tee box.");return
			if not sim.sandbox and not sim.can_build("tool:multi_tee"):
				notify("Unlock Championship Tees in the Progress tree.");return
			add_tee_box(p,"middle")
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
	if not sim.sandbox and not sim.can_build(kind):
		return "Unlock this item in the Progress tree."
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
	var hole={"id":terrain.uid(),"name":"Hole %02d"%(terrain.holes.size()+1),"tee":tee,"cup":cup,"green_radius":14.0,"par":3 if tee.distance_to(cup)<220 else (4 if tee.distance_to(cup)<430 else 5),"open":true,"waypoints":[],"pins":[],"pin_index":0,"tees":[]}
	var commands=[{"kind":"brush","patch":tee_patch},{"kind":"brush","patch":cup_patch},{"kind":"hole","before":{},"after":hole,"index":terrain.holes.size()}]
	if _commit({"kind":"batch","commands":commands,"cost":500+tee_patch.cost+cup_patch.cost,"center":tee.lerp(cup,0.5),"radius":tee.distance_to(cup)*0.5+16}):
		selected_hole=terrain.holes.back()
		set_tool("inspect")
		ui.tab="Holes"
		ui.show_inspector()

func _commit(command: Dictionary, add_history: bool = true, reverse: bool = false) -> bool:
	var amount=float(command.get("cost",0))*(-1 if reverse else 1)
	if amount>0 and not sim.charge(amount,"construction","%s%s"%["Undo " if reverse else "",command.kind.capitalize()]):
		sim.post("warning","construction","Insufficient funds or unpaid bills. Check the finance panel.",Vector3.INF,sim._tab_target("Money"))
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
		var pins_value: Variant = hole.get("pins", [])
		if pins_value is Array:
			for pin_index in range((pins_value as Array).size()):
				var pin_pos: Vector3 = Vector3((pins_value as Array)[pin_index])
				pin_pos.y = terrain.height_at(pin_pos)
				(pins_value as Array)[pin_index] = pin_pos
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
	ui.refresh_view()

func add_tee_box(pos: Vector3, name: String) -> void:
	if selected_hole.is_empty():return
	var tees=selected_hole.get("tees",[]).duplicate()
	for entry in tees:
		if str(entry.get("name",""))==name:
			notify("A %s tee already exists on this hole."%name);return
	tees.append({"pos":Vector3(pos.x,terrain.height_at(pos),pos.z),"name":name})
	edit_hole_value("tees",tees)

func remove_pin(index: int) -> void:
	if selected_hole.is_empty():return
	var pins=selected_hole.get("pins",[]).duplicate()
	if index<0 or index>=pins.size():return
	pins.remove_at(index)
	var after=selected_hole.duplicate(true)
	after["pins"]=pins
	after["pin_index"]=clampi(int(after.get("pin_index",0)),0,maxi(0,pins.size()-1))
	_commit({"kind":"hole","before":selected_hole.duplicate(true),"after":after,"index":terrain.holes.find(selected_hole),"cost":0,"center":after.cup,"radius":after.green_radius})

func remove_tee(name: String) -> void:
	if selected_hole.is_empty():return
	var tees=selected_hole.get("tees",[]).duplicate()
	var filtered=[]
	for entry in tees:
		if str(entry.get("name",""))!=name:
			filtered.append(entry)
	edit_hole_value("tees",filtered)

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
	ui.refresh_view()


func reorder_hole(direction: int) -> void:
	if selected_hole.is_empty():return
	var index=terrain.holes.find(selected_hole)
	var to=clampi(index+direction,0,terrain.holes.size()-1)
	if to!=index:_commit({"kind":"reorder","from":index,"to":to,"cost":0,"center":Vector3.ZERO,"radius":0})
	ui.refresh_view()

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
	ui.refresh_view()

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
	ui.refresh_view()

func demolish_selected() -> void:
	if selected_object.is_empty():return
	var obj=selected_object
	var kind: String = str(obj.get("kind", ""))
	var def: Dictionary = Catalog.find(kind)
	var is_tree: bool = kind in TerrainModel.TREE_KINDS
	var salvage: float = 0.0
	var cost: float = 0.0
	if is_tree:
		cost = float(def.get("cost", 0.0)) * float(terrain.cost_multipliers.get("clear_tree", 1.0))
	elif obj.has("end"):
		salvage = _path_cost(obj.pos, obj.end, kind) * 0.25
	else:
		salvage = float(def.get("cost", 0.0)) * 0.25
	_commit({"kind":"object","before":obj.duplicate(true),"after":{},"cost":cost if is_tree else -salvage,"center":obj.pos.lerp(obj.end,0.5) if obj.has("end") else obj.pos,"radius":obj.pos.distance_to(obj.end)*0.5+8 if obj.has("end") else def.get("radius",6)+4})
	selected_object={}
	ui.show_tab("Build")

func upgrade_object(id: int) -> void:
	for obj in terrain.objects:
		if int(obj.get("id", -1)) != id:
			continue
		var kind: String = str(obj.get("kind", ""))
		var definition: Dictionary = Catalog.find(kind)
		if not definition.has("capacity"):
			notify("Only facilities can be upgraded.")
			return
		var current_level: int = maxi(1, int(obj.get("level", 1)))
		var upgrade: Dictionary = Catalog.facility_upgrade(kind, current_level)
		if upgrade.is_empty():
			notify("This facility is already at maximum level.")
			return
		if not sim.sandbox and upgrade.has("grade") and sim.grade < int(upgrade.get("grade", 1)):
			notify("Reach grade %d to unlock this upgrade." % int(upgrade.get("grade", 1)))
			return
		var after: Dictionary = obj.duplicate(true)
		after["level"] = current_level + 1
		var cost: float = float(upgrade.get("cost", 0.0))
		var center: Vector3 = Vector3(obj.get("pos", Vector3.ZERO))
		var radius: float = float(definition.get("radius", 6.0)) + 4.0
		if _commit({"kind": "object", "before": obj.duplicate(true), "after": after, "cost": cost, "center": center, "radius": radius}):
			notify("Upgraded to %s." % str(upgrade.get("name", "tier %d" % after.level)))
		ui.refresh_view()
		return
	notify("Object not found.")

func toggle_facility_closed(id: int) -> void:
	for obj in terrain.objects:
		if int(obj.get("id", -1)) != id:
			continue
		var definition: Dictionary = Catalog.find(str(obj.get("kind", "")))
		if not definition.has("capacity"):
			notify("Only facilities can be closed.")
			return
		var after: Dictionary = obj.duplicate(true)
		var closed: bool = not bool(obj.get("closed", false))
		after["closed"] = closed
		var center: Vector3 = Vector3(obj.get("pos", Vector3.ZERO))
		var radius: float = float(definition.get("radius", 6.0)) + 4.0
		if _commit({"kind": "object", "before": obj.duplicate(true), "after": after, "cost": 0.0, "center": center, "radius": radius}):
			notify("%s %s to guests." % [definition.get("name", obj.kind), "closed" if closed else "reopened"])
		ui.refresh_view()
		return
	notify("Object not found.")

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
		selected_staff_id=-1
		_draw_selection()
		ui.tab="Build"
		ui.show_inspector()
		return
	for hole in terrain.holes:
		if p.distance_to(hole.cup)<20 or p.distance_to(hole.tee)<14:select_hole(hole.id);return
	clear_selection()
	ui.refresh_view()

func clear_selection() -> void:
	selected_object={}
	selected_hole={}
	selected_guest_id=-1
	selected_staff_id=-1
	follow_selected=false
	_draw_selection()

func select_hole(id: int) -> void:
	for hole in terrain.holes:
		if hole.id==id:
			selected_hole=hole
			selected_object={}
			camera.focus=hole.tee.lerp(hole.cup,0.5)
			selected_guest_id=-1
			selected_staff_id=-1
			camera.size=maxf(140,hole.tee.distance_to(hole.cup)*1.5)
			_draw_selection()
			ui.tab="Holes"
			ui.show_inspector()
			return

func select_guest(id: int) -> void:
	selected_guest_id=id
	selected_staff_id=-1
	selected_object={}
	selected_hole={}
	for guest in sim.guests:
		if guest.id==id:camera.focus=guest.pos;camera.size=minf(camera.size,120)
	set_tool("inspect")
	ui.tab="Guests"
	ui.show_inspector()
	ui.refresh()

func select_staff(id: int) -> void:
	selected_staff_id=id
	selected_guest_id=-1
	selected_object={}
	selected_hole={}
	_draw_selection()
	for worker in sim.staff:
		if worker.id==id:
			camera.focus=worker.pos
			var assignment: Variant = worker.get("assignment", -1)
			if assignment is Dictionary and str(assignment.get("kind", "")) == "hole":
				for hole in terrain.holes:
					if int(hole.get("id", -1)) == int(assignment.get("id", -1)):
						camera.focus = Vector3(hole.get("tee", worker.pos)).lerp(Vector3(hole.get("cup", worker.pos)), 0.5)
						break
			camera.size=100
			break
	ui.tab="Staff"
	ui.show_inspector()

func guest_details() -> String:
	for guest in sim.guests:
		if guest.id==selected_guest_id:
			var patron_line: String = sim.guest_patron_line(guest)
			var patron_text: String = ("\n%s" % patron_line) if not patron_line.is_empty() else ""
			return "%s\n%s · Group %d%s\n\nSkill %.0f%% · Mood %.0f%%\nEnergy %.0f%% · Hunger %.0f%%\nRestroom need %.0f%%\nBudget $%s · Spent $%s\n\nHole %d · %d strokes\nScorecard %s\n\n“%s”\n\nDestination %.0f, %.0f"%[guest.name,str(guest.activity).replace("_"," ").capitalize(),guest.group_id,patron_text,guest.skill*100,guest.mood*100,guest.energy*100,guest.hunger*100,guest.restroom*100,ResortUI.format_money(guest.budget),ResortUI.format_money(guest.spent),guest.hole_index+1,guest.strokes,str(guest.scorecard),guest.thought,guest.destination.x,guest.destination.z]
	return "%d golfers visiting\n%.0f%% overall satisfaction\n\nClick a golfer on the course or select one below to see their day unfold."%[sim.guests.size(),sim.satisfaction*100]

func _draw_selection() -> void:
	for child in _selection_root.get_children():child.free()
	if not selected_object.is_empty():_selection_root.add_child(_ring(selected_object.pos,Catalog.find(selected_object.kind).get("radius",6)+1,Color("f1c777"),0.7))
	if not selected_hole.is_empty():
		var outline=terrain.green_outline_points(selected_hole)
		if outline.size()>=4:
			_selection_root.add_child(TerrainView.line_mesh(outline,Color("fff0bf"),0.45))
		else:
			_selection_root.add_child(_ring(selected_hole.cup,selected_hole.green_radius,Color("fff0bf"),0.4))
		var cup_pos=TerrainModel.effective_cup(selected_hole)
		_selection_root.add_child(_ring(cup_pos,1.2,Color("ffffff"),0.35))
		var points=PackedVector3Array([selected_hole.tee])
		for tee_entry in selected_hole.get("tees",[]):
			points.append(Vector3(tee_entry.get("pos",selected_hole.tee)))
		for p in selected_hole.waypoints:points.append(p)
		points.append(cup_pos)
		for i in range(points.size()-1):_selection_root.add_child(TerrainView.line_mesh(_sample_line(points[i],points[i+1]),Color("eacf8c"),0.5))

func analyze_hole() -> void:
	if selected_hole.is_empty():notify("Select a hole first.");return
	clear_analysis()
	analysis_metrics=ShotEngine.metrics(terrain,selected_hole,30,42)
	analysis_results=analysis_metrics.get("analysis",[])
	analysis_filter=""
	_draw_analysis_results()
	ui.tab="Holes"
	ui.show_inspector()
	notify("Shot lab complete · 90 seeded rounds across three skill levels.")

func show_metric_shots(filter_id: String) -> void:
	if analysis_metrics.is_empty():
		if selected_hole.is_empty():
			notify("Analyze this hole first.")
			return
		analysis_metrics = ShotEngine.metrics(terrain, selected_hole, 30, 42)
		analysis_results = analysis_metrics.get("analysis", [])
	analysis_filter = filter_id
	_draw_analysis_results()
	ui.tab="Holes"
	ui.show_inspector()

func _draw_analysis_results() -> void:
	for child in _shot_root.get_children():
		child.queue_free()
	if analysis_results.is_empty():
		return
	var palette=[Color("79b9d5"),Color("f1cf79"),Color("dd8e70")]
	var filtered: Array = []
	if not analysis_filter.is_empty():
		filtered = ShotEngine.filter_shots(analysis_metrics, analysis_filter)
	for tier in range(analysis_results.size()):
		var result=analysis_results[tier]
		var count=0
		for shot in result.shots:
			if not analysis_filter.is_empty() and not filtered.has(shot):
				continue
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

func clear_analysis() -> void:
	analysis_results.clear()
	analysis_metrics.clear()
	analysis_filter=""
	for child in _shot_root.get_children():child.queue_free()

func toggle_grid() -> void:
	show_grid=not show_grid
	world.set_grid(show_grid)

func set_overlay(value: String) -> void:
	if not is_instance_valid(world):
		return
	var chosen: String = value if OVERLAY_IDS.has(value) else "none"
	world.analytics_source = sim.analytics if sim != null else null
	world.set_overlay(chosen)
	_refresh_overlay_visuals(true)
	if chosen != "none":
		_push_overlay_history(chosen)
	notify("Overlay: "+world.overlay)

func toggle_overlay(value: String) -> void:
	set_overlay("none" if world.overlay == value else value)

func cycle_overlay_hotkey() -> void:
	if _overlay_history.size() < 2:
		set_overlay("traffic")
		return
	var current: String = world.overlay
	var next: String = _overlay_history[1] if current == _overlay_history[0] else _overlay_history[0]
	set_overlay(next)

func _push_overlay_history(value: String) -> void:
	if value == "none":
		return
	_overlay_history.erase(value)
	_overlay_history.insert(0, value)
	if _overlay_history.size() > 2:
		_overlay_history.resize(2)

func _refresh_overlay_visuals(_force: bool = false) -> void:
	if not is_instance_valid(world) or sim == null:
		return
	for child in _overlay_root.get_children():
		child.free()
	var overlay_id: String = world.overlay
	if overlay_id in TerrainView.HEAT_OVERLAYS:
		world.refresh_overlay(sim)
	elif overlay_id == "wear":
		world.analytics_source = sim.analytics
		world.rebuild_all_chunks()
	else:
		world._clear_overlay_mesh()
	if overlay_id == "coverage":
		_rebuild_coverage_discs()
	elif overlay_id == "landings":
		_rebuild_landing_instances()

func _rebuild_coverage_discs() -> void:
	var palette: Dictionary = {
		"clubhouse": Color("f1c777"),
		"driving_range": Color("9fd0a8"),
		"restroom": Color("b5c9df"),
		"snack_kiosk": Color("efb08a"),
		"cart_barn": Color("c9b8df"),
		"maintenance_shed": Color("c8c2b4"),
		"putting_green": Color("8fbf8a"),
		"halfway_house": Color("efb08a"),
		"pro_shop": Color("c9b8df"),
		"restaurant": Color("f1c777"),
		"bar_terrace": Color("efb08a"),
		"spa": Color("b5c9df"),
		"lodge": Color("d8c4a8"),
		"caddie_house": Color("c8c2b4"),
	}
	for obj in terrain.objects:
		var definition: Dictionary = Catalog.find(str(obj.get("kind", "")))
		if not definition.has("capacity"):
			continue
		var radius: float = float(definition.get("radius", 6.0)) * (service_range / 9.0)
		var color: Color = palette.get(str(obj.get("kind", "")), Color("d8e2c8"))
		var ring: MeshInstance3D = _ring(obj.pos, radius, color, 0.35)
		ring.position.y = terrain.height_at(obj.pos) + 0.2
		_overlay_root.add_child(ring)

func _rebuild_landing_instances() -> void:
	var grid: AnalyticsGrid = sim.analytics
	var fair_points: PackedVector3Array = PackedVector3Array()
	var hazard_points: PackedVector3Array = PackedVector3Array()
	for z in range(AnalyticsGrid.SIZE):
		for x in range(AnalyticsGrid.SIZE):
			var center: Vector3 = Vector3((float(x) + 0.5) * AnalyticsGrid.CELL_METERS, 0.0, (float(z) + 0.5) * AnalyticsGrid.CELL_METERS)
			var fair_count: float = grid.value("landings", center)
			var hazard_count: float = grid.value("hazard_landings", center)
			if fair_count > 0.05:
				fair_points.append(Vector3(center.x, terrain.height_at(center) + 0.35, center.z))
			if hazard_count > 0.05:
				hazard_points.append(Vector3(center.x, terrain.height_at(center) + 0.35, center.z))
	_add_landing_batch(fair_points, Color("6fbf73"))
	_add_landing_batch(hazard_points, Color("d8665a"))

func _add_landing_batch(points: PackedVector3Array, color: Color) -> void:
	if points.is_empty():
		return
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.55
	sphere.height = 1.1
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = sphere
	multimesh.instance_count = points.size()
	for index in range(points.size()):
		var transform: Transform3D = Transform3D.IDENTITY
		transform.origin = points[index]
		multimesh.set_instance_transform(index, transform)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = mat
	_overlay_root.add_child(instance)

func overlay_legend() -> Dictionary:
	var overlay_id: String = world.overlay if is_instance_valid(world) else "none"
	var min_label: String = "0"
	var max_label: String = "—"
	var colors: PackedColorArray = PackedColorArray()
	match overlay_id:
		"traffic":
			max_label = "%.0f" % sim.analytics.max_value("traffic")
			colors = PackedColorArray([Color(1, 0.55, 0.18, 0), Color(1, 0.45, 0.08, 0.85)])
		"cart_traffic":
			max_label = "%.0f" % sim.analytics.max_value("cart_traffic")
			colors = PackedColorArray([Color(0.35, 0.65, 1, 0), Color(0.15, 0.45, 0.95, 0.85)])
		"waiting":
			max_label = "%.0f" % sim.analytics.max_value("waiting")
			colors = PackedColorArray([Color(1, 0.92, 0.35, 0), Color(0.92, 0.18, 0.12, 0.85)])
		"landings":
			max_label = "%d fair" % int(sim.analytics.max_value("landings"))
			min_label = "%d hazard" % int(sim.analytics.max_value("hazard_landings"))
			colors = PackedColorArray([Color("6fbf73"), Color("d8665a")])
		"wear":
			max_label = "%.0f%% wear" % (terrain.wear * 100.0)
			colors = PackedColorArray([Color("8bae72"), Color("ad704e")])
		"elevation":
			min_label = "Low"
			max_label = "High"
			colors = PackedColorArray([Color("5a5a5a"), Color("dcdcdc")])
		"beauty":
			min_label = "Low"
			max_label = "High"
			colors = PackedColorArray([Color("ad704e"), Color("a2d88a")])
		"access":
			min_label = "Blocked"
			max_label = "Playable"
			colors = PackedColorArray([Color("b07857"), Color("8bae72")])
		"coverage":
			min_label = "Facility"
			max_label = "%.0f m" % service_range
			colors = PackedColorArray([Color("f1c777", 0.2), Color("f1c777", 0.7)])
	return {"min": min_label, "max": max_label, "colors": colors, "overlay": overlay_id}

func landing_caption() -> String:
	if world.overlay != "landings" or sim == null:
		return ""
	var fair_total: float = 0.0
	var hazard_total: float = 0.0
	for z in range(AnalyticsGrid.SIZE):
		for x in range(AnalyticsGrid.SIZE):
			var center: Vector3 = Vector3((float(x) + 0.5) * AnalyticsGrid.CELL_METERS, 0.0, (float(z) + 0.5) * AnalyticsGrid.CELL_METERS)
			fair_total += sim.analytics.value("landings", center)
			hazard_total += sim.analytics.value("hazard_landings", center)
	return "Fair landings %d · Hazard landings %d" % [int(round(fair_total)), int(round(hazard_total))]

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
			var node=AssetFactory.staff_golfer(str(worker.get("role", "")), worker.id)
			node.position=worker.pos
			_agent_root.add_child(node)
			_staff_nodes[worker.id]=node
		var node=_staff_nodes[worker.id]
		var delta=worker.pos-node.position
		node.position=node.position.lerp(worker.pos,minf(1,dt*10))
		if delta.length()>0.2:node.rotation.y=atan2(delta.x,delta.z)+PI
		var staff_activity: String = "mowing" if str(worker.get("activity", "")) == "maintaining" else ("walking" if delta.length()>0.5 else "idle")
		AssetFactory.animate_golfer(node, staff_activity, _visual_time * 4)
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
	_last_settlements=sim.settlements
	_last_season=sim.season_index()
	_apply_season()
	_last_toast_log_id=sim.log.back().get("id",0) if not sim.log.is_empty() else 0
	selected_hole={}
	selected_object={}
	selected_guest_id=-1
	selected_staff_id=-1
	undo_stack.clear()
	redo_stack.clear()
	clear_analysis()
	var c=data.get("camera",{})
	camera.focus=c.get("focus",terrain.entrance+Vector3(184,0,174))
	camera.yaw=c.get("yaw",0.3)
	camera.size=c.get("size",480)
	menu_open=false
	set_tool("inspect")
	ui.show_tab("Terrain")
	notify("Loaded “%s”. Active visits and the simulation clock were restored."%name_value)

func notify(message: String) -> void:
	if sim!=null and not message.is_empty():
		sim.post("info","system",message)
	if is_instance_valid(ui) and is_instance_valid(ui.status_label):
		ui.status_label.text=message
	_notice_time=_visual_time

func _poll_log_toasts() -> void:
	if sim==null or sim.log.is_empty() or not is_instance_valid(ui):
		return
	var latest: Dictionary = sim.log.back()
	var latest_id: int = int(latest.get("id",0))
	if latest_id<=_last_toast_log_id:
		return
	for index in range(sim.log.size()):
		var entry: Dictionary = sim.log[index]
		var entry_id: int = int(entry.get("id",0))
		if entry_id<=_last_toast_log_id:
			continue
		ui.show_toast(entry)
		if str(entry.get("severity",""))=="critical" and pause_on_critical:
			set_speed(0)
	_last_toast_log_id=latest_id

func jump_to(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var pos: Vector3 = entry.get("pos",Vector3.INF)
	if pos.is_finite():
		camera.focus=pos
		camera.size=minf(camera.size,180)
	var target: Dictionary = entry.get("target",{})
	match str(target.get("kind","")):
		"hole":
			select_hole(int(target.get("id",-1)))
		"guest":
			select_guest(int(target.get("id",-1)))
		"staff":
			select_staff(int(target.get("id",-1)))
		"object":
			for obj in terrain.objects:
				if int(obj.get("id",-1))==int(target.get("id",-1)):
					selected_object=obj
					selected_hole={}
					selected_guest_id=-1
					selected_staff_id=-1
					_draw_selection()
					ui.tab="Build"
					ui.show_inspector()
					return
		"tab":
			var tab_id: int = int(target.get("id",7))
			for tab_name in ResortSimulation.TAB_IDS:
				if int(ResortSimulation.TAB_IDS[tab_name])==tab_id:
					ui.show_tab(tab_name)
					break
	if sim!=null:
		sim.last_seen_log_id=maxi(sim.last_seen_log_id,int(entry.get("id",0)))
		ui.refresh_bell()

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


func toggle_photo_mode() -> void:
	_photo_mode=not _photo_mode
	if _photo_mode:
		set_tool("inspect")
		set_overlay("none")
	ui.root.visible=not _photo_mode
	_cursor_root.visible=not _photo_mode
	_selection_root.visible=not _photo_mode
	for hole in world.hole_root.get_children():
		for part in hole.get_children():
			if part is Label3D: part.visible=not _photo_mode

func reset_resort_camera() -> void:
	camera.reset_view(terrain.entrance)
	if terrain.map_id == "cedar_house" and not terrain.holes.is_empty():
		var center := Vector3.ZERO
		for hole in terrain.holes: center+=(hole.tee+hole.cup)*0.5
		camera.focus=center/terrain.holes.size()
		camera.size=470


func save_screenshot() -> void:
	var directory: String = OS.get_user_data_dir().path_join("screenshots")
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		notify("Could not create the screenshots folder.")
		return
	var stamp: String = Time.get_datetime_string_from_system().replace(":","-")
	var filename: String = directory.path_join("resort-%s-%d.png" % [stamp,Time.get_ticks_msec()])
	error=get_viewport().get_texture().get_image().save_png(filename)
	notify("Screenshot saved: "+filename if error==OK else "Could not save screenshot.")
