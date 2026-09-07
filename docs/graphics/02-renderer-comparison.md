# 02 — Renderer comparison and conditional migration

**Difficulty:** 2/5 for the trial; 4/5 if migration is justified. **Dependencies:** 01. **Outcome:** choose the renderer from measured compatibility, image quality and frame-time evidence.

## Current implementation and entry points

`project.godot` uses `gl_compatibility`. Custom shaders live in `shaders/`; environment setup is in `scripts/main.gd`. Export settings and scripts are `export_presets.cfg` and `tools/export.sh`. Changing the renderer can change lighting and shader behavior even when the scenes load.

## Implementation sequence

1. Pin the installed Godot version and verify its [renderer feature matrix](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html). Treat the linked 4.7 documentation as the assessment reference, not a guarantee for another version. Audit every custom shader and proposed feature against actual supported APIs.
2. Create isolated test configurations for Compatibility, Mobile and Forward+. Use supported platform drivers and record the actual backend chosen. Keep the production default unchanged during the trial. Avoid editing shared settings between concurrent benchmark runs.
3. Run package 01 fixtures at identical resolution, camera and comparable antialiasing/shadow settings. Separate a feature-matched comparison from a second comparison with renderer-specific improvements enabled. This prevents attributing a prettier, more expensive setting to the backend alone.
4. Capture materials, foliage wind, water, overlays, paths, horizons, photo mode and UI. Check shader compilation, color-space differences, depth sampling and transparent ordering. Run exported cold starts and window resize/minimize/restore cases.
5. Produce a decision table covering p95/p99, memory, startup, visual defects and platform coverage. Keep Compatibility when alternatives offer no compelling measured benefit. Lack of a Windows runner must remain a documented evidence gap.
6. If migrating, implement backend capability detection and explicit feature fallbacks. Recalibrate lighting through package 03, replace incompatible shader paths, and retest saves/gameplay. Keep a documented known-good launch configuration and avoid automatic restart loops on startup failure.
7. Make any renderer preference restart-aware and independent of gameplay saves. Do not expose an option whose configuration cannot be validated. Refresh export instructions and record why the chosen default is appropriate.

## Acceptance and adoption gate

The trial is complete with reproducible results and a recorded keep/migrate decision; migration is not required for completion of the trial. Adopt a new default only if the tested hardware meets the agreed budgets, exported startup works and material/overlay regressions are resolved. A performance gain in an empty scene is insufficient.

The 4.7 assessment lists probes, SSAO and basic fog for Compatibility; do not assume all advanced-looking effects require Forward+. SSR and volumetric fog are separate renderer-dependent features. Verify feature support in the installed build before implementation.

## Delivery and fallback

Follow [shared validation](VALIDATION.md). Commit comparison configurations/scripts and `results/02-renderer-comparison.md`; distinguish trial status from migration status. Keep a supported baseline tier without optional effects. If a platform/backend is unavailable, mark it untested instead of extrapolating another platform's results.
