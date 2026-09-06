# Resort simulation

`ResortSimulation` is a data-only `RefCounted`. It never creates nodes, emits signals, or owns presentation state. Call `setup(terrain, sandbox, starter)` once, then call `tick(simulated_seconds)`. The main game advances at 60 simulated seconds per real second. Tick accumulates fractional inputs and divides time into fixed one-second steps, so a full day may also be advanced in one call.

The operating day is 600 minutes, beginning at 7:00 a.m. `minute` is therefore in the range 0–600. Demand considers the number of playable holes, satisfaction, publicity, grade, green-fee price, and a scheduled event. A developed resort sees roughly 70–112 individual arrivals per day, assembled into groups of one to four.

## Guest and group lifecycle

Groups move through `arriving`, `checkin_queue`, optional `facility_queue` and `facility_use`, `to_tee`, `tee_queue`, `playing`, `departing`, and `departed`. Each hole admits one group and keeps a FIFO tee queue. Golfers take sequential turns; every shot uses `ShotEngine.shot`, retains the returned shot data while it animates, and adds penalties to the golfer's score. Each golfer has an individual scorecard, skill, budget, purchases, needs, mood, thought, and physical position.

`shot_serial` increments when a flight starts. The flight's original ShotEngine duration is kept as `shot.physics_duration`; the public `shot.duration` lasts at least 30 simulated seconds so a view polling after `tick(60)` can see it. `last_shot` keeps the most recent payload for views that animate independently. `shot` is cleared when the flight finishes.

Walkers move at 1.8 m/s. Cart groups use terrain cart routes at 6.5 m/s and expose `cart_pos` and `cart_parked`. The cart barn's catalog capacity limits simultaneous cart groups. Route results are cached by four-meter endpoint cells and cart mode, and the cache is discarded when `terrain.revision` changes.

Blocked or invalid play never strands a guest. If a hole closes, the resort refunds part of the green fee, releases queues and occupancy, finds safe ground, and routes the group to the entrance. `on_construction(center, radius, removed_hole_id)` performs the same recovery after terrain edits and records compensation in the ledger.

## Facilities and workers

Facilities are discovered from `terrain.objects` using Catalog definitions with `capacity`. Facility state includes condition, cleanliness, queue length, and assigned/nearby workers. Guest use lowers condition and cleanliness. Low quality reduces effective service capacity and can make a facility unusable.

The three individual worker roles are:

- `groundskeeper`: repairs facility condition and reduces course wear.
- `service_attendant`: increases clubhouse check-in throughput and facility service capacity.
- `cleaner`: restores facility cleanliness.

`assignment == -1` means automatic assignment. Otherwise `assign_staff(worker_id, object_id)` sends the worker to that facility. Workers use terrain walking routes and receive daily wages. `facility_status()` returns presentation-ready copies, including live queue and worker counts. Condition and cleanliness are also copied back into the matching terrain object dictionaries.

## Business, grades, and events

`prices` contains `green_fee`, `cart`, `range`, `snack`, and `event`. Guests can only buy within their personal budgets. Resort revenue and every expense are appended to `ledger` with day, minute, signed amount, category, description, and resulting balance. Daily settlement charges staff wages, object upkeep, loan interest, and scheduled loan payments. Three consecutive days below zero cash close a non-sandbox resort; `reopen()` succeeds once cash is positive and at least one hole is playable.

The catalog loan IDs are `working_capital`, `equipment_financing`, and `course_expansion`. Catalog `min_grade`, `interest`, `term_days`, and `payment` values are normalized into active loan records. `borrow()` prevents duplicate active products, while `repay()` supports additional principal payments. `recovery` is a one-time fallback accepted only after insolvency; if its proceeds restore positive cash, a playable closed resort reopens.

Grade promotion follows Catalog's cash, building count, playable-hole and publicity requirements, plus satisfaction, course-condition and successful qualifying-event thresholds. `grade_requirements()`, `unlocks()`, and `can_build(kind)` expose the same rules to UI code.

The six event IDs are `open_day`, `charity_scramble`, `beginner_clinic`, `club_championship`, `regional_amateur`, and `invitational`. Only one event can be scheduled per day. Attendance is counted when an event group begins real play, and completed rounds are counted only when those golfers finish the available course. End-of-day success, publicity, satisfaction, and scaled event revenue therefore depend on actual attendance and completion rather than a timer-only reward.

## Saving and integration API

The interface fields and methods in `docs/INTERFACES.md` are implemented. Additional polling helpers are:

- `admit_group(size, event_guest=false) -> int`: immediately creates a one-to-four-person group for debugging or scenarios, returning `-1` when admission is impossible.
- `facility_status() -> Array[Dictionary]`
- `active_event() -> Dictionary`
- `unlocks() -> Dictionary`
- `can_build(kind) -> bool`
- `reopen() -> bool`

`snapshot()` contains all public collections, all monotonic ID counters, active queues and occupancy, facility state, accounting accumulators, event state, closure state, and both RNG seed and RNG stream state. Call `setup()` on a new simulation with its terrain, then `restore(snapshot)`. Identical later ticks produce identical arrivals, shots, and financial results.

Run the standalone validation with:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_simulation.gd
```
