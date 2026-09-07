# 01 — Reproducible benchmarks and quality settings

**Difficulty:** 2/5. **Dependencies:** none. **Outcome:** subsequent graphics decisions have comparable evidence and a safe performance fallback.

## Current implementation and entry points

`tests/benchmark_lush.gd` provides a short live benchmark; `tests/capture_lush.gd` provides fixed views. `project.godot` selects Compatibility, 4× MSAA and a 4096 directional shadow map. `scripts/main.gd` owns lighting, simulation updates and scene recreation. `scripts/terrain_view.gd` owns spatial scenery batches; `scripts/asset_factory.gd` owns meshes and foliage LOD generation. There is no established multi-scenario graphics budget in the assessment.

## Implementation sequence

1. Inspect the benchmark's timing and fixture setup. Add command-line scenario, duration, warmup, seed, preset and output-path arguments. Export machine-readable JSON/CSV plus a concise text summary. Record engine/driver/hardware and all relevant settings with each result.
2. Build immutable fixtures for the starter lake, dense forest/buildings and an 18-hole resort. Add separate fixed-state rendering, active golfers and repeated terrain-edit scenarios. Do not derive a render comparison from two independently evolving live simulations.
3. Run at least three measured 60-second samples after warmup. Capture frame-time distributions, outliers, rendering counters and memory where supported. Instrument simulation, terrain rebuilds, asset creation and scene synchronization independently. Identify unavailable GPU measurements explicitly.
4. Add a proposed `GraphicsSettings` resource/service with Low, Standard and High presets. Define fields for foliage range/density, shadow distance/resolution, reflection mode/resolution and effect caps. Unsupported or not-yet-implemented features remain disabled. Keep defaults equivalent to the measured existing configuration until there is evidence for a change.
5. Persist preferences in a user settings file separate from resort saves. Validate values, handle missing/unknown keys and apply settings after world recreation. Publish a settings-changed signal so feature systems can update without polling. Avoid a full resort rebuild when only a shader uniform changes.
6. Add a small settings UI using the existing UI architecture. Explain visible tradeoffs plainly. Changes requiring renderer restart belong to package 02; do not change rendering backend mid-session through an ordinary quality toggle.
7. Establish initial per-scenario budgets and save baseline result tables. Track total costs first; do not assign fictional GPU millisecond budgets to individual effects without isolated measurement.

## Acceptance and tests

The same fixture and preset produce comparable results across repeated runs; output identifies every configuration difference. Low quality survives world recreation and application restart without changing simulation state. Invalid settings fall back safely. Changing quality does not alter shot results, RNG state, placement costs or routes. Verify at two resolutions and during edits, not only a static overview.

Target stable 30-fps low-tier play on the reference M2; treat 60 fps as an optimization goal. Follow the [shared validation](VALIDATION.md) and investigate frame-time tails before recommending a renderer migration.

## Delivery and fallback

Commit fixture-generation code, settings schema and benchmark instructions; store a compact baseline report under `results/`. Keep the old visual preset available for A/B comparisons. If a counter is unsupported, omit it with an explicit capability flag rather than substituting a misleading measurement. This package is complete when a future agent can reproduce the comparison without manually arranging a scene.
