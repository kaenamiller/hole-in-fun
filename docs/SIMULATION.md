# Resort simulation

`ResortSimulation` is a data-only `RefCounted`. It never creates nodes, emits signals, or owns presentation state. Call `setup(terrain, sandbox, starter)` once, then call `tick(calendar_seconds)`. The main game advances at 60 calendar-seconds per real second. Each fixed calendar step derives actor time with `actor_dt = calendar_dt / SIM_RATE`.

## Calendar, seasons, and settlement

Play is continuous: there is no operating window and no closing-time eviction. One calendar day is `DAY_SIM_SECONDS` = 800 simulated seconds (≈ 13.3 real seconds at 1x speed, so a 90-day quarter lasts about 20 real minutes). Every month has 30 days; day 1 is March 1 of Year 1, giving Mar–May Spring, Jun–Aug Summer, Sep–Nov Fall, and Dec–Feb Winter. `date_string()`, `season_name()`, `clock_string()` (a 24-hour face anchored at 6:00 a.m.), and `weather()` (rain / clear / leaves / snow) expose the calendar to views.

Roll-overs replace the old day boundary:

- **`_roll_day`** (every calendar day): event settling/activation, analytics and terrain decay, staff day close, unlock project ticks, intraday series reset. Guests are never evicted — visits continue until they finish, lodge, or leave on their own.
- **`_roll_month`** (month boundary): wages, upkeep, and loan settlement (ledger entries dated to the settled month), monthly history record, insolvency check.
- **`_roll_season`** (quarter boundary): course grading and seasonal assessment.

Demand uses **awareness** (reach) and **rating** (conversion), plus facilities, wear, season, weekend, and price elasticity. Demand was authored against the old 36,000-second operating day and is converted with `DEMAND_SCALE` (× 800/36000 × 4); a starter resort targets roughly 3–16 arrivals per calendar day, assembled into groups of one to four. `arrivals_enabled = false` suspends walk-ins without disturbing golfers already on the course.

## Pace of play

The simulation has separate calendar and actor time scales. Movement, shots, waits, facility service, maintenance, and staff vitals consume actor-seconds; the calendar, seasons, demand, and financial settlement consume calendar-seconds. `SIM_RATE = 60` calendar-seconds per actor-second, `BASE_PACE = 1.6` makes walking somewhat brisker than real life, and `SHOT_PACE = 1.5` stretches ball flight. The player speed multiplier scales both systems. A targeted 15–16 minute 18-hole round spans roughly 68–72 calendar days, or 2.25–2.4 months.

## Reputation and marketing

Three managed numbers drive demand while **publicity** remains a derived value for grade checks:

- **Awareness** (0..100): raised by campaigns and events; decays 1.5% per day.
- **Rating** (1.0..5.0): rolling mean of departing guests' star scores (`1 + mood × 4`, refunds = 1 star) with a 14-day half-life. Seeded at 3.0.
- **Buzz** (−20..+20): word-of-mouth from the last three days of `feedback_summary` plus press moments; decays 40% per day.

`publicity = awareness × (0.4 + 0.15 × rating) + buzz`, clamped 0..100.

Demand base: `(30 + awareness × 0.9) × (0.55 + rating × 0.14)` multiplied by facility, scenery, wear, season, weekend, and elasticity factors.

**Campaigns** (`Catalog.campaigns()`, max two concurrent): `start_campaign(id)` charges day one; `_roll_day` applies daily effects, charges subsequent days, and retires finished runs. Unlock grants use `marketing:flyer` and `marketing:radio_spot`.

**Press moments** at day end: course records, congestion stories, unusable facilities, grade promotions, and event outcomes adjust buzz and awareness.

`rating_breakdown()` returns overall stars plus Course, Facilities, Service, Value, and Scenery sub-scores from feedback tags. `forecast_arrivals()` estimates tomorrow's visitor band (±12%).

Old saves without awareness/rating state migrate with `awareness = publicity` and `rating = 3.0`.

## Guest and group lifecycle

Groups move through `arriving`, `checkin_queue`, optional `facility_queue` and `facility_use`, `to_tee`, `tee_queue`, `playing`, optional mid-round and post-round facility stops, `departing`, `lodged` (multi-night lodge stays), and `departed`. Each hole admits one group and keeps a FIFO tee queue. Golfers take sequential turns; every shot uses `ShotEngine.shot`, retains the returned shot data while it animates, and adds penalties to the golfer's score. `ShotEngine` first scores a small set of aims (pin, fat of green, short of hazard, carry, tree sidestep, lag putt) with a cheap expected-strokes model that uses the same miss ellipse as execution, then plays the chosen target with the usual bell-curve scatter. Better players attack more because their predicted ellipse is tighter and they are less risk-averse; worse players lay up or aim away from trouble. Each golfer has an individual scorecard, skill, budget, purchases, needs, mood, thought, and physical position.

