class_name CosmeticEffectEvent
extends RefCounted

## Cosmetic shot/contact events for graphics package 16. Presentation-only.

enum Type {
	SAND_PUFF = 0,
	TURF_DIVOT = 1,
	WATER_RIPPLE = 2,
}

const SCHEMA_VERSION: int = 1
const DEDUP_CAPACITY: int = 128

const TYPE_NAMES: Array[String] = ["sand_puff", "turf_divot", "water_ripple"]

const PRIORITY: Dictionary = {
	Type.SAND_PUFF: 2,
	Type.TURF_DIVOT: 1,
	Type.WATER_RIPPLE: 3,
}


static func make_id(actor_id: int, shot_serial: int, type: Type) -> int:
	return actor_id * 1_000_000 + shot_serial * 10 + int(type)


static func make_event(
	actor_id: int,
	shot_serial: int,
	type: Type,
	world_pos: Vector3,
	surface_or_body_id: int,
	visual_time: float,
) -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"id": make_id(actor_id, shot_serial, type),
		"type": int(type),
		"type_name": TYPE_NAMES[int(type)],
		"actor_id": actor_id,
		"serial": shot_serial,
		"position": world_pos,
		"surface_id": surface_or_body_id,
		"visual_time": visual_time,
		"priority": PRIORITY.get(type, 0),
	}


static func contact_events_for_shot(
	actor_id: int,
	shot: Dictionary,
	visual_time: float,
	terrain,
) -> Array:
	var events: Array = []
	var serial: int = int(shot.get("serial", 0))
	if serial <= 0:
		return events
	var landing: Vector3 = Vector3(shot.get("landing", shot.get("start", Vector3.ZERO)))
	var surface: int = int(shot.get("landing_surface", shot.get("surface", -1)))
	if surface < 0 and terrain != null:
		surface = int(terrain.surface_at(landing))
	var is_putt: bool = str(shot.get("club", "")) == "putter"

	if surface == 4:
		events.append(make_event(actor_id, serial, Type.SAND_PUFF, landing, surface, visual_time))
	elif not is_putt and surface in [0, 1, 3]:
		events.append(make_event(actor_id, serial, Type.TURF_DIVOT, landing, surface, visual_time))

	if surface == 5 and terrain != null:
		var body: Dictionary = terrain.water_body_at(landing)
		var body_id: int = int(body.get("body_id", -1))
		if body_id >= 0 and float(body.get("depth", 0.0)) > 0.0:
			events.append(make_event(actor_id, serial, Type.WATER_RIPPLE, landing, body_id, visual_time))
	return events
