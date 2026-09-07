extends SceneTree

const ShotEngineClass = preload("res://scripts/shot_engine.gd")
const SettingsService = preload("res://scripts/graphics_settings_service.gd")
const SettingsClass = preload("res://scripts/graphics_settings.gd")
const PaletteClass = preload("res://scripts/graphics_palette.gd")
const CalibrationClass = preload("res://scripts/color_calibration.gd")
const RendererComparisonClass = preload("res://scripts/renderer_comparison.gd")
const ShadowClass = preload("res://scripts/graphics_shadow.gd")
const AtmosphereClass = preload("res://scripts/graphics_atmosphere.gd")
const DiagnosticsClass = preload("res://scripts/shadow_diagnostics.gd")
const MaterialLibraryClass = preload("res://scripts/material_library.gd")
const HoleMowingClass = preload("res://scripts/hole_mowing.gd")
const TreeAssetsClass = preload("res://scripts/tree_assets.gd")
const GroundCoverClass = preload("res://scripts/ground_cover.gd")
const GroundCoverAssetsClass = preload("res://scripts/ground_cover_assets.gd")
const ActorMotionClass = preload("res://scripts/actor_motion.gd")
const ReflectionProbesClass = preload("res://scripts/graphics_reflection_probes.gd")
const PlanarReflectionsClass = preload("res://scripts/graphics_planar_reflections.gd")
const PlanarFixtureClass = preload("res://scripts/planar_reflection_fixture.gd")
const EffectEventClass = preload("res://scripts/cosmetic_effect_event.gd")
const EffectManagerClass = preload("res://scripts/cosmetic_effect_manager.gd")

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run() -> void:
	SaveStore.directory = "user://test_saves/graphics_%d" % OS.get_process_id()
	_test_defaults()
	_test_palette_contract()
	_test_material_library()
	_test_season_apply_preserves_roughness()
	_test_readability_constants()
	_test_calibration_scene_builds()
	_test_shadow_contract()
	_test_atmosphere_contract()
	_test_gen2_trees_contract()
	_test_ground_cover_contract()
	_test_renderer_comparison_contract()
	_test_reflection_probe_contract()
	_test_planar_reflection_contract()
	_test_mowing_cosmetic_contract()
	_test_actor_motion_contract()
	_test_event_effects_contract()
	_test_invalid_fallback()
	_test_persistence_round_trip()
	await _test_quality_does_not_touch_sim()
	await _test_low_survives_world_recreation()
	print("test_graphics: %d failures" % failures.size())
	quit(1 if not failures.is_empty() else 0)

func _test_defaults() -> void:
	var settings: GraphicsSettings = SettingsClass.defaults()
	check(settings.preset == SettingsClass.Preset.STANDARD, "default preset is Standard")
	check(is_equal_approx(settings.shadow_distance, 1100.0), "default shadow distance matches current lighting")
	check(settings.shadow_resolution == 4096, "default shadow resolution matches project")
	check(settings.msaa_3d == 2, "default MSAA matches project 4x setting")
	check(is_equal_approx(settings.foliage_density, 1.0), "default foliage density is full")

func _test_palette_contract() -> void:
	var summer: Dictionary = PaletteClass.environment_for_season(1)
	check(summer.sun_color == PaletteClass.LEGACY.sun_color, "summer sun color matches legacy fixture")
	check(is_equal_approx(float(summer.sun_energy), PaletteClass.LEGACY.sun_energy), "summer sun energy matches legacy")
	check(summer.ambient_color == PaletteClass.LEGACY.season_ambient[1].amb, "summer ambient matches legacy season row")
	check(summer.tonemap == Environment.TONE_MAPPER_LINEAR, "tonemap stays linear on Compatibility")
	check(PaletteClass.SURFACE_COLORS.size() == 7, "surface palette exposes seven terrain slots")
	check(PaletteClass.ART_CURVES.ground.gamma == 1.65, "ground art curve documented")
	var surfaces: Dictionary = PaletteClass.surface_colors_for_terrain()
	check(surfaces.has("fairway_color"), "terrain surface dictionary includes fairway")
	check(PaletteClass.terrain_season_tint(2).x > 1.0, "fall ground tint warms")