`shot_serial` increments when a flight starts. The flight's original ShotEngine duration is kept as `shot.physics_duration` (stretched by `SHOT_PACE`); the public `shot.duration` is expressed in actor-seconds. `last_shot` keeps the most recent payload for views that animate independently. `shot` is cleared when the flight finishes.

Walkers move at 1.8 m/s × `BASE_PACE` (1.6); cart groups use terrain cart routes at 6.5 m/s × `BASE_PACE` and expose `cart_pos` and `cart_parked`. During hole play, golfers with cart groups ride to their ball instead of walking. The cart barn's catalog capacity limits simultaneous cart groups. Route results are cached by four-meter endpoint cells and cart mode, and the cache is discarded when `terrain.revision` changes.

Blocked or invalid play never strands a guest. If a hole closes, the resort refunds part of the green fee, releases queues and occupancy, finds safe ground, and routes the group to the entrance. `on_construction(center, radius, removed_hole_id)` performs the same recovery after terrain edits and records compensation in the ledger.

## Patrons and memberships

Guests can become **patrons** — persistent records in `sim.patrons` keyed by monotonic `patron_id`. Each patron stores `name`, `skill`, `budget_base`, `visits`, `last_day`, `affinity` (0..1), optional membership `tier`, dues schedule fields, capped `history` (10 visits), capped `scorecards` (5 rounds), and a computed `handicap`.

**Returning arrivals:** when creating a walk-in group, each guest has probability `clamp(0.15 + 0.5 × satisfaction, 0.2, 0.65)` of matching an eligible patron (not on site, `last_day < day`). Selection is weighted by `affinity` and days since the last visit. Returning guests copy patron skill (plus 0.005 per prior visit, capped at 0.97), budget scaled from mood history, and carry `guest.patron_id`.

**New patrons:** on departure, guests without a patron who leave with mood ≥ 0.55 are registered. Affinity updates each visit: `lerp(affinity, mood, 0.4)`; refund departures take an extra −0.15. Patrons below 0.2 affinity with no visit in 20 days are removed (`Lost customer` log entry, collapsed). The roster caps at 600; when full, the lowest-affinity non-member with the oldest `last_day` is dropped.

**Member bookings** are a separate arrival channel from walk-in demand (`_arrival_target`). Each morning, every member has chance `0.35 × affinity` to book (×1.5 while the loyalty mailer campaign is active). Booked members spawn ahead of walk-ins. Tier perks apply through `price(key, {membership_tier})`:

| Tier | Dues / 30 days | Includes | Perks |
|---|---|---|---|
| `social` | 180 (editable) | 10% off snacks | may book |
| `player` | 520 | green fees | priority tee (one queue place) |
| `founder` | 1,400 | green fees, cart, range | priority tee; auto-booked for `club_championship` |

Offer logic on departure: non-members with `visits ≥ 3`, `affinity ≥ 0.7`, and `budget_base ≥ 2 × dues/30` join the best affordable open tier with probability `0.5 × affinity`. Caps scale with clubhouse capacity: social ×4, player ×2, founder ×0.5. Tiers two and three require unlock grants (`membership:2`, `membership:3`, `membership:founder`).

Members pay dues when `day % 30 == joined_day % 30` (`credit(..., "membership", …)`). They cancel after two consecutive visits with `affinity < 0.35` or when dues exceed 45% of `budget_base × 30`. Join/cancel reasons use `_feedback` tags `member_join` and `member_cancel`.

**Handicap:** mean of the last five completed scorecards versus par: `mean(strokes − par) × 1.1`. Display-only today; exposed on guests via `guest_patron_line()`.

**Player controls** (Money panel → Members): editable dues and open/closed toggles per tier, live counts, estimated monthly dues income, and 30-day churn. `patron_summary()` and `members()` feed the UI.

## Facilities and workers

Facilities are discovered from `terrain.objects` using Catalog definitions with `capacity`. Each facility object carries `level` (default 1), optional `closed`, `condition`, and `cleanliness`. Tier stats (`capacity`, `upkeep`, bonuses) come from `Catalog.facility_tier(kind, level)`. Runtime state in `_facility_state` also tracks `revenue_today`, `visits_today`, and whether the facility is staffed.

