# Package 05 — Hole-aware mowing patterns

**Status:** implemented (straight patterns only; curved mode deferred)  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 05 adds cosmetic per-hole mowing stripes with autonomous defaults from tee-to-cup routing, fairway ownership (authored cells or nearest-corridor fallback), a 256×256 `pattern_map` texture for shader lookup, world-space stripe phase for chunk continuity, and distance-based contrast fade at overview zoom. No shot, RNG, routing, or surface-classification changes.

## Source changes

| File | Role |
|---|---|
| `scripts/hole_mowing.gd` | Pattern schema, defaults, pattern-map encoding, overview fade, stripe test helpers |
| `scripts/terrain_model.gd` | `fairway_owner`, `rebuild_mowing_maps`, `hole_by_id`; optional `mowing_version` in snapshot |
| `scripts/terrain_view.gd` | `pattern_map` texture build/update (full + chunk partial), `set_stripe_overview_fade` |
| `shaders/resort_ground.gdshader` | Samples `pattern_map`; `fwidth` anti-alias; overview fade uniform |
| `scripts/main.gd` | Refreshes mowing on construction commits; passes camera size for overview fade |
| `tests/test_terrain.gd` | Ownership fallback, seam stability, save round-trip |
| `tests/test_graphics.gd` | Cosmetic contract (shots unchanged, autonomous defaults) |

### Deviations from plan

- **Curved patterns:** Not implemented. Metadata contract includes `pattern_type: "straight"` only; package 06 should not assume curved fields exist.
- **Editor control:** No new UI — autonomous defaults cover starter and generated courses. Optional `hole.mowing` overrides are save-compatible for future editor work.
- **Windowed captures:** Not run this pass (same headless limitation as packages 01–03).

## Ownership fallback rules

1. **Authored:** `hole.mowing.fairway_cells` (cell indices) assigns fairway/tee paint to that hole. Overlap resolves to the **lowest hole id**.
2. **Fallback:** Unassigned fairway/tee cells use **nearest tee→cup corridor** distance (`_distance_to_corridor`). Ties break on **lowest hole id**.
3. **Greens:** Use existing `green_owner` flood-fill; stripe direction is fairway orientation + **12°** offset.
4. **Neutral:** Rough, sand, water, garden, and unowned maintained turf use legacy global direction `(0.78, 0.63)` at **35%** contrast.
5. **Playable semantics unchanged:** `surface_at`, `green_owner`, shots, and routing do not read fairway ownership.

## Schema contract (package 06)

### Per-hole optional field: `hole.mowing`

```gdscript
{
  "orientation": float,        # radians, stripe direction; default ⊥ tee→cup
  "width": float,              # stripe frequency scale (default 0.56)
  "phase": float,              # world-space phase offset (reserved; shader phase is world-dot for now)
  "contrast": float,           # 0..1 stripe strength
  "pattern_type": "straight",  # only supported mode
  "fairway_cells": Array[int], # optional authored fairway/tee cell indices
}
```

### Terrain snapshot

- `mowing_version: 1` (optional; missing on legacy saves)
- Pattern overrides live inside each `holes[]` entry; no separate top-level mowing blob.

### Runtime queries (cosmetic)

| API | Returns |
|---|---|
| `TerrainModel.fairway_owner(Vector3) -> int` | Hole id owning fairway/tee stripe, or `-1` |
| `TerrainModel.hole_by_id(int) -> Dictionary` | Hole record |
| `HoleMowing.effective_pattern(hole) -> Dictionary` | Merged defaults + overrides |
| `HoleMowing.build_pattern_image(terrain) -> Image` | 256×256 RGBA pattern map |

### `pattern_map` encoding (per cell)

| Channel | Meaning |
|---|---|
| R | Stripe direction X, encoded `dir.x * 0.5 + 0.5` |
| G | Stripe direction Z, encoded `dir.z * 0.5 + 0.5` |
| B | Frequency scale / 1.5 |
| A | Contrast multiplier (surface-weighted in shader) |

Package 06 (continuous contours) should **consume** `fairway_owner` / `pattern_map` for visual continuity at boundaries — not introduce a second ownership map.

### Shader uniforms

- `pattern_map` — filtered like turf/detail maps
- `default_stripe_dir` — neutral fallback `vec2(0.78, 0.63)`
- `stripe_overview_fade` — `0.12..1.0` from `HoleMowing.overview_fade(camera.size)`

## Checks run

| Check | Result |
|---|---|
| `tests/test_terrain.gd` | **0 failures** (includes mowing ownership, seam, save round-trip) |
| `tests/test_graphics.gd` | **0 failures** (includes mowing cosmetic contract) |

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_terrain.gd
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd
```

## Known limitations / follow-up

1. **Windowed before/after captures** — Neighboring holes, chunk boundaries, overview motion (run `tests/capture_lush.gd` on macOS display).
2. **Curved patterns** — Deferred; same metadata can gain `pattern_type: "curved"` later with phase-continuous fields.
3. **`phase` uniform** — Stored in save schema; world-space dot provides seam stability today. Wire explicit phase offset in shader when curved fields land.
4. **18-hole mask-update benchmark** — Not measured this pass; full rebuild is O(65k) cells and runs on hole edits only.

## Next step

Package 06: sample `fairway_owner` and `pattern_map` at contour boundaries; keep one authoritative ownership source documented above.
