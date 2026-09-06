class_name AssetFactory
extends RefCounted

## Warm, low-poly resort props assembled from cached Godot primitives.
## Every returned model is centered on the origin with its feet on y=0.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}

const GREEN := Color("#4f7b4b")
const DEEP_GREEN := Color("#2d5236")
const FAIRWAY := Color("#74a35b")
const CREAM := Color("#f1dfb7")
const TERRACOTTA := Color("#b85d3f")
const TERRACOTTA_DARK := Color("#7d3b32")
const WOOD := Color("#8b5a3c")
const WOOD_DARK := Color("#4e3326")
const BRASS := Color("#d5a84b")
const WATER := Color("#5e9da0")
const FLOWER_PINK := Color("#e4868b")
const FLOWER_YELLOW := Color("#f2c75b")
const FLOWER_BLUE := Color("#759bd1")
const SKIN := Color("#e4ad83")
const SHIRT_BLUE := Color("#527aa5")
const PANTS := Color("#394858")
const WHITE := Color("#f7f2df")

static func build(kind: String, variant: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = kind
	match kind:
		"clubhouse":
			_build_clubhouse(root, variant)
		"driving_range":
			_build_driving_range(root, variant)
		"restroom":
			_build_restroom(root, variant)
		"snack_kiosk":
			_build_snack_kiosk(root, variant)
		"cart_barn":
			_build_cart_barn(root, variant)
		"maintenance_shed":
			_build_maintenance_shed(root, variant)
		"oak_tree", "tree":
			_build_oak_tree(root, variant)
		"pine_tree":
			_build_pine_tree(root, variant)
		"woodland_log":
			_build_log(root, variant)
		"woodland_boulder":
			_build_boulder(root, variant)
		"pergola":
			_build_pergola(root, variant)
		"fountain":
			_build_fountain(root, variant)
		"flower_bed":
			_build_flower_bed(root, variant)
		"topiary":
			_build_topiary(root, variant)
		"gazebo":
			_build_gazebo(root, variant)
		"palm_tree":
			_build_palm(root, variant)
		"bench":
			_build_bench(root, variant)
		"decorative_pond":
			_build_pond(root, variant)
		"flag":
			_build_flag(root, variant)
		"bridge", "bridge_walk", "bridge_cart":
			_build_bridge(root, variant)
		"sign":
			_build_sign(root, variant)
		_:
			_build_generic_prop(root, variant)
	return root

static func golfer(variant: int = 0) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Golfer"
	var shirts = [SHIRT_BLUE,Color("b76554"),Color("e0bb66"),Color("719078"),Color("8c78a8"),Color("c6d4bf")]
	var shirt_color: Color = shirts[variant % shirts.size()]
	var skin_mat: StandardMaterial3D = _material(SKIN)
	var shirt_mat: StandardMaterial3D = _material(shirt_color)
	var pants_mat: StandardMaterial3D = _material(PANTS)
	var shoe_mat: StandardMaterial3D = _material(WOOD_DARK)
	var hair_mat: StandardMaterial3D = _material(Color("#3b2926"))
	var torso: Node3D = Node3D.new()
	torso.name = "Torso"
	root.add_child(torso)
	_mesh(torso, _box(Vector3(0.42, 0.62, 0.30)), shirt_mat, Vector3(0, 1.20, 0))
	var head: MeshInstance3D = _mesh(root, _sphere(0.18, SKIN), skin_mat, Vector3(0, 1.70, 0))
	head.name = "Head"
	_mesh(root, _sphere(0.185, Color("#3b2926")), hair_mat, Vector3(0, 1.81, -0.01), Vector3(1.0, 0.55, 1.0))
	var arm_l: Node3D = _limb(root, "ArmL", Vector3(-0.29, 1.36, 0), Vector3(0.11, 0.47, 0.11), skin_mat)
	var arm_r: Node3D = _limb(root, "ArmR", Vector3(0.29, 1.36, 0), Vector3(0.11, 0.47, 0.11), skin_mat)
	var leg_l: Node3D = _limb(root, "LegL", Vector3(-0.12, 0.66, 0), Vector3(0.14, 0.64, 0.14), pants_mat)
	var leg_r: Node3D = _limb(root, "LegR", Vector3(0.12, 0.66, 0), Vector3(0.14, 0.64, 0.14), pants_mat)
	_mesh(root, _box(Vector3(0.22, 0.10, 0.38)), shoe_mat, Vector3(-0.12, 0.22, -0.08))
	_mesh(root, _box(Vector3(0.22, 0.10, 0.38)), shoe_mat, Vector3(0.12, 0.22, -0.08))
	var club: Node3D = Node3D.new()
	club.name = "Club"
	root.add_child(club)
	_mesh(club, _box(Vector3(0.035, 0.88, 0.035)), _material(BRASS), Vector3(0.40, 0.77, -0.10), Vector3.ONE, Vector3(0, 0, -0.25))
	_mesh(club, _box(Vector3(0.20, 0.06, 0.10)), _material(TERRACOTTA_DARK), Vector3(0.40, 0.32, -0.10))
	root.set_meta("asset_type", "golfer")
	return root

static func cart() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "GolfCart"
	var chassis_mat: StandardMaterial3D = _material(WHITE)
	var trim_mat: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(1.60, 0.22, 2.35)), chassis_mat, Vector3(0, 0.58, 0))
	_mesh(root, _box(Vector3(1.44, 0.08, 2.10)), _material(WOOD), Vector3(0, 0.72, 0.20))
	for x in [-0.72, 0.72]:
		for z in [-0.72, 0.72]:
			_mesh(root, _cylinder(0.30, 0.16, WOOD_DARK, 14), _material(WOOD_DARK), Vector3(x, 0.34, z), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	for x in [-0.62, 0.62]:
		_mesh(root, _box(Vector3(0.07, 1.28, 0.07)), trim_mat, Vector3(x, 1.30, 0.20))
	_mesh(root, _box(Vector3(1.62, 0.10, 2.08)), _material(CREAM), Vector3(0, 1.94, 0.20))
	_mesh(root, _box(Vector3(1.30, 0.08, 0.08)), trim_mat, Vector3(0, 1.00, -0.70))
	_mesh(root, _cylinder(0.18, 0.04, BRASS, 12), _material(BRASS), Vector3(0.42, 1.13, -0.80), Vector3.ONE, Vector3(PI / 2.0, 0, 0))
	return root

static func animate_golfer(node: Node3D, activity: String, phase: float) -> void:
	if node == null:
		return
	var torso: Node3D = node.get_node_or_null("Torso") as Node3D
	var arm_l: Node3D = node.get_node_or_null("ArmL") as Node3D
	var arm_r: Node3D = node.get_node_or_null("ArmR") as Node3D
	var leg_l: Node3D = node.get_node_or_null("LegL") as Node3D
	var leg_r: Node3D = node.get_node_or_null("LegR") as Node3D
	var club: Node3D = node.get_node_or_null("Club") as Node3D
	var sway: float = sin(phase * TAU)
	var stride: float = sin(phase * TAU)
	if activity == "walking":
		if leg_l != null:
			leg_l.rotation.x = stride * 0.45
		if leg_r != null:
			leg_r.rotation.x = -stride * 0.45
		if arm_l != null:
			arm_l.rotation.x = -stride * 0.28
		if arm_r != null:
			arm_r.rotation.x = stride * 0.28
		if torso != null:
			torso.rotation.z = sway * 0.035
	elif activity == "swinging":
		var swing: float = sin(clamp(phase, 0.0, 1.0) * PI)
		if arm_l != null:
			arm_l.rotation.z = -0.55 - swing * 1.2
		if arm_r != null:
			arm_r.rotation.z = 0.55 + swing * 1.2
		if torso != null:
			torso.rotation.y = swing * 0.65
		if club != null:
			club.rotation.z = -0.45 - swing * 1.4
	elif activity == "putting":
		if torso != null:
			torso.rotation.x = -0.48
		if arm_l != null:
			arm_l.rotation.z = -0.28 + sway * 0.30
		if arm_r != null:
			arm_r.rotation.z = 0.28 - sway * 0.30
		if club != null:
			club.rotation.z = sway * 0.20
	elif activity == "seated":
		if torso != null:
			torso.rotation.x = -0.22
		if leg_l != null:
			leg_l.rotation.x = -1.05
		if leg_r != null:
			leg_r.rotation.x = -1.05
		if arm_l != null:
			arm_l.rotation.z = -0.20
		if arm_r != null:
			arm_r.rotation.z = 0.20
	else:
		for part in [arm_l, arm_r, leg_l, leg_r, torso, club]:
			var part_node: Node3D = part as Node3D
			if part_node != null:
				part_node.rotation = Vector3.ZERO

static func _build_clubhouse(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(TERRACOTTA)
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	_mesh(root, _box(Vector3(13.0, 0.35, 9.5)), _material(WOOD_DARK), Vector3(0, 0.18, 0))
	_mesh(root, _box(Vector3(12.0, 5.0, 8.6)), wall, Vector3(0, 2.82, 0))
	_roof(root, 14.0, 10.0, 1.15, 5.40, accent)
	_mesh(root, _box(Vector3(2.8, 0.20, 1.1)), wood, Vector3(0, 0.45, -5.05))
	_mesh(root, _box(Vector3(2.4, 2.2, 0.28)), wood, Vector3(0, 1.56, -4.50))
	for x in [-4.2, -2.2, 2.2, 4.2]:
		_window(root, Vector3(x, 2.60, -4.48), Vector3(1.30, 1.35, 0.10), _material(Color("#9bc6bd")))
		_mesh(root, _box(Vector3(0.10, 1.55, 0.14)), wood, Vector3(x, 2.60, -4.57))
	for x in [-2.3, 2.3]:
		_mesh(root, _box(Vector3(0.22, 2.9, 0.22)), accent, Vector3(x, 1.80, -5.05))
	_mesh(root, _box(Vector3(5.6, 0.18, 1.8)), accent, Vector3(0, 3.95, -4.95))
	_mesh(root, _box(Vector3(5.6, 0.22, 0.22)), wood, Vector3(0, 3.86, -5.86))
	_mesh(root, _box(Vector3(3.0, 0.18, 0.48)), _material(CREAM), Vector3(0, 4.05, -5.88))
	_steps(root, Vector3(0, 0.40, -5.35), 3, 2.8)

static func _build_driving_range(root: Node3D, variant: int) -> void:
	var turf: StandardMaterial3D = _material(FAIRWAY)
	var frame: StandardMaterial3D = _material(WOOD_DARK)
	var net: StandardMaterial3D = _material(Color("#b7ccb2"), 1.0)
	_mesh(root, _box(Vector3(14.0, 0.25, 8.0)), turf, Vector3(0, 0.12, 0))
	_mesh(root, _box(Vector3(13.0, 0.16, 1.6)), _material(WOOD), Vector3(0, 0.34, -2.8))
	for x in [-5.5, -1.85, 1.85, 5.5]:
		_mesh(root, _box(Vector3(0.18, 3.8, 0.18)), frame, Vector3(x, 2.2, -3.1))
		_mesh(root, _box(Vector3(0.18, 3.8, 0.18)), frame, Vector3(x, 2.2, 2.8))
	for x in [-3.7, 0, 3.7]:
		_mesh(root, _box(Vector3(0.12, 3.2, 0.12)), frame, Vector3(x, 1.9, 2.8))
	_mesh(root, _box(Vector3(12.0, 0.15, 0.15)), frame, Vector3(0, 4.0, -3.1))
	_mesh(root, _box(Vector3(12.0, 0.15, 0.15)), frame, Vector3(0, 4.0, 2.8))
	for x in [-5.2, -1.75, 1.75, 5.2]:
		_mesh(root, _box(Vector3(0.14, 2.7, 0.08)), net, Vector3(x, 2.05, 0.0))
	for x in [-4.0, -1.3, 1.3, 4.0]:
		_mesh(root, _box(Vector3(2.30, 0.08, 0.95)), _material(CREAM), Vector3(x, 0.55, -2.75))
		_mesh(root, _box(Vector3(0.08, 0.75, 0.08)), frame, Vector3(x - 0.7, 0.72, -2.75))
		_mesh(root, _box(Vector3(0.08, 0.75, 0.08)), frame, Vector3(x + 0.7, 0.72, -2.75))

static func _build_restroom(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(CREAM)
	var accent: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(7.2, 0.30, 5.5)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(6.6, 3.8, 4.9)), wall, Vector3(0, 2.15, 0))
	_roof(root, 7.4, 5.6, 0.85, 4.15, accent)
	for x in [-1.75, 1.75]:
		_mesh(root, _box(Vector3(1.35, 2.0, 0.25)), _material(WOOD), Vector3(x, 1.18, -2.58))
		_mesh(root, _box(Vector3(0.55, 0.10, 0.05)), _material(BRASS), Vector3(x, 1.55, -2.73))
	_window(root, Vector3(0, 2.65, -2.52), Vector3(1.7, 0.72, 0.10), _material(Color("#9bc6bd")))
	_steps(root, Vector3(0, 0.35, -3.00), 2, 2.9)
	_mesh(root, _box(Vector3(0.90, 0.10, 0.20)), accent, Vector3(0, 3.95, -2.85))

static func _build_snack_kiosk(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(TERRACOTTA)
	var trim: StandardMaterial3D = _material(CREAM)
	_mesh(root, _box(Vector3(6.4, 0.28, 4.3)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(5.8, 3.5, 3.8)), wall, Vector3(0, 2.0, 0.1))
	_roof(root, 6.5, 4.6, 0.75, 3.95, trim)
	_mesh(root, _box(Vector3(5.3, 1.2, 0.18)), trim, Vector3(0, 2.15, -2.05))
	_mesh(root, _box(Vector3(5.2, 0.16, 0.90)), _material(WOOD), Vector3(0, 1.30, -2.16))
	for x in [-2.0, 0, 2.0]:
		_mesh(root, _cylinder(0.23, 0.62, WOOD_DARK, 10), _material(WOOD_DARK), Vector3(x, 0.82, -2.16))
		_mesh(root, _cylinder(0.45, 0.10, CREAM, 12), trim, Vector3(x, 1.18, -2.16))
	_mesh(root, _box(Vector3(3.4, 0.12, 0.18)), trim, Vector3(0, 3.20, -2.05))
	_mesh(root, _box(Vector3(3.2, 0.30, 0.12)), _material(BRASS), Vector3(0, 2.98, -2.15))

static func _build_cart_barn(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(WOOD)
	var trim: StandardMaterial3D = _material(CREAM)
	_mesh(root, _box(Vector3(13.0, 0.30, 8.6)), _material(WOOD_DARK), Vector3(0, 0.15, 0))
	_mesh(root, _box(Vector3(12.3, 4.9, 7.8)), wall, Vector3(0, 2.60, 0))
	_roof(root, 13.5, 9.0, 1.15, 5.25, _material(TERRACOTTA))
	for x in [-5.1, -1.7, 1.7, 5.1]:
		_mesh(root, _box(Vector3(0.25, 5.2, 0.25)), trim, Vector3(x, 2.72, -4.02))
	for x in [-3.4, 0, 3.4]:
		_mesh(root, _box(Vector3(2.7, 3.9, 0.16)), _material(WOOD_DARK), Vector3(x, 2.14, -4.02))
		_mesh(root, _box(Vector3(2.4, 0.15, 0.15)), trim, Vector3(x, 3.55, -4.14))
	_mesh(root, _box(Vector3(12.0, 0.20, 0.26)), trim, Vector3(0, 4.82, -4.08))
	_mesh(root, _box(Vector3(3.6, 0.16, 0.20)), _material(BRASS), Vector3(0, 4.50, -4.17))

static func _build_maintenance_shed(root: Node3D, variant: int) -> void:
	var wall: StandardMaterial3D = _material(Color("#c7955c"))
	var trim: StandardMaterial3D = _material(DEEP_GREEN)
	_mesh(root, _box(Vector3(8.4, 0.28, 6.0)), _material(WOOD_DARK), Vector3(0, 0.14, 0))
	_mesh(root, _box(Vector3(7.7, 4.2, 5.4)), wall, Vector3(0, 2.28, 0))
	_roof(root, 8.5, 6.4, 0.85, 4.60, trim)
	_mesh(root, _box(Vector3(3.8, 2.85, 0.18)), _material(WOOD_DARK), Vector3(0, 1.58, -2.78))
	_mesh(root, _box(Vector3(0.12, 2.85, 0.12)), trim, Vector3(0, 1.58, -2.90))
	for x in [-2.4, 2.4]:
		_window(root, Vector3(x, 2.95, -2.75), Vector3(1.20, 0.95, 0.10), _material(Color("#9bc6bd")))
	_mesh(root, _cylinder(0.42, 0.62, TERRACOTTA_DARK, 12), _material(TERRACOTTA_DARK), Vector3(4.15, 0.58, -1.7), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.42, 0.62, WOOD, 12), _material(WOOD), Vector3(4.15, 0.58, -0.65), Vector3.ONE, Vector3(0, 0, PI / 2.0))

static func _build_oak_tree(root: Node3D, variant: int) -> void:
	root.scale=Vector3.ONE*(1.8+(variant%4)*0.12)
	_mesh(root, _cylinder(0.35, 3.0, WOOD_DARK, 10), _material(WOOD_DARK), Vector3(0, 1.5, 0))
	_mesh(root, _cylinder(0.18, 1.7, WOOD, 9), _material(WOOD), Vector3(-0.55, 2.55, 0), Vector3.ONE, Vector3(0, 0, -0.55))
	_mesh(root, _cylinder(0.15, 1.5, WOOD, 9), _material(WOOD), Vector3(0.60, 2.62, 0), Vector3.ONE, Vector3(0, 0, 0.50))
	for p in [Vector3(-0.72, 3.15, 0), Vector3(0.0, 3.55, 0.10), Vector3(0.75, 3.18, 0), Vector3(0, 3.0, -0.65)]:
		_mesh(root, _sphere(1.10, DEEP_GREEN), _material(DEEP_GREEN), p)
	_mesh(root, _sphere(1.30, GREEN), _material(GREEN), Vector3(0, 3.22, 0.15))

static func _build_pine_tree(root: Node3D, variant: int) -> void:
	root.scale=Vector3.ONE*(2.0+(variant%4)*0.15)
	_mesh(root, _cylinder(0.25, 2.2, WOOD_DARK, 9), _material(WOOD_DARK), Vector3(0, 1.1, 0))
	for pair in [[0.95, 1.75], [0.75, 2.55], [0.52, 3.30]]:
		var radius: float = float(pair[0])
		var height: float = float(pair[1])
		_mesh(root, _cone(radius, height, DEEP_GREEN), _material(DEEP_GREEN), Vector3(0, height * 0.54 + 0.5, 0))

static func _build_log(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.42, 2.8, WOOD, 10), _material(WOOD), Vector3(0, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.32, 0.08, CREAM, 10), _material(CREAM), Vector3(-1.42, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))
	_mesh(root, _cylinder(0.32, 0.08, CREAM, 10), _material(CREAM), Vector3(1.42, 0.48, 0), Vector3.ONE, Vector3(0, 0, PI / 2.0))

static func _build_boulder(root: Node3D, variant: int) -> void:
	_mesh(root, _sphere(1.0, Color("#777b70")), _material(Color("#777b70")), Vector3(0, 0.72, 0), Vector3(1.45, 0.82, 1.05))
	_mesh(root, _sphere(0.35, Color("#9a9c8a")), _material(Color("#9a9c8a")), Vector3(-0.35, 1.30, -0.40), Vector3(1.2, 0.35, 0.8))

static func _build_pergola(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	for x in [-2.2, 2.2]:
		for z in [-1.6, 1.6]:
			_mesh(root, _box(Vector3(0.25, 3.4, 0.25)), wood, Vector3(x, 1.7, z))
	for x in [-1.5, 0, 1.5]:
		_mesh(root, _box(Vector3(0.22, 0.24, 3.8)), wood, Vector3(x, 3.38, 0))
	_mesh(root, _box(Vector3(4.6, 0.16, 3.8)), _material(GREEN), Vector3(0, 3.00, 0))
	_build_flower_ring(root, 0.0)

static func _build_fountain(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(1.55, 0.24, CREAM, 20), _material(CREAM), Vector3(0, 0.12, 0))
	_mesh(root, _cylinder(1.35, 0.18, WATER, 20), _material(WATER), Vector3(0, 0.28, 0))
	_mesh(root, _cylinder(0.24, 1.35, CREAM, 14), _material(CREAM), Vector3(0, 0.95, 0))
	_mesh(root, _cylinder(0.62, 0.18, CREAM, 16), _material(CREAM), Vector3(0, 1.62, 0))
	_mesh(root, _sphere(0.18, WATER), _material(WATER), Vector3(0, 1.88, 0))
	for a in range(0, 360, 45):
		var radians: float = deg_to_rad(float(a))
		_mesh(root, _sphere(0.10, WATER), _material(WATER), Vector3(cos(radians) * 0.72, 1.36, sin(radians) * 0.72))

static func _build_flower_bed(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(4.2, 0.26, 1.7)), _material(WOOD), Vector3(0, 0.13, 0))
	for x in [-1.45, -0.72, 0, 0.72, 1.45]:
		var color: Color = FLOWER_PINK if int(x * 10.0) % 2 == 0 else FLOWER_YELLOW
		_mesh(root, _cylinder(0.10, 0.52, GREEN, 8), _material(GREEN), Vector3(x, 0.52, 0))
		_mesh(root, _sphere(0.24, color), _material(color), Vector3(x, 0.85, 0))
	for z in [-0.45, 0.45]:
		_mesh(root, _box(Vector3(4.3, 0.12, 0.10)), _material(WOOD_DARK), Vector3(0, 0.28, z))

static func _build_topiary(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.28, 1.15, WOOD, 10), _material(WOOD), Vector3(0, 0.58, 0))
	_mesh(root, _sphere(0.75, DEEP_GREEN), _material(DEEP_GREEN), Vector3(0, 1.42, 0))
	_mesh(root, _sphere(0.50, GREEN), _material(GREEN), Vector3(0, 2.10, 0))