**Pre-round stops** (`_choose_pre_round_facility`): putting green, driving range, snack kiosk, restroom — skipped when `closed`.

**Mid-round stop**: after hole index `floor(n/2)`, groups with hunger > 0.35 or energy < 0.5 may visit `halfway_house` (hunger −0.5, energy +0.15) before continuing.

**Post-round stops**: after the last hole, up to two of `restaurant` (`prices.meal`, ledger `meals`), `bar_terrace`, `spa`, and `pro_shop` (`prices.retail`, ledger `retail`) are chosen from needs and budget. Completion still counts when `post_round` is set.

**Lodge**: groups with `wants_lodging` (probability `0.12 + 0.2 × (grade − 1)` when rooms are free) may stay overnight instead of departing. `_process_lodge_night` charges `prices.room` (default 120) per guest (ledger `lodging`), resets needs, and decrements `lodge_nights` (1–3). Lodged groups survive day rollover; `_release_lodge_guests_to_tee` re-queues them as unpaid `to_tee` groups the next morning. Lodged guests count toward the 200-guest cap.

**Closed facilities** are omitted by `_has_facility` / `_best_facility` and do not decay in `_tick_facility_decay`. Toggle via `main.gd::toggle_facility_closed(id)` (undoable object command).

**Upgrades**: `main.gd::upgrade_object(id)` applies the next catalog tier through `_commit` with `before`/`after` for undo. Clubhouse tiers raise `_checkin_capacity()` via `checkin_bonus`.

Guest use lowers condition and cleanliness. Low quality reduces effective service capacity and can make a facility unusable.

Each worker record carries `skill`, `experience` (0..1), `morale` (0..1), `fatigue` (0..1), `shift` (`early` | `late` | `full`), optional `training` (`{course, days_left}`), `traits`, `hired_day`, `wage`, and `raise_requested`.

**Effective skill** (used for all work rates):

`skill × (0.7 + 0.3 × experience) × (0.6 + 0.4 × morale) × (1 − 0.35 × fatigue)`, then ×1.1 if morale > 0.8, and ×0.5 if fatigue > 0.8.

**Fatigue** rises 0.0011 per on-shift actor minute (slower with the `careful` trait) and recovers continuously while off shift. Shifts use a repeating actor-time day rather than the compressed game calendar: `early` and `late` cover consecutive eight-hour blocks, while `full` is always on.

**Morale** drifts toward a target from wage fairness (vs. catalog base × (1 + experience)), walking workload, facility/hole condition where assigned, and resort satisfaction. Below 0.3 for three days triggers `raise_requested`; ignored for five more days the worker quits (critical log). Firing costs 3× wage severance and lowers other staff morale by 0.05.

**Hiring** refills `candidates` each morning with 2–4 applicants per unlocked role (rolled skill 0.45–0.95, traits, asking wage). `hire(candidate_id)` charges a signing bonus of 2× wage. `hire(role)` hires the first candidate for that role.

**Training** (`train(worker_id, course_id)`) removes the worker for `days_left` days and adds the catalog skill bonus on completion.

Roles:

- `groundskeeper`: repairs facility condition and reduces course wear; hole assignment via `{"kind":"hole","id"}`.
- `service_attendant`: increases clubhouse check-in throughput and facility service capacity.
- `cleaner`: restores facility cleanliness.
- `golf_pro`: waits at the driving range; 50% lesson chance (`prices.lesson`, default 35) adds guest skill +0.06 and mood +0.08 (ledger category `lessons`).
- `marshal`: patrols assigned hole tee/green loop; −12% group turn time and −40% tee-queue mood loss on that hole.
- `head_greenkeeper`: supervises from the maintenance shed; +20% groundskeeper output within 200 m.
- `shop_clerk`: staffs `pro_shop` on site; without a clerk the shop runs at 60% queue capacity. When present, the clerk serves at the shop (`activity` = `serving`) and full retail throughput applies.

`assignment == -1` means automatic assignment. Otherwise `assign_staff(worker_id, object_id)` or `{"kind":"hole"|"object","id"}`. Workers use terrain walking routes and receive monthly wages. `facility_status()` returns presentation-ready copies, including `level`, `closed`, `revenue_today`, `visits_today`, `staffed`, live queue, and worker counts.

## Business, grades, and events

