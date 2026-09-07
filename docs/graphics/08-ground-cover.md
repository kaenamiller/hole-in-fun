# 08 — Ground cover and planting composition

**Difficulty:** 3/5. **Dependencies:** 04 and 06. **Outcome:** layered edges and purposeful planting without obscuring the course.

## Baseline and entry points

`TerrainView::_shore_details` already adds bounded cosmetic rocks/reeds near wet rough. Scenery batching is spatial. `TerrainModel::_plant_starter_woodland` creates actual simulation trees; do not replace those with untracked cosmetic obstacles. Consume the shared boundary/ownership data produced by 06.

## Implementation sequence

1. Define cover families: short rough tufts, bank reeds, low shrubs, flower clusters, leaf litter and small stones. Set exclusion rules for greens, tees, paths, cup/ball visibility, building entrances and navigation corridors. Substantial obstacles remain ordinary simulation objects.
2. Implement deterministic scatter keyed by world seed, chunk, family and stable candidate index. Use boundary distance, slope, moisture/water level and surface type as inputs. Regenerating one chunk must not reshuffle the whole resort or consume simulation RNG.
3. Use clustered distributions with deliberate gaps and species mixtures. Concentrate detail at woodland margins, shorelines and buildings. Avoid uniformly covering every square meter or creating a continuous wall of shrubs around the green.
4. Generate shared small meshes/material atlases offline. Conform roots to terrain height and align within bounded slope limits. Use cutout foliage cautiously and measure overdraw.
5. Build region-sized MultiMeshes per family/material/LOD. Add quality-dependent candidate subsets using stable hashes so density reduction removes instances without relocating survivors. Set view-distance fades or transitions and conservative animated bounds.
6. Invalidate affected scatter on painting, sculpting, object placement and water edits. Queue/coalesce rebuilds to protect drag responsiveness. Keep cosmetic cover derived rather than bloating saves; persist only authored planting overrides if explicitly introduced.
7. Integrate with seasons and wind using shared conventions from 07. Ensure faded cover does not leave full-strength shadow blobs. Add budgets per region and globally, with deterministic truncation.

## Acceptance and tests

Capture shore, woodland, building and fairway transitions at multiple distances. Repeated load and local edits reproduce stable placement. Cover never blocks the ball/flag or becomes an invisible physical obstacle. Test chunk seams, flooding/draining, steep banks and construction clearing. Compare dense-view frame tails, instance count and rebuild latency across quality tiers.

Follow [shared validation](VALIDATION.md). Deliver family rules, budgets and regeneration contracts. If the budget is exceeded, reduce distant density and family complexity before reducing gameplay readability or introducing stochastic frame-by-frame popping.
