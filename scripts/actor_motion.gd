class_name ActorMotion
extends RefCounted

## Cosmetic golfer/cart motion (graphics package 15). Presentation-only; never reads or
## writes simulation RNG, guest dictionaries, or shot outcomes.

const SCHEMA_VERSION: int = 1

# Visual shot timeline — package 16 consumes these constants and helpers.
const SWING_TOTAL: float = 0.70
const PUTT_TOTAL: float = 0.55
const SWING_ADDRESS_END: float = 0.18
const SWING_BACKSWING_END: float = 0.48
const SWING_CONTACT_END: float = 0.52
const SWING_FOLLOW_END: float = 0.88
const WALK_STRIDE: float = 1.35
const TELEPORT_DISTANCE: float = 8.0
const WHEEL_RADIUS: float = 0.28
const WHEEL_CIRCUMFERENCE: float = TAU * WHEEL_RADIUS
const CART_WHEEL_BASE: float = 1.05
const CART_TRACK: float = 0.92

var golfer_cosmetic: Dictionary = {}
var cart_cosmetic: Dictionary = {}
var visual_shots: Dictionary = {}


func reset() -> void:
	golfer_cosmetic.clear()
	cart_cosmetic.clear()
	visual_shots.clear()


func presentation_dt(dt: float, speed: int, menu_open: bool, photo_mode: bool) -> float:
	if menu_open or photo_mode or speed <= 0:
		return 0.0
	return dt * float(speed)


static func shot_visual_timeline(shot: Dictionary, is_putt: bool) -> Dictionary:
	var swing_duration: float = PUTT_TOTAL if is_putt else SWING_TOTAL
	var contact_time: float = swing_duration * 0.50
	var flight_duration: float = maxf(0.8, float(shot.get("physics_duration", 1.6)))
	return {
		"schema_version": SCHEMA_VERSION,
		"swing_duration": swing_duration,
		"contact_time": contact_time,
		"launch_time": contact_time,
		"flight_duration": flight_duration,
		"total_duration": contact_time + flight_duration,
	}


static func swing_pose(time: float, is_putt: bool) -> Dictionary:
	var timeline: Dictionary = shot_visual_timeline({}, is_putt)
	var swing_duration: float = float(timeline["swing_duration"])
	var t: float = clampf(time / maxf(0.001, swing_duration), 0.0, 1.0)
	if is_putt:
		return {"activity": "putting", "phase": t}
	if t < SWING_ADDRESS_END:
		return {"activity": "address", "phase": t / SWING_ADDRESS_END}
	if t < SWING_BACKSWING_END:
		return {
			"activity": "backswing",
			"phase": (t - SWING_ADDRESS_END) / maxf(0.001, SWING_BACKSWING_END - SWING_ADDRESS_END),
		}
	if t < SWING_CONTACT_END:
		return {
			"activity": "contact",
			"phase": (t - SWING_BACKSWING_END) / maxf(0.001, SWING_CONTACT_END - SWING_BACKSWING_END),
		}
	if t < SWING_FOLLOW_END:
		return {
			"activity": "follow_through",
			"phase": (t - SWING_CONTACT_END) / maxf(0.001, SWING_FOLLOW_END - SWING_CONTACT_END),
		}
	return {"activity": "idle", "phase": clampf((t - SWING_FOLLOW_END) / maxf(0.001, 1.0 - SWING_FOLLOW_END), 0.0, 1.0)}


static func shot_aim_yaw(shot: Dictionary) -> float:
	var start: Vector3 = Vector3(shot.get("start", Vector3.ZERO))
	var landing: Vector3 = Vector3(shot.get("landing", start))
	var flat: Vector2 = Vector2(landing.x - start.x, landing.z - start.z)
	if flat.length_squared() < 0.04:
		return 0.0
	return atan2(flat.x, flat.y)


static func animation_detail(distance: float, settings: GraphicsSettings) -> int:
	if distance >= settings.animation_distance_far:
		return 0
	if distance >= settings.animation_distance_mid:
		return 1
	return 2