`prices` is a price book kept in `sim.prices` for save compatibility. Product keys (`green_fee`, `cart`, `range`, `snack`, `lesson`, `event_entry`, `retail`, `meal`, `room`) store `{"base": …}` entries; green fee also has `twilight`, `weekend`, and `twilight_start_minute` (default 420, i.e. 2:00 p.m.). Scalars include `group_discount` (default 0.10 for groups of four), `member_discount` (0.15 snack discount for the social tier), `replay_fee`, and `bundle_weekend_cart`.

`price(key, context)` resolves the charge for `minute` (sim seconds within the calendar day, 0–800), `day`, `group_size`, and optional `membership_tier`. Weekend days (Saturday–Sunday) use the weekend green-fee band; weekday arrivals after twilight (day-sim-second 420, late afternoon on the 24-hour face) use the twilight band. The weekend cart bundle sets cart price to zero on weekends and folds the cart base into the weekend green fee; guests treat bundled prices as 8 % better than the sum for balking checks.

`weekday(day)` returns 0 = Monday. `is_weekend(day)` is true on Saturday and Sunday. The header clock shows the weekday abbreviation. Demand in `_reset_arrivals` multiplies by 1.35 on weekends and 0.9 on weekdays, then applies price elasticity from the expected average green fee (≈ 70 % base / 30 % twilight on weekdays, blended with weekend rates):

`elasticity = clamp(1.25 − 0.55 × (avg_fee / reference_fee − 1), 0.3, 1.4)` where `reference_fee = 40 + 12 × grade + 4 × rating_or_satisfaction()`.

Twilight intervals shorten arrival spacing in proportion to `base / twilight`. Each guest rolls `price_tolerance` from skill and budget. At check-in, a guest balks (leaves without playing, `too_expensive` feedback, no ledger entry) when `fee > tolerance × (35 + 90 × perceived_value)` and `perceived_value = rating_or_satisfaction × 0.6 + beauty_factor × 0.2 + course_holes/18 × 0.2`. Snack, range, cart, and lesson purchases use the same tolerance gate.

Event participants pay `event_entry` at check-in (ledger `admissions`). Entry fees above the catalog `attendance_ref` reduce scheduled event arrivals. `pricing_summary()` feeds the Money panel table, suggested hints, balked counter, and revenue-per-visitor stat. Old flat `prices` snapshots migrate on `restore` by wrapping each number as `{"base": value}` and renaming `event` to `event_entry`.

Guests can only buy within their personal budgets. Resort revenue and every expense are appended to `ledger` with day, minute, signed amount, category, description, and resulting balance. Monthly settlement at `_roll_month` charges staff wages, object upkeep, loan interest, and scheduled loan payments, all dated to the settled month. Three consecutive months below zero cash trigger game over in a non-sandbox resort; the presentation layer pauses and returns to the title screen.

The catalog loan IDs are `working_capital`, `equipment_financing`, and `course_expansion`. Catalog `min_grade`, `interest`, `term_days`, and `payment` values are normalized into active loan records. `borrow()` prevents duplicate active products, while `repay()` supports additional principal payments. `recovery` is a one-time fallback available before the third consecutive insolvent settlement; game over is terminal for that resort session.

Grade promotion follows Catalog's cash, building count, playable-hole and publicity requirements, plus a successful qualifying event and either listed progress-tree nodes or the legacy satisfaction and wear thresholds. Grade nodes (`grade_club`, `grade_resort`) name the branch prerequisites shown in the Progress tab.

## Unlock progression

Building, scenery, staff roles, and future facilities unlock through a research tree in `Catalog.unlocks()` rather than resort grade alone. Each node has `id`, `name`, `branch` (`operations` | `course` | `hospitality` | `prestige`), `cost`, `days`, `requires`, optional `milestone`, and `grants`. Grade nodes use `"kind": "grade"` and list branch prerequisites in `nodes`.

- **Available** when every `requires` node is complete, `grade` is met, and any `milestone` is satisfied.
- **Commit** via `commit_project(id)`: charges full cost immediately, runs up to two concurrent projects, completes after `days` daily ticks (`_tick_projects` in `_roll_day`). `cancel_project(id)` on the same day refunds 80%.
- **Completed** node ids live in `sim.unlocked`; active work in `sim.projects`.
- **`can_build(kind)`** is true when `kind` appears in any completed node's `grants`, or when `Catalog.unlock_for(kind)` is empty (base content: clubhouse, restroom, snack kiosk, driving range, grade-1 woodland scenery, paths). Sandbox bypasses locks.
- **Migration**: saves without `unlocked` mark every node with `grade <= sim.grade` and no `milestone` as complete. Starter resorts bootstrap `cart_fleet`, `greenkeeping`, `local_press`, and related nodes so pre-placed content stays buildable.

