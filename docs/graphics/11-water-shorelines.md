# 11 — Depth-aware water and shoreline materials

**Difficulty:** 3/5. **Dependencies:** 03 and 06. **Outcome:** water has plausible shallow/deep variation and banks integrate with surrounding land.

## Baseline and entry points

`resort_water.gdshader` uses animated sine patterns and a filtered water mask; edge fraction is not actual depth. `TerrainView::rebuild_chunk` generates water near wet cells from local water levels. `_update_surface_maps` shares ground/water masks. `TerrainModel` owns water levels and terrain heights. Existing editing can create water at different elevations.

## Implementation sequence

1. Document authoritative basin height, water surface elevation and water-body membership after 06. Define behavior for connected cells with inconsistent levels and disconnected bodies. Do not assume the starter lake is the only possible water plane.
2. Produce a maintained depth field from water elevation minus basin height, clamped at zero, plus shore distance and body ID as needed. Share boundary definitions with visible geometry. Update dirty regions after sculpting, water painting and undo; avoid rebuilding a full depth texture every frame.
3. Shade shallow water with restrained bank/bottom influence and transition to deeper lake color over physical depth. Keep artistic tint parameters independent of raw depth units. Compare top-down and oblique views; avoid using screen-space depth as the sole source when offscreen terrain or transparency makes it unreliable.
4. Improve wave normals with multiple non-aligned scales, modest amplitude and distance filtering. Break obvious sine repetition while retaining calm water. Keep shoreline geometry and gameplay water heights stable unless a separately tested displacement model is introduced.
5. Blend damp soil/stone and irregular vegetation at banks using shore distance, slope and elevation. Use generated shoreline geometry from 06 for actual profiles. Prevent wet coloration from climbing arbitrary heights or leaking across nearby dry islands.
6. Define a cosmetic ripple input contract: body ID, world position, start time, radius and strength. Implement the shader/pool receiving side; package 16 supplies event dispatch. Reject ripples for removed bodies and cap active inputs.
7. Publish reflection integration points for 12/13 and quality controls for wave detail/ripple count. Keep a no-reflection baseline that still has credible depth coloration.

## Acceptance and tests

Test shallow/deep basins, islands, steep banks, separate elevations and edits that join/split/drain bodies. Shader appearance and water penalties agree at the boundary. Undo and load restore depth without stale patches. Inspect mask/chunk seams, reflections-disabled views and motion for shimmering.

Follow [shared validation](VALIDATION.md), including terrain/shot regression checks and edit latency. Deliver field/channel definitions and invalidation rules. If a depth texture exceeds memory/update budgets, use bounded regional fields; do not silently revert to edge fraction while labeling it physical depth.