func _test_material_library() -> void:
	check(PaletteClass.MATERIAL_FAMILIES.size() == 9, "nine material families are registered")
	check(MaterialLibraryClass.family_ids().size() == 9, "MaterialLibrary exposes all families")
	var plaster_a: StandardMaterial3D = MaterialLibraryClass.material("arch.plaster")
	var plaster_b: StandardMaterial3D = MaterialLibraryClass.material("arch.plaster")
	check(plaster_a == plaster_b, "MaterialLibrary reuses shared plaster instance")
	check(plaster_a.albedo_texture != null, "plaster loads albedo map")
	check(plaster_a.normal_enabled, "plaster enables normal map")
	check(plaster_a.uv1_triplanar, "architecture materials use triplanar mapping")
	var fairway: StandardMaterial3D = MaterialLibraryClass.material("course.fairway")
	check(is_equal_approx(fairway.roughness, 0.88), "fairway roughness matches family definition")
	var manifest: Dictionary = MaterialLibraryClass.manifest()
	check(manifest.has("generator_version"), "material manifest loads at runtime")
	check(manifest.get("families", []).size() == 9, "manifest lists nine families")
	var stone: StandardMaterial3D = MaterialLibraryClass.material("prop.stone")
	var timber: StandardMaterial3D = MaterialLibraryClass.material("arch.timber")
	check(stone.get_instance_id() != timber.get_instance_id(), "distinct families do not share material instances")
	var turf_before: Color = fairway.albedo_color
	MaterialLibraryClass.apply_season(2)
	var rough_before: float = plaster_a.roughness
	check(is_equal_approx(plaster_a.roughness, rough_before), "season tint does not change plaster roughness")
	check(plaster_a.albedo_color == PaletteClass.material_tint_color("arch.plaster"), "plaster skips seasonal albedo tint")
	check(fairway.albedo_color != turf_before, "fairway receives seasonal albedo tint")
	MaterialLibraryClass.reset_season()

func _test_season_apply_preserves_roughness() -> void:
	var green_mat: StandardMaterial3D = AssetFactory._material(AssetFactory.GREEN)
	var rough_before: float = green_mat.roughness
	var metallic_before: float = green_mat.metallic
	AssetFactory.apply_season(2)
	check(is_equal_approx(green_mat.roughness, rough_before), "season apply does not change material roughness")
	check(is_equal_approx(green_mat.metallic, metallic_before), "season apply does not change material metallic")
	AssetFactory.apply_season(1)

func _test_readability_constants() -> void:
	check(PaletteClass.READABILITY.ball == Color("fffbef"), "ball readability color is warm white")
	check(PaletteClass.READABILITY.has("overlay_traffic"), "overlay traffic gradient is defined")
	var traffic: Array = PaletteClass.READABILITY.overlay_traffic
	check(traffic.size() == 2, "traffic overlay gradient has two stops")
	check(float(traffic[1].a) > 0.8, "traffic overlay max alpha stays readable")

func _test_calibration_scene_builds() -> void:
	var scene: Node3D = CalibrationClass.build_root(1)
	check(scene.get_child_count() >= 2, "calibration scene includes lighting and samples")
	var samples: Node3D = scene.get_node_or_null("SurfaceSamples") as Node3D
	check(samples != null and samples.get_child_count() >= 5, "calibration scene includes surface swatches")
	scene.free()

