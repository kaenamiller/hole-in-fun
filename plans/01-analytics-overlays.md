# Analytics overlays

## Goal

Extend the two existing terrain overlays (`beauty`, `access` in `TerrainView.rebuild_chunk`) into a family of data layers that let the player see where guests walk, wait, land balls, and wear the course, and which land each facility serves. All layers are derived from simulation state that already exists or is added by the statistics plan.

## Current state

- `TerrainView.overlay` is a string; `rebuild_chunk` recolors every cell when it is `beauty` or `access`. `set_overlay` rebuilds all 256 chunks synchronously.
- `main.gd::toggle_overlay` flips between one overlay and `none`. The Terrain panel exposes the two buttons.
- The simulation has per-guest `pos`, `route`, `ball_pos`, `last_shot.landing`, group `wait_seconds`, per-facility queues, and `terrain.wear` as a single float. Nothing is accumulated over space.

## Design

### Overlay layers

| ID | Source | Colour ramp | Notes |
|---|---|---|---|
| `beauty` | existing `beauty_at` | brown to green | unchanged |
| `access` | existing `playable` | unchanged | unchanged |
| `traffic` | walking heat grid | transparent to warm orange | decays daily |
| `cart_traffic` | cart heat grid | transparent to blue | separate grid |
| `waiting` | wait-time heat grid | yellow to red | logs where groups stand in `tee_queue`, `checkin_queue`, `facility_queue` |
| `landings` | shot landing grid, split by `hazard` flag | green dots for fair, red for hazard | reads `last_shot.landing`, `end` |
| `wear` | per-cell wear array | green to bare brown | requires the per-hole maintenance plan; before that, colour by aggregate `terrain.wear` times traffic |
| `coverage` | facility service radii | tinted discs per facility kind | purely geometric, no sampling |
| `elevation` | height contour bands | stepped greys | cheap and useful for design |

### Heat grid storage

Add `AnalyticsGrid` (new `scripts/analytics_grid.gd`, `RefCounted`) holding named `PackedFloat32Array`s of 64 × 64 cells (16 m per cell, 1,024 m / 64). Methods:

- `add(layer: String, pos: Vector3, amount: float)`
- `decay(layer: String, factor: float)` called from `_end_day`
- `value(layer, pos) -> float` and `max_value(layer)` for normalisation
- `snapshot() / restore()` returning dictionaries keyed by layer

The simulation owns one instance as `sim.analytics`. Sampling calls:

- `_move_person`: `analytics.add("traffic", pos, dt)` for guests, `"cart_traffic"` in `_move_cart_group`.
- `_apply_wait_mood`: `analytics.add("waiting", leader_pos, dt)`.
- `_finish_shot`: `analytics.add("landings", landing, 1.0)` and `"hazard_landings"` when `shot.hazard`.

Sampling cost: one array index per moving person per one-second step. With 100 guests that is trivially cheap.

### Rendering

`TerrainView.rebuild_chunk` keeps the per-cell colour path for `beauty`, `access`, `elevation`, and `wear` because these vary at 4 m resolution. For the heat layers, do not rebuild chunk meshes. Instead add an `overlay_mesh: MeshInstance3D` that is a single 64 × 64 quad grid draped slightly above the terrain (`height_at + 0.15`), vertex-coloured from the grid, using an unshaded, alpha-blended material. Regenerating one 4,096-quad mesh each refresh is far cheaper than rebuilding 256 chunks.

`coverage` draws translucent discs using `main.gd::_ring` style meshes per facility, radius from `Catalog.find(kind).radius` scaled by a new `service_range` field (default 90 m) so players can see gaps.

`landings` renders as instanced small spheres using a `MultiMesh`, reusing the pattern in `_rebuild_scenery_instances`.

Refresh cadence: heat overlays refresh every 2 s while active (a timer in `main.gd::_process`), never when `overlay == "none"`.

### UI

Replace the two overlay buttons in `_terrain_panel` with an `OptionButton` listing all layers plus a legend row (min/max labels and a gradient `TextureRect` generated from the ramp). Add an "Overlays" hotkey `O` that cycles the last two used layers. When `landings` is selected, show a small caption with counts of fair vs hazard landings for the visible day.

## Files

- New: `scripts/analytics_grid.gd`
- `scripts/resort_simulation.gd`: `analytics` field, sampling calls, snapshot/restore, daily decay (traffic × 0.6, waiting × 0.5, landings × 0.7).
- `scripts/terrain_view.gd`: `overlay_mesh`, `set_overlay` for new IDs, `refresh_overlay(sim)`.
- `scripts/main.gd`: refresh timer, hotkey, coverage discs, landing instances.
- `scripts/resort_ui.gd`: option button, legend.
- `docs/INTERFACES.md`: document `AnalyticsGrid`.

## Tests

- `tests/test_simulation.gd`: after a simulated day on the starter resort, `analytics.max_value("traffic") > 0`, the entrance cell has the highest traffic, and `landings` is non-zero near every hole's green. Snapshot/restore round-trips all layers.
- `tests/test_terrain.gd`: `set_overlay("traffic")` on a view with a populated grid produces one overlay mesh with 4,096 × 6 vertices and no chunk rebuild (chunk node instance IDs unchanged).
- `tests/test_game.gd`: cycle all overlay IDs through `toggle_overlay` without errors; the render QA capture includes one traffic overlay frame.

## Phases

1. `AnalyticsGrid` plus traffic and waiting sampling, snapshot/restore, tests. No rendering.
2. Draped overlay mesh, option button, legend, `traffic`, `cart_traffic`, `waiting`.
3. `landings`, `coverage`, `elevation`.
4. `wear` once per-hole maintenance lands.

## Risks

- Godot `Dictionary` snapshots of `PackedFloat32Array` serialise fine via `store_var`, but keep layer arrays fixed-length and validate on `restore` to avoid corrupt saves.
- The overlay mesh must be excluded from click picking in `_world_click` (use a separate collision-free node, and skip it in `_inspect_at`).
