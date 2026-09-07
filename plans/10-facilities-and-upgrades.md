# Facilities and upgrades

## Goal

Grow the six facilities into a fuller hospitality set with upgrade tiers, so building choices differentiate resorts and give grade progression something to spend on: putting green, pro shop, restaurant tiers, halfway house, spa, lodge for multi-day stays, and tiered clubhouse and range.

## Current state

- Facilities are catalog entries with `capacity`, `radius`, `upkeep`, `benefit`. `_refresh_facilities` discovers them from `terrain.objects`; `_apply_facility_to_guest` has a `match` on kind for three behaviours.
- `_choose_pre_round_facility` picks one facility before the round. Nothing happens between holes or after the round.
- Objects are one dictionary; there is no upgrade level.

## Design

### New facilities

| ID | Cost | Upkeep | Capacity | Benefit | Guest effect | Unlock |
|---|---|---|---|---|---|---|
| `putting_green` | 9,000 | 40 | 12 | practice | skill +0.015 putting only, mood +0.03, free | base |
| `pro_shop` | 34,000 | 160 | 10 | retail | purchase 18..60 at `prices.retail`, mood +0.04; needs `shop_clerk` for full capacity | `pro_shop` node |
| `halfway_house` | 21,000 | 120 | 12 | hunger | mid-round snack stop for groups after hole ⌈n/2⌉; hunger −0.5, energy +0.15 | base |
| `restaurant` | 62,000 | 320 | 32 | dining | post-round meal at `prices.meal` (28); mood +0.10; spend gates on budget | `restaurant` node |
| `bar_terrace` | 38,000 | 200 | 24 | social | post-round drink; mood +0.06; publicity +0.5/day when busy | `restaurant` node |
| `spa` | 88,000 | 420 | 10 | comfort | post-round; energy reset, mood +0.12, spend 45 | grade 3 |
| `lodge` | 140,000 | 640 | 16 rooms | lodging | groups may stay overnight and play again next day | `lodge` node |
| `caddie_house` | 30,000 | 180 | 8 | service | caddie groups get skill +0.04 and 10 % faster turns | grade 2 |

### Upgrade tiers

Add `level: int` (default 1) to facility object dictionaries and a `tiers` array in the catalog entry:

```gdscript
"tiers": [{"capacity": 28, "upkeep": 240}, {"cost": 36000, "capacity": 44, "upkeep": 330, "name": "Clubhouse Pavilion"},
          {"cost": 70000, "capacity": 64, "upkeep": 450, "name": "Grand Clubhouse", "grade": 3}]
```

Clubhouse (3 tiers, also raises membership caps), driving range (2 tiers: covered bays, +lesson capacity), snack kiosk → snack bar (2 tiers), restroom → comfort station (2 tiers, slower cleanliness decay), cart barn (2 tiers, capacity 12 → 20), maintenance shed (2 tiers, +groundskeeper output). `upgrade_object(id)` in `main.gd` runs through `_commit` as an `"object"` command with `before`/`after` so undo works, and `AssetFactory.build(kind, level)` varies the model (extra wing, second storey, colour trim).

### Visit flow changes

Extend the group state machine with two optional stops:

- **Mid-round**: after finishing hole index `floor(course_size / 2)`, if `halfway_house` exists and average hunger > 0.35 or energy < 0.5, route to it, then resume at the next hole. Implemented in `_complete_hole` before `_send_to_next_hole`.
- **Post-round**: after the last hole, in `_complete_hole` where departure is set, pick up to two of `restaurant`, `bar_terrace`, `spa`, `pro_shop` based on needs, budget, and mood, then depart. Reuse `_send_to_facility` and `_tick_facility_use` with a `post_round` flag so completion is still counted.

### Lodge and multi-day stays

Groups with `wants_lodging` reserve one to three nights when rooms are available. The complete stay is charged as ancillary revenue at departure; it never pauses, refreshes, stores, or re-queues active golfers. Legacy saves migrate `lodged` groups into normal departure.

### Facility state additions

`_facility_state` gains `level`, `revenue_today`, `visits_today`, and `staffed` (clerk present). `facility_status()` exposes them for the Build panel's per-facility inspector: condition, cleanliness, queue, workers, today's revenue and visits, an Upgrade button with cost, and a Close toggle (closed facilities are skipped by choosers and have no decay).

## Files

- `scripts/catalog.gd`: new entries, `tiers`, `prices` defaults for `retail`, `meal`, `room`.
- `scripts/asset_factory.gd`: eight new builders plus tier variants.
- `scripts/resort_simulation.gd`: kind behaviours in `_apply_facility_to_guest`, mid- and post-round stops, lodging lifecycle, level-aware capacity in `_refresh_facilities`, `_settle_wages_and_upkeep` reading tier upkeep, closed flag, revenue counters.
- `scripts/main.gd`: `upgrade_object`, `toggle_facility_closed`.
- `scripts/resort_ui.gd`: Build panel inspector.
- `tests/test_assets.gd`: bounds and ground offsets for new models.

## Tests

- `tests/test_assets.gd`: every new kind and tier builds, is centred, and sits at y = 0.
- `tests/test_simulation.gd`: a restaurant with hungry post-round groups records `meals` revenue and completion still counts; halfway house visit occurs mid-round on a 6-hole course and the group finishes all holes; lodge groups survive `_end_day`, are charged rooms, and replay next morning; upgrading the clubhouse raises `_checkin_capacity()`; a closed facility is never chosen.
- `tests/test_regressions.gd`: old objects without `level` default to 1; 100-guest stress day with a lodge still strands nobody; ledger reconciles with rooms and retail.
- `tests/test_game.gd`: place, upgrade, undo the upgrade, demolish.

## Phases

1. Tier data, `level` field, upgrade command with undo, asset variants for existing six facilities.
2. `putting_green`, `halfway_house`, `pro_shop`, `caddie_house`, mid-round stop.
3. `restaurant`, `bar_terrace`, `spa`, post-round stops.
4. `lodge` and overnight stays.

## Dependencies

- `pro_shop` staffing uses the `shop_clerk` role from the staff plan; until then it runs at 60 % capacity.
- New kinds should register unlock nodes in the progression plan.
