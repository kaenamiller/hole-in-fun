# Guest feedback aggregation

## Goal

Roll individual guest state (`thought`, `mood`, needs, refunds, wait time, scorecards) into daily aggregate feedback so the player learns *why* satisfaction moved. Deliver a "Reviews" section in the Guests panel and a structured record the marketing and statistics plans consume.

## Current state

- Each guest carries `thought` (free text set at a dozen call sites), `mood`, `hunger`, `energy`, `restroom`, `budget`, `spent`, `scorecard`, `paid_green_fee`.
- `satisfaction` is a single float nudged in `_finish_departure` by group average mood.
- `_apply_wait_mood` lowers mood while queuing but does not record why.
- Nothing survives `_cleanup_departed` except `completed_visits`.

## Design

### Tagged complaints instead of free text

Introduce a small enum of feedback tags set alongside every `thought` write. Add a helper in the simulation:

```gdscript
func _feedback(guest: Dictionary, tag: String, delta: float, text: String) -> void
```

It sets `guest.thought = text`, appends `{tag, delta, minute}` to `guest.feedback` (capped at 12 entries), and applies `delta` to mood. Convert existing sites:

| Site | Tag |
|---|---|
| `_apply_wait_mood` (tee) | `wait_tee` |
| `_apply_wait_mood` (check-in) | `wait_checkin` |
| `_apply_wait_mood` (facility) | `wait_facility` |
| `_apply_facility_to_guest` | `served_snack`, `served_range`, `served_restroom` |
| hunger or restroom above 0.8 with no facility | `unmet_hunger`, `unmet_restroom` |
| `_shot_thought` hazard | `hazard`; holed under par | `great_hole` |
| `_safe_refund_and_depart` | `refund_closure`, `refund_construction`, `refund_closing_time` |
| low facility condition or cleanliness at use | `dirty_facility`, `broken_facility` |
| price rejected in `_collect_green_fees` | `too_expensive` |
| beauty at tee below 15 | `bland_scenery`; above 60 | `lovely_scenery` |
| completed full course | `completed_round` |

### Departure review

In `_finish_departure`, build a review per guest:

```gdscript
{"day", "guest_name", "skill", "mood", "spent", "strokes_total", "holes_played", "tags": {tag: count}, "headline": String}
```

`headline` is chosen from the dominant negative tag if mood < 0.45, dominant positive tag if mood > 0.7, else neutral. Store in `sim.reviews` (Array, cap 400, oldest dropped). Also accumulate `sim.daily_feedback[day] = {tag: count}` so trend queries are O(days) not O(reviews).

### Satisfaction decomposition

Add `feedback_summary(days: int = 1) -> Dictionary` returning:

- `top_complaints`: sorted array of `{tag, count, share}` for negative tags
- `top_praise`: same for positive tags
- `average_mood`, `refund_rate`, `completion_rate`, `average_spend`
- `by_skill`: mood averages per beginner/intermediate/expert band

Helper text per tag lives in a `FEEDBACK_TEXT` const so the UI prints "Long waits at the tee (31 guests)" rather than the raw tag.

### UI

Guests panel gains a "What guests are saying" section above the selected-guest details: three praise lines, three complaint lines, completion and refund rates for today, and a `Yesterday / 7 days` toggle. Below it, a scrolling list of the last 12 review headlines with name, mood as a five-step word (Delighted … Upset), and spend. Clicking a review with a live guest still on-site selects that guest.

The header bar's satisfaction becomes hoverable: tooltip lists the top complaint.

## Files

- `scripts/resort_simulation.gd`: `_feedback`, `reviews`, `daily_feedback`, `feedback_summary`, snapshot/restore, tag conversion at all listed sites.
- `scripts/resort_ui.gd`: Guests panel sections, tooltip.
- `docs/SIMULATION.md`: tag table.

## Tests

- `tests/test_simulation.gd`: run a day with the clubhouse removed → `top_complaints` includes `wait_checkin` or refunds; run a day with no snack kiosk and forced hunger → `unmet_hunger` dominates; every departed guest produced exactly one review; `reviews.size() <= 400` after 6 stress days.
- `tests/test_regressions.gd`: snapshot/restore preserves `reviews` and `daily_feedback`; `feedback_summary(7)` sums match per-day dictionaries.
- `tests/test_game.gd`: Guests tab renders with zero, one, and many reviews.

## Phases

1. `_feedback` helper and tag conversion (no behaviour change).
2. Reviews, daily aggregation, `feedback_summary`, tests.
3. UI.

## Notes

- Keep `thought` as the display string so the existing guest inspector and tests keep working.
- Feedback tags are the input the marketing plan uses for word-of-mouth and the statistics plan charts over time. Agree on the tag list before either starts.