static func _build_gazebo(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD_DARK)
	for a in range(0, 360, 60):
		var radians: float = deg_to_rad(float(a))
		_mesh(root, _box(Vector3(0.20, 2.65, 0.20)), wood, Vector3(cos(radians) * 1.55, 1.33, sin(radians) * 1.55))
	_mesh(root, _cylinder(1.90, 0.16, WOOD, 6), _material(WOOD), Vector3(0, 2.75, 0))
	_mesh(root, _cone(2.2, 1.55, TERRACOTTA), _material(TERRACOTTA), Vector3(0, 3.58, 0))
	_mesh(root, _cylinder(1.22, 0.16, CREAM, 16), _material(CREAM), Vector3(0, 0.28, 0))

static func _build_palm(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.28, 3.8, WOOD, 10), _material(WOOD), Vector3(0, 1.9, 0), Vector3.ONE, Vector3(0, 0, -0.10))
	for a in range(0, 360, 45):
		var radians: float = deg_to_rad(float(a))
		_mesh(root, _box(Vector3(0.14, 0.08, 1.35)), _material(GREEN), Vector3(cos(radians) * 0.58, 3.85, sin(radians) * 0.58), Vector3.ONE, Vector3(0, -radians, 0.22))
	_mesh(root, _sphere(0.48, DEEP_GREEN), _material(DEEP_GREEN), Vector3(0, 3.80, 0))

