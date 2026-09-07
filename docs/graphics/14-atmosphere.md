# 14 — Atmospheric depth and distant landscape

**Difficulty:** 2/5. **Dependencies:** 03; coordinate reflection refresh with 12/13. **Outcome:** layered resort vistas with readable foreground play.

## Baseline and entry points

`TerrainView::_build_horizon` and `_horizon_height` generate peripheral hills; `resort_horizon.gdshader` supplies their palette. `main.gd::_setup_light` builds a procedural sky, and `_apply_season` changes colors. The camera is orthographic with a wide zoom/elevation range.

## Implementation sequence

1. Capture the full camera range to identify where horizon layers disappear, expose the property edge or compete with the playing surface. Record sky/hill/forest value separation under the calibrated lighting.
2. Add subtle distance/height haze using the selected backend's verified basic fog capabilities or a controlled shader equivalent. Test the actual orthographic depth behavior; do not assume perspective-style distance parameters produce the intended view.
3. Grade distant hills cooler/lighter and reduce fine contrast with distance. Add a small number of layered distant vegetation silhouettes outside playable bounds. Use shared low-detail meshes/materials and deterministic placement; do not create simulation trees beyond the property just to fill the horizon.
4. Blend horizon and sky colors without making the near course gray. Check all seasons and camera elevations. Preserve the visual distinction between water, sand, green and rough.
5. Trial slow, low-contrast cloud shading as a cosmetic world effect. Keep it coherent over terrain and major props if used; avoid a moving dark texture applied only to turf. Measure the implementation and disable it if the result looks inconsistent or distracts from play.
6. Make haze/cloud strength quality-aware only where cost differs materially. Coordinate sky/lighting changes with probe invalidation so reflections do not preserve a different atmosphere. Keep sky movement cosmetic and independent of simulation RNG.
7. Leave volumetric fog as a separate renderer-dependent experiment. It is unnecessary for completion of gentle atmospheric depth and should not force a renderer migration.

## Acceptance and tests

Overview has clear foreground/midground/background separation without a washed-out course. No exposed horizon gaps or obvious cardboard layers across zoom, rotation and tilt. Ball, flag, selection and overlays stay readable. Inspect a motion clip for cloud distraction and horizon parallax artifacts.

Follow [shared validation](VALIDATION.md), including full-resort rendering costs. Deliver palette/fog parameters and camera coverage captures. Retain simple sky/horizon fallback if an effect is unsupported; do not hide camera-boundary defects with excessively dense fog.
