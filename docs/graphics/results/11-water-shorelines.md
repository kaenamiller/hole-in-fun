# Package 11 — Depth-aware water and shoreline materials

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 11 replaces mask-edge water tinting with a maintained 256×256 `water_field` texture derived from gameplay water levels and basin heights. Connected cells at matching elevations share stable merged `body_id` values; inconsistent levels split at the flood-fill boundary. `resort_water.gdshader` shades shallow→deep from physical depth, multi-scale filtered normals, and a capped cosmetic ripple pool. `resort_ground.gdshader` damps bank soil/sand using shore distance and slope. Gameplay `water_levels`, penalties, and mesh placement are unchanged.

## Field / channel definitions

### Authoritative semantics

| Concept | Source | Notes |
|---|---|---|
| Basin height | `TerrainModel.height_at(p)` bilinear | Shared with mesh + shots |
| Water surface | `water_levels[cell]` when `surface == 5` | Per-cell; may differ across a map |
| Body membership | `WaterField` flood fill | 4-connected water cells with `abs(level_a - level_b) <= 0.25 m` |
| Physical depth | `max(0, surface_y - basin_y)` | Clamped field range 0–12 m |
| Shore distance (water) | metres to nearest dry cell | Used for foam / shallow tint |
| Shore distance (dry) | metres to nearest water cell | Used for bank blend |

Disconnected bodies and elevation splits receive distinct `body_id` values (stable minimum cell index per component).

### `water_field` texture (256×256 RGBA)

| Channel | Water cells | Dry cells |
|---|---|---|
| R | `depth / 12 m` | 0 |
| G | `shore_in / 16 m` | `shore_out / 16 m` |
| B | `body_id / 255` | nearest-body id / 255 (0 when none) |
| A | 255 (mask) | 0 |

Artistic shader uniforms (`depth_tint_strength`, `shallow_depth_m`, `deep_depth_m`, `water_tint`) are independent of the physical depth scale.

## Invalidation rules

| Event | Action |
|---|---|
| `TerrainModel.touch()` | `_water_dirty_full = true` |
| `apply_brush` height/surface/water_level edits | `mark_water_field_dirty(bounds)` expanded by shore band |
| `restore(snapshot)` | full invalidation via `touch()` |
| `TerrainView._update_surface_maps` | partial rebuild when `changed_surface_chunks` set, else dirty-rect flush |
| `TerrainView.rebuild_dirty` | `_update_water_field_maps(true)` on surface edits |

Regional rebuild pads dirty rects by `ceil(16 m / 4 m) + 2` cells. Full rebuild is O(256²) and runs on load / first use.

## Ripple API (package 16 dispatch)

```gdscript
# Submit (returns false when rejected)
TerrainView.submit_water_ripple(body_id, world_pos, start_time, radius, strength) -> bool

# Or directly:
WaterRipplePool.submit(body_id, world_pos, start_time, radius, strength, terrain) -> bool
```

**Contract**

| Field | Type | Rule |
|---|---|---|
| `body_id` | int | Must match `water_body_at(world_pos).body_id` and `WaterField.body_exists` |
| `world_pos` | Vector3 | xz used; must be on water with `depth > 0` |
| `start_time` | float | Cosmetic clock seconds (`Time.get_ticks_msec()/1000` in view) |
| `radius` | float | Clamped 0.5–24 m |
| `strength` | float | Clamped 0–1 |

**Caps:** `GraphicsSettings.water_ripple_cap` — 4 / 8 / 16 for low / standard / high. Pool drops oldest when full. Ripples expire after `3.2 s + radius * 0.12`.

Shader uniforms: `ripple_positions[16]`, `ripple_meta[16]`, `ripple_count`.

## Reflection integration (packages 12/13)

| Hook | Location |
|---|---|
| `TerrainView.set_reflection_texture(tex)` | Binds `reflection_map` on water material |
| `GraphicsSettings.reflection_mode == "planar"` | Enables `use_reflection` (still sky-only until package 13) |
| `GraphicsSettings.water_reflection_strength` | Fresnel-weighted blend |
| `wave_detail` | 0.35 / 0.72 / 1.0 by preset — wave layer amplitude |

Baseline tier (`reflection_mode = "sky"`) retains depth coloration without a second pass.

## Source changes

| File | Role |
|---|---|
| `scripts/water_field.gd` | Body merge, depth/shore arrays, dirty-region rebuild, `water_field` image |
| `scripts/water_ripple_pool.gd` | Cosmetic ripple receiver + shader upload |
| `scripts/terrain_model.gd` | Field cache arrays, dirty marking, `water_body_at` → `WaterField.sample` |
| `scripts/course_contours.gd` | `water_body_query` delegates to `WaterField` |
| `scripts/terrain_view.gd` | `water_field` texture, ripple pool, reflection hook, quality uniforms |
| `scripts/graphics_settings.gd` | `water_wave_detail`, `water_ripple_cap`, `water_reflection_strength` |
| `shaders/resort_water.gdshader` | Depth tint, multi-scale normals, ripples, reflection hook |
| `shaders/resort_ground.gdshader` | Shore-distance bank blend with slope damp |
| `tests/test_terrain.gd` | Depth, body IDs, restore, ripple contract |

### Deviations from plan

- **Windowed captures:** Not run (headless regression only).
- **512 depth texture:** Kept 256×256 gameplay resolution; regional dirty updates instead of full-GPU 512 pass.
- **Shore prop scatter:** Prior `_shore_details` mesh scatter removed in working tree; bank visuals rely on ground shader + existing cover package hooks.

## Checks run

| Check | Result |
|---|---|
| `tests/test_terrain.gd` | **0 failures** (4 new water tests; ~209 s headless) |
| `tests/test_shots.gd` | **0 failures** |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_terrain.gd
"$GODOT_BIN" --headless --path . --script tests/test_shots.gd
```

## Quality tiers

| Preset | `water_wave_detail` | `water_ripple_cap` | Reflection |
|---|---|---|---|
| Low | 0.35 | 4 | off (`water_reflection_strength = 0`) |
| Standard | 0.72 | 8 | hook only (`reflection_mode = sky`) |
| High | 1.0 | 16 | hook ready (`water_reflection_strength = 0.34`) |

## Known limitations / follow-up

1. **Windowed validation** — Run `tests/capture_lush.gd` for seam/motion/shimmer checks.
2. **Package 13** — Wire `set_reflection_texture` from planar capture pass.
3. **Package 16** — Dispatch `submit_water_ripple` from shot impact timeline.
4. **Steep cliff shores** — Slope damp reduces wet soil but does not add geometry lips (package 06 collars remain separate).

## Next step

Package 12/13: connect `set_reflection_texture` and probe baseline; package 16: dispatch ripple events through `submit_water_ripple`.
