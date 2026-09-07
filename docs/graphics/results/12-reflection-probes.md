# Package 12 — Managed reflection probes

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 12 adds a deterministic single-probe budget for Standard/High presets on Compatibility. One managed `ReflectionProbe` is placed from the dominant water body plus nearby structures (starter lakeside: clubhouse cluster). A coalesced orthographic capture pass feeds the package 11 `reflection_map` water hook; built-in probes also influence standard spatial materials (cart, windows, test chrome sphere). Low tier remains sky-only with `water_reflection_strength = 0`.

## Placement rules

| Step | Rule |
|---|---|
| Budget | Low **0** probes; Standard/High **1** probe (`MAX_PROBES_STANDARD` / `MAX_PROBES_HIGH`) |
| Body pick | Sort `WaterField.active_body_ids()` by cell count; take largest bodies up to budget |
| Origin | AABB center of selected body in world xz; probe Y = mean water level + 6 m |
| Extents | Water AABB expanded by **56 m** (`STRUCTURE_MARGIN_M`) to include nearby placed objects; minimum span **96 m** per axis |
| Shore anchor | Nearest non-path object to body center → chrome test marker + lakeside framing |
| Box projection | Enabled on managed probes |
| Overlap | Single probe only — avoids Compatibility per-mesh overlap limit on broad lake meshes |

Starter `cedar_house` lakeside: one probe covering the main lake (~cells 53–108) and clubhouse/restroom/kiosk/cart barn cluster.

## Invalidation rules

| Event | Action |
|---|---|
| `TerrainView.setup()` / `apply_graphics_settings()` | Recompute placements, resize capture, schedule capture |
| `TerrainView.rebuild_dirty()` | `notify_edit_burst()` (terrain/surface/water edits) |
| `TerrainView.sync_objects()` | `notify_edit_burst()` (construction / removal) |
| `TerrainView.set_season()` | `notify_edit_burst()` |
| `GraphicsAtmosphere.invalidate_reflection_captures(root)` | Existing probes → `UPDATE_ONCE` (sky/atmosphere/season/lighting from `main.gd`) |
| Burst coalescing | **0.35 s** debounce (`DEBOUNCE_SEC`); at most one orthographic capture per debounced burst |
| Disabled / Low preset | Probes hidden; `set_reflection_texture(null)`; water uses sky-only depth tint |

Removed buildings leave the scene graph on next `sync_objects`; the following debounced capture drops them from `reflection_map`.

## Layer assignments

| Layer bit | Value | Captured by probe / water pass? | Contents |
|---|---:|---|---|
| `LAYER_SCENE` | 1 | **Yes** | Terrain, buildings, vegetation, horizon, distant foliage, clouds, paths, chrome test marker |
| `LAYER_WATER` | 2 | **No** | Water mesh chunks (self-capture avoided) |
| `LAYER_DYNAMIC` | 4 | **No** | Golfers, staff, carts, balls |
| `LAYER_HELPER` | 8 | **No** | Cursor rings/lines, selection outlines, analysis overlays |

`CAPTURE_MASK = LAYER_SCENE` (1) on `ReflectionProbe.cull_mask` and capture camera.

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_reflection_probes.gd` | Probe manager: placement, layers, debounced capture, test marker |
| `scripts/graphics_settings.gd` | Standard/High → `probe` when supported; `sanitize` allows probe, still blocks planar |
| `scripts/terrain_view.gd` | Owns manager, water layer tagging, `mark_reflections_dirty()`, reflection shader gating |
| `scripts/main.gd` | Dynamic/helper layer tagging; probe invalidation on graphics + season |
| `tests/test_graphics.gd` | Probe contract + sanitize tests |

### Deviations from plan

- **Probe count:** Kept at **1** for both Standard and High (explicit small budget); no multi-probe automation yet.
- **Water reflection map:** Orthographic xz capture (matches existing `reflection_map` UVs) rather than cubemap sampling in `resort_water.gdshader` — probes still benefit standard materials; water uses the shared capture pass.
- **Windowed validation:** Not run (headless contract only).

## Quality tiers

| Preset | `reflection_mode` | Resolution | Probes | `water_reflection_strength` |
|---|---|---:|---:|---:|
| Low | `sky` | 128 | 0 | 0.0 |
| Standard | `probe`* | 256 | 1 | 0.28 |
| High | `probe`* | 512 | 1 | 0.34 |

\*Falls back to `sky` when `GraphicsReflectionProbes.probes_supported()` is false.

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** |
| `tests/capture_lush.gd` | Not run (windowed) |
| Capture spike benchmark | Not run separately |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd
```

## Known limitations / follow-up

1. **Windowed motion review** — Inspect reflection lag, shimmer and clubhouse readability with `tests/capture_lush.gd`.
2. **Broad lake accuracy** — xz-projected capture is approximate on the full lake; package 13 planar trial is the optional upgrade path.
3. **Multi-body maps** — Only the largest water body receives a probe until budget evidence justifies more.
4. **Capture spike metrics** — Benchmark probe refresh separately from steady-state (package 01 harness).

## Next step

Package 13: optional planar lake pass for dominant water plane; reuse `set_reflection_texture` and sky/probe fallback outside the valid capture region.
