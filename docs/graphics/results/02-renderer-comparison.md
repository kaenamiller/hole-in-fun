# Package 02 — Renderer comparison

**Status:** trial complete — **keep Compatibility (`gl_compatibility`)**  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable (`ed1daf0bf`), pinned at `.tools/Godot.app` / `GODOT_BIN`

## Decision

**Keep `gl_compatibility` as the production default.** Mobile and Forward+ launch headless on macOS M2 (Metal driver) and compile all audited resort shaders, but measured headless frame times are indistinguishable (~127–131 avg fps, p95 ≈ 8 ms) and GPU counters/timings are unavailable in headless mode. That is CPU/script-bound noise, not evidence of a GPU win. No renderer-specific visual regression was observed in a single windowed Compatibility capture (248 draw calls, 272k primitives); cross-renderer screenshot comparison was **not** run. Windows and exported cold-start behavior remain **untested**. Migration is deferred until windowed/exported evidence shows a compelling benefit without material regressions.

No user-facing renderer picker was added. Renderer changes would require a restart and a separate preference store (not tied to resort saves); that remains out of scope until a backend is validated.

## Source changes (package 02)

| File | Role |
|---|---|
| `scripts/renderer_comparison.gd` | Trial helpers: method matrix, shader audit, handoff JSON |
| `tests/renderer_probe.gd` | Per-backend launch + shader compile probe |
| `tests/renderer_compare.gd` | Feature-matched benchmark wrapper around package 01 fixtures |
| `tests/render_api_probe.gd` | Minimal runtime API smoke print |
| `tools/renderer_compare.sh` | Batch probes + comparisons without editing `project.godot` |
| `tools/renderer_configs/*.override.cfg` | Isolated override snippets (not applied to production) |
| `tests/test_graphics.gd` | Lightweight contract tests for `RendererComparison` |
| `docs/graphics/results/02-renderer-comparison.md` | This handoff |

`project.godot` **`rendering/renderer/rendering_method` remains `gl_compatibility`** (including mobile export override).

## Godot pin and probe matrix

Engine: `.tools/Godot.app/Contents/MacOS/Godot` → `4.7.2.stable.official.ed1daf0bf` (see `.tools/godot.version`).

Probes use `--rendering-method <method>` on the CLI; `project.godot` is unchanged.

| Backend | CLI method | Runtime driver (headless macOS M2) | Probe | All 5 resort shaders compile |
|---|---|---|---|---|
| Compatibility | `gl_compatibility` | `opengl3` | OK | OK |
| Mobile | `mobile` | `metal` | OK | OK |
| Forward+ | `forward_plus` | `metal` | OK | OK |

Probe logs: `builds/renderer_compare/{method}_probe.log`

## Feature-matched benchmark results

**Config:** `standard` preset, feature-matched mode (no renderer extras), **12 s** measured × **2** samples, **3 s** warmup, 1440×1440 headless viewport. Scenarios: `starter_lake`, `dense_forest` only (short AFK pass).

| Scenario | Backend | Driver | avg fps (last sample) | p95 ms | p99 ms | draw calls | GPU timings |
|---|---|---|---:|---:|---:|---:|---|
| starter_lake | Compatibility | opengl3 | 129.1 | 8.0 | 65.0 | 0 | unsupported |
| starter_lake | Mobile | metal | 130.0 | 8.0 | 61.0 | 0 | unsupported |
| starter_lake | Forward+ | metal | 131.1 | 8.0 | 54.0 | 0 | unsupported |
| dense_forest | Compatibility | opengl3 | 126.8 | 8.0 | 75.0 | 0 | unsupported |
| dense_forest | Mobile | metal | 127.3 | 8.0 | 74.0 | 0 | unsupported |
| dense_forest | Forward+ | metal | 127.9 | 8.0 | 68.0 | 0 | unsupported |

**Interpretation:** All backends sit within ~3% average fps and identical p95 in headless. `Performance.RENDER_*` monitors read **0** draw calls/primitives headless for every backend (known limitation from package 01). `gpu_frame_time_ms` is false whenever headless. **Do not use these numbers to justify migration.**

JSON handoffs: `builds/renderer_compare/{scenario}_{method}.json` (+ `.txt` summary, `.log`).

### Decision table (trial gate)