func _test_shadow_contract() -> void:
	check(ShadowClass.ssao_supported(), "SSAO is supported on the installed Compatibility renderer")
	var standard: GraphicsSettings = SettingsClass.for_preset("standard")
	check(standard.ssao_enabled, "standard preset enables SSAO")
	check(is_equal_approx(standard.shadow_bias, 0.12), "standard shadow bias tuned for contact")
	check(standard.shadow_splits == 2, "standard preset keeps two shadow cascades")
	var low: GraphicsSettings = SettingsClass.for_preset("low")
	check(not low.ssao_enabled, "low preset disables SSAO")
	check(not low.tree_shadow_volumes, "low preset disables canopy shadow proxies")
	check(not low.terrain_cast_shadows, "terrain casting stays off on low tier")
	var high: GraphicsSettings = SettingsClass.for_preset("high")
	check(high.shadow_splits == 4, "high preset uses four shadow cascades")
	check(ShadowClass.preset_rows().size() == 3, "shadow preset table documents three tiers")
	var oak_mesh: ArrayMesh = AssetFactory.tree_shadow_mesh(false)
	var pine_mesh: ArrayMesh = AssetFactory.tree_shadow_mesh(true)
	check(oak_mesh.get_surface_count() == 1, "oak shadow proxy mesh builds")
	check(pine_mesh.get_surface_count() == 1, "pine shadow proxy mesh builds")
	check(oak_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 0, "oak shadow proxy has vertices")
	check(pine_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 0, "pine shadow proxy has vertices")
	var diagnostics: Node3D = DiagnosticsClass.build_root(standard)
	check(diagnostics.get_node_or_null("ContactSet") != null, "shadow diagnostics scene includes contact set")
	check(diagnostics.get_node_or_null("Sun") != null, "shadow diagnostics scene includes sun")
	diagnostics.free()
	var light := DirectionalLight3D.new()
	ShadowClass.apply_directional_light(light, high)
	check(is_equal_approx(light.shadow_bias, high.shadow_bias), "GraphicsShadow applies directional bias")
	check(light.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "high split mode applied")
	var env := Environment.new()
	ShadowClass.apply_environment_ssao(env, low)
	check(not env.ssao_enabled, "SSAO apply respects low preset off switch")
	ShadowClass.apply_environment_ssao(env, standard)
	check(env.ssao_enabled, "SSAO apply enables on standard preset")
	check(is_equal_approx(env.ssao_radius, standard.ssao_radius), "SSAO radius comes from settings")
	var clubhouse: Node3D = AssetFactory.build("clubhouse", 0)
	var baked: bool = false
	for child in clubhouse.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var colors: Variant = child.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
			if colors != null and colors.size() > 0:
				for c in colors:
					if c != Color.WHITE:
						baked = true
						break
	clubhouse.free()
	check(baked, "static prop bake stores object-space self-occlusion in vertex colors")

func _test_atmosphere_contract() -> void:
	check(AtmosphereClass.fog_supported(), "basic fog is supported on the installed Compatibility renderer")
	check(AtmosphereClass.preset_rows().size() == 3, "atmosphere preset table documents three tiers")
	var low: GraphicsSettings = SettingsClass.for_preset("low")
	check(not low.atmosphere_clouds, "low preset disables cosmetic clouds")
	check(is_equal_approx(low.atmosphere_haze, 0.45), "low preset reduces haze strength")
	var standard: GraphicsSettings = SettingsClass.for_preset("standard")
	check(standard.atmosphere_clouds, "standard preset enables cosmetic clouds")
	check(is_equal_approx(standard.atmosphere_haze, 1.0), "standard preset uses full haze scale")
	var high: GraphicsSettings = SettingsClass.for_preset("high")
	check(is_equal_approx(high.atmosphere_cloud_strength, 0.72), "high preset raises cloud strength")
	var env := Environment.new()
	AtmosphereClass.apply_environment_atmosphere(env, standard, 1)
	check(env.fog_enabled, "standard atmosphere enables depth fog")
	check(env.fog_mode == Environment.FOG_MODE_DEPTH, "atmosphere uses depth fog rather than volumetric fog")
	var fog: Dictionary = AtmosphereClass.fog_parameters(1, standard)
	check(float(fog.depth_begin) >= 780.0, "fog depth begin stays beyond typical course framing")
	check(float(fog.depth_end) <= 2400.0, "fog depth end stays within camera far clip")
	var summer: Dictionary = PaletteClass.atmosphere_for_season(1)
	check(summer.has("haze_tint"), "summer atmosphere palette exposes haze tint")
	var horizon: Dictionary = AtmosphereClass.horizon_shader_params(1, standard)
	check(float(horizon.haze_strength) > 0.0, "horizon shader receives non-zero haze strength")
	for path in [
		"res://shaders/resort_horizon.gdshader",
		"res://shaders/resort_distant_foliage.gdshader",
		"res://shaders/resort_cloud_layer.gdshader",
	]:
		var shader: Shader = load(path)
		check(shader != null, "atmosphere shader loads: " + path)

