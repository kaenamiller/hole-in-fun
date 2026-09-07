class_name Catalog
extends RefCounted

## Shared economic and content catalogue. IDs are stable save-game keys.

static func buildings() -> Array:
	# Upkeep values are charged monthly at settlement.
	return [
		{"id": "clubhouse", "name": "Cedar House Clubhouse", "cost": 48000.0, "upkeep": 480.0, "radius": 9.0, "capacity": 28, "grade": 1, "benefit": "hospitality",
			"tiers": [
				{"capacity": 28, "upkeep": 480, "checkin_bonus": 0},
				{"cost": 36000.0, "capacity": 44, "upkeep": 330, "name": "Clubhouse Pavilion", "checkin_bonus": 1},
				{"cost": 70000.0, "capacity": 64, "upkeep": 450, "name": "Grand Clubhouse", "grade": 3, "checkin_bonus": 2},
			]},
		{"id": "driving_range", "name": "Practice Range", "cost": 32000.0, "upkeep": 300.0, "radius": 8.0, "capacity": 16, "grade": 1, "benefit": "practice",
			"tiers": [
				{"capacity": 16, "upkeep": 300, "lesson_bonus": 0.0},
				{"cost": 22000.0, "capacity": 24, "upkeep": 420, "name": "Covered Range Bays", "lesson_bonus": 0.25},
			]},
		{"id": "restroom", "name": "Trailhead Restrooms", "cost": 14000.0, "upkeep": 190.0, "radius": 5.0, "capacity": 8, "grade": 1, "benefit": "comfort",
			"tiers": [
				{"capacity": 8, "upkeep": 190, "decay_mult": 1.0},
				{"cost": 9000.0, "capacity": 14, "upkeep": 250, "name": "Comfort Station", "decay_mult": 0.6},
			]},
		{"id": "snack_kiosk", "name": "Terracotta Snack Kiosk", "cost": 18000.0, "upkeep": 220.0, "radius": 5.0, "capacity": 10, "grade": 1, "benefit": "hunger",
			"tiers": [
				{"capacity": 10, "upkeep": 220},
				{"cost": 12000.0, "capacity": 16, "upkeep": 280, "name": "Snack Bar"},
			]},
		{"id": "cart_barn", "name": "Cart Barn", "cost": 26000.0, "upkeep": 260.0, "radius": 8.0, "capacity": 12, "grade": 2, "benefit": "mobility",
			"tiers": [
				{"capacity": 12, "upkeep": 260},
				{"cost": 18000.0, "capacity": 20, "upkeep": 340, "name": "Expanded Cart Barn"},
			]},
		{"id": "maintenance_shed", "name": "Greenkeepers Shed", "cost": 22000.0, "upkeep": 340.0, "radius": 6.0, "capacity": 6, "grade": 2, "benefit": "condition",
			"tiers": [
				{"capacity": 6, "upkeep": 340, "maint_bonus": 1.0},
				{"cost": 15000.0, "capacity": 8, "upkeep": 420, "name": "Equipment Wing", "maint_bonus": 1.35},
			]},
		{"id": "putting_green", "name": "Practice Putting Green", "cost": 9000.0, "upkeep": 40.0, "radius": 6.0, "capacity": 12, "grade": 1, "benefit": "practice"},
		{"id": "halfway_house", "name": "Halfway House", "cost": 21000.0, "upkeep": 120.0, "radius": 6.0, "capacity": 12, "grade": 1, "benefit": "hunger"},
		{"id": "pro_shop", "name": "Pro Shop", "cost": 34000.0, "upkeep": 160.0, "radius": 7.0, "capacity": 10, "grade": 2, "benefit": "retail"},
		{"id": "caddie_house", "name": "Caddie House", "cost": 30000.0, "upkeep": 180.0, "radius": 5.5, "capacity": 8, "grade": 2, "benefit": "service"},
		{"id": "restaurant", "name": "Fairway Restaurant", "cost": 62000.0, "upkeep": 320.0, "radius": 10.0, "capacity": 32, "grade": 2, "benefit": "dining"},
		{"id": "bar_terrace", "name": "Bar Terrace", "cost": 38000.0, "upkeep": 200.0, "radius": 8.0, "capacity": 24, "grade": 2, "benefit": "social"},
		{"id": "spa", "name": "Resort Spa", "cost": 88000.0, "upkeep": 420.0, "radius": 9.0, "capacity": 10, "grade": 3, "benefit": "comfort"},
		{"id": "lodge", "name": "Cedar Lodge", "cost": 140000.0, "upkeep": 640.0, "radius": 11.0, "capacity": 16, "grade": 3, "benefit": "lodging"},
	]

