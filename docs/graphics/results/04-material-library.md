# Package 04 — Distinct procedural material library

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 04 adds nine deterministic material families (fairway, rough, sand, gravel, stone, plaster, bark, timber, roof) with offline-generated PBR maps, a shared `MaterialLibrary` lookup, terrain detail blending in `resort_ground.gdshader`, and representative asset conversions (clubhouse architecture, trees, boulder, putting green, cart paths). Seasonal tint applies only to course turf families; architecture and stone skip tint. Generated runtime assets are committed under `assets/materials/`; launch requires no Blender, network, or generator.

## Material ID contract

Stable IDs use `{category}.{family}`:

| ID | Folder | Palette source | m/repeat | Roughness | Season tint | Triplanar |
|---|---|---|---:|---:|---|---|
| `course.fairway` | `fairway/` | `SURFACE_COLORS[1]` | 2.0 | 0.88 | yes | no |
| `course.rough` | `rough/` | `SURFACE_COLORS[0]` | 1.5 | 0.92 | yes | no |
| `course.sand` | `sand/` | `SURFACE_COLORS[4]` | 0.8 | 0.94 | yes | no |
| `course.gravel` | `gravel/` | `SURFACE_COLORS[6]` | 0.5 | 0.90 | no | yes |
| `prop.stone` | `stone/` | `ARCH_COLORS.stone` | 1.2 | 0.85 | no | yes |
| `arch.plaster` | `plaster/` | `ARCH_COLORS.plaster` | 1.8 | 0.86 | no | yes |
| `prop.bark` | `bark/` | `ARCH_COLORS.bark` | 0.6 | 0.91 | no | yes |
| `arch.timber` | `timber/` | `ARCH_COLORS.timber` | 1.4 | 0.84 | no | yes |
| `arch.roof` | `roof/` | `ARCH_COLORS.roof` | 0.9 | 0.89 | no | yes |

### Runtime API

```gdscript
MaterialLibrary.material(family_id)           # shared StandardMaterial3D instance
MaterialLibrary.detail_textures(family_id)    # albedo/roughness/normal + repeat
MaterialLibrary.apply_season(season_index)      # course families only; preserves roughness
MaterialLibrary.manifest()                    # committed JSON manifest
GraphicsPalette.material_family(id)           # family metadata
GraphicsPalette.material_tint_color(id)       # sRGB tint from palette (no duplicated constants)
GraphicsPalette.season_tinted_material_ids()
```

### Map channels

| File | Import role | Notes |
|---|---|---|
| `albedo.png` | sRGB color (`process/hdr_as_srgb=true`) | Macro + fine variation; no baked lighting |
| `roughness.png` | linear data | Mipmapped grayscale |
| `normal.png` | linear tangent-space (`compress/normal_map=1`) | Derived from authored height; +Y up |
| `height.png` | linear data | Generator source; not bound at runtime |
| `architecture_trim/*` | trim sheet atlas | Plaster/timber/roof rows; individual folders also committed |

## Source changes

| File | Role |
|---|---|
| `tools/assets/generate_materials.py` | Deterministic spectral tileable generator + seam/gradient gates |
| `tools/assets/configure_imports.py` | sRGB albedo vs linear data/normal import sidecars |
| `tools/assets/generate.sh` | Regenerate maps, configure imports, Godot reimport |
| `assets/materials/**` | Committed PNG maps + `manifest.json` |
| `scripts/material_library.gd` | Shared instance cache keyed by family ID |
| `scripts/graphics_palette.gd` | `MATERIAL_FAMILIES`, `ARCH_COLORS`, tint helpers |
| `scripts/asset_factory.gd` | `_family()` wrapper; clubhouse/trees/boulder/bench/greens converted |
| `scripts/terrain_view.gd` | Ground detail bind; gravel on cart/walking paths |
| `shaders/resort_ground.gdshader` | Fairway/rough/sand detail blend with overview fade |
| `scripts/color_calibration.gd` | Swatches use MaterialLibrary |
| `tests/test_graphics.gd` | Manifest, sharing, season tint, roughness preservation |

### Representative conversions (bulk deferred)

| Family | Converted asset / surface |
|---|---|
| fairway | `putting_green`, `driving_range` turf |
| rough/sand | terrain ground shader detail (all holes) |
| gravel | cart/walking path ribbons |
| stone | `woodland_boulder` |
| plaster/timber/roof | `clubhouse` walls, trim, roof |
| bark/timber | `oak_tree` / `pine_tree` trunks and branches |
| timber | `bench` slats |

## Generator commands

```bash
cd /Users/kaenamiller/Documents/ChatGPT/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Full regenerate (maps + import sidecars + Godot reimport)
bash tools/assets/generate.sh

# Maps only
python3 tools/assets/generate_materials.py

# Import sidecars only (after hand-editing PNGs)
python3 tools/assets/configure_imports.py
"$GODOT_BIN" --headless --editor --path . --quit
```

**Tool versions:** Python 3.9+, numpy; generator version `1.0.0`; global seed `0x042026` (270374 decimal).

**Manifest (this pass):** `assets/materials/manifest.json` sha256 `e9ff706d31f749e95f6ba3fdbadfe84d5fd300b450dcdb4f20cf9d334ae7d204`.

Determinism: re-run `generate_materials.py` twice; manifest hash and PNG bytes match when inputs unchanged.

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** (includes material library contract) |
| `tests/test_assets.gd` | **60 passed** |
| `tests/test_terrain.gd` | **passed** |
| `tests/test_shots.gd` | **passed** |
| `tests/test_simulation.gd` | **Not completed** (headless run hung >7 min; unchanged sim code paths) |
| Windowed calibration/lush captures | **Not run** (headless dummy renderer) |

**Pre-existing:** `shadow_diagnostics.gd` assigns `receive_shadows` on `MeshInstance3D` (invalid property) during shadow contract test; unrelated to package 04.

## Quality-tier behavior

Material maps load at all graphics presets. Detail fade in the ground shader reduces close-up grain when zoomed out (management overview). Low tier still shares material instances (batching preserved).

## Known limitations / follow-up

1. **Bulk architecture conversion** — Only clubhouse + bench among buildings; remaining facilities keep legacy `_material()` flat colors + noise.
2. **Trim sheet UVs** — Atlas committed; runtime uses per-family folders with triplanar (trim reserved for future UV-authored meshes).
3. **Windowed captures** — Run `tests/capture_color_calibration.gd` after material landing for visual regression.
4. **Roughness texture channel** — StandardMaterial3D roughness texture modulates base roughness; values tuned per family.

## Next step

Package 05+: extend `_family()` across remaining facility catalogue; windowed before/after captures at overview + single-hole zoom.