`grade_requirements()`, `unlocks()`, `project_available()`, `milestone_progress()`, and `can_build(kind)` expose the rules to UI code.

The six event IDs are `open_day`, `charity_scramble`, `beginner_clinic`, `club_championship`, `regional_amateur`, and `invitational`. Only one event can be scheduled per day. Attendance is counted when an event group begins real play, and completed rounds are counted only when those golfers finish the available course. Because rounds now span many calendar days, an event settles when its field finishes playing, when attendance stalls for a fortnight (saturated courses can hold part of the field waiting for weeks), or when a hard course-sized grace period ends; completion is judged against the guests who actually got onto the course. Success, publicity, satisfaction, and scaled event revenue therefore depend on actual attendance and completion rather than a timer-only reward.

## Saving and integration API

The interface fields and methods in `docs/INTERFACES.md` are implemented. Additional polling helpers are:

- `admit_group(size, event_guest=false) -> int`: immediately creates a one-to-four-person group for debugging or scenarios, returning `-1` when admission is impossible.
- `facility_status() -> Array[Dictionary]`
- `active_event() -> Dictionary`
- `unlocks() -> Dictionary`
- `can_build(kind) -> bool`
- `commit_project(node_id) -> String`
- `cancel_project(node_id) -> String`
- `project_available(node_id) -> bool`
- `milestone_progress(node_id) -> Dictionary`
- `reopen() -> bool` (manual arrival closures only; game over is terminal)
- `patron_summary() -> Dictionary`
- `members() -> Array[Dictionary]`
- `guest_patron_line(guest) -> String`

`snapshot()` contains all public collections, all monotonic ID counters, active queues and occupancy, facility state, accounting accumulators, event state, closure state, the event log (`log`, `_next_log_id`, `last_seen_log_id`), and both RNG seed and RNG stream state. Call `setup()` on a new simulation with its terrain, then `restore(snapshot)`. Identical later ticks produce identical arrivals, shots, and financial results.

## Event log

`post(severity, category, text, pos, target)` appends a structured record to `log` (capped at 500 entries). Identical `category + text` on the same day collapse via `count`. `notice` remains the latest `warning` or higher message for backward compatibility. `unread_count(severity_at_least)` counts entries newer than `last_seen_log_id`.

Each record contains:

```gdscript
{"id": int, "day": int, "minute": float, "severity": "info"|"success"|"warning"|"critical",
 "category": "finance"|"guest"|"staff"|"facility"|"course"|"event"|"construction"|"system",
 "text": String, "pos": Vector3 (optional), "target": {"kind": "hole"|"object"|"guest"|"staff"|"tab", "id": int} (optional),
 "count": int}
```

The UI polls the log on its 0.5 s refresh, shows a toast stack, and exposes a filterable history in the Resort (Saves) panel.

## Daily history and intraday series

At `_roll_month`, the simulation appends one dictionary to `history` (capped at 365 entries — one per settled month). Revenue and expense categories are accumulated live in `_today_by_category` during `_record()` instead of re-scanning `ledger`. `daily_report()` in the UI reads `history`, which keeps finance refreshes O(months) instead of O(ledger).

Each monthly record contains:

```gdscript
{"day", "date", "season", "weekday", "cash_open", "cash_close", "revenue": {category: amount}, "expenses": {category: amount},
 "arrivals", "groups", "completed_rounds", "completion_rate", "refunds", "average_spend",
 "satisfaction", "average_mood", "rating", "publicity", "grade", "wear",
 "average_wait_tee", "max_tee_queue", "average_wait_checkin",
 "facility_visits": {kind: count}, "facility_revenue": {kind: amount},
 "staff_count", "wages", "holes_open", "event": {id, name, status} or {},
 "hole_stats": {hole_id: {"rounds", "average_strokes", "hazards", "average_minutes"}},
 "peak_guests", "peak_queue_minute", "net"}
```

`today_series` is a ring buffer sampled every ~27 simulated seconds (up to 30 points per calendar day) with `{t, guests_on_site, cash, tee_queue_total, facility_queue_total}`. It clears at each day roll.