| Criterion | Compatibility | Mobile | Forward+ | Notes |
|---|---|---|---|---|
| Launches headless (macOS M2) | Yes | Yes | Yes | |
| Custom shaders compile | Yes (5/5) | Yes (5/5) | Yes (5/5) | No `hint_screen_texture` / `hint_depth_texture` |
| Headless p95 frame time | ~8 ms | ~8 ms | ~8 ms | CPU-bound; not GPU evidence |
| Headless avg fps | 127–129 | 127–130 | 128–131 | Within noise |
| GPU frame timing | N/A headless | N/A headless | N/A headless | Needs windowed/exported run |
| Visual parity evidence | 1× Compatibility capture | Not captured | Not captured | See visual gap below |
| SSR / volumetric fog / decals (matrix) | Off | On (unused) | On (unused) | Game does not enable these yet |
| Windows | untested | untested | untested | Export presets not re-run |
| **Adopt as default?** | **Yes (keep)** | No | No | Insufficient measured benefit |

## Shader audit

All paths under `res://shaders/` used by the resort view:

| Shader | Compiles (all backends) | Notable tokens | Compatibility blockers |
|---|---|---|---|
| `resort_ground.gdshader` | Yes | `discard`, `source_color`, `MODEL_MATRIX`, analysis/show_grid | None |
| `resort_water.gdshader` | Yes | `TIME` waves, `NORMAL`/`METALLIC`/`SPECULAR`, `discard` shoreline | None; no screen/depth hints |
| `resort_foliage.gdshader` | Yes | vertex wind (`TIME`), `EMISSION` | None |
| `resort_path.gdshader` | Yes | `source_color` | None |
| `resort_horizon.gdshader` | Yes | simple `ALBEDO`/`ROUGHNESS` | None |

Audit flags `uses standard spatial lighting path` for all five (expected — not unshaded). No shader uses `hint_screen_texture` or `hint_depth_texture`. Materials are custom spatial shaders; terrain is not `StandardMaterial3D`.

`GraphicsSettings.sanitize` still forces unsupported `reflection_mode` values to **sky** (probe/planar deferred to packages 12/13).

## Visual evidence

| Capture | Status | Location |
|---|---|---|
| Compatibility windowed (`capture_lush.gd`) | OK — 5 views, 248 draw calls | `builds/renderer_captures/gl_compatibility/lush-*.png` |
| Mobile / Forward+ windowed | Not run this pass | — |
| Headless comparison | Frame times only | No pixel diff |

Windowed Compatibility capture confirms non-zero render counters and screenshot pipeline; cross-renderer A/B still outstanding.

## Platform gaps

| Platform | Status |
|---|---|
| macOS M2 headless | All three backends probed + benchmarked |
| macOS M2 windowed | Compatibility capture only |
| Windows (Compatibility / Vulkan) | **Untested** — no runner in this pass |
| Exported cold start / resize | **Untested** |
| Android / iOS export overrides | Project still sets mobile → `gl_compatibility` |

## How to re-run

```bash
cd /path/to/hole-in-fun
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"

# Probes only
for m in gl_compatibility mobile forward_plus; do
  "$GODOT_BIN" --headless --path . --rendering-method "$m" --script tests/renderer_probe.gd \
    > "builds/renderer_compare/${m}_probe.log" 2>&1
done

# Short feature-matched comparison (does not edit project.godot)
BENCHMARK_DURATION=12 BENCHMARK_WARMUP=3 BENCHMARK_SAMPLES=2 \
  ./tools/renderer_compare.sh
# Edit tools/renderer_compare.sh scenarios array to limit scenarios if needed.

# Single scenario/backend
"$GODOT_BIN" --headless --path . --rendering-method forward_plus --script tests/renderer_compare.gd -- \
  --benchmark-scenario=dense_forest \
  --benchmark-duration=12 --benchmark-warmup=3 --benchmark-samples=2 \
  --benchmark-preset=standard --comparison-mode=feature_matched \
  --benchmark-output=builds/renderer_compare/dense_forest_forward_plus

# Optional windowed captures (macOS display driver)
CAPTURE_WINDOWED=1 ./tools/renderer_compare.sh
```

Outputs stay under `builds/renderer_compare/` and `builds/renderer_captures/` (gitignored).

## Implications for package 03 (color and lighting)

- Calibrate color grading, sun/sky, and material reference images against **Compatibility** only until a future trial justifies retesting on Mobile/Forward+.
- Do not assume Forward+-only features (SSR, volumetric fog, decal buffers) are available in production.
- Keep `reflection_mode` on sky and existing shadow/MSAA defaults from package 01; lighting work should not depend on Metal/Vulkan-only paths.
- When package 03 lands reference PNGs, capture them with `tests/capture_lush.gd` under the current default renderer for regression baselines.

## Tests

```bash
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd
```

`test_graphics.gd` now checks `RendererComparison.METHODS`, `capabilities_for` feature flags, shader audit file presence/compile, and `project_method() == gl_compatibility`. Unit tests do **not** spawn three renderers.

## Trial vs migration status

| Item | Status |
|---|---|
| Renderer trial (02) | **Complete** |
| Production migration | **Not started / not recommended** |
| User renderer setting | **Not exposed** |
