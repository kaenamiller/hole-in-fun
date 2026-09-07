# Package 01 — Benchmarks and quality settings

**Status:** implemented  
**Date:** 2026-09-06  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 01 adds a reproducible benchmark harness with immutable fixtures, a persisted `GraphicsSettings` service with Low / Standard / High presets, and a small settings UI in the gear menu. Standard defaults match the pre-package visual configuration (4× MSAA, 4096 shadow map, 1100 shadow distance, full foliage). Simulation RNG, shots, placement costs, and routes are unchanged by quality toggles.

## Source changes

| File | Role |
|---|---|
| `scripts/graphics_settings.gd` | Resource schema and preset definitions |
| `scripts/graphics_settings_service.gd` | Load/save (`user://settings/graphics.json`), apply, hardware/engine metadata |
| `scripts/benchmark_fixtures.gd` | Fixed scenarios: starter lake, dense forest, 18-hole resort, active golfers, terrain edit |
| `scripts/benchmark_runner.gd` | CLI parsing, frame stats, JSON/CSV/text export, capability flags |
| `tests/benchmark_lush.gd` | Benchmark entry script (upgraded harness) |
| `tests/test_graphics.gd` | Settings persistence, fallback, RNG isolation, world recreation |
| `scripts/main.gd` | Settings service, lighting/viewport apply, profile metrics |
| `scripts/terrain_view.gd` | Foliage density, LOD bias, visibility range, tree shadow volumes |
| `scripts/asset_factory.gd` | Configurable foliage LOD distance |
| `scripts/resort_ui.gd` | Graphics quality buttons in System settings |
| `tools/test.sh` | Adds `graphics` suite |

### Deviations from plan

- **60-second samples:** Baseline tables below use 25 s × 3 samples (5 s warmup) for this AFK run. The harness supports `--benchmark-duration=60 --benchmark-samples=3`; prefer that for regression gates.
- **Two resolutions:** Primary target remains 1440×900 (`project.godot`). A second pass at 1920×1080 (or native Retina) is documented intent only; not run here. Override with window size before launch when comparing tiers.
- **GPU timings / headless render counters:** Compatibility headless runs report `gpu_frame_time_ms=false`, `memory_dynamic=false`, and `render_info_headless=false` (draw-call/primitive Performance monitors read 0 headless; windowed `capture_lush.gd` still reports counters, e.g. 248 draw calls / 272k primitives on this machine).
- **Reflection probe / planar:** Schema fields exist; unsupported modes fall back to sky-only (`reflection_mode` forced to `sky` until package 12/13).

## How to run benchmarks

```bash
cd /path/to/hole-in-fun
GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Single scenario (JSON + CSV + summary text under builds/benchmarks/)
"$GODOT_BIN" --headless --path . --script tests/benchmark_lush.gd -- \
  --benchmark-scenario=starter_lake \
  --benchmark-duration=60 \
  --benchmark-warmup=5 \
  --benchmark-samples=3 \
  --benchmark-preset=standard \
  --benchmark-seed=730241 \
  --benchmark-output=builds/benchmarks/starter_lake_standard

# Legacy-compatible 25 s active-golfer run (prints summary only)
"$GODOT_BIN" --headless --path . --script tests/benchmark_lush.gd
```

### CLI arguments

| Argument | Default | Description |
|---|---|---|
| `--benchmark-scenario=` | `starter_lake` | `starter_lake`, `dense_forest`, `resort_18`, `active_golfers`, `terrain_edit` |
| `--benchmark-duration=` | `25` | Measured seconds per sample (after warmup) |
| `--benchmark-warmup=` | `5` | Warmup seconds discarded |
| `--benchmark-samples=` | `1` | Repeated samples appended to JSON/CSV |
| `--benchmark-seed=` | `-1` | Fixture seed (`-1` = scenario default) |
| `--benchmark-preset=` | `standard` | `low`, `standard`, `high` |
| `--benchmark-output=` | _(empty)_ | Base path; writes `.json`, `.csv`, `.txt` |

### Scenarios

| ID | Mode | Contents |
|---|---|---|
| `starter_lake` | Fixed state, sim paused | Cedar House starter lake layout, overview camera |
| `dense_forest` | Fixed state | Pinewood Valley + deterministic extra trees/buildings (~520 objects) |
| `resort_18` | Fixed state | Pinewood Valley 18-hole stress layout |
| `active_golfers` | Deterministic sim | Starter lake, 20 guests (5×4), arrivals closed, speed 1×, fixed RNG seed 90210 |
| `terrain_edit` | Repeated edit | Starter lake, paint brush loop, terrain rebuild + sync timed |

## Settings schema / API contract (for packages 02–16)

### Resource: `GraphicsSettings`

Persisted JSON keys (version 1):

```json
{
  "version": 1,
  "preset": "standard",
  "foliage_view_distance": 900.0,
  "foliage_density": 1.0,
  "foliage_lod_bias": 2.0,
  "shadow_distance": 1100.0,
  "shadow_resolution": 4096,
  "msaa_3d": 2,
  "reflection_mode": "sky",
  "reflection_resolution": 256,
  "weather_particle_cap": 600,
  "effect_instance_cap": 64,
  "tree_shadow_volumes": true
}
```

**Presets**