static func _build_bench(root: Node3D, variant: int) -> void:
	var wood: StandardMaterial3D = _material(WOOD)
	_mesh(root, _box(Vector3(3.2, 0.22, 0.58)), wood, Vector3(0, 1.05, 0))
	_mesh(root, _box(Vector3(3.2, 0.22, 0.58)), wood, Vector3(0, 1.60, 0.20), Vector3.ONE, Vector3(-0.28, 0, 0))
	for x in [-1.2, 1.2]:
		_mesh(root, _box(Vector3(0.18, 1.0, 0.18)), _material(WOOD_DARK), Vector3(x, 0.50, 0))
	_mesh(root, _box(Vector3(3.5, 0.10, 0.10)), _material(CREAM), Vector3(0, 1.86, 0.20))

static func _build_pond(root: Node3D, variant: int) -> void:
	_mesh(root, _sphere(2.0, WATER), _material(WATER, 0.2), Vector3(0, 0.20, 0), Vector3(1.5, 0.14, 1.0))
	_mesh(root, _sphere(2.15, GREEN), _material(GREEN), Vector3(0, 0.06, 0), Vector3(1.55, 0.06, 1.05))
	for x in [-1.6, 1.6]:
		_mesh(root, _sphere(0.35, Color("#777b70")), _material(Color("#777b70")), Vector3(x, 0.20, 0.2))