static func scenery() -> Array:
	# Upkeep values are charged monthly at settlement.
	return [
		{"id": "oak_tree", "name": "Old Oak", "cost": 900.0, "upkeep": 16.0, "radius": 2.4, "grade": 1, "set": "woodland", "beauty": 10.0, "influence": 42.0},
		{"id": "pine_tree", "name": "Pine Tree", "cost": 750.0, "upkeep": 12.0, "radius": 2.0, "grade": 1, "set": "woodland", "beauty": 8.0, "influence": 36.0},
		{"id": "woodland_log", "name": "Resting Log", "cost": 450.0, "upkeep": 6.0, "radius": 1.8, "grade": 1, "set": "woodland", "beauty": 8.0, "influence": 28.0},
		{"id": "woodland_boulder", "name": "Mossy Boulder", "cost": 600.0, "upkeep": 4.0, "radius": 1.8, "grade": 1, "set": "woodland", "beauty": 9.0, "influence": 30.0},
		{"id": "pergola", "name": "Rose Pergola", "cost": 6200.0, "upkeep": 90.0, "radius": 3.0, "grade": 2, "set": "garden", "beauty": 18.0, "influence": 52.0},
		{"id": "fountain", "name": "Garden Fountain", "cost": 5200.0, "upkeep": 110.0, "radius": 2.2, "grade": 2, "set": "garden", "beauty": 19.0, "influence": 46.0},
		{"id": "flower_bed", "name": "Seasonal Flower Bed", "cost": 1600.0, "upkeep": 56.0, "radius": 2.5, "grade": 1, "set": "garden", "beauty": 12.0, "influence": 32.0},
		{"id": "topiary", "name": "Topiary Pair", "cost": 2100.0, "upkeep": 44.0, "radius": 1.5, "grade": 2, "set": "garden", "beauty": 14.0, "influence": 34.0},
		{"id": "gazebo", "name": "Sunset Gazebo", "cost": 8500.0, "upkeep": 120.0, "radius": 3.0, "grade": 2, "set": "resort", "beauty": 22.0, "influence": 60.0},
		{"id": "palm_tree", "name": "Resort Palm", "cost": 1800.0, "upkeep": 24.0, "radius": 2.0, "grade": 2, "set": "resort", "beauty": 12.0, "influence": 40.0},
		{"id": "bench", "name": "Cedar Bench", "cost": 1200.0, "upkeep": 16.0, "radius": 1.8, "grade": 1, "set": "resort", "beauty": 9.0, "influence": 28.0},
		{"id": "decorative_pond", "name": "Reflecting Pond", "cost": 7600.0, "upkeep": 144.0, "radius": 3.2, "grade": 3, "set": "resort", "beauty": 22.0, "influence": 60.0},
		{"id": "desert_shrub", "name": "Desert Shrub", "cost": 420.0, "upkeep": 8.0, "radius": 1.6, "grade": 1, "set": "desert", "beauty": 8.0, "influence": 28.0},
		{"id": "dune_grass", "name": "Dune Grass", "cost": 280.0, "upkeep": 4.0, "radius": 1.2, "grade": 1, "set": "coastal", "beauty": 8.0, "influence": 28.0},
	]

