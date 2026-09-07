# Hole in Fun

An offline, single-player 3D golf-resort builder and management simulation, built from scratch in Godot 4.7.2 and GDScript. All models, materials, interface graphics, and construction sounds are generated within the project. No Blender, paid asset packs, API keys, or network services are required to play.

## Play

- **macOS:** open `builds/macos/Hole in Fun.app`. The universal application supports Apple Silicon and Intel Macs. The matching ZIP is suitable for copying to another Mac.
- **Windows:** run `builds/windows/Hole in Fun.exe` on Windows x64. Game data is embedded in the executable.
- **Source:** import `project.godot` in Godot 4.7.2 and press F6/F5, or run the command below. The editor downloaded for this workspace is in `.tools/Godot.app`.

```sh
.tools/Godot.app/Contents/MacOS/Godot --path .
```

Choose **Cedar House** for a working three-hole resort with six facilities and three staff, or begin with a funded blank property. Management mode has costs and progression; sandbox bypasses spending and grade restrictions. A blank property needs a clubhouse and a playable hole before visitors arrive.

These are development builds. The Mac app uses ad-hoc signing without Apple notarization; downloaded copies may require the normal macOS Open Anyway flow. Windows export is verified but has not been run on a Windows machine. There is no installer or store integration.

## What is playable

- A 1,024 m square, 4 m grid heightfield with individual height nodes, raise/lower/smooth/flatten brushes, seven surface types, water, cost previews, and reversible construction.
- Up to 18 named/reorderable holes with tees, cups, adjustable circular green boundaries, par, routing waypoints, availability checks, and open/closed states.
- A shared seeded shot engine for live golf and a 90-round design lab: beginner, intermediate, and expert profiles choose aims from expected remaining strokes (hazards, layups, carries), then resolve clubs, dispersion, elevation, lies, trees, water recovery, flight, roll, and putting.
- Two path types and two functional bridge types. Weighted walking routes favor paths. Carts follow a separate connected network; guests walk to their parked cart and from it to tees, facilities, and balls.
- Six facilities and 12 scenery items across three collections. Beauty radiates to nearby land and gains capped bonuses from distinct pieces in a collection. Repeated scenery is rendered with spatially grouped MultiMeshes.
- Individually inspectable golfers, groups of 1–4, arrival/check-in/need/round/departure states, turn-taking, tee and facility queues, scorecards, cart travel, and walking/swinging/putting/seated animations.
- Hireable and assignable groundskeepers, service attendants, and cleaners, with wages, physical travel, maintenance, cleanliness, and service effects.
- Prices, demand, cash, detailed transactions, monthly reports and settlement, three loan products, repayment, insolvency and one-time recovery funding.
- A continuous calendar with seasons and weather visuals, six event types with physical prerequisites, attendance and completed-round results, publicity, and three course grades assessed quarterly.
- Live edits relocate affected visitors, reset interrupted shots without adding strokes, recalculate routes, and record compensation. Impossible rounds end with refunds. Construction undo preserves ongoing simulation and transactions.
- Named local saves, monthly autosave, a save before replacing the current game, atomic replacement, a backup, and restoration of active visits and RNG state.

## Controls

| Action | Input |
|---|---|
| Pan | WASD, arrow keys, or middle-mouse drag |
| Camera height | `R`/`F` |
| Zoom | Mouse wheel or `Z`/`C` |
| Rotate camera | Q/E or right-mouse drag |
| Trackpad gestures | Two-finger swipe up/down pans; left/right rotates; pinch in/out zooms |
| Zoom | Mouse wheel |
| Build or select | Left click; drag terrain brushes |
| Rotate placement | X |
| Return to inspection / cancel tool | Escape |
| Pause / resume | Space or the top time controls |
| Undo / redo | Command/Ctrl+Z; Command/Ctrl+Shift+Z |
| Quick save | F5 |
| Photo mode | F9 (Escape exits) |
| Save screenshot | F12 |

Paths and bridges take two clicks. New holes take a tee click followed by a cup click and include painted tee and green surfaces. Use the **Holes** panel to select a hole, edit it, or run the shot lab. **Build** lists facilities, paths and scenery; click existing objects to relocate, rotate or demolish them. **Guests** exposes individual needs and thoughts. **Saves** contains camera reset, sound toggle and saved games.

