# Package 06 — Continuous course contours, collars and shaped banks

**Status:** partial (bounded vertical slice: one green + one bunker per save, programmatic/API authoring; no in-game contour editor UI yet)  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 06 adds versioned optional vector course features (`green`, `bunker`) that rasterize into the existing 256×256 gameplay grid on commit. A 512×512 `contour_map` softens rendered boundaries; collar/lip ribbons and height profiles share `height_at` data. Legacy saves without `course_features` load unchanged via the raster compatibility path. Gameplay queries (`surface_at`, `green_owner`, shots, routing) remain raster-authoritative; render weights agree within **2 m** (`CourseContours.SAMPLE_TOLERANCE_M`).

## Surface / height consumer inventory

| Consumer | Uses | Semantics (unchanged) |
|---|---|---|
| `TerrainModel.surface_at` | `surfaces[]` cell index | Authoritative lie classification |
| `TerrainModel.height_at` | `heights[]` bilinear | Ball ground, mesh, objects |
| `TerrainModel.slope_at` / `playable` | height + surface | Steep/water blocking |
| `TerrainModel.green_owner` / `on_green` | surface flood-fill from cup | Cup ownership; ignores cosmetic-only masks |
| `TerrainModel.fairway_owner` | mowing maps (pkg 05) | Cosmetic stripes only |
| `TerrainModel.bunkers` / `bunker_at` | sand flood-fill | Hazard depth metrics |
| `TerrainModel.zone_at` / `penalty_drop` | surface + stakes + water distance | Penalties/OB |
| `TerrainModel.route` / `path_valid` | `playable`, `height_at`, `surface_at` | Walking/cart paths |
| `TerrainModel.hole_valid` / `green_area` | raster green cells | Validation metrics |
| `ShotEngine` | `surface_at`, `height_at`, `on_green`, `green_owner` | Shots and putting |
| `ResortSimulation` | `surface_at`, `condition_at`, wear | Traffic/wear |
| `TerrainView::_update_surface_maps` | `surfaces[]` → 256 masks | Base turf/detail textures |
| `TerrainView::_update_contour_maps` | vector features → 512 mask | Cosmetic boundary softening |
| `TerrainView::rebuild_chunk` | heights + surfaces + contour ribbons | Chunk meshes |
| `resort_ground.gdshader` | turf/detail/pattern/contour maps | Visual only when `use_contour_map` |
| `SaveStore` | `terrain.snapshot()` | No VERSION bump (array layout unchanged) |

**Boundary fixtures added:** ellipse green/bunker in `tests/test_terrain.gd` (`_test_contour_*`).

## Source changes

| File | Role |
|---|---|
| `scripts/course_contours.gd` | Schema, validation, rasterize, render mask, collar/lip ribbons, water query helper |
| `scripts/terrain_model.gd` | `course_features`, `plan_feature_contour`, `apply_contour_command`, boundary/water queries, snapshot |
| `scripts/terrain_view.gd` | `contour_map` texture, `refresh_contour_maps`, per-chunk collar/lip meshes |
| `shaders/resort_ground.gdshader` | `contour_map`, `use_contour_map`; collar/lip/sand blending |
| `scripts/main.gd` | `contour` undo/redo via `_apply`; refresh contour maps on commit |
| `tests/test_terrain.gd` | Legacy save, round-trip, gameplay agreement, undo, cup ownership, chunk bounds |

### Deviations from plan

- **In-game contour editor:** Not implemented. Features are committed through `TerrainModel.plan_feature_contour` / `apply_contour_command` (tests and future editor). Existing paint/green-contour/bunker-shape brushes unchanged.
- **Starter auto-migration:** No automatic vector extraction on load. `CourseContours.approximate_outline_from_cells` is a documented approximation helper only.
- **Water shoreline vectors:** Water remains raster-authored; `water_body_at` publishes depth contract from existing cells.
- **Windowed captures:** Not run (headless pass).

## Representation decision

| Layer | Resolution | Authority |
|---|---|---|
| Gameplay raster | 256×256 @ 4 m | `surface_at`, ownership, shots, routing |
| Vector feature | Closed polygon + optional islands | Stored in save; rasterized on contour commit |
| Render mask | 512×512 | Cosmetic edge softening; falls back to raster when no features |

