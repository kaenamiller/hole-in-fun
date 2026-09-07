extends SceneTree

const FACILITIES: Array[String] = [
	"clubhouse", "driving_range", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed",
	"putting_green", "halfway_house", "pro_shop", "caddie_house", "restaurant", "bar_terrace", "spa", "lodge",
]
const SCENERY: Array[String] = ["oak_tree", "pine_tree", "woodland_log", "woodland_boulder", "pergola", "fountain", "flower_bed", "topiary", "gazebo", "palm_tree", "bench", "decorative_pond", "desert_shrub", "dune_grass"]
const PROPS: Array[String] = ["flag", "bridge", "bridge_walk", "bridge_cart", "sign"]
const ACTIVITIES: Array[String] = ["walking", "swinging", "putting", "seated", "idle"]
const TIERED_FACILITIES: Array[String] = ["clubhouse", "driving_range", "restroom", "snack_kiosk", "cart_barn", "maintenance_shed"]

func _init() -> void:
	var checks: int = 0
	for kind in FACILITIES + SCENERY + PROPS:
		var max_level: int = Catalog.facility_max_level(kind)
		for level in range(1, max_level + 1):
			var variant: int = level - 1
			var model: Node3D = AssetFactory.build(kind, variant)
			assert(model != null, "AssetFactory returned null for " + kind + " level " + str(level))
			assert(model.get_child_count() > 0, "Asset has no visible parts: " + kind + " level " + str(level))
			var bounds: AABB = _bounds(model)
			assert(bounds.size.x > 0.1 and bounds.size.y > 0.1 and bounds.size.z > 0.1, "Asset has degenerate bounds: " + kind)
			assert(bounds.position.y >= -0.20, "Asset sinks too far below ground: " + kind + " y=" + str(bounds.position.y))
			assert(bounds.size.y < 16.0, "Asset is unreasonably tall: " + kind)
			var center_xz: Vector2 = Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.z + bounds.size.z * 0.5)
			assert(center_xz.length() < 2.0, kind + " level " + str(level) + " should be centred near origin")
			model.free()
			checks += 1
	for kind in TIERED_FACILITIES:
		assert(Catalog.facility_max_level(kind) >= 2, "Tiered facility should expose multiple levels: " + kind)
	var golfer: Node3D = AssetFactory.golfer()
	assert(golfer.get_node_or_null("Head") != null, "Golfer head missing")
	assert(golfer.get_node_or_null("Club") != null, "Golfer club missing")
	for activity in ACTIVITIES:
		AssetFactory.animate_golfer(golfer, activity, 0.35)
		checks += 1
	golfer.free()
	var cart_model: Node3D = AssetFactory.cart()
	assert(cart_model.get_child_count() >= 8, "Cart silhouette missing wheels/roof")
	cart_model.free()
	checks += 1
	for entry in Catalog.scenery():
		assert(float(entry.get("influence", 0.0)) >= 25.0 and float(entry.get("influence", 0.0)) <= 60.0, "Scenery influence out of range")
		assert(float(entry.get("beauty", 0.0)) >= 8.0 and float(entry.get("beauty", 0.0)) <= 22.0, "Scenery beauty out of range")
		checks += 1
	assert(Catalog.as_resource("clubhouse") is ContentDefinition, "Typed building definition missing")
	assert(Catalog.as_resource("oak_tree") is ContentDefinition, "Typed scenery definition missing")
	print("test_assets: %d asset and catalogue checks passed" % checks)
	quit()

func _bounds(node: Node) -> AABB:
	var result: AABB = AABB()
	var has_bounds: bool = false
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			var child_bounds: AABB = mesh_node.transform * mesh_node.get_aabb()
			if not has_bounds:
				result = child_bounds
				has_bounds = true
			else:
				result = result.merge(child_bounds)
		var nested: AABB = _bounds(child)
		if nested.size != Vector3.ZERO:
			if not has_bounds:
				result = nested
				has_bounds = true
			else:
				result = result.merge(nested)
	return result
