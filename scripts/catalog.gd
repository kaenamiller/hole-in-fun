class_name Catalog
extends RefCounted

## Shared economic and content catalogue. IDs are stable save-game keys.

static func buildings() -> Array:
	return [
		{"id": "clubhouse", "name": "Cedar House Clubhouse", "cost": 48000.0, "upkeep": 240.0, "radius": 9.0, "capacity": 28, "grade": 1, "benefit": "hospitality"},
		{"id": "driving_range", "name": "Practice Range", "cost": 32000.0, "upkeep": 150.0, "radius": 8.0, "capacity": 16, "grade": 1, "benefit": "practice"},
		{"id": "restroom", "name": "Trailhead Restrooms", "cost": 14000.0, "upkeep": 95.0, "radius": 5.0, "capacity": 8, "grade": 1, "benefit": "comfort"},
		{"id": "snack_kiosk", "name": "Terracotta Snack Kiosk", "cost": 18000.0, "upkeep": 110.0, "radius": 5.0, "capacity": 10, "grade": 1, "benefit": "hunger"},
		{"id": "cart_barn", "name": "Cart Barn", "cost": 26000.0, "upkeep": 130.0, "radius": 8.0, "capacity": 12, "grade": 2, "benefit": "mobility"},
		{"id": "maintenance_shed", "name": "Greenkeepers Shed", "cost": 22000.0, "upkeep": 170.0, "radius": 6.0, "capacity": 6, "grade": 2, "benefit": "condition"}
	]

static func scenery() -> Array:
	return [
		{"id": "oak_tree", "name": "Old Oak", "cost": 900.0, "upkeep": 8.0, "radius": 2.4, "grade": 1, "set": "woodland", "beauty": 10.0, "influence": 42.0},
		{"id": "pine_tree", "name": "Pine Tree", "cost": 750.0, "upkeep": 6.0, "radius": 2.0, "grade": 1, "set": "woodland", "beauty": 8.0, "influence": 36.0},
		{"id": "woodland_log", "name": "Resting Log", "cost": 450.0, "upkeep": 3.0, "radius": 1.8, "grade": 1, "set": "woodland", "beauty": 8.0, "influence": 28.0},
		{"id": "woodland_boulder", "name": "Mossy Boulder", "cost": 600.0, "upkeep": 2.0, "radius": 1.8, "grade": 1, "set": "woodland", "beauty": 9.0, "influence": 30.0},
		{"id": "pergola", "name": "Rose Pergola", "cost": 6200.0, "upkeep": 45.0, "radius": 3.0, "grade": 2, "set": "garden", "beauty": 18.0, "influence": 52.0},
		{"id": "fountain", "name": "Garden Fountain", "cost": 5200.0, "upkeep": 55.0, "radius": 2.2, "grade": 2, "set": "garden", "beauty": 19.0, "influence": 46.0},
		{"id": "flower_bed", "name": "Seasonal Flower Bed", "cost": 1600.0, "upkeep": 28.0, "radius": 2.5, "grade": 1, "set": "garden", "beauty": 12.0, "influence": 32.0},
		{"id": "topiary", "name": "Topiary Pair", "cost": 2100.0, "upkeep": 22.0, "radius": 1.5, "grade": 2, "set": "garden", "beauty": 14.0, "influence": 34.0},
		{"id": "gazebo", "name": "Sunset Gazebo", "cost": 8500.0, "upkeep": 60.0, "radius": 3.0, "grade": 2, "set": "resort", "beauty": 22.0, "influence": 60.0},
		{"id": "palm_tree", "name": "Resort Palm", "cost": 1800.0, "upkeep": 12.0, "radius": 2.0, "grade": 2, "set": "resort", "beauty": 12.0, "influence": 40.0},
		{"id": "bench", "name": "Cedar Bench", "cost": 1200.0, "upkeep": 8.0, "radius": 1.8, "grade": 1, "set": "resort", "beauty": 9.0, "influence": 28.0},
		{"id": "decorative_pond", "name": "Reflecting Pond", "cost": 7600.0, "upkeep": 72.0, "radius": 3.2, "grade": 3, "set": "resort", "beauty": 22.0, "influence": 60.0}
	]