Save files live in Godot's user-data directory under `saves/`: typically `~/Library/Application Support/Godot/app_userdata/Hole in Fun/saves/` on macOS and `%APPDATA%/Godot/app_userdata/Hole in Fun/saves/` on Windows. Tests use separate temporary save directories.

## Build and verify

Godot 4.7.2 and its matching export templates are required. Override `GODOT_BIN` to use a different installation. macOS universal export requires ETC2/ASTC imports; this project enables them. Both export presets are checked in.

```sh
./tools/test.sh
./tools/export.sh
```

The test script runs an editor parse scan, asset smoke checks, deterministic shots, terrain/navigation/bridge tests, simulation and economy tests, save-recovery regressions, and scene/UI integration. The real-world stress case admits 100 golfers onto 18 holes and advances a full operating day. The regression suite also hosts an actual open-day event through its full calendar lifecycle.

For visual checks and a 40-second performance capture:

```sh
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/capture_showcase.gd
.tools/Godot.app/Contents/MacOS/Godot --path . --script tests/test_game.gd -- --render-qa
.tools/Godot.app/Contents/MacOS/Godot --path . --resolution 1920x1080 -- --benchmark
```

Images and build/test logs are written to the ignored `builds/` directory. See `docs/VALIDATION.md` for measured results and test limitations.

## Architecture and extension points

`TerrainModel` owns height/surface arrays, holes, objects, beauty queries and weighted navigation. `TerrainView` renders chunk meshes, paths, bridges and scenery instances. `ResortSimulation` owns a fixed one-second simulation clock, people, queues, business and events. `ShotEngine` is shared by live and preview golf. `main.gd` coordinates reversible construction and scene presentation; `ResortUI` builds native Godot controls. `SaveStore` persists terrain and active simulation state.

`Catalog` exposes stable dictionary IDs plus typed `ContentDefinition` resources. `AssetFactory` produces cached, batched resort meshes with foliage LODs and animated scene hierarchies. Replace its builders with imported scenes later while preserving stable catalog IDs. No runtime code generation or external model service is needed.

## MVP boundaries

This is an initial, playable management prototype, not a finished commercial game. Content is intentionally compact and procedural. Terrain is a heightfield with cell-painted edges; greens have circular editable boundaries. Ball flight and strategy use a deliberately simplified model rather than a complete golf rules/aerodynamics engine. Facility use is simulated without detailed interiors, course maintenance is an aggregate condition value, and play is continuous: days roll over as accounting ticks (monthly settlement, seasonal course grading) rather than closing gates, so a congested course can hold golfers waiting for weeks.

No multiplayer, detailed weather/seasons, long-term memberships, underground terrain, organic spline bridges, licensed music, or store publishing is included. Balance, accessibility, controller support, and additional art/content remain future production work.

## Planned features

Detailed implementation plans for the next round of systems live in [`plans/`](plans/README.md), which also gives a suggested build order. Planned and specified there:

- Analytics overlays (traffic, waiting, landings, wear, coverage, elevation)
- Guest feedback aggregation and departure reviews
- Notifications and a persistent event log
- Per-hole maintenance replacing the aggregate wear value
- Memberships and returning guests
- Marketing campaigns and a reputation model
- Staff depth (experience, morale, shifts, training, new roles)
- Pricing depth (twilight and weekend rates, discounts, price sensitivity)
- Unlock progression separate from course grades
- Additional facilities and upgrade tiers
- Green shapes, bunkers, out-of-bounds, penalty areas, pins, and tee boxes
- Hole design metrics and a course report card
- Statistics, history, and charts
- Multiple procedurally generated maps

Deferred, not yet planned in detail:

- Goals and scenarios with win conditions
- Guided in-game onboarding for the blank property
- Spline paths and organic bridges
- A settings menu (audio, resolution, keybinds, accessibility, UI scale)
- Additional camera modes (walk the course, photo mode)
- Blueprints for saving and reusing hole layouts and facility clusters
- Music and ambient audio

Trees and vegetation as a growth system were considered and rejected.

## Lush resort visual pass

New Cedar House games feature three holes around a lake, woodland and a connected cart loop. Saved resorts receive the updated terrain, water, foliage and architectural rendering while keeping their layouts. F9 enables photo mode; F12 saves a PNG in the game's user-data screenshots folder. See [the implementation notes](design/lush-resort/README.md) for scope, captures and validation.
