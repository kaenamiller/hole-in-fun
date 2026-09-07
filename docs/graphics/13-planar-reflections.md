# 13 — Optional planar lake reflections

**Difficulty:** 4/5. **Dependencies:** 12 and the benchmark/backend decisions. **Outcome:** accurately positioned reflections on a dominant lake, only where the extra render pass is affordable.

## Baseline and scope

The initial game has no planar pass; package 12 establishes the cheaper reflection baseline. `scripts/orbit_camera.gd` uses an orthographic camera. `TerrainView` owns water meshes/materials; package 11 establishes water-body elevations. This is an optional quality experiment, not a required default-renderer migration.

## Implementation sequence

1. Build an isolated fixture with one flat water plane, an asymmetric building and a camera that pans/zooms/tilts. Implement a reflected camera in a SubViewport. Match orthographic size, aspect ratio and projection; derive the mirrored transform from the actual world-space plane.
2. Solve clipping before integrating. Geometry below the reflection plane must not leak into the reflected scene. Verify supported clipping/projection mechanisms on the selected backend; if a custom projection or shader clip is required, document it and its limitations. Account for mirrored winding/culling rather than hiding artifacts through double-sided rendering everywhere.
3. Exclude water, reflection helpers, UI, overlays and selection from the capture. Prevent recursive capture and keep capture-only visibility from affecting the main view. Include sky, terrain and selected vegetation/buildings with reduced-detail settings.
4. Project the reflection texture onto water in stable world coordinates, with correct UV orientation and edge behavior. Blend with Fresnel/roughness and restrained wave distortion. Handle pixels outside the valid captured region using the probe/sky fallback.
5. Add half/quarter-resolution trials and selective refresh. Camera motion, world edits and moving important objects invalidate the capture. Test update skipping in motion for visible lag; do not freeze a reflection that visibly slides as the camera moves.
6. Select at most one dominant visible water plane initially. Other water elevations retain probe/sky shading. Use hysteresis when switching bodies to prevent rapid toggling and release unused viewport resources on world recreation.
7. Integrate as an explicitly optional High setting with capability detection. Compare against package 12 at the same camera/load and include the second scene pass in triangle/draw-call accounting.

## Acceptance, adoption gate and tests

Ship enabled only when correctness is established and the agreed high-tier budget passes. Test camera extremes, shoreline near-plane intersections, multiple elevations, islands, resize, photo mode, seasonal updates and exported builds. Inspect video for clipping leaks, wrong orientation, swimming UVs and stale motion.

Follow [shared validation](VALIDATION.md). A rejected experiment is a valid outcome: retain probe reflections, remove disabled prototype runtime overhead and document the measured reason. A static screenshot that looks attractive does not pass this package.

## Handoff

Record reflection math conventions, capture layers, clipping method, active-plane selection, update cadence and measured resolution tradeoffs. Leave a reproducible fixture so another agent can revisit the experiment without reverse-engineering the implementation.