static func should_tick_cosmetic(frame_counter: int, detail: int, settings: GraphicsSettings) -> bool:
	if detail >= 2:
		return true
	if detail == 1:
		var skip: int = maxi(1, settings.animation_update_stride)
		return frame_counter % skip == 0
	return frame_counter % maxi(2, settings.animation_update_stride + 1) == 0


func ensure_golfer_state(actor_id: int) -> Dictionary:
	if not golfer_cosmetic.has(actor_id):
		golfer_cosmetic[actor_id] = {
			"walk_distance": 0.0,
			"last_pos": Vector3.ZERO,
			"body_yaw": 0.0,
			"aim_yaw": 0.0,
			"ground_pitch": 0.0,
			"ground_roll": 0.0,
			"frame": 0,
		}
	return golfer_cosmetic[actor_id]


func ensure_cart_state(group_id: int) -> Dictionary:
	if not cart_cosmetic.has(group_id):
		cart_cosmetic[group_id] = {
			"distance": 0.0,
			"heading": 0.0,
			"steer": 0.0,
			"suspension": 0.0,
			"pitch": 0.0,
			"roll": 0.0,
			"last_pos": Vector3.ZERO,
			"frame": 0,
		}
	return cart_cosmetic[group_id]


func erase_actor(actor_id: int) -> void:
	golfer_cosmetic.erase(actor_id)
	visual_shots.erase(actor_id)


func erase_cart(group_id: int) -> void:
	cart_cosmetic.erase(group_id)


func register_shot(actor_id: int, shot: Dictionary) -> void:
	visual_shots[actor_id] = {
		"shot": shot.duplicate(true),
		"time": 0.0,
		"serial": int(shot.get("serial", 0)),
	}


func advance_visual_shots(presentation_dt: float) -> void:
	for actor_id in visual_shots.keys():
		var entry: Dictionary = visual_shots[actor_id]
		entry["time"] = float(entry.get("time", 0.0)) + presentation_dt


func ball_position(actor_id: int) -> Vector3:
	var entry: Variant = visual_shots.get(actor_id)
	if entry == null or not entry is Dictionary:
		return Vector3.ZERO
	var data: Dictionary = entry
	var shot: Dictionary = data.get("shot", {})
	if shot.is_empty():
		return Vector3(shot.get("start", Vector3.ZERO))
	var is_putt: bool = str(shot.get("club", "")) == "putter"
	var timeline: Dictionary = shot_visual_timeline(shot, is_putt)
	var time: float = float(data.get("time", 0.0))
	var contact_time: float = float(timeline["contact_time"])
	if time < contact_time:
		return Vector3(shot.get("start", Vector3.ZERO))
	var flight_t: float = clampf(
		(time - contact_time) / maxf(0.001, float(timeline["flight_duration"])),
		0.0,
		1.0,
	)
	var p: Vector3
	if flight_t < 0.8:
		var f: float = flight_t / 0.8
		p = Vector3(shot.get("start", Vector3.ZERO)).lerp(Vector3(shot.get("landing", Vector3.ZERO)), f)
		p.y += sin(f * PI) * float(shot.get("arc", 0.0)) + 0.25
	else:
		p = Vector3(shot.get("landing", Vector3.ZERO)).lerp(Vector3(shot.get("end", Vector3.ZERO)), (flight_t - 0.8) / 0.2)
		p.y += 0.2 + absf(sin((flight_t - 0.8) * PI * 15.0)) * 0.3 * (1.0 - flight_t)
	return p


func ball_visible(actor_id: int) -> bool:
	var entry: Variant = visual_shots.get(actor_id)
	if entry == null or not entry is Dictionary:
		return true
	var shot: Dictionary = (entry as Dictionary).get("shot", {})
	if shot.is_empty():
		return true
	var is_putt: bool = str(shot.get("club", "")) == "putter"
	var timeline: Dictionary = shot_visual_timeline(shot, is_putt)
	var time: float = float((entry as Dictionary).get("time", 0.0))
	var flight_t: float = clampf(
		(time - float(timeline["contact_time"])) / maxf(0.001, float(timeline["flight_duration"])),
		0.0,
		1.0,
	)
	return not bool(shot.get("holed", false)) or flight_t < 1.0


