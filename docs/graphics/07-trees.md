# 07 — Second-generation trees

**Difficulty:** 4/5. **Dependencies:** 04; coordinate with 10. **Outcome:** convincing asymmetrical tree silhouettes without losing dense-resort performance.

## Baseline and entry points

`AssetFactory::_canopy`, `_build_oak_tree`, `_build_pine_tree` and palm construction use procedural forms. `_bake_static` generates foliage LODs. `TerrainView::_rebuild_scenery_instances` groups meshes/materials spatially; `_tree_shadow_instances` uses simplified shadow-only volumes. `resort_foliage.gdshader` supplies wind and seasonal response. Existing trees are simulation objects, not merely decorative scatter.

## Implementation sequence

1. Create turntable fixtures at close, hole and overview distances under the calibrated lighting. Measure current bounds, materials, triangles, draw calls and shadow costs for each species.
2. Implement deterministic offline branching: tapered trunk segments, branch hierarchy, irregular lean and bounded crown envelopes. Generate several species/age variants from fixed seeds. Preserve catalogue footprint and scale conventions unless a separate gameplay change is explicitly required.
3. Compare two crown prototypes: smaller opaque leaf clusters and alpha-cutout leaf cards. Inspect silhouette, backlighting, normal response, aliasing and overdraw. Choose by actual target-camera quality and measured cost, not triangle count alone.
4. Create shared bark/leaf materials from 04. For cards, pad atlas edges, test mipmaps and cutout thresholds, and avoid unnecessary alpha blending. Vary leaf orientation/color through stable instance data without creating a material per tree.
5. Generate near/mid/far LODs and appropriate shadow meshes. Preserve crown mass and color across transitions. Use screen-size thresholds or a verified equivalent supported by the current batching path. Check that generated LOD data survives import and MultiMesh use.
6. Refine wind with branch/leaf weighting and per-instance phase. Bound displacement, account for culling bounds and ensure the normal/shadow response remains plausible. Do not animate trunks as uniformly bending grass.
7. Integrate through stable asset IDs and cached shared resources. Keep spatial batches; a single course-wide MultiMesh would undermine culling. Coordinate proxy replacement with 10 and avoid drawing both proxy and full foliage shadows.
8. Replace a small woodland first, compare motion and full-course timings, then update species variants. Retain old meshes as a temporary fallback until the new low tier passes.

## Acceptance and tests

No conspicuous repeated lobe pattern, leaf-card rectangles, LOD mass collapse or wind synchronization. Verify seasons, rotated/scaled instances, far silhouettes, asset bounds and tree placement/save restore. Confirm gameplay collision/obstacle behavior and upkeep are unchanged. Measure forest-heavy views, shadow passes, memory and camera movement—not only isolated turntables.

Follow [shared validation](VALIDATION.md). Deliver generator commands, variant seeds, LOD thresholds, material contracts and comparative captures. Runtime must use shipped assets without generating a forest of meshes at startup.
