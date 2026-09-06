# Green shapes and hazards

## Goal

Move beyond circular greens and implicit hazards: painted or polygon green boundaries, tiered greens, shaped bunkers, out-of-bounds stakes, penalty areas with drop rules, and rotating pin positions. Design expression improves and the shot engine gets richer hazard data for the metrics plan.

## Current state

- A hole is `{tee, cup, green_radius, par, waypoints}`. `ShotEngine.shot` treats "on the green" as within `green_radius` of the cup; `resize_green` repaints a disc of surface 2.
- Sand (4) and water (5) are surface paints; water triggers `hazard` and recovery logic in the shot engine. There is no out-of-bounds.
- `hole_valid` requires green paint under the cup and tee paint under the tee.

## Design

### Painted greens as the boundary

Make the painted surface authoritative. `green_radius` stays as the initial paint disc and the fallback, but "on the green" becomes `terrain.surface_at(p) == 2 and terrain.green_owner(p) == hole.id`. Add `TerrainModel.green_cells(hole) -> PackedInt32Array` computed by flood-filling surface-2 cells from the cup (cached per `revision`), and `green_owner(p)` via a per-cell owner map built from all holes' fills. Players then shape greens with the existing paint brush; disconnected green paint is ignored by the engine and shown hatched in the Holes panel warning.

`hole_valid` adds: green area between 250 m² and 2,500 m², and the green fill must not touch another hole's cup.

### Tiers and contours

Greens already inherit the heightfield. Add a **green contour** brush (Terrain panel, unlocked by the `green_complex` node) that applies smooth raise/lower with a 6 m radius and strength ×0.25, restricted to green cells, plus a per-green **slope readout** (mean and max slope, from `slope_at`). The shot engine's putting model gains a slope term: `putt_scatter += mean_slope × 6`, and putts above 4 % slope across the line add a 12 % miss chance.

### Bunkers

Bunkers are contiguous sand fills. Add `TerrainModel.bunkers() -> Array[Dictionary]` (`{cells, centre, area, depth}` where depth = mean height below the surrounding rim) computed per revision. A **bunker shaping** brush lowers sand cells 0.3–0.8 m with lipped edges. The shot engine reads depth: deeper bunkers reduce recovery carry by up to 35 % and raise fat/thin variance. Sand condition (per-hole maintenance plan) already decays per shot.

### Out of bounds and penalty areas

Add two new object kinds placed as two-click segments like paths: `ob_stakes` (white) and `penalty_stakes` (red). Segments chain; `TerrainModel.zone_at(p) -> String` returns `"ob"` when the point lies on the far side of a chain from the hole's centreline, `"penalty"` when inside a closed red loop or within 3 m of water. The shot engine:

- OB: stroke and distance (replay from previous spot, +1 penalty).
- Penalty area: +1 penalty, drop at the nearest point on the line of entry that is playable (replaces the current water recovery which uses `nearest_safe`).
- The `reason` string names the zone so the analyzer can bucket it.

### Pin positions

Each hole gains `pins: Array[Vector3]` (up to 4) and `pin_index`. `_reset_arrivals` rotates `pin_index` daily; the effective cup is `pins[pin_index]` when present. The Holes panel lets the player add a pin by clicking inside the green fill; the flag model follows the active pin in `sync_holes`. Fresh cups from the metrics plan reward rotation (green condition around a used pin decays faster).

### Multiple tee boxes

`tees: Array[{pos, name: "forward"|"middle"|"back"}]` with `tee` remaining the default for compatibility. Guests choose by skill (beginner → forward). Par and analysis run per tee. Unlocked by `championship_tees`.

### UI

- Holes panel: green area and slope readout, pin list with add/remove, tee list, zone warnings.
- Terrain panel: green contour and bunker shaping brushes, stake tools in Build.
- Selection outline (`_draw_selection` in `main.gd`) draws the green fill outline instead of a ring when a fill exists.

## Files

- `scripts/terrain_model.gd`: `green_cells`, `green_owner`, `bunkers`, `zone_at`, stake objects in navigation (walkable), validity rules, snapshot fields `pins`, `pin_index`, `tees` inside hole dictionaries (already saved as part of `holes`).
- `scripts/shot_engine.gd`: green test, slope putting, bunker depth, OB and penalty rules, `reason` codes.
- `scripts/resort_simulation.gd`: pin rotation, tee choice, `start_position(hole)` per tee.
- `scripts/main.gd`: brushes, stake placement, pin and tee editing via `_commit` batches, selection outline.
- `scripts/terrain_view.gd`: stake visuals, flag at active pin.
- `scripts/asset_factory.gd`: stake models.
- `docs/INTERFACES.md`: hole dictionary additions.

## Tests

- `tests/test_terrain.gd`: flood fill returns only connected cells; two greens touching are rejected; `zone_at` classifies OB and penalty correctly on a synthetic layout; bunker depth computed from a lowered disc.
- `tests/test_shots.gd`: an OB drive replays from the tee with a penalty; a deep bunker lowers average recovery carry versus a flat bunker; a sloped green raises average putts; a shaped (non-circular) green is honoured, i.e. a ball on a painted lobe outside `green_radius` reads as on the green.
- `tests/test_simulation.gd`: pin rotates daily; beginners start from the forward tee.
- `tests/test_game.gd`: adding a pin and a stake segment commits and undoes.

## Phases

1. Painted green as boundary, validity, selection outline. Engine change is small.
2. Pins and tee boxes.
3. Bunker depth and shaping brush.
4. Stakes, OB, penalty drops.
5. Green contours and slope putting.

## Risks

- Flood fill on 65k cells per revision is fine, but cache and only recompute for holes whose green chunk changed (`changed_chunks`).
- Existing tests in `test_shots.gd` assume circular greens; update fixtures to paint discs so behaviour is unchanged at phase 1.
