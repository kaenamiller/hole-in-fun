# Marketing and reputation

## Goal

Turn `publicity` from an event by-product into a managed system: spendable marketing campaigns, a public course rating driven by guest reviews, word of mouth, and press moments. Reputation decays without care and responds to real guest experience.

## Current state

- `publicity` rises only on successful events (`_settle_events`) and falls by 2 on failures. It feeds `_reset_arrivals` (`base += publicity * 0.7`) and grade requirements.
- No advertising, no rating, no decay.

## Design

### Reputation model

Replace the single `publicity` with three visible numbers, keeping `publicity` as the derived value used by existing grade checks so nothing breaks:

- **Awareness** (0..100): how many people know the resort exists. Raised by campaigns and events, decays 1.5 % per day.
- **Rating** (1.0..5.0): rolling weighted mean of departing guests' mood mapped to stars (`1 + mood × 4`), with a 14-day half-life. Seeded at 3.0. Refund departures count as 1 star.
- **Buzz** (−20..+20): short-lived word-of-mouth from the last 3 days' `feedback_summary` (praise minus complaint share × 40) and press moments; decays 40 % per day.

`publicity = awareness × (0.4 + 0.15 × rating) + buzz`, clamped 0..100.

Demand: `_reset_arrivals` uses `awareness` for reach and `rating` for conversion: `base = (30 + awareness × 0.9) × (0.55 + rating × 0.14) × factors…`. Tune so the starter resort's day-one arrivals stay in the current 54..70 band.

### Campaigns

`Catalog.campaigns()`:

| ID | Name | Cost per day | Duration | Effect | Min grade |
|---|---|---|---|---|---|
| `local_flyers` | Local Flyers | 220 | 7 | awareness +1.2/day, mostly beginners | 1 |
| `radio_spot` | Radio Spot | 650 | 5 | awareness +2.5/day | 1 |
| `golf_magazine` | Golf Magazine Feature | 1,800 | 3 | awareness +4/day, +25 % expert arrivals, requires rating ≥ 3.5 | 2 |
| `social_video` | Course Flyover Video | 900 | 4 | buzz +6 once, awareness +1.5/day | 2 |
| `pro_visit` | Touring Pro Visit | 6,000 | 1 | buzz +12, one expert group with skill 0.97, press moment | 3 |
| `loyalty_mailer` | Member Mailer | 300 | 1 | member booking chance +50 % for 3 days | 2 |

Only two campaigns run concurrently. `start_campaign(id) -> String` charges the first day and appends to `sim.campaigns`; `_end_day` charges the next day, applies effects, and retires finished campaigns with a log entry. Campaigns influence guest skill mix by shifting the `randfn(0.53, 0.19)` centre in `_create_group` via a `_skill_bias` value.

### Press moments

Log-driven reputation shocks generated in `_end_day` from real outcomes:

- Course record (any golfer finishes 18 holes at ≤ par − 6): buzz +5.
- A day with completion rate < 40 % and more than 20 guests: buzz −6, "congestion" story.
- Facility unusable for a full day: buzz −4.
- Grade promotion: awareness +10.
- Event success/underperformance replaces the flat ±publicity with awareness +4..+12 and buzz ±5.

### Rating breakdown

`rating_breakdown() -> Dictionary` returning stars plus sub-scores derived from feedback tags: Course, Facilities, Service, Value, Scenery. Each sub-score is 5 minus penalty share × 4 for its tag family. Value uses `too_expensive` and average spend against budget.

### UI

New **Marketing** tab (ninth nav button, icon `◎`, header "THE WORD"):

- Reputation card: stars with sub-scores, awareness bar, buzz indicator with today's press headlines.
- Campaign list with cost, days remaining, start/stop buttons, and the two-slot limit.
- Reach forecast: "Expected visitors tomorrow: 62–78" from the demand formula ± 12 %.

Header bar: replace the grade stat's caption with `GRADE · ★ 3.8`.

## Files

- `scripts/catalog.gd`: `campaigns()`.
- `scripts/resort_simulation.gd`: `awareness`, `rating`, `buzz`, `campaigns`, `start_campaign`, `stop_campaign`, `rating_breakdown`, `forecast_arrivals`, `_skill_bias`, revised `_reset_arrivals` and `_settle_events`, press moments, snapshot/restore (default `awareness = publicity`, `rating = 3.0` for old saves).
- `scripts/resort_ui.gd`: Marketing tab, header stars.
- `scripts/main.gd`: none beyond tab callback.
- `docs/SIMULATION.md`: reputation formulas.

## Tests

- `tests/test_simulation.gd`: starter day-one arrivals within 54..70; `local_flyers` for 7 days raises awareness by ≈ 8 and charges 7 × 220; forcing all departures to refund drives rating below 2 within 5 days and lowers next-day demand; two campaigns running → third `start_campaign` returns an error string; expert share rises during `golf_magazine`.
- `tests/test_regressions.gd`: grade promotion thresholds on `publicity` still reachable in the two-day event scenario; snapshot/restore preserves campaigns and rolling rating state; ledger reconciles with campaign charges.
- `tests/test_game.gd`: Marketing tab renders and its callbacks run.

## Phases

1. Awareness/rating/buzz with derived `publicity`; demand rewired; tests hold the current balance.
2. Campaigns and UI.
3. Press moments and rating breakdown.

## Dependencies

- Guest feedback aggregation supplies the tags for buzz and sub-scores.
- Notifications plan carries press headlines.
- Membership plan's `loyalty_mailer` hook is a no-op until memberships exist.
