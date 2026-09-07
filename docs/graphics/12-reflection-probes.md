# 12 — Managed reflection probes

**Difficulty:** 2/5. **Dependencies:** 11, with backend decided in 02. **Outcome:** water and polished materials respond to nearby resort structures and vegetation.

## Baseline and entry points

Current water receives sky response without scene reflections. Environment setup is in `main.gd`; water material and world objects are managed by `TerrainView`. Verify the installed engine against the [probe documentation](https://docs.godotengine.org/en/4.7/tutorials/3d/global_illumination/reflection_probes.html). The assessment's 4.7 matrix supports probes on Compatibility, with limited overlap per mesh.

## Implementation sequence

1. Add a deterministic probe manager with a small explicit budget. Start with one lakeside probe near the clubhouse and a material test object. Establish whether built-in probe influence reaches the custom water shader as intended before building placement automation.
2. Choose capture extents/origin from the relevant water body and nearby structures. Test box projection and transition behavior where supported. Avoid course-wide overlapping probes and account for the backend's overlap limit and large water meshes spanning multiple regions.
3. Set capture layers to omit UI, selection/analysis helpers, water self-capture and insignificant animated actors. Include the buildings, terrain, sky and vegetation that materially affect appearance. Use reduced-detail capture settings where supported.
4. Refresh on initial load and relevant construction, vegetation, terrain or lighting/season changes. Coalesce edit bursts, schedule at most a bounded number of updates and avoid recapturing every frame. Record pending/stale state during rapid edits.
5. Connect resolution, count and enablement to quality presets. Use the sky/environment fallback when disabled or before a capture completes. Verify that deleting a water body/building releases unused probes.
6. Compare reflected color and roughness on water, cart and windows. Probes approximate broad flat lakes; do not compensate for positional inaccuracy by making the whole lake mirror-like. Document remaining errors for the optional planar trial.

## Acceptance and tests

New buildings appear in reflections after the documented update delay; removed objects do not persist indefinitely. Rapid construction does not generate repeated long stalls. Seasons update captures coherently. Verify load/recreate cleanup, probe boundaries and several water bodies.

Follow [shared validation](VALIDATION.md). Benchmark capture spikes separately from steady-state cost. Deliver placement/invalidation rules, layer assignments and supported-backend evidence. If probes add little value to the broad lake, retain them only for suitable materials/areas and record that outcome rather than increasing their count without evidence.