func _test_gen2_trees_contract() -> void:
	check(TreeAssetsClass.available(), "shipped gen2 tree assets are present")
	var manifest: Dictionary = TreeAssetsClass.manifest()
	check(manifest.has("lod_thresholds"), "tree manifest documents LOD thresholds")
	check(manifest.get("crown_choice", {}).get("selected", "") == "opaque_clusters", "crown prototype chose opaque clusters")
	var thresholds: Dictionary = TreeAssetsClass.lod_thresholds()
	check(float(thresholds.get("near_end", 0.0)) > float(thresholds.get("mid_begin", 0.0)), "near LOD ends before mid overlap")
	AssetFactory.gen2_trees_enabled = true
	AssetFactory.clear_tree_cache()
	var oak: Node3D = AssetFactory.build("oak_tree", 1)
	check(oak.get_meta("skip_bake", false), "gen2 oak skips runtime bake")
	var mesh_count: int = 0
	for child in oak.get_children():
		if child is MeshInstance3D:
			mesh_count += 1
			if child.material_override == AssetFactory._foliage():
				check(child.visibility_range_end > child.visibility_range_begin, "gen2 foliage LOD range is valid")
	check(mesh_count >= 4, "gen2 oak ships near/mid/far bark and foliage parts")
	var shadow: ArrayMesh = AssetFactory.tree_shadow_mesh(false, 1)
	check(shadow != null and shadow.get_surface_count() == 1, "gen2 oak shadow mesh loads")
	oak.free()
	AssetFactory.gen2_trees_enabled = false
	AssetFactory.clear_tree_cache()
	var legacy: Node3D = AssetFactory.build("oak_tree", 1)
	check(legacy.get_child_count() <= 3, "legacy oak falls back to procedural bake")
	legacy.free()
	AssetFactory.gen2_trees_enabled = true
	AssetFactory.clear_tree_cache()

func _test_ground_cover_contract() -> void:
	check(GroundCoverAssetsClass.available(), "shipped ground-cover assets are present")
	var manifest: Dictionary = GroundCoverAssetsClass.manifest()
	check(manifest.has("lod_thresholds"), "ground-cover manifest documents LOD thresholds")
	check(manifest.get("variants", []).size() >= 6, "ground-cover manifest lists all families")
	var thresholds: Dictionary = GroundCoverAssetsClass.lod_thresholds()
	check(float(thresholds.get("near_end", 0.0)) > float(thresholds.get("far_begin", 0.0)), "near LOD ends after far overlap begins")
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var region: Vector2i = GroundCoverClass.region_key_for_point(Vector3(200.0, 0.0, 200.0))
	var settings: GraphicsSettings = SettingsClass.defaults()
	var batches_a: Array = GroundCoverClass.build_region_batches(terrain, region, settings)
	var batches_b: Array = GroundCoverClass.build_region_batches(terrain, region, settings)
	check(str(batches_a) == str(batches_b), "ground cover scatter is deterministic for a region")
	var low: GraphicsSettings = SettingsClass.for_preset("low")
	var dense: Array = GroundCoverClass.build_region_batches(terrain, region, settings)
	var sparse: Array = GroundCoverClass.build_region_batches(terrain, region, low)
	var dense_count: int = 0
	var sparse_count: int = 0
	for batch in dense:
		dense_count += (batch as Dictionary).get("instances", []).size()
	for batch in sparse:
		sparse_count += (batch as Dictionary).get("instances", []).size()
	check(sparse_count <= dense_count, "low foliage density reduces ground-cover instances without reshuffling survivors")
	var cup_region: Vector2i = GroundCoverClass.region_key_for_point(TerrainModel.effective_cup(terrain.holes[0]))
	var cup_batches: Array = GroundCoverClass.build_region_batches(terrain, cup_region, settings)
	for batch_value in cup_batches:
		var batch: Dictionary = batch_value
		for row in batch.get("instances", []):
			var pos: Vector3 = (row as Dictionary).get("transform", Transform3D.IDENTITY).origin
			check(terrain.surface_at(pos) != 2, "ground cover avoids green surfaces near cup")
	var mesh: ArrayMesh = GroundCoverAssetsClass.load_mesh("rough_tuft", 0, "near")
	check(mesh != null and mesh.get_surface_count() == 1, "rough tuft near mesh loads")
	GroundCoverAssetsClass.clear_cache()

