# Multiple maps

## Goal

Offer more than one flat 1,024 m starting property: seeded procedural terrain presets (coastal, rolling hills, desert, woodland valley, links) with distinct surface palettes, water bodies, existing vegetation, and an entrance location, plus a map preview at new-game time. Later scenarios and blueprints build on this.

## Current state

- `TerrainModel._init` creates a flat heightfield; `starter_resort(full)` places the Cedar House layout at fixed coordinates.
- `ENTRANCE` is a constant `Vector3(64, 0, 64)` in `ResortSimulation`; `hole_valid` and `admit_group` reference it.
- `SURFACE_COLORS` is a constant palette in `TerrainModel`. `main.gd::_create_resort(sandbox, starter, full)` wires everything.
- Save files store the full heightfield, so any generated map is already persistable.

## Design

### Map definition

New `scripts/map_generator.gd` (`class_name MapGenerator extends RefCounted`) and `Catalog.maps()`:

```gdscript
{"id": "cedar_house", "name": "Cedar House", "description": "Gentle meadow with an established three-hole club.",
 "seed": 730241, "biome": "meadow", "entrance": Vector3(64, 0, 64), "starter": true,
 "starting_cash": 180000.0, "difficulty": "easy", "features": ["stream"]}
```

Maps: `cedar_house` (current, unchanged), `blank_meadow` (current blank), `harbour_links` (coastal, dunes, prevailing wind flag for future weather, large sea body along one edge, sand-heavy palette), `stonebrook_hills` (rolling 25 m relief, a river with two natural crossings, more expensive earthworks), `red_mesa` (desert: rough is `scrub` colour, water scarce, higher upkeep for fairway, decorative palette shift), `pinewood_valley` (dense existing pines that must be cleared at a cost, a lake in the centre, high starting beauty).

### Generation

`MapGenerator.generate(definition) -> TerrainModel`:

1. Height: layered `FastNoiseLite` (Godot built-in) with per-biome amplitude, ridge and valley masks, and an edge falloff so the boundary is playable. Entrance area (120 m radius) is flattened and cleared.
2. Water: fill cells below a biome sea level to surface 5 with `water_levels`; carve rivers by tracing a noise-perturbed polyline and lowering cells, then flooding. Ensure at least two crossing points where banks are within 12 m (so `path_valid` bridge placement works).
3. Vegetation: Poisson-disc scatter of `oak_tree`, `pine_tree`, or a new `desert_shrub` and `dune_grass` scenery, density per biome, avoiding the entrance and a reserved corridor.
4. Palette: `TerrainModel.palette: PackedColorArray` replaces the `SURFACE_COLORS` constant; `TerrainView.rebuild_chunk` reads `model.palette`. Biomes set palette and a `rough_name` used by the UI.
5. Costs: `TerrainModel.cost_multipliers: Dictionary` (`{"raise": 1.0, "fairway": 1.0, "water": 1.0, "clear_tree": 1.0}`) read in `plan_brush` and `main.gd::_placement_reason` so desert fairway is pricier and valley trees cost to clear.
6. Validation: `route(entrance, random playable points)` must reach ≥ 70 % of the map; otherwise re-roll with `seed + 1` (bounded to 8 tries) so no map ships unplayable.

Generation for 257² nodes with 3 noise layers runs well under a second on the M2; run it synchronously on new game.

### Entrance and simulation

`ENTRANCE` becomes `terrain.entrance` with the constant as fallback. Replace all uses in `ResortSimulation`, `TerrainModel.hole_valid`, and `main.gd` camera defaults. Snapshot includes `entrance`, `palette`, `cost_multipliers`, and `map_id`; old saves default to the Cedar House values.

### New-game flow

The main menu (`ResortUI.show_menu`) gains a map picker: card per map with a 128 × 128 preview `TextureRect` rendered from a quick low-resolution generation (heights to shaded colours, water in blue), description, difficulty chip, and a seed field with a "Random" button. Mode (management / sandbox) and starter toggle remain. `main.gd::new_game(sandbox, starter)` becomes `new_game(sandbox, map_id, seed, starter)`.

### Existing trees as obstacles

Pre-placed vegetation participates in `segment_blocked`, beauty, and upkeep exactly as player-placed scenery, since it is the same object kinds. Clearing uses the existing demolish path with a `clear_tree` cost multiplier instead of salvage credit.

## Files

- New: `scripts/map_generator.gd`.
- `scripts/catalog.gd`: `maps()`, `desert_shrub`, `dune_grass` scenery.
- `scripts/terrain_model.gd`: `entrance`, `palette`, `cost_multipliers`, `map_id`, cost hooks in `plan_brush`, snapshot/restore defaults.
- `scripts/terrain_view.gd`: palette from model; water colour per biome.
- `scripts/resort_simulation.gd`: `terrain.entrance` everywhere `ENTRANCE` is used; `starting_cash` from the map.
- `scripts/main.gd`: `new_game` signature, camera defaults from entrance, preview generation.
- `scripts/resort_ui.gd`: map picker.
- `scripts/asset_factory.gd`: shrub and dune grass.
- `docs/INTERFACES.md`: `entrance`, palette, multipliers.

## Tests

- `tests/test_terrain.gd`: each map generates deterministically for its seed (hash of heights equal across two runs); ≥ 70 % reachability from the entrance; every river has ≥ 2 bridgeable crossings; palette has 7 entries; snapshot/restore round-trips the new fields; an old snapshot without them restores Cedar House defaults.
- `tests/test_simulation.gd`: a starter day on `stonebrook_hills` with the Cedar House layout translated to its entrance runs without stranded guests (guards `ENTRANCE` migration).
- `tests/test_assets.gd`: new scenery kinds build.
- `tests/test_game.gd`: `new_game` for every map id reaches `MAIN_SMOKE_OK`; the menu renders previews.
- Performance: the benchmark still meets 30 FPS on `pinewood_valley` (highest scenery count).

## Phases

1. `entrance`, `palette`, `cost_multipliers` fields with Cedar House defaults; migrate constants. No visible change.
2. `MapGenerator` with `blank_meadow` and `stonebrook_hills`; menu picker; tests.
3. Coastal, desert, and valley biomes, new scenery, cost multipliers.
4. Random seed and preview polish.

## Risks

- `starter_resort()` hard-codes coordinates; for non-Cedar maps the starter toggle should be disabled in phase 2 and revisited with the blueprints feature.
- Water bodies near the edge interact with `edge falloff`; validate `playable` at the entrance after generation.
