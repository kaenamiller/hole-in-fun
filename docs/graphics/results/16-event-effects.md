# Package 16 — Small event-driven effects

**Status:** implemented  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 16 adds pooled cosmetic contact and ambient effects driven by the package-15 visual shot timeline. Sand puffs, turf divot marks, and water ripples dispatch once per live shot serial at `launch_time`, with bounded deduplication and no save/load replay. Temporary divot marks use draped shader quads (no Decals). Flag cloth flutter and capped fountain spray use the always-advancing cosmetic clock; contact effects follow the presentation clock (zero when paused or at sim speed 0).

## Event IDs and timing

### Event adapter (`CosmeticEffectEvent`)

| Field | Type | Rule |
|---|---|---|
| `id` | int | `actor_id * 1_000_000 + shot_serial * 10 + type` |
| `type` | int | `0=sand_puff`, `1=turf_divot`, `2=water_ripple` |
| `position` | Vector3 | Authoritative landing from frozen shot payload |
| `surface_id` | int | Terrain surface index, or `body_id` for water ripples |
| `visual_time` | float | Presentation seconds at dispatch (`launch_time`) |
| `priority` | int | water 3, sand 2, divot 1 |

### Surface mapping

| Landing surface | Club | Effect |
|---|---|---|
| Sand (`4`) | any | Sand puff |
| Rough/fairway/tee (`0`,`1`,`3`) | not putter | Turf divot mark |
| Water (`5`) | any | `TerrainView.submit_water_ripple` when depth > 0 and body matches |
| Green (`2`) | any | none (no sand puff from greens) |

### Timing contract

1. Poll `ActorMotion.visual_shots` after `advance_visual_shots(presentation_dt)`.
2. Fire when `entry.time >= shot_visual_timeline(...).launch_time` once per `(actor_id, serial)`.
3. `presentation_dt` is zero when paused, menu open, photo mode, or sim speed 0 — contact effects do not accumulate.
4. Fast-forward does not burst on return to normal: dispatch is keyed to serial crossing, not queued while paused.
5. `reset()` on world recreation / load clears dedupe, dispatch keys, and active instances — historical shots are not replayed.
6. Water ripple submit uses wall cosmetic time (`Time.get_ticks_msec()/1000`) to match package-11 shader clock.

## Pool caps (`GraphicsSettings.effect_instance_cap`)

| Preset | Total cap | Sand pool | Mark pool | Ambient (flags/fountains) |
|---:|---:|---:|---:|---:|
| Low | 24 | 4 | 6 | 2 |
| Standard | 64 | 10 | 16 | 8 |
| High | 96 | 16 | 24 | 8 |

Derived in `CosmeticEffectManager.configure()`:

- `sand_cap = clamp(total / 6, 2..24)`
- `mark_cap = clamp(total / 4, 2..32)`
- `ambient_cap = clamp(min(8, total / 8), 0..8)`
- `total_cap = 0` disables contact effects entirely

Distance cull: 80 / 140 / 200 m by preset. When full, farthest/lowest-priority active instance is dropped.

## Lifetimes and invalidation

| Family | Lifetime | Teardown |
|---|---|---|
| Sand puff | 0.85 s presentation | Pool reuse |
| Turf mark | 45 s presentation fade | Removed on terrain edit in affected radius (+2 m pad) |
| Water ripple | package-11 pool | Rejected when dry / wrong body |
| Fountain spray | continuous | Max 6 objects, quality capped |

Marks clear on construction brush/contour commands via `invalidate_region(center, radius)`.

## Source changes

| File | Role |
|---|---|
| `scripts/cosmetic_effect_event.gd` | Event schema, surface mapping, bounded dedup ring |
| `scripts/cosmetic_effect_manager.gd` | Pools, dispatch, ambient flutter/spray, stats |
| `shaders/resort_effect_mark.gdshader` | Fading draped divot quad (no Decals) |
| `scripts/main.gd` | `_effects` integration in balls/update, terrain invalidation, world reset |
| `scripts/asset_factory.gd` | Named `Cloth` flag mesh, `SprayAnchor` on fountains |
| `scripts/renderer_comparison.gd` | Shader audit entry |
| `tests/test_graphics.gd` | Event/timing/dedupe/cap contract tests |

### Deviations from plan

- **Windowed motion clips:** Not run (headless validation only).
- **Birds/insects:** Deferred optional ambient; flags/fountains only.
- **GPU particles:** Sand/fountain use CPU particles for Compatibility pooling simplicity.

## Checks run

```bash
export GODOT_BIN="${GODOT_BIN:-$PWD/.tools/Godot.app/Contents/MacOS/Godot}"
"$GODOT_BIN" --headless --path . --script tests/test_graphics.gd
"$GODOT_BIN" --headless --path . --script tests/test_shots.gd
```

| Check | Result |
|---|---|
| `tests/test_graphics.gd` | **0 failures** (event effects contract + existing suites; ~52 s headless incl. main scene) |
| `tests/test_shots.gd` | **0 failures** |
| Windowed lush captures / motion clips | **Not run** |

## Debug / stress

`CosmeticEffectManager.stats()` returns active counts and caps for HUD or probes.

Suggested stress: run `--autoplay` at speed 10 for several minutes, return to speed 1 — contact dispatch keys prevent replay burst; pool counts stay bounded.

## Known limitations / follow-up

1. **Windowed validation** — Capture sand/divot/water contacts with `tests/capture_lush.gd`.
2. **Divot reprojection** — Marks fade in place; steep edits may leave faint quads until lifetime expires (region invalidation handles most edits).
3. **Separate-height lakes** — Water ripples reject wrong `body_id` via package-11 contract.

## Next step

Run windowed motion validation; profile worst-case simultaneous contact effects at standard preset with 20 active golfers.
