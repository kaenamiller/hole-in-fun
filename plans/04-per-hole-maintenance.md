# Per-hole maintenance

## Goal

Replace the single `terrain.wear` float with spatial course condition so greens, fairways, tees, and bunkers degrade individually with traffic and play, groundskeepers do visible work at specific places, and course quality becomes a design and staffing problem rather than a global counter.

## Current state

- `TerrainModel.wear` is one float. `_begin_shot` adds 0.000015 per shot; groundskeepers subtract `dt * 0.0000008 * skill` while standing at a facility.
- `demand_factors().wear` and `_update_grade` read the aggregate. The Money panel shows "Course condition" as `1 - wear`.
- Groundskeepers target facilities (`_staff_target` picks lowest condition facility), never the course.
- Surface types: 0 rough, 1 fairway, 2 green, 3 tee, 4 sand, 5 water, 6 garden.

## Design

### Storage

Add `TerrainModel.condition: PackedFloat32Array` sized 256 × 256 (one per surface cell), initialised to 1.0. Only cells whose surface is fairway, green, tee, or sand accumulate wear. Keep `wear` as a derived getter (`course_wear()` returning `1 - mean condition` over maintained cells) so `demand_factors` and grade checks continue to work.

Include `condition` in `snapshot()` / `restore()`; default to all-ones when loading an old save.

### Decay sources

| Source | Where | Effect |
|---|---|---|
| Footsteps | `_move_person` | cell under each step −0.00004 × dt on fairway/green/tee; rough and paths ignored |
| Shot landing | `_finish_shot` | landing cell −0.0025 (divot) on fairway/tee, −0.0015 on green (ball mark) |
| Bunker shot | `_finish_shot` when `landing_surface == 4` | −0.006 (unraked sand) |
| Cart traffic | `_move_cart_group` | cell −0.0001 × dt when a cart crosses fairway (off the cart network) |
| Weather-neutral baseline | `_end_day` | all maintained cells −0.01 overnight |
| Overnight recovery | `_end_day` | greens +0.03 when a `maintenance_shed` exists (mowing) |

### Effects of poor condition

- **Shot engine**: `ShotEngine.shot` already reads `surface_at`. Add `terrain.condition_at(pos)` and use it in `_surface_distance_factor` and putting dispersion: greens below 0.5 add up to +40 % putt scatter; fairway below 0.5 behaves halfway toward rough.
- **Mood**: `_feedback(guest, "poor_greens", -0.03, …)` when a putt is taken on a green cell below 0.4 (once per hole per guest).
- **Demand**: `demand_factors().wear` unchanged formula but now driven by the mean.
- **Per-hole condition**: `hole_condition(hole) -> Dictionary` with `green`, `fairway`, `tee`, `bunkers` means, computed by sampling the green disc, a 12 m corridor along tee → waypoints → cup, and painted sand cells within 60 m of the corridor. Cached per `revision` and refreshed once per simulated minute.

### Groundskeeper work

Rework `_staff_target` for `groundskeeper`:

1. If manually assigned to a hole (`assignment` becomes `{"kind": "hole"|"object", "id"}`, migrating the old int), pick the worst cell in that hole's zones.
2. Otherwise choose the hole with the lowest `hole_condition.green` (greens weigh 2×), fall back to facilities as today.
3. Walk to the target cell using `_route`; on arrival enter `maintaining`, restore the target cell and its 8 neighbours by `dt * 0.0035 * skill`, then choose the next-worst cell within 30 m before re-planning. Show a `mower` animation state via `AssetFactory.animate_golfer(node, "mowing", phase)` (new activity).
4. A `maintenance_shed` within 150 m of the hole boosts the restore rate by 1.5×; carts (if a cart barn exists) let groundskeepers travel at cart speed.

### Hole open/close for maintenance

Add a **Close for maintenance** toggle on a hole (existing `open` flag). A closed hole's condition recovers 4× faster when a groundskeeper is present. `_refresh_course` already excludes closed holes from play.

### UI

- Holes panel: per-hole condition row (green / fairway / tee / bunkers as four small bars), "Assign groundskeeper" dropdown, "Close for maintenance" toggle.
- Staff panel: groundskeeper assignment now lists holes and facilities.
- Money panel "Course condition" remains, now the mean.
- Overlay `wear` (analytics plan) reads `condition` directly.

## Files

- `scripts/terrain_model.gd`: `condition`, `condition_at`, `course_wear()`, `hole_condition`, snapshot/restore, `paint_disk` resets condition of newly painted cells to 1.0.
- `scripts/shot_engine.gd`: condition-aware distance and putting scatter (optional terrain method, guarded by `has_method`).
- `scripts/resort_simulation.gd`: decay hooks, groundskeeper targeting, assignment migration, feedback, end-of-day recovery.
- `scripts/asset_factory.gd`: `mowing` animation.
- `scripts/resort_ui.gd`, `scripts/main.gd`: UI and camera jump to assigned hole.
- `docs/INTERFACES.md`: new terrain API.

## Tests

- `tests/test_terrain.gd`: `condition` round-trips; `hole_condition` on a fresh hole is all 1.0; painting a disc resets cells.
- `tests/test_shots.gd`: a green at 0.3 condition raises average putts on a fixed seed set versus 1.0.
- `tests/test_simulation.gd`: one stress day lowers the mean green condition of every played hole; a groundskeeper assigned to a hole raises its green mean over one day while the unassigned hole falls; closing a hole speeds recovery; an old snapshot without `condition` restores to all ones.
- `tests/test_regressions.gd`: `_terrain_wear()` still in 0..1 and the grade check unchanged for the starter.

## Phases

1. `condition` array, decay hooks, derived wear, save compatibility. Aggregate behaviour equal to today within tolerance.
2. Groundskeeper targeting on holes, assignment migration, UI.
3. Shot-engine effects and guest feedback.
4. Close-for-maintenance and overnight recovery tuning.

## Risks

- Per-step cell writes in `_move_person` are cheap, but avoid calling `hole_condition` per tick; cache per minute.
- The `assignment` migration must accept both the old int form and the new dictionary in `restore`.