static func maps() -> Array:
	return [
		{"id": "cedar_house", "name": "Cedar House", "description": "Gentle meadow with an established three-hole club.",
			"seed": 730241, "biome": "meadow", "entrance": Vector3(64, 0, 64), "starter": true,
			"starting_cash": 180000.0, "difficulty": "easy", "features": ["stream"], "rough_name": "Rough"},
		{"id": "blank_meadow", "name": "Blank Meadow", "description": "A flat meadow waiting for your first layout.",
			"seed": 120884, "biome": "meadow", "entrance": Vector3(64, 0, 64), "starter": false,
			"starting_cash": 350000.0, "difficulty": "easy", "features": [], "rough_name": "Rough"},
		{"id": "harbour_links", "name": "Harbour Links", "description": "Coastal dunes beside a sheltered harbour with links-style turf.",
			"seed": 481902, "biome": "coastal", "entrance": Vector3(220, 0, 512), "starter": false,
			"starting_cash": 320000.0, "difficulty": "moderate", "features": ["sea", "dunes", "prevailing_wind"],
			"rough_name": "Links rough",
			"palette": PackedColorArray([Color("8a9a62"), Color("9cb070"), Color("b8c888"), Color("a0b878"), Color("e8d8a8"), Color("4a8aaa"), Color("c4a878")]),
			"water_color": Color("4a8aaa")},
		{"id": "stonebrook_hills", "name": "Stonebrook Hills", "description": "Rolling hills cut by a winding stream with natural crossings.",
			"seed": 592013, "biome": "hills", "entrance": Vector3(96, 0, 96), "starter": false,
			"starting_cash": 280000.0, "difficulty": "moderate", "features": ["river", "bridges"],
			"rough_name": "Rough",
			"cost_multipliers": {"raise": 1.35, "fairway": 1.0, "water": 1.0, "clear_tree": 1.0}},
		{"id": "red_mesa", "name": "Red Mesa", "description": "Sun-baked desert scrub where fairways and water are precious.",
			"seed": 640118, "biome": "desert", "entrance": Vector3(128, 0, 880), "starter": false,
			"starting_cash": 260000.0, "difficulty": "hard", "features": ["scrub", "oasis"],
			"rough_name": "Scrub",
			"palette": PackedColorArray([Color("a88458"), Color("b89868"), Color("c8b080"), Color("b09060"), Color("e0c898"), Color("6a9aaa"), Color("c09070")]),
			"water_color": Color("6a9aaa"),
			"cost_multipliers": {"raise": 1.1, "fairway": 1.45, "water": 1.6, "clear_tree": 0.85}},
		{"id": "pinewood_valley", "name": "Pinewood Valley", "description": "A wooded valley around a central lake with mature pines to clear.",
			"seed": 771204, "biome": "valley", "entrance": Vector3(512, 0, 64), "starter": false,
			"starting_cash": 300000.0, "difficulty": "moderate", "features": ["lake", "pines"],
			"rough_name": "Rough",
			"cost_multipliers": {"raise": 1.0, "fairway": 1.0, "water": 1.0, "clear_tree": 1.55}},
	]


static func map(map_id: String) -> Dictionary:
	for entry in maps():
		if str(entry.get("id", "")) == map_id:
			return entry
	return {}


static func staff_roles() -> Array:
	# Wages are charged monthly at settlement.
	return [
		{"id": "groundskeeper", "name": "Groundskeeper", "wage": 435.0, "skill": 0.80, "grade": 1, "benefit": "condition", "needs": "maintenance_shed", "description": "Keeps fairways, greens, and scenery healthy."},
		{"id": "service_attendant", "name": "Service Attendant", "wage": 375.0, "skill": 0.72, "grade": 1, "benefit": "satisfaction", "needs": "clubhouse", "description": "Runs guest services and keeps facilities welcoming."},
		{"id": "cleaner", "name": "Cleaner", "wage": 315.0, "skill": 0.68, "grade": 1, "benefit": "cleanliness", "description": "Restores cleanliness in buildings and carts."},
		{"id": "golf_pro", "name": "Golf Pro", "wage": 720.0, "skill": 0.85, "grade": 2, "min_grade": 2, "benefit": "lessons", "needs": "driving_range", "description": "Teaches lessons at the practice range and lifts guest skill."},
		{"id": "shop_clerk", "name": "Shop Clerk", "wage": 390.0, "skill": 0.74, "grade": 2, "min_grade": 2, "benefit": "retail", "needs": "pro_shop", "description": "Staffs the pro shop for full retail capacity and throughput."},
		{"id": "marshal", "name": "Marshal", "wage": 450.0, "skill": 0.78, "grade": 2, "min_grade": 2, "benefit": "pace", "description": "Patrols assigned holes to keep play moving."},
		{"id": "head_greenkeeper", "name": "Head Greenkeeper", "wage": 900.0, "skill": 0.92, "grade": 3, "min_grade": 3, "benefit": "supervision", "needs": "maintenance_shed", "description": "Supervises groundskeepers and unlocks advanced turf programmes."},
	]