static func _build_flag(root: Node3D, variant: int) -> void:
	_mesh(root, _cylinder(0.035, 2.7, CREAM, 8), _material(CREAM), Vector3(0, 1.35, 0))
	_mesh(root, _box(Vector3(0.70, 0.38, 0.05)), _material(TERRACOTTA), Vector3(0.34, 2.35, 0.0), Vector3.ONE, Vector3(0, 0, 0.05))
	_mesh(root, _cylinder(0.22, 0.08, CREAM, 12), _material(CREAM), Vector3(0, 0.06, 0))

static func _build_bridge(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(4.8, 0.35, 3.0)), _material(WOOD), Vector3(0, 0.45, 0))
	for x in [-2.1, 2.1]:
		for z in [-1.15, 1.15]:
			_mesh(root, _box(Vector3(0.18, 1.15, 0.18)), _material(WOOD_DARK), Vector3(x, 1.10, z))
		_mesh(root, _box(Vector3(0.18, 0.18, 4.5)), _material(WOOD_DARK), Vector3(x, 1.55, 0))
	for x in [-1.2, 0, 1.2]:
		_mesh(root, _box(Vector3(0.12, 0.16, 2.65)), _material(CREAM), Vector3(x, 0.70, 0))

static func _build_sign(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(0.20, 2.0, 0.20)), _material(WOOD_DARK), Vector3(0, 1.0, 0))
	_mesh(root, _box(Vector3(2.1, 0.72, 0.16)), _material(TERRACOTTA), Vector3(0, 2.02, 0))
	_mesh(root, _box(Vector3(1.6, 0.10, 0.05)), _material(CREAM), Vector3(0, 2.02, -0.11))