func update_golfer(
	actor_id: int,
	node: Node3D,
	sim_pos: Vector3,
	activity: String,
	shot: Dictionary,
	visual_time: float,
	terrain,
	camera_focus: Vector3,
	settings: GraphicsSettings,
	presentation_dt: float,
	interp_dt: float,
	group_offset: Vector3 = Vector3.ZERO,
) -> void:
	var state: Dictionary = ensure_golfer_state(actor_id)
	state["frame"] = int(state.get("frame", 0)) + 1
	var target_position: Vector3 = sim_pos + group_offset
	var previous: Vector3 = node.position
	if state["last_pos"] == Vector3.ZERO:
		state["last_pos"] = target_position
	var jump: float = Vector2(target_position.x - state["last_pos"].x, target_position.z - state["last_pos"].z).length()
	if jump > TELEPORT_DISTANCE:
		state["walk_distance"] = 0.0
		state["body_yaw"] = node.rotation.y
		node.position = target_position
	previous = node.position
	node.position = node.position.lerp(target_position, minf(1.0, interp_dt * 10.0))
	var delta: Vector3 = target_position - previous
	if Vector2(delta.x, delta.z).length() > 0.2:
		var move_yaw: float = atan2(delta.x, delta.z) + PI
		state["body_yaw"] = lerp_angle(float(state.get("body_yaw", move_yaw)), move_yaw, minf(1.0, interp_dt * 8.0))
	if Vector2(delta.x, delta.z).length() > 0.05:
		state["walk_distance"] = float(state.get("walk_distance", 0.0)) + Vector2(delta.x, delta.z).length()
	state["last_pos"] = target_position

	var distance: float = node.position.distance_to(camera_focus)
	var detail: int = animation_detail(distance, settings)
	var pose_activity: String = activity
	var pose_phase: float = fmod(float(state.get("walk_distance", 0.0)) / WALK_STRIDE, 1.0)
	var aim_yaw: float = float(state.get("aim_yaw", state.get("body_yaw", 0.0)))
	var swing_active: bool = visual_shots.has(actor_id)
	if swing_active:
		var swing_data: Dictionary = visual_shots[actor_id]
		var active_shot: Dictionary = swing_data.get("shot", shot)
		var is_putt: bool = str(active_shot.get("club", "")) == "putter"
		var swing_time: float = float(swing_data.get("time", 0.0))
		var timeline: Dictionary = shot_visual_timeline(active_shot, is_putt)
		if swing_time < float(timeline["swing_duration"]) * 1.05:
			var pose: Dictionary = swing_pose(swing_time, is_putt)
			pose_activity = str(pose.get("activity", "swinging"))
			pose_phase = float(pose.get("phase", 0.0))
			aim_yaw = shot_aim_yaw(active_shot)
			state["aim_yaw"] = aim_yaw
	elif activity == "walking" or activity == "walking_to_ball" or activity == "walking_to_cart" or activity == "walking_from_cart":
		pose_activity = "walking"
	elif activity == "riding":
		pose_activity = "seated"
	elif activity == "idle" or activity == "watching":
		pose_activity = "idle"
		pose_phase = fmod(visual_time * 0.35, 1.0)

	if should_tick_cosmetic(int(state.get("frame", 0)), detail, settings) and terrain != null:
		_apply_ground_pose(node, state, terrain, target_position, interp_dt, detail)

	var body_yaw: float = float(state.get("body_yaw", 0.0))
	if swing_active and pose_activity in ["follow_through", "contact", "backswing", "address"]:
		node.rotation.y = lerp_angle(body_yaw, aim_yaw, clampf(pose_phase * 0.65, 0.0, 0.85))
	else:
		node.rotation.y = body_yaw

	var simplified: bool = detail <= 0
	AssetFactory.animate_golfer(node, pose_activity, pose_phase, aim_yaw, simplified)


