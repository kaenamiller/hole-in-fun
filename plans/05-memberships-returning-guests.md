# Memberships and returning guests

## Goal

Give guests a memory of the resort so satisfaction has long-term consequences: visitors can return, join as members, pay recurring dues, and bring reputation with them. Members form a stable revenue base that rewards consistency and punishes neglect.

## Current state

- Every guest is created fresh in `_create_group` with random skill, budget, and mood, and is erased by `_cleanup_departed`.
- Demand is recomputed each morning in `_reset_arrivals` from grade, publicity, and `demand_factors()`.
- Events reference "returning members" in flavour text only.

## Design

### Persistent patrons

Add `sim.patrons: Dictionary` keyed by `patron_id` (monotonic, separate from guest ids):

```gdscript
{"id", "name", "skill", "budget_base", "visits", "last_day", "affinity": float (0..1), "member": bool,
 "tier": "", "joined_day", "dues_paid_through", "handicap": float, "favourite_hole_id", "history": Array[{day, mood, spent}] (cap 10)}
```

Cap at 600 patrons; when full, drop the lowest-affinity non-member with the oldest `last_day`.

### Arrival mix

In `_spawn_due_arrivals`, when a group is created decide per guest:

1. **Returning patron** with probability `0.15 + 0.5 * satisfaction` (clamped 0.2..0.65) if any eligible patrons exist. Choose with weighted random on `affinity` and days since `last_day`. Copy `skill` (with +0.005 per visit growth, cap 0.97), `budget_base` scaled by mood history, and set `guest.patron_id`.
2. **Member** groups: members arrive independently of the demand target. Each morning every member has a chance `0.35 * affinity` to book; booked members are appended to the arrival schedule ahead of walk-ins and skip the green fee if their tier includes it.
3. Otherwise a **new visitor**, who becomes a patron on departure if mood ≥ 0.55.

### Affinity update

In `_finish_departure` (per guest with `patron_id`): `affinity = lerp(affinity, mood, 0.4)`, `visits += 1`, push history. Guests who left via `_safe_refund_and_depart` take an extra −0.15. Patrons with `affinity < 0.2` and no visit in 20 days are removed ("lost customer" log entry, collapsed).

### Membership tiers

Catalog addition `Catalog.memberships()`:

| ID | Name | Dues per 30 days | Includes | Min grade | Perks |
|---|---|---|---|---|---|
| `social` | Social | 180 | 10 % off snacks | 1 | may book |
| `player` | Player | 520 | green fees | 2 | priority tee (queue jump one place) |
| `founder` | Founder | 1,400 | green fees + cart + range | 3 | invited to `club_championship` automatically |

Offer logic: on departure, a non-member patron with `visits >= 3`, `affinity >= 0.7`, and `budget_base >= 2 × dues/30` joins the best tier they can afford with probability `0.5 × affinity`. Members pay dues on `day % 30 == joined_day % 30` via `credit(dues, "membership", …)`. Members cancel when `affinity < 0.35` for two consecutive visits or when dues exceed 45 % of their `budget_base × 30`.

Membership cap per tier scales with clubhouse capacity: `capacity × 4` for social, `× 2` player, `× 0.5` founder, so the clubhouse upgrade (facilities plan) matters.

### Player controls

New **Members** section in the Money panel:

- Dues per tier (SpinBox) and an open/closed toggle per tier.
- Current counts, monthly dues income, churn last 30 days.
- A "Member day" toggle per calendar day (via events plan later) that restricts walk-ins and boosts member affinity.

Members and returning patrons are visible in the guest inspector ("Visit 7 · Player member · Handicap 14.2").

### Handicap

Compute a simple handicap from the last 5 completed scorecards versus par: `mean(strokes - par) × 1.1`. Used by the metrics plan and displayed only.

## Files

- `scripts/catalog.gd`: `memberships()`, `find` support.
- `scripts/resort_simulation.gd`: `patrons`, `members`, arrival mix, affinity, dues settlement in `_end_day`, cap enforcement, snapshot/restore, `patron_summary()` for UI.
- `scripts/resort_ui.gd`: Members section, inspector lines.
- `docs/SIMULATION.md`: patron lifecycle.

## Tests

- `tests/test_simulation.gd`: after 5 starter days some guests carry `patron_id`; a patron's `visits` increases; forcing `satisfaction = 0.95` and running 10 days yields at least one member and dues income in the ledger with category `membership`; forcing repeated refunds drops affinity and removes patrons; patrons never exceed 600.
- `tests/test_regressions.gd`: snapshot/restore preserves patrons and dues schedule; a save without `patrons` loads with an empty dictionary; ledger reconciliation still balances with dues.

## Phases

1. Patrons and returning arrivals (no membership). Affinity loop and cap.
2. Membership tiers, dues, joining and cancelling, UI counts.
3. Perks (queue priority, event auto-invite), handicap, dues controls.

## Dependencies

- Uses `_feedback` tags from the guest feedback plan for join/cancel reasons.
- Pricing plan's demand pipeline should treat member bookings as a separate additive channel, not part of `_arrival_target`.
