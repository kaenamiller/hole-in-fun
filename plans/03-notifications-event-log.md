# Notifications and event log

## Goal

Replace the single `sim.notice` string with a structured, persistent event log that the UI shows as a toast stream plus a scrollable history, with severity, category, and an optional world position the player can jump to.

## Current state

- `ResortSimulation.notice` is overwritten by many code paths (`_end_day`, `_update_grade`, `_reset_arrivals`, `schedule_event`, insolvency).
- `main.gd::_process` polls `notice` every 0.5 s and calls `notify`, which writes `ui.status_label`. Two notices inside one 0.5 s window lose the first.
- Construction results and save results also go through `notify` directly.

## Design

### Log record

```gdscript
{"id": int, "day": int, "minute": float, "severity": "info"|"success"|"warning"|"critical",
 "category": "finance"|"guest"|"staff"|"facility"|"course"|"event"|"construction"|"system",
 "text": String, "pos": Vector3 (optional), "target": {"kind": "hole"|"object"|"guest"|"staff"|"tab", "id": int} (optional),
 "count": int}
```

Add to the simulation:

- `var log: Array[Dictionary]` capped at 500; `var _next_log_id`.
- `func post(severity, category, text, pos = Vector3.INF, target = {}) -> void`. If the last entry within the same day has identical `category + text`, increment its `count` instead of appending (collapses "Guest refunded" spam).
- Keep `notice` as a derived string of the latest `warning` or higher for backward compatibility with tests; `post` sets it.
- `func unread_count(severity_at_least) -> int` via a `last_seen_log_id` field the UI advances.

### Sources to convert

| Situation | Severity | Target |
|---|---|---|
| Day summary net (`_end_day`) | info | Money tab |
| Grade promotion (`_update_grade`) | success | Events tab |
| Event started / result (`_reset_arrivals`, `_settle_events`) | info / success or warning | event |
| Insolvent day, closure, reopen | critical | Money tab |
| Missed loan payment (`_settle_loans`) | warning | Money tab |
| Facility condition or cleanliness below 0.3 (`_tick_facility_decay`, once per facility per day) | warning | object, pos |
| Facility unusable | critical | object |
| Group refunded (`_safe_refund_and_depart`) | warning, collapsed | pos |
| Hole became invalid after edit (`_refresh_course` diff) | warning | hole |
| Cart barn at capacity for > 10 min | info | object |
| Tee queue longer than 3 groups for > 15 min | warning | hole |
| Staff hired / fired | info | staff |
| Construction rejected in `main.gd::_commit` | warning | tab Money |
| Save / load results | info | Saves tab |

`main.gd::notify` becomes a thin wrapper calling `sim.post("info", "system", text)`, so all messages flow through one place.

### UI

- **Toast stack**: bottom-left `VBoxContainer` of up to four toasts, newest at the bottom, each with a severity colour stripe, text, and count badge. Toasts live 6 s (critical: 12 s, and persist until clicked). Clicking a toast performs its jump.
- **Bell button** in the header showing unread warning-or-higher count. Opens the **Log** section in the Saves panel (renamed "Resort"): filter chips per category and severity, entries listed newest first with day and clock, click to jump.
- **Jump**: `main.gd::jump_to(entry)` sets `camera.focus = pos` where present, then `select_hole`, `select_guest`, `select_staff`, or selects the object and opens Build, or `ui.show_tab`.
- **Pause on critical** toggle (default off) in settings: sets `speed = 0` when a critical entry posts.

## Files

- `scripts/resort_simulation.gd`: `log`, `post`, conversions, snapshot/restore (`log`, `_next_log_id`, `last_seen_log_id`).
- `scripts/main.gd`: `notify` wrapper, toast polling (compare `log.back().id` with the last shown id), `jump_to`, pause-on-critical.
- `scripts/resort_ui.gd`: toast container, bell, log view with filters.
- `docs/SIMULATION.md`: log record schema.

## Tests

- `tests/test_simulation.gd`: run a day → log contains a `daily_summary`; force insolvency for 3 days → exactly one `critical` closure entry; 20 identical refunds in a day collapse to one entry with `count == 20`; log never exceeds 500.
- `tests/test_regressions.gd`: existing tests that read `sim.notice` still pass; snapshot/restore preserves `log`.
- `tests/test_game.gd`: post entries of each severity and confirm toast children count ≤ 4; `jump_to` for a hole target moves `camera.focus`.

## Phases

1. `post` and log storage with `notice` compatibility; convert simulation call sites.
2. Toasts and `notify` wrapper.
3. Log view with filters and jump.
4. Queue and facility watchdogs (the rate-limited warnings).

## Risks

- Rate limiting: watchdog warnings need a per-target "last warned day" dictionary to avoid re-posting every second.
- The `pos` field must survive `duplicate(true)` in `snapshot`; `Vector3.INF` serialises fine but compare with `is_finite()` in the UI.