func update_staff(
	actor_id: int,
	node: Node3D,
	sim_pos: Vector3,
	activity: String,
	terrain,
	camera_focus: Vector3,
	settings: GraphicsSettings,
	visual_time: float,
	interp_dt: float,
) -> void:
	var state: Dictionary = ensure_golfer_state(actor_id)
	state["frame"] = int(state.get("frame", 0)) + 1
	var previous: Vector3 = node.position
	if state["last_pos"] == Vector3.ZERO:
		state["last_pos"] = sim_pos
	var jump: float = Vector2(sim_pos.x - state["last_pos"].x, sim_pos.z - state["last_pos"].z).length()
	if jump > TELEPORT_DISTANCE:
		state["walk_distance"] = 0.0
		node.position = sim_pos
	previous = node.position
	node.position = node.position.lerp(sim_pos, minf(1.0, interp_dt * 10.0))
	var delta: Vector3 = sim_pos - previous
	if Vector2(delta.x, delta.z).length() > 0.2:
		var move_yaw: float = atan2(delta.x, delta.z) + PI
		state["body_yaw"] = lerp_angle(float(state.get("body_yaw", move_yaw)), move_yaw, minf(1.0, interp_dt * 8.0))
	if Vector2(delta.x, delta.z).length() > 0.05:
		state["walk_distance"] = float(state.get("walk_distance", 0.0)) + Vector2(delta.x, delta.z).length()
	state["last_pos"] = sim_pos
	node.rotation.y = float(state.get("body_yaw", node.rotation.y))
	var distance: float = node.position.distance_to(camera_focus)
	var detail: int = animation_detail(distance, settings)
	if should_tick_cosmetic(int(state.get("frame", 0)), detail, settings) and terrain != null:
		_apply_ground_pose(node, state, terrain, sim_pos, interp_dt, detail)
	var pose_activity: String = activity
	var pose_phase: float = fmod(float(state.get("walk_distance", 0.0)) / WALK_STRIDE, 1.0)
	if activity == "idle":
		pose_phase = fmod(visual_time * 0.35, 1.0)
	AssetFactory.animate_golfer(node, pose_activity, pose_phase, NAN, detail <= 0)


func update_cart(
	group_id: int,
	node: Node3D,
	target_pos: Vector3,
	terrain,
	camera_focus: Vector3,
	settings: GraphicsSettings,
	interp_dt: float,
) -> void:
	var state: Dictionary = ensure_cart_state(group_id)
	state["frame"] = int(state.get("frame", 0)) + 1
	if state["last_pos"] == Vector3.ZERO:
		state["last_pos"] = target_pos
		node.position = target_pos
	var jump: float = Vector2(target_pos.x - state["last_pos"].x, target_pos.z - state["last_pos"].z).length()
	if jump > TELEPORT_DISTANCE:
		state["distance"] = 0.0
		state["heading"] = node.rotation.y
		node.position = target_pos
	var old: Vector3 = node.position
	node.position = old.lerp(target_pos, minf(1.0, interp_dt * 8.0))
	var difference: Vector3 = target_pos - old
	var travel: float = Vector2(difference.x, difference.z).length()
	if travel > 0.01:
		state["distance"] = float(state.get("distance", 0.0)) + travel
		var heading: float = atan2(difference.x, difference.z)
		var steer_delta: float = angle_difference(float(state.get("heading", heading)), heading)
		state["steer"] = lerpf(float(state.get("steer", 0.0)), clampf(steer_delta, -0.55, 0.55), minf(1.0, interp_dt * 6.0))
		state["heading"] = heading
		node.rotation.y = lerp_angle(node.rotation.y, heading, minf(1.0, interp_dt * 8.0))
	state["last_pos"] = target_pos

	var distance: float = node.position.distance_to(camera_focus)
	var detail: int = animation_detail(distance, settings)
	if detail <= 0 and not should_tick_cosmetic(int(state.get("frame", 0)), detail, settings):
		return

	var wheel_spin: float = float(state.get("distance", 0.0)) / WHEEL_CIRCUMFERENCE
	var steer: float = float(state.get("steer", 0.0))
	var pitch: float = float(state.get("pitch", 0.0))
	var roll: float = float(state.get("roll", 0.0))
	var suspension: float = float(state.get("suspension", 0.0))
	if terrain != null and detail > 0:
		var forward: Vector3 = Vector3(sin(node.rotation.y), 0.0, cos(node.rotation.y))
		var right: Vector3 = Vector3(forward.z, 0.0, -forward.x)
		var front: Vector3 = node.position + forward * CART_WHEEL_BASE
		var rear: Vector3 = node.position - forward * CART_WHEEL_BASE * 0.35
		var left: Vector3 = node.position - right * CART_TRACK * 0.5
		var right_pos: Vector3 = node.position + right * CART_TRACK * 0.5
		var front_h: float = float(terrain.height_at(front))
		var rear_h: float = float(terrain.height_at(rear))
		var left_h: float = float(terrain.height_at(left))
		var right_h: float = float(terrain.height_at(right_pos))
		var target_pitch: float = clampf(atan2(front_h - rear_h, CART_WHEEL_BASE * 1.35), -0.22, 0.22)
		var target_roll: float = clampf(atan2(right_h - left_h, CART_TRACK), -0.18, 0.18)
		var ground_y: float = (front_h + rear_h + left_h + right_h) * 0.25
		var target_suspension: float = ground_y - float(terrain.height_at(node.position))
		pitch = lerpf(pitch, target_pitch, minf(1.0, interp_dt * 5.0))
		roll = lerpf(roll, target_roll, minf(1.0, interp_dt * 5.0))
		suspension = lerpf(suspension, clampf(target_suspension, -0.12, 0.12), minf(1.0, interp_dt * 7.0))
		state["pitch"] = pitch
		state["roll"] = roll
		state["suspension"] = suspension
		node.position.y = lerpf(node.position.y, target_pos.y + suspension, minf(1.0, interp_dt * 10.0))

	var body: Node3D = node.get_node_or_null("Body") as Node3D
	if body == null:
		body = node
	body.rotation.x = pitch
	body.rotation.z = roll
	_apply_cart_wheels(node, wheel_spin, steer, detail)


