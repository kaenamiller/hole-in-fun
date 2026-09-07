# Package 07 — Second-generation trees

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 07 replaces procedural first-generation oak/pine canopies with deterministic offline meshes: tapered trunks, branch hierarchy, irregular lean, species/age variants (four each), near/mid/far LODs, species shadow proxies, and branch-weighted wind in `resort_foliage.gdshader`. **Opaque leaf clusters** were chosen over alpha-cutout cards after measured silhouette/cost review. Shipped GLTF assets live under `assets/trees/`; runtime loads them via `TreeAssets` with no startup mesh generation. **Low** graphics preset keeps legacy procedural trees until the far LOD tier is validated on that tier.

## Crown prototype decision

| Prototype | Oak v0 near tris | Est. dense-woodland fill | Verdict |
|---|---:|---|---|
| **Opaque clusters** (selected) | 960 foliage / 1172 total | Baseline | Stable silhouettes, shared foliage shader batching, no alpha overdraw |
| Alpha cutout cards (rejected) | 28 cards / 1172 total mesh context | ~3.2× fill vs clusters in 40-tree fixture | Rectangle shimmer at hole distance; worse Compatibility overdraw |

Cards remain in the generator for regression comparison only; shipped assets use clusters.

## Variant seeds

Global seed: `0x070026` (458790). Per-variant:

| Species | v0 | v1 | v2 | v3 |
|---|---:|---:|---:|---:|
| oak | 463511 | 463612 | 463713 | 463814 |
| pine | 464631 | 464732 | 464833 | 464934 |

Shadow mesh seed: variant seed + 9001.

## LOD thresholds (camera distance, world units)

| Tier | visibility_range_begin | visibility_range_end |
|---|---:|---:|
| near | 0 | 85 |
| mid | 75 | 190 |
| far | 175 | 950 |

Overlap bands (75–85, 175–190) reduce popping. `TerrainView` MultiMesh batches still use spatial 128 m regions; foliage `visibility_range_end` also respects `GraphicsSettings.foliage_view_distance`.

## Material contract

| Part | Runtime material | Instance variation |
|---|---|---|
| Bark / branches | `MaterialLibrary.material("prop.bark")` | Shared triplanar instance |
| Foliage | `AssetFactory._foliage()` → `resort_foliage.gdshader` | Vertex `COLOR` tint + alpha; `TEXCOORD_0.x` phase, `.y` wind weight |

Wind: branch-weighted displacement (not uniform trunk bend); world position still de-synchronizes instances in MultiMesh batches.

## Source changes

| File | Role |
|---|---|
| `tools/assets/generate_trees.py` | Deterministic trunk/branch/crown/shadow generator + GLTF export |
| `tools/assets/generate.sh` | Runs tree generator before Godot reimport |
| `assets/trees/**` | Committed GLTF meshes + `manifest.json` |
| `scripts/tree_assets.gd` | Manifest lookup, GLTF mesh cache, LOD thresholds |
| `scripts/asset_factory.gd` | `_build_gen2_tree`, `gen2_trees_enabled`, shipped shadow meshes, legacy fallback |
| `scripts/terrain_view.gd` | Per-variant shadow MultiMesh grouping |
| `scripts/main.gd` | Disables gen2 on Low preset; clears tree cache on toggle |
| `shaders/resort_foliage.gdshader` | Phase + branch weight from UV; bounded sway |
| `tests/test_graphics.gd` | Gen2 contract, manifest, legacy fallback |

### Deviations from plan

- **Low tier:** Legacy `_canopy` procedural meshes retained when `gen2_trees_enabled=false` (Low preset).
- **Windowed captures:** Turntable/before-after PNGs deferred (headless dummy renderer).
- **Package 10 shadow proxies:** Replaced by shipped species/variant shadow GLTF when gen2 active; legacy analytic proxies remain on Low.

## Generator commands

```bash
cd /Users/kaenamiller/Documents/ChatGPT/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Trees only
python3 tools/assets/generate_trees.py
"$GODOT_BIN" --headless --editor --path . --quit

# Full asset pipeline (materials + trees + import sidecars)
bash tools/assets/generate.sh
```

**Tool versions:** Python 3.9+; generator `1.0.0`; global seed `0x070026`.

**Manifest:** `assets/trees/manifest.json` — 8 variants (oak/pine × 4), 32 GLTF files (near/mid/far/shadow each).

Determinism: re-run `generate_trees.py` twice with unchanged inputs; manifest bytes and GLTF hashes match.

## Checks run

| Check | Result |
|---|---|
| `tests/test_assets.gd` | **64 passed** |
| `tests/test_graphics.gd` | **0 failures** (includes gen2 contract + legacy fallback) |
| Godot GLTF import | **OK** (32 scenes) |
| Windowed lush/tree captures | **Not run** |
| `dense_forest` benchmark | **Not re-run** |

**Pre-existing:** Minor ObjectDB leak warning at `test_graphics.gd` exit (main scene recreation test).

## Quality-tier behavior

| Preset | Trees | Shadow proxies |
|---|---|---|
| Low | Legacy procedural bake + runtime foliage LOD | Off (`tree_shadow_volumes=false`) |
| Standard / High | Shipped gen2 near/mid/far GLTF | Shipped species shadow GLTF |

## Known limitations / follow-up

1. **Low-tier gen2** — Enable far-only shipped LOD on Low after benchmark confirms mass/silhouette.
2. **Windowed validation** — Run `tests/capture_lush.gd` + `tests/capture_shadow_diagnostics.gd` for motion/LOD/shadow regression.
3. **Benchmark** — Re-run `dense_forest` × presets after shadow mesh swap (package 10 follow-up).
4. **Palm / shrubs** — Out of scope; still procedural.

## Handoff path

- Asset IDs unchanged: `oak_tree`, `pine_tree` (catalogue radius/cost untouched).
- Runtime API: `TreeAssets.manifest()`, `TreeAssets.lod_thresholds()`, `AssetFactory.gen2_trees_enabled`, `AssetFactory.tree_shadow_mesh(pine, variant)`.
- Regenerate: `python3 tools/assets/generate_trees.py` then Godot headless editor import.
- Next packages: **08** ground cover (coordinate foliage density), **10** revalidate shadow diagnostics with gen2 proxies.