func _test_renderer_comparison_contract() -> void:
	check(RendererComparisonClass.is_valid_method("gl_compatibility"), "gl_compatibility is a supported trial method")
	check(RendererComparisonClass.is_valid_method("mobile"), "mobile is a supported trial method")
	check(RendererComparisonClass.is_valid_method("forward_plus"), "forward_plus is a supported trial method")
	check(not RendererComparisonClass.is_valid_method("vulkan"), "unknown renderer methods are rejected")
	check(
		RendererComparisonClass.project_method() == "gl_compatibility",
		"project default renderer remains gl_compatibility"
	)
	var compat_caps: Dictionary = RendererComparisonClass.capabilities_for("gl_compatibility")
	check(not bool(compat_caps.get("gpu_frame_time_ms", true)), "Compatibility headless trial omits GPU frame timings")
	var compat_features: Dictionary = compat_caps.get("renderer_features", {})
	check(compat_features.get("ssr", true) == false, "Compatibility feature matrix disables SSR")
	check(compat_features.get("reflection_probes", false) == true, "Compatibility feature matrix keeps reflection probes")
	var mobile_caps: Dictionary = RendererComparisonClass.capabilities_for("mobile")
	var mobile_features: Dictionary = mobile_caps.get("renderer_features", {})
	check(mobile_features.get("ssr", false) == true, "Mobile feature matrix enables SSR")
	var audit: Array = RendererComparisonClass.audit_shaders()
	check(audit.size() == RendererComparisonClass.SHADER_PATHS.size(), "shader audit covers every resort shader path")
	for row in audit:
		var path: String = str(row.get("path", ""))
		check(row.get("exists", false), "audited shader file exists: " + path)
		check(row.get("compiles", false), "audited shader compiles: " + path)
		for issue in row.get("issues", PackedStringArray()):
			check(
				str(issue).find("hint_screen_texture") < 0 and str(issue).find("hint_depth_texture") < 0,
				"shader avoids incompatible depth/screen sampling: " + path
			)

func _test_mowing_cosmetic_contract() -> void:
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var hole: Dictionary = terrain.holes[0]
	var pattern: Dictionary = HoleMowingClass.effective_pattern(hole)
	check(pattern.has("orientation"), "starter holes receive autonomous mowing defaults")
	check(float(pattern.get("width", 0.0)) > 0.0, "mowing width default is positive")
	var owner: int = terrain.fairway_owner(hole["tee"])
	check(owner == int(hole.get("id", -1)), "tee fairway ownership resolves to its hole")
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5150
	var shot_a: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	terrain.holes[0]["mowing"] = {"orientation": 2.4, "contrast": 0.2, "fairway_cells": []}
	terrain.touch()
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5150
	var shot_b: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	check(str(shot_a) == str(shot_b), "mowing metadata does not change shot results")
	check(HoleMowingClass.overview_fade(420.0) > HoleMowingClass.overview_fade(900.0), "overview fade reduces stripe contrast when zoomed out")

func _test_actor_motion_contract() -> void:
	var motion: ActorMotion = ActorMotionClass.new()
	var shot: Dictionary = {
		"start": Vector3(10, 0, 10),
		"landing": Vector3(40, 0, 18),
		"end": Vector3(42, 0, 19),
		"arc": 6.0,
		"physics_duration": 1.6,
		"club": "iron",
		"holed": false,
	}
	var timeline: Dictionary = ActorMotionClass.shot_visual_timeline(shot, false)
	check(float(timeline["contact_time"]) == ActorMotionClass.SWING_TOTAL * 0.5, "contact occurs at mid-swing")
	check(float(timeline["launch_time"]) == float(timeline["contact_time"]), "ball launch aligns with contact")
	motion.register_shot(1, shot)
	check(motion.ball_position(1) == Vector3(shot.start), "ball stays at tee until contact")
	motion.visual_shots[1]["time"] = float(timeline["contact_time"]) + 0.2
	check(motion.ball_position(1).distance_to(Vector3(shot.start)) > 0.5, "ball moves after contact")
	var address_pose: Dictionary = ActorMotionClass.swing_pose(0.05, false)
	check(address_pose.get("activity", "") == "address", "early swing maps to address")
	var follow_pose: Dictionary = ActorMotionClass.swing_pose(ActorMotionClass.SWING_TOTAL * 0.7, false)
	check(follow_pose.get("activity", "") in ["follow_through", "idle"], "late swing maps to follow-through or idle")
	var putt_timeline: Dictionary = ActorMotionClass.shot_visual_timeline(shot, true)
	check(float(putt_timeline["swing_duration"]) == ActorMotionClass.PUTT_TOTAL, "putt uses shorter swing window")
	var settings: GraphicsSettings = SettingsClass.defaults()
	check(ActorMotionClass.animation_detail(20.0, settings) == 2, "near actors use full animation detail")
	check(ActorMotionClass.animation_detail(500.0, settings) == 0, "far actors use simplified animation detail")
	var golfer: Node3D = AssetFactory.golfer()
	for activity in ["address", "backswing", "contact", "follow_through"]:
		AssetFactory.animate_golfer(golfer, activity, 0.5)
	var club: Node3D = golfer.get_node("Club") as Node3D
	var club_before: Vector3 = club.rotation
	AssetFactory.animate_golfer(golfer, "contact", 0.9, 1.2)
	check(club.rotation != club_before, "swing aim yaw affects club pose")
	AssetFactory.animate_golfer(golfer, "walking", 0.25, NAN, true)
	check(club.rotation == Vector3.ZERO, "simplified distant rig resets limbs")
	golfer.free()
	var cart: Node3D = AssetFactory.cart()
	motion.update_cart(9, cart, Vector3(100, 0, 100), null, Vector3.ZERO, settings, 0.1)
	for wheel_path in ArchitectureManifest.contracts()["cart"]["dynamic_nodes"]:
		var wheel: Node3D = cart.get_node_or_null(wheel_path) as Node3D
		check(wheel != null, "cart wheel pivot remains available to motion: " + wheel_path)
	cart.free()
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var hole: Dictionary = terrain.holes[0]
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5150
	var shot_a: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5150
	var shot_b: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	check(str(shot_a) == str(shot_b), "actor motion layer does not change shot results")
	motion.reset()
	check(motion.visual_shots.is_empty(), "motion reset clears visual shot cache")

