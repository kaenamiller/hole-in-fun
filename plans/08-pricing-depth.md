# Pricing depth

## Goal

Turn the five flat prices into a pricing system with time-of-day bands, weekday and weekend calendars, group and member rates, event entry fees, and a visible price-elasticity model so pricing becomes an ongoing decision rather than a one-time slider.

## Current state

- `prices` = `{green_fee, cart, range, snack, event}`; edited directly by SpinBoxes in `_money_panel`.
- Demand uses only `green_fee` in `_reset_arrivals`: `1.12 − (fee − 48)/130`.
- Guests reject a fee only if `budget < due` in `_collect_green_fees`; there is no per-guest price sensitivity.
- No weekday concept; `day` is a counter.

## Design

### Calendar

Add `weekday(day) -> int` (0 = Monday) and `is_weekend(day)`. Weekend base demand ×1.35, weekday ×0.9, so the weekly average stays near today's. Show the weekday in the header clock.

### Price book

Replace flat `prices` with a `PriceBook` structure kept in `sim.prices` for compatibility but with nested rules:

```gdscript
prices = {
  "green_fee": {"base": 48.0, "twilight": 32.0, "weekend": 58.0, "twilight_start_minute": 420},
  "cart": {"base": 22.0}, "range": {"base": 12.0}, "snack": {"base": 9.0}, "lesson": {"base": 35.0},
  "event_entry": {"base": 18.0},
  "group_discount": 0.10,   # groups of 4
  "member_discount": 0.15,  # social tier; player/founder include fees
  "replay_fee": 24.0        # second round same day (memberships plan)
}
```

Provide `price(key, context: Dictionary) -> float` that resolves the applicable value given `minute`, `day`, group size, and membership tier. All existing `prices.get("green_fee", …)` reads migrate to `price("green_fee", {...})`. `restore` accepts the old flat dictionary and wraps each number as `{"base": value}`.

### Guest price sensitivity

Each guest gains `price_tolerance: float` rolled from skill and budget: experts and high budgets tolerate more. In `_collect_green_fees`, before the budget check, compute `perceived_value = rating_or_satisfaction × 0.6 + beauty_factor × 0.2 + course_holes/18 × 0.2`. A guest balks (`too_expensive` feedback, group leaves without playing, no refund needed) if `fee > tolerance × (35 + 90 × perceived_value)`. Balking is visible so players can see prices are too high, instead of demand silently shrinking the next morning.

### Demand elasticity

`_reset_arrivals` uses the expected average fee for the coming day (weighted by twilight share ≈ 30 %) and a smooth elasticity curve `clamp(1.25 − 0.55 × (avg_fee / reference_fee − 1), 0.3, 1.4)` where `reference_fee = 40 + 12 × grade + 4 × rating`. Twilight pricing fills late tee times: arrivals after `twilight_start_minute` scale with the twilight discount.

### Secondary spend

- Snack, range, cart, and lesson purchases check `budget` and `price_tolerance` similarly; a rejected purchase adds `too_expensive` feedback and skips the facility.
- Add a `bundle` toggle: "Cart included with weekend fee" that sets cart price to 0 on weekends and raises the fee; guests perceive bundles 8 % better than the sum.

### Event fees

`prices.event_entry` is charged to event participants at check-in (`_collect_green_fees` when `group.event`), replacing the flat `event` price. Entry fee raises event revenue but lowers attendance ratio when above `attendance_ref` from Catalog.

### UI

Money panel pricing section becomes a table with columns Base / Twilight / Weekend for green fee, single columns for others, discount sliders, bundle toggle, and a "Suggested" hint per row computed from `rating` and `grade` (a heuristic, shown greyed). A small "Balked today: N guests" counter and the revenue-per-visitor stat sit above the table.

## Files

- `scripts/resort_simulation.gd`: `weekday`, `price`, price-book migration, tolerance, balking, elasticity, twilight arrivals, event entry, `pricing_summary()` for UI.
- `scripts/resort_ui.gd`: table, header weekday.
- `docs/SIMULATION.md`: pricing formulas.

## Tests

- `tests/test_simulation.gd`: `price("green_fee", {minute: 450})` returns twilight; weekend arrivals exceed weekday arrivals on identical state; fee at 200 causes balks and ledger records no green fee for those groups; fee at 20 raises arrivals and lowers average spend; old flat `prices` restore correctly.
- `tests/test_regressions.gd`: the two-day starter event scenario still produces a success with default prices; ledger reconciliation includes event entry fees.
- `tests/test_game.gd`: price table edits write through to the book.

## Phases

1. Price book with `price()` and migration; behaviour identical at defaults.
2. Weekday calendar, twilight, weekend, elasticity.
3. Tolerance and balking, feedback tag.
4. Bundles, event entry fee, suggested prices.

## Dependencies

- Balking and suggested prices read `rating` from the marketing plan when present, otherwise `satisfaction`.
- Member discounts activate with the memberships plan.
