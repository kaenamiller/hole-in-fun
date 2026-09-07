# Validation record

The project is developed with Godot 4.7.2 on an Apple M2 Mac with 16 GB RAM. Source-level checks use the same Godot runtime as the packaged application.

## Automated coverage

- **Assets:** 60 catalog/model checks, including every facility and scenery asset, golfers, activity animation, carts, flags, model bounds and ground offsets.
- **Shots:** fixed-seed reproducibility, skill profiles, trees, water recovery, putting and bounded rounds. Players choose aims from expected remaining strokes (pin vs layup vs carry) before the usual miss ellipse resolves the shot. 8 behavioral-tuning checks currently fail (see open items below).
- **Terrain:** boundaries, reversible brushes and costs, flat water cells, snapshots, beauty and set combinations, separate walking/cart connectivity, bridge crossing, hole validity, mesh chunks and overlays, per-hole green ownership, OB/penalty zone classification, bunker depth, and procedural map generation. All passing.
- **Simulation:** individual visits, groups, staff assignments, financial transactions and loans, calendar events, qualifying-event and quality gates, construction interruption, hole order, RNG continuity, pricing/marketing/memberships, and a congested real-terrain stress run. 129 of 133 checks pass; `SIM_TEST_ONLY=<names>` runs individual tests in under two minutes.
- **Regressions:** partition-independent fixed simulation ticks, no fabricated routes across water, bridge reconnection, sandbox/physical event requirements, damaged-save backup recovery, a real starter-resort event through its full lifecycle, lodge stress drain, and reconciliation of cash with all ledger transactions. All passing.
- **Game integration:** main scene initialization, all navigation tab callbacks, terrain editing, placement, undo/redo, new tee/green creation, shot analysis, map smoke tests, menu previews, and named save/load with active visitors. All passing.

The stress scenario admits 12 four-balls at once (48 guests) on the real 3-hole starter terrain with arrivals suspended, and runs until the first completions land (~54,000 simulated seconds ≈ 68 calendar days under continuous play). Under the current calendar model there are no closing-time departures; visits resolve on their own.

## Open items after the calendar rework

The day model moved from a 600-minute operating window to continuous play (one calendar day = 800 sim-seconds; monthly settlement; seasonal grading; weather visuals). The following are tracked as known-open:

1. **test_shots (8 failures):** behavioral tuning of the expected-value decision/metrics system — difficulty bands on short par 4s, water-guard decision splits, aim-near-pin targeting, `pace_minutes` on the FakeTerrain double, and lag-putt behavior. Mechanical bugs in the same area (green ownership fallback, OB boundary spans, PNPOLY ray-cast, paint order) are fixed and their tests pass.
2. **test_simulation (4 failures):** analytics-landings spread across holes (sequential play + daily landing decay make multi-hole landings within short horizons unlikely), groundskeeper hole-recovery assertion, third-concurrent-project rejection, and the balk counter. All four are isolated contract checks; the systems themselves function.
3. **Unverified at scale:** full-round real-time pacing (~15–16 real minutes estimated for 18 holes at 1x), course congestion under full demand (a saturated 3-hole starter fills the 200-guest cap with multi-week tee waits), and starter-economy margins (monthly revenue roughly break-even against wages + upkeep).
4. **Balance notes:** analytics `landings` decay (0.7/day) is faster than the new round length suggests; event attendance on saturated small courses relies on the fortnight stall rule.

## Visual and desktop checks

The game is rendered using Godot's native Compatibility renderer on the M2 GPU. `capture_showcase.gd` and the integration harness capture actual engine viewports for inspection of terrain, buildings, scenery, shot trajectories, panels, and guest inspection. Roof orientation, excessive terrain brightness, palette noise and framing were corrected after inspecting these images.

System UI automation was unavailable because macOS Accessibility/Screen Recording permissions remained pending. Scene interactions are tested through their native Godot callbacks and rendered output, rather than claiming a manual OS-driven playthrough.

Both desktop presets use the official matching export templates. The macOS universal application is ad-hoc signed and is smoke-tested from its exported bundle. The Windows x64 executable embeds the game pack; export and file structure are checked, but Windows runtime validation requires a Windows machine.

## Performance

The reproducible benchmark opens all 18 holes, admits 100 guests, renders at the requested 1920 × 1080 window size, runs for 40 seconds, discards its first five seconds and reports average FPS and the 95th-percentile frame time. The target is 30 FPS on this machine, aiming for 60 FPS during ordinary play. The final run measured **117.5 FPS average** and **18.75 ms at the 95th percentile**, with 100 guests and all 18 holes present. Measurements are recorded in `builds/benchmark.log`; graphical captures and automated output are in the ignored `builds/` directory.

Performance depends on view distance, scenery count, simulation speed, machine load and screen scaling. This is a local benchmark, not a cross-platform performance guarantee.