Overlap priority on raster commit: later contour command wins per cell (same as paint). Self-intersecting outlines are **rejected** (`CourseContours.validate_feature`).

## Schema contract

### Terrain snapshot (optional)

- `contours_version: 1` (optional; missing on legacy saves)
- `course_features: Array[Dictionary]` (optional; missing → `[]`)

### Per-feature record

```gdscript
{
  "id": int,              # stable uid (TerrainModel.uid())
  "kind": "green" | "bunker",
  "hole_id": int,         # green ownership reference; -1 for unassigned bunker
  "points": PackedVector2Array,  # closed outline in world xz
  "islands": Array[PackedVector2Array],  # optional holes
  "collar_width": float,  # default 1.6 m (green)
  "lip_width": float,     # default 1.4 m (bunker)
  "lip_depth": float,     # default 0.55 m (bunker profile)
}
```

`SaveStore.VERSION` unchanged (still 2).

### `contour_map` encoding (512×512 RGBA)

| Channel | Meaning |
|---|---|
| R | Authored green render weight |
| G | Authored bunker render weight |
| B | Green collar band weight |
| A | Bunker lip band weight |

When `course_features` is empty, `use_contour_map = false` and rendering uses legacy turf/detail masks only.

## Query contracts for packages 08 / 11

### Package 08 — ground cover

| API | Returns |
|---|---|
| `TerrainModel.boundary_distance_at(p, kind="") -> float` | Metres to nearest authored feature boundary (empty kind = any) |
| `TerrainModel.signed_boundary_distance_at(p, feature_id) -> float` | Negative inside feature, positive outside |
| `CourseContours.contains_point(feature, xz) -> bool` | Point-in-polygon (gameplay uses raster; compare for scatter exclusion) |
| `TerrainModel.contour_features_for_chunk(chunk) -> Array` | Features intersecting a 64 m chunk |

Use `fairway_owner` / `pattern_map` (package 05) for stripe continuity at fairway edges — do not add a second ownership map.

### Package 11 — water / shorelines

| API | Returns |
|---|---|
| `TerrainModel.water_body_at(p) -> Dictionary` | `{body_id, depth, shore_distance, surface_y, basin_y}` |
| `CourseContours.water_body_query(terrain, p)` | Low-level helper (same fields) |

`body_id` is currently the water cell index (conservative; no merged basin IDs yet). `depth = max(0, water_level - basin_height)`.

### Transactional editor command

```gdscript
{
  "kind": "contour",
  "before_features": Array[Dictionary],
  "after_features": Array[Dictionary],
  "nodes": Array,   # height deltas (collar/lip profile)
  "cells": Array,   # surface paint records (same format as plan_brush)
  "cost": float,    # paint + height costs (same rules as previews)
  "bounds": Rect2,
  "center": Vector3,
  "radius": float,
}
```

Undo/redo via `main.gd` `_apply` restores features, raster, and heights together.

## Checks run

| Check | Result |
|---|---|
| `tests/test_terrain.gd` | **0 failures** (includes 6 new contour tests) |
| `tests/test_shots.gd` | **0 failures** |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_terrain.gd
"$GODOT_BIN" --headless --path . --script tests/test_shots.gd
```

## Known limitations / follow-up

1. **Contour editor UI** — Wire `plan_feature_contour` to a polygon tool; previews must call the same planner for costs.
2. **Starter content** — Optionally attach one demo green + bunker feature to lakeside hole 1 after validating chunk seams in-window.
3. **Water body IDs** — Merge connected water cells into stable basin IDs for package 11 depth fields.
4. **Island / overlapping greens** — Schema supports islands; gameplay overlap rules need fixtures beyond the single-feature slice.
5. **Windowed validation** — Run `tests/capture_lush.gd` for collar/lip silhouettes and chunk crossings.
6. **18-hole edit benchmark** — Full `contour_map` rebuild is O(512²) per contour commit; partial chunk updates already scoped.

## Next step

Package 08: consume `boundary_distance_at` and `contour_features_for_chunk` for scatter exclusion; package 11: replace per-cell `body_id` with merged basin IDs using the same boundary data.