static func _build_generic_prop(root: Node3D, variant: int) -> void:
	_mesh(root, _box(Vector3(1.4, 1.0, 1.4)), _material(WOOD), Vector3(0, 0.5, 0))
	_mesh(root, _sphere(0.55, GREEN), _material(GREEN), Vector3(0, 1.35, 0))

static func _build_flower_ring(root: Node3D, y: float) -> void:
	for a in range(0, 360, 45):
		var radians: float = deg_to_rad(float(a))
		var p: Vector3 = Vector3(cos(radians) * 2.0, y + 0.42, sin(radians) * 1.45)
		_mesh(root, _sphere(0.22, FLOWER_YELLOW), _material(FLOWER_YELLOW), p)

static func _limb(parent: Node3D, name_value: String, position_value: Vector3, size: Vector3, material: StandardMaterial3D) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = name_value
	parent.add_child(pivot)
	_mesh(pivot, _box(size), material, Vector3(0, -size.y * 0.28, 0))
	pivot.position = position_value
	return pivot

static func _steps(root: Node3D, center: Vector3, count: int, width: float) -> void:
	for i in range(count):
		_mesh(root, _box(Vector3(width - float(i) * 0.25, 0.18, 0.48)), _material(CREAM), center + Vector3(0, float(i) * 0.18, float(i) * 0.42))

