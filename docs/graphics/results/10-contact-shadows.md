# Package 10 — Contact shading and better shadows

**Status:** implemented  
**Date:** 2026-09-06  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 10 centralizes directional shadow tuning and SSAO in `GraphicsShadow`, improves tree canopy shadow proxies (pending package 07 revalidation), bakes rotation-safe self-occlusion into static props, and adds a deterministic shadow diagnostic fixture. Terrain heightfields still **receive** shadows but do **not** cast them globally; bounded casting was evaluated and left off for cost.

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_shadow.gd` | Preset tables, directional shadow apply, SSAO capability gate |
| `scripts/graphics_settings.gd` | Shadow split/bias/blur, SSAO knobs, terrain_cast_shadows schema |
| `scripts/main.gd` | Applies shadow + SSAO via `GraphicsShadow` on lighting/environment |
| `scripts/terrain_view.gd` | Improved canopy proxies, terrain cast toggle (default off) |
| `scripts/asset_factory.gd` | `tree_shadow_mesh`, vertex AO bake, triplanar material AO |
| `scripts/shadow_diagnostics.gd` | Diagnostic fixture (tree/building/bridge/slope/cart/foundation) |
| `tests/capture_shadow_diagnostics.gd` | Windowed capture entry (3 presets × 2 views) |
| `tests/test_graphics.gd` | Shadow contract, SSAO gate, diagnostics build, occlusion bake |
| `scripts/color_calibration.gd` | Uses shared shadow preset for calibration lighting |

### Deviations from plan

- **Canopy proxies only:** Package 07 species/LOD shadow meshes not landed; multi-blob proxies replace single cone/sphere. Revalidate after 07.
- **Terrain casting:** `terrain_cast_shadows` exists but defaults **false** on all tiers; full-course cast not enabled after cost review.
- **Windowed captures:** Diagnostic PNGs require a windowed Godot launch (headless dummy framebuffer).

## Shadow configuration tables

### Directional shadow presets

| Field | Low | Standard | High |
|---|---:|---:|---:|
| shadow_distance | 600 | 1100 | 1400 |
| shadow_resolution | 2048 | 4096 | 4096 |
| shadow_splits | 2 | 2 | 4 |
| shadow_split_1 | 0.18 | 0.14 | 0.10 |
| shadow_split_2 | 0.42 | 0.38 | 0.24 |
| shadow_split_3 | 0.70 | 0.62 | 0.48 |
| shadow_bias | 0.18 | 0.12 | 0.10 |
| shadow_normal_bias | 1.85 | 1.25 | 1.05 |
| shadow_blur | 1.25 | 1.6 | 1.85 |
| tree_shadow_volumes | false | true | true |
| terrain_cast_shadows | false | false | false |

Bias/normal bias were reduced on Standard/High versus the pre-package `0.15 / 1.5` fixture to improve ground contact while Low keeps slightly higher bias to limit acne at 2048.

### SSAO behavior

| Tier | ssao_enabled | radius | intensity | power | light_affect | ao_channel_affect |
|---|---:|---:|---:|---:|---:|---:|
| Low | **off** | — | — | — | — | — |
| Standard | **on** (if supported) | 1.35 | 0.55 | 1.45 | 0.35 | 0.65 |
| High | **on** (if supported) | 1.55 | 0.62 | 1.55 | 0.38 | 0.70 |

**Runtime gate:** `GraphicsShadow.ssao_supported()` reads the package 02 feature matrix (`gl_compatibility.ssao = true`). Verified on Godot 4.7.2 headless probe (`Environment.ssao_enabled` sets cleanly). When unsupported or `ssao_enabled=false`, `apply_environment_ssao` forces `environment.ssao_enabled = false`.

SSAO is tuned conservatively to avoid double-darkening turf/water (no terrain AO texture) and to limit halos on thin flag/foliage geometry. Overlays remain unshaded UI layers.

### Asset self-occlusion

| Technique | Scope | Rotation |
|---|---|---|
| Vertex color bake in `_bake_static` | Static architectural meshes | Object-local normals/positions |
| Triplanar `ao_texture` on wood/plaster/roof materials | Shared `StandardMaterial3D` families | Triplanar object UV |

No world-position baked contact shadows on editable terrain.

## Canopy shadow proxies

- Foliage `MultiMesh` batches: `cast_shadow = OFF` (unchanged).
- `_tree_shadow_instances`: `SHADOWS_ONLY` multi-meshes using `AssetFactory.tree_shadow_mesh(pine)`.
- Oak: trunk cylinder + three offset canopy spheres. Pine: trunk + three stacked cones.
- Source tree nodes hidden when batched (`visible=false`) — no duplicate full+proxy casting.

## Terrain casting evaluation

Editable 16×16 chunk heightfields (~256 chunks) would add a large shadow-pass surface area with grazing-angle acne risk. Diagnostic steep bank uses the same **off** default. Enable only via `terrain_cast_shadows=true` for experiments; not exposed in the gear UI.

## Captures

```bash
cd /path/to/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Shadow diagnostic fixture (windowed for PNGs)
"$GODOT_BIN" --path . --script tests/capture_shadow_diagnostics.gd
# → builds/shadow_diagnostics/{low,standard,high}-{overview,contact}.png
```

| Artifact | Headless | Windowed |
|---|---|---|
| `builds/shadow_diagnostics/*.png` | Pipeline OK; skipped (dummy texture) | **Not run** (AFK) |

## Benchmarks (not re-run this pass)

Re-run isolated scenarios before combining regressions:

```bash
for s in dense_forest starter_lake; do
  for p in low standard high; do
    "$GODOT_BIN" --headless --path . --script tests/benchmark_lush.gd -- \
      --benchmark-scenario=$s --benchmark-duration=25 --benchmark-warmup=5 \
      --benchmark-samples=3 --benchmark-preset=$p \
      --benchmark-output=builds/benchmarks/${s}_${p}_pkg10
  done
done
```

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **1 failure** (pre-existing: `fairway receives seasonal albedo tint` from package 04 material library) |
| `tests/test_assets.gd` | **60 passed** |
| SSAO Compatibility probe | `ssao_enabled=true`, `renderer=gl_compatibility` |
| Windowed shadow captures | deferred |

## Known limitations / follow-up

1. **Package 07** — Replace `tree_shadow_mesh` with species/LOD shadow meshes; re-run diagnostics + dense_forest benchmark.
2. **Windowed before/after PNGs** — Run `capture_shadow_diagnostics.gd` on macOS display.
3. **Terrain cast** — Chunked/bounded caster for banks if art direction requires ridge shadows without full-course cost.
4. **SSAO cost** — Measure p95 with SSAO on/off at Standard; disable on Low only today.

## Handoff path

- Settings API: `GraphicsSettings` shadow/SSAO fields + `GraphicsShadow.apply_*`
- Diagnostic entry: `ShadowDiagnostics.build_root(settings)`, `tests/capture_shadow_diagnostics.gd`
- Next package touching shadows: **07 trees** (proxy replacement), **09** winter (seasonal bias check)
