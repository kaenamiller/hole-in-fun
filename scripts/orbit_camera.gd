class_name ResortCamera
extends Camera3D

var focus = Vector3(248,0,238)
var yaw = 0.30
var distance = 550.0
var elevation = 1.05
var drag_mode = 0
var enabled = true

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	size = 420
	near = 0.5
	far = 2400
	current = true
	_update_transform()

func _process(dt: float) -> void:
	if not enabled: return
	var direction = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y-=1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y+=1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x-=1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x+=1
	var speed = size*0.55*dt
	focus += (global_transform.basis.x*direction.x+Vector3(sin(yaw),0,cos(yaw))*direction.y)*speed
	if Input.is_physical_key_pressed(KEY_Z): size=minf(1250,size*(1.0+0.95*dt))
	if Input.is_physical_key_pressed(KEY_C): size=maxf(28,size*(1.0-0.66*dt))
	if Input.is_physical_key_pressed(KEY_R): elevation=minf(2.4,elevation+dt*0.9)
	if Input.is_physical_key_pressed(KEY_F): elevation=maxf(0.25,elevation-dt*0.9)
	if Input.is_physical_key_pressed(KEY_Q): yaw+=dt*0.8
	if Input.is_physical_key_pressed(KEY_E): yaw-=dt*0.8
	focus.x=clampf(focus.x,-20,1044)
	focus.z=clampf(focus.z,-20,1044)
	_update_transform()

func handle_input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_MIDDLE: drag_mode=1 if event.pressed else 0
		if event.button_index==MOUSE_BUTTON_RIGHT: drag_mode=2 if event.pressed else 0
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: size=maxf(28,size*0.89)
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: size=minf(1250,size*1.12)
	elif event is InputEventMouseMotion:
		if drag_mode==1:
			focus-=global_transform.basis.x*event.relative.x*size/get_viewport().get_visible_rect().size.y
			focus-=Vector3(sin(yaw),0,cos(yaw))*event.relative.y*size/get_viewport().get_visible_rect().size.y*1.5
		elif drag_mode==2: yaw-=event.relative.x*0.006
	elif event is InputEventPanGesture:
		var viewport_height=get_viewport().get_visible_rect().size.y
		focus-=global_transform.basis.x*event.delta.x*size/viewport_height
		focus-=Vector3(sin(yaw),0,cos(yaw))*event.delta.y*size/viewport_height*1.5
	elif event is InputEventMagnifyGesture:
		if event.factor>1.0: size=maxf(28,size/event.factor)
		elif event.factor<1.0: size=minf(1250,size/event.factor)
	_update_transform()

func _update_transform() -> void:
	var framed_focus=focus+Vector3(cos(yaw),0,-sin(yaw))*size*0.14
	position=framed_focus+Vector3(sin(yaw)*distance, distance*elevation, cos(yaw)*distance)
	look_at(framed_focus,Vector3.UP)

func reset_view() -> void:
	focus=Vector3(248,0,238)
	yaw=0.30
	size=420
	elevation=1.05
	_update_transform()

func ground_point(screen: Vector2, terrain: TerrainModel) -> Vector3:
	var origin=project_ray_origin(screen)
	var direction=project_ray_normal(screen)
	if absf(direction.y)<0.0001:return Vector3.INF
	var t=-origin.y/direction.y
	var p=origin+direction*t
	for i in range(5):
		t=(terrain.height_at(p)-origin.y)/direction.y
		p=origin+direction*t
	return p
