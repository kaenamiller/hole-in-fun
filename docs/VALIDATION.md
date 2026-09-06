# Validation record

The project is developed with Godot 4.7.2 on an Apple M2 Mac with 16 GB RAM. Source-level checks use the same Godot runtime as the packaged application.

## Automated coverage

- **Assets:** 41 catalog/model checks, including every facility and scenery asset, golfers, activity animation, carts, flags, model bounds and ground offsets.
- **Shots:** fixed-seed reproducibility, skill profiles, trees, water recovery, putting and bounded rounds. A representative test hole averages 5.07 / 4.63 / 3.77 strokes for beginner / intermediate / expert.
- **Terrain:** boundaries, reversible brushes and costs, flat water cells, snapshots, beauty and set combinations, separate walking/cart connectivity, bridge crossing, hole validity, mesh chunks and overlays.
- **Simulation:** individual visits, groups, staff assignments, financial transactions and loans, calendar events, qualifying-event and quality gates, construction interruption, hole order, RNG continuity, and a full day on the real 18-hole terrain with 100 golfers admitted at once.
- **Regressions:** partition-independent fixed simulation ticks, no fabricated routes across water, bridge reconnection, sandbox/physical event requirements, damaged-save backup recovery, a real starter-resort event through two complete days, and reconciliation of cash with all ledger transactions.
- **Game integration:** main scene initialization, all eight UI tab callbacks, terrain editing, placement, undo/redo, new tee/green creation, shot analysis, and named save/load with active visitors. Tests use isolated save directories.

The full-course stress scenario is deliberately harsher than normal arrivals: all 100 guests arrive together. It verifies that completed rounds and closing-time departures resolve without stranded visitors; it does not require every congested visit to finish all 18 holes. The latest pre-packaging run completed 56 full visits and settled at day 2 with positive funds. A separate real open-day scenario produced a successful result with 75 attendees and 75 completed rounds.

## Visual and desktop checks

The game is rendered using Godot's native Compatibility renderer on the M2 GPU. `capture_showcase.gd` and the integration harness capture actual engine viewports for inspection of terrain, buildings, scenery, shot trajectories, panels, and guest inspection. Roof orientation, excessive terrain brightness, palette noise and framing were corrected after inspecting these images.

System UI automation was unavailable because macOS Accessibility/Screen Recording permissions remained pending. Scene interactions are tested through their native Godot callbacks and rendered output, rather than claiming a manual OS-driven playthrough.

Both desktop presets use the official matching export templates. The macOS universal application is ad-hoc signed and is smoke-tested from its exported bundle. The Windows x64 executable embeds the game pack; export and file structure are checked, but Windows runtime validation requires a Windows machine.

## Performance

The reproducible benchmark opens all 18 holes, admits 100 guests, renders at the requested 1920 × 1080 window size, runs for 40 seconds, discards its first five seconds and reports average FPS and the 95th-percentile frame time. The target is 30 FPS on this machine, aiming for 60 FPS during ordinary play. The final run measured **117.5 FPS average** and **18.75 ms at the 95th percentile**, with 100 guests and all 18 holes present. Measurements are recorded in `builds/benchmark.log`; graphical captures and automated output are in the ignored `builds/` directory.

Performance depends on view distance, scenery count, simulation speed, machine load and screen scaling. This is a local benchmark, not a cross-platform performance guarantee.
