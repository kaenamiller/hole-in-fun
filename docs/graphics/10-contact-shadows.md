# 10 — Contact shading and better shadows

**Difficulty:** 3/5. **Dependencies:** 03; revalidate after 07/09. **Outcome:** trees, buildings and props feel grounded across camera distances.

## Baseline and entry points

`main.gd::_setup_light` configures directional shadows. Terrain receives shadows but `TerrainView::rebuild_chunk` disables terrain shadow casting. `_tree_shadow_instances` uses simplified canopy proxies while foliage batches avoid full shadow casting. This reduces cost but can produce disconnected or oversimplified silhouettes.

## Implementation sequence

1. Capture a shadow diagnostic scene: tree near a building, bridge over water, sloped terrain, small cart and contact at a foundation. Use close and overview cameras and inspect current bias artifacts separately from absent contact shading.
2. Tune shadow distance, splits, resolution, bias and normal bias as a coherent preset. Check near contact, far stability and slope acne. Do not reduce bias until acne appears or increase resolution without measuring the shadow pass.
3. Replace canopy proxies with species/LOD-appropriate shadow meshes from 07 when available. Use full near shadows only where they add value; use simplified distant silhouettes. Avoid duplicate proxy/full casting and align wind displacement or accept only a visually small difference.
4. Bake asset self-occlusion into a dedicated material channel or controlled shading factor for static crevices. It must remain valid when buildings move or rotate. Do not bake fixed world contact shadows into an editable course.
5. Trial supported SSAO on the selected backend, verifying installed-version support. Tune radius/intensity using actual scene scale, inspect halos around flags/foliage and measure cost. Compare against a no-SSAO baseline and provide an off option.
6. Evaluate terrain casting on a bounded representative area for banks/hills. If enabled globally, measure full-course cost. Do not leave visual ridges without expected shadows merely because a local fixture looked acceptable; document any low-tier simplification.
7. Attach settings to package 01 presets and recheck seasonal lighting. Preserve readable overlays and avoid darkening lake/grass twice through baked AO plus screen-space AO.

## Acceptance and tests

Objects meet the ground without obvious floating, acne, detached shadows or transition jumps. Inspect panning and zooming, moving carts and foliage, steep slopes and shadow-map limits. Benchmark forest and building fixtures with each technique isolated before combining them.

Follow [shared validation](VALIDATION.md). Deliver configuration tables, before/after views and shadow-pass evidence. If SSAO is noisy or too costly, keep improved bias/proxies and asset self-occlusion; it is not an all-or-nothing dependency. Avoid introducing a baked whole-resort lighting workflow that breaks terrain editing.
