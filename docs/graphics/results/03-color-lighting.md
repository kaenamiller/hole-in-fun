# Package 03 — Consistent color and lighting

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 03 centralizes environment and surface palettes in `GraphicsPalette`, wires `main.gd` / `terrain_view.gd` / `AssetFactory` through the same seasonal contract, documents retained shader art curves, and adds a deterministic calibration swatch scene. Visual values match the pre-package configuration (legacy fixture preserved in `GraphicsPalette.LEGACY`). No renderer migration, no simulation/shot changes, bloom remains off.

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_palette.gd` | Environment + surface palette, season tints, readability accents, legacy fixture, art-curve constants |
| `docs/graphics/color-space-contract.md` | Authoring rules and API for packages 04–16 |
| `scripts/color_calibration.gd` | Procedural calibration scene (grays, spheres, turf/water/path/foliage/stone/plaster/timber, flag/ball/tree) |
| `tests/capture_color_calibration.gd` | Capture entry (4 seasons × overview/close) |
| `scenes/color_calibration.tscn` | Scene wrapper for capture script |
| `scripts/main.gd` | `_setup_light` / `_apply_season` use palette; ball + heatmap overlays use `READABILITY` |
| `scripts/terrain_view.gd` | Season tints + surface colors from palette; horizon lake tint constant |
| `scripts/asset_factory.gd` | `apply_season` via palette; preserves roughness/metallic |
| `scripts/terrain_model.gd` | Default palette sourced from `GraphicsPalette.SURFACE_COLORS` |
| `scripts/resort_ui.gd` | Palette chip fallback uses `GraphicsPalette` |
| `tests/test_graphics.gd` | Palette load, season roughness, readability, calibration build tests |

### Deviations from plan

- **Shader `pow()` curves:** Audited and **retained** (no capture justified removal). Documented in `GraphicsPalette.ART_CURVES` and `color-space-contract.md`.
- **Bloom:** Explicitly disabled (`bloom_enabled: false`) — restrained default; no new glow pass.
- **Headless captures:** Dummy renderer has no framebuffer (`root.get_texture()` null); pipeline runs but PNGs require a **windowed** Godot launch (same limitation as package 01/02).

## Color sources traced

| Source | Type | Path to output |
|---|---|---|
| Sun / ambient / sky | Environment sRGB | `GraphicsPalette` → `main._setup_light` / `_apply_season` → Compatibility lighting |
| Terrain slot colors | sRGB albedo uniforms | `TerrainModel.palette` / `GraphicsPalette.SURFACE_COLORS` → `resort_ground.gdshader` |
| `turf_map` / `detail_map` | **Data masks** (weights) | `TerrainView._update_surface_maps` → ground/water discard & mix |
| Water tint | sRGB uniform | `TerrainModel.water_color` → `resort_water.gdshader` |
| Foliage vertex COLOR | sRGB + alpha stipple weight | `AssetFactory._canopy` → `resort_foliage.gdshader` |
| Prop materials | sRGB `StandardMaterial3D` | `AssetFactory._material` (+ optional noise **data** texture) |
| Ball / flag / overlays | Readability accents | `GraphicsPalette.READABILITY` (not environment-graded) |
| UI theme | CanvasItem colors | `resort_ui.gd` (unchanged grading) |

**Duplicated conversions:** Per-shader `pow(gamma)` art curves remain shader-local by design; environment no longer duplicates seasonal ambient tables in `main.gd`.

## Legacy comparison fixture

Pre-package values live in `GraphicsPalette.LEGACY` (sun `fff0d3` / 1.12, ambient `c6d8cf` / 0.48, sky colors, linear tonemap, per-season `bg`/`amb` rows). Summer environment after package 03 uses the same numbers via `environment_for_season(1)`.

## Retained shader curves

| Shader | Expression | Purpose |
|---|---|---|
| `resort_ground` | `pow(col, 1.65) * 0.9` | Turf contrast under linear tonemap |
| `resort_foliage` | `pow(col, 1.35)` + stipple | Canopy depth; `EMISSION` 0.055 fill |
| `resort_water` | `pow(col, 1.5)`; glint `pow(,16)` | Cool lake vs warm shore |
| `resort_path` | `pow(path, 1.65)` | Path warmth vs fairway |
| `resort_horizon` | `pow(rgb*tint, 1.65)*0.9` | Distant hills cooler than architecture |

## Palette contract (packages 04–16)

See `docs/graphics/color-space-contract.md`. Key entry points:

- `GraphicsPalette.environment_for_season(i)` — sun, sky, ambient, exposure, tonemap
- `GraphicsPalette.surface_colors_for_terrain(model)` — ground shader uniforms
- `GraphicsPalette.terrain_season_tint(i)` / `foliage_season_*` — seasonal surface shifts
- `GraphicsPalette.READABILITY` — ball, flag, analytics gradients
- `GraphicsPalette.ART_CURVES` — do not duplicate gamma in new shaders without capture review
- `GraphicsPalette.LEGACY` — A/B baseline

## Captures

### Regenerate (windowed — required for pixels)

```bash
cd /path/to/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Calibration swatches (4 seasons × 2 views → builds/color_calibration/)
"$GODOT_BIN" --path . --script tests/capture_color_calibration.gd

# Full resort (existing harness)
"$GODOT_BIN" --path . --script tests/capture_lush.gd
```

### This pass

| Artifact | Headless | Windowed |
|---|---|---|
| `builds/color_calibration/*.png` | Pipeline OK; **skipped** (dummy texture storage) | **Not run** (AFK) |
| `builds/lush-*.png` | Hung on `frame_post_draw` in headless trial | **Not run** |

Headless calibration run: draw calls 0, primitives 0 (expected dummy renderer).

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** (palette, season roughness, readability, calibration build, renderer contract) |
| `tests/test_assets.gd` | **60 passed** |
| `tests/capture_color_calibration.gd` | Completes headless; PNGs need windowed run |
| `tests/capture_lush.gd` | Not completed headless (framebuffer wait); defer to windowed |
| Simulation / shots | Not re-run (unchanged code paths) |

**Pre-existing:** `resort_ui.gd` references missing `_system_*_section()` helpers when `main.tscn` loads in tests — unrelated to package 03; causes script errors during game instantiation in headless tests but checks still pass.

## Quality-tier behavior

Lighting/palette is **independent** of Low/Standard/High graphics presets. Quality toggles still adjust shadows, MSAA, foliage only (package 01).

## Known limitations / follow-up

1. **Windowed before/after PNGs** — Run both capture scripts on macOS display for regression baselines.
2. **Package 04** — Bitmap materials should consume `GraphicsPalette` surface families, not duplicate sRGB constants.
3. **Winter snow on buildings** — Foliage/ground tint only; architecture snow is package 09/14 scope.
4. **Cross-renderer color** — Calibrate on Compatibility only (package 02 decision).
5. **Exposure tuning** — Fixed at 1.0 linear; HDR grading deferred unless captures show clipping.

## Next step

Package 04: add procedural material families keyed off `GraphicsPalette` surface slots; run windowed calibration + lush captures after first material family lands.