Wait-time sampling happens in `_apply_wait_mood()` for tee and check-in queues. Tee-queue grace uses each hole's cached `pace_minutes` × 60 (clamped 120–1200 s) so slow holes tolerate longer waits before mood drops. Per-hole stats are gathered in `_complete_hole()` and reset daily. `records` tracks resort bests (revenue, rounds, positive streak, course record round, largest refund day). CSV export writes `user://exports/<save>_history.csv` with flattened category columns.

## Hole design metrics

`ShotEngine.metrics(terrain, hole, count = 30, seed = 42)` returns a per-hole report card built on `analyze()` plus per-shot fields (`landing_surface`, `intended_target_distance`, `layup`, `plan`, `contested`). `ShotEngine.course_metrics(terrain, holes)` rolls those up into rating, slope, routing, rhythm, signature hole, and `design_score` (0..100).

| Metric | Definition | Target band |
|---|---|---|
| `difficulty` | Intermediate average − par | −0.3 .. +0.8 |
| `spread` | Expert average − beginner average | 1.0 .. 2.2 |
| `hazard_rate` | Hazards per round (intermediate) | 0.1 .. 0.6 |
| `blowup_rate` | Share of rounds ≥ par + 4 | < 0.12 |
| `fairness` | 1 − share of penalties landing within 10 m of target | > 0.75 |
| `variety` | Distinct clubs used / 8 | > 0.4 |
| `decision` | Share of contested par 4/5 tee shots that take a conservative line (layup / safe side). If intermediates still attack, a beginner-vs-expert plan split still scores in-band. | 0.2 .. 0.7 |
| `pace_minutes` | Mean four-ball minutes (walk + turns) | par 3 ≤ 11, par 4 ≤ 14, par 5 ≤ 17 |
| `green_receptiveness` | Share of approach shots holding the green | > 0.5 |
| `scenery` | `beauty_at` averaged over tee, landing zones, green | shown, no band |
| `fun` | Weighted mix of variety, decision, fairness, spread-in-band, blow-up penalty | ≥ 0.6 |

Each metric is `{value, band: "low"|"ok"|"high", note: String}`. Values cache in `sim.hole_metrics[hole_id]` keyed by `terrain.revision`; `_roll_day()` refreshes stale entries. Grade promotion adds `design_score` ≥ 45 (Club) and ≥ 65 (Resort) when metrics exist (sandbox bypasses). `club_championship` requires slope ≥ 105; `beginner_clinic` requires a hole with difficulty ≤ 0. A qualifying `signature_hole` adds +3 awareness per day; `design_score` blends into the Course sub-score of `rating_breakdown()`.

## Guest feedback and reviews

Each guest carries `thought` (display string), `mood`, and a capped `feedback` log of `{tag, delta, minute}` entries. `_feedback(guest, tag, delta, text)` sets the thought, appends the tag, and applies the mood delta once.

| Tag | Typical trigger |
|---|---|
| `wait_tee` | Tee queue past grace period |
| `wait_checkin` | Check-in queue past grace period |
| `wait_facility` | Facility queue past grace period |
| `served_snack` | Snack kiosk visit |
| `served_range` | Driving range visit |
| `served_restroom` | Restroom visit |
| `unmet_hunger` | Hunger above 0.8 with no snack kiosk |
| `unmet_restroom` | Restroom need above 0.8 with no restroom |
| `hazard` | Hazard shot |
| `great_hole` | Holed under par |
| `refund_closure` | Refund after inaccessible route |
| `refund_construction` | Refund after construction interruption |
| `dirty_facility` | Low cleanliness at facility use |
| `broken_facility` | Low condition at facility use |
| `too_expensive` | Green fee or facility price rejected at check-in or purchase |
| `bland_scenery` | Tee beauty below 15 |
| `lovely_scenery` | Tee beauty above 60 |
| `completed_round` | Full course completed at departure |

At `_finish_departure`, each guest produces one review stored in `reviews` (cap 400):

```gdscript
{"day", "guest_name", "guest_id", "skill", "mood", "spent", "strokes_total", "holes_played", "tags": {tag: count}, "headline": String}
```

Tag counts also accumulate in `daily_feedback[day] = {tag: count}` for O(days) trend queries. `feedback_summary(days, end_day)` returns `top_complaints`, `top_praise`, `average_mood`, `refund_rate`, `completion_rate`, `average_spend`, and `by_skill` mood averages. Human labels live in the `FEEDBACK_TEXT` constant.

Run the standalone validation with:

```sh
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/test_simulation.gd
```
