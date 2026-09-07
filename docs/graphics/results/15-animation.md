# Package 15 — Character and vehicle motion

**Status:** implemented (bounded foot placement; detailed IK planting deferred)  
**Date:** 2026-09-07  
**Godot:** 4.7.2 stable, Compatibility (`gl_compatibility`)

## Summary

Package 15 adds cosmetic golfer and cart motion through `ActorMotion`, keeping pose state separate from simulation position/RNG. Golfers blend idle, walk, address, backswing, contact, and follow-through poses with walk cadence driven by traveled distance. Terrain slope sampling drives root lean and lightweight foot height correction. Club contact and ball launch share a published visual timeline so package 16 can synchronize effects without re-deriving outcomes. Carts rotate wheels from distance, steer from route curvature, and apply pitch/roll/suspension from ground sampling under axle points.

## Rig and state contracts

### Golfer rig nodes (unchanged from package 09)

| Node | Role |
|---|---|
| `Head` | Head mesh; yaw toward shot direction during swings |
| `Torso` | Body lean (pitch/roll from terrain) |
| `ArmL` / `ArmR` | Walk stride and swing phases |
| `LegL` / `LegR` | Walk stride; bounded vertical foot offset on slopes |
| `Club` | Swing arc; aligned to contact/follow-through phases |

`AssetFactory::staff_golfer` reuses the same rig. `AssetFactory::animate_golfer(node, activity, phase, aim_yaw=NaN, simplified=false)` remains the low-level pose API.

### Supported pose activities

`idle`, `walking`, `address`, `backswing`, `contact`, `follow_through`, `swinging` (legacy), `putting`, `seated`, `mowing`

### Cart dynamic nodes (package 09 contract)

`Wheels/WheelFL`, `Wheels/WheelFR`, `Wheels/WheelRL`, `Wheels/WheelRR` — spin on X, front wheels steer on Y.

### Cosmetic state (`ActorMotion` instance)

| Key | Scope | Fields |
|---|---|---|
| `golfer_cosmetic[id]` | guest/staff | `walk_distance`, `last_pos`, `body_yaw`, `aim_yaw`, `ground_pitch`, `ground_roll`, `frame` |
| `cart_cosmetic[group_id]` | cart group | `distance`, `heading`, `steer`, `suspension`, `pitch`, `roll`, `last_pos`, `frame` |
| `visual_shots[id]` | guest | `shot` (duplicate), `time` (presentation seconds), `serial` |

Reset via `ActorMotion.reset()` on world recreation, save/load, and despawn (`erase_actor` / `erase_cart`). Teleports above `TELEPORT_DISTANCE` (8 m) zero walk/wheel accumulators.

## Visual contact / event timing (package 16 handoff)

```gdscript
# ActorMotion.shot_visual_timeline(shot, is_putt) →
{
  "schema_version": 1,
  "swing_duration": 0.70 | 0.55,   # full swing | putt
  "contact_time": swing_duration * 0.50,
  "launch_time": contact_time,     # ball flight begins here
  "flight_duration": max(0.8, shot.physics_duration),
  "total_duration": launch_time + flight_duration,
}
```

**Rules for consumers (package 16):**

1. Read `visual_shots[id].time` only through `ActorMotion` after `advance_visual_shots(presentation_dt)` — never infer contact from live `guest.activity`.
2. Trigger contact effects at `launch_time` using the frozen `visual_shots[id].shot` payload (`landing`, `surface`, `club`, etc.).
3. `presentation_dt` is zero when paused, in photo mode, or at simulation speed 0; effects must follow the same clock.
4. Do not replay historical shots on save/load — `reset()` clears `visual_shots`; new serials register only on live `shot_serial` changes.
5. Simulation `shot_serial` / ShotEngine payloads remain authoritative for outcomes; cosmetic timing never feeds back.

Swing phase boundaries (normalized within `swing_duration`): address `<0.18`, backswing `<0.48`, contact `<0.52`, follow-through `<0.88`.

## Source changes

| File | Role |
|---|---|
| `scripts/actor_motion.gd` | Cosmetic state, terrain/cart posing, visual shot timeline, ball position |
| `scripts/asset_factory.gd` | Extended `animate_golfer` with swing phases, head aim, simplified LOD |
| `scripts/graphics_settings.gd` | `animation_distance_mid/far`, `animation_update_stride` per preset |
| `scripts/main.gd` | `_motion` integration in `_update_people`, `_update_balls`, `_recreate_world` |
| `tests/test_graphics.gd` | Timeline contract, determinism, rig/quality checks (+1 test group) |
| `tests/test_assets.gd` | Swing activity pose smoke checks |

### Deviations from plan

- **Detailed foot planting:** Shipped bounded root/leg Y correction from slope samples; full per-foot IK marked partial.
- **Windowed motion captures:** Not run this pass (headless validation only).
- **Separate distant golfer mesh:** Distant actors use simplified limb posing via `simplified=true`, not a second rig asset.

## Quality-tier behavior

| Preset | Mid distance | Far distance | Update stride | Distant behavior |
|---|---:|---:|---:|---|
| low | 50 m | 120 m | 3 | Root + wheels only; limbs reset |
| standard | 70 m | 180 m | 2 | Reduced cosmetic tick rate beyond mid |
| high | 90 m | 240 m | 1 | Full posing to far distance |

Nearby motion stays continuous; far actors skip limb posing and some ground samples.

## Checks run

| Check | Result |
|---|---|
| `tests/test_assets.gd` | **68 passed** (swing phase activities included) |
| `tests/test_graphics.gd` | **0 failures** (actor motion contract + determinism; ~162 s headless incl. main scene) |
| Windowed lush captures / motion clips | **Not run** |

## Known limitations / follow-up

1. **Foot IK** — Add stable two-bone planting if art direction requires it; keep bounded root correction as fallback tier.
2. **Cart body node** — Shipped cart may not expose `Body`; pitch/roll fall back to root when absent.
3. **Package 16** — Implement effect adapter consuming `shot_visual_timeline` and `visual_shots` serial dedupe.
4. **Benchmark** — Profile 20+ active golfers/carts at standard preset after merge.

## Next step

Package 16: pool contact effects (sand puff, divot, water ripple) at `launch_time` from `ActorMotion.shot_visual_timeline`, with dedupe on `shot.serial` and bounded replay on world recreation.
