# Package 13 — Optional planar lake reflections

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Decision

**Ship** on High preset when `RendererComparison.planar_reflections_supported()` is true (Compatibility/OpenGL on this project). Standard/Low unchanged (probe / sky). Headless budget shows no p95 regression; **windowed motion/correctness review remains outstanding** before treating the adoption gate as fully closed.

## Summary

Package 13 adds an optional second scene pass for the dominant water body on **High** only. A reflected orthographic `Camera3D` renders into a half-resolution `SubViewport` (256 px from the 512 reflection budget). The capture feeds the existing package 11 `reflection_map` hook with planar view-projection UVs, edge falloff, and probe/sky shading outside the valid region. Package 12 spatial probes remain active on High for cart/window materials; probe orthographic water capture is skipped when planar owns the lake texture.

## Reflection math conventions

| Item | Convention |
|---|---|
| Mirror plane | Horizontal `Plane(Vector3.UP, -water_y)` from dominant body mean level |
| Camera reflection | `GraphicsPlanarReflections.reflect_transform_across_plane(main_xform, plane)` — origin and basis reflected; orthonormalized |
| Projection match | Reflected camera copies main camera `projection`, `size`, `far` |
| Water UV (planar) | `reflection_view_projection * vec4(world_x, plane_y, world_z, 1)` → NDC → UV with Y flip |
| Water UV (probe) | `world_pos.xz / 1024.0` (unchanged) |
| Dominant body | Largest `WaterField` body by cell count; 1.15× cell-count + 2 s hysteresis before switching |

## Clipping method

**Reflected-camera near plane at the water surface.** After mirroring the main camera below the plane, `near = max(0.35, abs(plane.distance_to(reflected_origin)) + 0.08)` clips geometry between the reflected camera and the mirror plane (underwater terrain / submerged hull). Shared-world rendering avoids duplicate geometry; winding follows the reflected view matrix (no global double-sided override). Capture `cull_mask` remains `LAYER_SCENE` (1).

## Capture layers (excluded)

| Layer | Value | Captured? |
|---|---:|---|
| `LAYER_SCENE` | 1 | **Yes** — terrain, buildings, vegetation, horizon |
| `LAYER_WATER` | 2 | **No** — avoids self-capture |
| `LAYER_DYNAMIC` | 4 | **No** — golfers, carts, balls |
| `LAYER_HELPER` | 8 | **No** — cursor, selection, overlays |

## Update cadence

| Trigger | Action |
|---|---|
| Main camera pan/zoom/tilt | Refresh when position/size/yaw/elevation exceed thresholds (1.25 m, 2.5 size, 0.004 yaw, 0.01 elev) |
| Static camera | Skip up to **0.14 s**, then re-check |
| Terrain/object/season edit | `notify_edit_burst()` → **0.35 s** debounce (shared with probes) |
| Capture mode | `SubViewport.UPDATE_ONCE` per invalidation |
| Disabled / non-High | SubViewport torn down; zero capture process work |

## Resolution tradeoffs

| Setting | Value |
|---|---|
| High `reflection_resolution` | 512 (schema) |
| Planar capture scale | **0.5×** → **256×256** default |
| Quarter trial | Set `RESOLUTION_SCALE = 0.25` in `graphics_planar_reflections.gd` (128 px); not adopted as default |

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_planar_reflections.gd` | Planar pass manager: mirror camera, viewport, invalidation, body hysteresis |
| `scripts/planar_reflection_fixture.gd` | Isolated flat lake + asymmetric clubhouse/kiosk fixture |
| `scripts/graphics_reflection_probes.gd` | High keeps spatial probe; water ortho capture only when `reflection_mode == "probe"` |
| `scripts/graphics_settings.gd` | High → `planar` when supported; sanitize fallback probe → sky |
| `scripts/renderer_comparison.gd` | `planar_reflections` capability flag |
| `scripts/terrain_view.gd` | Owns planar node; `set_planar_reflection_matrix()` shader hook |
| `shaders/resort_water.gdshader` | `planar_reflection`, `reflection_view_projection`, edge mask |
| `tests/capture_planar_reflections.gd` | Windowed capture entry for fixture |
| `tests/test_graphics.gd` | Planar contract + updated probe/planar tier tests |

### Deviations from plan

- **Adoption gate:** Headless cannot confirm visual correctness or second-pass draw calls; shipped with documented windowed follow-up (same posture as package 12).
- **Quarter resolution:** Implemented as constant scale; default remains half-res after headless budget parity.
- **Multi-body lakes:** Only dominant body receives planar UVs; others keep depth tint / probe influence.

## Quality tiers

| Preset | `reflection_mode` | Water capture | Spatial probes | Planar resolution |
|---|---|---|---|---:|
| Low | `sky` | off | 0 | — |
| Standard | `probe`* | probe ortho 256 | 1 | — |
| High | `planar`*† | planar half 256 | 1 (materials) | 256 |

\*Falls back per `sanitize()`.  
†Falls back to `probe` then `sky` when planar unsupported.

## Benchmarks (headless, starter_lake, 25 s, seed 730241)

| Preset | avg fps | p50 ms | p95 ms | p99 ms | draw calls |
|---|---:|---:|---:|---:|---|
| standard (probe water) | 73.9 | 7.0 | 9.0 | 70.0 | 0† |
| high (planar water) | 74.2 | 7.0 | 9.0 | 72.0 | 0† |

†Headless Compatibility reports `render_info_headless=false`; use windowed `capture_lush.gd` or `capture_planar_reflections.gd` for second-pass draw-call accounting.

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** |
| `tests/capture_planar_reflections.gd` | Not run windowed (headless skips framebuffer) |
| `tests/capture_lush.gd` | Not run |
| Headless `starter_lake` benchmark (standard vs high) | No p95 regression |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd

# Windowed fixture captures
"$GODOT_BIN" --path . --script tests/capture_planar_reflections.gd

# Second-pass / motion review on starter lake
"$GODOT_BIN" --path . --script tests/capture_lush.gd
```

## Known limitations / follow-up

1. **Windowed validation** — Inspect clipping at shorelines, UV stability during pan/zoom/tilt, reflection lag, and second-pass draw calls.
2. **Orthographic lake footprint** — Angled overview still approximates on very wide lakes; edge mask fades invalid samples.
3. **Photo mode / export** — Not re-tested this pass.
4. **Quarter-res default** — Revisit after windowed GPU measurements.

## Handoff path

1. Run `tests/capture_planar_reflections.gd` windowed; confirm clubhouse/kiosk appear upright in reflection and near-plane clip holds at `y = water_y`.
2. Compare High vs Standard on starter lake with `capture_lush.gd` motion clip; count draw calls with planar enabled.
3. If p95 regresses >10% windowed or clipping leaks, set `planar_reflections: false` in `renderer_comparison.gd` FEATURE_MATRIX for `gl_compatibility` and document rejection — planar manager already tears down with no idle overhead.

## Next step

Windowed motion review on M2 @ 1440×900; if clean, treat package 13 adoption gate as closed. Otherwise flip capability off and retain probe-only water on High.
