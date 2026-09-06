# Staff depth

## Goal

Make the team a real management layer: individual skill and experience, training, morale and fatigue, shifts, a golf-pro role that teaches lessons, and a pro-shop attendant role for the new retail facility. Staff choices should scale with grade.

## Current state

- `Catalog.staff_roles()` has three roles with a flat `wage` and `skill`. `_add_staff` copies them; `hire` charges nothing up front.
- `_tick_staff` walks each worker to a target and applies a rate scaled by `skill`. Wages settle daily in `_settle_wages_and_upkeep`.
- `assignment` is an object id or −1.

## Design

### Worker record

Extend the staff dictionary:

```gdscript
{"skill": float, "experience": float (0..1), "morale": float (0..1), "fatigue": float (0..1),
 "shift": "early"|"late"|"full", "training": {"course": String, "days_left": int} or {},
 "traits": Array[String], "hired_day": int, "wage": float, "raise_requested": bool}
```

Effective skill = `skill × (0.7 + 0.3 × experience) × (0.6 + 0.4 × morale) × (1 − 0.35 × fatigue)`. Replace every `worker_skill` read in `_tick_staff` with `_effective_skill(worker)`.

### Experience, morale, fatigue

- **Experience** grows 0.004 per working day, faster with a `mentor` trait nearby.
- **Fatigue** rises 0.0011 per working minute, resets overnight for `full` shift only if the worker had at least 120 minutes off; `early` (0..330) and `late` (270..600) shifts reset fully. Fatigue above 0.8 halves output and posts a warning.
- **Morale** moves toward a target composed of wage fairness (wage vs. `Catalog` base × (1 + experience)), workload (time spent walking vs. working), facility condition where they work, and resort satisfaction. Morale below 0.3 for 3 days → `raise_requested`; ignored for 5 more days → quits (log critical). Morale above 0.8 gives +10 % output.

### Roles

Add to `Catalog.staff_roles()`:

| ID | Wage | Benefit | Needs | Min grade |
|---|---|---|---|---|
| `golf_pro` | 240 | lessons: raises visiting guest skill +0.06 per lesson and mood +0.08; sells lesson at `prices.lesson` | driving range | 2 |
| `shop_clerk` | 130 | staffs `pro_shop` facility (facilities plan); adds retail revenue | pro shop | 2 |
| `marshal` | 150 | patrols holes; reduces group turn time 12 % and tee-queue mood loss 40 % on assigned holes | none | 2 |
| `head_greenkeeper` | 300 | supervises: +20 % groundskeeper output within 200 m, unlocks fertiliser programme | maintenance shed | 3 |

`golf_pro` behaviour: waits at the range; groups choosing `driving_range` in `_choose_pre_round_facility` take a lesson with probability `0.5` if the pro is present and free, paying `prices.lesson` (default 35). `marshal` uses hole assignment from the per-hole maintenance plan and walks a loop between tee and green.

### Hiring

Replace `hire(role)` with a candidate pool: each morning `sim.candidates` is refilled with 2–4 applicants per unlocked role, each with rolled `skill` (0.45..0.95), traits (`quick_learner`, `mentor`, `night_owl`, `grumpy`, `careful`), and asking wage. `hire(candidate_id)` pays a signing cost of 2 × wage. Firing pays 3 × wage severance and lowers other staff morale 0.05.

### Training

`Catalog.training()`: `turf_school` (groundskeeper, 5 days, 900, skill +0.12), `hospitality` (attendant, 3 days, 600, +0.10), `sanitation` (cleaner, 2 days, 300, +0.08), `pga_clinic` (golf_pro, 7 days, 2,400, +0.15). Training removes the worker from duty for `days_left` days.

### UI

Staff panel rework:

- Team list with role icon, effective skill bar, morale and fatigue chips, shift dropdown, assignment dropdown, train button, fire button.
- Applicants section listing candidates with traits and asking wage; hire button.
- Payroll summary: daily wages, forecast for next 7 days, requested raises with accept buttons (+12 % wage).
- Worker inspector (click in world) shows current task and target.

## Files

- `scripts/catalog.gd`: new roles, `training()`, `traits()`.
- `scripts/resort_simulation.gd`: `_effective_skill`, morale/fatigue/experience ticks in `_tick_staff` and `_end_day`, candidates, `hire(candidate_id)` (keep `hire(role)` as a convenience that picks the first candidate so tests keep working), `train`, `set_shift`, `grant_raise`, golf pro lessons, marshal loop, snapshot/restore.
- `scripts/asset_factory.gd`: role-tinted uniforms for new roles.
- `scripts/resort_ui.gd`: Staff panel.
- `docs/SIMULATION.md`: staff formulas.

## Tests

- `tests/test_simulation.gd`: fatigue on a `full` shift with no break exceeds 0.8 by minute 500 and output halves; morale falls when wage is set below base and a raise request appears after 3 days; a quitting worker disappears with severance not charged; golf pro lessons appear in the ledger as `lessons`; training removes and returns the worker with higher skill.
- `tests/test_regressions.gd`: old saves with integer `assignment` and no morale fields restore with defaults; wages reconcile in ledger.
- `tests/test_game.gd`: Staff tab callbacks for hire/train/fire run.

## Phases

1. Worker record fields, effective skill, fatigue and shifts (behaviour-neutral for `full` shift at morale 0.7).
2. Morale, raises, quitting, candidates and signing.
3. New roles: marshal, golf pro.
4. Training, head greenkeeper, shop clerk (after facilities plan).

## Dependencies

- Marshal and head greenkeeper need hole assignments from per-hole maintenance.
- Shop clerk needs the `pro_shop` facility.