| Field | Low | Standard (default) | High |
|---|---|---|---|
| foliage_view_distance | 450 | 900 | 1100 |
| foliage_density | 0.55 | 1.0 | 1.0 |
| foliage_lod_bias | 3.5 | 2.0 | 1.6 |
| shadow_distance | 600 | 1100 | 1400 |
| shadow_resolution | 2048 | 4096 | 4096 |
| msaa_3d | 0 (off) | 2 (4×) | 2 (4×) |
| weather_particle_cap | 200 | 600 | 600 |
| tree_shadow_volumes | false | true | true |

### Service: `GraphicsSettingsService`

- **Path:** `user://settings/graphics.json` (separate from resort saves)
- **`current: GraphicsSettings`** — active settings
- **`settings_changed(previous, current)`** — emitted on preset/custom change
- **`load_or_default()` / `_read_file()`** — invalid keys clamp; unknown preset → Standard
- **`save()`** — writes JSON
- **`set_preset(name: String)`** — applies preset, saves, emits signal
- **`apply_to_game(game, rebuild_scenery := true)`** — MSAA, shadows, environment, weather cap, `TerrainView.apply_graphics_settings`
- **`hardware_info()` / `engine_info()` / `runtime_info(game)`** — benchmark metadata

### Integration hooks for later packages

- **`main.gd`:** `_apply_graphics_lighting`, `_apply_graphics_environment`, `_apply_graphics_weather`; call `graphics.apply_to_game(self, false)` for uniform-only updates
- **`terrain_view.gd`:** `apply_graphics_settings(settings)` — foliage batches, shadow volumes
- **`AssetFactory.foliage_lod_distance`** — static, set from settings before mesh bake/LOD
- **Do not** change `rendering/renderer/rendering_method` via quality toggle (package 02)

## Baseline tables (this machine)

**Hardware:** Apple M2, macOS 26.5.2, Compatibility/OpenGL  
**Resolution:** 1440×900 project default (headless viewport reported 1440×1440)  
**Protocol:** 5 s warmup, 25 s × 3 samples, Standard unless noted  
**Historical reference (pre-package):** 35.9 avg fps, 20 ms p95, 20 guests, 719 frames — different scenario/duration; not directly comparable.

### Standard preset — frame time (ms)

| Scenario | avg fps | p50 | p95 | p99 | worst | frames/sample | guests |
|---|---:|---:|---:|---:|---:|---:|---:|
| starter_lake | 128.7 | 7.0 | 10.0 | 63.0 | — | ~1073 | 0 |
| dense_forest | 127.2 | 7.0 | 9.0 | 70.0 | — | ~1060 | 0 |
| resort_18 | 128.7 | 7.0 | 10.0 | 66.0 | — | ~1075 | 0 |
| active_golfers | 128.3 | 7.0 | 9.0 | 68.0 | — | ~1071 | 20 |
| terrain_edit | 71.7 | 12.0 | 12.0 | 82.0 | — | ~598 | 0 |

### Low vs Standard (starter_lake & active_golfers)

| Scenario | Preset | avg fps | p95 ms | Notes |
|---|---|---:|---:|---|
| starter_lake | standard | 128.7 | 10.0 | Full foliage + shadows |
| starter_lake | low | 129.6 | 10.0 | Headless CPU-bound; foliage/shadow savings visible windowed |
| active_golfers | standard | 128.3 | 9.0 | 20 guests, sim 1× |
| active_golfers | low | 128.0 | 9.0 | Same guest count |

### Workload instrumentation (terrain_edit, sample totals)

| Metric | ~ms per 25 s sample |
|---|---:|
| terrain rebuild + sync | dominated by edit loop (~12 ms p50 frame) |
| sim tick | 0 (paused) |

### Initial budget triggers (proposed, not measured GPU ms)

| Tier | Target | Review trigger |
|---|---|---|
| Low | stable 30 fps windowed on M2 @ 1440×900 | p95 frame > 33 ms at Low preset |
| Standard | optimization goal 60 fps | >10% p95 regression vs baseline at same fixture |
| High | optional headroom | adopt only with measured margin |

Do **not** assign per-effect GPU millisecond budgets without isolated measurements (capability flags document gaps).

## Checks run

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | 0 failures |
| `tests/test_assets.gd` | 60 passed |
| `tests/test_lush.gd` | 0 failures |
| `tests/test_shots.gd` | all passed |
| `tests/test_terrain.gd` | all passed |
| `tests/test_simulation.gd` | not re-run to completion (long-running pre-existing suite) |
| Windowed `capture_lush.gd` | screenshots OK; render counters non-zero |
| Headless benchmarks | all five scenarios completed |

## Known limitations / follow-up

1. **Headless render counters** — use windowed runs or exported app for draw-call/primitive baselines.
2. **Second resolution pass** — add `--benchmark-width/height` or document manual window override before compare.
3. **60 s × 3 official baselines** — re-run with `--benchmark-duration=60` and replace tables above.
4. **Windows runtime** — not tested; export rendering verification outstanding.
5. **Package 02** — renderer migration remains explicit; quality toggle does not restart renderer.
6. **`effect_instance_cap`** — schema only; event effects (package 16) should respect it.

## Regeneration

```bash
./tools/test.sh          # includes test_graphics
# Full benchmark sweep (outputs gitignored under builds/benchmarks/)
for s in starter_lake dense_forest resort_18 active_golfers terrain_edit; do
  "$GODOT_BIN" --headless --path . --script tests/benchmark_lush.gd -- \
    --benchmark-scenario=$s --benchmark-duration=60 --benchmark-warmup=5 \
    --benchmark-samples=3 --benchmark-preset=standard \
    --benchmark-output=builds/benchmarks/${s}_standard
done
```