static func _window(root: Node3D, position_value: Vector3, size: Vector3, material: StandardMaterial3D) -> void:
	_mesh(root, _box(size), material, position_value)
	_mesh(root, _box(Vector3(0.07, size.y, 0.04)), _material(WOOD_DARK), position_value + Vector3(0, 0, -size.z * 0.65))

static func _roof(root: Node3D, width: float, depth: float, thickness: float, y: float, material: StandardMaterial3D) -> void:
	var angle: float = 0.40
	var rise: float = width * 0.5 * tan(angle)
	var pitch_length: float = width * 0.5 / cos(angle)
	var slab: float = thickness * 0.3
	_mesh(root, _box(Vector3(pitch_length, slab, depth + 0.7)), material, Vector3(-width * 0.25, y + rise * 0.5, 0), Vector3.ONE, Vector3(0, 0, angle))
	_mesh(root, _box(Vector3(pitch_length, slab, depth + 0.7)), material, Vector3(width * 0.25, y + rise * 0.5, 0), Vector3.ONE, Vector3(0, 0, -angle))
	_mesh(root, _box(Vector3(0.26, slab, depth + 0.8)), _material(TERRACOTTA_DARK), Vector3(0, y + rise, 0))
	var arrays=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-width*0.45,y,-depth*0.46),Vector3(width*0.45,y,-depth*0.46),Vector3(0,y+rise,-depth*0.46),Vector3(width*0.45,y,depth*0.46),Vector3(-width*0.45,y,depth*0.46),Vector3(0,y+rise,depth*0.46)])
	arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.FORWARD,Vector3.FORWARD,Vector3.FORWARD,Vector3.BACK,Vector3.BACK,Vector3.BACK])
	var gable=ArrayMesh.new()
	gable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_mesh(root,gable,_material(CREAM))