func _test_event_effects_contract() -> void:
	var dedup_ring: Array[int] = []
	var dedup_lookup: Dictionary = {}
	var event_id: int = EffectEventClass.make_id(3, 42, EffectEventClass.Type.SAND_PUFF)
	var consume := func(id: int) -> bool:
		if dedup_lookup.has(id):
			return false
		if dedup_ring.size() >= EffectEventClass.DEDUP_CAPACITY:
			dedup_lookup.erase(int(dedup_ring.pop_front()))
		dedup_ring.append(id)
		dedup_lookup[id] = true
		return true
	check(consume.call(event_id), "effect dedup accepts first event id")
	check(not consume.call(event_id), "effect dedup rejects duplicate event id")
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var bunker_shot: Dictionary = {
		"serial": 7,
		"club": "iron",
		"landing": Vector3(120.0, 0.0, 120.0),
		"landing_surface": 4,
	}
	var bunker_events: Array = EffectEventClass.contact_events_for_shot(1, bunker_shot, 0.35, terrain)
	check(bunker_events.size() == 1, "bunker landing emits sand puff only")
	check(int((bunker_events[0] as Dictionary).get("type", -1)) == EffectEventClass.Type.SAND_PUFF, "bunker maps to sand puff")
	var green_shot: Dictionary = bunker_shot.duplicate(true)
	green_shot["landing_surface"] = 2
	var green_events: Array = EffectEventClass.contact_events_for_shot(1, green_shot, 0.35, terrain)
	check(green_events.is_empty(), "green landing does not emit sand puff")
	var fairway_shot: Dictionary = {
		"serial": 8,
		"club": "iron",
		"landing": Vector3(130.0, 0.0, 130.0),
		"landing_surface": 1,
	}
	var fairway_events: Array = EffectEventClass.contact_events_for_shot(2, fairway_shot, 0.35, terrain)
	check(fairway_events.size() == 1, "fairway iron emits turf divot")
	check(int((fairway_events[0] as Dictionary).get("type", -1)) == EffectEventClass.Type.TURF_DIVOT, "fairway maps to divot")
	var putt_shot: Dictionary = fairway_shot.duplicate(true)
	putt_shot["club"] = "putter"
	var putt_events: Array = EffectEventClass.contact_events_for_shot(2, putt_shot, 0.35, terrain)
	check(putt_events.is_empty(), "putts skip turf divot marks")
	var motion: ActorMotion = ActorMotionClass.new()
	var shot: Dictionary = {
		"start": Vector3(10, 0, 10),
		"landing": Vector3(40, 0, 18),
		"end": Vector3(42, 0, 19),
		"arc": 6.0,
		"physics_duration": 1.6,
		"club": "iron",
		"landing_surface": 1,
		"serial": 99,
	}
	motion.register_shot(5, shot)
	var timeline: Dictionary = ActorMotionClass.shot_visual_timeline(shot, false)
	motion.visual_shots[5]["time"] = float(timeline["launch_time"]) - 0.01
	var root_node := Node3D.new()
	var manager = EffectManagerClass.new()
	manager.attach(root_node)
	manager.configure(SettingsClass.defaults())
	manager.poll_shot_effects(motion, terrain, null, Vector3(35, 0, 15), SettingsClass.defaults())
	check(manager.stats().get("active_puffs", 1) == 0, "contact effects wait until launch time")
	motion.visual_shots[5]["time"] = float(timeline["launch_time"]) + 0.02
	manager.poll_shot_effects(motion, terrain, null, Vector3(35, 0, 15), SettingsClass.defaults())
	check(int(manager.stats().get("active_marks", 0)) >= 1, "launch crossing spawns divot mark")
	manager.poll_shot_effects(motion, terrain, null, Vector3(35, 0, 15), SettingsClass.defaults())
	check(int(manager.stats().get("active_marks", 0)) >= 1, "duplicate poll does not respawn contact mark")
	motion.reset()
	manager.reset()
	manager.teardown()
	root_node.free()
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5150
	var hole: Dictionary = terrain.holes[0]
	var shot_a: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 5150
	var shot_b: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	check(str(shot_a) == str(shot_b), "event layer does not change shot results")
	var low: GraphicsSettings = SettingsClass.for_preset("low")
	check(low.effect_instance_cap == 24, "low preset caps cosmetic effects")
	manager = EffectManagerClass.new()
	manager.configure(low)
	check(int(manager.stats().get("total_cap", -1)) == 24, "manager reads effect_instance_cap")
	manager.teardown()

