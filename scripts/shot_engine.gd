class_name ShotEngine
extends RefCounted

## Deterministic, bounded golf shot planning shared by the live game and previews.
##
## The engine deliberately talks only to the terrain methods documented in
## docs/INTERFACES.md.  It contains no scene or node dependencies, so a shot
## can be planned from a headless simulation as well as from the 3D view.

const MAX_STROKES: int = 14
const MAX_WAYPOINTS_CHECKED: int = 6
const MAX_ANCHOR_CHECKS: int = 2

const _CLUBS: Array = [
	{"name": "putter", "carry": 18.0, "arc": 0.35, "roll": 1.2},
	{"name": "chip", "carry": 35.0, "arc": 2.5, "roll": 3.0},
	{"name": "wedge", "carry": 95.0, "arc": 12.0, "roll": 2.0},
	{"name": "9-iron", "carry": 125.0, "arc": 18.0, "roll": 2.4},
	{"name": "7-iron", "carry": 150.0, "arc": 22.0, "roll": 2.8},
	{"name": "5-iron", "carry": 175.0, "arc": 26.0, "roll": 3.1},
	{"name": "3-wood", "carry": 205.0, "arc": 31.0, "roll": 4.8},
	{"name": "driver", "carry": 230.0, "arc": 36.0, "roll": 6.0}
]

static func shot(terrain, start: Vector3, hole: Dictionary, skill: float, rng: RandomNumberGenerator) -> Dictionary:
	var safe_skill: float = clampf(skill, 0.0, 1.0)
	var source_rng: RandomNumberGenerator = rng
	if source_rng == null:
		source_rng = RandomNumberGenerator.new()
		source_rng.seed = 1

	var cup: Vector3 = Vector3(hole.get("cup", start))
	var tee: Vector3 = Vector3(hole.get("tee", start))
	var green_radius: float = maxf(3.0, float(hole.get("green_radius", 16.0)))
	var start_surface: int = int(terrain.surface_at(start))
	var start_ground: Vector3 = _ground_point(terrain, start)
	var plan: Dictionary = _choose_target(terrain, start_ground, cup, hole, safe_skill, start_surface)
	var target: Vector3 = Vector3(plan.get("target", cup))
	var target_reason: String = String(plan.get("reason", "approach"))
	var distance: float = _flat_distance(start_ground, target)
	var slope: Vector2 = _read_slope(terrain, start_ground)
	var elevation: float = float(terrain.height_at(target)) - float(terrain.height_at(start_ground))
	var club: Dictionary = _choose_club(distance, start_surface, safe_skill, slope, elevation)
	var club_name: String = String(club.get("name", "wedge"))
	var carry: float = float(club.get("carry", 95.0)) * _skill_distance_factor(safe_skill)
	carry *= _surface_distance_factor(start_surface)
	carry *= _slope_distance_factor(slope)
	if elevation > 0.0:
		carry *= clampf(1.0 - elevation / 180.0, 0.74, 1.0)
	var direction: Vector3 = _flat_direction(start_ground, target)
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var dispersion: float = 0.018 + (1.0 - safe_skill) * 0.105
	if start_surface == 0:
		dispersion += 0.018
	elif start_surface == 4:
		dispersion += 0.045
	var dispersion_meters: float = maxf(1.5, distance * dispersion)
	var along_error: float = _noise(source_rng) * dispersion_meters * 1.15
	var side_error: float = _noise(source_rng) * dispersion_meters
	# Uphill shots come up short and downhill shots tend to run through.
	along_error -= elevation * 0.26
	along_error -= maxf(0.0, distance - carry) * 0.3
	var landing: Vector3 = target + direction * along_error + side * side_error
	landing = _ground_point(terrain, landing)
	var landing_surface: int = int(terrain.surface_at(landing))
	var hazard: bool = landing_surface == 5 or not bool(terrain.playable(landing))
	var penalty: int = 0
	var end: Vector3 = landing
	var reason: String = target_reason
	var bounce: float = float(club.get("arc", 10.0))
	var roll: float = float(club.get("roll", 2.0))
	var holed: bool = false
	if hazard:
		penalty = 1
		var safe_landing: Vector3 = Vector3(terrain.nearest_safe(landing))
		end = _ground_point(terrain, safe_landing)
		reason = "water_recovery" if landing_surface == 5 else "out_of_bounds_recovery"
		bounce = 1.0
		roll = 0.0
	else:
		if landing_surface == 4:
			reason = "sand_lie" if reason == "approach" else reason + "_sand"
			roll *= 0.45
		elif landing_surface == 2:
			roll *= 0.35
		var roll_direction: Vector3 = _flat_direction(start_ground, landing)
		end = _ground_point(terrain, landing + roll_direction * roll)
		var end_distance: float = _flat_distance(end, cup)
		var end_surface: int = int(terrain.surface_at(end))
		if end_surface == 2 and end_distance <= maxf(0.65, 0.55 + safe_skill * 0.95):
			holed = true
		elif club_name == "putter" and end_distance <= maxf(0.45, 0.6 + safe_skill * 0.9):
			holed = true
		elif end_surface == 2 and end_distance <= 1.0 and source_rng.randf() < 0.54 + safe_skill * 0.36:
			holed = true
		if holed:
			end = _ground_point(terrain, cup)
			reason = "holed_" + club_name
		elif end_surface == 2 and reason == "approach":
			reason = "green_hit"

	var duration: float = 0.45 + distance / (52.0 if club_name != "putter" else 17.0)
	if hazard:
		duration += 0.3
	var arc: float = clampf(bounce + absf(elevation) * 0.08 + distance * 0.025, 0.2, 48.0)
	return {
		"start": start,
		"landing": landing,
		"end": end,
		"target": target,
		"arc": arc,
		"duration": clampf(duration, 0.35, 7.0),
		"club": club_name,
		"penalty": penalty,
		"holed": holed,
		"hazard": hazard,
		"reason": reason,
		# These fields are useful to the overlay and cost nothing for callers
		# that only consume the required contract fields.
		"surface": landing_surface,
		"distance": distance,
		"skill": safe_skill,
		"green_radius": green_radius,
		"tee": tee
	}