static func staff_roles() -> Array:
	return [
		{"id": "groundskeeper", "name": "Groundskeeper", "wage": 145.0, "skill": 0.80, "benefit": "condition", "description": "Keeps fairways, greens, and scenery healthy."},
		{"id": "service_attendant", "name": "Service Attendant", "wage": 125.0, "skill": 0.72, "benefit": "satisfaction", "description": "Runs guest services and keeps facilities welcoming."},
		{"id": "cleaner", "name": "Cleaner", "wage": 105.0, "skill": 0.68, "benefit": "cleanliness", "description": "Restores cleanliness in buildings and carts."}
	]

static func loans() -> Array:
	return [
		{"id": "working_capital", "name": "Working Capital", "principal": 18000.0, "interest": 0.065, "term_days": 18, "payment": 1080.0, "min_grade": 1},
		{"id": "equipment_financing", "name": "Equipment Financing", "principal": 42000.0, "interest": 0.055, "term_days": 30, "payment": 1530.0, "min_grade": 2},
		{"id": "course_expansion", "name": "Course Expansion Loan", "principal": 90000.0, "interest": 0.045, "term_days": 45, "payment": 2180.0, "min_grade": 3}
	]

static func events() -> Array:
	return [
		{"id": "open_day", "name": "Open Day", "days": 1, "cost": 900.0, "revenue": 5200.0, "attendance": 20, "satisfaction": 6.0, "min_grade": 1, "description": "Invite the neighborhood for a friendly first look."},
		{"id": "charity_scramble", "name": "Charity Scramble", "days": 2, "cost": 1800.0, "revenue": 8600.0, "attendance": 32, "satisfaction": 8.0, "min_grade": 1, "description": "A team day that builds goodwill and publicity."},
		{"id": "beginner_clinic", "name": "Beginner Clinic", "days": 1, "cost": 700.0, "revenue": 3600.0, "attendance": 16, "satisfaction": 7.0, "min_grade": 1, "description": "A welcoming lesson for new golfers."},
		{"id": "club_championship", "name": "Club Championship", "days": 3, "cost": 2400.0, "revenue": 11200.0, "attendance": 42, "satisfaction": 9.0, "min_grade": 2, "description": "A marquee tournament for returning members."},
		{"id": "regional_amateur", "name": "Regional Amateur", "days": 4, "cost": 3800.0, "revenue": 18800.0, "attendance": 58, "satisfaction": 10.0, "min_grade": 2, "description": "A serious field that puts the course on the map."},
		{"id": "invitational", "name": "Cedar Invitational", "days": 5, "cost": 7200.0, "revenue": 34500.0, "attendance": 84, "satisfaction": 13.0, "min_grade": 3, "description": "An elite showcase for a fully established resort."}
	]

static func grades() -> Array:
	return [
		{"grade": 1, "id": "trailhead", "name": "Trailhead", "requirements": {"cash": 0.0, "buildings": 1, "holes": 3, "publicity": 0.0}},
		{"grade": 2, "id": "club", "name": "Club", "requirements": {"cash": 45000.0, "buildings": 3, "holes": 6, "publicity": 18.0}},
		{"grade": 3, "id": "resort", "name": "Resort", "requirements": {"cash": 120000.0, "buildings": 6, "holes": 9, "publicity": 42.0}}
	]

static func grade_requirements() -> Array:
	return grades()

static func course_grades() -> Array:
	return grades()

static func as_resource(kind: String) -> ContentDefinition:
	var entry: Dictionary = find(kind)
	if entry.is_empty():
		return null
	return ContentDefinition.from_dictionary(entry)

static func find(kind: String) -> Dictionary:
	for entry in buildings():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in scenery():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in staff_roles():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in loans():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in events():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in grades():
		if str(entry.get("id", "")) == kind:
			return entry
	return {}