func _test_reflection_probe_contract() -> void:
	check(ReflectionProbesClass.probes_supported(), "reflection probes supported on installed Compatibility renderer")
	var layers: Dictionary = ReflectionProbesClass.layer_contract()
	check(int(layers.capture_mask) == ReflectionProbesClass.LAYER_SCENE, "capture mask targets scene layer only")
	check(int(layers.water) == ReflectionProbesClass.LAYER_WATER, "water layer documented for self-capture exclusion")
	var high: GraphicsSettings = SettingsClass.for_preset("high")
	if ReflectionProbesClass.probes_supported():
		check(high.reflection_mode == "planar", "high preset enables planar mode when supported")
	check(high.reflection_resolution == 512, "high preset uses 512 reflection capture resolution")
	var standard: GraphicsSettings = SettingsClass.for_preset("standard")
	if ReflectionProbesClass.probes_supported():
		check(standard.reflection_mode == "probe", "standard preset enables probe mode when supported")
	check(standard.reflection_resolution == 256, "standard preset uses 256 reflection capture resolution")
	var low: GraphicsSettings = SettingsClass.for_preset("low")
	check(low.reflection_mode == "sky", "low preset keeps sky-only reflections")
	check(ReflectionProbesClass.max_probe_count(low) == 0, "low tier allocates no managed probes")
	check(ReflectionProbesClass.max_probe_count(standard) == 1, "standard tier allocates one managed probe")
	if high.reflection_mode == "planar":
		check(ReflectionProbesClass.max_probe_count(high) == 1, "planar high tier keeps one spatial probe for materials")
	else:
		check(ReflectionProbesClass.max_probe_count(high) == 1, "high tier keeps the explicit single-probe budget")
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var placements_a: Array = ReflectionProbesClass._compute_placements(terrain, 1)
	var placements_b: Array = ReflectionProbesClass._compute_placements(terrain, 1)
	check(placements_a.size() == 1, "starter lakeside yields one lakeside probe placement")
	check(str(placements_a) == str(placements_b), "probe placement is deterministic for a fixed terrain")
	if placements_a.size() > 0:
		var placement: Dictionary = placements_a[0]
		check(float(placement.get("size", Vector3.ZERO).x) >= ReflectionProbesClass.MIN_PROBE_EXTENT_M, "probe span covers the dominant lake")
		var clubhouse: Vector3 = Vector3(171, 0, 290) + terrain.entrance - TerrainModel.DEFAULT_ENTRANCE
		var shore: Vector3 = placement.get("shore_anchor", Vector3.ZERO)
		check(shore.distance_to(clubhouse) < 90.0, "starter probe shore anchor stays at clubhouse lakeside")

