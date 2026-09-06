# Statistics and history

## Goal

Record daily and intraday time series for the numbers the resort already produces (cash, arrivals, rounds, satisfaction, wear, waits, facility use, revenue by category) and present them as charts and tables so players can see trends and connect actions to outcomes. This plan also introduces the sampling infrastructure that the analytics overlays reuse.

## Current state

- `ledger` holds every transaction; `daily_report()` in the UI re-aggregates it each refresh by scanning the whole array.
- `completed_visits`, `satisfaction`, `publicity`, `grade`, and `terrain.wear` are current values only; history is lost.
- Event results live in `event_history`.

## Design

### Daily record

At `_end_day`, before resetting counters, append to `sim.history: Array[Dictionary]` (cap 365):

```gdscript
{"day", "weekday", "cash_open", "cash_close", "revenue": {category: amount}, "expenses": {category: amount},
 "arrivals", "groups", "completed_rounds", "completion_rate", "refunds", "average_spend",
 "satisfaction", "average_mood", "rating", "publicity", "grade", "wear",
 "average_wait_tee", "max_tee_queue", "average_wait_checkin",
 "facility_visits": {kind: count}, "facility_revenue": {kind: amount},
 "staff_count", "wages", "holes_open", "event": {id, name, status} or {},
 "hole_stats": {hole_id: {"rounds", "average_strokes", "hazards", "average_minutes"}}}
```

Revenue and expense by category are accumulated live in `_record` into `_today_by_category` (a dictionary) instead of re-scanning the ledger, and `daily_report()` switches to reading `history`. This also fixes the O(ledger) UI refresh.

Per-hole stats are gathered in `_complete_hole` (strokes and elapsed minutes per group) and reset daily. Wait times are gathered in `_apply_wait_mood` per state.

### Intraday series

A lightweight ring buffer `sim.today_series` sampled every 10 simulated minutes (60 points per day): `{minute, guests_on_site, cash, tee_queue_total, facility_queue_total}`. Cleared at `_end_day` after being summarised into the daily record (`peak_guests`, `peak_queue_minute`).

### Charts

Add `scripts/ui/chart.gd` (`class_name SimpleChart extends Control`): a `_draw()`-based line/bar chart with axes, up to four series, hover tooltip via `_gui_input`, and a legend. No plugins. Colours from the existing UI palette (INK, ACCENT, plus two muted greens). Keep the same palette in light and dark backgrounds. Range picker: 7 / 30 / all days.

### Statistics tab

New tab (icon `∿`, header "THE RECORD") with sections:

1. **Money**: cash close line; stacked revenue by category bars; expenses by category; net per day. Loan balance line when loans exist.
2. **Guests**: arrivals vs completed rounds; completion rate; satisfaction and rating; average spend; refunds.
3. **Operations**: average tee wait and max queue; wear; staff count vs wages; facility visits table sorted by revenue.
4. **Course**: per-hole table with rounds, average strokes vs par, hazards, minutes; sortable by column; click a row to `select_hole`.
5. **Today**: intraday guests-on-site and queue lines with the current minute marker.
6. **Records**: best day revenue, most rounds, longest streak of positive days, course record round (name, day, strokes), largest single refund day.

The Money panel keeps its compact daily report but adds a "Open statistics" button.

### Exports

"Export CSV" writes `user://exports/<save>_history.csv` with one row per day and flattened category columns, so players can analyse offline. Also useful for balancing during development.

## Files

- `scripts/resort_simulation.gd`: `history`, `today_series`, `_today_by_category`, per-hole and wait accumulators, `records`, snapshot/restore (history is the largest new save payload: 365 × ~2 KB is fine).
- New: `scripts/ui/chart.gd`.
- `scripts/resort_ui.gd`: Statistics tab, `daily_report()` rewrite, export button.
- `scripts/main.gd`: tab callback, `select_hole` from table row.
- `docs/SIMULATION.md`: record schema.

## Tests

- `tests/test_simulation.gd`: after three starter days `history.size() == 3`; revenue category sums equal the ledger's positive amounts for that day; `completion_rate` in 0..1; per-hole stats include every played hole; `today_series` has ≤ 60 points and clears at day end; cap at 365 holds after simulating 400 days with a fast path (skip guests by closing the resort).
- `tests/test_regressions.gd`: `daily_report()` output for the two-day scenario matches the previous ledger-derived numbers within rounding; snapshot/restore preserves history and records.
- `tests/test_game.gd`: Statistics tab renders each section with zero and with three days of data; chart `_draw` runs without errors at 300 × 120 px; CSV export creates a file in the isolated save directory.

## Phases

1. Daily record, category accumulators, `daily_report()` rewrite, tests.
2. Chart control and Money/Guests sections.
3. Operations, Course, Today, Records, CSV export.

## Dependencies

- None to start. The analytics overlays plan reuses the wait sampling introduced here. Marketing's `rating` and memberships' counts are added to the record when those plans land.
