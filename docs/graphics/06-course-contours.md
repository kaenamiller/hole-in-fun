# 06 — Continuous course contours, collars and shaped banks

**Difficulty:** 4/5. **Dependencies:** 01; preserve 05. **Outcome:** smooth authored boundaries and integrated terrain profiles with consistent gameplay semantics.

## Baseline and risk

`TerrainModel` uses 256×256 surface cells at 4 m spacing and a height grid. `TerrainView::_update_surface_maps` produces 256×256 masks; filtering softens their edges without adding authoring precision. `rebuild_chunk` generates ground/water geometry. Model entry points include `plan_brush`, `apply_brush`, `surface_at`, `height_at`, green caches, `plan_green_contour`, `plan_bunker_shape`, `snapshot`, `restore` and navigation rebuilding. `SaveStore` serializes model state.

This package changes a shared representation. A visually smooth bunker that the ball classifies differently is a regression. Do not simply upscale the mask and call it continuous authoring.

## Implementation sequence

1. Inventory every surface/height consumer: rendering, shots, lies, ownership, costs, green validation, hazards, walking/cart routes and editing previews. Document the current semantics and add boundary fixtures before changing them.
2. Write a short representation decision. Prefer persistent editable outlines for bounded features, retaining raster paint for legacy/general land; consider a higher-resolution authored field if it better matches the editor. Define overlap priority, holes/islands, ownership and invalid-shape handling. Keep one authoritative definition per feature.
3. Add versioned optional feature data with stable IDs, geometry, surface type and ownership. Old saves must retain their appearance and queries through an explicit raster compatibility path. Do not invent precise original curves from coarse data. Offer deterministic conversion only as a documented approximation.
4. Implement shared sampling/rasterization from the authoritative data. Rendering masks can have higher resolution than navigation, but ball lies, feature ownership and displayed boundaries must agree to a documented tolerance. Resolve green flood-fill/area metrics explicitly; a new visual mask alone cannot update those semantics.
5. Add transactional editor operations. The command stores before/after feature data, affected bounds and terrain changes; calculate costs from the same area rule used by previews. Undo/redo restores geometry, costs and caches together. Reject self-intersections or repair them deterministically with a clear rule.
6. Triangulate/render a single green and bunker first. Generate collars and bunker lips from sampled boundary normals with bounded widths, slopes and miter behavior. Handle concave corners, narrow features and adjacent surfaces without overlapping ribbons or z-fighting.
7. Shape shore/bunker height profiles only through data that `height_at` and collision/shot consumers share. If visual-only microrelief is retained, keep it below an explicit tolerance and exclude meaningful cliffs/lips. Support separate water elevations and islands.
8. Rebuild only intersecting chunks and necessary neighbors. Publish boundary distance, ownership and water-body/depth inputs for packages 08/11. Use conservative navigation rasterization around hazards; test routes near curves rather than assuming a finer render mask fixes navigation.
9. Expand to starter content after one-feature correctness. Preserve the legacy resort and existing paint workflow; avoid a mandatory mass migration on first load.

## Acceptance and tests

Use fixtures for convex/concave shapes, narrow necks, islands, overlapping greens, different water levels and chunk crossings. Sample lies just inside/outside boundaries and compare to rendering. Test cup ownership, bunker escape, water penalties, green metrics and a complete round. Save/load and repeated undo/redo must preserve geometry and costs exactly within the chosen representation's tolerance.

Measure edit latency and mask/mesh memory on the full property. Follow [shared validation](VALIDATION.md). Deliver schema/migration notes and query contracts. If integrated contour authoring cannot yet meet these checks, retain the legacy representation and label the prototype partial; do not ship cosmetic/gameplay disagreement.