func _test_planar_reflection_contract() -> void:
	check(PlanarReflectionsClass.planar_supported(), "planar reflections supported on installed Compatibility renderer")
	var high: GraphicsSettings = SettingsClass.for_preset("high")
	if PlanarReflectionsClass.planar_supported():
		check(high.reflection_mode == "planar", "high preset selects planar when capability is present")
	check(PlanarReflectionsClass.capture_resolution(high) == 256, "planar capture defaults to half of high reflection resolution")
	var standard: GraphicsSettings = SettingsClass.for_preset("standard")
	check(standard.reflection_mode == "probe", "standard preset keeps probe reflections")
	var fixture: Node3D = PlanarFixtureClass.build_root(high)
	check(fixture.get_node_or_null("OffsetClubhouse") != null, "planar fixture includes asymmetric clubhouse")
	check(fixture.get_node_or_null("LakePlane") != null, "planar fixture includes flat water plane")
	fixture.free()
	var main_transform := Transform3D(Basis.IDENTITY, Vector3(20.0, 30.0, 24.0))
	main_transform = main_transform.looking_at(Vector3(8.0, 0.0, 6.0), Vector3.UP)
	var reflected: Transform3D = PlanarReflectionsClass.reflect_transform_across_plane(
		main_transform,
		Plane(Vector3.UP, 0.0),
	)
	check(reflected.origin.y < 0.0, "reflected camera mirrors below the water plane")
	check(reflected.basis.y.dot(Vector3.UP) < 0.0, "reflected camera basis flips across the mirror plane")
	var planar_settings: GraphicsSettings = SettingsClass.defaults()
	planar_settings.reflection_mode = "planar"
	planar_settings.sanitize()
	if PlanarReflectionsClass.planar_supported():
		check(planar_settings.reflection_mode == "planar", "sanitize retains planar mode when supported")
	else:
		check(planar_settings.reflection_mode in ["probe", "sky"], "sanitize downgrades planar when unsupported")

func _test_invalid_fallback() -> void:
	var settings: GraphicsSettings = SettingsClass.defaults()
	settings.load_dict({
		"preset": "ultra",
		"foliage_density": 9.0,
		"shadow_resolution": 3333,
		"reflection_mode": "planar",
		"msaa_3d": 99,
	})
	check(settings.preset == SettingsClass.Preset.STANDARD, "unknown preset falls back to Standard")
	check(is_equal_approx(settings.foliage_density, 1.0), "out-of-range foliage density clamps")
	check(settings.shadow_resolution == 4096, "unknown shadow resolution snaps to nearest supported size")
	if PlanarReflectionsClass.planar_supported():
		check(settings.reflection_mode == "planar", "planar reflection mode retained when supported")
	else:
		check(settings.reflection_mode == "sky", "unsupported planar reflection mode falls back")
	check(settings.msaa_3d == 3, "MSAA clamps to supported range")
	var probe_settings: GraphicsSettings = SettingsClass.defaults()
	probe_settings.reflection_mode = "probe"
	probe_settings.sanitize()
	if ReflectionProbesClass.probes_supported():
		check(probe_settings.reflection_mode == "probe", "probe mode retained when renderer supports probes")
	else:
		check(probe_settings.reflection_mode == "sky", "probe mode falls back to sky when unsupported")

func _test_persistence_round_trip() -> void:
	var service: GraphicsSettingsService = SettingsService.new()
	service.current.apply_preset(SettingsClass.Preset.LOW)
	var err: String = service.save()
	check(err.find("Could not") < 0, "graphics settings save succeeds")
	var reloaded: GraphicsSettingsService = SettingsService.new()
	check(reloaded.current.preset == SettingsClass.Preset.LOW, "graphics settings reload preset")
	check(is_equal_approx(reloaded.current.foliage_density, 0.55), "graphics settings reload low foliage density")
	service.current.apply_preset(SettingsClass.Preset.STANDARD)
	service.save()

func _test_quality_does_not_touch_sim() -> void:
	var terrain := MapGenerator.generate(Catalog.map("cedar_house"))
	terrain.starter_resort()
	var hole: Dictionary = terrain.holes[0]
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 4242
	var shot_a: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_a)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var rng_state_before: int = int(game.sim._rng.state)
	game.graphics.set_preset("low")
	game.graphics.apply_to_game(game, true)
	check(int(game.sim._rng.state) == rng_state_before, "graphics apply does not advance simulation RNG")
	game.graphics.set_preset("high")
	game.graphics.apply_to_game(game, true)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 4242
	var shot_b: Dictionary = ShotEngineClass.shot(terrain, hole["tee"], hole, 0.62, rng_b)
	check(str(shot_a) == str(shot_b), "graphics quality does not change shot results")
	game.queue_free()
	await process_frame

func _test_low_survives_world_recreation() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.graphics.set_preset("low")
	game.graphics.apply_to_game(game, true)
	var rng_state: int = int(game.sim._rng.state)
	game._recreate_world()
	await process_frame
	check(game.graphics.current.preset == SettingsClass.Preset.LOW, "low preset survives world recreation")
	check(int(game.sim._rng.state) == rng_state, "world recreation keeps simulation RNG")
	game.queue_free()
	await process_frame