static func _mesh(parent: Node3D, mesh: Mesh, material: StandardMaterial3D, position_value: Vector3 = Vector3.ZERO, scale_value: Vector3 = Vector3.ONE, rotation_value: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position_value
	instance.scale = scale_value
	instance.rotation = rotation_value
	parent.add_child(instance)
	return instance

static func _material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = color.to_html(false) + ":" + str(roughness) + ":" + str(metallic)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_materials[key] = material
	return material

static func _box(size: Vector3) -> BoxMesh:
	var key: String = "box:" + str(size)
	if _meshes.has(key):
		return _meshes[key] as BoxMesh
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	_meshes[key] = mesh
	return mesh

static func _cylinder(radius: float, height: float, color: Color, segments: int = 12) -> CylinderMesh:
	var key: String = "cyl:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as CylinderMesh
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	_meshes[key] = mesh
	return mesh

static func _cone(radius: float, height: float, color: Color, segments: int = 12) -> CylinderMesh:
	var key: String = "cone:" + str(radius) + ":" + str(height) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as CylinderMesh
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.04
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	_meshes[key] = mesh
	return mesh

static func _sphere(radius: float, color: Color, segments: int = 16) -> SphereMesh:
	var key: String = "sphere:" + str(radius) + ":" + str(segments)
	if _meshes.has(key):
		return _meshes[key] as SphereMesh
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = 8
	_meshes[key] = mesh
	return mesh
