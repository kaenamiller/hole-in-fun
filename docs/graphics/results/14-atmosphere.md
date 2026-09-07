# Package 14 — Atmospheric depth and distant landscape

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 14 adds Compatibility **depth fog** plus shader-graded horizon hills, three deterministic distant-vegetation silhouette layers outside the playable bounds, and an optional low-contrast cosmetic cloud sheet. Haze and cloud strength scale with Low / Standard / High presets. Playable turf, water, sand and readability accents are not regraded. Volumetric fog is intentionally unused.

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_atmosphere.gd` | Fog presets, horizon/distant/cloud shader params, reflection-probe invalidation hook |
| `scripts/graphics_palette.gd` | `atmosphere_for_season()`, distant vista constants |
| `scripts/graphics_settings.gd` | `atmosphere_haze`, `atmosphere_clouds`, `atmosphere_cloud_strength` |
| `scripts/main.gd` | Applies fog on setup, graphics change and season; probe invalidation |
| `scripts/terrain_view.gd` | Horizon distance alpha, distant vegetation multimeshes, cloud layer, `apply_atmosphere()` |
| `shaders/resort_horizon.gdshader` | Distance haze, cooler/lighter hills, reduced far contrast, sky blend |
| `shaders/resort_distant_foliage.gdshader` | Low-detail silhouette material |
| `shaders/resort_cloud_layer.gdshader` | Slow scrolling cosmetic cloud sheet (Standard/High only) |
| `scripts/color_calibration.gd` | Calibration lighting includes atmosphere fog |
| `scripts/renderer_comparison.gd` | Shader audit includes new atmosphere shaders |
| `tests/test_graphics.gd` | Atmosphere contract tests |

### Deviations from plan

- **Orthographic depth fog:** Verified `FOG_MODE_DEPTH` on Godot 4.7.2 Compatibility; `fog_depth_begin=820` keeps near/mid course readable while far geometry and sky receive haze. Horizon shader distance grading supplements fog where view-space depth is shallow.
- **Clouds:** Kept as a single low-alpha horizontal sheet (`resort_cloud_layer.gdshader`) rather than volumetric or screen-space noise on turf. Disabled on Low; strength scales on High. Revisit if windowed motion review shows distraction.
- **Windowed captures:** Overview / zoom / season PNGs and motion clip deferred (headless dummy framebuffer; same limitation as packages 01–03).

## Fog and palette parameters

### Environment depth fog (Standard tier, summer)

| Parameter | Value | Notes |
|---|---:|---|
| `fog_mode` | `FOG_MODE_DEPTH` | Compatibility basic fog |
| `fog_density` | `0.00115` | × `atmosphere_haze` preset scale |
| `fog_depth_begin` | `820` | Beyond typical ortho overview framing |
| `fog_depth_end` | `2150` | Inside camera `far=2400` |
| `fog_height` | `6.0` | Ground-reference height fog |
| `fog_height_density` | `0.11` | × haze scale |
| `fog_aerial_perspective` | `0.26` | × haze scale |
| `fog_sky_affect` | `0.46` | Blends distant pixels toward sky |
| `fog_light_color` | summer sky horizon → white (38%) | From `GraphicsPalette.atmosphere_for_season()` |

### Quality-tier atmosphere

| Field | Low | Standard | High |
|---|---:|---:|---:|
| `atmosphere_haze` | 0.45 | 1.0 | 1.15 |
| `atmosphere_clouds` | off | on | on |
| `atmosphere_cloud_strength` | 0.0 | 0.55 | 0.72 |

Low disables fog when haze scale ≤ 0.01 gate is not met — at 0.45, fog remains on but at ~52% Standard density.

### Horizon / distant shader grading

| Uniform / data | Purpose |
|---|---|
| Vertex `COLOR.a` | Normalized distance from property edge (120–900 m) |
| `haze_color` | Season sky horizon ↔ top blend |
| `hill_cool` | `(0.94, 0.97, 1.05)` multiply for distant hills |
| `detail_fade` | Lowers horizon gamma 1.65 → 1.22 with distance |
| Distant vegetation | 3 MultiMesh layers, 152 instances, seed `1407`, outside 0..1024 bounds |

Season rows adjust `fog_light`, `haze_tint`, distant foliage (fall/winter cooler) via `atmosphere_for_season()`.

## Camera coverage notes

Orthographic camera (`scripts/orbit_camera.gd`):

| Control | Range | Atmosphere interaction |
|---|---|---|
| `size` (zoom) | 28 – 1250 | Overview fade on turf stripes unchanged; fog targets depth > 820 |
| `elevation` | 0.25 – 2.4 | Raises/lowers view axis; height fog adds aerial separation on hills |
| `distance` | ~550 base | `far=2400`; fog_end 2150 avoids clipping into solid fog |
| `focus` clamp | −20..1044 | Horizon mesh spans −768..1760; distant veg rings 380–1280 m from center |

Recommended windowed validation shots: overview (`size≈470`), wide overview (`size≈1100`), single-hole close (`size≈64–140`), each season, Low vs Standard cloud toggle.

## Probe / reflection coordination

`GraphicsAtmosphere.invalidate_reflection_captures(root)` sets any `ReflectionProbe` to `UPDATE_ONCE` when sky/atmosphere/season changes. Package 12 can call the same hook after probe placement lands.

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** (includes atmosphere contract) |
| `tests/_fog_probe.gd` | Compatibility fog API sets cleanly (headless) |
| `tests/capture_lush.gd` | Not run (windowed) |
| Simulation / shots | Not re-run (unchanged code paths) |

## Known limitations / follow-up

1. **Windowed before/after PNGs + motion clip** — Run `tests/capture_lush.gd` and inspect cloud distraction / horizon parallax across zoom and rotation.
2. **Orthographic fog tuning** — If wide overview still looks flat or near turf grays, adjust `fog_depth_begin` using captured depth readback, not perspective assumptions.
3. **Package 12 probes** — Hook is in place; verify captures refresh after probe manager lands.
4. **Volumetric fog** — Explicitly out of scope; do not enable without renderer migration evidence.

## Regenerate captures (windowed)

```bash
cd /Users/kaenamiller/Documents/ChatGPT/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

"$GODOT_BIN" --path . --script tests/test_graphics.gd
"$GODOT_BIN" --path . --script tests/capture_lush.gd
```

## Next step

Windowed overview + motion review across four seasons and three quality presets; tune `fog_depth_begin` or disable clouds if motion review shows turf distraction.
