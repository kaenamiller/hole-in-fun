# Continuous calendar, seasons, and monthly settlement

Implemented 2026-09. This supersedes the 600-minute operating-day model described in the original MVP notes and changes assumptions in plans 01, 02, 04, 05, 06, 07, 08, 09, 10, and 13 (see "Impact on other plans" below).

## Model

- **Play is continuous.** There is no operating window and no closing-time eviction. The course never closes during active play; visits resolve on their own. Three consecutive insolvent months end a non-sandbox game and return to the title screen.
- **One calendar day = 800 simulated seconds** (`DAY_SIM_SECONDS`), i.e. ≈ 13.3 real seconds at 1x, so a 90-day quarter lasts about 20 real minutes. Every month has 30 days; day 1 is March 1 of Year 1.
- **Two time scales, one speed control.** The calendar advances in calendar-seconds while golfers, staff, facilities, waits, and ball physics advance in actor-seconds (`actor_dt = calendar_dt / SIM_RATE`). The 1x/2x/4x controls accelerate both. A full 18-hole round is targeted at ~15–16 real minutes at 1x, roughly 68–72 calendar days (2.25–2.4 months).
- **Seasons:** Mar–May Spring, Jun–Aug Summer, Sep–Nov Fall, Dec–Feb Winter. Seasonal demand multipliers `[1.05, 1.2, 0.95, 0.7]` and weather `rain / clear / leaves / snow`.
- **Roll-overs:** `_roll_day` (daily: events, decay, staff, projects), `_roll_month` (wages, upkeep, loans, monthly history, insolvency at 3 consecutive negative months — settlement ledger entries are dated to the settled month), `_roll_season` (grade assessment).
- **No day/night cycle.** The environment was already static; the status bar shows date, season, and a 24-hour clock face anchored at 6:00 a.m.

## Pace

`SIM_RATE = 60` is the ratio of calendar-seconds to actor-seconds. Physical durations are authored in actor-seconds; movement uses real-world m/s × `BASE_PACE = 1.6`, and `SHOT_PACE = 1.5` stretches flight time. The 1x/2x/4x buttons scale both clocks linearly.

## Economy

- Catalog wages ×3 and upkeep ×2 of their old daily values, charged **monthly**. Loan interest and payments apply **monthly** (`term_days` is the term in months). Membership dues settle every 30 days.
- Demand begins with course throughput at 78% utilization, then applies awareness, rating, marketing, facilities, scenery, wear, season, weekend, and price elasticity. Fractional carry produces appropriately spaced arrivals even when capacity is below one golfer per calendar day.
- Guest cap raised to `MAX_GUESTS = 200`; `arrivals_enabled` suspends walk-ins without touching golfers on the course.

## Seasons visuals

`main.gd::_apply_season()` swaps sky/ambient palettes, tints the ground shader (`season_tint`) and shared foliage materials (winter = snow-dusted), and runs per-season weather particles (spring rain, summer clear, fall leaves, winter snow) that track the camera focus.

## Events

Events span their catalog windows and settle when the field finishes or after deadlines derived from target actor-time round length, calendar conversion, playable-hole capacity, and expected field waves. Completion is judged against actual attendance.

## Impact on other plans

- **01 analytics:** layer decay remains calendar-based but uses long retention (0.98–0.995/day) so multi-month rounds remain visible.
- **02 feedback:** `refund_closing_time` no longer occurs (no evictions); feedback aggregates at departure, which now happens mid-"month".
- **04 per-hole maintenance:** overnight decay/recovery still runs daily via `_roll_day`; "irrigation halves overnight decay" (09) unchanged.
- **05 memberships:** dues settle monthly (`day % 30 == joined_day % 30`); patron creation at departure unchanged.
- **06 marketing:** campaigns charge/apply daily; awareness decays daily; press congestion moments key off monthly arrival/completion ratios.
- **07 staff depth:** all schedules use staggered 20-minute actor-time duty cycles (15 minutes on, 5 off), independent of the compressed calendar; wages remain monthly.
- **08 pricing:** twilight bands use day-sim-seconds; weekday/weekend uses `weekday()`; `twilight_start_minute` semantics changed.
- **09 unlocks:** projects still tick daily in `_roll_day`; grading moved to `_roll_season`.
- **10 facilities:** the lodge is purely ancillary room revenue. The stay is charged at departure and never pauses, refreshes, or re-queues golfers.
- **13 statistics:** history holds one record per settled month; `today_series` samples ~27 sim-seconds apart (30 buckets/day); autosave on month rollover.

## Open items

1. **test_shots (8 failures):** decision/metrics behavioral tuning — difficulty bands on short par 4s, water-guard EV splits, aim-near-pin, `pace_minutes` on the FakeTerrain double, lag putts. Mechanical fixes landed: green-ownership fallback for offline hole dicts, OB boundary spans (past-line anywhere in the stake span, not within 8 m), PNPOLY denominator, paint order in tests.
2. **test_simulation (4 failures):** analytics-landings spread across holes, groundskeeper hole-recovery assertion, third-concurrent-project rejection, balk counter. Systems function; the contract checks need final alignment.
3. **Verify at scale:** full-round real-time pacing (~15–16 real minutes estimated, not measured), congestion behavior when a small course saturates the 200-guest cap (tee waits stretch to weeks; congestion press tanks buzz), starter-economy margins (~break-even estimate).
4. **Balance candidates:** analytics retention across multi-month rounds; target course utilization; and the measured round-duration constant after playtesting.
5. **Nice-to-have:** marshal/tee priority for event groups on saturated courses; needs pacing for guests whose rounds span 40+ calendar days (hunger/restroom repeat visits mid-round).

## Test runner

`./tools/test.sh` runs every suite. `SIM_TEST_ONLY=<name[,name2]>` (tests/test_simulation.gd) runs selected simulation tests with per-test timing; each individual test completes in under two minutes.