static func round_preview(terrain, hole: Dictionary, skill: float, seed_value: int) -> Dictionary:
	var safe_skill: float = clampf(skill, 0.0, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var start: Vector3 = Vector3(hole.get("tee", Vector3.ZERO))
	var strokes: int = 0
	var hazards: int = 0
	var shots: Array = []
	while strokes < MAX_STROKES:
		var current: Dictionary = shot(terrain, start, hole, safe_skill, rng)
		shots.append(current)
		strokes += 1
		if bool(current.get("hazard", false)):
			hazards += 1
		if bool(current.get("holed", false)):
			break
		start = Vector3(current.get("end", start))
	return {"strokes": strokes, "hazards": hazards, "shots": shots}

static func analyze(terrain, hole: Dictionary, count: int = 30, seed_value: int = 42) -> Array:
	var rounds: int = clampi(count, 1, 120)
	var profiles: Array = [
		{"label": "beginner", "skill": 0.28},
		{"label": "intermediate", "skill": 0.58},
		{"label": "expert", "skill": 0.88}
	]
	var result: Array = []
	for profile_value in profiles:
		var profile: Dictionary = profile_value
		var total_strokes: int = 0
		var total_hazards: int = 0
		var sample_shots: Array = []
		for index in range(rounds):
			var preview: Dictionary = round_preview(terrain, hole, float(profile.get("skill", 0.5)), seed_value + index * 7919 + result.size() * 104729)
			total_strokes += int(preview.get("strokes", MAX_STROKES))
			total_hazards += int(preview.get("hazards", 0))
			var preview_shots: Array = preview.get("shots", [])
			for shot_value in preview_shots:
				sample_shots.append(shot_value)
		result.append({
			"label": String(profile.get("label", "player")),
			"skill": float(profile.get("skill", 0.5)),
			"average": float(total_strokes) / float(rounds),
			"hazard_rate": float(total_hazards) / float(rounds),
			"shots": sample_shots
		})
	return result

static func _choose_target(terrain, start: Vector3, cup: Vector3, hole: Dictionary, skill: float, start_surface: int) -> Dictionary:
	var direct_distance: float = _flat_distance(start, cup)
	var slope: Vector2 = _read_slope(terrain, start)
	var max_reach: float = 230.0 * _skill_distance_factor(skill) * _surface_distance_factor(start_surface) * _slope_distance_factor(slope)
	var blocked: bool = false
	if direct_distance > 1.0:
		blocked = bool(terrain.segment_blocked(start, cup))
	if not blocked and direct_distance <= max_reach * 0.96:
		return {"target": cup, "reason": "putt" if start_surface == 2 and direct_distance <= 24.0 else "approach"}

	var waypoints_value: Variant = hole.get("waypoints", [])
	var waypoints: Array = waypoints_value if waypoints_value is Array else []
	var best: Vector3 = Vector3.ZERO
	var best_remaining: float = INF
	var checks: int = 0
	for waypoint_value in waypoints:
		if checks >= MAX_WAYPOINTS_CHECKED:
			break
		checks += 1
		var waypoint: Vector3 = Vector3(waypoint_value)
		var from_start: float = _flat_distance(start, waypoint)
		var remaining: float = _flat_distance(waypoint, cup)
		if from_start < 8.0 or remaining >= direct_distance - 2.0 or from_start > max_reach * 1.05:
			continue
		if bool(terrain.segment_blocked(start, waypoint)):
			continue
		if not bool(terrain.playable(waypoint)):
			continue
		if remaining < best_remaining:
			best = waypoint
			best_remaining = remaining
	if best_remaining < INF:
		return {"target": _ground_point(terrain, best), "reason": "waypoint_layup"}

	# A blocked line gets two inexpensive side anchors. They make trees feel
	# meaningful while keeping previews independent of path-routing cost.
	var direction: Vector3 = _flat_direction(start, cup)
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var anchor_distance: float = minf(direct_distance * 0.62, max_reach * 0.82)
	var anchor: Vector3 = start + direction * anchor_distance
	if blocked:
		for sign_value in [-1.0, 1.0]:
			var candidate: Vector3 = _ground_point(terrain, anchor + side * 12.0 * sign_value)
			if bool(terrain.playable(candidate)) and not bool(terrain.segment_blocked(start, candidate)):
				return {"target": candidate, "reason": "tree_layup"}
	return {"target": _ground_point(terrain, anchor), "reason": "layup"}

static func _choose_club(distance: float, surface: int, skill: float, slope: Vector2, elevation: float) -> Dictionary:
	var terrain_factor: float = _surface_distance_factor(surface) * _slope_distance_factor(slope)
	if elevation > 0.0:
		terrain_factor *= clampf(1.0 - elevation / 180.0, 0.74, 1.0)
	for club_value in _CLUBS:
		var club: Dictionary = club_value
		var name: String = String(club.get("name", "wedge"))
		if name == "putter" and surface != 2:
			continue
		var reachable: float = float(club.get("carry", 30.0)) * _skill_distance_factor(skill) * terrain_factor
		if reachable >= distance * 0.98:
			return club
	return _CLUBS[_CLUBS.size() - 1]

static func _ground_point(terrain, point: Vector3) -> Vector3:
	var ground_y: float = float(terrain.height_at(point))
	return Vector3(point.x, ground_y, point.z)

static func _read_slope(terrain, point: Vector3) -> Vector2:
	var value: Variant = terrain.slope_at(point)
	if value is Vector2:
		return value
	return Vector2.ZERO

static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

static func _flat_direction(a: Vector3, b: Vector3) -> Vector3:
	var delta: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	if delta.length_squared() < 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return delta.normalized()

static func _skill_distance_factor(skill: float) -> float:
	return 0.78 + skill * 0.30

static func _surface_distance_factor(surface: int) -> float:
	if surface == 0:
		return 0.92
	if surface == 4:
		return 0.67
	if surface == 2:
		return 1.0
	return 0.96

static func _slope_distance_factor(slope: Vector2) -> float:
	return clampf(1.0 - slope.length() * 0.045, 0.78, 1.0)

static func _noise(rng: RandomNumberGenerator) -> float:
	return (rng.randf() + rng.randf() + rng.randf()) / 3.0 * 2.0 - 1.0