static func traits() -> Array:
	return [
		{"id": "quick_learner", "name": "Quick learner", "description": "Gains experience faster."},
		{"id": "mentor", "name": "Mentor", "description": "Nearby colleagues gain experience faster."},
		{"id": "night_owl", "name": "Night owl", "description": "Prefers late shifts."},
		{"id": "grumpy", "name": "Grumpy", "description": "Morale drifts lower under stress."},
		{"id": "careful", "name": "Careful", "description": "Fatigue rises more slowly."},
	]


static func training() -> Array:
	return [
		{"id": "turf_school", "name": "Turf school", "role": "groundskeeper", "days": 5, "cost": 900.0, "skill_bonus": 0.12},
		{"id": "hospitality", "name": "Hospitality", "role": "service_attendant", "days": 3, "cost": 600.0, "skill_bonus": 0.10},
		{"id": "sanitation", "name": "Sanitation", "role": "cleaner", "days": 2, "cost": 300.0, "skill_bonus": 0.08},
		{"id": "pga_clinic", "name": "PGA clinic", "role": "golf_pro", "days": 7, "cost": 2400.0, "skill_bonus": 0.15},
	]

static func loans() -> Array:
	# Interest and payments are applied monthly at settlement; term_days is the
	# term in calendar months.
	return [
		{"id": "working_capital", "name": "Working Capital", "principal": 18000.0, "interest": 0.065, "term_days": 18, "payment": 1080.0, "min_grade": 1},
		{"id": "equipment_financing", "name": "Equipment Financing", "principal": 42000.0, "interest": 0.055, "term_days": 30, "payment": 1530.0, "min_grade": 2},
		{"id": "course_expansion", "name": "Course Expansion Loan", "principal": 90000.0, "interest": 0.045, "term_days": 45, "payment": 2180.0, "min_grade": 3}
	]

static func campaigns() -> Array:
	return [
		{"id": "local_flyers", "name": "Local Flyers", "cost": 220.0, "days": 7, "awareness_daily": 1.2, "skill_bias": -0.08, "min_grade": 1, "grant": "marketing:flyer"},
		{"id": "radio_spot", "name": "Radio Spot", "cost": 650.0, "days": 5, "awareness_daily": 2.5, "min_grade": 1, "grant": "marketing:radio_spot"},
		{"id": "golf_magazine", "name": "Golf Magazine Feature", "cost": 1800.0, "days": 3, "awareness_daily": 4.0, "expert_boost": 0.25, "min_grade": 2, "min_rating": 3.5},
		{"id": "social_video", "name": "Course Flyover Video", "cost": 900.0, "days": 4, "awareness_daily": 1.5, "buzz_once": 6.0, "min_grade": 2},
		{"id": "pro_visit", "name": "Touring Pro Visit", "cost": 6000.0, "days": 1, "buzz_once": 12.0, "expert_group": true, "min_grade": 3},
		{"id": "loyalty_mailer", "name": "Member Mailer", "cost": 300.0, "days": 1, "loyalty_days": 3, "min_grade": 2},
	]


static func campaign(campaign_id: String) -> Dictionary:
	for entry in campaigns():
		if str(entry.get("id", "")) == campaign_id:
			return entry
	return {}