static func _apply_ground_pose(node: Node3D, state: Dictionary, terrain, pos: Vector3, interp_dt: float, detail: int) -> void:
	var slope: Vector2 = terrain.slope_at(pos)
	var target_pitch: float = clampf(-slope.y * 0.07, -0.16, 0.16)
	var target_roll: float = clampf(slope.x * 0.07, -0.16, 0.16)
	var pitch: float = lerpf(float(state.get("ground_pitch", 0.0)), target_pitch, minf(1.0, interp_dt * 6.0))
	var roll: float = lerpf(float(state.get("ground_roll", 0.0)), target_roll, minf(1.0, interp_dt * 6.0))
	state["ground_pitch"] = pitch
	state["ground_roll"] = roll
	var torso: Node3D = node.get_node_or_null("Torso") as Node3D
	if torso != null:
		torso.rotation.x = pitch
		torso.rotation.z = roll
	if detail >= 2:
		var walk_phase: float = fmod(float(state.get("walk_distance", 0.0)) / WALK_STRIDE, 1.0)
		var stride: float = sin(walk_phase * TAU)
		var leg_l: Node3D = node.get_node_or_null("LegL") as Node3D
		var leg_r: Node3D = node.get_node_or_null("LegR") as Node3D
		if leg_l != null:
			leg_l.position.y = clampf(-slope.y * 0.02, -0.06, 0.06) + maxf(0.0, -stride) * 0.04
		if leg_r != null:
			leg_r.position.y = clampf(slope.y * 0.02, -0.06, 0.06) + maxf(0.0, stride) * 0.04


static func _apply_cart_wheels(node: Node3D, spin: float, steer: float, detail: int) -> void:
	var wheels_root: Node3D = node.get_node_or_null("Wheels") as Node3D
	if wheels_root == null:
		return
	var spin_angle: float = spin * TAU
	for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
		var wheel: Node3D = wheels_root.get_node_or_null(wheel_name) as Node3D
		if wheel == null:
			continue
		if detail <= 0:
			wheel.rotation.x = spin_angle
			continue
		wheel.rotation.x = spin_angle
		if wheel_name == "WheelFL":
			wheel.rotation.y = steer
		elif wheel_name == "WheelFR":
			wheel.rotation.y = steer
