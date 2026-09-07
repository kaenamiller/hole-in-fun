# Package 08 — Ground cover and planting composition

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 08 replaces ad-hoc `_shore_details` rock/reed MultiMeshes with a deterministic cosmetic scatter system keyed by `TerrainModel.generation_seed`, 128 m regions, family rules and stable candidate hashes. Six cover families (rough tufts, bank reeds, shrubs, flowers, leaf litter, small stones) respect greens, tees, paths, cup/tee visibility, building clears, entrance radius and simulation tree radii. Shipped near/far GLTF meshes live under `assets/ground_cover/`; foliage families use `resort_foliage.gdshader` and shared season tint. Simulation trees from `_plant_starter_woodland` / map scatter remain authoritative obstacles.

## Cover family rules

| Family | Surfaces | Cluster bias | Region budget | Placement bias |
|---|---|---:|---:|---|
| `rough_tuft` | rough | general rough | 52 | open rough, slope ≤ 0.85 |
| `bank_reed` | rough, garden | shore ≤ 4.5 m | 36 | wet banks, moderate slope |
| `shrub` | rough, garden | woodland/building margins | 28 | within 14 m of sim trees or 10 m of buildings |
| `flower` | rough, garden, fairway edge | building beds | 20 | within 8 m of buildings; fairway only for this family |
| `leaf_litter` | rough | under canopy | 44 | within 6 m of sim trees |
| `small_stone` | rough, garden | shore / woodland edge | 18 | shore ≤ 5 m or within 10 m of trees |

**Exclusion (all families):** water cells; green/tee/sand (except litter on sand blocked); cup radius 5.5 m; tee radius 4.5 m; authored green boundary ≤ 1.8 m (`boundary_distance_at`); paved/gravel/bridge path ribbons; building footprint + 6 m; entrance 28 m; inside simulation tree collision discs.

**Global region cap:** 190 instances before per-family budgets; overflow truncated by stable score sort (hash order, not distance sort).

## Budgets and quality tiers

| Control | Standard / High | Low |
|---|---|---|
| `GraphicsSettings.foliage_density` | 1.0 | 0.55 |
| Density thinning | `stable_id % step == 0`, step = round(1/density) | same |
| `foliage_view_distance` | 900 / 1100 | 450 |
| Far LOD end | `foliage_view_distance` | 450 |
| Region rebuild coalesce | 1 region / frame | 1 region / frame |

Low tier removes distant instances deterministically; survivors keep transforms.

## Regeneration contract

| Event | Action |
|---|---|
| Terrain setup / world recreate | `_rebuild_all_cover_regions()` |
| Chunk height/surface/water dirty | `_queue_cover_regions_for_chunks(changed_chunks)` → `_process_dirty_cover_regions` |
| Object place/move/remove | `_queue_cover_regions_for_objects(objects)` on `sync_objects` |
| Graphics preset / density change | `apply_graphics_settings` → full cover rebuild |
| Save/load | Cover derived at runtime; `generation_seed` persisted in terrain snapshot |

**Scatter seed:** `TerrainModel.generation_seed ^ GroundCover.GLOBAL_SCATTER_SEED (0x080026)` — never uses `ResortSimulation` RNG.

**Candidate hash:** `hash_u32(world_seed, region.x, region.y*997+family.hash(), index)` for cluster gates, offsets, yaw, scale and budget scores.

## Source changes

| File | Role |
|---|---|
| `tools/assets/generate_ground_cover.py` | Offline tuft/reed/shrub/flower/litter/stone GLTF + manifest |
| `assets/ground_cover/**` | Committed near/far meshes + `manifest.json` |
| `scripts/ground_cover.gd` | Family rules, exclusions, deterministic scatter + budgets |
| `scripts/ground_cover_assets.gd` | Manifest lookup, mesh cache, materials |
| `scripts/terrain_model.gd` | `generation_seed` snapshot field |
| `scripts/map_generator.gd` | Sets `generation_seed` from map definition |
| `scripts/terrain_view.gd` | `cover_root`, region MultiMeshes, invalidation; removes `_shore_details` |
| `tools/assets/generate.sh` | Runs ground-cover generator |
| `tests/test_graphics.gd` | Manifest, determinism, density, green exclusion |
| `tests/test_terrain.gd` | Cross-region stability, seed round-trip |

### Deviations from plan

- **Windowed captures:** Not run (headless dummy renderer).
- **Cutout foliage:** Rejected; opaque/cluster meshes only (same rationale as package 07).
- **Authored planting overrides:** Not persisted; all cover remains derived.

## Generator commands

```bash
cd /Users/kaenamiller/Documents/ChatGPT/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

python3 tools/assets/generate_ground_cover.py
"$GODOT_BIN" --headless --editor --path . --quit

# Full pipeline
bash tools/assets/generate.sh
```

**Tool versions:** Python 3.9+; generator `1.0.0`; global seed `0x080026` (524326 decimal).

**Manifest:** `assets/ground_cover/manifest.json` — 9 variants (6 families, near/far each).

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** (includes ground-cover contract) |
| `tests/test_terrain.gd` | **all passed** (includes ground-cover determinism + seed round-trip; ~3.5 min headless due to water-field rebuilds in package 11 tests) |
| Windowed lush captures | **Not run** |
| Benchmark dense_forest | **Not re-run** |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd
"$GODOT_BIN" --headless --path . --script tests/test_terrain.gd
```

## Known limitations / follow-up

1. **Windowed validation** — Run `tests/capture_lush.gd` for shore/woodland/building/fairway transitions.
2. **Merged water basins (package 11)** — Bank reeds already consume `water_body_at.shore_distance`; revisit clustering when basin IDs merge.
3. **Benchmark** — Re-run starter + dense presets after visual pass; watch region rebuild latency during sculpt drag.
4. **Low-tier cover** — Could add far-only families on Low after frame-tail review.

## Handoff path

- **Runtime API:** `GroundCover.build_region_batches`, `GroundCover.scatter_seed_for`, `GroundCoverAssets.manifest()`, `GroundCoverAssets.lod_thresholds()`, `TerrainView.cover_root`.
- **Regenerate assets:** `python3 tools/assets/generate_ground_cover.py` then Godot headless editor import.
- **Next packages:** **11** water/shorelines (ripple + depth field integration), **14** atmosphere (season/wind already shared via `AssetFactory.apply_season` + foliage shader).