static func memberships() -> Array:
	return [
		{"id": "social", "name": "Social", "dues": 180.0, "min_grade": 1,
			"includes": ["snack_discount"], "perks": ["book"],
			"description": "10% off snacks; may book tee times."},
		{"id": "player", "name": "Player", "dues": 520.0, "min_grade": 2,
			"includes": ["green_fee"], "perks": ["book", "priority_tee"],
			"description": "Green fees included; priority tee queue."},
		{"id": "founder", "name": "Founder", "dues": 1400.0, "min_grade": 3,
			"includes": ["green_fee", "cart", "range"], "perks": ["book", "priority_tee", "club_championship"],
			"description": "Green fees, cart, and range included; auto-invited to club championship."},
	]


static func membership(membership_id: String) -> Dictionary:
	for entry in memberships():
		if str(entry.get("id", "")) == membership_id:
			return entry
	return {}


static func events() -> Array:
	return [
		{"id": "open_day", "name": "Open Day", "days": 1, "cost": 900.0, "revenue": 5200.0, "attendance": 20, "attendance_ref": 18.0, "satisfaction": 6.0, "min_grade": 1, "description": "Invite the neighborhood for a friendly first look."},
		{"id": "charity_scramble", "name": "Charity Scramble", "days": 2, "cost": 1800.0, "revenue": 8600.0, "attendance": 32, "attendance_ref": 18.0, "satisfaction": 8.0, "min_grade": 1, "description": "A team day that builds goodwill and publicity."},
		{"id": "beginner_clinic", "name": "Beginner Clinic", "days": 1, "cost": 700.0, "revenue": 3600.0, "attendance": 16, "attendance_ref": 15.0, "satisfaction": 7.0, "min_grade": 1, "description": "A welcoming lesson for new golfers."},
		{"id": "club_championship", "name": "Club Championship", "days": 3, "cost": 2400.0, "revenue": 11200.0, "attendance": 42, "attendance_ref": 22.0, "satisfaction": 9.0, "min_grade": 2, "description": "A marquee tournament for returning members."},
		{"id": "regional_amateur", "name": "Regional Amateur", "days": 4, "cost": 3800.0, "revenue": 18800.0, "attendance": 58, "attendance_ref": 25.0, "satisfaction": 10.0, "min_grade": 2, "description": "A serious field that puts the course on the map."},
		{"id": "invitational", "name": "Cedar Invitational", "days": 5, "cost": 7200.0, "revenue": 34500.0, "attendance": 84, "attendance_ref": 30.0, "satisfaction": 13.0, "min_grade": 3, "description": "An elite showcase for a fully established resort."}
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
	for entry in training():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in traits():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in loans():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in events():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in campaigns():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in memberships():
		if str(entry.get("id", "")) == kind:
			return entry
	for entry in grades():
		if str(entry.get("id", "")) == kind:
			return entry
	return {}


## Research-and-milestone unlock tree. Grade nodes use `"kind": "grade"` and list
## branch prerequisites in `"nodes"`. Grants use plain catalog ids or prefixes:
## `role:marshal`, `marketing:radio_spot`, `event:invitational`, `tool:bunker_shape`.
static func unlocks() -> Array:
	return [
		# Operations
		{"id": "cart_fleet", "name": "Cart Fleet", "branch": "operations", "cost": 12000.0, "days": 3, "requires": [], "grade": 1,
			"grants": ["cart_barn", "role:marshal"], "description": "Fleet carts and course patrol staffing."},
		{"id": "greenkeeping", "name": "Greenkeeping", "branch": "operations", "cost": 8000.0, "days": 2, "requires": [], "grade": 1,
			"grants": ["maintenance_shed", "training:turf_school"], "description": "A dedicated turf programme and shed."},
		{"id": "irrigation", "name": "Irrigation", "branch": "operations", "cost": 14000.0, "days": 4, "requires": ["greenkeeping"], "grade": 1,
			"grants": ["trait:half_decay"], "description": "Overnight wear decays at half speed."},
		{"id": "night_crew", "name": "Night Crew", "branch": "operations", "cost": 6000.0, "days": 2, "requires": ["greenkeeping"], "grade": 2,
			"grants": ["shift:late"], "description": "Unlock late-shift scheduling for all roles."},
		{"id": "fleet_upgrade", "name": "Fleet Upgrade", "branch": "operations", "cost": 18000.0, "days": 3, "requires": ["cart_fleet"], "grade": 2,
			"grants": ["trait:cart_capacity_50"], "description": "+50% cart barn capacity."},
		# Course
		{"id": "bunker_craft", "name": "Bunker Craft", "branch": "course", "cost": 4500.0, "days": 2, "requires": [], "grade": 1,
			"grants": ["tool:bunker_shape"], "description": "Sand shaping tools for hazard design."},
		{"id": "green_complex", "name": "Green Complex", "branch": "course", "cost": 9000.0, "days": 3, "requires": ["bunker_craft"], "grade": 2,
			"grants": ["tool:green_shape"], "description": "Non-circular green shapes."},
		{"id": "water_features", "name": "Water Features", "branch": "course", "cost": 11000.0, "days": 3, "requires": ["bunker_craft"], "grade": 2,
			"grants": ["decorative_pond", "tool:water_hazard"], "description": "Reflecting ponds and water hazard tools."},
		{"id": "championship_tees", "name": "Championship Tees", "branch": "course", "cost": 7500.0, "days": 2, "requires": [], "grade": 2,
			"grants": ["tool:multi_tee"], "description": "Multiple tee boxes per hole."},
		{"id": "signature_hole", "name": "Signature Hole", "branch": "course", "cost": 15000.0, "days": 5, "requires": ["green_complex"], "grade": 3,
			"milestone": {"kind": "events_won", "value": 1},
			"grants": ["badge:signature_hole"], "description": "Design-metrics badge that lifts awareness."},
		{"id": "garden_accents", "name": "Garden Accents", "branch": "course", "cost": 5200.0, "days": 2, "requires": [], "grade": 2,
			"grants": ["pergola", "fountain", "topiary", "gazebo", "palm_tree"], "description": "Garden and resort scenery collection."},
		# Hospitality
		{"id": "snack_bar", "name": "Snack Bar", "branch": "hospitality", "cost": 4000.0, "days": 2, "requires": [], "grade": 1,
			"grants": ["trait:snack_bar_tier"], "description": "Upgrade path for the terracotta kiosk."},
		{"id": "pro_shop", "name": "Pro Shop", "branch": "hospitality", "cost": 10000.0, "days": 3, "requires": ["snack_bar"], "grade": 2,
			"grants": ["pro_shop", "role:shop_clerk"], "description": "Retail building and shop clerk hiring."},
		{"id": "restaurant", "name": "Restaurant", "branch": "hospitality", "cost": 16000.0, "days": 4, "requires": ["pro_shop"], "grade": 2,
			"grants": ["restaurant", "bar_terrace"], "description": "Post-round dining and terrace drinks for guests."},
		{"id": "lodge", "name": "Lodge", "branch": "hospitality", "cost": 22000.0, "days": 5, "requires": ["restaurant"], "grade": 3,
			"grants": ["lodge"], "description": "Multi-day stays and returning guests."},
		{"id": "member_lounge", "name": "Member Lounge", "branch": "hospitality", "cost": 12000.0, "days": 3, "requires": ["pro_shop"], "grade": 2,
			"grants": ["membership:2", "membership:3"], "description": "Membership tiers two and three."},
		# Prestige
		{"id": "local_press", "name": "Local Press", "branch": "prestige", "cost": 3500.0, "days": 2, "requires": [], "grade": 1,
			"grants": ["marketing:flyer", "marketing:radio_spot"], "description": "Flyers and radio spots for awareness."},
		{"id": "charity_network", "name": "Charity Network", "branch": "prestige", "cost": 5000.0, "days": 2, "requires": ["local_press"], "grade": 1,
			"milestone": {"kind": "completed_visits", "value": 200},
			"grants": ["event:club_championship"], "description": "Relationships to host a club championship."},
		{"id": "regional_circuit", "name": "Regional Circuit", "branch": "prestige", "cost": 9000.0, "days": 3, "requires": ["local_press"], "grade": 2,
			"grants": ["event:regional_amateur"], "description": "Sanctioning for a regional amateur."},
		{"id": "invitational_rights", "name": "Invitational Rights", "branch": "prestige", "cost": 18000.0, "days": 4, "requires": ["regional_circuit"], "grade": 3,
			"grants": ["event:invitational"], "description": "Rights to host the Cedar Invitational."},
		{"id": "founder_program", "name": "Founder Programme", "branch": "prestige", "cost": 14000.0, "days": 4, "requires": ["member_lounge"], "grade": 3,
			"grants": ["membership:founder"], "description": "Founding-member campaign for loyal guests."},
		{"id": "turf_leadership", "name": "Turf Leadership", "branch": "operations", "cost": 20000.0, "days": 4, "requires": ["irrigation", "greenkeeping"], "grade": 3,
			"grants": ["role:head_greenkeeper"], "description": "Head greenkeeper supervision programme."},
		{"id": "pro_instruction", "name": "Pro Instruction", "branch": "hospitality", "cost": 11000.0, "days": 3, "requires": [], "grade": 2,
			"grants": ["role:golf_pro"], "description": "PGA professional lessons at the range."},
		# Grade promotion nodes (read by _update_grade and Events panel)
		{"id": "grade_club", "name": "Club", "kind": "grade", "branch": "prestige", "grade": 2, "requires": [],
			"nodes": ["greenkeeping", "local_press"],
			"description": "Earn Club status: turf programme and local press in place."},
		{"id": "grade_resort", "name": "Resort", "kind": "grade", "branch": "prestige", "grade": 3, "requires": ["grade_club"],
			"nodes": ["pro_shop", "regional_circuit", "irrigation"],
			"description": "Earn Resort status: retail, regional circuit, and irrigation."},
	]


static func unlock_node(node_id: String) -> Dictionary:
	for node in unlocks():
		if str(node.get("id", "")) == node_id:
			return node
	return {}


static func grade_unlock_node(target_grade: int) -> Dictionary:
	for node in unlocks():
		if str(node.get("kind", "")) == "grade" and int(node.get("grade", -1)) == target_grade:
			return node
	return {}


static var _grant_index: Dictionary = {}


static func _rebuild_grant_index() -> void:
	_grant_index.clear()
	for node in unlocks():
		if str(node.get("kind", "")) == "grade":
			continue
		var node_id: String = str(node.get("id", ""))
		for grant in node.get("grants", []):
			var key: String = str(grant)
			if not _grant_index.has(key):
				_grant_index[key] = node_id


## Returns the unlock node that gates `kind`, or {} when the catalog entry is base content.
static func unlock_for(kind: String) -> Dictionary:
	if _grant_index.is_empty():
		_rebuild_grant_index()
	var node_id: String = str(_grant_index.get(kind, _grant_index.get("role:%s" % kind, "")))
	if node_id.is_empty():
		return {}
	return unlock_node(node_id)


static func grant_keys_for_kind(kind: String) -> Array[String]:
	var keys: Array[String] = [kind]
	keys.append("role:%s" % kind)
	return keys


## Tier stats for a placed facility level (1-based). Falls back to catalog capacity/upkeep.
static func facility_tier(kind: String, level: int = 1) -> Dictionary:
	var entry: Dictionary = find(kind)
	if entry.is_empty():
		return {}
	var tiers: Array = entry.get("tiers", [])
	var index: int = clampi(level - 1, 0, maxi(0, tiers.size() - 1))
	var tier: Dictionary = tiers[index] if not tiers.is_empty() else {}
	var result: Dictionary = {
		"capacity": int(tier.get("capacity", entry.get("capacity", 4))),
		"upkeep": float(tier.get("upkeep", entry.get("upkeep", 0.0))),
		"name": str(tier.get("name", entry.get("name", kind))),
	}
	for key in ["checkin_bonus", "lesson_bonus", "decay_mult", "maint_bonus", "grade"]:
		if tier.has(key):
			result[key] = tier[key]
	return result


static func facility_max_level(kind: String) -> int:
	var tiers: Array = find(kind).get("tiers", [])
	return maxi(1, tiers.size() if not tiers.is_empty() else 1)


static func facility_upgrade(kind: String, current_level: int) -> Dictionary:
	var tiers: Array = find(kind).get("tiers", [])
	if current_level < 1 or current_level >= tiers.size():
		return {}
	return tiers[current_level]
