# Shared graphics validation and agent handoff

These requirements apply to every [graphics package](README.md). Scale testing to the change: an isolated material update needs visual/import checks, while changes to terrain semantics need gameplay regression coverage. These are implementation instructions; creating the plans does not require running the game suite.

## Baseline and controlled comparisons

The prior assessment recorded Apple M2, Compatibility/OpenGL, 1440×900, 4× MSAA, 35.9 average fps, 20 ms p95, 20 golfers and 719 sampled frames. It used a short 5-second warmup/25-second run. It is historical evidence, not a current baseline or bottleneck diagnosis. The differing average and p95 warrant investigation of long frames.

Before implementation, record commit/worktree identity, Godot version, OS/hardware, renderer/driver, resolution, quality, scenario seed, season, camera and simulation speed. Preserve a reproducible save or fixture and baseline screenshots. Separate render-only fixed state from deterministic simulation workloads; live arrivals and variable frame timing can invalidate comparisons.

Capture at least the established overview, single hole, clubhouse and vegetation views using `tests/capture_lush.gd` as an entry point. Include a short motion clip for wind, water, reflections, LOD or animation. Add the specific edge cases listed in the package. Use actual rendering: headless dummy-renderer results do not establish shader appearance or GPU readback behavior.

## Performance and quality gates

Use the harness from package 01 once available. Compare p50/p95/p99 frame time, worst frames, draw calls, primitives, memory, startup and edit latency across at least three warm runs. State CPU/GPU timing availability rather than presenting CPU frame time as GPU time. Report compilation/loading stalls separately from steady state, but retain cold-start results.

As an initial review trigger, investigate a >10% p95 or p99 regression at an unchanged preset and workload. This is a proposed threshold, not measured headroom. Expensive features may justify a separate higher tier, but must preserve a working baseline tier. Averages alone cannot pass the gate. Measure a starter resort, dense vegetation/buildings, active simulation and a representative 18-hole fixture.

Screenshots must show coherent color, stable silhouettes, no obvious seams or z-fighting, readable ball/flag and readable overlays. Inspect motion for shimmer, popping, reflection lag and repeated patterns. An agent should compare captures and iterate; successful import alone is insufficient aesthetic validation.

## Correctness and delivery

- Inspect `tools/test.sh` and run checks relevant to modified code. Existing coverage includes assets, terrain, shots, simulation, regressions, game, lush layout and a completed lush round. Establish failures before editing and distinguish pre-existing failures from new regressions.
- For terrain/saves: exercise old-save restore, new-save round trip, paint, undo/redo, object placement, water elevations, surface ownership and walking/cart routes. Run a full golf round after semantic changes.
- For assets: verify bounds, transforms, materials, LODs, dynamic node names, catalogue variants and seasons. `tests/test_assets.gd` is the starting point.
- For rendering: launch a real-rendered development build and exported macOS app. Use `tools/export.sh` after inspecting it. Record a Windows export separately; actual Windows rendering needs an available runner. If unavailable, explicitly leave runtime verification outstanding.
- Preserve user save data. Use disposable fixture saves and separate capture output. Avoid storing large temporary videos, exports or benchmark dumps in source control without an existing convention.
- Inspect `git diff --check` and ensure generated runtime dependencies are included. A normal player launch must not invoke Blender, a texture generator, network downloads or paid services.

## Required handoff record

Add `docs/graphics/results/NN-short-name.md` when implementing a package. Record:

1. Status: implemented, partial, experiment rejected, or blocked, with the exact remaining issue.
2. Source changes and any differences from the plan, including schema migration and fallback behavior.
3. Generator command, tool versions, input seed/settings, output manifest and regeneration instructions when assets are involved.
4. Before/after image and motion artifact paths, benchmark tables and hardware/configuration.
5. Checks run, outcomes, pre-existing failures and untested platforms.
6. Quality-tier behavior, known limitations and follow-up work with a concrete next step.

Do not mark a package complete while its required acceptance checks remain unverified. Do not silently expand a visual change into simulation balancing. Reconcile proposed APIs with current code and document the final contract for the next agent.
