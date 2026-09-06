# Hole design metrics

## Goal

Extend the shot lab from "average strokes and hazard rate" into a design report card: difficulty versus par, slope-style rating, fairness, fun, pace, and a course-level summary with target bands per grade. Designers get clear goals; the resort gets a course rating that feeds reputation and events.

## Current state

- `ShotEngine.analyze` runs 30 seeded rounds at three skills and returns average strokes, hazard rate, and sample shots. `main.gd::analyze_hole` draws them.
- No metrics are stored; nothing compares holes or the course as a whole.

## Design

### Per-hole metrics

`ShotEngine.metrics(terrain, hole, count = 30, seed = 42) -> Dictionary` built on `analyze` output plus extra per-shot fields the engine already knows (`club`, `landing_surface`, `penalty`, `reason`):

| Metric | Definition | Target band |
|---|---|---|
| `difficulty` | intermediate average − par | −0.3 .. +0.8 |
| `spread` | expert average − beginner average | 1.0 .. 2.2 (skill matters but everyone finishes) |
| `hazard_rate` | hazards per round, intermediate | 0.1 .. 0.6 |
| `blowup_rate` | share of rounds ≥ par + 4 | < 0.12 |
| `fairness` | 1 − share of penalties whose landing was within 10 m of the intended target (unlucky) | > 0.75 |
| `variety` | distinct clubs used across all rounds / 8 | > 0.4 |
| `decision` | share of rounds where the layup choice differed from the driver line | 0.2 .. 0.7 for par 4/5 |
| `pace_minutes` | mean simulated minutes for a four-ball from tee to cup using `WALK_SPEED` and turn pauses | par 3 ≤ 11, par 4 ≤ 14, par 5 ≤ 17 |
| `green_receptiveness` | share of approach shots that hold the green | > 0.5 |
| `scenery` | `beauty_at` averaged over tee, landing zones, green | shown, no band |
| `fun` | weighted mix: variety 0.25, decision 0.25, fairness 0.2, spread-in-band 0.15, blowup penalty 0.15 | ≥ 0.6 |

Each metric returns `{value, band: "low"|"ok"|"high", note: String}` where `note` is an actionable sentence, e.g. "Beginners lose 1.4 balls here. Widen the landing area or move the water 20 m right."

### Course-level summary

`course_metrics(terrain, holes) -> Dictionary`:

- `course_rating` (expert average total) and `slope` (`(beginner total − expert total) × 5.381 / 1.5`, clamped 55..155) presented as familiar golf numbers.
- `par_total`, `length_total`, `par_mix` (counts of 3/4/5) with a note when the mix is monotonous.
- `routing`: sum of walking distance green → next tee via `terrain.route`, flagged when any transfer > 150 m.
- `rhythm`: whether difficulty alternates (a hard hole after two easy ones is rewarded); a simple autocorrelation score.
- `signature_hole`: the hole with the highest `fun` above 0.75 and scenery above 50.
- `design_score` (0..100) from the per-hole `fun` mean, routing, rhythm, and par mix.

### Where it is used

- **Grade nodes** (progression plan) require `design_score` ≥ 45 for Club and ≥ 65 for Resort, replacing part of the hidden quality gates.
- **Marketing**: a `signature_hole` adds +3 awareness per day while it holds; `design_score` feeds the Course sub-score.
- **Events**: `club_championship` and above require `slope ≥ 105`; `beginner_clinic` requires a hole with `difficulty ≤ 0`.
- **Guest behaviour**: `pace_minutes` becomes the estimate the simulation uses for tee-queue mood grace (`_apply_wait_mood` grace = expected pace), so slow holes explicitly cause queue complaints.

Metrics are computed on demand (analysis is 90 rounds, roughly 60 ms on the M2) and cached in `sim.hole_metrics[hole.id]` keyed by `terrain.revision`; `_end_day` refreshes any stale entries so daily systems have values without the player pressing Analyze.

### UI

Holes panel:

- Report card under Analyze: each metric as a row with value, band colour dot, and note; a "Show" button per metric that draws the relevant shots (e.g. hazard landings only) using the existing line and dot renderers.
- Course summary section at the top of the Holes list: rating/slope, par mix, design score with a target for the next grade, routing warnings with jump links.
- Hole list rows show a small fun/difficulty pair so the weakest hole is obvious.

## Files

- `scripts/shot_engine.gd`: `metrics`, `course_metrics`, per-shot fields `landing_surface`, `intended_target_distance`, `layup` flag.
- `scripts/resort_simulation.gd`: `hole_metrics`, cache refresh, pace-based grace, requirement hooks.
- `scripts/main.gd`: filtered draw modes.
- `scripts/resort_ui.gd`: report card and summary.
- `docs/SIMULATION.md`: metric table.

## Tests

- `tests/test_shots.gd`: metrics are deterministic for a fixed seed; a hole with water across the fairway scores lower fairness and higher blowup than the same hole without water; a very short par 4 gives `difficulty < −0.5` with a "consider par 3" note; `pace_minutes` grows with length.
- `tests/test_simulation.gd`: the 18-hole starter yields a `design_score` in 30..70 and a `slope` in 90..130 (guards against wild balance); cache invalidates when a hole is edited.
- `tests/test_game.gd`: report card renders; filtered draw adds and clears nodes.

## Phases

1. Per-hole metrics and report card.
2. Course summary, caching, pace-based grace.
3. Hooks into grade, events, marketing.

## Dependencies

- Green shapes plan supplies `reason` codes for OB/penalty buckets; before it lands, `hazard` alone is used.
